#!/bin/bash
################################################################################
# Migrate from Calico + MetalLB to Cilium
# This script will replace the CNI and remove MetalLB
# Expected downtime: 15-20 minutes
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================="
echo "  Cilium CNI Migration"
echo "=================================="
echo ""
echo "This will:"
echo "  1. Remove MetalLB"
echo "  2. Remove Calico CNI"
echo "  3. Install Cilium with LoadBalancer support"
echo "  4. All pods will restart"
echo ""
echo "Expected downtime: 15-20 minutes"
echo ""
read -p "Continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "=== Step 1: Backing up current LoadBalancer services ==="
mkdir -p /tmp/k8s-backup-$(date +%Y%m%d-%H%M)
kubectl get svc -A -o yaml > /tmp/k8s-backup-$(date +%Y%m%d-%H%M)/services.yaml
kubectl get pods -A -o yaml > /tmp/k8s-backup-$(date +%Y%m%d-%H%M)/pods.yaml
echo "Backup saved to /tmp/k8s-backup-$(date +%Y%m%d-%H%M)/"

echo ""
echo "=== Step 2: Removing MetalLB ==="
kubectl delete namespace metallb-system --ignore-not-found=true
kubectl delete namespace metallb-watchdog --ignore-not-found=true

echo ""
echo "=== Step 3: Removing Calico ==="
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml --ignore-not-found=true || true
kubectl delete daemonset -n kube-system calico-node --ignore-not-found=true
kubectl delete deployment -n kube-system calico-kube-controllers --ignore-not-found=true

echo ""
echo "=== Step 4: Installing Cilium CLI ==="
if ! command -v cilium &> /dev/null; then
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
fi

echo ""
echo "=== Step 5: Installing Cilium via Helm ==="
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --version 1.16.5 \
  --namespace kube-system \
  -f "${PROJECT_ROOT}/configs/cilium-values.yaml"

echo ""
echo "=== Step 6: Waiting for Cilium to be ready ==="
echo "This may take 5-10 minutes..."
cilium status --wait --wait-duration=10m

echo ""
echo "=== Step 7: Applying LoadBalancer IP Pool ==="
kubectl apply -f "${PROJECT_ROOT}/manifests/cilium-lb-ippool.yaml"

echo ""
echo "=== Step 8: Restarting all pods to pick up new CNI ==="
# Restart all pods except kube-system
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v kube-system); do
    echo "Restarting pods in namespace: $ns"
    kubectl delete pods --all -n $ns --grace-period=30 || true
done

echo ""
echo "=== Step 9: Waiting for pods to restart ==="
sleep 30

echo ""
echo "=== Step 10: Validating cluster connectivity ==="
cilium connectivity test --test-concurrency 1 --all-flows || echo "Some connectivity tests failed - this may be normal"

echo ""
echo "=== Step 11: Checking LoadBalancer services ==="
kubectl get svc -A --field-selector spec.type=LoadBalancer

echo ""
echo "=================================="
echo "  Migration Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Verify LoadBalancer IPs are assigned"
echo "  2. Test service connectivity"
echo "  3. Check Hubble UI: kubectl port-forward -n kube-system svc/hubble-ui 12000:80"
echo "  4. View Cilium status: cilium status"
echo ""
echo "If services don't have EXTERNAL-IP assigned:"
echo "  kubectl get ciliumloadbalancerippool"
echo "  kubectl get ciliuml2announcementpolicy"
echo ""
