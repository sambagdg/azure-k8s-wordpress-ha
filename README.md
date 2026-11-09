# WordPress haute disponibilité sur Kubernetes dans Azure

![Terraform](https://img.shields.io/badge/Terraform-1.16-7B42BC?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-2.21-EE0000?logo=ansible&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35-326CE5?logo=kubernetes&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-North%20Europe-0078D4?logo=microsoftazure&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-Grafana-E6522C?logo=prometheus&logoColor=white)
![CI](https://github.com/sambagdg/azure-k8s-wordpress-ha/actions/workflows/ci.yml/badge.svg)

Déploiement **entièrement automatisé** d'une application e-commerce WordPress / MySQL sur un cluster Kubernetes de 3 nœuds dans Microsoft Azure : Infrastructure as Code, gestion de configuration, stockage persistant NFS, haute disponibilité, supervision, logs centralisés et sauvegardes.

> Projet réalisé dans le cadre du titre professionnel **Administrateur Système DevOps** (RNCP36061 — niveau 6).

## Architecture

![Architecture](docs/architecture.png)

| Nœud | Rôle | Taille Azure | Zone |
|---|---|---|---|
| master | Control-plane Kubernetes, etcd | Standard_B2s (2 vCPU / 4 Go) | 1 |
| worker1 | Pods WordPress, supervision | Standard_B2ms (2 vCPU / 8 Go) | 2 |
| worker2 | Pods WordPress, MySQL, serveur NFS (disque dédié 32 Go) | Standard_B2ms (2 vCPU / 8 Go) | 3 |

Chaque nœud est placé dans une **zone de disponibilité différente** : la perte d'un datacenter laisse le cluster opérationnel.

## Stack technique

| Domaine | Outils |
|---|---|
| Cloud | Microsoft Azure (VNet, NSG, IP publiques, disques managés, zones de disponibilité) |
| Infrastructure as Code | Terraform (`azurerm` 4.x, `for_each`, génération de l'inventaire Ansible) |
| Configuration | Ansible (rôles : common, containerd, kubernetes, master, workers, nfs) |
| Orchestration | Kubernetes 1.35 (kubeadm), containerd, Flannel (VXLAN) |
| Stockage | NFS — PersistentVolumes statiques (RWO pour MySQL, RWX pour WordPress) |
| Observabilité | Prometheus, Grafana, Alertmanager, kube-state-metrics, Loki |
| Sauvegarde | Snapshots etcd, dumps MySQL |

## Points techniques notables

- **Contraintes de gouvernance Azure** prises en compte : RBAC limité à un groupe de ressources existant (référencé via `data "azurerm_resource_group"`), Azure Policy restreignant les tailles de VM, quotas de vCPU par région et par famille.
- **Inventaire Ansible généré par Terraform** (`templatefile`) : aucune IP recopiée à la main.
- **Sécurité** : accès SSH par clé uniquement, ports d'administration (22, 6443, Grafana) ouverts à la seule IP de l'administrateur, secrets Kubernetes pour les mots de passe, aucun secret ni état Terraform versionné.
- **containerd** comme runtime (dockershim supprimé depuis Kubernetes 1.24) et **Flannel VXLAN** (l'IP-in-IP n'est pas supporté par le réseau Azure).
- WordPress ne démarre qu'une fois MySQL disponible (**initContainer**).

## Structure du dépôt

```
.
├── terraform/      # Infrastructure Azure (réseau, NSG, VM, disque NFS, inventaire)
├── ansible/        # Configuration des nœuds et création du cluster
├── kubernetes/     # Manifests : namespace, secrets, configmaps, PV/PVC, MySQL, WordPress, HPA
├── monitoring/     # Valeurs Helm kube-prometheus-stack, règles d'alerte
├── logging/        # Valeurs Helm Loki
├── backup/         # Scripts de sauvegarde etcd et MySQL
└── docs/           # Schémas et captures
```

## Déploiement

Prérequis : Terraform, Azure CLI, Ansible, kubectl, Helm, une clé SSH (`~/.ssh/azure_k8s`).

```bash
# 1. Infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars   # renseigner admin_ip
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init && terraform apply

# 2. Configuration et cluster (à venir)
# 3. Application, supervision, logs (à venir)
```

## Avancement

| Phase | Statut |
|---|---|
| Conception de l'architecture | ✅ |
| Poste de contrôle | ✅ |
| Infrastructure Terraform | ✅ |
| Configuration Ansible + cluster Kubernetes | 🔄 En cours |
| Stockage NFS + application WordPress/MySQL | ⏳ |
| Haute disponibilité (scaling, HPA) | ⏳ |
| Supervision, logs, alerting | ⏳ |
| Sauvegarde etcd / MySQL | ⏳ |

## Auteur

**Samba Gandega** — Administrateur Système & DevOps | Développeur Full-Stack Java/Angular
[sambagandega.com](https://sambagandega.com)
