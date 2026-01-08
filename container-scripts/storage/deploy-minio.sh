#!/bin/bash
################################################################################
# Deploy MinIO S3-Compatible Object Storage
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/helpers/logging.sh"
source "$PROJECT_ROOT/scripts/helpers/ssh-utils.sh"

MASTER_IP="${1:-}"
USE_LOADBALANCER="${2:-false}"
STORAGE_SIZE="${3:-10Gi}"

if [[ -z "$MASTER_IP" ]]; then
    log_error "Usage: $0 <master-ip> [use-loadbalancer:true/false] [storage-size:10Gi]"
    exit 1
fi

log_info "Deploying MinIO (storage: $STORAGE_SIZE)..."

# Create namespace
ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl create namespace minio || true"

# Deploy MinIO
ssh_execute "$MASTER_IP" "cat <<'EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-data
  namespace: minio
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $STORAGE_SIZE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - :9001
        env:
        - name: MINIO_ROOT_USER
          value: minioadmin
        - name: MINIO_ROOT_PASSWORD
          value: minioadmin
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-data
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  type: $([ "$USE_LOADBALANCER" == "true" ] && echo "LoadBalancer" || echo "NodePort")
  selector:
    app: minio
  ports:
  - name: api
    port: 9000
    targetPort: 9000
    $([ "$USE_LOADBALANCER" != "true" ] && echo "nodePort: 30900")
---
apiVersion: v1
kind: Service
metadata:
  name: minio-console
  namespace: minio
spec:
  type: $([ "$USE_LOADBALANCER" == "true" ] && echo "LoadBalancer" || echo "NodePort")
  selector:
    app: minio
  ports:
  - name: console
    port: 9001
    targetPort: 9001
    $([ "$USE_LOADBALANCER" != "true" ] && echo "nodePort: 30901")
EOF"

log_info "Waiting for MinIO to be ready..."
sleep 10

for i in {1..60}; do
    if ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n minio | grep -q 'Running'"; then
        log_success "MinIO is running"
        break
    fi
    sleep 5
done

log_success "MinIO deployed successfully!"
log_info "Default credentials: minioadmin / minioadmin"
if [[ "$USE_LOADBALANCER" == "true" ]]; then
    log_info "Access via LoadBalancer IPs (check with: kubectl get svc -n minio)"
else
    log_info "API: http://<node-ip>:30900"
    log_info "Console: http://<node-ip>:30901"
fi
