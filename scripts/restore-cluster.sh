#!/bin/bash

# Cluster Restore Script
# Restores Portainer and other resources after cluster rebuild
# Run this AFTER rebuilding your cluster with build-lab.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source helper functions
source "$SCRIPT_DIR/helpers/logging.sh"
source "$SCRIPT_DIR/helpers/error-handling.sh"

# Configuration
BACKUP_DIR=""
PORTAINER_ONLY=true
ALL_NAMESPACES=false

usage() {
    echo "Usage: $0 --backup-dir PATH [options]"
    echo ""
    echo "Required:"
    echo "  --backup-dir PATH    Directory containing backup files"
    echo ""
    echo "Options:"
    echo "  --portainer-only     Only restore Portainer (default)"
    echo "  --all-namespaces     Restore all backed up namespaces"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --backup-dir ./cluster-backup-20260108-143000"
    echo "  $0 --backup-dir /backups/k8s --all-namespaces"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-dir)
            BACKUP_DIR="$2"
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

# Validate backup directory
if [ -z "$BACKUP_DIR" ]; then
    log_error "Missing required argument: --backup-dir"
    usage
fi

if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster. Ensure cluster is running and kubeconfig is set."
    exit 1
fi

log_info "Starting cluster restore..."
log_info "Backup directory: $BACKUP_DIR"

# Display backup info
if [ -f "$BACKUP_DIR/backup-manifest.txt" ]; then
    echo ""
    echo "=============================="
    echo "Backup Information"
    echo "=============================="
    cat "$BACKUP_DIR/backup-manifest.txt"
    echo "=============================="
    echo ""
fi

# Confirm before proceeding
read -p "Proceed with restore? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    log_info "Restore cancelled by user"
    exit 0
fi

# Function to restore namespace resources
restore_namespace() {
    local namespace=$1
    local source_dir=$2
    
    log_info "Restoring namespace: $namespace"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - 2>&1 | grep -v "Warning" || true
    
    # Restore resources in order (some have dependencies)
    local resources=("configmaps" "secrets" "persistentvolumeclaims" "serviceaccounts" 
                     "roles" "rolebindings" "services" "deployments" "statefulsets" 
                     "daemonsets" "ingresses")
    
    for resource in "${resources[@]}"; do
        local file="$source_dir/$namespace/$resource.yaml"
        if [ -f "$file" ]; then
            log_info "  Restoring $resource..."
            
            # Filter out managed fields and status
            kubectl apply -f "$file" 2>&1 | grep -v "Warning" || \
                log_warning "  Some $resource may not have been restored (this is often normal)"
        fi
    done
}

