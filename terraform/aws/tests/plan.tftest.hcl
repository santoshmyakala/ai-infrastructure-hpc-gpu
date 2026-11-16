mock_provider "aws" {
  override_during = plan
  override_data {
    target = data.aws_eks_cluster.this
    values = { vpc_config = [{ cluster_security_group_id = "sg-cluster", vpc_id = "vpc-1", subnet_ids = [], security_group_ids = [], endpoint_private_access = true, endpoint_public_access = false, public_access_cidrs = [] }] }
  }
  override_data {
    target = data.aws_subnet.gpu
    values = { vpc_id = "vpc-1", availability_zone = "us-east-1a" }
  }
  override_data {
    target = data.aws_iam_policy_document.node_assume
    values = { json = "{}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/gpu-node" }
  }
}

variables {
  cluster_name = "ai-platform"
  subnet_id    = "subnet-0123"
}

run "gpu_fabric" {
  command = plan

  assert {
    condition     = aws_placement_group.gpu.strategy == "cluster"
    error_message = "GPU nodes need a cluster placement group for low-latency NCCL."
  }
  assert {
    condition     = length(aws_launch_template.gpu.network_interfaces) == 32 && alltrue([for n in aws_launch_template.gpu.network_interfaces : n.interface_type == "efa"])
    error_message = "p5.48xlarge must expose all 32 EFA network cards."
  }
  assert {
    condition     = length([for n in aws_launch_template.gpu.network_interfaces : n if n.device_index == 0]) == 1
    error_message = "Exactly one primary interface (device_index 0)."
  }
  assert {
    condition     = aws_eks_node_group.gpu.ami_type == "AL2023_x86_64_NVIDIA"
    error_message = "Use the EKS-optimised NVIDIA AMI."
  }
}

run "isolation_and_storage" {
  command = plan

  assert {
    condition     = [for t in aws_eks_node_group.gpu.taint : t.key] == ["nvidia.com/gpu"]
    error_message = "GPU nodes must be tainted so non-GPU pods do not consume them."
  }
  assert {
    condition     = aws_eks_node_group.gpu.scaling_config[0].min_size == 0
    error_message = "Scale-to-zero keeps idle GPU cost at zero."
  }
  assert {
    condition     = aws_launch_template.gpu.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 required."
  }
  assert {
    condition     = aws_fsx_lustre_file_system.datasets.deployment_type == "PERSISTENT_2"
    error_message = "Persistent Lustre for datasets and checkpoints."
  }
}

run "small_instance_profile" {
  command = plan
  variables {
    instance_type  = "p4d.24xlarge"
    efa_interfaces = 4
  }
  assert {
    condition     = length(aws_launch_template.gpu.network_interfaces) == 4
    error_message = "EFA interface count follows the instance type."
  }
}
