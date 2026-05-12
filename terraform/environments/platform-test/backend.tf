terraform {
  backend "azurerm" {
    resource_group_name  = "ips-cloud-tfstate"
    storage_account_name = "tfstateipstest"
    container_name       = "tfstate"
    key                  = "platform-test/terraform.tfstate"
    subscription_id      = "aca258eb-d34c-4b5a-be85-3cfd1f9786bc"
  }
}
