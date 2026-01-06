#!/bin/bash

################################################################################
# Add-on Setup Module
# Installs and configures Kubernetes add-ons like CNI, ingress, monitoring, etc.
################################################################################

################################################################################
# Setup CNI (Container Network Interface) plugin
################################################################################
setup_cni() {
    local cni_plugin=$1
    local pod_cidr=$2
    local master_ip=$3
    
    log_info "Setting up CNI plugin: $cni_plugin"
    
    case "$cni_plugin" in
        calico)
            setup_calico "$pod_cidr" "$master_ip"
            ;;
        flannel)
            setup_flannel "$pod_cidr" "$master_ip"
            ;;
        weave)
            setup_weave "$master_ip"
            ;;
        *)
            log_error "Unsupported CNI plugin: $cni_plugin"
            return 1
            ;;
    esac
    
    log_success "CNI plugin configured: $cni_plugin"
}

################################################################################
# Setup default storage class (local-path provisioner)
################################################################################
setup_default_storage() {
  local master_ip=$1

  log_info "Setting up default storage class (local-path)..."

  ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

  # Make local-path the default storage class
  ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class='true' --overwrite"

  # Wait for controller pod ready
  ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=120s" 2>/dev/null || true

  log_success "Default storage class configured (local-path)"
}

################################################################################
# Setup Calico CNI
################################################################################
setup_calico() {
    local pod_cidr=$1
    local master_ip=$2
    
    log_debug "Installing Calico CNI..."
    
    # Detect OS family for encapsulation mode
    local os_family=$(detect_os_family "$master_ip")
    local encap_mode="VXLANCrossSubnet"
    local bgp_setting=""
    
    # Use simpler VXLAN-only mode for RHEL/Rocky to avoid BGP/BIRD firewall issues
    if [[ "$os_family" == "rhel" ]]; then
        encap_mode="VXLAN"
        bgp_setting="bgp: Disabled"
        log_debug "Using VXLAN-only mode for RHEL-family OS"
    else
        log_debug "Using VXLANCrossSubnet mode for Debian-family OS"
    fi
    
    # Execute kubectl on master node via SSH, using kubeadm kubeconfig
    # Use --server-side to avoid annotation size limits
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml"
    
    # Wait for operator to be ready
    sleep 10
    
    # Create Calico custom resource via SSH (with OS-specific settings)
    ssh_execute "$master_ip" "cat << 'CALICO_EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ${bgp_setting}
    ipPools:
    - blockSize: 26
      cidr: ${pod_cidr}
      encapsulation: ${encap_mode}
      natOutgoing: Enabled
      nodeSelector: all()
CALICO_EOF"
    
    log_success "Calico CNI configured"
}

################################################################################
# Setup Flannel CNI
################################################################################
setup_flannel() {
    local pod_cidr=$1
    local master_ip=$2
    
    log_debug "Installing Flannel CNI..."
    
    # Execute kubectl on master node via SSH
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
    
    log_success "Flannel CNI configured"
}

################################################################################
# Setup Weave CNI
################################################################################
setup_weave() {
    local master_ip=$1
    
    log_debug "Installing Weave CNI..."
    
    # Execute kubectl on master node via SSH
    ssh_execute "$master_ip" "bash -c 'KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f \"https://cloud.weave.works/k8s/net?k8s-version=\$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl version | base64 | tr -d \"\\n\")\"'"
    
    log_success "Weave CNI configured"
}

