mock_provider "azurerm" {
  override_during = plan
  mock_resource "azurerm_proximity_placement_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ai/providers/Microsoft.Compute/proximityPlacementGroups/ppg-gpu-training" }
  }
}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  kubernetes_cluster_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ai/providers/Microsoft.ContainerService/managedClusters/aks-ai"
  resource_group_name   = "rg-ai"
  gpu_subnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ai/providers/Microsoft.Network/virtualNetworks/vnet-ai/subnets/snet-gpu"
  lustre_subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ai/providers/Microsoft.Network/virtualNetworks/vnet-ai/subnets/snet-lustre"
}

run "gpu_pool" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.gpu.min_count == 0 && azurerm_kubernetes_cluster_node_pool.gpu.auto_scaling_enabled
    error_message = "GPU pool must autoscale from zero."
  }
  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.gpu.node_taints == tolist(["nvidia.com/gpu=present:NoSchedule"])
    error_message = "GPU nodes must be tainted."
  }
  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.gpu.gpu_driver == "None"
    error_message = "Driver lifecycle belongs to the GPU Operator, not the node image."
  }
  assert {
    condition     = join(",", sort(azurerm_kubernetes_cluster_node_pool.gpu.zones)) == var.zone && join(",", sort(azurerm_managed_lustre_file_system.datasets.zones)) == var.zone
    error_message = "Compute and Lustre must share one zone (latency + no cross-zone data charges)."
  }
  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.gpu.host_encryption_enabled
    error_message = "Encryption at host required."
  }
}
