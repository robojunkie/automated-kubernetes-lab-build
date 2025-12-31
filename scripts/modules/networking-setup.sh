#!/bin/bash

################################################################################
# Networking Setup Module
# Configures networking on cluster nodes
################################################################################

################################################################################
# Setup networking prerequisites on all nodes
################################################################################
setup_networking() {
    local master_ip=$1
    shift
    local worker_ips=("$@")
    
    log_info "Setting up networking prerequisites..."
    
    # Setup master node
    log_info "Configuring master node: $master_ip"
    configure_node_networking "$master_ip"
    
    # Setup worker nodes
    for worker_ip in "${worker_ips[@]}"; do
        log_info "Configuring worker node: $worker_ip"
        configure_node_networking "$worker_ip"
    done
    
    log_success "Networking prerequisites setup completed"
}

################################################################################
# Configure networking on a single node
################################################################################
configure_node_networking() {
    local node_ip=$1
    
    log_debug "Configuring networking on: $node_ip"
    
    # Disable swap
    log_debug "Disabling swap on $node_ip..."
    ssh_execute "$node_ip" "sudo swapoff -a"
    ssh_execute "$node_ip" "sudo sed -i '/ swap / s/^/#/' /etc/fstab"
    
    # Load kernel modules
    log_debug "Loading required kernel modules on $node_ip..."
    ssh_execute "$node_ip" "sudo modprobe overlay"
    ssh_execute "$node_ip" "sudo modprobe br_netfilter"
    
    # Configure kernel parameters
    log_debug "Configuring kernel parameters on $node_ip..."
    ssh_execute "$node_ip" "cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF"
    
    ssh_execute "$node_ip" "sudo sysctl --system"
    
    log_success "Networking configured on: $node_ip"
}

################################################################################
# Configure firewall rules for Kubernetes
################################################################################
setup_firewall_rules() {
    local master_ip=$1
    shift
    local worker_ips=("$@")
    
    log_info "Setting up firewall rules..."
    
    # Master node ports
    log_debug "Configuring firewall for master: $master_ip"
    configure_master_firewall "$master_ip"
    
    # Worker node ports
    for worker_ip in "${worker_ips[@]}"; do
        log_debug "Configuring firewall for worker: $worker_ip"
        configure_worker_firewall "$worker_ip"
    done
    
    log_success "Firewall rules configured"
}

################################################################################
# Configure firewall for master node
################################################################################
configure_master_firewall() {
    local master_ip=$1
    
    # Master node Kubernetes ports
    local master_ports=(
        "6443:tcp"    # Kubernetes API
        "2379:tcp"    # etcd server
        "2380:tcp"    # etcd peer
        "10250:tcp"   # kubelet API
        "10251:tcp"   # kube-scheduler
        "10252:tcp"   # kube-controller-manager
    )
    
    for port in "${master_ports[@]}"; do
        ssh_execute "$master_ip" "sudo firewall-cmd --add-port=$port --permanent 2>/dev/null || true"
    done
    
    # Reload firewall
    ssh_execute "$master_ip" "sudo firewall-cmd --reload 2>/dev/null || true"
}

################################################################################
# Configure firewall for worker nodes
################################################################################
configure_worker_firewall() {
    local worker_ip=$1
    
    # Worker node Kubernetes ports
    local worker_ports=(
        "10250:tcp"   # kubelet API
        "30000-32767:tcp"  # NodePort services
    )
    
    for port in "${worker_ports[@]}"; do
        ssh_execute "$worker_ip" "sudo firewall-cmd --add-port=$port --permanent 2>/dev/null || true"
    done
    
    # Reload firewall
    ssh_execute "$worker_ip" "sudo firewall-cmd --reload 2>/dev/null || true"
}

################################################################################
# Configure container runtime prerequisites
################################################################################
setup_container_runtime() {
    local master_ip=$1
    shift
    local worker_ips=("$@")
    
    log_info "Setting up container runtime prerequisites..."
    
    # Setup master node
    configure_container_runtime_on_node "$master_ip"
    
    # Setup worker nodes
    for worker_ip in "${worker_ips[@]}"; do
        configure_container_runtime_on_node "$worker_ip"
    done
    
    log_success "Container runtime prerequisites configured"
}

################################################################################
# Configure container runtime on a single node
################################################################################
configure_container_runtime_on_node() {
    local node_ip=$1
    
    log_debug "Setting up container runtime on: $node_ip"
    
    # Update package manager
    ssh_execute "$node_ip" "sudo apt-get update || sudo yum check-update"
    
    # Install containerd (production-grade container runtime)
    log_debug "Installing containerd on $node_ip..."
    ssh_execute "$node_ip" "curl -fsSL https://get.docker.com | sh - || true"
    ssh_execute "$node_ip" "sudo apt-get install -y containerd.io || sudo yum install -y containerd.io"
    
    # Configure containerd
    ssh_execute "$node_ip" "sudo mkdir -p /etc/containerd"
    ssh_execute "$node_ip" "containerd config default | sudo tee /etc/containerd/config.toml"
    ssh_execute "$node_ip" "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"
    
    # Restart containerd
    ssh_execute "$node_ip" "sudo systemctl daemon-reload"
    ssh_execute "$node_ip" "sudo systemctl restart containerd"
    ssh_execute "$node_ip" "sudo systemctl enable containerd"
    
    log_success "Container runtime configured on: $node_ip"
}
