# Getting Started with Automated Kubernetes Lab

## Welcome! 👋

This guide will help you build a complete Kubernetes lab environment from scratch. No prior Kubernetes experience required!

## What You're Building

This automation creates a **production-grade Kubernetes cluster** in two phases:

### Phase 1: Base Cluster (Automated)
- ✅ **Kubernetes 1.28** cluster (1 master + N workers)
- ✅ **Calico CNI** - Pod networking (OS-optimized)
- ✅ **MetalLB** - LoadBalancer IPs (optional)
- ✅ **Local-path storage** - Persistent volumes
- ✅ **Portainer** - Web UI for cluster management (optional)

⏱️ **Time**: ~10 minutes for base cluster

### Phase 2: Additional Infrastructure (Your Choice)
Deploy after base cluster via **Portainer UI** (visual) or **CLI scripts** (automated):
- 📦 **Container Registry** - Store your own images
- 🌐 **Ingress Controller** - Access services by hostname
- 🔒 **Cert-Manager** - Automatic TLS certificates
- 📊 **Monitoring Stack** - Prometheus + Grafana
- 🗄️ **MinIO** - S3-compatible object storage
- 📝 **Git Server** - Gitea (lightweight) or GitLab (full-featured)
- 💾 **Longhorn** - Distributed storage with replication

⏱️ **Time**: ~5-10 minutes per component

**Perfect for**: Learning Kubernetes, testing applications, CI/CD experimentation, home labs

## Prerequisites

### Hardware Requirements
- **Minimum**: 1 master + 1 worker node, 2GB RAM each
- **Recommended**: 1 master + 3 workers, 4GB+ RAM each
- **Network**: All nodes on same subnet, SSH access

### Supported Operating Systems
- Ubuntu 24.04 LTS (tested)
- Rocky Linux 9.6 (tested)
- Debian/RHEL-family variants (should work)

### On Your Jump Box (Control Machine)
- Linux with Bash 4+
- SSH client
- Network access to all cluster nodes

## Quick Start (5 Minutes to Running Cluster)

### Step 1: Prepare Your Nodes

On each node (master and workers):
```bash
# Ubuntu
sudo apt-get update
sudo apt-get install -y openssh-server

# Rocky Linux
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
```

Ensure SSH key-based authentication is set up:
```bash
# On your jump box
ssh-keygen -t ed25519 -f ~/.ssh/k8s-lab
ssh-copy-id -i ~/.ssh/k8s-lab.pub user@master-ip
ssh-copy-id -i ~/.ssh/k8s-lab.pub user@worker1-ip
# ... repeat for all workers
```

### Step 2: Clone the Repository

```bash
cd ~
git clone https://github.com/yourusername/automated-kubernetes-lab-build.git
cd automated-kubernetes-lab-build
```

### Step 3: Run the Build Script

```bash
bash scripts/build-lab.sh
```

The script will prompt you for:
1. **Cluster name** (e.g., "my-lab")
2. **Master node** hostname and IP
3. **Worker nodes** - add as many as you want
4. **Network subnet** for pod networking (default: 10.244.0.0/16)
5. **Public container access** - yes for LoadBalancer IPs, no for NodePort only
6. **MetalLB IP pool** - if public access enabled (e.g., 192.168.1.220-192.168.1.250)
7. **CNI plugin** - calico (recommended), flannel, or weave
8. **SSH key path** - if not using default ~/.ssh/id_rsa
9. **Install Portainer?** - yes (recommended) or no

### Step 4: Wait for Deployment

The script will:
- ⏱️ Install container runtime (5-10 min)
- ⏱️ Initialize Kubernetes master (2-5 min)
- ⏱️ Join worker nodes (2-3 min per node)
- ⏱️ Deploy CNI networking (1-2 min)
- ⏱️ Deploy MetalLB (if enabled, 2-3 min)
- ⏱️ Deploy Portainer (if enabled, 2-3 min)

**Total time**: ~10-15 minutes for base cluster.

### Step 5: Access Your Cluster

After deployment completes, you'll find:
```
./[clustername]-kubeconfig.yaml  <- Your cluster credentials
./deployment.log                  <- Full deployment log
```

Use your cluster:
```bash
export KUBECONFIG=./my-lab-kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

### Step 6: Deploy Additional Components (Optional)

**Two ways to add more infrastructure**:

#### Option A: Portainer UI (Visual, Beginner-Friendly) 🖱️

1. Access Portainer: `http://<master-ip>:30777`
2. Follow the **[Portainer Deployments Guide](docs/PORTAINER_DEPLOYMENTS.md)**
3. Click through Helm charts to deploy:
   - Nginx Ingress
   - Cert-Manager
   - Monitoring Stack
   - MinIO, Longhorn, Gitea, etc.
