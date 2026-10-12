#!/usr/bin/env bash
# Installs kube-prometheus-stack and this kit on the current kubectl context.
# Optional: export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/... before running.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CHART_VERSION=65.1.1

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Alertmanager reads the Slack webhook from this secret. A placeholder keeps it starting without Slack.
kubectl -n monitoring create secret generic alertmanager-slack \
  --from-literal=webhook-url="${SLACK_WEBHOOK_URL:-https://hooks.slack.com/services/T000/B000/PLACEHOLDER}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update prometheus-community >/dev/null

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version "$CHART_VERSION" \
  --values "$ROOT/helm/kube-prometheus-stack-values.yaml" \
  --wait --timeout 10m

kubectl apply -k "$ROOT"

echo
echo "Grafana:      kubectl -n monitoring port-forward svc/kps-grafana 3000:80"
echo "Prometheus:   kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090"
echo "Alertmanager: kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-alertmanager 9093"
