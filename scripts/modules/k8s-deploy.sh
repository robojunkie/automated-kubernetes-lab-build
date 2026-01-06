#!/bin/bash

################################################################################
# Kubernetes Deployment Module
# Handles kubeadm initialization and cluster setup
################################################################################

################################################################################
# Detect OS family
################################################################################
detect_os_family() {
    local node_ip=$1
    
    # Check for OS release info
    local os_info=$(ssh_execute "$node_ip" "cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'")
    
    case "$os_info" in
        ubuntu|debian)
            echo "debian"
            ;;
        rocky|rhel|centos|almalinux)
            echo "rhel"
            ;;
        *)
            log_error "Unsupported OS: $os_info on $node_ip"
            exit 1
            ;;
    esac
}

################################################################################
# Install kubeadm, kubectl, and kubelet (Debian/Ubuntu)
################################################################################
install_kubernetes_binaries_debian() {
    local node_ip=$1
    local k8s_version=$2
    
    log_debug "Installing Kubernetes binaries (Debian) on: $node_ip (version: $k8s_version)"
    
    # Remove old Kubernetes repository if it exists
    ssh_execute "$node_ip" "sudo rm -f /etc/apt/sources.list.d/kubernetes.list"
    ssh_execute "$node_ip" "sudo rm -f /etc/apt/keyrings/kubernetes-archive-keyring.gpg"
    ssh_execute "$node_ip" "sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    
    # Ensure required packages are installed
    ssh_execute "$node_ip" "sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg"
    
    # Create keyrings directory if it doesn't exist
    ssh_execute "$node_ip" "sudo mkdir -p -m 755 /etc/apt/keyrings"
    
        # Download Kubernetes GPG key locally (avoids remote shell pitfalls) with mirror fallbacks
        local tmp_key="/tmp/k8s-key.asc"
        rm -f "$tmp_key"

        local key_url_base="core:/stable:/v${k8s_version}/deb/Release.key"
        local key_hosts=(pkgs.k8s.io pkgs.kubernetes.io packages.kubernetes.io)
        local key_downloaded=false

        for host in "${key_hosts[@]}"; do
            log_info "Attempting key download from https://${host}/${key_url_base}"
            if curl -4fsSL --retry 3 --retry-delay 1 -H "User-Agent: apt" "https://${host}/${key_url_base}" -o "$tmp_key"; then
                log_debug "Key download succeeded from ${host}"
                key_downloaded=true
                break
            else
                log_warning "Key download failed from ${host}; trying next mirror..."
            fi
        done

        if [[ "$key_downloaded" != true || ! -s "$tmp_key" ]]; then
            log_error "Unable to download Kubernetes apt key from any mirror"
            rm -f "$tmp_key"
            exit 1
        fi

        # Copy key to target node and convert
        scp_to_remote "$tmp_key" "$node_ip" "/tmp/k8s-key.asc"
        ssh_execute "$node_ip" "sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg /tmp/k8s-key.asc"
        ssh_execute "$node_ip" "sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
        ssh_execute "$node_ip" "rm -f /tmp/k8s-key.asc"
        rm -f "$tmp_key"

    # Add Kubernetes repository (primary host); mirror can be swapped manually if needed
    ssh_execute "$node_ip" "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
    
    # Update package list
    ssh_execute "$node_ip" "sudo apt-get update -o Acquire::ForceIPv4=true"
    
    # Install Kubernetes components
    ssh_execute "$node_ip" "sudo apt-get install -y kubelet kubeadm kubectl"
    
    # Hold packages at current version
    ssh_execute "$node_ip" "sudo apt-mark hold kubelet kubeadm kubectl"
}

