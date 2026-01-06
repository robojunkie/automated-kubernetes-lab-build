# Component Reference

Complete guide to all components available in the Automated Kubernetes Lab.

## Table of Contents
- [Core Components](#core-components)
- [Networking](#networking)
- [Storage](#storage)
- [Management & Monitoring](#management--monitoring)
- [Development Tools](#development-tools)
- [Port Reference](#port-reference)

---

## Core Components

### Kubernetes 1.28
**What it is**: Container orchestration platform that manages your containerized applications.

**Access**: Via `kubectl` CLI tool using the generated kubeconfig file.

**Key Concepts**:
- **Pods**: Smallest deployable units (one or more containers)
- **Deployments**: Manage replicated pods
- **Services**: Network access to pods
- **Namespaces**: Logical cluster subdivisions

**Quick Commands**:
```bash
kubectl get nodes              # Show cluster nodes
kubectl get pods -A            # Show all pods
kubectl get svc -A             # Show all services
kubectl create deployment ...  # Deploy an application
```

---

### Calico CNI (Container Network Interface)
**What it is**: Provides pod-to-pod networking and network policies.

**Default Configuration**:
- **Ubuntu**: VXLANCrossSubnet mode (BGP + VXLAN)
- **Rocky Linux**: Pure VXLAN mode (firewall-friendly)
- **Pod CIDR**: 10.244.0.0/16
- **Service CIDR**: 10.96.0.0/12

**Check Status**:
```bash
kubectl get pods -n calico-system
kubectl get nodes  # All should show Ready
```

**Alternatives**: Flannel, Weave Net (selectable during setup)

---

## Networking

### MetalLB Load Balancer
**What it is**: Provides LoadBalancer IPs for services in bare-metal/VM environments (not cloud).

**When to use**: Enable "public container access" during setup if you want services to get real IPs on your network.

**Configuration**: You choose an IP range from your network (e.g., 192.168.1.220-192.168.1.250).

**How it works**:
```bash
# Create a service with type LoadBalancer
kubectl expose deployment myapp --port=80 --type=LoadBalancer

# MetalLB assigns an IP from your pool
kubectl get svc myapp
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
# myapp   LoadBalancer   10.96.123.45    192.168.1.220    80:31234/TCP
```

**Access**: http://192.168.1.220 from anywhere on your network

**Check Status**:
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
```

---

### Nginx Ingress Controller
**What it is**: Routes HTTP/HTTPS traffic to services based on hostnames and paths.

**Why use it**: Access multiple services using friendly names instead of IPs and ports.

**Access**:
- With MetalLB: Gets a LoadBalancer IP
- Without MetalLB: NodePort 30080 (HTTP), 30443 (HTTPS)

**Quick Start**: See [docs/quickstart/INGRESS.md](docs/quickstart/INGRESS.md)

**Example**:
```bash
# Create ingress for a service
kubectl create ingress myapp --rule="myapp.local/*=myapp:80"

# Add to your /etc/hosts:
# <ingress-ip> myapp.local

# Access at: http://myapp.local
```

**Check Status**:
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

---

### Cert-Manager
**What it is**: Automatically creates and renews TLS certificates for your services.

**Lab Configuration**: Uses self-signed certificates (good for testing, not production).

**Use with Ingress**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  tls:
  - hosts:
    - myapp.local
    secretName: myapp-tls
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

**Check Status**:
```bash
kubectl get pods -n cert-manager
kubectl get certificates -A
```

---

## Storage

### Local-Path Provisioner (Default)
**What it is**: Creates persistent volumes using local disk space on nodes.

**Characteristics**:
- ✅ Simple, fast, no setup needed
- ✅ Good for single-node or testing
- ❌ Data lost if node fails
- ❌ Not replicated across nodes

**Usage**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-path
```

---

### Longhorn Distributed Storage (Optional)
**What it is**: Enterprise-grade distributed block storage across all nodes with replication.

**Characteristics**:
- ✅ Data replicated across nodes (survives node failures)
- ✅ Web UI for management
- ✅ Snapshots and backups
- ❌ More resource intensive
- ❌ Requires open-iscsi on all nodes

**Access**: NodePort 30800 (UI)

**Quick Start**: See [docs/quickstart/LONGHORN.md](docs/quickstart/LONGHORN.md)

**Usage**: Same as local-path, but use `storageClassName: longhorn`

**Check Status**:
```bash
kubectl get pods -n longhorn-system
# Access UI: http://<any-node-ip>:30800
```

---

## Management & Monitoring

### Portainer Dashboard
**What it is**: Web-based UI for managing Kubernetes clusters - **perfect for beginners!**

**Features**:
- Visual pod/deployment management
- Log viewing
- Shell access to containers
- Resource monitoring
- YAML editor

**Access**:
- With MetalLB: LoadBalancer IP on port 9000
- Without MetalLB: NodePort 30777

**Default Credentials**: Set on first login

**Quick Start**: See [docs/quickstart/PORTAINER.md](docs/quickstart/PORTAINER.md)

**URL**: http://\<node-ip\>:30777

---

### Prometheus + Grafana Monitoring Stack
**What it is**: Complete monitoring solution with metrics collection (Prometheus) and visualization (Grafana).

**What you get**:
- Cluster metrics (CPU, memory, network)
- Node metrics
- Pod/container metrics
- Pre-built dashboards

**Access Grafana**:
- With MetalLB: LoadBalancer IP on port 3000
- Without MetalLB: NodePort 30300

**Default Credentials**: admin / admin (change on first login)

**Quick Start**: See [docs/quickstart/MONITORING.md](docs/quickstart/MONITORING.md)

**Popular Dashboards**:
- Node Exporter Full
- Kubernetes Cluster Monitoring
- Kubernetes Pods

---

## Development Tools

### Container Registry (Docker Registry + UI)
**What it is**: Private container registry for storing your own images.

**Why use it**:
- Faster image pulls (local network)
- Store custom images
- No Docker Hub rate limits
- Practice CI/CD workflows

**Access**:
- **Registry**: Port 5000 (MetalLB) or 30500 (NodePort)
- **Web UI**: Port 80 (MetalLB) or 30501 (NodePort)

**Quick Start**: See [docs/quickstart/REGISTRY.md](docs/quickstart/REGISTRY.md)

**Usage**:
```bash
# Tag your image
docker tag myapp:latest <node-ip>:30500/myapp:latest

# Push to registry
docker push <node-ip>:30500/myapp:latest

# Use in Kubernetes
kubectl create deployment myapp --image=<node-ip>:30500/myapp:latest
```

---

### MinIO Object Storage
**What it is**: S3-compatible object storage for files, backups, data lakes, etc.

**Use Cases**:
- Application file storage
- Backup destination
- Data science datasets
- Media files

**Access**:
- **API**: Port 9000 (MetalLB) or 30900 (NodePort)
- **Web Console**: Port 9001 (MetalLB) or 30901 (NodePort)

**Default Credentials**: minioadmin / minioadmin

**Quick Start**: See [docs/quickstart/MINIO.md](docs/quickstart/MINIO.md)

**Compatible Tools**: AWS CLI, s3cmd, rclone, Velero

---

### Gitea (Lightweight Git Server)
**What it is**: Self-hosted Git service similar to GitHub, but lighter than GitLab.

**Features**:
- Git repositories
- Web UI
- Issue tracking
- Pull requests
- Webhooks

**Access**:
- **Web**: Port 3000 (MetalLB) or 30030 (NodePort)
- **SSH**: Port 22 (MetalLB) or 30022 (NodePort)

**Quick Start**: See [docs/quickstart/GIT.md](docs/quickstart/GIT.md)

**First Time Setup**: Configure via web UI on first access

---

### GitLab (Full-Featured Git Platform)
**What it is**: Complete DevOps platform with Git, CI/CD, registry, and more.

**⚠️ Resource Warning**: Requires 4GB+ RAM, takes 5-10 minutes to start.

**Features**: Everything Gitea has plus:
- Built-in CI/CD
- Container registry
- Package registry
- Wiki
- More...

**Access**:
- **Web**: Port 80 (MetalLB) or 30080 (NodePort)
- **SSH**: Port 22 (MetalLB) or 30222 (NodePort)

**Default Credentials**: root / Password123!

**Quick Start**: See [docs/quickstart/GIT.md](docs/quickstart/GIT.md)

---

## Port Reference

### Core Kubernetes Ports
| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| API Server | 6443 | TCP | Kubernetes API |
| etcd | 2379-2380 | TCP | Key-value store |
| Kubelet | 10250 | TCP | Node agent |
| NodePort Range | 30000-32767 | TCP | Service exposure |

### CNI Ports
| CNI | Port | Protocol | Purpose |
|-----|------|----------|---------|
| Calico BGP | 179 | TCP | Routing (Ubuntu mode) |
| Calico VXLAN | 4789 | UDP | Pod networking |
| Calico Typha | 5473 | TCP | Scaling proxy |
| Flannel | 8472 | UDP | Pod networking |
| Weave | 6783 | TCP/UDP | Control/data |

### Application Ports (NodePort Mode)
| Component | Port | Purpose |
|-----------|------|---------|
| Portainer | 30777 | Web UI |
| Container Registry | 30500 | Push/pull images |
| Registry UI | 30501 | Browse images |
| Grafana | 30300 | Monitoring dashboards |
| MinIO API | 30900 | S3 API |
| MinIO Console | 30901 | Web UI |
| Gitea Web | 30030 | Git web UI |
| Gitea SSH | 30022 | Git SSH |
| GitLab Web | 30080 | GitLab UI |
| GitLab SSH | 30222 | Git SSH |
| Longhorn UI | 30800 | Storage management |
| Nginx Ingress | 30080/30443 | HTTP/HTTPS routing |

### LoadBalancer Mode
When MetalLB is enabled, services get IPs from your configured pool instead of NodePorts. Access them directly on their standard ports (80, 443, 3000, 9000, etc.).

---

## Resource Requirements by Component

### Minimal Installation (Core Only)
- **Master**: 2GB RAM, 2 CPU
- **Workers**: 2GB RAM, 2 CPU each
- **Total**: ~2-8GB RAM depending on worker count

### With Common Components (+Portainer, +Registry, +Ingress)
- **Add**: +1-2GB RAM total
- **Total**: ~4-10GB RAM

### Full Installation (All Components)
- **Add**: +4-6GB RAM (mostly GitLab)
- **Total**: ~8-16GB RAM
- **Recommended**: 4 worker nodes for Longhorn replication

---

## Choosing What to Install

### Recommended for Beginners
- ✅ Portainer (visual management)
- ✅ Container Registry (store images)
- ✅ Ingress (easy service access)
- ❌ Skip monitoring initially
- ❌ Skip distributed storage initially

### Recommended for Development
- ✅ Everything above
- ✅ Gitea (lightweight, fast)
- ✅ MinIO (S3 testing)
- ❌ Skip GitLab (unless you need CI/CD)

### Recommended for Production-Like Testing
- ✅ Monitoring (Prometheus/Grafana)
- ✅ Cert-Manager (TLS testing)
- ✅ Longhorn (storage resilience)
- ✅ GitLab (full CI/CD)
- ✅ Everything else

---

## Update Strategy

When re-running the deployment:
1. The script will **completely wipe and rebuild** the cluster
2. All data in persistent volumes will be **lost** unless backed up
3. Re-select the components you want during the new run

### To preserve data:
```bash
# Before rebuild, backup PVCs:
kubectl get pvc -A
# Use Velero or manual backup strategies
```

---

## Further Reading

- [Getting Started Guide](GETTING_STARTED.md) - First-time setup
- [Architecture Overview](docs/ARCHITECTURE.md) - How it all fits together
- [Quickstart Guides](docs/quickstart/) - Component-specific tutorials
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues

---

**Questions?** Open an issue on GitHub or check the discussions forum!
