# Runbook — Restauration d'etcd (cluster kubeadm, master unique)

À utiliser en cas de corruption ou de perte de la base etcd.
Toutes les commandes s'exécutent sur le master (`ssh -i ~/.ssh/azure_k8s azureuser@<IP master>`), en root (`sudo -i`).

## 1. Choisir la sauvegarde
    ls -lt /mnt/backup/etcd/
    etcdutl snapshot status /mnt/backup/etcd/etcd-AAAAMMJJ-HHMMSS.db -w table

Vérifier que le HASH et le nombre de clés sont cohérents.

## 2. Arrêter le plan de contrôle
Les composants du plan de contrôle sont des « pods statiques » : kubelet les
lance à partir des fichiers de /etc/kubernetes/manifests. Déplacer ces fichiers
les arrête.
    mkdir -p /root/manifests-backup
    mv /etc/kubernetes/manifests/*.yaml /root/manifests-backup/
    # attendre l'arrêt (environ 30 s)
    crictl ps | grep -E "etcd|kube-apiserver"    # doit être vide

## 3. Restaurer le snapshot
    mv /var/lib/etcd /var/lib/etcd.old
    etcdutl snapshot restore /mnt/backup/etcd/etcd-AAAAMMJJ-HHMMSS.db \
      --data-dir /var/lib/etcd \
      --name master \
      --initial-cluster master=https://10.10.1.10:2380 \
      --initial-advertise-peer-urls https://10.10.1.10:2380

## 4. Redémarrer le plan de contrôle
    mv /root/manifests-backup/*.yaml /etc/kubernetes/manifests/
    # attendre 1 à 2 minutes
    crictl ps | grep -E "etcd|kube-apiserver"    # les deux doivent être Running

## 5. Vérifier (depuis le poste de contrôle)
    kubectl get nodes
    kubectl get pods -A
    kubectl get all -n gandega-project1

## Points d'attention
- Les objets Kubernetes créés après la date du snapshot sont perdus.
- Les données applicatives (base MySQL, fichiers WordPress) ne sont PAS dans etcd :
  elles sont sur le NFS et ont leur propre sauvegarde (CronJob mysql-backup).
- Un snapshot etcd contient tous les Secrets du cluster (encodés en base64, non chiffrés) :
  il doit être stocké avec des droits restreints (root, 0600).
- Conserver /var/lib/etcd.old jusqu'à validation complète, puis le supprimer.
