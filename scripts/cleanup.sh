#!/bin/bash

echo "Starting cleanup of old Kubernetes and container runtime remnants..."

sudo systemctl stop kubelet
sudo systemctl stop containerd

sudo apt-get remove --purge -y kubeadm kubectl kubelet
sudo apt-get autoremove -y
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /var/lib/containerd

sudo kubeadm reset -f
sudo rm -rf /var/lib/cni /etc/cni
sudo iptables -F
sudo iptables -t nat -F

sudo apt-get remove --purge -y docker docker-ce docker-ce-cli
sudo rm -rf /var/lib/docker /etc/docker

echo "Cleanup complete! The instance is now ready for a fresh Kubernetes install."
