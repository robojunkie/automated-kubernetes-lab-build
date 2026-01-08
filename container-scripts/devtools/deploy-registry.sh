#!/bin/bash
################################################################################
# Deploy Container Registry (Docker Registry + Joxit UI)
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/scripts/helpers/logging.sh"
source "$PROJECT_ROOT/scripts/helpers/ssh-utils.sh"

MASTER_IP="${1:-}"
USE_LOADBALANCER="${2:-false}"
STORAGE_SIZE="${3:-20Gi}"

if [[ -z "$MASTER_IP" ]]; then
    log_error "Usage: $0 <master-ip> [use-loadbalancer:true/false] [storage-size:20Gi]"
    exit 1
fi

log_info "Deploying container registry (storage: $STORAGE_SIZE)..."

ssh_execute "$MASTER_IP" "cat <<'EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: registry
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: registry
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
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        env:
        - name: REGISTRY_STORAGE_DELETE_ENABLED
          value: \"true\"
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: data
          mountPath: /var/lib/registry
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: registry-data
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  type: $([ "$USE_LOADBALANCER" == "true" ] && echo "LoadBalancer" || echo "NodePort")
  selector:
    app: registry
  ports:
  - name: registry
    port: 5000
    targetPort: 5000
    $([ "$USE_LOADBALANCER" != "true" ] && echo "nodePort: 30500")
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-ui
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry-ui
  template:
    metadata:
      labels:
        app: registry-ui
    spec:
      containers:
      - name: ui
        image: joxit/docker-registry-ui:latest
        env:
        - name: REGISTRY_URL
          value: http://registry.registry.svc.cluster.local:5000
        - name: DELETE_IMAGES
          value: \"true\"
        - name: REGISTRY_TITLE
          value: \"Lab Container Registry\"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: registry-ui
  namespace: registry
spec:
  type: $([ "$USE_LOADBALANCER" == "true" ] && echo "LoadBalancer" || echo "NodePort")
  selector:
    app: registry-ui
  ports:
  - name: http
    port: 80
    targetPort: 80
    $([ "$USE_LOADBALANCER" != "true" ] && echo "nodePort: 30501")
EOF"

log_info "Waiting for registry to be ready..."
sleep 10

for i in {1..60}; do
    if ssh_execute "$MASTER_IP" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n registry | grep -c 'Running' | grep -q '2'"; then
        log_success "Registry is running"
        break
    fi
    sleep 5
done

log_success "Container registry deployed successfully!"
if [[ "$USE_LOADBALANCER" == "true" ]]; then
    log_info "Check IPs with: kubectl get svc -n registry"
else
    log_info "Registry API: http://<node-ip>:30500"
    log_info "Registry UI: http://<node-ip>:30501"
fi
log_info "Note: Configure insecure registry in Docker/containerd for HTTP access"
