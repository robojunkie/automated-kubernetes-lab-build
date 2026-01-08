# Deploying Infrastructure via Portainer

This guide shows how to deploy additional infrastructure components using Portainer's web interface.

## Prerequisites

- ✅ Kubernetes cluster is running
- ✅ Portainer is installed and accessible
- ✅ You're logged into Portainer dashboard

## Access Portainer

After cluster deployment, access Portainer at:
- **NodePort**: `http://<master-ip>:30777`
- **LoadBalancer**: `http://<portainer-lb-ip>:9000`

Default credentials are set during initial setup.

## Quick Navigation

1. [Nginx Ingress Controller](#nginx-ingress-controller)
2. [Cert-Manager](#cert-manager)
3. [Longhorn Storage](#longhorn-storage)
4. [MinIO Object Storage](#minio-object-storage)
5. [Prometheus + Grafana Monitoring](#prometheus--grafana-monitoring)
6. [Container Registry](#container-registry)
7. [Gitea Git Server](#gitea-git-server)
8. [GitLab](#gitlab)

---

## Nginx Ingress Controller

**Purpose**: Enable hostname-based routing and load balancing for services

### Deployment Steps

1. Navigate to **Helm** → **Charts**
2. Search for "**ingress-nginx**"
3. Click **Install**
4. Configure:
   - **Name**: `ingress-nginx`
   - **Namespace**: Create new → `ingress-nginx`
   - **Values**:
     ```yaml
     controller:
       service:
         type: NodePort  # or LoadBalancer
         nodePorts:
           http: 30080
           https: 30443
       replicaCount: 1
     ```
5. Click **Install**

### Verification

- Check pods: Navigate to **Applications** → **Pods** → Filter by `ingress-nginx`
- Should see `ingress-nginx-controller` pod running

### Access

- HTTP: `http://<node-ip>:30080`
- HTTPS: `http://<node-ip>:30443`

---

## Cert-Manager

**Purpose**: Automatic TLS certificate management

### Deployment Steps

1. **Helm** → **Charts**
2. Search for "**cert-manager**"
3. Click **Install**
4. Configure:
   - **Name**: `cert-manager`
   - **Namespace**: Create new → `cert-manager`
   - **Values**:
     ```yaml
     installCRDs: true
     ```
5. Click **Install**

### Post-Installation: Create ClusterIssuer

1. Navigate to **Custom Resources** → **Create Resource**
2. Paste this YAML:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: selfsigned-issuer
   spec:
     selfSigned: {}
   ```
3. Click **Create**

### Verification

- Check pods in `cert-manager` namespace
- Verify ClusterIssuer: **Custom Resources** → Search "ClusterIssuer"

---

## Longhorn Storage

**Purpose**: Distributed block storage with replication

### Prerequisites

**IMPORTANT**: Install iSCSI packages on ALL nodes first:

**Ubuntu/Debian**:
```bash
apt-get install -y open-iscsi nfs-common
systemctl enable --now iscsid
```

**Rocky Linux/RHEL**:
```bash
dnf install -y iscsi-initiator-utils nfs-utils
systemctl enable --now iscsid
```

### Deployment Steps

1. **Helm** → **Charts**
2. Search for "**longhorn**"
3. Click **Install**
4. Configure:
   - **Name**: `longhorn`
   - **Namespace**: Create new → `longhorn-system`
   - **Values**:
     ```yaml
     defaultSettings:
       defaultReplicaCount: 1
       defaultDataPath: /var/lib/longhorn
     service:
       ui:
         type: NodePort
         nodePort: 30900
     ```
5. Click **Install** (may take 5-10 minutes)

### Access Longhorn UI

- Navigate to: `http://<node-ip>:30900`
- View volumes, replicas, and storage health

### Set as Default StorageClass

1. **Cluster** → **Storage** → **StorageClasses**
2. Find `longhorn`
3. Click **Edit** → Enable **Make Default**

---

## MinIO Object Storage

**Purpose**: S3-compatible object storage for backups and artifacts

### Deployment Steps

1. **Helm** → **Charts**
2. Search for "**minio**"
3. Click **Install**
4. Configure:
   - **Name**: `minio`
   - **Namespace**: Create new → `minio`
   - **Values**:
     ```yaml
     mode: standalone
     persistence:
       size: 10Gi
     service:
       type: NodePort
       nodePort: 30900
     consoleService:
       type: NodePort
       nodePort: 30901
     rootUser: admin
     rootPassword: minio123  # CHANGE THIS!
     ```
5. Click **Install**

### Access MinIO

- **Console**: `http://<node-ip>:30901` (web UI)
- **API**: `http://<node-ip>:30900` (S3 endpoint)
- **Credentials**: `admin` / `minio123` (change these!)

### Create First Bucket

1. Access console UI
2. Click **Buckets** → **Create Bucket**
3. Enter bucket name (e.g., `backups`)
4. Click **Create**

---

## Prometheus + Grafana Monitoring

**Purpose**: Metrics collection and visualization

### Deployment Steps

1. **Helm** → **Charts**
2. Search for "**kube-prometheus-stack**"
3. Click **Install**
4. Configure:
   - **Name**: `monitoring`
   - **Namespace**: Create new → `monitoring`
   - **Values**:
     ```yaml
     prometheus:
       service:
         type: NodePort
         nodePort: 30090
     grafana:
       service:
         type: NodePort
         nodePort: 30300
       adminPassword: admin  # CHANGE THIS!
     alertmanager:
       enabled: false
     ```
5. Click **Install** (may take 5-10 minutes)

### Access Dashboards

- **Grafana**: `http://<node-ip>:30300`
  - Username: `admin`
  - Password: `admin` (change on first login)
- **Prometheus**: `http://<node-ip>:30090`

### Pre-configured Dashboards

Grafana includes 20+ pre-configured dashboards:
- Kubernetes Cluster Overview
- Node Exporter
- Pod Resource Usage
- Persistent Volumes

Navigate: **Dashboards** → **Browse** → Look for "Kubernetes" dashboards

---

## Container Registry

**Purpose**: Private Docker image registry with web UI

### Deployment Steps

#### 1. Deploy Docker Registry

1. **Applications** → **Create Application**
2. Click **Create from Manifest**
3. Paste:
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: registry
   ---
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: registry-pvc
     namespace: registry
   spec:
     accessModes: [ReadWriteOnce]
     resources:
       requests:
         storage: 20Gi
   ---
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: registry
     namespace: registry
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: registry
     template:
       metadata:
         labels:
           app: registry
       spec:
         containers:
         - name: registry
           image: registry:2
           ports:
           - containerPort: 5000
           volumeMounts:
           - name: storage
             mountPath: /var/lib/registry
         volumes:
         - name: storage
           persistentVolumeClaim:
             claimName: registry-pvc
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: registry
     namespace: registry
   spec:
     type: NodePort
     ports:
     - port: 5000
       targetPort: 5000
       nodePort: 30500
     selector:
       app: registry
   ```
4. Click **Deploy**

#### 2. Deploy Registry UI (Joxit)

1. **Applications** → **Create from Manifest**
2. Paste:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: registry-ui
     namespace: registry
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: registry-ui
     template:
       metadata:
         labels:
           app: registry-ui
       spec:
         containers:
         - name: ui
           image: joxit/docker-registry-ui:latest
           ports:
           - containerPort: 80
           env:
           - name: REGISTRY_URL
             value: "http://registry:5000"
           - name: DELETE_IMAGES
             value: "true"
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: registry-ui
     namespace: registry
   spec:
     type: NodePort
     ports:
     - port: 80
       targetPort: 80
       nodePort: 30501
     selector:
       app: registry-ui
   ```
3. Click **Deploy**

### Access Registry

- **Web UI**: `http://<node-ip>:30501`
- **Registry API**: `http://<node-ip>:30500`

### Push Image to Registry

```bash
# Tag image
docker tag myapp:latest <node-ip>:30500/myapp:latest

# Configure Docker to use insecure registry
# Add to /etc/docker/daemon.json:
{
  "insecure-registries": ["<node-ip>:30500"]
}

# Restart Docker
systemctl restart docker

# Push image
docker push <node-ip>:30500/myapp:latest
```

---

## Gitea Git Server

**Purpose**: Lightweight self-hosted Git service

### Deployment Steps

1. **Helm** → **Charts**
2. Search for "**gitea**"
3. Click **Install**
4. Configure:
   - **Name**: `gitea`
   - **Namespace**: Create new → `gitea`
   - **Values**:
     ```yaml
     service:
       http:
         type: NodePort
         nodePort: 30300
     persistence:
       enabled: true
       size: 10Gi
     gitea:
       admin:
         username: gitea_admin
         password: gitea123  # CHANGE THIS!
         email: admin@gitea.local
     ```
5. Click **Install**

### Access Gitea

- Navigate to: `http://<node-ip>:30300`
- Login with configured admin credentials
- Create first repository

---

## GitLab

**Purpose**: Full-featured DevOps platform

### Resource Requirements

⚠️ **WARNING**: GitLab requires significant resources:
- **Minimum 4GB RAM** per node
- **20-30Gi storage** for PostgreSQL, Redis, Gitaly
- Consider Gitea for a lighter alternative

### Deployment Steps

1. **Helm** → **Add Repository**
   - Name: `gitlab`
   - URL: `https://charts.gitlab.io/`
   - Click **Add**

2. **Helm** → **Charts** → Search "**gitlab**"
3. Click **Install**
4. Configure:
   - **Name**: `gitlab`
   - **Namespace**: Create new → `gitlab`
   - **Values**:
     ```yaml
     global:
       edition: ce
       hosts:
         domain: gitlab.local
       ingress:
         enabled: false
     postgresql:
       install: true
       persistence:
         size: 8Gi
     redis:
       install: true
     gitlab:
       gitaly:
         persistence:
           size: 30Gi
       gitlab-shell:
         service:
           type: NodePort
     nginx-ingress:
       enabled: false
     certmanager:
       install: false
     ```
5. Click **Install** (deployment takes 15-20 minutes)

### Access GitLab

1. Wait for all pods to be running (check **Applications** → **Pods**)
2. Get service NodePort:
   - **Applications** → **Services** → `gitlab-webservice`
   - Note the NodePort (usually 30080)
3. Access: `http://<node-ip>:<nodeport>`

### Get Root Password

1. **Config & Storage** → **Secrets**
2. Find `gitlab-gitlab-initial-root-password`
3. Click **View** → Decode base64 value
4. Username: `root`
5. Password: (decoded secret)

⚠️ **Change password immediately after first login!**

---

## Tips and Best Practices

### Storage Management

- Monitor PVC usage: **Config & Storage** → **PersistentVolumeClaims**
- Clean up unused volumes regularly
- Consider Longhorn for production workloads

### Service Discovery

- Use Kubernetes DNS: `<service-name>.<namespace>.svc.cluster.local`
- Example: `registry.registry.svc.cluster.local:5000`

### Security Hardening

1. Change all default passwords immediately
2. Enable RBAC for applications
3. Use NetworkPolicies to restrict traffic
4. Configure TLS with cert-manager
5. Regularly update charts/images

### Networking

- **NodePort**: Simple, works everywhere (ports 30000-32767)
- **LoadBalancer**: Cleaner IPs, requires MetalLB
- **Ingress**: Best for production, requires Ingress Controller

### Troubleshooting

- Check pod logs: **Applications** → **Pods** → Click pod → **Logs**
- View events: **Applications** → **Events**
- Shell into pods: Click pod → **Console**
- Check resource usage: **Cluster** → **Nodes** → View metrics

---

## Alternative: CLI Deployment Scripts

Don't want to use Portainer? Use the CLI deployment scripts instead:

```bash
cd automated-kubernetes-lab-build/container-scripts

# Deploy components individually
./networking/deploy-ingress.sh <master-ip>
./storage/deploy-longhorn.sh <master-ip>
./monitoring/deploy-monitoring.sh <master-ip>
# ... etc
```

See `container-scripts/README.md` for full documentation.

---

## Support

- Main docs: [GETTING_STARTED.md](../GETTING_STARTED.md)
- Component guides: [docs/quickstart/](../docs/quickstart/)
- Troubleshooting: [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
- Issues: GitHub Issues

---

**Happy deploying! 🚀**
