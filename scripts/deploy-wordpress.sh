#!/bin/bash
################################################################################
# Deploy WordPress using Helm
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../helm-charts/wordpress"

# Set kubeconfig
export KUBECONFIG="${KUBECONFIG:-$HOME/automated-kubernetes-lab-build/k8s-home-kubeconfig.yaml}"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
    echo "Error: Kubeconfig not found at $KUBECONFIG"
    echo "Please specify the cluster kubeconfig or run from the master node"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Parse arguments
RELEASE_NAME="${1:-wordpress}"
NAMESPACE="${2:-wordpress}"

echo "=================================================="
echo "Deploying WordPress"
echo "=================================================="
echo "Release Name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Install or upgrade
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --wait \
    --timeout 5m

echo ""
echo "=================================================="
echo "WordPress Deployment Complete!"
echo "=================================================="
echo ""

# Get service information
SERVICE_TYPE=$(kubectl get svc wordpress -n "$NAMESPACE" -o jsonpath='{.spec.type}')

if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo "Waiting for LoadBalancer IP..."
    for i in {1..30}; do
        LB_IP=$(kubectl get svc wordpress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$LB_IP" ]; then
            echo "WordPress URL: http://$LB_IP"
            break
        fi
        sleep 2
    done
    
    if [ -z "$LB_IP" ]; then
        echo "LoadBalancer IP not assigned yet. Check with: kubectl get svc -n $NAMESPACE"
    fi
else
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    NODE_PORT=$(kubectl get svc wordpress -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
    echo "WordPress URL: http://$NODE_IP:$NODE_PORT"
fi

echo ""
echo "To uninstall: helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
