variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  description = "Existing EKS cluster to attach the GPU node group to."
  type        = string
}

variable "subnet_id" {
  description = "Single private subnet (one AZ) so all GPU nodes share a placement group and EFA fabric."
  type        = string
}

variable "instance_type" {
  description = "EFA-capable GPU instance (p5.48xlarge: 8x H100, 32 EFA interfaces)."
  type        = string
  default     = "p5.48xlarge"
}

variable "efa_interfaces" {
  description = "EFA network cards per instance (p5.48xlarge supports 32; p4d.24xlarge supports 4)."
  type        = number
  default     = 32
}

variable "node_count" {
  type    = number
  default = 2
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 64
    error_message = "1-64 GPU nodes."
  }
}

variable "capacity_reservation_id" {
  description = "Optional ODCR / Capacity Block ID; GPU capacity is often only guaranteed through a reservation."
  type        = string
  default     = null
}

variable "lustre_capacity_gib" {
  type    = number
  default = 4800
}
