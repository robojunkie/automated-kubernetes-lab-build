#!/bin/bash

# Setup script for configuring the jump box, SSH connectivity, Kubernetes installation, and networking setup dynamically.
set -e

# --- Helper Functions ---

# Validate IPv4 address
function validate_ip() {
  local ip=$1
  local valid_ip_regex='^([0-9]{1,3}\\.){3}[0-9]{1,3}$'

  if [[ $ip =~ $valid_ip_regex ]]; then
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if ((octet > 255)); then
        return 1
      fi
    done
    return 0
  else
    return 1
  fi
}

# Collect Master Node IP with validation
function get_master_node() {
  while true; do
    echo "Enter the Master Node hostname or IP:"
    read -r MASTER_NODE
    if validate_ip "$MASTER_NODE"; then
      break
    else
      echo "Invalid IP address. Please enter a valid IPv4 address."
    fi
  done
}

# Collect Worker Node IPs from CSV
function get_worker_nodes() {
  while true; do
    echo "Enter a comma-separated list of Worker Node IPs (e.g., 192.168.1.203,192.168.1.204,192.168.1.205):"
    read -r WORKER_NODE_CSV
    IFS=',' read -r -a WORKER_NODES <<< "$WORKER_NODE_CSV"
    if [[ "${#WORKER_NODES[@]}" -gt 0 ]]; then
      echo "Detected ${#WORKER_NODES[@]} worker nodes: ${WORKER_NODES[*]}"
      break
    else
      echo "Invalid input. Please enter a valid comma-separated list of IP addresses."
    fi
  done
}

# Prompt for Network CIDR
function get_pod_network_cidr() {
  while true; do
    echo "Enter the pod network CIDR (default: 192.168.0.0/16):"
    read -r POD_CIDR
    POD_CIDR=${POD_CIDR:-192.168.0.0/16}

    if [[ $POD_CIDR =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
      break
    else
      echo "Invalid CIDR format. Please enter a valid IPv4 CIDR."
    fi
  done
}

# Setup Kubernetes Repository
function setup_kubernetes_repository() {
  echo "Setting up Kubernetes repository for the detected Linux distribution ($ID)..."

  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    sudo apt-get update && sudo apt-get install -y apt-transport-https curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    # Adjust repository distribution based on the detected version
    if [[ "$VERSION_CODENAME" == "focal" || "$VERSION_CODENAME" == "jammy" ]]; then
      echo "deb https://apt.kubernetes.io/ kubernetes-focal main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    elif [[ "$VERSION_CODENAME" == "noble" ]]; then
      echo "deb https://apt.kubernetes.io/ kubernetes-noble main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    else
      echo "Unsupported Ubuntu distribution codename ($VERSION_CODENAME). Exiting."
      exit 1
    fi

    sudo apt-get update
  elif [[ "$ID" == "centos" || "$ID" == "fedora" || "$ID" == "rhel" ]]; then
    sudo dnf config-manager --add-repo=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
    sudo dnf install -y kubeadm kubectl kubelet
    sudo dnf update
  else
    echo "Unsupported Linux distribution ($ID). Exiting."
    exit 1
  fi
}

# Install Kubernetes Tools
function install_kubernetes_tools() {
  echo "Installing Kubernetes tools (kubeadm, kubelet, kubectl)..."

  setup_kubernetes_repository

  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    sudo apt-get install -y kubeadm kubelet kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
  elif [[ "$ID" == "centos" || "$ID" == "fedora" || "$ID" == "rhel" ]]; then
    sudo dnf install -y kubeadm kubelet kubectl
    sudo dnf mark hold kubelet kubeadm kubectl
  fi
}

# Initialize Master Node
function initialize_master_node() {
  echo "Initializing Kubernetes master node with pod network CIDR $POD_CIDR..."

  sudo kubeadm init --pod-network-cidr="$POD_CIDR"

  echo "Configuring kubectl on the master node..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

# Install Networking (Calico)
function install_networking() {
  echo "Installing Calico networking..."
  kubectl apply -f https://docs.projectcalico.org/v3.25/manifests/calico.yaml

  echo "Networking setup is complete!"
}

# Generate the Join Token for Workers
function generate_worker_join_command() {
  echo "Generating join command for worker nodes..."
  JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)
  echo "Join command generated: $JOIN_COMMAND"
}

# Join Worker Nodes
function join_worker_nodes() {
  for node in "${WORKER_NODES[@]}"; do
    echo "Joining worker node: $node to the cluster..."
    ssh "$node" "$JOIN_COMMAND"
  done
}

# --- Main Logic ---
function main() {
  echo "Welcome to the Kubernetes Jump Box Setup Script."
  echo "This script will help set up your jump box and remotely clean Kubernetes nodes."

  # Detect Linux distribution
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Linux distribution detected: $ID ($VERSION_CODENAME)"
  else
    echo "Cannot determine the Linux distribution. Exiting."
    exit 1
  fi

  get_master_node
  get_worker_nodes
  get_pod_network_cidr

  echo "Master Node: $MASTER_NODE"
  echo "Worker Nodes: ${WORKER_NODES[*]}"
  echo "Pod Network CIDR: $POD_CIDR"

  install_kubernetes_tools
  initialize_master_node
  install_networking
  generate_worker_join_command
  join_worker_nodes

  echo "Setup completed successfully!"
}

main