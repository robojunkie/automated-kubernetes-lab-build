#!/bin/bash

# Kubernetes Setup Script for Automated Lab Build
# Author: robojunkie
# Created: 2025-12-22

# Optional Cleanup Script Integration
echo "Would you like to run the cleanup script first? (y/n)"
read cleanup_choice
if [[ "$cleanup_choice" == "y" ]]; then
    echo "Running cleanup..."
    ./scripts/cleanup.sh
else
    echo "Skipping cleanup."
fi

# User Configuration
echo "Is this the master node? (y/n)"
read is_master

if [[ "$is_master" == "y" ]]; then
    echo "Configuring node as master..."
    echo "Please enter the Pod network CIDR (default: 10.244.0.0/16):"
    read pod_cidr
    pod_cidr=${pod_cidr:-10.244.0.0/16}
else
    echo "Configuring node as worker..."
    echo "Please enter the Join Token for this worker node:"
    read join_token
	echo "Enter the Master Node's IP address:"
	read master_ip
fi

# Setup and Install Dependencies
echo "Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Install required packages
echo "Installing prerequisites..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Kubernetes APT repository and Key
echo "Adding Kubernetes APT repository and key..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

# Install containerd
echo "Installing containerd..."
sudo apt-get install -y containerd

# Configure containerd
echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

echo "Loading necessary kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Setting sysctl params for Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# Install kubeadm, kubelet, and kubectl
echo "Installing Kubernetes tools..."
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Check if this is the master node or a worker node and proceed appropriately
if [[ "$is_master" == "y" ]]; then
    echo "Initializing Kubernetes Master Node..."
    sudo kubeadm init --pod-network-cidr=$pod_cidr

    # Configure kubectl for the master node
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Deploy pod network
    echo "Deploying Pod Network (Weave Net)..."
    kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml
else
    echo "Joining Kubernetes Worker Node..."
    sudo kubeadm join $master_ip:6443 --token $join_token --discovery-token-ca-cert-hash sha256:${DISCOVERY_TOKEN_HASH}
fi

echo "Setup complete!"