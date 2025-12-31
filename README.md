# Automated Kubernetes Lab Build

A lab-agnostic, bash-based automation framework to quickly and easily deploy production-grade Kubernetes clusters in home labs, on-premises, or budget-constrained environments (Proxmox, VirtualBox, bare metal, etc.).

## Overview

This project automates the entire process of setting up a Kubernetes cluster using industry-standard tools and practices, without requiring expensive cloud environments. It's designed for IT professionals, cloud engineers, and hobbyists who want to practice with real-world Kubernetes configurations.

### Key Features

- **Lab-Agnostic**: Works with any underlying virtualization platform (Proxmox, VMware, VirtualBox, bare metal)
- **Interactive Configuration**: Prompts users for cluster topology, node details, and networking configuration
- **Flexible Networking**: Automatically configures networking based on user subnet specifications
- **LAN Access**: Containers are accessible from your local network by default
- **Public Service Support**: Easily expose services to the public if needed
- **Production-Grade**: Uses `kubeadm` for real-world Kubernetes setup (matching production environments)
- **Jump Box Compatible**: Runs from a single jump box with SSH access to all nodes
- **Extensible**: Modular design allows for easy addition of ingress controllers, monitoring, and storage solutions

## Quick Start

### Prerequisites

- A jump box (Linux) with SSH access to your cluster nodes
- Pre-provisioned nodes (VMs or physical machines) with a supported Linux distribution:
  - Ubuntu 20.04+
  - Debian 10+
  - CentOS 7+
- Minimum hardware per node:
  - Master: 2+ CPUs, 2GB+ RAM
  - Worker: 1+ CPUs, 1GB+ RAM
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
   - Subnet information for networking
   - Whether containers should be public by default
   - Optional add-ons (ingress, monitoring, storage)

4. Sit back and let the script automate the rest!

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