#!/bin/bash

set -e

# Check if SSH key exists
SSH_KEY="${HOME}/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found at $SSH_KEY"
    exit 1
fi

# Base64 encode the SSH key
SSH_KEY_B64=$(cat "$SSH_KEY" | base64 -w 0 2>/dev/null || cat "$SSH_KEY" | base64)

# Create namespace
kubectl create namespace web-terminal --dry-run=client -o yaml | kubectl apply -f -

# Create secret with SSH key
kubectl create secret generic ssh-key \
    --from-file=id_ed25519="$SSH_KEY" \
    -n web-terminal \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy the terminal
kubectl apply -f manifests/kubectl-web-terminal.yaml

echo ""
echo "Waiting for terminal to be ready..."
kubectl wait --for=condition=ready pod -l app=kubectl-terminal -n web-terminal --timeout=60s

echo ""
echo "=============================================="
echo "Web Terminal Deployment Complete!"
echo "=============================================="
echo ""

# Get access info
SERVICE_TYPE=$(kubectl get svc kubectl-terminal -n web-terminal -o jsonpath='{.spec.type}')

if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
    echo "Waiting for LoadBalancer IP..."
    for i in {1..30}; do
        LB_IP=$(kubectl get svc kubectl-terminal -n web-terminal -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$LB_IP" ]; then
            echo "Access terminal at: http://$LB_IP:7681"
            echo ""
            echo "Add this to Portainer:"
            echo "  1. Go to Portainer Settings"
            echo "  2. Add External Link:"
            echo "     Name: kubectl Terminal"
            echo "     URL: http://$LB_IP:7681"
            break
        fi
        sleep 2
    done
else
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    NODE_PORT=$(kubectl get svc kubectl-terminal -n web-terminal -o jsonpath='{.spec.ports[0].nodePort}')
    echo "Access terminal at: http://$NODE_IP:$NODE_PORT"
    echo ""
    echo "Add this to Portainer:"
    echo "  1. Go to Portainer Settings"
    echo "  2. Add External Link:"
    echo "     Name: kubectl Terminal"
    echo "     URL: http://$NODE_IP:$NODE_PORT"
fi

echo ""
