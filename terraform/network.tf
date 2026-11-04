# Groupe de ressources : conteneur logique de tout le projet
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-devops-wordpress"
  location = var.location
  tags     = local.tags
}

# Réseau virtuel
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}-k8s"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Sous-réseau des nœuds Kubernetes
resource "azurerm_subnet" "k8s" {
  name                 = "snet-${var.prefix}-k8s"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# Groupe de sécurité réseau (pare-feu)
resource "azurerm_network_security_group" "k8s" {
  name                = "nsg-${var.prefix}-k8s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.admin_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-K8s-API-Admin"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "${var.admin_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-WordPress"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Grafana-Admin"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30300"
    source_address_prefix      = "${var.admin_ip}/32"
    destination_address_prefix = "*"
  }
}

# Association du NSG au sous-réseau : les règles s'appliquent à toutes les VM
resource "azurerm_subnet_network_security_group_association" "k8s" {
  subnet_id                 = azurerm_subnet.k8s.id
  network_security_group_id = azurerm_network_security_group.k8s.id
}
