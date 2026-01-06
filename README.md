# Automated Kubernetes Lab Build

A lab-agnostic, bash-based automation framework to quickly and easily deploy production-grade Kubernetes clusters in home labs, on-premises, or budget-constrained environments (Proxmox, VirtualBox, bare metal, etc.).

## Overview

This project automates the entire process of setting up a **complete Kubernetes lab environment** with enterprise-grade components, without requiring expensive cloud infrastructure. Perfect for:
- 🎓 Learning Kubernetes from scratch
- 🧪 Testing and developing applications
- 🔬 Experimenting with cloud-native technologies
- 🏠 Building a powerful home lab
- 💼 Training and certification prep

### What You Get

**Core Cluster** (Always Installed):
- ✅ Kubernetes 1.28 cluster (kubeadm)
- ✅ Calico CNI networking (OS-optimized)
- ✅ MetalLB load balancer (optional)
- ✅ Local-path storage provisioner

**Optional Infrastructure** (Choose During Setup):
- 🎯 **Portainer** - Web UI for visual cluster management
- 📦 **Container Registry** - Private Docker registry with web UI
- 🌐 **Nginx Ingress** - Hostname-based routing
- 🔒 **Cert-Manager** - Automatic TLS certificates
- 📊 **Monitoring** - Prometheus + Grafana dashboards
- 🗄️ **MinIO** - S3-compatible object storage
- 📝 **Git Server** - Gitea (lightweight) or GitLab (full-featured)
- 💾 **Longhorn** - Distributed storage with replication

**Result**: A production-like Kubernetes environment running on your own hardware!

### Key Features

- **🚀 Zero-to-Cluster in 15 Minutes**: Fully automated deployment of production-grade Kubernetes
- **🖥️ Multi-OS Support**: Ubuntu 24.04 and Rocky Linux 9.6 fully tested and working
- **🔧 Lab-Agnostic**: Works with Proxmox, VMware, VirtualBox, bare metal, or any VM platform
- **📦 Complete Infrastructure Stack**: Optional components for a full-featured lab environment:
  - Container Registry (Docker Registry + Web UI)
  - Ingress Controller (Nginx)
  - TLS Certificates (Cert-Manager)
  - Monitoring (Prometheus + Grafana)
  - Object Storage (MinIO S3-compatible)
  - Git Server (Gitea or GitLab)
  - Distributed Storage (Longhorn)
- **🌐 Real LoadBalancer IPs**: MetalLB provides actual IPs from your network (not just NodePort)
- **🎯 Production-Grade**: Uses `kubeadm` for real-world Kubernetes setup matching production environments
- **📚 Comprehensive Documentation**: Beginner-friendly guides assuming no prior Kubernetes knowledge
- **🔄 SSH Orchestration**: Single jump box controls everything - no need to login to each node
- **🛡️ Firewall-Aware**: Automatically configures firewalld on Rocky Linux with all necessary ports
- **💾 Storage Options**: Local-path (fast) or Longhorn (replicated) storage classes

## Documentation

### 📚 New to Kubernetes?
Start here: **[Getting Started Guide](GETTING_STARTED.md)** - Complete beginner-friendly walkthrough (15-30 minutes)

### 📖 Component Reference
**[Components Guide](COMPONENTS.md)** - Detailed reference for all 15+ components with usage examples

### 🎯 Component Quick Start Guides
Master individual components:
- [Portainer](docs/quickstart/PORTAINER.md) - Visual cluster management (start here!)
- [Container Registry](docs/quickstart/REGISTRY.md) - Store and manage your images
- [Nginx Ingress](docs/quickstart/INGRESS.md) - Hostname-based routing
- [Monitoring](docs/quickstart/MONITORING.md) - Prometheus + Grafana dashboards
- [MinIO](docs/quickstart/MINIO.md) - S3-compatible object storage
- [Git Server](docs/quickstart/GIT.md) - Gitea or GitLab for version control
- [Longhorn](docs/quickstart/LONGHORN.md) - Distributed storage with replication

### 🏗️ Architecture & Troubleshooting
- [Architecture Overview](docs/ARCHITECTURE.md) - How all components connect
- [Networking Details](docs/NETWORKING.md) - Deep dive into CNI, MetalLB, and ingress
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions

## Quick Start

### Prerequisites

- A jump box (Linux) with SSH access to your cluster nodes
- Pre-provisioned nodes (VMs or physical machines) with a supported Linux distribution:
  - **Ubuntu 24.04 LTS** (tested ✅)
  - **Rocky Linux 9.6** (tested ✅)
  - Debian/RHEL-family variants (should work)
- Minimum hardware per node:
  - Master: 2+ CPUs, 2GB+ RAM
  - Worker: 1+ CPUs, 1GB+ RAM (4GB+ recommended for full stack)
- Network connectivity between all nodes

### Installation & Deployment

