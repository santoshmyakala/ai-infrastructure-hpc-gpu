output "node_group" {
  value = aws_eks_node_group.gpu.node_group_name
}

output "lustre_dns_name" {
  value = aws_fsx_lustre_file_system.datasets.dns_name
}

output "lustre_mount_name" {
  value = aws_fsx_lustre_file_system.datasets.mount_name
}