# Function to restore PVC data
restore_pvc_data() {
    local namespace=$1
    local pvc_name=$2
    local backup_file="$BACKUP_DIR/pvcs/data/$pvc_name.tar.gz"
    
    if [ ! -f "$backup_file" ]; then
        log_warning "  No data backup found for PVC: $pvc_name"
        return 0
    fi
    
    log_info "  Restoring data for PVC: $pvc_name"
    
    # Wait for PVC to be bound
    log_info "    Waiting for PVC to be bound..."
    timeout=60
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        status=$(kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$status" = "Bound" ]; then
            log_success "    PVC is bound"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [ "$status" != "Bound" ]; then
        log_warning "    PVC not bound yet, skipping data restore for $pvc_name"
        return 1
    fi
    
    # Create restore job
    log_info "    Creating restore job..."
    cat <<EOF | kubectl apply -f - 2>&1 | grep -v "Warning" || true
apiVersion: batch/v1
kind: Job
metadata:
  name: restore-$pvc_name
  namespace: $namespace
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: restore
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "Restoring data to volume..."
          cd /data
          if [ -f /backup/$pvc_name.tar.gz ]; then
            tar xzf /backup/$pvc_name.tar.gz
            echo "Restore complete for $pvc_name"
            ls -lh /data/
          else
            echo "No backup file found"
          fi
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
          type: Directory
EOF
    
    # Wait for restore job
    log_info "    Waiting for restore job to complete..."
    timeout=180
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        status=$(kubectl get job "restore-$pvc_name" -n "$namespace" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
        if [ "$status" = "1" ]; then
            log_success "    Restore job completed for $pvc_name"
            kubectl delete job "restore-$pvc_name" -n "$namespace" 2>/dev/null || true
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    log_warning "    Restore job timed out for $pvc_name"
    kubectl delete job "restore-$pvc_name" -n "$namespace" 2>/dev/null || true
    return 1
}

# Restore MetalLB config first (if exists)
if [ -f "$BACKUP_DIR/configs/metallb-ipaddresspools.yaml" ]; then
    log_info "Restoring MetalLB configuration..."
    kubectl apply -f "$BACKUP_DIR/configs/metallb-ipaddresspools.yaml" 2>&1 | grep -v "Warning" || \
        log_warning "Could not restore MetalLB IPAddressPools"
fi

if [ -f "$BACKUP_DIR/configs/metallb-l2advertisements.yaml" ]; then
    kubectl apply -f "$BACKUP_DIR/configs/metallb-l2advertisements.yaml" 2>&1 | grep -v "Warning" || \
        log_warning "Could not restore MetalLB L2Advertisements"
fi

# Restore Portainer
if [ -d "$BACKUP_DIR/portainer/portainer" ]; then
    log_info "Restoring Portainer..."
    
    restore_namespace "portainer" "$BACKUP_DIR/portainer"
    
    # Wait for Portainer pods to be ready
    log_info "Waiting for Portainer pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=portainer -n portainer --timeout=300s 2>/dev/null || \
        log_warning "Portainer pods may not be ready yet"
    
    # Restore PVC data
    pvcs=$(kubectl get pvc -n portainer -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for pvc in $pvcs; do
        restore_pvc_data "portainer" "$pvc"
    done
    
    log_success "Portainer restore complete"
    
    # Get Portainer access info
    nodeport=$(kubectl get svc -n portainer portainer -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    if [ -n "$nodeport" ]; then
        master_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
        if [ -n "$master_ip" ]; then
            log_info "Access Portainer at: http://$master_ip:$nodeport"
        fi
    fi
else
    log_warning "No Portainer backup found in $BACKUP_DIR"
fi

# Restore all namespaces if requested
if [ "$ALL_NAMESPACES" = true ]; then
    log_info "Restoring all backed up namespaces..."
    
    if [ -d "$BACKUP_DIR/resources" ]; then
        for ns_dir in "$BACKUP_DIR/resources"/*; do
            if [ -d "$ns_dir" ]; then
                ns=$(basename "$ns_dir")
                log_info "Restoring namespace: $ns"
                restore_namespace "$ns" "$BACKUP_DIR/resources"
                
                # Restore PVCs
                pvcs=$(kubectl get pvc -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
                for pvc in $pvcs; do
                    restore_pvc_data "$ns" "$pvc"
                done
            fi
        done
    else
        log_info "No user namespace backups found"
    fi
fi

# Summary
log_success "Restore completed!"
echo ""
echo "=============================="
echo "Restore Summary"
echo "=============================="
echo "Restored from: $BACKUP_DIR"
echo "Portainer: $([ -d "$BACKUP_DIR/portainer/portainer" ] && echo "Restored" || echo "Not found")"
echo "User Namespaces: $([ "$ALL_NAMESPACES" = true ] && echo "Restored (all)" || echo "Skipped (Portainer only)")"
echo ""
echo "Next Steps:"
echo "1. Verify Portainer is accessible"
echo "2. Check restored resources: kubectl get all -A"
echo "3. Verify application data is intact"
echo "=============================="
echo ""
log_info "Restoration complete. Your cluster should now have your previous configuration."
