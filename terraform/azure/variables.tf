variable "subscription_id" {
  type = string
}

variable "kubernetes_cluster_id" {
  description = "Existing AKS cluster resource ID."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "zone" {
  description = "Single zone so GPU nodes share the InfiniBand fabric and the Lustre file system."
  type        = string
  default     = "1"
}

variable "gpu_subnet_id" {
  type = string
}

variable "lustre_subnet_id" {
  type = string
}

variable "vm_size" {
  description = "ND H100 v5: 8x H100 80GB, 8x 400 Gb/s InfiniBand."
  type        = string
  default     = "Standard_ND96isr_H100_v5"
}

variable "max_nodes" {
  type    = number
  default = 4
}
