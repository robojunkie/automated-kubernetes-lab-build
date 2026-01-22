#!/bin/bash
set -e

# Deploy AWX to Kubernetes with MySQL backend
# This script installs the AWX Operator and deploys AWX with MySQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "${SCRIPT_DIR}/helpers/logging.sh"
source "${SCRIPT_DIR}/helpers/error-handling.sh"

log_info "Starting AWX deployment with MySQL backend"

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    log_error "kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Create namespace
log_info "Creating AWX namespace"
kubectl apply -f "${PROJECT_ROOT}/manifests/awx-namespace.yaml"

# Install AWX Operator using kustomize
log_info "Installing AWX Operator"
cd /tmp
if [ ! -d "awx-operator" ]; then
    git clone https://github.com/ansible/awx-operator.git
    cd awx-operator
    git checkout 2.19.1  # Latest stable as of Jan 2026
else
    cd awx-operator
    git pull
    git checkout 2.19.1
fi

# Deploy operator to awx namespace
export NAMESPACE=awx
make deploy

log_info "Waiting for AWX Operator to be ready"
kubectl wait --for=condition=available --timeout=300s deployment/awx-operator-controller-manager -n awx

# Deploy MySQL
log_info "Deploying MySQL database"
kubectl apply -f "${PROJECT_ROOT}/manifests/awx-mysql.yaml"

log_info "Waiting for MySQL to be ready"
kubectl wait --for=condition=ready --timeout=300s pod -l app=awx-mysql -n awx

# Create secrets
log_info "Creating AWX secrets"
kubectl apply -f "${PROJECT_ROOT}/manifests/awx-mysql-secret.yaml"
kubectl apply -f "${PROJECT_ROOT}/manifests/awx-admin-password.yaml"

# Deploy AWX instance
log_info "Deploying AWX instance"
kubectl apply -f "${PROJECT_ROOT}/manifests/awx-instance.yaml"

log_info "Waiting for AWX deployment (this may take 5-10 minutes)"
log_info "You can monitor progress with: kubectl logs -f deployment/awx-operator-controller-manager -n awx -c awx-manager"

# Wait for AWX to be ready
for i in {1..60}; do
    if kubectl get pods -n awx | grep -q "awx-web.*Running"; then
        log_success "AWX web pod is running"
        break
    fi
    echo -n "."
    sleep 10
done

echo ""
log_info "Checking AWX status"
kubectl get pods -n awx
kubectl get svc -n awx

# Get LoadBalancer IP
LOADBALANCER_IP=$(kubectl get svc -n awx -l app.kubernetes.io/name=awx-web-svc -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo ""
log_success "AWX deployment initiated!"
echo ""
echo "============================================"
echo "  AWX Kubernetes Deployment"
echo "============================================"
echo "Namespace:     awx"
echo "Admin User:    admin"
echo "Admin Pass:    changeme123"
echo "LoadBalancer:  ${LOADBALANCER_IP}"
echo ""
echo "Access AWX at: http://${LOADBALANCER_IP}"
echo "Or via DNS:    http://awx.home.lab (add to pfSense)"
echo ""
echo "Monitor deployment:"
echo "  kubectl logs -f deployment/awx-operator-controller-manager -n awx -c awx-manager"
echo "  kubectl get pods -n awx -w"
echo ""
echo "MySQL Database:"
echo "  Host: awx-mysql.awx.svc.cluster.local"
echo "  Database: awx"
echo "  User: awx"
echo "============================================"