################################################################################
# Install kubeadm, kubectl, and kubelet (RHEL/Rocky/AlmaLinux)
################################################################################
install_kubernetes_binaries_rhel() {
    local node_ip=$1
    local k8s_version=$2
    
    log_debug "Installing Kubernetes binaries (RHEL) on: $node_ip (version: $k8s_version)"
    
    # Remove old Kubernetes repository if it exists
    ssh_execute "$node_ip" "sudo rm -f /etc/yum.repos.d/kubernetes.repo"
    
    # Disable swap
    ssh_execute "$node_ip" "sudo swapoff -a"
    ssh_execute "$node_ip" "sudo sed -i '/ swap / s/^/#/' /etc/fstab 2>/dev/null || true"
    
    # Set SELinux to permissive mode
    ssh_execute "$node_ip" "sudo setenforce 0 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true"
    
    # Add Kubernetes repository
    ssh_execute "$node_ip" "cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF"
    
    # Install Kubernetes components
    ssh_execute "$node_ip" "sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes"
    
    # Enable and start kubelet
    ssh_execute "$node_ip" "sudo systemctl enable kubelet"
}

################################################################################
# Install kubeadm, kubectl, and kubelet (dispatch by OS)
################################################################################
install_kubernetes_binaries() {
    local node_ip=$1
    local k8s_version=$2
    local os_family=$(detect_os_family "$node_ip")
    
    case "$os_family" in
        debian)
            install_kubernetes_binaries_debian "$node_ip" "$k8s_version"
            ;;
        rhel)
            install_kubernetes_binaries_rhel "$node_ip" "$k8s_version"
            ;;
        *)
            log_error "Unsupported OS family: $os_family"
            exit 1
            ;;
    esac
}

################################################################################
# Ensure container runtime is ready (Debian/Ubuntu)
################################################################################
ensure_container_runtime_ready_debian() {
    local node_ip=$1
    local max_attempts=30
    local delay=2
    local attempt=1

    log_info "Ensuring container runtime (containerd) is ready on: $node_ip"
    
    # Add Docker's repository for containerd
    ssh_execute "$node_ip" "sudo apt-get install -y ca-certificates curl gnupg lsb-release"
    ssh_execute "$node_ip" "sudo mkdir -p /etc/apt/keyrings"
    # Download Docker GPG key non-interactively then dearmor
    ssh_execute "$node_ip" "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg"
    ssh_execute "$node_ip" "sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg /tmp/docker.gpg"
    ssh_execute "$node_ip" "sudo rm -f /tmp/docker.gpg"
    ssh_execute "$node_ip" "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
    ssh_execute "$node_ip" "sudo apt-get update -o Acquire::ForceIPv4=true"
    
    # Install containerd (Docker repo). Fallback to Ubuntu's containerd if Docker repo is unreachable.
    ssh_execute "$node_ip" "sudo apt-get install -y containerd.io || sudo apt-get install -y containerd"
    
    # Create containerd config directory if needed
    ssh_execute "$node_ip" "sudo mkdir -p /etc/containerd"
    
    # Write containerd config with CRI enabled and systemd cgroup driver
    ssh_execute "$node_ip" "sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null"
    ssh_execute "$node_ip" "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"
    
    # Enable and restart containerd to load new config
    ssh_execute "$node_ip" "sudo systemctl enable containerd"
    ssh_execute "$node_ip" "sudo systemctl daemon-reload"
    # Restart may return non-zero if already active; tolerate and verify via socket check
    ssh_execute "$node_ip" "sudo systemctl restart containerd || true"
    
    # Wait for containerd socket to be available
    while [[ $attempt -le $max_attempts ]]; do
        if ssh_execute "$node_ip" "test -S /var/run/containerd/containerd.sock" 2>/dev/null; then
            log_success "Container runtime is ready: $node_ip"
            return 0
        fi
        
        log_debug "Waiting for container runtime socket. Attempt $attempt/$max_attempts"
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    
    log_error "Container runtime failed to become ready within timeout: $node_ip"
    return 1
}

