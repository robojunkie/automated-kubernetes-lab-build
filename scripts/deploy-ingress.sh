#!/bin/bash
set -e

echo "=== Deploying Ingress Controller with Single LoadBalancer IP ==="

# Create configs directory if it doesn't exist
mkdir -p /home/rswanson/configs

# Install ingress-nginx with LoadBalancer at 192.168.1.50
echo "Installing nginx-ingress-controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=192.168.1.50 \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.ingressClassResource.default=true \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.extraArgs.enable-ssl-passthrough=true \
  --set-string "controller.service.annotations.io\.cilium/lb-ipam-ips"=192.168.1.50 \
  --set tcp.5000="registry/registry:5000" \
  --set tcp.9443="portainer/portainer:9443"

echo "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "Ingress controller deployed successfully!"
kubectl get svc -n ingress-nginx

echo ""
echo "=== Next Steps ==="
echo "1. Configure DNS or /etc/hosts:"
echo "   192.168.1.50  grafana.home.lab"
echo "   192.168.1.50  awx.home.lab"
echo "   192.168.1.50  wordpress.home.lab"
echo "   192.168.1.50  registry-ui.home.lab"
echo ""
echo "2. Access services:"
echo "   - Grafana:     http://grafana.home.lab"
echo "   - AWX:         http://awx.home.lab"
echo "   - WordPress:   http://wordpress.home.lab"
echo "   - Registry UI: http://registry-ui.home.lab"
echo "   - Portainer:   https://192.168.1.50:9443"
echo "   - Registry:    192.168.1.50:5000"
