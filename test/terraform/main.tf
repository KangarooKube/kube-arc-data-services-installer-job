# ---------------------------------------------------------------------------------------------------------------------
# RESOURCE PREFIX GENERATOR
# ---------------------------------------------------------------------------------------------------------------------

# Random ID generator
resource "random_id" "workspace" {
  byte_length = 4
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE RESOURCE GROUP
# ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_prefix}-${random_id.workspace.hex}-rg"
  location = var.resource_group_location
  tags     = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# AKS
# ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  depends_on = [azurerm_resource_group.rg]

  name                = "${var.resource_prefix}-${random_id.workspace.hex}-aks"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = azurerm_resource_group.rg.name

  default_node_pool {
    name                = "agentpool"
    node_count          = 3
    vm_size             = "Standard_DS3_v2"
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 6
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to nodes because we have autoscale enabled
      default_node_pool[0].node_count
    ]
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_la.id
  }

  role_based_access_control_enabled = true

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CONTAINER REGISTRY
# ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                   = "${var.resource_prefix}${random_id.workspace.hex}acr"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.resource_group_location
  sku                    = "Premium"
  admin_enabled          = true
  anonymous_pull_enabled = true

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# LOG ANALYTICS - AUDIT LOGS & CONTAINER INSIGHTS
# ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "aks_la" {
  depends_on = [azurerm_resource_group.rg]

  name                = "${var.resource_prefix}-${random_id.workspace.hex}-la"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.resource_group_location
  sku                 = "PerGB2018"

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "aks_la" {
  solution_name         = "ContainerInsights"
  location              = var.resource_group_location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks_la.id
  workspace_name        = azurerm_log_analytics_workspace.aks_la.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks_audit" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  name                       = "${azurerm_kubernetes_cluster.aks.name}-audit"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_la.id

  log {
    category = "kube-apiserver"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "kube-audit"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "kube-audit-admin"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "kube-controller-manager"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "kube-scheduler"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "cluster-autoscaler"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "cloud-controller-manager"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "guard"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "csi-azuredisk-controller"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "csi-azurefile-controller"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "csi-snapshot-controller"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }
}
