# =============================================================================
# Data Sources — bestehende Ressourcen, werden NUR gelesen, nie veraendert
# =============================================================================

data "azurerm_virtual_network" "existing" {
  name                = var.existing_vnet_name
  resource_group_name = var.existing_rg_network
}

data "azurerm_container_registry" "global" {
  name                = var.existing_acr_name
  resource_group_name = var.existing_rg_global
}

data "azurerm_log_analytics_workspace" "existing" {
  name                = var.existing_log_analytics_name
  resource_group_name = var.existing_rg_logging
}

# =============================================================================
# Neue Ressourcen
# =============================================================================

# Resource Group fuer den Test-Cluster
resource "azurerm_resource_group" "aks_test" {
  name     = "ips-cloud-${var.environment}"
  location = var.location

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Neues Subnetz im bestehenden VNet
# Hinweis: Terraform erstellt nur das Subnetz — das VNet selbst wird nicht geaendert.
resource "azurerm_subnet" "aks_test" {
  name                 = var.aks_test_subnet_name
  resource_group_name  = var.existing_rg_network
  virtual_network_name = data.azurerm_virtual_network.existing.name
  address_prefixes     = [var.aks_test_subnet_cidr]
}

# Managed Identity fuer den neuen AKS-Cluster
resource "azurerm_user_assigned_identity" "aks_test" {
  name                = "user-ident-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_test.name

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

# ACR Pull-Berechtigung fuer die Managed Identity des neuen Clusters
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = data.azurerm_container_registry.global.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks_test.principal_id
}

# Netzwerk-Berechtigungen: Managed Identity darf im Subnetz Netzwerkkonfigurationen schreiben
resource "azurerm_role_assignment" "aks_network" {
  scope                = data.azurerm_virtual_network.existing.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_test.principal_id
}

# AKS Test-Cluster
resource "azurerm_kubernetes_cluster" "aks_test" {
  name                = "aks-cluster-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_test.name
  dns_prefix          = "aks-${var.environment}"
  node_resource_group = "aks-node-${var.environment}"

  kubernetes_version        = "1.34"
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Identitaet: eigene Managed Identity, getrennt vom bestehenden Cluster
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_test.id]
  }

  # System Node Pool — nur fuer Kubernetes-eigene Komponenten (kube-system)
  default_node_pool {
    name       = "systempool"
    vm_size    = var.system_pool_vm_size
    node_count = 1

    # Kein Autoscaler im System Pool — bleibt immer auf 1
    auto_scaling_enabled = false

    os_disk_type    = "Ephemeral"
    os_disk_size_gb = 75           # Standard_D2ds_v6 hat 75 GiB Temp-Disk
    os_sku          = "AzureLinux"
    vnet_subnet_id  = azurerm_subnet.aks_test.id

    upgrade_settings {
      max_surge = "10%"
    }

    tags = {
      environment = var.environment
    }
  }

  # Netzwerk: gleiche Konfiguration wie der bestehende Cluster
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = "10.245.0.0/16"   # eigener CIDR, kein Konflikt mit bestehendem Cluster
    service_cidr        = "10.1.0.0/16"     # eigener CIDR, kein Konflikt mit bestehendem Cluster
    dns_service_ip      = "10.1.0.10"
  }

  # Key Vault Secrets Provider (CSI Driver) — fuer spaetere Key Vault Integration
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Monitoring: bestehenden Log Analytics Workspace wiederverwenden
  oms_agent {
    log_analytics_workspace_id      = data.azurerm_log_analytics_workspace.existing.id
    msi_auth_for_monitoring_enabled = true
  }

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }

  depends_on = [
    azurerm_role_assignment.aks_acr_pull,
    azurerm_role_assignment.aks_network,
  ]
}

# App Node Pool — fuer Anwendungs-Workloads, mit Autoscaler und scale-to-zero
resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name                  = "apppool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_test.id
  vm_size               = var.app_pool_vm_size
  mode                  = "User"

  auto_scaling_enabled = true
  min_count            = var.app_pool_min_count
  max_count            = var.app_pool_max_count

  os_disk_type    = "Ephemeral"
  os_disk_size_gb = 75           # Standard_D2ds_v6 hat 75 GiB Temp-Disk
  os_sku          = "AzureLinux"
  vnet_subnet_id  = azurerm_subnet.aks_test.id

  upgrade_settings {
    max_surge = "10%"
  }

  tags = {
    environment = var.environment
  }
}
