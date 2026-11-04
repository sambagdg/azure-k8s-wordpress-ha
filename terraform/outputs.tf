output "public_ips" {
  description = "IP publiques des nœuds"
  value       = { for k, ip in azurerm_public_ip.node : k => ip.ip_address }
}

output "ssh_commands" {
  description = "Commandes de connexion SSH"
  value = {
    for k, ip in azurerm_public_ip.node :
    k => "ssh -i ~/.ssh/azure_k8s ${var.admin_username}@${ip.ip_address}"
  }
}

# Inventaire Ansible généré automatiquement
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    vms        = var.vms
    ips        = { for k, ip in azurerm_public_ip.node : k => ip.ip_address }
    admin_user = var.admin_username
  })
}
