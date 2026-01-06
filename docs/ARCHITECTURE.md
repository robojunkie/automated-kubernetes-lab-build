# Architecture Overview

Understanding how all the pieces fit together in your Kubernetes lab.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            JUMP BOX (Your Machine)                       │
│  • SSH orchestration                                                     │
│  • kubectl (KUBECONFIG points to master)                                 │
│  • Triggers automation scripts                                           │
└────────────────────┬────────────────────────────────────────────────────┘
                     │ SSH
                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CONTROL PLANE                          │
│                              (Master Node)                               │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Core Components:                                                   │ │
│  │  • kube-apiserver (6443)                                            │ │
│  │  • kube-controller-manager                                          │ │
│  │  • kube-scheduler                                                   │ │
│  │  • etcd (2379-2380)                                                 │ │
│  │  • kubelet (10250)                                                  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└────────────────────┬────────────────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┬──────────────────┐
          ▼                     ▼                  ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Worker Node 1  │  │   Worker Node 2  │  │   Worker Node 3  │
│                  │  │                  │  │                  │
│  • kubelet       │  │  • kubelet       │  │  • kubelet       │
│  • containerd    │  │  • containerd    │  │  • containerd    │
│  • kube-proxy    │  │  • kube-proxy    │  │  • kube-proxy    │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## Network Architecture

```
                    ┌────────────────────────────────────────┐
                    │         External Network               │
                    │      (Your Home/Lab Network)           │
                    │     192.168.1.0/24 (example)           │
                    └──────────────┬─────────────────────────┘
                                   │
                    ┌──────────────┴─────────────────┐
                    │        MetalLB L2 Mode         │
                    │  (Assigns IPs from pool)       │
                    │  e.g., 192.168.1.210-219       │
                    └──────────────┬─────────────────┘
                                   │
            ┌──────────────────────┼─────────────────────────┐
            │                      │                         │
            ▼                      ▼                         ▼
    ┌──────────────┐      ┌──────────────┐         ┌──────────────┐
    │   Ingress    │      │  Portainer   │         │   Grafana    │
    │ LoadBalancer │      │ LoadBalancer │         │ LoadBalancer │
    │ 192.168.1.210│      │ 192.168.1.211│         │ 192.168.1.212│
    │              │      │              │         │              │
    │ Port 80/443  │      │  Port 9000   │         │  Port 3000   │
    └──────┬───────┘      └──────┬───────┘         └──────┬───────┘
           │                     │                        │
           │                     │                        │
           │    ┌────────────────┴────────────┐           │
           │    │                             │           │
           ▼    ▼                             ▼           ▼
    ┌─────────────────────────────────────────────────────────────┐
    │              Kubernetes Service Network                      │
    │                 10.96.0.0/12 (CIDR)                          │
    │                                                               │
    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
    │  │   Service   │  │   Service   │  │   Service   │          │
    │  │  ClusterIP  │  │  ClusterIP  │  │  ClusterIP  │          │
    │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
    │         │                │                │                  │
    └─────────┼────────────────┼────────────────┼──────────────────┘
              │                │                │
              ▼                ▼                ▼
    ┌─────────────────────────────────────────────────────────────┐
    │              Kubernetes Pod Network                          │
    │               10.244.0.0/16 (CIDR)                           │
    │                  (Calico CNI)                                │
    │                                                               │
    │  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐     │
    │  │  Pod  │  │  Pod  │  │  Pod  │  │  Pod  │  │  Pod  │     │
    │  │ App 1 │  │ App 2 │  │ DB 1  │  │ DB 2  │  │ Cache │     │
    │  └───────┘  └───────┘  └───────┘  └───────┘  └───────┘     │
    │                                                               │
    └───────────────────────────────────────────────────────────────┘
```

## Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER / APPLICATION                               │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           │ HTTP/HTTPS (hostname-based routing)
           │ app1.lab.local, app2.lab.local, etc.
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      NGINX INGRESS CONTROLLER                            │
│  • Hostname-based routing                                                │
│  • TLS termination (with cert-manager)                                   │
│  • Path-based routing                                                    │
│  Port: 80 (HTTP), 443 (HTTPS)                                            │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           │ Forwards to appropriate Service
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      KUBERNETES SERVICES                                 │
│  • ClusterIP: Internal routing                                           │
│  • LoadBalancer: External access via MetalLB                             │
│  • NodePort: Access via node IP + port                                   │
└──────────┬──────────────────────────────────────────────────────────────┘
           │
           │ Load balances to healthy pods
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION PODS                                 │
│  • Your containerized applications                                       │
│  • Scaled horizontally (multiple replicas)                               │
│  • Health checks (liveness/readiness probes)                             │
└──────────┬────────────────────────────────────┬───────────────────────────┘
           │                                    │
           │ Reads/Writes                       │ Pushes Metrics
           │                                    │
           ▼                                    ▼
