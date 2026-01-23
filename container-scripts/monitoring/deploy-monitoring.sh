#!/bin/bash
################################################################################
# Deploy Prometheus + Grafana Monitoring Stack
# Monitors Kubernetes cluster and can be extended to monitor LAN devices
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Deploying Prometheus & Grafana Monitoring Stack ==="
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Add Helm repo
echo "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack
echo ""
echo "Installing kube-prometheus-stack (this may take 5-10 minutes)..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f "${PROJECT_ROOT}/configs/monitoring-values.yaml" \
  --wait

echo ""
echo "Waiting for Prometheus and Grafana pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s || true

# Get service information
echo ""
echo "Getting LoadBalancer IPs..."
GRAFANA_IP=$(kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

# Display status
echo ""
echo "============================================"
echo "  Monitoring Stack Deployment Complete!"
echo "============================================"
echo ""
echo "Grafana:"
echo "  URL: http://${GRAFANA_IP}:3000 (or http://grafana.home.lab)"
echo "  Username: admin"
echo "  Password: changeme123"
echo ""
echo "Prometheus:"
echo "  Access via port-forward:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""
echo "Alertmanager:"
echo "  Access via port-forward:"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
echo ""
echo "Pre-configured Dashboards:"
echo "  - Kubernetes / Compute Resources / Cluster"
echo "  - Kubernetes / Compute Resources / Namespace (Pods)"
echo "  - Node Exporter / Nodes"
echo "  - Kubernetes / Networking / Cluster"
echo "  - Prometheus / Overview"
echo ""
echo "Next Steps:"
echo "  1. Add Grafana DNS to pfSense: grafana.home.lab -> ${GRAFANA_IP}"
echo "  2. Login to Grafana and explore dashboards"
echo "  3. Install node_exporter on external servers to monitor"
echo "  4. See docs/MONITORING.md for full configuration guide"
echo ""
echo "View all monitoring resources:"
echo "  kubectl get all -n monitoring"
echo "============================================"