################################################################################
# Ensure container runtime is ready (RHEL/Rocky/AlmaLinux)
################################################################################
ensure_container_runtime_ready_rhel() {
    local node_ip=$1
    local max_attempts=30
    local delay=2
    local attempt=1

    log_info "Ensuring container runtime (containerd) is ready on: $node_ip"
    
    # Add Docker repo for containerd
    ssh_execute "$node_ip" "sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
    
    # Install containerd
    ssh_execute "$node_ip" "sudo dnf install -y containerd.io"
    
    # Create containerd config directory if needed
    ssh_execute "$node_ip" "sudo mkdir -p /etc/containerd"
    
    # Write containerd config with CRI enabled and systemd cgroup driver
    ssh_execute "$node_ip" "sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null"
    ssh_execute "$node_ip" "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"
    
    # Configure firewalld for Kubernetes
    ssh_execute "$node_ip" "sudo systemctl enable --now firewalld 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=6443/tcp 2>/dev/null || true"  # API server
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=2379-2380/tcp 2>/dev/null || true"  # etcd
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=10250-10252/tcp 2>/dev/null || true"  # kubelet, scheduler, controller
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=10255/tcp 2>/dev/null || true"  # read-only kubelet
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=30000-32767/tcp 2>/dev/null || true"  # NodePort range
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=179/tcp 2>/dev/null || true"  # BGP for Calico
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=4789/udp 2>/dev/null || true"  # VXLAN for Calico
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true"  # HTTPS for webhooks/services
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --add-port=9443/tcp 2>/dev/null || true"  # Webhook server port
    
    # Allow Calico/CNI pod network (10.244.0.0/16) and service network (10.96.0.0/12)
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/12 2>/dev/null || true"
    
    # Enable masquerading for NAT and allow forwarding
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=public --add-masquerade 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=trusted --add-masquerade 2>/dev/null || true"
    
    # Explicitly allow traffic to/from pod and service CIDRs in public zone (default interface zone)
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.244.0.0/16 accept' 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.96.0.0/12 accept' 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.244.0.0/16 accept' 2>/dev/null || true"
    ssh_execute "$node_ip" "sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.96.0.0/12 accept' 2>/dev/null || true"
    
    ssh_execute "$node_ip" "sudo firewall-cmd --reload 2>/dev/null || true"
    
    # Enable and restart containerd to load new config
    ssh_execute "$node_ip" "sudo systemctl enable containerd"
    ssh_execute "$node_ip" "sudo systemctl daemon-reload"
    ssh_execute "$node_ip" "sudo systemctl restart containerd || true"
    
    # Wait for containerd socket to be available
    while [[ $attempt -le $max_attempts ]]; do
        if ssh_execute "$node_ip" "test -S /var/run/containerd/containerd.sock" 2>/dev/null; then
            log_success "Container runtime is ready: $node_ip"
            return 0
        fi
        
        log_debug "Waiting for container runtime socket. Attempt $attempt/$max_attempts"
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    
    log_error "Container runtime failed to become ready within timeout: $node_ip"
    return 1
}

################################################################################
# Ensure container runtime is ready (dispatch by OS)
################################################################################
ensure_container_runtime_ready() {
    local node_ip=$1
    local os_family=$(detect_os_family "$node_ip")
    
    case "$os_family" in
        debian)
            ensure_container_runtime_ready_debian "$node_ip"
            ;;
        rhel)
            ensure_container_runtime_ready_rhel "$node_ip"
            ;;
        *)
            log_error "Unsupported OS family: $os_family"
            exit 1
            ;;
    esac
}

