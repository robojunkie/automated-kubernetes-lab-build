#!/bin/bash
# Deploy Rundeck to Kubernetes cluster

set -e

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/logging.sh"
source "${SCRIPT_DIR}/helpers/error-handling.sh"

setup_error_handling

RELEASE_NAME="${1:-rundeck}"
NAMESPACE="${2:-rundeck}"

# Function to detect kubeconfig
detect_kubeconfig() {
    if [ -f "$HOME/.kube/config" ]; then
        export KUBECONFIG="$HOME/.kube/config"
    elif [ -n "$KUBECONFIG" ]; then
        log_info "Using KUBECONFIG: $KUBECONFIG"
    else
        log_error "No kubeconfig found. Please set KUBECONFIG or create ~/.kube/config"
        exit 1
    fi
}

# Function to check if Helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        log_warning "Helm not found. Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    local helm_version=$(helm version --short 2>/dev/null || echo "unknown")
    log_info "Using Helm: $helm_version"
}

# Function to wait for deployment
wait_for_deployment() {
    log_info "Waiting for Rundeck deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/rundeck -n "$NAMESPACE" 2>/dev/null || {
        log_warning "Deployment taking longer than expected..."
        kubectl get pods -n "$NAMESPACE"
        log_info "Continuing to wait..."
        sleep 30
    }
}

# Function to get LoadBalancer IP
get_loadbalancer_ip() {
    log_info "Retrieving LoadBalancer IP..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local external_ip=$(kubectl get svc rundeck -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        
        if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
            echo "$external_ip"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 5
    done
    
    log_warning "LoadBalancer IP not assigned yet. Check MetalLB status."
    return 1
}

# Main deployment
main() {
    log_section "Rundeck Deployment"
    
    detect_kubeconfig
    check_helm
    
    log_info "Deploying Rundeck release: $RELEASE_NAME to namespace: $NAMESPACE"
    
    # Deploy Rundeck
    helm upgrade --install "$RELEASE_NAME" \
        "${SCRIPT_DIR}/../helm-charts/rundeck" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout 10m
    
    wait_for_deployment
    
    # Get access information
    local external_ip=$(get_loadbalancer_ip)
    local admin_user=$(helm get values "$RELEASE_NAME" -n "$NAMESPACE" -o json | grep -o '"adminUser":"[^"]*"' | cut -d'"' -f4)
    local admin_pass=$(helm get values "$RELEASE_NAME" -n "$NAMESPACE" -o json | grep -o '"adminPassword":"[^"]*"' | cut -d'"' -f4)
    
    log_section "Rundeck Deployment Complete!"
    echo ""
    log_success "✓ Rundeck is now running"
    echo ""
    echo "Access Information:"
    echo "  URL:      http://${external_ip}:4440"
    echo "  Username: ${admin_user}"
    echo "  Password: ${admin_pass}"
    echo ""
    echo "Next Steps:"
    echo "  1. Access Rundeck at the URL above"
    echo "  2. Log in with the admin credentials"
    echo "  3. Go to 'Projects' → Create a new project (e.g., 'Kubernetes')"
    echo "  4. Import jobs from: ${SCRIPT_DIR}/../helm-charts/rundeck/jobs.yaml"
    echo "     - Go to Jobs → Upload Definition → Select jobs.yaml"
    echo "  5. Configure a node source:"
    echo "     - Go to Project Settings → Edit Nodes"
    echo "     - Add 'Local Node' as the execution target"
    echo ""
    echo "Available Maintenance Jobs:"
    echo "  • Fix MetalLB LoadBalancers - Restart speaker pods"
    echo "  • Restart Service/Deployment - Rollout restart any deployment"
    echo "  • Backup Cluster Resources - Backup all resources to YAML"
    echo "  • Check Cluster Health - Comprehensive health check"
    echo "  • Scale Deployment - Change replica count"
    echo "  • List LoadBalancer Services - Show all LoadBalancer IPs"
    echo "  • List All Pods - View all pods across namespaces"
    echo "  • List PersistentVolumeClaims - View all PVCs"
    echo ""
    log_info "To uninstall: helm uninstall $RELEASE_NAME -n $NAMESPACE"
}

main "$@"
