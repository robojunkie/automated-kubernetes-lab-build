#!/bin/bash
# Deploy MetalLB Watchdog

set -e

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers/logging.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/helpers/error-handling.sh" 2>/dev/null || true

if [ "$(type -t setup_error_handling)" == "function" ]; then
    setup_error_handling
fi

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_section() {
    echo ""
    echo "======================================"
    echo "$1"
    echo "======================================"
}

# Function to detect kubeconfig
detect_kubeconfig() {
    if [ -f "$HOME/.kube/config" ]; then
        export KUBECONFIG="$HOME/.kube/config"
    elif [ -n "$KUBECONFIG" ]; then
        log_info "Using KUBECONFIG: $KUBECONFIG"
    else
        log_info "No kubeconfig found. Please set KUBECONFIG or create ~/.kube/config"
        exit 1
    fi
}

# Main deployment
main() {
    log_section "MetalLB Watchdog Deployment"
    
    detect_kubeconfig
    
    log_info "Deploying MetalLB Watchdog DaemonSet..."
    
    kubectl apply -f "${SCRIPT_DIR}/../manifests/metallb-watchdog.yaml"
    
    log_info "Waiting for watchdog pods to start..."
    sleep 10
    
    kubectl wait --for=condition=ready pod -n metallb-watchdog -l app=metallb-watchdog --timeout=60s || true
    
    log_section "MetalLB Watchdog Deployed!"
    echo ""
    log_success "✓ Watchdog is now monitoring LoadBalancer services"
    echo ""
    echo "The watchdog will:"
    echo "  • Check LoadBalancer connectivity every 60 seconds"
    echo "  • Restart MetalLB speakers if 3 consecutive failures detected"
    echo "  • Cooldown period: 5 minutes between restarts"
    echo "  • Runs on every node for redundancy"
    echo ""
    echo "View watchdog logs:"
    echo "  kubectl logs -n metallb-watchdog -l app=metallb-watchdog -f"
    echo ""
    echo "Check watchdog status:"
    echo "  kubectl get pods -n metallb-watchdog"
    echo ""
    echo "Uninstall:"
    echo "  kubectl delete -f ${SCRIPT_DIR}/../manifests/metallb-watchdog.yaml"
}

main "$@"
