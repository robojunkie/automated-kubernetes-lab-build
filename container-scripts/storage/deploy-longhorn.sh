#!/bin/bash
################################################################################
# Deploy Longhorn Distributed Storage
# Replicated block storage with snapshots and backups
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/helpers/logging.sh"
source "$PROJECT_ROOT/scripts/helpers/ssh-utils.sh"
source "$PROJECT_ROOT/scripts/modules/k8s-deploy.sh"

MASTER_IP="${1:-}"
USE_LOADBALANCER="${2:-false}"

if [[ -z "$MASTER_IP" ]]; then
    log_error "Usage: $0 <master-ip> [use-loadbalancer:true/false]"
    log_error "Example: $0 192.168.1.202 false"
    exit 1
fi

log_info "Deploying Longhorn distributed storage..."

# Get all node IPs from cluster
NODE_IPS=($(ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type==\"InternalIP\")].address}'"))

log_info "Installing iSCSI prerequisites on all nodes..."
for node_ip in "${NODE_IPS[@]}"; do
    local os_family=$(detect_os_family "$node_ip")
    log_info "  Installing on $node_ip ($os_family)..."
    
    if [[ "$os_family" == "debian" ]]; then
        ssh_execute "$node_ip" "sudo apt-get update && sudo apt-get install -y open-iscsi nfs-common"
        ssh_execute "$node_ip" "sudo systemctl enable --now iscsid"
    elif [[ "$os_family" == "rhel" ]]; then
        ssh_execute "$node_ip" "sudo dnf install -y iscsi-initiator-utils nfs-utils"
        ssh_execute "$node_ip" "sudo systemctl enable --now iscsid"
    fi
done

# Deploy Longhorn
log_info "Deploying Longhorn components..."
ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.0/deploy/longhorn.yaml"

log_info "Waiting for Longhorn pods to be ready (this may take 2-3 minutes)..."
sleep 30

# Wait for Longhorn to be ready
for i in {1..120}; do
    READY_COUNT=$(ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n longhorn-system | grep -c 'Running' || echo 0")
    if [[ "$READY_COUNT" -ge 10 ]]; then
        log_success "Longhorn is running"
        break
    fi
    sleep 5
done

# Expose Longhorn UI
log_info "Configuring Longhorn UI access..."
if [[ "$USE_LOADBALANCER" == "true" ]]; then
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch svc longhorn-frontend -n longhorn-system -p '{\"spec\":{\"type\":\"LoadBalancer\"}}'"
    log_info "Longhorn UI will be available on LoadBalancer IP (check with: kubectl get svc -n longhorn-system)"
else
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch svc longhorn-frontend -n longhorn-system -p '{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"port\":80,\"nodePort\":30800,\"targetPort\":8000}]}}'"
    log_success "Longhorn UI available at: http://<node-ip>:30800"
fi

# Set Longhorn as default storage class (optional)
read -r -p "Set Longhorn as default storage class? (yes/no) [default: no]: " SET_DEFAULT
if [[ "$SET_DEFAULT" =~ ^(yes|y)$ ]]; then
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch storageclass local-path -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"false\"}}}'"
    ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl patch storageclass longhorn -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
    log_success "Longhorn is now the default storage class"
fi

log_success "Longhorn deployed successfully!"
