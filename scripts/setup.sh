#!/bin/bash

# Setup script for configuring the jump box, SSH connectivity, Kubernetes installation, and networking setup dynamically.
set -e

# --- Helper Functions ---

# Validate IPv4 address
function validate_ip() {
  local ip=$1
  local valid_ip_regex='^(([0-9]{1,3})\.){3}([0-9]{1,3})$'

  if [[ $ip =~ $valid_ip_regex ]]; then
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      # Ensure each octet is in the range [0-255]
      if ((octet < 0 || octet > 255)); then
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

# Cleanup Logic
function cleanup_remote_nodes() {
  echo "Do you want to run the cleanup process on the nodes? (yes/no)"
  read -r RUN_CLEANUP

  if [[ "$RUN_CLEANUP" != "yes" ]]; then
    echo "Skipping cleanup process. Proceeding without cleanup."
    return
  fi

  echo "Starting cleanup process..."
  for node in "$MASTER_NODE" "${WORKER_NODES[@]}"; do
    echo "Connecting to node: $node"
    ssh "$node" bash -s << 'ENDSSH'
      set -e
      echo "Cleaning node: $(hostname)"

      # Stop Kubernetes and container runtimes
      for service in kubelet containerd; do
        if systemctl is-active --quiet "$service"; then
          echo "Stopping $service..."
          sudo systemctl stop "$service"
        else
          echo "$service is not running."
        fi
      done

      # Remove Kubernetes tools if installed
      echo "Checking and removing Kubernetes tools..."
      if command -v kubeadm > /dev/null 2>&1; then
        echo "Removing kubeadm, kubectl, and kubelet..."
        sudo apt-get purge -y kubeadm kubectl kubelet || sudo dnf remove -y kubeadm kubectl kubelet
      else
        echo "Kubernetes tools are not installed."
      fi

      # Clear Kubernetes directories
      echo "Removing Kubernetes-related directories..."
      sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd || true
ENDSSH

  done
}

# Setup Kubernetes Repository
function setup_kubernetes_repository() {
  echo "Setting up Kubernetes repository for the detected Linux distribution ($ID)..."

  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    sudo apt-get update && sudo apt-get install -y apt-transport-https curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    # Attempt repository setup dynamically
    if [[ "$VERSION_CODENAME" == "noble" ]]; then
      echo "Repository for 'noble' not found, using fallback: kubernetes-focal"
      echo "deb https://apt.kubernetes.io/ kubernetes-focal main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    else
      echo "deb https://apt.kubernetes.io/ kubernetes-$VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    fi

    sudo apt-get update || (echo "Repository setup failed. Exiting." && exit 1)
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

  sudo apt-get install -y kubeadm kubelet kubectl
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

# Main Logic
function main() {
  echo "Welcome to the Kubernetes Jump Box Setup Script."

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
  cleanup_remote_nodes
  install_kubernetes_tools
}

main