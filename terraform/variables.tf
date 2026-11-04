variable "prefix" {
  description = "Préfixe des ressources (abonnement partagé)"
  type        = string
  default     = "sg"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "northeurope"
}

variable "owner" {
  description = "Propriétaire des ressources (tag)"
  type        = string
  default     = "samba"
}

variable "admin_ip" {
  description = "IP publique du poste de contrôle (accès SSH, API K8s, Grafana)"
  type        = string
}

variable "admin_username" {
  description = "Utilisateur administrateur des VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Chemin de la clé publique SSH injectée dans les VM"
  type        = string
  default     = "~/.ssh/azure_k8s.pub"
}

variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "vms" {
  description = "Définition des nœuds du cluster"
  type = map(object({
    size       = string
    private_ip = string
    zone       = string
    role       = string
  }))
  default = {
    master = {
      size       = "Standard_B2s"
      private_ip = "10.10.1.10"
      zone       = "1"
      role       = "master"
    }
    worker1 = {
      size       = "Standard_B2ms"
      private_ip = "10.10.1.11"
      zone       = "2"
      role       = "worker"
    }
    worker2 = {
      size       = "Standard_B2ms"
      private_ip = "10.10.1.12"
      zone       = "3"
      role       = "worker"
    }
  }
}

locals {
  tags = {
    projet = "devops-wordpress-k8s"
    owner  = var.owner
    env    = "lab"
  }
}


variable "resource_group_name" {
  description = "Groupe de ressources existant fourni par l'organisme de formation"
  type        = string
  default     = "rg-formation-samba"
}
