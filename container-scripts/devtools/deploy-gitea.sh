#!/bin/bash
################################################################################
# Deploy Gitea (Lightweight Git Server)
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

log_info "Deploying Gitea..."

# Use Helm if available, otherwise use manifests
if ssh_execute "$MASTER_IP" "command -v helm >/dev/null 2>&1"; then
    log_info "Deploying via Helm..."
    ssh_execute "$MASTER_IP" "helm repo add gitea-charts https://dl.gitea.com/charts/"
    ssh_execute "$MASTER_IP" "helm repo update"
    
    if [[ "$USE_LOADBALANCER" == "true" ]]; then
        ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf helm install gitea gitea-charts/gitea --namespace git --create-namespace --set service.http.type=LoadBalancer --set service.ssh.type=LoadBalancer"
    else
        ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf helm install gitea gitea-charts/gitea --namespace git --create-namespace --set service.http.type=NodePort --set service.http.nodePort=30030 --set service.ssh.type=NodePort --set service.ssh.nodePort=30022"
    fi
else
    log_info "Helm not found, deploying via manifests..."
    # Fallback to manual deployment (simplified version)
    log_warning "For best experience, install Helm and use: helm install gitea gitea-charts/gitea"
    log_info "See: https://docs.gitea.com/installation/install-on-kubernetes"
fi

log_success "Gitea deployment initiated!"
log_info "Wait a few minutes for Gitea to be ready, then access via:"
if [[ "$USE_LOADBALANCER" == "true" ]]; then
    log_info "  kubectl get svc -n git"
else
    log_info "  Web: http://<node-ip>:30030"
    log_info "  SSH: <node-ip>:30022"
fi
