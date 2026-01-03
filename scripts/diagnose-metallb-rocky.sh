#!/usr/bin/env bash
# Diagnose MetalLB issues on Rocky Linux

set -euo pipefail

MASTER_IP="${1:-192.168.1.206}"

echo "=== MetalLB Controller Logs ==="
ssh -o StrictHostKeyChecking=no "rswanson@${MASTER_IP}" \
  "sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl logs -n metallb-system -l app.kubernetes.io/component=controller --tail=50" || true

echo ""
echo "=== MetalLB Speaker Pod Description ==="
ssh -o StrictHostKeyChecking=no "rswanson@${MASTER_IP}" \
  "sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl describe pod -n metallb-system -l app.kubernetes.io/component=speaker | head -80" || true

echo ""
echo "=== MetalLB Controller Events ==="
ssh -o StrictHostKeyChecking=no "rswanson@${MASTER_IP}" \
  "sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl describe pod -n metallb-system -l app.kubernetes.io/component=controller | tail -30" || true

echo ""
echo "=== Firewalld Status on Master ==="
ssh -o StrictHostKeyChecking=no "rswanson@${MASTER_IP}" "sudo firewall-cmd --list-all" || true

echo ""
echo "=== Check if speaker needs host network access ==="
ssh -o StrictHostKeyChecking=no "rswanson@${MASTER_IP}" \
  "sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get daemonset -n metallb-system speaker -o yaml | grep -A5 'hostNetwork'" || true

echo ""
echo "=== SELinux denials for metallb ==="
ssh -o StrictHostKeyChecking=no "rswanson@${MASTER_IP}" \
  "sudo ausearch -m avc -ts recent | grep metallb || echo 'No SELinux denials found'"