################################################################################
# Stop common conflicting services and free control-plane ports
################################################################################
stop_conflicting_services() {
    local node_ip=$1
    # Allow users to opt out by exporting STOP_CONFLICTING_SERVICES=false
    local stop_conflicting=${STOP_CONFLICTING_SERVICES:-true}

    if [[ "$stop_conflicting" != "true" ]]; then
        log_info "Skipping conflicting service shutdown on $node_ip (STOP_CONFLICTING_SERVICES=false)"
        return 0
    fi

    log_debug "Stopping conflicting services on $node_ip..."
    
    # All cleanup attempts are best-effort; swallow all errors to continue
    # Uninstall k3s if present
    ssh_execute "$node_ip" "if [ -x /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi; true" 2>/dev/null || true
    ssh_execute "$node_ip" "if [ -x /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi; true" 2>/dev/null || true
    
    # Stop services
    ssh_execute "$node_ip" "sudo systemctl stop kubelet k3s k3s-agent microk8s 2>/dev/null; true" 2>/dev/null || true
    ssh_execute "$node_ip" "sudo systemctl disable k3s k3s-agent microk8s 2>/dev/null; true" 2>/dev/null || true
    
    # Kill remaining processes
    ssh_execute "$node_ip" "sudo pkill -9 -f k3s 2>/dev/null; true" 2>/dev/null || true
    ssh_execute "$node_ip" "sudo pkill -9 -f kubelet 2>/dev/null; true" 2>/dev/null || true
    
    # Free ports
    ssh_execute "$node_ip" 'for port in 6443 10250 10257 10259; do sudo fuser -k $port/tcp 2>/dev/null || true; done; true' 2>/dev/null || true
    
    # Clean k3s directories
    ssh_execute "$node_ip" "sudo rm -rf /etc/rancher /var/lib/rancher /usr/local/bin/k3s* 2>/dev/null; true" 2>/dev/null || true

    log_debug "Conflicting service cleanup complete on $node_ip"
    return 0
}

################################################################################
# Initialize Kubernetes master node
################################################################################
initialize_master() {
    local master_node=$1
    local master_ip=$2
    local pod_cidr=$3
    local k8s_version=$4
    
    log_info "Initializing Kubernetes master: $master_node ($master_ip)"
    
    # Install Kubernetes binaries
    install_kubernetes_binaries "$master_ip" "$k8s_version"
    
    # Ensure container runtime is ready
    ensure_container_runtime_ready "$master_ip"
    
    # Reset any previous kubeadm state and ensure nothing else holds control-plane ports
    log_info "Cleaning up any previous Kubernetes state..."
    stop_conflicting_services "$master_ip"
    ssh_execute "$master_ip" "sudo systemctl stop kubelet 2>/dev/null; true" 2>/dev/null || true
    ssh_execute "$master_ip" "sudo systemctl reset-failed kubelet 2>/dev/null; true" 2>/dev/null || true
    ssh_execute "$master_ip" "sudo pkill -9 -f kubelet 2>/dev/null; true" 2>/dev/null || true
    # kubeadm reset will show warnings about failed pod cleanup if Calico is running - these are expected and harmless
    log_debug "Running kubeadm reset (may show Calico cleanup warnings - these are expected)..."
    ssh_execute "$master_ip" "sudo kubeadm reset -f 2>&1 | grep -v 'Failed to remove containers\\|plugin type=.*calico.*failed\\|error getting ClusterInformation' || true"
    ssh_execute "$master_ip" "sudo rm -rf /etc/cni/net.d/* /var/lib/etcd/* ~/.kube || true"
    
    # Enable kubelet (start will be handled by kubeadm init)
    ssh_execute "$master_ip" "sudo systemctl enable kubelet"
    
    # Initialize kubeadm
    log_debug "Running kubeadm init on master..."
    ssh_execute "$master_ip" "sudo kubeadm init \
        --apiserver-advertise-address=$master_ip \
        --pod-network-cidr=$pod_cidr \
        --ignore-preflight-errors=all"
    
    # Setup kubeconfig for root and default user
    log_debug "Setting up kubeconfig on master..."
    ssh_execute "$master_ip" "mkdir -p \$HOME/.kube"
    ssh_execute "$master_ip" "sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config 2>/dev/null || sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config"
    ssh_execute "$master_ip" "sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
    
    # Make admin.conf readable by the SSH user for kubectl commands
    ssh_execute "$master_ip" "sudo chmod 644 /etc/kubernetes/admin.conf"
    
    log_success "Master node initialized: $master_node"
}

