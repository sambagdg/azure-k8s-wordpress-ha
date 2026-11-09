#!/bin/bash
# Validation de la plateforme WordPress sur Kubernetes
# Usage : ./tests/validation.sh   (KUBECONFIG doit pointer vers le cluster du projet)

NS_APP=gandega-project1
NS_MON=monitoring
NODE_IPS=(4.207.144.21 40.113.41.15 40.67.242.232)
WP_HOST="40.113.41.15:30080"
PASS=0
FAIL=0

ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
ko()   { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else ko "$1"; fi; }
prom()  { kubectl get --raw "/api/v1/namespaces/$NS_MON/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=$1"; }

echo "== Contexte : $(kubectl config current-context)"

echo "== 1. Cluster"
check "3 nœuds Ready" '[ "$(kubectl get nodes --no-headers | grep -cw Ready)" -eq 3 ]'
check "Pods système Running" '! kubectl get pods -n kube-system --no-headers | grep -vE "Running|Completed"'

echo "== 2. Application"
check "Namespace $NS_APP présent" "kubectl get ns $NS_APP"
check "Secret mysql-secret présent" "kubectl get secret mysql-secret -n $NS_APP"
check "ConfigMap app-config présente" "kubectl get configmap app-config -n $NS_APP"
check "PVC mysql-pvc Bound" '[ "$(kubectl get pvc mysql-pvc -n $NS_APP -o jsonpath={.status.phase})" = Bound ]'
check "PVC wordpress-pvc Bound" '[ "$(kubectl get pvc wordpress-pvc -n $NS_APP -o jsonpath={.status.phase})" = Bound ]'
check "MySQL disponible (1/1)" '[ "$(kubectl get deploy mysql -n $NS_APP -o jsonpath={.status.availableReplicas})" -ge 1 ]'
check "WordPress ≥ 3 réplicas disponibles" '[ "$(kubectl get deploy wordpress -n $NS_APP -o jsonpath={.status.availableReplicas})" -ge 3 ]'
check "WordPress réparti sur 2 nœuds" '[ "$(kubectl get pods -n $NS_APP -l app=wordpress -o jsonpath="{.items[*].spec.nodeName}" | tr " " "\n" | sort -u | wc -l)" -ge 2 ]'

echo "== 3. Accès HTTP (NodePort 30080 sur chaque nœud)"
for ip in "${NODE_IPS[@]}"; do
  check "WordPress répond 200 via $ip" '[ "$(curl -s -o /dev/null -w %{http_code} --max-time 5 -H "Host: $WP_HOST" http://$ip:30080/)" = 200 ]'
done

echo "== 4. Haute disponibilité"
check "HPA présent (min 3, max 6)" '[ "$(kubectl get hpa wordpress-hpa -n $NS_APP -o jsonpath={.spec.minReplicas}-{.spec.maxReplicas})" = 3-6 ]'
check "HPA reçoit les mesures CPU" 'kubectl get hpa wordpress-hpa -n $NS_APP -o jsonpath={.status.currentMetrics[0].resource.current.averageUtilization} | grep -qE "^[0-9]+$"'
check "PodDisruptionBudget (min 2)" '[ "$(kubectl get pdb wordpress-pdb -n $NS_APP -o jsonpath={.spec.minAvailable})" = 2 ]'
check "metrics-server opérationnel" 'kubectl top nodes'

echo "== 5. Supervision"
check "Pods monitoring Running" '! kubectl get pods -n $NS_MON --no-headers | grep -vE "Running|Completed"'
check "Grafana répond (30300)" '[ "$(curl -s -o /dev/null -w %{http_code} --max-time 5 http://${NODE_IPS[1]}:30300/api/health)" = 200 ]'
check "Sonde WordPress : probe_success = 1" 'prom "probe_success%7Bjob%3D%22wordpress-http%22%7D" | grep -q "\"1\"\]"'
check "Règles d’alerte du projet chargées" 'kubectl get prometheusrule wordpress-alerts -n $NS_MON'
check "Aucune alerte critique du projet active" '! prom "ALERTS%7Balertstate%3D%22firing%22%2Cseverity%3D%22critical%22%7D" | grep -q alertname'

echo "== 6. Logs"
check "Loki prêt" 'kubectl get --raw "/api/v1/namespaces/$NS_MON/services/loki:3100/proxy/ready" | grep -q ready'
check "Alloy Running" 'kubectl get pods -n $NS_MON -l app.kubernetes.io/name=alloy --no-headers | grep -q Running'

echo "== 7. Sauvegardes"
check "CronJob mysql-backup présent" "kubectl get cronjob mysql-backup -n $NS_APP"
check "Sauvegarde MySQL de moins de 25 h sur le NFS" 'ansible -i ansible/inventory.ini nfs_server -b -m shell -a "find /srv/nfs/backup/mysql -name \"*.sql\" -mmin -1500 | grep -q ."'
check "Sauvegarde etcd de moins de 25 h sur le NFS" 'ansible -i ansible/inventory.ini nfs_server -b -m shell -a "find /srv/nfs/backup/etcd -name \"*.db\" -mmin -1500 | grep -q ."'

echo
echo "== Résultat : $PASS réussis, $FAIL en échec"
[ "$FAIL" -eq 0 ]
