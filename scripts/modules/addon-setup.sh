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
# Setup Calico CNI
################################################################################
setup_calico() {
    local pod_cidr=$1
    local master_ip=$2
    
    log_debug "Installing Calico CNI..."
    
    # Execute kubectl on master node via SSH, using kubeadm kubeconfig
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml"
    
    # Wait for operator to be ready
    sleep 10
    
    # Create Calico custom resource via SSH
    ssh_execute "$master_ip" "cat << 'CALICO_EOF' | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: ${pod_cidr}
      encapsulation: VXLANCrossSubnet
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
    local subnet=$1
    
    log_info "Setting up MetalLB for load balancing..."
    
    # Install MetalLB
    log_debug "Installing MetalLB operator..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=metallb -n metallb-system --timeout=300s 2>/dev/null || true
    
    # Configure MetalLB with IP address pool
    log_debug "Configuring MetalLB IP pool..."
    kubectl apply -f - << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - ${subnet}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF
    
    log_success "MetalLB configured"
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
