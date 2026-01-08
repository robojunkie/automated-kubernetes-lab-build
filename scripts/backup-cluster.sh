#!/bin/bash

# Cluster Backup Script
# Backs up Portainer data, deployed resources, and cluster configuration
# Run this BEFORE rebuilding your cluster to preserve your work

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source helper functions
source "$SCRIPT_DIR/helpers/logging.sh"
source "$SCRIPT_DIR/helpers/error-handling.sh"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/cluster-backup-$(date +%Y%m%d-%H%M%S)}"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --backup-dir PATH    Directory for backup files (default: ./cluster-backup-TIMESTAMP)"
    echo "  --kubeconfig PATH    Path to kubeconfig file (default: ~/.kube/config)"
    echo "  --portainer-only     Only backup Portainer (faster)"
    echo "  --all-namespaces     Backup all namespaces (default: only portainer)"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Backup Portainer only"
    echo "  $0 --all-namespaces             # Backup everything"
    echo "  $0 --backup-dir /backups/k8s    # Custom backup location"
    exit 1
}

# Parse arguments
PORTAINER_ONLY=true
ALL_NAMESPACES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --kubeconfig)
            KUBECONFIG_FILE="$2"
            shift 2
            ;;
        --portainer-only)
            PORTAINER_ONLY=true
            ALL_NAMESPACES=false
            shift
            ;;
        --all-namespaces)
            ALL_NAMESPACES=true
            PORTAINER_ONLY=false
            shift
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi

log_info "Starting cluster backup..."
log_info "Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"/{portainer,resources,pvcs,configs}

# Save cluster info
log_info "Saving cluster information..."
kubectl cluster-info > "$BACKUP_DIR/cluster-info.txt" 2>&1 || true
kubectl version > "$BACKUP_DIR/kubectl-version.txt" 2>&1 || true
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt" 2>&1 || true

# Backup kubeconfig
log_info "Backing up kubeconfig..."
cp "$KUBECONFIG_FILE" "$BACKUP_DIR/configs/kubeconfig.yaml" 2>&1 || \
    log_warning "Could not backup kubeconfig from $KUBECONFIG_FILE"

# Function to backup namespace resources
backup_namespace() {
    local namespace=$1
    local output_dir=$2
    
    log_info "Backing up namespace: $namespace"
    mkdir -p "$output_dir/$namespace"
    
    # Backup all resources in namespace
    for resource in deployments statefulsets daemonsets services configmaps secrets \
                    persistentvolumeclaims ingresses serviceaccounts roles rolebindings; do
        
        log_info "  Backing up $resource in $namespace..."
        kubectl get $resource -n "$namespace" -o yaml > "$output_dir/$namespace/$resource.yaml" 2>/dev/null || \
            log_info "  No $resource found in $namespace"
    done
}

