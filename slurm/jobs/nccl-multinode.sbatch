#!/bin/bash
# Cross-node NCCL all-reduce benchmark: validates InfiniBand + GPUDirect RDMA before real jobs.
#SBATCH --job-name=nccl-test
#SBATCH --partition=train
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --exclusive
#SBATCH --output=logs/%x-%j.out

set -euo pipefail
srun --mpi=pmix --container-image="nvcr.io#nvidia/pytorch:25.01-py3" \
  bash -c 'test -x /tmp/nccl-tests/build/all_reduce_perf_mpi || { \
      git clone --depth 1 https://github.com/NVIDIA/nccl-tests /tmp/nccl-tests && \
      make -C /tmp/nccl-tests -j MPI=1 MPI_HOME=/usr/local/mpi NAME_SUFFIX=_mpi; }; \
    /tmp/nccl-tests/build/all_reduce_perf_mpi -b 8M -e 8G -f 2 -g 1'
