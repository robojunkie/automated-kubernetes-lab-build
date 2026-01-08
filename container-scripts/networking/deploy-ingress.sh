#!/bin/bash
################################################################################
# Deploy Nginx Ingress Controller
# Provides hostname-based routing (app.lab.local, api.lab.local, etc.)
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

log_info "Deploying Nginx Ingress Controller..."

# Deploy ingress-nginx
ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml"

log_info "Waiting for ingress controller pods to be ready..."
sleep 10

# Wait for pods
for i in {1..60}; do
    if ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n ingress-nginx | grep -q 'Running'"; then
        log_success "Ingress controller pods are running"
        break
    fi
    sleep 5
done

# Patch service type if needed
if [[ "$USE_LOADBALANCER" != "true" ]]; then
    log_info "Configuring ingress for NodePort access..."
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{\"spec\":{\"type\":\"NodePort\"}}'"
fi

log_success "Nginx Ingress Controller deployed successfully!"
log_info "Access via:"
if [[ "$USE_LOADBALANCER" == "true" ]]; then
    log_info "  LoadBalancer IP (check with: kubectl get svc -n ingress-nginx)"
else
    log_info "  NodePort: http://<node-ip>:$(ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name==\"http\")].nodePort}'")"
fi
