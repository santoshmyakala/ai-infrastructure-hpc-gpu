"""Run the DDP script for real: 2 processes on CPU with the gloo backend (no GPU needed)."""

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def _run(tmp_path, nproc):
    out = tmp_path / f"result-{nproc}.json"
    cmd = [sys.executable, "-m", "torch.distributed.run", "--standalone", f"--nproc-per-node={nproc}",
           str(ROOT / "training/train_ddp.py"), "--backend", "gloo", "--epochs", "3",
           "--samples", "4096", "--width", "256", "--out", str(out)]
    subprocess.run(cmd, check=True, timeout=600, capture_output=True)
    return json.loads(out.read_text())


def test_two_process_ddp_trains_and_stays_in_sync(tmp_path):
    result = _run(tmp_path, 2)
    assert result["world_size"] == 2
    assert result["weights_in_sync"], "DDP replicas diverged"
    losses = [h["loss"] for h in result["history"]]
    assert losses[-1] < losses[0], f"loss did not decrease: {losses}"