┌─────────────────────────┐         ┌─────────────────────────────────────┐
│    STORAGE LAYER        │         │      MONITORING LAYER                │
│                         │         │                                      │
│  ┌──────────────────┐   │         │  ┌────────────────────────────────┐ │
│  │  Local-Path      │   │         │  │  Prometheus                    │ │
│  │  (default)       │   │         │  │  • Scrapes metrics from pods   │ │
│  │  • Fast          │   │         │  │  • Stores time-series data     │ │
│  │  • Node-local    │   │         │  │  • Alerts on thresholds        │ │
│  └──────────────────┘   │         │  └────────────┬───────────────────┘ │
│                         │         │               │                     │
│  ┌──────────────────┐   │         │               │ Visualized by       │
│  │  Longhorn        │   │         │               ▼                     │
│  │  (optional)      │   │         │  ┌────────────────────────────────┐ │
│  │  • Replicated    │   │         │  │  Grafana                       │ │
│  │  • Snapshots     │   │         │  │  • Dashboards                  │ │
│  │  • HA storage    │   │         │  │  • Alerts visualization        │ │
│  └──────────────────┘   │         │  │  • User-facing UI              │ │
│                         │         │  └────────────────────────────────┘ │
│  ┌──────────────────┐   │         └─────────────────────────────────────┘
│  │  MinIO (S3)      │   │
│  │  • Object storage│   │
│  │  • Backups       │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

## Management & Development Tools Flow

```
                 ┌─────────────────────────────────────┐
                 │         DEVELOPER WORKFLOW          │
                 └──────────────┬──────────────────────┘
                                │
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────┐        ┌──────────────┐       ┌──────────────┐
│   PORTAINER  │        │  GIT SERVER  │       │   REGISTRY   │
│   (Web UI)   │        │ (Gitea/GitLab)│       │ (Docker Reg) │
│              │        │              │       │              │
│ • View pods  │        │ • Git repos  │       │ • Store      │
│ • Deploy     │        │ • CI/CD      │       │   images     │
│ • Logs       │        │ • Webhooks   │       │ • Private    │
│ • Exec       │        │              │       │   registry   │
└──────────────┘        └──────┬───────┘       └──────┬───────┘
                               │                      │
                               │ Push trigger         │ Push image
                               ▼                      ▼
                        ┌──────────────────────────────────┐
                        │       CI/CD PIPELINE             │
                        │                                  │
                        │  1. Code pushed to Git           │
                        │  2. Webhook triggers build       │
                        │  3. Build Docker image           │
                        │  4. Push to Registry             │
                        │  5. Deploy to Kubernetes         │
                        └──────────────┬───────────────────┘
                                       │
                                       │ kubectl apply
                                       ▼
                        ┌──────────────────────────────────┐
                        │    KUBERNETES CLUSTER            │
                        │  (deploys new version)           │
                        └──────────────────────────────────┘
```

## Storage Architecture Detail

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        APPLICATION POD                                   │
│  Container needs persistent storage                                      │
└──────────────────┬──────────────────────────────────────────────────────┘
                   │
                   │ Requests PVC (PersistentVolumeClaim)
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     STORAGE CLASSES                                      │
│                                                                          │
│  ┌──────────────────┐                    ┌──────────────────┐           │
│  │   local-path     │                    │    longhorn      │           │
│  │   (default)      │                    │   (replicated)   │           │
│  └────────┬─────────┘                    └────────┬─────────┘           │
│           │                                       │                     │
└───────────┼───────────────────────────────────────┼─────────────────────┘
            │                                       │
            │ Provisions PV                         │ Provisions PV
            │                                       │
            ▼                                       ▼
┌───────────────────────┐          ┌────────────────────────────────────┐
│  LOCAL-PATH VOLUME    │          │      LONGHORN VOLUME               │
│                       │          │                                    │
│  • Stored on single   │          │  ┌─────────────┐ ┌─────────────┐  │
│    node's disk        │          │  │  Replica 1  │ │  Replica 2  │  │
│  • Fast               │          │  │  (Worker 1) │ │  (Worker 2) │  │
│  • No redundancy      │          │  └─────────────┘ └─────────────┘  │
│                       │          │  ┌─────────────┐                  │
│  /opt/local-path-     │          │  │  Replica 3  │                  │
│  provisioner/         │          │  │  (Worker 3) │                  │
│  pvc-xxx/             │          │  └─────────────┘                  │
│                       │          │                                    │
│  ❌ Pod dies if node  │          │  ✅ Survives node failure          │
│     fails             │          │  ✅ Snapshots & backups            │
│                       │          │                                    │
└───────────────────────┘          └────────────────────────────────────┘
```

## Security Boundaries

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL NETWORK                                 │
│  • Untrusted                                                             │
│  • Firewall rules control access                                         │
└──────────────────┬──────────────────────────────────────────────────────┘
                   │
                   │ Allowed ports: LoadBalancer IPs, NodePorts
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      CLUSTER PERIMETER                                   │
│  • MetalLB LoadBalancer IPs                                              │
│  • NodePort services (30000-32767)                                       │
│  • Ingress controller (80, 443)                                          │
└──────────────────┬──────────────────────────────────────────────────────┘
                   │
                   │ Routes to services
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     KUBERNETES RBAC                                      │
│  • ServiceAccounts                                                       │
│  • Roles and RoleBindings                                                │
│  • ClusterRoles and ClusterRoleBindings                                  │
│  Example: Portainer has cluster-admin                                    │
└──────────────────┬──────────────────────────────────────────────────────┘
                   │
                   │ Controls access to Kubernetes API
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        NAMESPACES                                        │
│  Logical isolation boundaries                                            │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   default   │  │  portainer  │  │  metallb-   │  │ monitoring  │   │
│  │             │  │             │  │   system    │  │             │   │
│  │ Your apps   │  │ Management  │  │ Networking  │  │ Observability│  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │  registry   │  │    minio    │  │     git     │  │  longhorn-  │   │
│  │             │  │             │  │             │  │   system    │   │
│  │ Container   │  │   Storage   │  │ Source Ctrl │  │  Storage    │   │
│  │  Registry   │  │             │  │             │  │             │   │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```
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
