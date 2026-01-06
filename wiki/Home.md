# Automated Kubernetes Lab Build - Wiki

Welcome to the comprehensive wiki for the Automated Kubernetes Lab Build project!

## 📖 What is This Project?

This project was born from a simple need: **"Build me a nuclear option for rebuilding my Kubernetes cluster."**

What started as a script to automate Kubernetes deployment on Ubuntu evolved into a complete, production-grade lab infrastructure framework that works on multiple operating systems and includes everything you need for a modern cloud-native development environment.

## 🎯 Project Goals

### The Problem We Solved

**Before this project:**
- ❌ Manually SSH into each node to install packages
- ❌ Copy/paste commands from various tutorials
- ❌ Spend hours debugging CNI networking issues
- ❌ Fight with firewall configurations on RHEL systems
- ❌ No consistent way to add monitoring, storage, or ingress
- ❌ Each rebuild takes 2-4 hours of manual work

**After this project:**
- ✅ One command to deploy entire cluster (15-30 minutes)
- ✅ Works identically on Ubuntu and Rocky Linux
- ✅ Automatic firewall configuration
- ✅ Optional components (registry, monitoring, git, storage) via simple prompts
- ✅ Production-grade setup using kubeadm (not k3s or minikube)
- ✅ Comprehensive documentation for beginners

### Why "Nuclear Option"?

The name comes from the original request - a way to completely **nuke and rebuild** a Kubernetes lab environment quickly and reliably. Perfect for:
- 🧪 Testing and breaking things (then rebuilding in minutes)
- 📚 Learning Kubernetes without cloud costs
- 🏠 Home lab experimentation
- 💼 Training environments
- 🔬 CI/CD testing

## 🏗️ What We Built

### Core Infrastructure
- **Kubernetes 1.28** cluster using kubeadm
- **Multi-OS Support**: Ubuntu 24.04 and Rocky Linux 9.6 (fully tested)
- **Calico CNI** with OS-optimized configuration
- **MetalLB** for real LoadBalancer IPs on bare metal
- **Local-path storage** for persistent volumes

### Optional Lab Infrastructure (Choose What You Need)
- 🎯 **Portainer** - Web UI for cluster management
- 📦 **Container Registry** - Private Docker registry with web UI
- 🌐 **Nginx Ingress** - Hostname-based routing (app1.lab.local, app2.lab.local)
- 🔒 **Cert-Manager** - Automatic TLS certificates
- 📊 **Monitoring** - Prometheus + Grafana with pre-built dashboards
- 🗄️ **MinIO** - S3-compatible object storage
- 📝 **Git Server** - Gitea (lightweight) or GitLab (full-featured)
- 💾 **Longhorn** - Distributed storage with replication and snapshots

## 📚 Wiki Navigation

### Getting Started
- **[Installation Guide](Installation-Guide)** - Step-by-step setup from scratch
- **[Quick Start](Quick-Start)** - Deploy your first cluster in 5 minutes
- **[Architecture Overview](Architecture)** - How all the pieces fit together

### Core Components
- **[Kubernetes Setup](Kubernetes-Setup)** - How we deploy and configure K8s
- **[Networking](Networking)** - CNI, MetalLB, and Ingress deep dive
- **[Storage Options](Storage)** - Local-path vs Longhorn comparison

### Optional Components
- **[Portainer Guide](Portainer)** - Visual cluster management
- **[Container Registry](Container-Registry)** - Private image storage
- **[Ingress Controller](Ingress)** - Hostname-based routing
- **[Monitoring Stack](Monitoring)** - Prometheus + Grafana
- **[MinIO Storage](MinIO)** - S3-compatible object storage
- **[Git Servers](Git-Servers)** - Gitea and GitLab setup
- **[Longhorn Storage](Longhorn)** - Distributed storage

### Operating Systems
- **[Ubuntu 24.04 Setup](Ubuntu-Setup)** - Ubuntu-specific details
- **[Rocky Linux 9.6 Setup](Rocky-Linux-Setup)** - RHEL-family configuration and firewall rules

### Advanced Topics
- **[Multi-OS Support](Multi-OS-Support)** - How we support different Linux distributions
- **[Firewall Configuration](Firewall-Configuration)** - Complete firewalld rules for Rocky Linux
- **[Troubleshooting Guide](Troubleshooting)** - Common issues and solutions
- **[Development Guide](Development)** - Contributing to the project

## 🚀 Quick Links

### For New Users
1. Start with [Installation Guide](Installation-Guide)
2. Follow the [Quick Start](Quick-Start)
3. Learn about [Portainer](Portainer) for visual management
4. Explore [Architecture Overview](Architecture) to understand the system

### For Developers
1. Read [Architecture Overview](Architecture)
2. Check [Development Guide](Development)
3. Review [Multi-OS Support](Multi-OS-Support) design
4. See [Troubleshooting Guide](Troubleshooting) for debugging

### For Operators
1. Understand [Networking](Networking) setup
2. Compare [Storage Options](Storage)
3. Set up [Monitoring Stack](Monitoring)
4. Configure [Ingress Controller](Ingress)

## 💡 Design Philosophy

### 1. **Lab-First, Production-Ready**
We use production tools (kubeadm, Calico, Prometheus) but optimize for lab use (self-signed certs, no auth by default, easy reset).

### 2. **Opinionated but Flexible**
Sensible defaults (Calico CNI, local-path storage) but supports alternatives (Flannel, Weave, Longhorn).

### 3. **Beginner-Friendly, Expert-Capable**
Documentation assumes no Kubernetes knowledge, but implements enterprise patterns.

### 4. **Infrastructure as Code**
Everything automated via bash scripts - reproducible and version-controlled.

### 5. **Multi-OS Support**
Works on both Debian and RHEL families with automatic OS detection.

## 📊 Project Stats

- **Lines of Code**: ~3,500+ lines of bash
- **Documentation**: ~5,000+ lines of markdown
- **Supported Components**: 15+ optional infrastructure components
- **Deployment Time**: 15-30 minutes for full stack
- **Manual Steps Required**: 1 (run the script)

## 🎓 Learning Path

### Week 1: Basic Kubernetes
1. Deploy basic cluster (just K8s + Calico)
2. Use Portainer to explore the cluster
3. Deploy your first application
4. Learn about pods, deployments, and services

### Week 2: Networking
1. Enable MetalLB for LoadBalancer IPs
2. Deploy Ingress controller
3. Set up hostname-based routing
4. Add TLS with cert-manager

### Week 3: Storage & Data
1. Understand local-path storage
2. Deploy Longhorn for replication
3. Set up MinIO for object storage
4. Practice backups and restores

### Week 4: DevOps Tools
1. Deploy container registry
2. Build and push your own images
3. Set up Git server (Gitea/GitLab)
4. Create CI/CD pipelines

### Week 5: Observability
1. Deploy monitoring stack
2. Create custom Grafana dashboards
3. Set up alerts
4. Monitor application metrics

## 🤝 Community & Support

- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/robojunkie/automated-kubernetes-lab-build/issues)
- **Discussions**: Ask questions and share ideas in [GitHub Discussions](https://github.com/robojunkie/automated-kubernetes-lab-build/discussions)
- **Contributing**: See [Development Guide](Development) for contribution guidelines

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/robojunkie/automated-kubernetes-lab-build/blob/main/LICENSE) file for details.

---

**Made by engineers, for engineers who want to learn cloud-native technologies without cloud costs.**

*Last Updated: January 2026*
