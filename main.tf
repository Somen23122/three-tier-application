# create resource group 
resource "azurerm_resource_group" "rg-name" {
  name     = var.resource_group_name
  location = var.location
}

############################# creating vnet #@@@#######################################
resource "azurerm_virtual_network" "vnet_aks" {
  name                = "vnet-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.1.0.0/16"]
  depends_on          = [azurerm_resource_group.rg-name]
}

resource "azurerm_subnet" "aks" {
  name                                      = "snet-aks"
  resource_group_name                       = var.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.vnet_aks.name
  address_prefixes                          = ["10.1.1.0/24"]
  private_endpoint_network_policies_enabled = true
  depends_on                                = [azurerm_virtual_network.vnet_aks]
}

################################ Creating acr #######################################

#Creating acr repo

resource "azurerm_container_registry" "acr" {
  name                          = "acrakssomen"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  depends_on                    = [azurerm_subnet.aks]
}

#Creating private dns zone

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_container_registry.acr]
}

#Link the private dns with the vnet 

resource "azurerm_private_dns_zone_virtual_network_link" "acr2" {
  name                  = "pdznl-acr-cac-002"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.vnet_aks.id
  depends_on            = [azurerm_private_dns_zone.acr]
}

# Creating private endpoint 

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-cac-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.aks.id
  depends_on          = [azurerm_private_dns_zone_virtual_network_link.acr2]

  private_service_connection {
    name                           = "psc-acr-cac-001"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-acr-cac-001"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}

############################################### Creating aKS Private cluster  ######################################################################
### DNS zone
resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.eastus.azmk8s.io"
  resource_group_name = var.resource_group_name
  depends_on = [ azurerm_resource_group.rg-name ]
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks1" {
  name                  = "pdzvnl-aks-cac-001"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.vnet_aks.id
}

### Identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-cac-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  depends_on = [ azurerm_resource_group.rg-name ]
}

resource "azurerm_user_assigned_identity" "pod" {
  name                = "id-pod-cac-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  depends_on = [ azurerm_resource_group.rg-name ]
}

### Identity role assignment
resource "azurerm_role_assignment" "dns_contributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = azurerm_virtual_network.vnet_aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}


### AKS cluster creation
resource "azurerm_kubernetes_cluster" "aks" {
  name                       = "aks-pvaks-cac-001"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  dns_prefix_private_cluster = "aks-pvaks-cac-001"
  private_cluster_enabled    = true
  private_dns_zone_id        = azurerm_private_dns_zone.aks.id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = var.vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.1.3.4"
    service_cidr   = "10.1.3.0/24"
  }

  depends_on = [
    azurerm_role_assignment.network_contributor,
    azurerm_role_assignment.dns_contributor
  ]
}

