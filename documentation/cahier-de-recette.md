# Cahier de recette — WordPress HA sur Kubernetes (Azure)

| ID | Exigence | Test réalisé | Résultat attendu | Résultat obtenu | Capture |
|----|----------|--------------|------------------|-----------------|---------|
| T01 | Infrastructure reproductible | `terraform plan` après déploiement | `No changes` | Conforme | P2-04 |
| T02 | Cluster 3 nœuds | `kubectl get nodes` | 3 nœuds Ready | Conforme | P4-02 |
| T03 | Configuration idempotente | 2ᵉ exécution de `site.yml` | `changed=0` | Conforme | P3-03, P4-04 |
| T04 | Stockage NFS | Écriture depuis worker1, lecture sur worker2 | Fichier identique | Conforme | P5-05 |
| T05 | Namespace, Secret, ConfigMap | `describe secret`, `get configmap` | Valeurs du Secret masquées | Conforme | P6-05 |
| T06 | WordPress dépend de MySQL | Démarrage avec MySQL indisponible | Pod WordPress bloqué en `Init` | Conforme (45 s d'attente) | P6-01, P7-06 |
| T07 | Accès à WordPress | HTTP sur le NodePort de chaque nœud | Code 200 | Conforme | P6-08, P11-01 |
| T08 | Persistance MySQL | Suppression du pod MySQL | Contenu intact | Conforme | P11-02 |
| T09 | Persistance des fichiers | Suppression des 3 pods WordPress | Image toujours servie | Conforme | P11-04 |
| T10 | Redémarrage des pods | Suppression d'un pod WordPress sous trafic | 100 % de réponses 200 | Conforme (remplacement en 11 s) | P7-05 |
| T11 | Résilience d'un nœud | `kubectl drain worker1` | Bascule sur worker2 | Conforme ; ~1 min d'indisponibilité de MySQL (instance unique) | P7-06 |
| T12 | Redémarrage complet | Arrêt puis démarrage des 3 VM | Plateforme opérationnelle sans intervention | Conforme | P7-00 |
| T13 | Scaling manuel | `kubectl scale --replicas=3` | 3 pods répartis sur 2 nœuds | Conforme | P7-02, P7-03 |
| T14 | Autoscaling | Test de charge (8 clients) | Passage de 3 à 6 réplicas, puis retour à 3 | Conforme | P7-08, P7-09 |
| T15 | Supervision active | Tableaux de bord Grafana, sonde HTTP | Mesures nœuds, pods, temps de réponse | Conforme | P8-04 à P8-08 |
| T16 | Alerte base indisponible | MySQL arrêté | `MySQLIndisponible` et `WordPressInaccessible` en Firing | Conforme | P8-10, P8-11 |
| T17 | Alerte CPU > 80 % / 2 min | Charge CPU sur worker1 | `NoeudCPUEleve` en Firing | Conforme | P8-13 |
| T18 | Logs centralisés | Recherche LogQL WordPress, MySQL, événements | Logs en temps réel | Conforme | P9-04 à P9-07 |
| T19 | Diagnostic par les logs | Panne MySQL simulée | Cause identifiée en 2 requêtes | Conforme | P9-09 |
| T20 | Sauvegarde etcd | `ansible-playbook backup.yml` | Snapshot vérifié sur le NFS | Conforme (567 clés, 21 Mo) | P10-01, P10-02 |
| T21 | Sauvegarde MySQL | Job issu du CronJob | Dump `.sql` sur le NFS | Conforme | P10-03 |
| T22 | Restauration MySQL | Article supprimé puis restauré | Article de nouveau visible | Conforme | P10-06 à P10-08 |
| T23 | Validation globale | `tests/validation.sh` | 0 test en échec | Conforme | P11-01 |
