#!/bin/bash

# GitLab deployment script for Kubernetes
# Deploys GitLab with PostgreSQL, Redis, and Gitaly
# NOTE: GitLab requires significant resources (4GB+ RAM recommended)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helper functions
source "$PROJECT_ROOT/scripts/helpers/logging.sh"
source "$PROJECT_ROOT/scripts/helpers/error-handling.sh"
source "$PROJECT_ROOT/scripts/helpers/ssh-utils.sh"

# Configuration
NAMESPACE="gitlab"
GITLAB_VERSION="7.7.0"  # Chart version
STORAGE_SIZE="${3:-30Gi}"  # Default 30Gi storage
USE_LOADBALANCER="${2:-false}"

usage() {
    echo "Usage: $0 <master-ip> [use-loadbalancer] [storage-size]"
    echo ""
    echo "Arguments:"
    echo "  master-ip         : IP address of the Kubernetes master node"
    echo "  use-loadbalancer  : Use LoadBalancer service type (true/false, default: false)"
    echo "  storage-size      : Storage size for GitLab data (default: 30Gi)"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.202                    # NodePort, 30Gi storage"
    echo "  $0 192.168.1.202 true               # LoadBalancer, 30Gi storage"
    echo "  $0 192.168.1.202 false 50Gi         # NodePort, 50Gi storage"
    echo ""
    echo "WARNING: GitLab requires significant resources:"
    echo "  - Minimum 4GB RAM recommended"
    echo "  - ~20-30Gi storage for PostgreSQL, Redis, Gitaly"
    echo "  - Consider using Gitea for a lighter alternative"
    exit 1
}

# Validate arguments
if [ $# -lt 1 ]; then
    log_error "Missing required argument: master-ip"
    usage
fi

MASTER_IP="$1"

# Validate master IP is reachable
if ! ping -c 1 -W 2 "$MASTER_IP" &>/dev/null; then
    log_error "Cannot reach master node at $MASTER_IP"
    exit 1
fi

log_info "Starting GitLab deployment to cluster at $MASTER_IP"
log_info "Storage size: $STORAGE_SIZE"
log_info "Service type: $([ "$USE_LOADBALANCER" = "true" ] && echo "LoadBalancer" || echo "NodePort")"

# Create namespace
log_info "Creating namespace: $NAMESPACE"
ssh_execute "$MASTER_IP" "kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -" || {
    log_error "Failed to create namespace"
    exit 1
}

# Check if Helm is available
log_info "Checking for Helm installation..."
if ssh_execute "$MASTER_IP" "command -v helm" &>/dev/null; then
    log_success "Helm is available, using Helm chart deployment"
    
    # Add GitLab Helm repository
    log_info "Adding GitLab Helm repository..."
    ssh_execute "$MASTER_IP" "helm repo add gitlab https://charts.gitlab.io/" || {
        log_error "Failed to add GitLab Helm repository"
        exit 1
    }
    
    ssh_execute "$MASTER_IP" "helm repo update" || {
        log_warning "Failed to update Helm repositories (continuing anyway)"
    }
    
    # Prepare Helm values
    SERVICE_TYPE=$([ "$USE_LOADBALANCER" = "true" ] && echo "LoadBalancer" || echo "NodePort")
    
    log_info "Installing GitLab via Helm chart (this may take 10-15 minutes)..."
    
    # Create minimal values file for GitLab
    ssh_execute "$MASTER_IP" "cat > /tmp/gitlab-values.yaml <<'EOF'
global:
  edition: ce
  hosts:
    domain: gitlab.local
  ingress:
    enabled: false
  
postgresql:
  install: true
  persistence:
    size: 8Gi
  
redis:
    install: true
    
gitlab:
  gitaly:
    persistence:
      size: ${STORAGE_SIZE}
  
  gitlab-shell:
    service:
      type: ${SERVICE_TYPE}
      
nginx-ingress:
  enabled: false

certmanager:
  install: false
EOF
" || {
        log_error "Failed to create GitLab values file"
        exit 1
    }
    
    # Install GitLab with Helm
    ssh_execute "$MASTER_IP" "helm upgrade --install gitlab gitlab/gitlab \
        --namespace $NAMESPACE \
        --version $GITLAB_VERSION \
        --values /tmp/gitlab-values.yaml \
        --timeout 20m \
        --wait" || {
        log_error "Failed to install GitLab via Helm"
        log_info "Checking pod status for debugging..."
        ssh_execute "$MASTER_IP" "kubectl get pods -n $NAMESPACE"
        exit 1
    }
    
    # Clean up values file
    ssh_execute "$MASTER_IP" "rm -f /tmp/gitlab-values.yaml"
    
