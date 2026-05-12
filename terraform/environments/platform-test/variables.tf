variable "subscription_id" {
  description = "Azure Subscription ID (ipsystemegmbhentw)"
  type        = string
  default     = "aca258eb-d34c-4b5a-be85-3cfd1f9786bc"
}

variable "location" {
  description = "Azure-Region fuer alle Ressourcen"
  type        = string
  default     = "germanywestcentral"
}

variable "environment" {
  description = "Kuerzel fuer die Umgebung"
  type        = string
  default     = "ipsentw-test"
}

# --- Referenzen auf bestehende Ressourcen ---

variable "existing_rg_network" {
  description = "Resource Group des bestehenden VNet"
  type        = string
  default     = "ips-cloud-ipsentw"
}

variable "existing_vnet_name" {
  description = "Name des bestehenden VNet, in dem das neue Subnetz angelegt wird"
  type        = string
  default     = "vnet-ipsentw"
}

variable "existing_rg_global" {
  description = "Resource Group mit gemeinsamen Ressourcen (ACR, PostgreSQL)"
  type        = string
  default     = "ips-cloud-ipsentw-global"
}

variable "existing_acr_name" {
  description = "Name der gemeinsam genutzten Container Registry"
  type        = string
  default     = "conregipsentwglobal"
}

variable "existing_rg_logging" {
  description = "Resource Group mit bestehendem Log Analytics Workspace"
  type        = string
  default     = "ips-cloud-ipsentw"
}

variable "existing_log_analytics_name" {
  description = "Name des bestehenden Log Analytics Workspace fuer AKS-Monitoring"
  type        = string
  default     = "log-ips-ipsentw"
}

# --- Neues Subnetz ---

variable "aks_test_subnet_name" {
  description = "Name des neuen Subnetzes fuer den Test-AKS-Cluster"
  type        = string
  default     = "snet_aks_test"
}

variable "aks_test_subnet_cidr" {
  description = "CIDR des neuen Subnetzes (freier Bereich in 10.31.0.0/16)"
  type        = string
  default     = "10.31.4.0/24"
}

# --- AKS Node Pools ---

variable "system_pool_vm_size" {
  description = "VM-Groesse fuer den System Node Pool"
  type        = string
  default     = "Standard_D2ds_v6"
}

variable "app_pool_vm_size" {
  description = "VM-Groesse fuer den App Node Pool"
  type        = string
  default     = "Standard_D2ds_v6"
}

variable "app_pool_min_count" {
  description = "Minimale Knotenanzahl im App Pool (0 = scale-to-zero moeglich)"
  type        = number
  default     = 0
}

variable "app_pool_max_count" {
  description = "Maximale Knotenanzahl im App Pool"
  type        = number
  default     = 3
}