4. Watch deployment progress in real-time

**Recommended starting point!**

#### Option B: CLI Scripts (Automated) 🖥️

Use the modular deployment scripts:

```bash
# Deploy ingress controller
./container-scripts/networking/deploy-ingress.sh <master-ip>

# Deploy monitoring (Prometheus + Grafana)
./container-scripts/monitoring/deploy-monitoring.sh <master-ip>

# Deploy container registry
./container-scripts/devtools/deploy-registry.sh <master-ip>

# Deploy Longhorn storage
./container-scripts/storage/deploy-longhorn.sh <master-ip>

# Deploy MinIO object storage
./container-scripts/storage/deploy-minio.sh <master-ip>

# Deploy Gitea git server
./container-scripts/devtools/deploy-gitea.sh <master-ip>

# Deploy cert-manager
./container-scripts/networking/deploy-cert-manager.sh <master-ip>
```

See **[container-scripts/README.md](container-scripts/README.md)** for full documentation.

## What's Next?

Now that your cluster is running, explore the components you installed:

### 📊 [Portainer Dashboard](docs/quickstart/PORTAINER.md)
Web UI for managing your cluster - **Start here if you're new to Kubernetes!**

### 📦 [Container Registry](docs/quickstart/REGISTRY.md)
Store and manage your own container images

### 🌐 [Ingress Controller](docs/quickstart/INGRESS.md)
Access your services using friendly hostnames

### 📈 [Monitoring with Prometheus & Grafana](docs/quickstart/MONITORING.md)
Visualize cluster metrics and performance

### 🗄️ [MinIO Object Storage](docs/quickstart/MINIO.md)
S3-compatible storage for your applications

### 📝 [Gitea/GitLab](docs/quickstart/GIT.md)
Self-hosted Git repositories

### 💾 [Longhorn Storage](docs/quickstart/LONGHORN.md)
Distributed block storage across your cluster

## Common Tasks

### Deploy Your First Application
```bash
# Create a simple nginx deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx  # Get the LoadBalancer IP
```

### Access via Ingress (if installed)
```bash
# Create an ingress resource
kubectl create ingress nginx --rule="nginx.local/*=nginx:80"
# Add nginx.local to your /etc/hosts pointing to ingress controller IP
```

### Push Image to Registry (if installed)
```bash
# Tag your image
docker tag myapp:latest registry-ip:30500/myapp:latest

# Push it
docker push registry-ip:30500/myapp:latest
```

### View Logs
```bash
# Check deployment log
less deployment.log

# Check pod logs
kubectl logs -f deployment/nginx
```

## Troubleshooting

### Nodes Not Ready
```bash
# Check node status
kubectl describe nodes

# Check CNI pods
kubectl get pods -n calico-system  # or kube-system

# Check firewall (Rocky Linux)
sudo firewall-cmd --list-all
```

### Services Not Accessible
```bash
# Check if MetalLB is working
kubectl get pods -n metallb-system

# Check service status
kubectl get svc -A

# Verify IP pool configuration
kubectl get ipaddresspool -n metallb-system
```

### Pod Stuck in Pending
```bash
# Check why
kubectl describe pod <pod-name>

# Common issues:
# - Insufficient resources
# - Storage class not available
# - Node selector/taint issues
```

## Architecture Overview

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for a detailed flow diagram and system design.

## Component Reference

See [COMPONENTS.md](COMPONENTS.md) for detailed information about each component, including:
- What it does
- How to access it
- Configuration options
- Common use cases

## Getting Help

- 📖 Full documentation: [docs/](docs/)
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/automated-kubernetes-lab-build/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/automated-kubernetes-lab-build/discussions)

## Re-deploying

To rebuild your cluster (nuclear option!):
```bash
# The script will clean up and redeploy everything
bash scripts/build-lab.sh
# Answer prompts with your desired configuration
```

All data will be lost unless you've backed up persistent volumes!

## Next Steps for Learning

1. **Start with Portainer** - Visual way to explore Kubernetes concepts
2. **Deploy sample apps** - Try the examples in `examples/`
3. **Set up monitoring** - Install Grafana and explore metrics
4. **Create ingress routes** - Make services accessible by hostname
5. **Experiment with storage** - Create PVCs and persistent applications
6. **Build CI/CD** - Use Gitea + container registry for your workflow

Happy clustering! 🚀
