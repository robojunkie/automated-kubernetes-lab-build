#!/bin/bash

# Setup script for configuring the jump box and cleaning up remote nodes dynamically.
set -e

# Determine the Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot determine the Linux distribution. Exiting."
    exit 1
fi

# Define cleanup function for remote nodes
cleanup_remote_nodes() {
  local node_list=($(kubectl get nodes --no-headers -o custom-columns=":metadata.name"))
  for node in "${node_list[@]}"; do
    echo "Executing cleanup on node: $node"
    ssh -o StrictHostKeyChecking=no $node 'bash -s' << 'ENDSSH'
      set -e
      echo "Cleaning up on \$HOSTNAME"
      docker ps -q | xargs --no-run-if-empty docker kill
      docker system prune -af
ENDSSH
  done
}

# Configure SSH
configure_ssh() {
  echo "Configuring SSH..."
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  # Add additional SSH configuration here as required
}

# Main setup logic
main() {
  echo "Linux distribution detected: $OS"

  # Jump box setup specific steps
  echo "Setting up the jump box..."
  case "$OS" in
    ubuntu)
      sudo apt-get update && sudo apt-get install -y sshpass docker.io
      ;;
    almalinux|rocky)
      sudo dnf install -y epel-release && sudo dnf install -y sshpass docker
      ;;
    *)
      echo "Unsupported Linux distribution: $OS"
      exit 1
      ;;
  esac

  # Additional setup steps can be added here

  # Invoke SSH configuration
  configure_ssh

  # Invoke remote node cleanup
  cleanup_remote_nodes

  echo "Setup completed successfully."
}

main "$@"