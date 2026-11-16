#!/bin/bash
# Multi-node PyTorch DDP on Slurm with Pyxis/Enroot containers and InfiniBand.
#   sbatch --nodes=2 slurm/jobs/train-multinode.sbatch
#SBATCH --job-name=ddp-train
#SBATCH --partition=train
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=8
#SBATCH --cpus-per-task=96
#SBATCH --time=04:00:00
#SBATCH --exclusive
#SBATCH --output=logs/%x-%j.out

set -euo pipefail

CONTAINER=${CONTAINER:-nvcr.io#nvidia/pytorch:25.01-py3}
MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export MASTER_ADDR MASTER_PORT=29500

# NCCL over InfiniBand/RoCE; set NCCL_SOCKET_IFNAME to the management NIC for bootstrap traffic.
export NCCL_IB_HCA=${NCCL_IB_HCA:-mlx5}
export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME:-eth0}
export NCCL_DEBUG=${NCCL_DEBUG:-WARN}

srun --container-image="$CONTAINER" \
     --container-mounts="$PWD:/workspace" \
     --container-workdir=/workspace \
     torchrun \
       --nnodes "$SLURM_NNODES" \
       --nproc-per-node "$SLURM_GPUS_ON_NODE" \
       --rdzv-id "$SLURM_JOB_ID" \
       --rdzv-backend c10d \
       --rdzv-endpoint "$MASTER_ADDR:$MASTER_PORT" \
       training/train_ddp.py --amp --epochs 5 --samples 4000000 --out "logs/result-$SLURM_JOB_ID.json"