# Function to backup PVC data (export volume info)
backup_pvcs() {
    local namespace=$1
    
    log_info "Exporting PVC information for namespace: $namespace"
    
    # Get all PVCs in namespace
    pvcs=$(kubectl get pvc -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$pvcs" ]; then
        for pvc in $pvcs; do
            log_info "  Backing up PVC: $pvc"
            
            # Save PVC manifest
            kubectl get pvc "$pvc" -n "$namespace" -o yaml > "$BACKUP_DIR/pvcs/$namespace-$pvc.yaml" 2>/dev/null
            
            # Save PV info (for reference)
            pv=$(kubectl get pvc "$pvc" -n "$namespace" -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "")
            if [ -n "$pv" ]; then
                kubectl get pv "$pv" -o yaml > "$BACKUP_DIR/pvcs/$namespace-$pvc-pv.yaml" 2>/dev/null || true
            fi
            
            # Create a backup job to export data (if local-path or similar)
            create_pvc_backup_job "$namespace" "$pvc"
        done
    else
        log_info "  No PVCs found in $namespace"
    fi
}

# Function to create a backup job for PVC data
create_pvc_backup_job() {
    local namespace=$1
    local pvc_name=$2
    
    log_info "    Creating backup job for PVC: $pvc_name"
    
    # Create backup job that tars the volume
    cat <<EOF | kubectl apply -f - 2>&1 | grep -v "Warning" || true
apiVersion: batch/v1
kind: Job
metadata:
  name: backup-$pvc_name
  namespace: $namespace
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: backup
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "Creating tarball of volume data..."
          cd /data
          tar czf /backup/$pvc_name.tar.gz . 2>/dev/null || echo "No data to backup"
          echo "Backup complete for $pvc_name"
          ls -lh /backup/
        volumeMounts:
        - name: data
          mountPath: /data
        - name: backup
          mountPath: /backup
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: $pvc_name
      - name: backup
        hostPath:
          path: $BACKUP_DIR/pvcs/data
          type: DirectoryOrCreate
EOF
    
    # Wait for job to complete (with timeout)
    log_info "    Waiting for backup job to complete..."
    timeout=180
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        status=$(kubectl get job "backup-$pvc_name" -n "$namespace" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
        if [ "$status" = "1" ]; then
            log_success "    Backup job completed for $pvc_name"
            kubectl delete job "backup-$pvc_name" -n "$namespace" 2>/dev/null || true
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    log_warning "    Backup job timed out for $pvc_name (data may not be backed up)"
    kubectl delete job "backup-$pvc_name" -n "$namespace" 2>/dev/null || true
}

# Backup Portainer
if kubectl get namespace portainer &> /dev/null; then
    log_info "Backing up Portainer..."
    backup_namespace "portainer" "$BACKUP_DIR/portainer"
    backup_pvcs "portainer"
    log_success "Portainer backup complete"
else
    log_warning "Portainer namespace not found"
fi

# Backup all namespaces if requested
if [ "$ALL_NAMESPACES" = true ]; then
    log_info "Backing up all user namespaces..."
    
    # Get all namespaces except system ones
    namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | \
                 grep -vE '^(kube-system|kube-public|kube-node-lease|calico-system|metallb-system|portainer)$' || echo "")
    
    if [ -n "$namespaces" ]; then
        for ns in $namespaces; do
            backup_namespace "$ns" "$BACKUP_DIR/resources"
            backup_pvcs "$ns"
        done
    else
        log_info "No user namespaces found to backup"
    fi
fi

# Backup MetalLB config (if exists)
if kubectl get namespace metallb-system &> /dev/null; then
    log_info "Backing up MetalLB configuration..."
    kubectl get ipaddresspools -n metallb-system -o yaml > "$BACKUP_DIR/configs/metallb-ipaddresspools.yaml" 2>/dev/null || true
    kubectl get l2advertisements -n metallb-system -o yaml > "$BACKUP_DIR/configs/metallb-l2advertisements.yaml" 2>/dev/null || true
fi

# Create backup manifest
log_info "Creating backup manifest..."
cat > "$BACKUP_DIR/backup-manifest.txt" <<EOF
Kubernetes Cluster Backup
Created: $(date)
Cluster: $(kubectl config current-context 2>/dev/null || echo "unknown")

Backed Up:
- Cluster Info: $([ -f "$BACKUP_DIR/cluster-info.txt" ] && echo "Yes" || echo "No")
- Kubeconfig: $([ -f "$BACKUP_DIR/configs/kubeconfig.yaml" ] && echo "Yes" || echo "No")
- Portainer: $([ -d "$BACKUP_DIR/portainer/portainer" ] && echo "Yes" || echo "No")
- MetalLB Config: $([ -f "$BACKUP_DIR/configs/metallb-ipaddresspools.yaml" ] && echo "Yes" || echo "No")
- User Namespaces: $([ "$ALL_NAMESPACES" = true ] && echo "Yes (all)" || echo "No (Portainer only)")

Backup Location: $BACKUP_DIR

To restore after cluster rebuild:
  ./scripts/restore-cluster.sh --backup-dir $BACKUP_DIR
EOF

# Create restore script reference
cat > "$BACKUP_DIR/HOW_TO_RESTORE.txt" <<EOF
How to Restore This Backup
===========================

After rebuilding your Kubernetes cluster:

1. Ensure your new cluster is running and accessible
   kubectl cluster-info

2. Run the restore script:
   cd $PROJECT_ROOT
   ./scripts/restore-cluster.sh --backup-dir $BACKUP_DIR

3. Wait for restoration to complete

4. Verify Portainer is accessible:
   kubectl get pods -n portainer

Options:
  --portainer-only    Restore only Portainer (faster)
  --all-namespaces    Restore all backed up namespaces

See scripts/restore-cluster.sh --help for more options.
EOF

# Summary
log_success "Backup completed successfully!"
echo ""
echo "=============================="
echo "Backup Summary"
echo "=============================="
cat "$BACKUP_DIR/backup-manifest.txt"
echo "=============================="
echo ""
log_info "Backup saved to: $BACKUP_DIR"
log_info "To restore: ./scripts/restore-cluster.sh --backup-dir $BACKUP_DIR"
echo ""
log_warning "IMPORTANT: Test your restore process before relying on it!"
