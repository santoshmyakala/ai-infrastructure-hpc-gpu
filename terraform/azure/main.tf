resource "azurerm_proximity_placement_group" "gpu" {
  name                = "ppg-gpu-training"
  location            = var.location
  resource_group_name = var.resource_group_name
  zone                = var.zone
  allowed_vm_sizes    = [var.vm_size]
}

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                         = "h100"
  kubernetes_cluster_id        = var.kubernetes_cluster_id
  vm_size                      = var.vm_size
  zones                        = [var.zone]
  vnet_subnet_id               = var.gpu_subnet_id
  proximity_placement_group_id = azurerm_proximity_placement_group.gpu.id
  auto_scaling_enabled         = true
  min_count                    = 0 # scale to zero when the queue is empty
  max_count                    = var.max_nodes
  os_disk_type                 = "Ephemeral"
  os_disk_size_gb              = 256
  host_encryption_enabled      = true
  gpu_driver                   = "None" # NVIDIA GPU Operator installs and manages the driver
  node_labels = {
    "nvidia.com/gpu.present"         = "true"
    "node.kubernetes.io/accelerator" = "h100"
  }
  node_taints = ["nvidia.com/gpu=present:NoSchedule"]
  upgrade_settings {
    max_unavailable = "1" # GPU capacity is scarce: upgrade in place, one node at a time (no surge node)
  }
}

# Azure Managed Lustre: shared, high-throughput storage for datasets and checkpoints.
resource "azurerm_managed_lustre_file_system" "datasets" {
  name                   = "amlfs-training"
  resource_group_name    = var.resource_group_name
  location               = var.location
  sku_name               = "AMLFS-Durable-Premium-250"
  storage_capacity_in_tb = 8
  subnet_id              = var.lustre_subnet_id
  zones                  = [var.zone]
  maintenance_window {
    day_of_week        = "Sunday"
    time_of_day_in_utc = "02:00"
  }
}
