# IP publique statique pour chaque nœud (une par zone)
resource "azurerm_public_ip" "node" {
  for_each            = var.vms
  name                = "pip-${var.prefix}-${each.key}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [each.value.zone]
  tags                = local.tags
}

# Carte réseau avec IP privée fixe
resource "azurerm_network_interface" "node" {
  for_each            = var.vms
  name                = "nic-${var.prefix}-${each.key}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = azurerm_public_ip.node[each.key].id
  }
}

# Machines virtuelles Ubuntu 22.04 (Gen2, requis par la série Bsv2)
resource "azurerm_linux_virtual_machine" "node" {
  for_each              = var.vms
  name                  = "vm-${var.prefix}-${each.key}"
  computer_name         = each.key
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  size                  = each.value.size
  zone                  = each.value.zone
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "osdisk-${var.prefix}-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(local.tags, { role = each.value.role })
}

# Disque de données dédié au stockage NFS (sur worker2 = node3)
resource "azurerm_managed_disk" "nfs" {
  name                 = "disk-${var.prefix}-nfs-data"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  zone                 = var.vms["worker2"].zone
  tags                 = local.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "nfs" {
  managed_disk_id    = azurerm_managed_disk.nfs.id
  virtual_machine_id = azurerm_linux_virtual_machine.node["worker2"].id
  lun                = 0
  caching            = "ReadWrite"
}
