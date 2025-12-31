# Automated Kubernetes Lab Build - Project Index

## 🎯 Quick Navigation

### For First-Time Users
1. Start here: [README.md](README.md)
2. Get started: [QUICKSTART.sh](QUICKSTART.sh) or `bash scripts/build-lab.sh`
3. Example config: [examples/example-config.env](examples/example-config.env)

### For Detailed Information
- **Architecture**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Networking**: [docs/NETWORKING.md](docs/NETWORKING.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Contributing**: [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)

### For Development
- **Main Script**: [scripts/build-lab.sh](scripts/build-lab.sh)
- **Helper Modules**: [scripts/helpers/](scripts/helpers/)
- **Core Modules**: [scripts/modules/](scripts/modules/)

---

## 📂 Directory Guide

| Path | Purpose | Files |
|------|---------|-------|
| `scripts/` | Deployment automation | build-lab.sh + modules |
| `scripts/helpers/` | Reusable utilities | logging, SSH, error handling |
| `scripts/modules/` | Core functionality | validation, networking, k8s, addons |
| `configs/` | Configuration templates | calico, metallb, kubeadm |
| `examples/` | Example configurations | config.env, deployments |
| `docs/` | Documentation | architecture, networking, troubleshooting |
| `manifests/` | Kubernetes manifests | (for future use) |
| `templates/` | Resource templates | (for future use) |

---

## 🚀 Usage Guide

### Basic Deployment (Interactive)
```bash
bash scripts/build-lab.sh
```
Prompts you for all configuration options step by step.

### Using Configuration File
```bash
cp examples/example-config.env my-lab.env
# Edit my-lab.env with your values
bash scripts/build-lab.sh -c my-lab.env
```

### Dry-Run Mode (Validation Only)
```bash
bash scripts/build-lab.sh -d -c my-lab.env
```
Tests configuration without making changes.

### Help
```bash
bash scripts/build-lab.sh -h
```

---

## 📚 Documentation Map

### User Guides
- [README.md](README.md) - Project overview, features, quick start
- [QUICKSTART.sh](QUICKSTART.sh) - Step-by-step quick start
- [examples/example-config.env](examples/example-config.env) - Configuration template

### Technical Documentation
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - System design and components
- [docs/NETWORKING.md](docs/NETWORKING.md) - Network configuration and troubleshooting
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - 10+ common issues and solutions

### Development Documentation
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) - How to contribute
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Build summary and statistics
- [MANIFEST.md](MANIFEST.md) - Complete manifest of deliverables

---

## 🔧 Script Reference

### Main Script: `scripts/build-lab.sh`
Entry point for cluster deployment. Handles:
- User input collection
- Configuration validation
- Orchestration of deployment

**Usage:**
```bash
bash scripts/build-lab.sh [OPTIONS]
  -h, --help              Show help
  -d, --dry-run          Test without changes
  -c, --config FILE      Use config file
```

### Helper Scripts

#### `scripts/helpers/logging.sh`
Provides colored logging functions:
- `log_info()` - Blue info messages
- `log_success()` - Green success messages
- `log_warning()` - Yellow warnings
- `log_error()` - Red error messages
- `log_debug()` - Cyan debug (if DEBUG=true)

#### `scripts/helpers/error-handling.sh`
Error handling and validation:
- `retry_with_backoff()` - Retry with exponential backoff
- `command_exists()` - Check if command available
- `assert_*()` - Assertion functions

#### `scripts/helpers/ssh-utils.sh`
SSH operations:
- `check_ssh_connectivity()` - Test SSH access
- `ssh_execute()` - Run remote command
- `scp_to_remote()` / `scp_from_remote()` - File transfer
- `wait_for_host()` - Wait for host online

### Module Scripts

#### `scripts/modules/input-validation.sh`
Input validation functions:
- `validate_ip()` - Validate IP address
- `validate_subnet()` - Validate CIDR subnet
- `validate_k8s_version()` - Validate K8s version
- `validate_cni_plugin()` - Validate CNI choice

#### `scripts/modules/networking-setup.sh`
Network configuration:
- `setup_networking()` - Configure all nodes
- `configure_node_networking()` - Setup single node
- `setup_firewall_rules()` - Configure firewall
- `setup_container_runtime()` - Install containerd

#### `scripts/modules/k8s-deploy.sh`
Kubernetes deployment:
- `install_kubernetes_binaries()` - Install k8s tools
- `initialize_master()` - Setup master node
- `join_worker_node()` - Add worker to cluster
- `deploy_kubernetes()` - Orchestrate full deployment

#### `scripts/modules/addon-setup.sh`
Add-ons installation:
- `setup_cni()` - Install CNI plugin (3 options)
- `setup_metallb()` - Install MetalLB
- `setup_nginx_ingress()` - Install Ingress Controller
- `setup_prometheus()` - Setup monitoring
- `setup_dashboard()` - Install Kubernetes Dashboard

---

## 🎓 Learning Path

### Beginner
1. Read [README.md](README.md)
2. Review [examples/example-config.env](examples/example-config.env)
3. Run in dry-run mode

