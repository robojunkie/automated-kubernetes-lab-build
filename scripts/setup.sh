#!/bin/bash

echo "Welcome to the Kubernetes Lab Setup Script"

# Ask for master and worker IPs or hostnames
read -r -p "Enter master node hostname or IP: " MASTER_NODE
read -r -p "Enter number of worker nodes: " WORKER_COUNT

# Collect worker nodes' IPs/hostnames interactively
WORKER_NODES=()
for i in $(seq 1 "$WORKER_COUNT"); do
    read -r -p "Enter hostname or IP of worker node $i: " WORKER_NODE
    WORKER_NODES+=("$WORKER_NODE")
done

# Networking setup
read -r -p "Enter subnet for cluster networking (e.g., 192.168.1.0/24): " SUBNET
read -r -p "Make containers public by default? (yes/no): " PUBLIC_CONTAINER_ACCESS

echo "\nConfiguration summary:"
echo "Master Node: $MASTER_NODE"
echo "Worker Nodes: ${WORKER_NODES[*]}"
echo "Cluster Subnet: $SUBNET"
echo "Public Containers: $PUBLIC_CONTAINER_ACCESS"
 
echo "\nFurther setup steps will be added later."