################################################################################
# Get kubeadm join token
################################################################################
get_join_token() {
    local master_ip=$1
    
    log_debug "Retrieving kubeadm join token from master..."
    
    local join_cmd=$(ssh_execute "$master_ip" "sudo kubeadm token create --print-join-command")
    
    echo "$join_cmd"
}

################################################################################
# Join worker node to cluster
################################################################################
join_worker_node() {
    local worker_node=$1
    local worker_ip=$2
    local join_cmd=$3
    local k8s_version=$4
    
    log_info "Joining worker node: $worker_node ($worker_ip)"
    
    # Clean up any previous state on worker (k3s, previous kubelet, etc.)
    stop_conflicting_services "$worker_ip"
    ssh_execute "$worker_ip" "sudo systemctl stop kubelet 2>/dev/null; true" 2>/dev/null || true
    ssh_execute "$worker_ip" "sudo systemctl reset-failed kubelet 2>/dev/null; true" 2>/dev/null || true
    ssh_execute "$worker_ip" "sudo pkill -9 -f kubelet 2>/dev/null; true" 2>/dev/null || true
    # Remove prior kubeadm/kubelet state if present (avoids FileAvailable preflight errors)
    ssh_execute "$worker_ip" "sudo kubeadm reset -f 2>/dev/null || true"
    ssh_execute "$worker_ip" "sudo rm -rf /etc/kubernetes /var/lib/kubelet /etc/cni/net.d 2>/dev/null || true"
    
    # Install Kubernetes binaries
    install_kubernetes_binaries "$worker_ip" "$k8s_version"
    
    # Ensure container runtime is ready
    ensure_container_runtime_ready "$worker_ip"
    
    # Enable and start kubelet
    ssh_execute "$worker_ip" "sudo systemctl enable kubelet"
    
    # Execute join command
    log_debug "Running kubeadm join on worker..."
    ssh_execute "$worker_ip" "sudo $join_cmd"
    
    log_success "Worker node joined: $worker_node"
}

################################################################################
# Wait for node to be ready
################################################################################
wait_for_node_ready() {
    local node_name=$1
    local master_ip=$2
    local max_attempts=${3:-60}
    local delay=${4:-5}
    local attempt=1
    
    log_info "Waiting for node to be ready: $node_name"
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Checking node status (attempt $attempt/$max_attempts)..."
        # Simpler approach: just grep for Ready in output to avoid jsonpath quoting issues
        if ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get node $node_name 2>/dev/null | grep -q ' Ready '"; then
            log_success "Node is ready: $node_name"
            return 0
        fi
        
        log_debug "Node not ready yet. Waiting..."
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    
    log_error "Node did not become ready within timeout: $node_name"
    log_info "Dumping node info for debugging..."
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide" || true
    ssh_execute "$master_ip" "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -A" || true
    return 1
}

################################################################################
# Deploy Kubernetes cluster
################################################################################
deploy_kubernetes() {
    local master_node=$1
    local master_ip=$2
    local k8s_version=$3
    
    log_info "Deploying Kubernetes cluster..."
    
    # Initialize master
    initialize_master "$master_node" "$master_ip" "10.244.0.0/16" "$k8s_version"
    
    # Setup CNI (Calico by default)
    log_info "Deploying CNI plugin..."
    setup_cni "${CNI_PLUGIN:-calico}" "10.244.0.0/16" "$master_ip"
    
    # Wait for master to be ready (with CNI deployed)
    wait_for_node_ready "$master_node" "$master_ip" 120 10
    
    # Get join token
    local join_token=$(get_join_token "$master_ip")
    
    if [[ -z "$join_token" ]]; then
        log_error "Failed to retrieve join token"
        return 1
    fi
    
    # Join worker nodes
    for i in "${!WORKER_NODES[@]}"; do
        join_worker_node "${WORKER_NODES[$i]}" "${WORKER_IPS[$i]}" "$join_token" "$k8s_version"
        wait_for_node_ready "${WORKER_NODES[$i]}" "$master_ip" 120 10
    done
    
    log_success "Kubernetes cluster deployment completed"
}