### Intermediate
1. Study [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
2. Review `scripts/build-lab.sh` and modules
3. Deploy to test environment

### Advanced
1. Read [docs/NETWORKING.md](docs/NETWORKING.md)
2. Study all modules
3. Customize for your needs
4. Contribute improvements

---

## 🐛 Troubleshooting Reference

Quick links to solutions:

| Issue | Reference |
|-------|-----------|
| SSH connection fails | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#1-ssh-connectivity-problems) |
| kubeadm fails | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#2-kubeadm-initialization-fails) |
| Nodes not ready | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#3-nodes-not-becoming-ready) |
| Pods stuck pending | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#4-pods-stuck-in-pending) |
| Network issues | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#5-pod-to-pod-communication-fails) |
| LoadBalancer pending | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#6-service-loadbalancer-stuck-in-pending) |

---

## 🔍 Search by Topic

### Kubernetes Configuration
- kubeadm config: [configs/kubeadm-config.yaml](configs/kubeadm-config.yaml)
- Deployment example: [examples/simple-deployment.yaml](examples/simple-deployment.yaml)
- Service example: [examples/public-service-example.yaml](examples/public-service-example.yaml)

### Networking
- Pod CIDR: [README.md](README.md#networking-details)
- Network setup: [docs/NETWORKING.md](docs/NETWORKING.md)
- CNI options: [docs/NETWORKING.md](docs/NETWORKING.md#choosing-a-cni)
- Calico config: [configs/calico-config.yaml](configs/calico-config.yaml)

### Add-ons
- MetalLB: [scripts/modules/addon-setup.sh](scripts/modules/addon-setup.sh) - `setup_metallb()`
- Ingress: [scripts/modules/addon-setup.sh](scripts/modules/addon-setup.sh) - `setup_nginx_ingress()`
- Dashboard: [scripts/modules/addon-setup.sh](scripts/modules/addon-setup.sh) - `setup_dashboard()`

### Debugging
- Log functions: [scripts/helpers/logging.sh](scripts/helpers/logging.sh)
- SSH debugging: [scripts/helpers/ssh-utils.sh](scripts/helpers/ssh-utils.sh)
- Troubleshooting: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🚀 Getting Started Checklist

- [ ] Read [README.md](README.md)
- [ ] Review [examples/example-config.env](examples/example-config.env)
- [ ] Verify prerequisites
- [ ] Create config file
- [ ] Run dry-run: `bash scripts/build-lab.sh -d -c my-config.env`
- [ ] Run deployment: `bash scripts/build-lab.sh -c my-config.env`
- [ ] Verify cluster: `kubectl get nodes`
- [ ] Deploy test app: `kubectl apply -f examples/simple-deployment.yaml`
- [ ] Check troubleshooting if issues: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 📞 Support

- **Documentation**: Check [docs/](docs/) folder
- **Issues**: Review [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Contributing**: See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)
- **Examples**: Check [examples/](examples/) folder

---

## 📋 File Index

### Root Level
- [README.md](README.md) - Main documentation
- [MANIFEST.md](MANIFEST.md) - Complete manifest
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Build summary
- [QUICKSTART.sh](QUICKSTART.sh) - Quick start guide
- [LICENSE](LICENSE) - MIT License
- [.gitignore](.gitignore) - Git ignore rules

### Scripts Folder
- [scripts/build-lab.sh](scripts/build-lab.sh) - Main entry point
- [scripts/helpers/logging.sh](scripts/helpers/logging.sh) - Logging utilities
- [scripts/helpers/error-handling.sh](scripts/helpers/error-handling.sh) - Error handling
- [scripts/helpers/ssh-utils.sh](scripts/helpers/ssh-utils.sh) - SSH utilities
- [scripts/modules/input-validation.sh](scripts/modules/input-validation.sh) - Input validation
- [scripts/modules/networking-setup.sh](scripts/modules/networking-setup.sh) - Network setup
- [scripts/modules/k8s-deploy.sh](scripts/modules/k8s-deploy.sh) - K8s deployment
- [scripts/modules/addon-setup.sh](scripts/modules/addon-setup.sh) - Add-ons

### Configs Folder
- [configs/calico-config.yaml](configs/calico-config.yaml) - Calico config
- [configs/metallb-config.yaml](configs/metallb-config.yaml) - MetalLB config
- [configs/kubeadm-config.yaml](configs/kubeadm-config.yaml) - kubeadm config

### Examples Folder
- [examples/example-config.env](examples/example-config.env) - Configuration template
- [examples/simple-deployment.yaml](examples/simple-deployment.yaml) - Simple deployment
- [examples/public-service-example.yaml](examples/public-service-example.yaml) - Public service

### Docs Folder
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Architecture guide
- [docs/NETWORKING.md](docs/NETWORKING.md) - Networking guide
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Troubleshooting guide
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) - Contributing guidelines

---

## 🎯 Next Steps

1. **Review the documentation** - Start with README.md
2. **Understand the architecture** - Read docs/ARCHITECTURE.md
3. **Prepare your environment** - Copy examples/example-config.env
4. **Run a test** - Execute with dry-run mode
5. **Deploy your cluster** - Run the main script
6. **Verify deployment** - Check kubectl output
7. **Troubleshoot if needed** - Consult TROUBLESHOOTING.md

---

*Welcome to Automated Kubernetes Lab Build! Happy deploying! 🚀*
