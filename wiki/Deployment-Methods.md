# Deployment Methods

## Architecture Evolution

In January 2026, we pivoted from a **monolithic all-in-one deployment** to a **two-phase modular approach**. This change makes the automation more reliable, flexible, and user-friendly.

## Two-Phase Deployment

### Phase 1: Base Cluster (Automated via Script)

**What Gets Deployed**:
- Kubernetes 1.28 cluster
- Calico CNI networking
- MetalLB load balancer
- Local-path storage provisioner
- Portainer web UI (optional)

**Command**:
```bash
./scripts/build-lab.sh
```

**Duration**: ~10 minutes  
**Interaction**: Simple prompts for cluster configuration  
**Result**: Production-ready Kubernetes cluster

### Phase 2: Additional Components (Your Choice)

After the base cluster is running, deploy additional infrastructure using either method:

## Method 1: Portainer UI 🖱️

**Best For**: 
- Visual learners
- Beginners to Kubernetes
- Users who prefer GUI interfaces
- Exploring available components

**How It Works**:
1. Access Portainer dashboard: `http://<master-ip>:30777`
2. Navigate to **Helm** → **Charts**
3. Search for component (e.g., "ingress-nginx")
4. Click **Install** and configure via form
5. Watch deployment progress in real-time

**Advantages**:
- ✅ No command-line knowledge needed
- ✅ Visual feedback during deployment
- ✅ Browse available charts easily
- ✅ Manage everything from one dashboard
- ✅ Easy to rollback or update

**Guide**: [Portainer Deployments](../docs/PORTAINER_DEPLOYMENTS.md)

**Example Components via Portainer**:
- Nginx Ingress Controller
- Cert-Manager
- Prometheus + Grafana Monitoring
- MinIO Object Storage
- Gitea/GitLab
- Longhorn Storage

## Method 2: CLI Scripts 🖥️

**Best For**:
- DevOps engineers
- Automation enthusiasts
- CI/CD pipelines
- Scripted deployments

**How It Works**:
```bash
# Make scripts executable (one time)
chmod +x container-scripts/**/*.sh

# Deploy components as needed
./container-scripts/networking/deploy-ingress.sh <master-ip>
./container-scripts/monitoring/deploy-monitoring.sh <master-ip>
./container-scripts/storage/deploy-longhorn.sh <master-ip>
```

**Advantages**:
- ✅ Fully automated, no interaction needed
- ✅ Scriptable for CI/CD pipelines
- ✅ Consistent, repeatable deployments
- ✅ Easy to version control configurations
- ✅ Flexible configuration options

**Guide**: [container-scripts/README.md](../container-scripts/README.md)

**Available Scripts**:

📡 **Networking**:
- `deploy-ingress.sh` - Nginx Ingress Controller
- `deploy-cert-manager.sh` - TLS certificate management

💾 **Storage**:
- `deploy-longhorn.sh` - Distributed block storage
- `deploy-minio.sh` - S3-compatible object storage

📊 **Monitoring**:
- `deploy-monitoring.sh` - Prometheus + Grafana

🔧 **DevTools**:
- `deploy-registry.sh` - Private container registry
- `deploy-gitea.sh` - Lightweight Git server
- `deploy-gitlab.sh` - Full Git platform

## Method Comparison

| Feature | Portainer UI | CLI Scripts |
|---------|--------------|-------------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ Very Easy | ⭐⭐⭐ Moderate |
| **Learning Curve** | Minimal | Requires bash/SSH knowledge |
| **Automation** | ⭐⭐ Limited | ⭐⭐⭐⭐⭐ Excellent |
| **Customization** | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Extensive |
| **Visual Feedback** | ⭐⭐⭐⭐⭐ Real-time | ⭐⭐ Text-based |
| **CI/CD Integration** | ⭐⭐ Difficult | ⭐⭐⭐⭐⭐ Easy |
| **Speed** | ⭐⭐⭐ Click-through | ⭐⭐⭐⭐⭐ Fast |
| **Repeatability** | ⭐⭐⭐ Manual steps | ⭐⭐⭐⭐⭐ Scriptable |

## Recommended Workflow

### For Beginners
1. Deploy base cluster via `build-lab.sh`
2. Access Portainer dashboard
3. Deploy 1-2 components via Portainer to learn
4. Explore Kubernetes concepts through Portainer UI
5. Graduate to CLI scripts when comfortable

### For Experienced Users
1. Deploy base cluster via `build-lab.sh`
2. Use CLI scripts for rapid component deployment
3. Customize script parameters as needed
4. Use Portainer for visual monitoring and troubleshooting

### For DevOps/Automation
1. Deploy base cluster via automated `build-lab.sh` execution
2. Chain CLI scripts in deployment pipeline
3. Version control all configurations
4. Use Portainer as backup management interface

## Why We Made This Change

### Problems with Original Monolithic Approach
- ❌ Long deployment times (20-30 minutes)
- ❌ Single point of failure (one component fails = whole deployment fails)
- ❌ Difficult to troubleshoot specific components
- ❌ No flexibility - all or nothing
- ❌ Complex user prompts (8+ yes/no questions)
- ❌ Hard to maintain and extend

### Benefits of Two-Phase Approach
- ✅ Fast base cluster deployment (10 minutes)
- ✅ Reliable core automation
- ✅ Deploy only what you need, when you need it
- ✅ Easy to experiment and tear down components
- ✅ Clear separation of concerns
- ✅ Two methods for different user preferences
- ✅ Visual feedback through Portainer
- ✅ Scriptable for automation

## Getting Started

### Quick Start with Portainer
```bash
# 1. Deploy base cluster
./scripts/build-lab.sh

# 2. Access Portainer
# Open browser to: http://<master-ip>:30777

# 3. Follow Portainer guide
# See: docs/PORTAINER_DEPLOYMENTS.md
```

### Quick Start with CLI Scripts
```bash
# 1. Deploy base cluster
./scripts/build-lab.sh

# 2. Make scripts executable
chmod +x container-scripts/**/*.sh

# 3. Deploy components
./container-scripts/networking/deploy-ingress.sh <master-ip>
./container-scripts/monitoring/deploy-monitoring.sh <master-ip>

# 4. Check deployment
kubectl get pods -A
```

## Support

- **Portainer Guide**: [docs/PORTAINER_DEPLOYMENTS.md](../docs/PORTAINER_DEPLOYMENTS.md)
- **CLI Scripts Guide**: [container-scripts/README.md](../container-scripts/README.md)
- **Main Documentation**: [GETTING_STARTED.md](../GETTING_STARTED.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

---

**Choose the method that fits your workflow - both lead to the same production-ready infrastructure!** 🚀
