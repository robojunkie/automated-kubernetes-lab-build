#!/bin/bash

# Kubernetes Lab Setup Script. Author: robojunkie.
# Updated script to support remote cleanup and dynamic configuration of master/worker nodes.
set -e

# --- Variables ---
SSH_KEY="~/.ssh/id_rsa"
DEFAULT_SSH_USER="ubuntu"

# --- Greet and Collect User Inputs ---
echo "Welcome to the Kubernetes Lab Setup Script"
read -r -p "Enter master node hostname or IP: " MASTER_NODE
read -r -p "Enter number of worker nodes: " WORKER_COUNT

WORKER_NODES=()
for i in $(seq 1 "$WORKER_COUNT"); do
    read -r -p "Enter hostname or IP of worker node $i: " WORKER_NODE
    WORKER_NODES+=("$WORKER_NODE")
done

read -r -p "Enter subnet for cluster networking (e.g., 192.168.1.0/24): " SUBNET
read -r -p "Make containers public by default? (yes/no): " PUBLIC_CONTAINER_ACCESS

# --- Cleanup Section ---
echo "Would you like to run the cleanup script to remove old Kubernetes setups? (yes/no): "
read -r RUN_CLEANUP
if [[ "$RUN_CLEANUP" == "yes" ]]; then
    echo "Running cleanup on the master node..."
    ssh -i "$SSH_KEY" "$DEFAULT_SSH_USER@$MASTER_NODE" 'bash -s' < ./scripts/cleanup.sh
    for WORKER in "${WORKER_NODES[@]}"; do
        echo "Running cleanup on worker node $WORKER..."
        ssh -i "$SSH_KEY" "$DEFAULT_SSH_USER@$WORKER" 'bash -s' < ./scripts/cleanup.sh
    done
else
    echo "Skipping cleanup."
fi

# --- Display Summary ---
echo "Configuration summary:"
echo "Master Node: $MASTER_NODE"
echo "Worker Nodes: ${WORKER_NODES[*]}"
echo "Cluster Subnet: $SUBNET"
echo "Public Containers: $PUBLIC_CONTAINER_ACCESS"

# --- Placeholder for Further Setup Logic ---
echo "Further setup steps will be added later. As of now, cleanup has been handled."
