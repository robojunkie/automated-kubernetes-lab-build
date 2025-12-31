#!/bin/bash

################################################################################
# Kubernetes Deployment Module
# Handles kubeadm initialization and cluster setup
################################################################################

################################################################################
# Install kubeadm, kubectl, and kubelet
################################################################################
install_kubernetes_binaries() {
    local node_ip=$1
    local k8s_version=$2
    
    log_debug "Installing Kubernetes binaries on: $node_ip (version: $k8s_version)"
    
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
    ssh_execute "$node_ip" "sudo apt-get update"
    
    # Install Kubernetes components
    ssh_execute "$node_ip" "sudo apt-get install -y kubelet kubeadm kubectl"
    
    # Hold packages at current version
    ssh_execute "$node_ip" "sudo apt-mark hold kubelet kubeadm kubectl"
}

################################################################################
# Ensure container runtime is ready
################################################################################
ensure_container_runtime_ready() {
    local node_ip=$1
    local max_attempts=30
    local delay=2
    local attempt=1

    log_info "Ensuring container runtime (containerd) is ready on: $node_ip"
    
    # Add Docker's repository for containerd
    ssh_execute "$node_ip" "sudo apt-get install -y ca-certificates curl gnupg lsb-release"
    ssh_execute "$node_ip" "sudo mkdir -p /etc/apt/keyrings"
    ssh_execute "$node_ip" "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
    ssh_execute "$node_ip" "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
    ssh_execute "$node_ip" "sudo apt-get update"
    
    # Install containerd
    ssh_execute "$node_ip" "sudo apt-get install -y containerd.io"
    
    # Create containerd config directory if needed
    ssh_execute "$node_ip" "sudo mkdir -p /etc/containerd"
    
    # Generate default containerd config if not exists
    ssh_execute "$node_ip" "test -f /etc/containerd/config.toml || sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null"
    
    # Enable and start containerd
    ssh_execute "$node_ip" "sudo systemctl enable containerd"
    ssh_execute "$node_ip" "sudo systemctl start containerd"
    
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
    
    # Enable and start kubelet
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
    local max_attempts=${2:-60}
    local delay=${3:-5}
    local attempt=1
    
    log_info "Waiting for node to be ready: $node_name"
    
    while [[ $attempt -le $max_attempts ]]; do
        local node_status=$(kubectl get node "$node_name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        
        if [[ "$node_status" == "True" ]]; then
            log_success "Node is ready: $node_name"
            return 0
        fi
        
        log_debug "Node not ready yet. Status: $node_status. Attempt $attempt/$max_attempts"
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    
    log_error "Node did not become ready within timeout: $node_name"
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
    
    # Get join token
    local join_token=$(get_join_token "$master_ip")
    
    if [[ -z "$join_token" ]]; then
        log_error "Failed to retrieve join token"
        return 1
    fi
    
    # Wait for master to be ready
    # Note: This requires kubectl to be configured properly
    wait_for_node_ready "$master_node"
    
    # Join worker nodes
    for i in "${!WORKER_NODES[@]}"; do
        join_worker_node "${WORKER_NODES[$i]}" "${WORKER_IPS[$i]}" "$join_token" "$k8s_version"
        wait_for_node_ready "${WORKER_NODES[$i]}"
    done
    
    log_success "Kubernetes cluster deployment completed"
}
