"""Distributed data-parallel training reference (PyTorch DDP).

The same script runs on:
  * one laptop CPU            torchrun --nproc-per-node 2 training/train_ddp.py --backend gloo
  * one GPU node (8 GPUs)     torchrun --nproc-per-node 8 training/train_ddp.py
  * Slurm, many nodes         srun torchrun --nnodes $SLURM_NNODES ... (see slurm/jobs)
  * Kubernetes (PyTorchJob)   env vars injected by the training operator

It reports per-step throughput so scaling efficiency (1 -> N GPUs) can be measured.
"""

from __future__ import annotations

import argparse
import json
import os
import time

import torch
import torch.distributed as dist
from torch import nn
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader, DistributedSampler, TensorDataset


def build_model(width: int) -> nn.Module:
    return nn.Sequential(
        nn.Linear(128, width), nn.GELU(), nn.Linear(width, width), nn.GELU(), nn.Linear(width, 10)
    )


def synthetic_dataset(n: int, seed: int) -> TensorDataset:
    g = torch.Generator().manual_seed(seed)
    x = torch.randn(n, 128, generator=g)
    w = torch.randn(128, 10, generator=g)
    return TensorDataset(x, (x @ w).argmax(1))  # learnable labels


def main(argv: list[str] | None = None) -> dict:
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", default="nccl" if torch.cuda.is_available() else "gloo")
    ap.add_argument("--epochs", type=int, default=2)
    ap.add_argument("--batch-size", type=int, default=256, help="per process")
    ap.add_argument("--samples", type=int, default=16384)
    ap.add_argument("--width", type=int, default=1024)
    ap.add_argument("--amp", action="store_true", help="bf16 autocast on GPU")
    ap.add_argument("--out", default="")
    args = ap.parse_args(argv)

    dist.init_process_group(args.backend)
    rank, world = dist.get_rank(), dist.get_world_size()
    local_rank = int(os.environ.get("LOCAL_RANK", 0))
    device = torch.device(f"cuda:{local_rank}" if torch.cuda.is_available() else "cpu")
    if device.type == "cuda":
        torch.cuda.set_device(device)
    torch.manual_seed(0)  # identical initial weights on every rank

    model = DDP(build_model(args.width).to(device), device_ids=[local_rank] if device.type == "cuda" else None)
    data = synthetic_dataset(args.samples, seed=1)
    sampler = DistributedSampler(data, num_replicas=world, rank=rank, shuffle=True, seed=0)
    loader = DataLoader(data, batch_size=args.batch_size, sampler=sampler, drop_last=True)
    opt = torch.optim.AdamW(model.parameters(), lr=1e-3)
    loss_fn = nn.CrossEntropyLoss()

    history = []
    for epoch in range(args.epochs):
        sampler.set_epoch(epoch)
        model.train()
        start, seen, total_loss = time.perf_counter(), 0, 0.0
        for x, y in loader:
            x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
            with torch.autocast(device.type, dtype=torch.bfloat16, enabled=args.amp and device.type == "cuda"):
                loss = loss_fn(model(x), y)
            opt.zero_grad(set_to_none=True)
            loss.backward()  # gradients all-reduced across ranks here
            opt.step()
            seen += x.size(0)
            total_loss += loss.item() * x.size(0)
        if device.type == "cuda":
            torch.cuda.synchronize()
        elapsed = time.perf_counter() - start
        stats = torch.tensor([seen, total_loss, elapsed], dtype=torch.float64, device=device)
        dist.all_reduce(stats[:2], op=dist.ReduceOp.SUM)
        dist.all_reduce(stats[2:], op=dist.ReduceOp.MAX)
        history.append({
            "epoch": epoch, "loss": stats[1].item() / stats[0].item(),
            "samples_per_sec": stats[0].item() / stats[2].item(),
        })

    # Every rank must hold identical weights after DDP training.
    checksum = torch.tensor(sum(p.detach().double().sum().item() for p in model.parameters()), dtype=torch.float64, device=device)
    gathered = [torch.zeros_like(checksum) for _ in range(world)]
    dist.all_gather(gathered, checksum)
    result = {
        "world_size": world, "backend": args.backend, "device": device.type, "history": history,
        "weights_in_sync": all(torch.isclose(g, checksum, rtol=0, atol=1e-6).item() for g in gathered),
    }
    if rank == 0:
        print(json.dumps(result))
        if args.out:
            with open(args.out, "w") as fh:
                json.dump(result, fh)
    dist.destroy_process_group()
    return result


if __name__ == "__main__":
    main()
