#!/bin/bash

# Setup script for configuring the jump box, SSH connectivity, and cleaning up remote nodes dynamically.
set -e

# --- Helper Functions ---

# Validate IPv4 address
function validate_ip() {
  local ip=$1
  local valid_ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

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

# Collect Worker Node IPs with validation
function get_worker_nodes() {
  echo "Enter the number of Worker Nodes:"
  read -r WORKER_COUNT

  WORKER_NODES=()
  for i in $(seq 1 "$WORKER_COUNT"); do
    while true; do
      echo "Enter the hostname or IP for Worker Node $i:"
      read -r WORKER_NODE
      if validate_ip "$WORKER_NODE"; then
        WORKER_NODES+=("$WORKER_NODE")
        break
      else
        echo "Invalid IP address. Please enter a valid IPv4 address."
      fi
    done
  done
}

# Cleanup Logic for Kubernetes and Container Tools
function cleanup_remote_nodes() {
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

      # Prune Docker or container runtimes
      echo "Pruning Docker..."
      if command -v docker > /dev/null 2>&1; then
        sudo docker system prune -af || true
      fi

      # Clear Kubernetes directories
      echo "Removing Kubernetes-related directories and volumes..."
      sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd || true

      echo "Cleanup complete for $(hostname)."
ENDSSH

  done
}

# --- Main Logic ---
function main() {
  echo "Welcome to the Kubernetes Jump Box Setup Script."
  echo "This script will help set up your jump box and remotely clean Kubernetes nodes."

  # Detect Linux distribution
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Linux distribution detected: $ID"
  else
    echo "Cannot determine the Linux distribution. Exiting."
    exit 1
  fi

  get_master_node
  get_worker_nodes

  echo "Master Node: $MASTER_NODE"
  echo "Worker Nodes: ${WORKER_NODES[*]}"

  cleanup_remote_nodes
  echo "Setup completed successfully."
}

main