1. Clone the repository on your jump box:
   ```bash
   git clone https://github.com/robojunkie/automated-kubernetes-lab-build.git
   cd automated-kubernetes-lab-build
   ```

2. Run the main build script:
   ```bash
   bash scripts/build-lab.sh
   ```

3. Follow the interactive prompts to provide:
   - Master node hostname/IP
   - Number and details of worker nodes
   - MetalLB IP pool (if using LoadBalancer services)
   - Optional components:
     - Portainer (visual cluster management)
     - Container Registry (store your images)
     - Nginx Ingress (hostname routing)
     - Cert-Manager (TLS certificates)
     - Monitoring Stack (Prometheus + Grafana)
     - MinIO (object storage)
     - Git Server (Gitea or GitLab)
     - Longhorn (distributed storage)

4. Sit back and let the script automate the rest! (15-30 minutes)

## Project Structure

```
automated-kubernetes-lab-build/
├── scripts/
│   ├── build-lab.sh              # Main entry point script
│   ├── modules/
│   │   ├── input-validation.sh    # User input handling and validation
│   │   ├── networking-setup.sh    # Network configuration
│   │   ├── k8s-deploy.sh          # Kubernetes deployment logic
│   │   └── addon-setup.sh         # Optional add-ons installation
│   └── helpers/
│       ├── logging.sh             # Logging utilities
│       ├── ssh-utils.sh           # SSH helper functions
│       └── error-handling.sh       # Error handling and recovery
├── configs/
│   ├── calico-config.yaml         # Calico CNI configuration
│   ├── metallb-config.yaml        # MetalLB load balancer config
│   └── kubeadm-config.yaml        # kubeadm initialization config
├── manifests/
│   ├── ingress-nginx-deploy.yaml  # NGINX Ingress Controller
│   ├── metallb-deploy.yaml        # MetalLB deployment
│   └── addons.yaml                # Additional Kubernetes add-ons
├── templates/
│   ├── network-policy-template.yaml    # Network policy templates
│   └── service-template.yaml           # Service templates for public access
├── examples/
│   ├── example-config.env         # Example environment configuration
│   ├── simple-deployment.yaml     # Example app deployment
│   └── public-service-example.yaml    # Example public-facing service
├── docs/
│   ├── ARCHITECTURE.md            # Detailed architecture documentation
│   ├── NETWORKING.md              # Networking guide
│   ├── TROUBLESHOOTING.md         # Common issues and solutions
│   └── CONTRIBUTING.md            # Contribution guidelines
├── LICENSE                         # MIT License
└── README.md                       # This file
```

## How It Works

### 1. User Input & Validation
The script collects essential information interactively:
- Cluster topology (master, worker count)
- Node connectivity (hostnames/IPs)
- Network configuration (subnet, CIDR)
- Service exposure options (LAN-only, public)

### 2. Network Configuration
Automatically sets up:
- Node-to-node networking using a CNI (Calico by default)
- LAN accessibility for pods
- Load balancing for public services (MetalLB)

### 3. Kubernetes Deployment
Uses `kubeadm` to:
- Initialize the control plane
- Generate and distribute join tokens
- Configure and join worker nodes
- Install the chosen CNI plugin

### 4. Optional Add-ons
Optionally installs:
- NGINX Ingress Controller for external traffic
- MetalLB for load balancing
- Storage provisioners
- Monitoring tools (Prometheus/Grafana)

## Configuration

Create a `config.env` file (see `examples/example-config.env`) to customize:
- Kubernetes version
- CNI plugin choice
- Resource limits
- Node roles and labels

## Examples

See the `examples/` directory for:
- Simple deployment YAML
- Public-facing service configuration
- Network policies
- Multi-tier application examples

## Networking Details

This setup makes Kubernetes pods directly accessible from your LAN. Services can be:
- **Internal** (ClusterIP): Accessible only within the cluster
- **LAN Access** (NodePort): Accessible from your local network
- **Public** (LoadBalancer with MetalLB): Assigned external IPs from your subnet

See [NETWORKING.md](docs/NETWORKING.md) for detailed information.

## Troubleshooting

Common issues and solutions are documented in [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

Key debugging tools:
```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Debug specific node
ssh <node-ip> systemctl status kubelet

# Check networking
kubectl get cni
kubectl describe pod <pod-name>
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines on how to contribute.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Disclaimer

This project is provided as-is for educational and lab purposes. Use at your own risk in production environments. Always test thoroughly before deploying to critical systems.

## Roadmap

- [ ] Multi-cluster support
- [ ] Automated backup and restore
- [ ] GitOps integration (ArgoCD)
- [ ] Advanced monitoring setup
- [ ] Terraform modules for infrastructure as code
- [ ] Cloud-agnostic storage solutions (Ceph, MinIO)
- [ ] CI/CD pipeline integration examples

## Support & Questions

- Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues
- Open an issue on GitHub for bugs
- Discussions are welcome for feature requests

---

**Made for engineers like you who want to learn and experiment with real-world Kubernetes without cloud costs.**