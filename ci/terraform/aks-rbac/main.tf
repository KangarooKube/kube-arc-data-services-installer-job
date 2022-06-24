module "resource_group" {
  source          = "git::https://github.com/KangarooKube/terraform-infrastructure-modules.git//modules/misc/resource-group?ref=v0.0.1"
  resource_prefix = var.resource_prefix
  location        = var.location
  tags            = var.tags
}

module "log_ws" {
  depends_on = [module.resource_group]
  source          = "git::https://github.com/KangarooKube/terraform-infrastructure-modules.git//modules/monitoring/log-analytics?ref=v0.0.1"
  resource_prefix = var.resource_prefix
  resource_group_name = module.resource_group.resource_group_name
  resource_group_location = module.resource_group.resource_group_location
  tags = var.tags
}

module "acr" {
  depends_on = [module.resource_group]
  source     = "git::https://github.com/KangarooKube/terraform-infrastructure-modules.git//modules/kubernetes/acr?ref=v0.0.1"
  resource_prefix = var.resource_prefix
  resource_group_name = module.resource_group.resource_group_name
  resource_group_location = module.resource_group.resource_group_location
  tags = var.tags
}

module "aks" {
  depends_on = [module.resource_group, module.log_ws]
  source     = "git::https://github.com/KangarooKube/terraform-infrastructure-modules.git//modules/kubernetes/aks?ref=v0.0.1"
  resource_prefix = var.resource_prefix
  resource_group_name = module.resource_group.resource_group_name
  resource_group_location = module.resource_group.resource_group_location
  enable_rbac = true
  log_ws_resource_name = module.log_ws.log_ws_resource_name
  log_ws_resource_id = module.log_ws.log_ws_resource_id
  tags = var.tags
}

resource "local_file" "kubeconfig" {
  depends_on = [module.aks]
  content  = module.aks.kube_config_raw
  filename = "kubeconfig"
}