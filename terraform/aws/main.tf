data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_subnet" "gpu" {
  id = var.subnet_id
}

# ------------------------------------------------------------------ placement + EFA networking
resource "aws_placement_group" "gpu" {
  name     = "${var.cluster_name}-gpu-cluster"
  strategy = "cluster" # physically close hosts: lowest latency for NCCL all-reduce
}

resource "aws_security_group" "efa" {
  name_prefix = "${var.cluster_name}-efa-"
  description = "EFA requires all traffic between members of the same security group"
  vpc_id      = data.aws_subnet.gpu.vpc_id
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "efa_self" {
  security_group_id            = aws_security_group.efa.id
  referenced_security_group_id = aws_security_group.efa.id
  ip_protocol                  = "-1"
  description                  = "EFA intra-group traffic"
}

resource "aws_vpc_security_group_egress_rule" "efa_self" {
  security_group_id            = aws_security_group.efa.id
  referenced_security_group_id = aws_security_group.efa.id
  ip_protocol                  = "-1"
  description                  = "EFA intra-group traffic"
}

resource "aws_launch_template" "gpu" {
  name_prefix = "${var.cluster_name}-gpu-"

  dynamic "network_interfaces" {
    for_each = range(var.efa_interfaces)
    content {
      device_index          = network_interfaces.value == 0 ? 0 : 1
      network_card_index    = network_interfaces.value
      interface_type        = "efa"
      subnet_id             = var.subnet_id
      security_groups       = [aws_security_group.efa.id, data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
      delete_on_termination = true
    }
  }

  placement {
    group_name = aws_placement_group.gpu.name
  }

  dynamic "capacity_reservation_specification" {
    for_each = var.capacity_reservation_id == null ? [] : [1]
    content {
      capacity_reservation_target { capacity_reservation_id = var.capacity_reservation_id }
    }
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 500 # container images for GPU frameworks are large
      volume_type = "gp3"
      encrypted   = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1 # pods cannot reach node credentials; workloads use EKS Pod Identity
  }
}

# ------------------------------------------------------------------ node role
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name_prefix        = "${var.cluster_name}-gpu-"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ------------------------------------------------------------------ GPU node group
resource "aws_eks_node_group" "gpu" {
  cluster_name    = var.cluster_name
  node_group_name = "gpu-${replace(var.instance_type, ".", "-")}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [var.subnet_id]
  ami_type        = "AL2023_x86_64_NVIDIA" # driver + container toolkit preinstalled; GPU Operator runs with driver.enabled=false
  instance_types  = [var.instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    min_size     = 0
    desired_size = var.node_count
    max_size     = var.node_count
  }

  launch_template {
    id      = aws_launch_template.gpu.id
    version = aws_launch_template.gpu.latest_version
  }

  labels = {
    "nvidia.com/gpu.present"         = "true"
    "vpc.amazonaws.com/efa.present"  = "true"
    "node.kubernetes.io/accelerator" = "h100"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE" # only pods that tolerate GPUs land here
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ------------------------------------------------------------------ shared high-throughput storage
resource "aws_security_group" "lustre" {
  name_prefix = "${var.cluster_name}-lustre-"
  description = "FSx for Lustre access from GPU nodes"
  vpc_id      = data.aws_subnet.gpu.vpc_id
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "lustre" {
  for_each                     = { "988" = 988, "1018-1023" = 1018 }
  security_group_id            = aws_security_group.lustre.id
  referenced_security_group_id = aws_security_group.efa.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.key == "988" ? 988 : 1023
  description                  = "Lustre from GPU nodes"
}

resource "aws_fsx_lustre_file_system" "datasets" {
  storage_capacity            = var.lustre_capacity_gib
  subnet_ids                  = [var.subnet_id]
  security_group_ids          = [aws_security_group.lustre.id]
  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = 500 # MB/s per TiB
  data_compression_type       = "LZ4"
  file_system_type_version    = "2.15"
  metadata_configuration {
    mode = "AUTOMATIC"
  }
}