else
    log_warning "Helm not found - GitLab requires Helm for installation"
    log_info "Installing Helm..."
    
    ssh_execute "$MASTER_IP" "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" || {
        log_error "Failed to install Helm"
        exit 1
    }
    
    log_success "Helm installed successfully"
    log_info "Please run this script again to deploy GitLab"
    exit 0
fi

# Wait for GitLab pods to be ready
log_info "Waiting for GitLab pods to be ready (this may take several minutes)..."
timeout=900  # 15 minutes
elapsed=0
interval=10

while [ $elapsed -lt $timeout ]; do
    ready_pods=$(ssh_execute "$MASTER_IP" "kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c Running || echo 0")
    total_pods=$(ssh_execute "$MASTER_IP" "kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo 0")
    
    if [ "$ready_pods" -gt 0 ] && [ "$ready_pods" -eq "$total_pods" ]; then
        log_success "All GitLab pods are running ($ready_pods/$total_pods)"
        break
    fi
    
    log_info "Pods ready: $ready_pods/$total_pods (waiting ${elapsed}s/${timeout}s)"
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
    log_warning "Timeout waiting for all pods to be ready"
    log_info "Current pod status:"
    ssh_execute "$MASTER_IP" "kubectl get pods -n $NAMESPACE"
    log_info "GitLab deployment may still be in progress. Check status with: kubectl get pods -n $NAMESPACE"
fi

# Get service information
log_info "Retrieving GitLab service information..."

WEBSERVICE_NAME=$(ssh_execute "$MASTER_IP" "kubectl get svc -n $NAMESPACE -o name | grep webservice | head -1 | cut -d/ -f2")

if [ -z "$WEBSERVICE_NAME" ]; then
    log_warning "Could not find GitLab webservice. Listing all services:"
    ssh_execute "$MASTER_IP" "kubectl get svc -n $NAMESPACE"
else
    if [ "$USE_LOADBALANCER" = "true" ]; then
        # Wait for LoadBalancer IP
        log_info "Waiting for LoadBalancer IP assignment..."
        timeout=120
        elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            EXTERNAL_IP=$(ssh_execute "$MASTER_IP" "kubectl get svc $WEBSERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo ''")
            
            if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "<pending>" ]; then
                log_success "GitLab LoadBalancer IP: $EXTERNAL_IP"
                log_info "Access GitLab at: http://$EXTERNAL_IP"
                break
            fi
            
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "<pending>" ]; then
            log_warning "LoadBalancer IP not assigned yet"
            log_info "Check status with: kubectl get svc $WEBSERVICE_NAME -n $NAMESPACE"
        fi
    else
        # NodePort service
        NODEPORT=$(ssh_execute "$MASTER_IP" "kubectl get svc $WEBSERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo ''")
        
        if [ -n "$NODEPORT" ]; then
            log_success "GitLab NodePort: $NODEPORT"
            log_info "Access GitLab at: http://$MASTER_IP:$NODEPORT"
        else
            log_warning "Could not retrieve NodePort"
            log_info "Check service with: kubectl get svc $WEBSERVICE_NAME -n $NAMESPACE"
        fi
    fi
fi

# Get root password
log_info "Retrieving initial root password..."
ROOT_PASSWORD=$(ssh_execute "$MASTER_IP" "kubectl get secret gitlab-gitlab-initial-root-password -n $NAMESPACE -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo ''")

if [ -n "$ROOT_PASSWORD" ]; then
    log_success "GitLab initial root password retrieved"
    log_info "Username: root"
    log_info "Password: $ROOT_PASSWORD"
    log_warning "Change this password immediately after first login!"
else
    log_warning "Could not retrieve initial root password"
    log_info "Check secret with: kubectl get secret gitlab-gitlab-initial-root-password -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d"
fi

# Display deployment summary
log_success "GitLab deployment completed!"
echo ""
echo "=============================="
echo "GitLab Deployment Summary"
echo "=============================="
echo "Namespace: $NAMESPACE"
echo "Storage: $STORAGE_SIZE"
echo ""
echo "Useful Commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get svc -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE <pod-name>"
echo ""
echo "Note: GitLab may take 5-10 minutes after pods are running to be fully operational"
echo "Monitor with: kubectl get pods -n $NAMESPACE -w"
echo ""
echo "For more information:"
echo "  https://docs.gitlab.com/charts/"
echo "=============================="
