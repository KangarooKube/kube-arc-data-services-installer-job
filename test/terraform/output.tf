# ----------------------------------------------------------------------------------------------------------------------
# OUTPUT DESIRED VALUES
# ----------------------------------------------------------------------------------------------------------------------
output "resource_group_name" {
  description = "Name of the RG deployed"
  value       = azurerm_resource_group.rg.name
}

output "aks_name" {
  description = "Name of the AKS Cluster deployed"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "acr_name" {
  description = "Name of the ACR deployed"
  value       = azurerm_container_registry.acr.name
}
