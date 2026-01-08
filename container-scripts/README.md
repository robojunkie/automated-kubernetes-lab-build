# Container Scripts - Modular Deployment Tools

Deploy additional infrastructure to your Kubernetes cluster after the base installation.

## Quick Start

All scripts require your master node IP as the first argument:

```bash
./container-scripts/networking/deploy-ingress.sh 192.168.1.202
```

## Directory Structure

### 📡 networking/
- **deploy-ingress.sh** - Nginx Ingress Controller for hostname-based routing
- **deploy-cert-manager.sh** - Automatic TLS certificate management

### 💾 storage/
- **deploy-longhorn.sh** - Distributed storage with replication
- **deploy-minio.sh** - S3-compatible object storage

### 📊 monitoring/
- **deploy-monitoring.sh** - Prometheus + Grafana stack

### 🔧 devtools/
- **deploy-registry.sh** - Private Docker registry with web UI
- **deploy-gitea.sh** - Lightweight Git server
- **deploy-gitlab.sh** - Full-featured Git platform (coming soon)

## Usage Examples

### Deploy Nginx Ingress
```bash
cd /path/to/automated-kubernetes-lab-build
./container-scripts/networking/deploy-ingress.sh 192.168.1.202 false
```
- First arg: Master node IP
- Second arg: Use LoadBalancer? (true/false, default: false)

### Deploy Container Registry
```bash
./container-scripts/devtools/deploy-registry.sh 192.168.1.202 false 20Gi
```
- First arg: Master node IP
- Second arg: Use LoadBalancer? (true/false, default: false)
- Third arg: Storage size (default: 20Gi)

### Deploy Monitoring Stack
```bash
./container-scripts/monitoring/deploy-monitoring.sh 192.168.1.202
```

### Deploy Longhorn Storage
```bash
./container-scripts/storage/deploy-longhorn.sh 192.168.1.202 false
```

### Deploy MinIO
```bash
./container-scripts/storage/deploy-minio.sh 192.168.1.202 false 10Gi
```

### Deploy Cert-Manager
```bash
./container-scripts/networking/deploy-cert-manager.sh 192.168.1.202
```

### Deploy Gitea
```bash
./container-scripts/devtools/deploy-gitea.sh 192.168.1.202
```

## LoadBalancer vs NodePort

Each script accepts a second parameter for service type:

- **`false`** or omit: Uses NodePort (access via `http://<node-ip>:<port>`)
- **`true`**: Uses LoadBalancer (requires MetalLB, gets dedicated IP)

## Prerequisites

Scripts assume:
- ✅ Kubernetes cluster is running
- ✅ Local-path storage provisioner is available
- ✅ kubectl configured on master node
- ✅ SSH access from jump box to master node

## Make Scripts Executable

```bash
chmod +x container-scripts/**/*.sh
```

## Alternative: Deploy via Portainer

All these components can also be deployed through Portainer's UI:
1. Access Portainer dashboard
2. Navigate to Helm charts or App Templates
3. Search for component (e.g., "ingress-nginx", "prometheus")
4. Click Install and configure

See `docs/quickstart/` for Portainer deployment guides.

## Troubleshooting

### Script fails with "command not found"
- Ensure you're running from the project root directory
- Check that helper scripts exist in `scripts/helpers/`

### SSH connection refused
- Verify master IP is correct
- Ensure SSH key is configured: `ssh root@<master-ip> echo test`

### Pods stuck in Pending
- Check storage: `kubectl get pvc -A`
- Check node resources: `kubectl describe node`

### Service not accessible
- Verify service type: `kubectl get svc -A`
- Check firewall rules on nodes
- Ensure MetalLB is running (if using LoadBalancer)

## Component Dependencies

Some components depend on others:

- **Cert-Manager** → Works best with Ingress
- **Longhorn** → Requires iSCSI packages (auto-installed)
- **Monitoring** → Needs ~2GB RAM for full stack
- **GitLab** → Requires 4GB+ RAM (use Gitea for lighter option)

## Contributing

To add a new deployment script:

1. Create script in appropriate category folder
2. Follow the template pattern (see existing scripts)
3. Add usage info to this README
4. Test on both Ubuntu and Rocky Linux
5. Submit PR

## Support

- See main documentation: `GETTING_STARTED.md`
- Component guides: `docs/quickstart/`
- Troubleshooting: `docs/TROUBLESHOOTING.md`
- Issues: GitHub Issues

---

**Tip**: Start with `deploy-ingress.sh` and `deploy-cert-manager.sh` for hostname-based access with TLS!
