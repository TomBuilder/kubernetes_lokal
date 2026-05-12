output "aks_cluster_name" {
  description = "Name des neuen AKS Test-Clusters"
  value       = azurerm_kubernetes_cluster.aks_test.name
}

output "aks_resource_group" {
  description = "Resource Group des neuen AKS Test-Clusters"
  value       = azurerm_resource_group.aks_test.name
}

output "aks_subnet_cidr" {
  description = "CIDR des neuen AKS-Subnetzes"
  value       = azurerm_subnet.aks_test.address_prefixes[0]
}

output "managed_identity_client_id" {
  description = "Client ID der Managed Identity (benoetigt fuer Workload Identity)"
  value       = azurerm_user_assigned_identity.aks_test.client_id
}

output "kubeconfig_command" {
  description = "Befehl zum Abrufen des kubeconfig fuer den neuen Cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.aks_test.name} --name ${azurerm_kubernetes_cluster.aks_test.name} --subscription ${var.subscription_id}"
}
