output "resource_group_name" {
  value = module.resource_group.resource_group_name
}

output "aks_kube_config_raw" {
  value     = module.aks.kube_config_raw
  sensitive = true
}

output "aks_client_key" {
  value     = module.aks.client_key
  sensitive = true
}

output "aks_client_certificate" {
  value     = module.aks.client_certificate
  sensitive = true
}

output "aks_cluster_ca_certificate" {
  value     = module.aks.cluster_ca_certificate
  sensitive = true
}

output "aks_cluster_username" {
  value     = module.aks.cluster_username
  sensitive = true
}

output "aks_cluster_password" {
  value     = module.aks.cluster_password
  sensitive = true
}

output "acr_name" {
  value = module.acr.acr_name
}
