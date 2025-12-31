#!/bin/bash

# Setup script for configuring the jump box, SSH connectivity, and cleaning up remote nodes dynamically.
set -e

# --- Functions ---

# Determine the Linux distribution
function detect_linux_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
  else
    echo "Cannot determine the Linux distribution. Exiting."
    exit 1
  fi
}

# Prompt user to configure SSH
function configure_ssh() {
  echo "Do you need help setting up SSH connectivity to the nodes? (yes/no)"
  read -r ssh_help

  if [[ "$ssh_help" == "yes" ]]; then
    echo "Let’s configure SSH connectivity."
    echo "Step 1: Generate an SSH key (if you don't have one):"
    echo "  Command: ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa"
    echo "Step 2: Copy the public key to the remote nodes:"
    echo "  Command: ssh-copy-id -i ~/.ssh/id_rsa.pub username@remote-host"
    echo "Step 3: Verify SSH works:"
    echo "  Command: ssh username@remote-host"
    echo ""
    echo "Run these steps and re-run this script once SSH is configured. Exiting for now."
    exit 0
  else
    echo "Assuming SSH connectivity is already set up. Let’s proceed."
  fi
}

# Run cleanup commands on remote nodes
function cleanup_remote_nodes() {
  echo "Enter the Master Node hostname or IP:"
  read -r MASTER_NODE

  echo "Enter the number of Worker Nodes:"
  read -r WORKER_COUNT

  WORKER_NODES=()
  for i in $(seq 1 "$WORKER_COUNT"); do
    echo "Enter the hostname or IP for Worker Node $i:"
    read -r WORKER_NODE
    WORKER_NODES+=("$WORKER_NODE")
  done

  echo "Do you want to run the cleanup script on the nodes? (this removes old Kubernetes resources) (yes/no)"
  read -r RUN_CLEANUP

  if [[ "$RUN_CLEANUP" == "yes" ]]; then
    echo "Running cleanup on Master Node..."
    ssh "$MASTER_NODE" 'bash -s' < ./scripts/cleanup.sh || echo "Failed to clean Master Node."

    for NODE in "${WORKER_NODES[@]}"; do
      echo "Running cleanup on Worker Node: $NODE..."
      ssh "$NODE" 'bash -s' < ./scripts/cleanup.sh || echo "Failed to clean Worker Node: $NODE"
    done
  else
    echo "Skipping cleanup process. Proceeding without cleanup."
  fi
}

# --- Main Code ---

echo "Welcome to the Kubernetes Jump Box Setup Script."
echo "This script will help set up your jump box and remotely clean Kubernetes nodes."

# Detect Linux distribution
detect_linux_distro
echo "Linux distribution detected: $OS"

# Configure SSH connectivity
configure_ssh

# Perform remote node cleanup
cleanup_remote_nodes

echo "Setup completed successfully."