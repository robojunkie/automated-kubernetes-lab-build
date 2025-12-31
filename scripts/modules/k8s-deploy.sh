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
    
    # Create keyrings directory if it doesn't exist
    ssh_execute "$node_ip" "sudo mkdir -p /etc/apt/keyrings"
    
    # Download Kubernetes GPG key (new repository location)
    ssh_execute "$node_ip" "curl -fsSL https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    
    # Add Kubernetes repository (new location)
    ssh_execute "$node_ip" "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
    
    # Update package list
    ssh_execute "$node_ip" "sudo apt-get update"
    
    # Install Kubernetes components (without version suffix since new repo is version-specific)
    ssh_execute "$node_ip" "sudo apt-get install -y kubelet kubeadm kubectl"
    
    # Hold packages at current version
    ssh_execute "$node_ip" "sudo apt-mark hold kubelet kubeadm kubectl"
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
    shift 2
    local worker_nodes=("${1}")
    local worker_ips=("${2}")
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
    for i in "${!worker_nodes[@]}"; do
        join_worker_node "${worker_nodes[$i]}" "${worker_ips[$i]}" "$join_token" "$k8s_version"
        wait_for_node_ready "${worker_nodes[$i]}"
    done
    
    log_success "Kubernetes cluster deployment completed"
}
