#!/bin/bash
################################################################################
# Deploy Prometheus + Grafana Monitoring Stack
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/helpers/logging.sh"
source "$PROJECT_ROOT/scripts/helpers/ssh-utils.sh"

MASTER_IP="${1:-}"
USE_LOADBALANCER="${2:-false}"

if [[ -z "$MASTER_IP" ]]; then
    log_error "Usage: $0 <master-ip> [use-loadbalancer:true/false]"
    exit 1
fi

log_info "Deploying kube-prometheus-stack (Prometheus + Grafana)..."
log_info "This will take 2-3 minutes..."

# Clone kube-prometheus manifests
ssh_execute "$MASTER_IP" "rm -rf /tmp/kube-prometheus && git clone --depth 1 https://github.com/prometheus-operator/kube-prometheus.git /tmp/kube-prometheus"

# Deploy CRDs
log_info "Creating monitoring CRDs..."
ssh_execute "$MASTER_IP" "cd /tmp/kube-prometheus && KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply --server-side -f manifests/setup"

sleep 10

# Deploy monitoring components
log_info "Deploying monitoring components..."
ssh_execute "$MASTER_IP" "cd /tmp/kube-prometheus && KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f manifests/"

log_info "Waiting for pods to be ready (this takes a while)..."
sleep 30

# Wait for Grafana to be ready
for i in {1..120}; do
    if ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n monitoring | grep grafana | grep -q 'Running'"; then
        log_success "Grafana is running"
        break
    fi
    sleep 5
done

# Configure Grafana access
log_info "Configuring Grafana access..."
if [[ "$USE_LOADBALANCER" == "true" ]]; then
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch svc grafana -n monitoring -p '{\"spec\":{\"type\":\"LoadBalancer\"}}'"
    log_info "Grafana will be available on LoadBalancer IP (check with: kubectl get svc -n monitoring)"
else
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch svc grafana -n monitoring -p '{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"port\":3000,\"nodePort\":30300,\"targetPort\":3000}]}}'"
    log_success "Grafana available at: http://<node-ip>:30300"
fi

log_success "Monitoring stack deployed successfully!"
log_info "Grafana credentials: admin / admin (change on first login)"
log_info "Prometheus available at: kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090"
