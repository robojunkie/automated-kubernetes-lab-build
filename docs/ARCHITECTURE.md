# Architecture Overview

## High-Level Design

The Automated Kubernetes Lab Build framework is designed to automate the deployment of a production-grade Kubernetes cluster in lab environments. The architecture is modular, allowing for flexible deployment across various infrastructure platforms.

```
┌─────────────────────────────────────────────────────────────┐
│                      Jump Box                                │
│  (Entry Point - runs build-lab.sh)                          │
└──────────────────────────────────────────────────────────────┘
           │
           ├─── SSH ──┬─── SSH ──┬─── SSH ───...
           │          │          │
    ┌──────▼──┐  ┌────▼──┐  ┌───▼────┐
    │ Master  │  │Worker │  │Worker  │
    │  Node   │  │  Node │  │  Node  │
    │(Control)│  │  1    │  │  2     │
    └──────────┘  └───────┘  └────────┘
```

## Components

### 1. Jump Box
- **Purpose**: Central orchestration point for cluster deployment
- **Requirements**: Linux, Bash, SSH access to all nodes
- **Role**: Runs the main deployment script and orchestrates setup

### 2. Master Node (Control Plane)
- **Role**: Manages the Kubernetes cluster
- **Components**:
  - API Server: Kubernetes API endpoint
  - etcd: Cluster state storage
  - Controller Manager: Manages cluster controllers
  - Scheduler: Assigns pods to nodes
  - kubelet: Node agent

### 3. Worker Nodes
- **Role**: Runs container workloads
- **Components**:
  - kubelet: Node agent
  - Container Runtime (containerd): Runs containers
  - kube-proxy: Network proxy

## Networking

### Pod Network
- **CIDR**: 10.244.0.0/16 (default, customizable)
- **CNI Options**:
  - **Calico**: High-performance, supports network policies
  - **Flannel**: Simple overlay network
  - **Weave**: Full mesh network

### Service Network
- **CIDR**: 10.96.0.0/12 (standard Kubernetes range)
- **Access Methods**:
  - ClusterIP: Internal only
  - NodePort: Access via node port (30000-32767)
  - LoadBalancer: External IP (with MetalLB)

### LAN Access
- Pods and services are accessible from the LAN if configured properly
- MetalLB provides external IP addresses for LoadBalancer services
- Uses VXLAN or other overlay networks to bridge LAN and pod network

## Data Flow

### Deployment Flow
```
1. User provides configuration (interactive or config file)
2. Validate prerequisites and connectivity
3. Setup networking prerequisites on all nodes
4. Install container runtime on all nodes
5. Initialize master node with kubeadm
6. Join worker nodes to cluster
7. Install CNI plugin
8. Install optional add-ons (MetalLB, Ingress, etc.)
9. Verify cluster health
```

### Pod Communication
```
Pod on Node A → CNI Plugin → Network Overlay → CNI Plugin → Pod on Node B
```

## Add-ons Architecture

### CNI (Container Network Interface)
- Manages pod networking
- Enables pod-to-pod communication across nodes
- Supports network policies (depends on CNI)

### MetalLB
- Provides external IP addresses for LoadBalancer services
- Uses Layer 2 advertisement by default
- Integrates with existing LAN network

### Ingress Controller (NGINX)
- Routes external HTTP/HTTPS traffic to services
- Manages hostname-based routing
- TLS termination support

### Monitoring (Optional)
- Prometheus: Metrics collection
- Grafana: Visualization
- AlertManager: Alert routing

## Security Considerations

1. **Authentication & Authorization**
   - kubeadm sets up RBAC out of the box
   - Service accounts and roles for workloads

2. **Network Security**
   - Network policies can restrict traffic (CNI-dependent)
   - Firewall rules configured on nodes

3. **Encryption**
   - etcd encryption at rest (optional)
   - TLS for all API communication

4. **Access Control**
   - SSH key-based authentication
   - kubeconfig restricted to authorized users

## Extensibility

The framework is designed for easy extension:

1. **Custom Modules**: Add shell modules in `scripts/modules/`
2. **Add-on Hooks**: Extend `addon-setup.sh` for additional tools
3. **Configuration**: Customize via `config.env` file
4. **Templates**: Modify manifest templates for your needs

## Performance Considerations

- **Pod Network**: VXLAN overhead is minimal (~50 bytes per packet)
- **etcd**: Single-node etcd adequate for labs (3+ nodes recommended for HA)
- **Kubelet**: Can manage hundreds of pods per node
- **Resource Limits**: Set resource requests/limits to prevent node overload

## Scalability

**Horizontal Scaling**:
- Add worker nodes by re-running join commands
- Current design supports up to ~5000 nodes (kubeadm limitation)

**Vertical Scaling**:
- Increase master node resources for large clusters
- Distribute control plane for HA (not in current MVP)

## High Availability (Future)

For production-grade HA:
- Multiple master nodes with load balancer
- Distributed etcd cluster
- Multiple ingress controllers
- Distributed storage backend
