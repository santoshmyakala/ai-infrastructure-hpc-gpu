# Licensing guide: NVIDIA GPU, HPC and AI infrastructure software

> **Short answer:** for the stack in this repository (bare-metal or cloud GPU nodes, Kubernetes or Slurm, PyTorch training), **no paid licence is required**. Every component is open source or free-of-charge NVIDIA software. You need a paid **NVIDIA AI Enterprise** subscription only for enterprise support and production-branch drivers, for running **NIM** microservices in production, or for **virtualised GPUs (vGPU)**.
>
> Licensing terms change. Confirm current terms with NVIDIA, or with your cloud or hardware vendor, before a production purchase. This guide is engineering guidance, not legal advice.

## Component by component

| Layer | Component | Licence | Cost | Notes |
|---|---|---|---|---|
| Driver | NVIDIA data-center GPU driver | NVIDIA software licence (proprietary) | Free | Open GPU kernel modules (Turing and newer) are dual **MIT/GPL-2.0**; user-space components remain proprietary |
| CUDA | CUDA Toolkit, cuBLAS, cuFFT… | NVIDIA CUDA EULA | Free | The EULA permits redistributing listed runtime libraries inside your containers |
| Libraries | cuDNN | NVIDIA Software License Agreement | Free | Included in NGC/PyTorch images |
| | NCCL | **BSD-3-Clause** | Free | Multi-GPU/multi-node collectives |
| Containers | NVIDIA Container Toolkit | **Apache-2.0** | Free | `nvidia-ctk` / CDI |
| | NGC framework containers (PyTorch, etc.) | NVIDIA Deep Learning Container License | Free | Some enterprise-only images need an AI Enterprise entitlement |
| Kubernetes | GPU Operator, device plugin, GPU Feature Discovery, MIG manager | **Apache-2.0** | Free | All open source; AI Enterprise adds supported releases only |
| | Network Operator (RDMA/InfiniBand) | **Apache-2.0** | Free | |
| | KAI Scheduler (open-sourced from Run:ai) | **Apache-2.0** | Free | The commercial Run:ai platform is separate |
| Monitoring | DCGM, dcgm-exporter | **Apache-2.0** | Free | GPU health, utilisation, XID errors |
| Networking | DOCA-OFED / MLNX_OFED drivers | Mixed open source (GPL/BSD) + NVIDIA | Free | UFM (InfiniBand fabric manager) is **commercial** |
| HPC scheduler | Slurm | **GPL-2.0** | Free | Optional paid support from SchedMD |
| | Enroot, Pyxis (containers in Slurm) | **Apache-2.0** | Free | |
| Cluster management | NVIDIA Base Command Manager | Commercial | Free tier / paid | A free edition exists for small clusters, and it's included with DGX and AI Enterprise. Check the current node/GPU limits |
| Queueing on K8s | Kueue, Volcano, Kubeflow Training Operator | **Apache-2.0** | Free | |
| Enterprise suite | **NVIDIA AI Enterprise (NVAIE)** | Commercial subscription | **Paid, per GPU** | Enterprise support, production-branch drivers, security patches for NGC images, **NIM in production**, vGPU for compute (vCS). Some GPU SKUs and DGX systems **bundle a multi-year subscription**; check your quote |
| Inference | NVIDIA NIM microservices | NVIDIA AI Product Agreement | Free for dev/test via the NVIDIA Developer Program; **production needs NVAIE** | |
| | Triton Inference Server, TensorRT-LLM | **BSD-3** / **Apache-2.0** | Free | Open source; NVAIE adds support |
| Virtualisation | NVIDIA vGPU software (vPC, vApps, RTX vWS, vCS) | Commercial | **Paid, per concurrent user or per GPU** | Needed only when **sharing one physical GPU across VMs via a hypervisor**. Not needed for bare metal, PCIe passthrough, **MIG on bare metal/Kubernetes**, or time-slicing in Kubernetes. Requires the NVIDIA License System (cloud or on-prem license server) |

## Cloud GPU instances

| Situation | Licence you need |
|---|---|
| AWS P- and G-family instances (p5, p4d, g6…), Azure ND/NC-series, GCP A3/A2 | **None extra.** Install the free data-center driver and CUDA, or use the provider's GPU-optimised images (DLAMI, Azure HPC images) |
| GRID/virtual-workstation drivers on cloud visualisation instances (AWS G-series GRID driver, Azure NV-series) | Provided by the cloud provider for use on its instances; the licence cost is included in the instance price |
| NVIDIA AI Enterprise in the cloud | Bring-your-own-licence, or pay-as-you-go through the AWS, Azure or GCP marketplaces (hourly per GPU) |

## Models and data (often forgotten)

The infrastructure can be free while the **model** is not:
- Open-weight models ship under their own licences, for example the Llama Community License (acceptable-use policy and a large-company clause), Gemma terms, or Apache-2.0 models such as Mistral 7B. Check commercial-use and attribution terms.
- Datasets have their own licences, as this portfolio's ML repos document per dataset.
- Hosted model APIs (Anthropic, OpenAI, Azure OpenAI, Bedrock) are governed by the provider's commercial terms, not by an infrastructure licence.

## Decision checklist

1. Will GPUs be shared across **virtual machines** with a hypervisor? → **vGPU licence**. If it's containers on bare metal, use MIG or time-slicing instead (free).
2. Will you run **NIM** containers in production, or need NVIDIA support SLAs or production-branch drivers? → **NVIDIA AI Enterprise**.
3. Do you need a managed InfiniBand fabric UI or telemetry at scale? → **UFM** (commercial). Otherwise use the free subnet manager (OpenSM) plus DCGM/Prometheus.
4. Do you want vendor support for the scheduler? → SchedMD support for Slurm (optional).
5. Otherwise → everything in this repository is **free to use**.
