#!/bin/bash
# Test de fumée post-déploiement (droits limités au namespace de l'application)
# Usage : SMOKE_TARGETS="IP1 IP2" ./tests/smoke.sh
set -euo pipefail

NS=gandega-project1
WP_HOST="40.113.41.15:30080"
TARGETS="${SMOKE_TARGETS:-10.10.1.11 10.10.1.12}"

echo "== Déploiements"
for d in mysql wordpress; do
  kubectl rollout status deployment/"$d" -n "$NS" --timeout=300s
done

echo "== Pods de l'application"
kubectl get pods -n "$NS" -o wide

echo "== Réponses HTTP"
for ip in $TARGETS; do
  for i in 1 2 3 4 5; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "Host: $WP_HOST" "http://$ip:30080/") || code=000
    [ "$code" = 200 ] && break
    sleep 5
  done
  echo "WordPress via $ip : HTTP $code"
  [ "$code" = 200 ] || { echo "ÉCHEC : WordPress ne répond pas via $ip"; exit 1; }
done

echo "== Test de fumée réussi"
