#!/bin/bash
################################################################################
# Deploy Cert-Manager
# Automatic TLS certificate management
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/helpers/logging.sh"
source "$PROJECT_ROOT/scripts/helpers/ssh-utils.sh"

MASTER_IP="${1:-}"

if [[ -z "$MASTER_IP" ]]; then
    log_error "Usage: $0 <master-ip>"
    exit 1
fi

log_info "Deploying Cert-Manager..."

# Install cert-manager CRDs and deployment
ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml"

log_info "Waiting for cert-manager pods to be ready..."
sleep 15

# Wait for pods
for i in {1..60}; do
    if ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n cert-manager | grep -c 'Running'" | grep -q "3"; then
        log_success "Cert-manager pods are running"
        break
    fi
    sleep 5
done

# Create self-signed ClusterIssuer for lab use
log_info "Creating self-signed ClusterIssuer..."
ssh_execute "$MASTER_IP" "cat <<EOF | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF"

log_success "Cert-Manager deployed successfully!"
log_info "Use annotation: cert-manager.io/cluster-issuer: \"selfsigned-issuer\" on Ingress resources"