################################################################################
# Setup MetalLB for load balancing
################################################################################
setup_metallb() {
  local pool=$1
  local master_ip=$2
  local max_retries=5
  local retry_delay=10
  local pool_addresses="$pool"

  # Guard against using network/broadcast if a /24 network address is provided
  if [[ "$pool_addresses" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.0/24$ ]]; then
    local base="${BASH_REMATCH[1]}"
    pool_addresses="${base}.50-${base}.250"
    log_info "Adjusting MetalLB pool to avoid .0/.255: ${pool_addresses}"
  fi
    
    log_info "Setting up MetalLB for load balancing..."
    
    # Install MetalLB via master (kubectl available there)
    log_debug "Installing MetalLB operator..."
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml"
    
    # Create memberlist secret for speaker pods (generate random key on master node)
    log_debug "Creating memberlist secret..."
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey=\$(openssl rand -hex 64)"
    
    # Wait a few seconds for namespace and resources to settle
    sleep 5
    
    # Wait for MetalLB controller pod to be created
    log_debug "Waiting for MetalLB controller pod to be created..."
    ssh_execute "$master_ip" "for i in {1..60}; do
        pod_count=\$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -l app.kubernetes.io/name=metallb -l app.kubernetes.io/component=controller -n metallb-system --no-headers 2>/dev/null | wc -l)
        if [[ \$pod_count -gt 0 ]]; then
            echo \"Controller pod created\"
            break
        fi
        sleep 2
    done"
    
    # Now wait for it to be ready
    log_debug "Waiting for MetalLB controller pod to be ready..."
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=metallb -l app.kubernetes.io/component=controller -n metallb-system --timeout=300s" || {
        log_warning "Controller pod not ready within timeout, checking status..."
        ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n metallb-system -o wide"
        ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl describe pod -l app.kubernetes.io/component=controller -n metallb-system | tail -20"
    }
    
    # Wait for webhook service endpoints to be populated
    log_debug "Waiting for MetalLB webhook endpoints..."
    local endpoint_ip=""
    ssh_execute "$master_ip" "for i in {1..60}; do
        endpoint_ip=\$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get endpoints metallb-webhook-service -n metallb-system -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [[ -n \"\$endpoint_ip\" ]]; then
            echo \"Webhook endpoint ready: \$endpoint_ip\"
            break
        fi
        sleep 2
    done" 2>/dev/null || true
    
    # Wait for webhook to actually respond (TCP connectivity check)
    log_debug "Verifying webhook connectivity..."
    ssh_execute "$master_ip" "for i in {1..30}; do
        webhook_pod=\$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod -l app.kubernetes.io/component=controller -n metallb-system -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n \"\$webhook_pod\" ]]; then
            if KUBECONFIG=/etc/kubernetes/admin.conf kubectl exec -n metallb-system \$webhook_pod -- timeout 2 sh -c 'echo > /dev/tcp/localhost/9443' 2>/dev/null; then
                echo \"Webhook is accepting connections\"
                break
            fi
        fi
        sleep 3
    done" 2>/dev/null || true
    
    # Wait for service networking to fully settle and webhook to be reachable via service IP
    log_debug "Waiting for webhook service to be reachable..."
    sleep 30
    
    log_debug "Configuring MetalLB IP pool: ${pool_addresses}"
    local attempt=1
    while [[ $attempt -le $max_retries ]]; do
        if ssh_execute "$master_ip" "cat << EOF | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - ${pool_addresses}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF"; then
            log_success "MetalLB configured"
            return 0
        fi
        
        log_debug "MetalLB config failed (attempt $attempt/$max_retries). Retrying in ${retry_delay}s..."
        sleep "$retry_delay"
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to configure MetalLB after $max_retries attempts"
    return 1
}

    ################################################################################
    # Deploy Portainer (dashboard)
    ################################################################################
    setup_portainer() {
        local master_ip=$1
        local public_access=$2
        local nodeport_port=30777
        local max_attempts=30
        local delay=5
        local attempt=1

        log_info "Deploying Portainer UI..."

        # Base manifests (namespace, deployment with ephemeral storage)
        ssh_execute "$master_ip" "cat << 'EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: portainer
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portainer-sa
  namespace: portainer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: portainer-cluster-admin
subjects:
- kind: ServiceAccount
  name: portainer-sa
  namespace: portainer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portainer
  namespace: portainer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portainer
  template:
    metadata:
      labels:
        app: portainer
    spec:
      serviceAccountName: portainer-sa
      containers:
      - name: portainer
        image: portainer/portainer-ce:2.20.3
        imagePullPolicy: IfNotPresent
        args:
        - "--http-disabled"
        ports:
        - containerPort: 9443
          name: https
        - containerPort: 8000
          name: edge
        volumeMounts:
        - name: portainer-data
          mountPath: /data
      volumes:
      - name: portainer-data
        emptyDir: {}
EOF"

        # Service manifest depends on public access choice
        if [[ "$public_access" == "true" ]]; then
            ssh_execute "$master_ip" "cat << 'EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: portainer
  namespace: portainer
spec:
  type: LoadBalancer
  ports:
  - name: https
    port: 9443
    targetPort: 9443
  - name: edge
    port: 8000
    targetPort: 8000
  selector:
    app: portainer
EOF"
        else
            ssh_execute "$master_ip" "cat << 'EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: portainer
  namespace: portainer
spec:
  type: NodePort
  ports:
  - name: https
    port: 9443
    targetPort: 9443
    nodePort: ${nodeport_port}
  selector:
    app: portainer
EOF"
        fi

        # Wait for deployment ready
        ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl rollout status deployment/portainer -n portainer --timeout=300s" || true

        # Determine access URL
        if [[ "$public_access" == "true" ]]; then
            local external_ip=""
            while [[ $attempt -le $max_attempts ]]; do
                external_ip=$(ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get svc portainer -n portainer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null")
                if [[ -n "$external_ip" ]]; then
                    break
                fi
                log_debug "Waiting for Portainer LoadBalancer IP (attempt $attempt/$max_attempts)..."
                sleep "$delay"
                attempt=$((attempt + 1))
            done

            if [[ -n "$external_ip" ]]; then
                log_success "Portainer is available at: https://${external_ip}:9443"
                log_info "If DNS is used, point a record to ${external_ip}."
            else
                log_warning "Portainer LoadBalancer IP not assigned yet. Check service status with: kubectl get svc -n portainer"
            fi
        else
            log_success "Portainer is available via NodePort: https://${master_ip}:${nodeport_port}"
        fi
    }

################################################################################
# Setup NGINX Ingress Controller
################################################################################
setup_nginx_ingress() {
    log_info "Setting up NGINX Ingress Controller..."
    
    log_debug "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s 2>/dev/null || true
    
    log_success "NGINX Ingress Controller configured"
}

################################################################################
# Setup Prometheus for monitoring
################################################################################
setup_prometheus() {
    log_info "Setting up Prometheus monitoring..."
    
    # Add Prometheus Helm repo
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install Prometheus
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values - << EOF
prometheus:
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
grafana:
  adminPassword: admin
  persistence:
    enabled: true
    size: 10Gi
EOF
    
    log_success "Prometheus monitoring configured"
}

################################################################################
# Setup local storage provisioner
################################################################################
setup_local_storage() {
    log_info "Setting up local storage provisioner..."
    
    # Add OpenEBS Helm repo
    helm repo add openebs https://openebs.github.io/charts
    helm repo update
    
    # Install OpenEBS
    helm install openebs openebs/openebs \
        --namespace openebs \
        --create-namespace
    
    log_success "Local storage provisioner configured"
}

################################################################################
# Setup dashboard (Kubernetes Web UI)
################################################################################
setup_dashboard() {
    log_info "Setting up Kubernetes Dashboard..."
    
    log_debug "Installing Kubernetes Dashboard..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    
    # Create admin service account
    kubectl apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
    
    log_success "Kubernetes Dashboard configured"
}

################################################################################
# Install Helm if not present
################################################################################
ensure_helm_installed() {
    if ! command_exists helm; then
        log_info "Installing Helm..."
        
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        
        log_success "Helm installed successfully"
    else
        log_debug "Helm is already installed"
    fi
}
