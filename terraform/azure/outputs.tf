output "node_pool_id" {
  value = azurerm_kubernetes_cluster_node_pool.gpu.id
}

output "lustre_mgs_address" {
  value = azurerm_managed_lustre_file_system.datasets.mgs_address
}
