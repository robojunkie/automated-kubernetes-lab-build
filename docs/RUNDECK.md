# Rundeck - Operations Dashboard

Rundeck provides a web-based self-service operations dashboard for managing Kubernetes cluster maintenance tasks.

## Features

- **Web UI** - No kubectl or SSH access needed
- **Pre-configured Jobs** - Common maintenance tasks ready to use
- **RBAC** - Role-based access control for family members
- **Audit Trail** - All job executions are logged
- **Scheduling** - Automate recurring tasks (health checks, backups)

## Deployment

### Quick Start

```bash
bash scripts/deploy-rundeck.sh
```

This will deploy Rundeck with:
- LoadBalancer service (assigned IP from MetalLB pool)
- Persistent storage for job history
- ServiceAccount with cluster-admin rights
- Pre-built maintenance scripts

### Custom Deployment

```bash
# Custom release name and namespace
bash scripts/deploy-rundeck.sh my-rundeck ops

# Or use Helm directly
helm install rundeck helm-charts/rundeck \
  --namespace rundeck \
  --create-namespace \
  --set rundeck.adminPassword=MySecurePassword123
```

## Initial Setup

After deployment:

1. **Access Rundeck** at `http://<LOADBALANCER-IP>:4440`
2. **Login** with admin credentials (shown in deployment output)
3. **Create a Project**:
   - Click "New Project"
   - Name: `Kubernetes` (or your choice)
   - Save
4. **Import Jobs**:
   - Navigate to Jobs → gear icon → Upload Definition
   - Upload `helm-charts/rundeck/jobs.yaml`
   - All maintenance jobs will be imported
5. **Configure Node Source**:
   - Project Settings → Edit Nodes
   - Add "Local Node" as execution target
   - Default hostname: `localhost`

## Available Jobs

### Fix MetalLB LoadBalancers
Restarts MetalLB speaker pods to re-announce LoadBalancer IPs. Use when services become unreachable after cluster restarts.

**Usage**: Click "Run" - no parameters needed

### Restart Service/Deployment
Gracefully restarts any Kubernetes deployment.

**Parameters**:
- `namespace`: Target namespace (e.g., wordpress, portainer)
- `deployment`: Deployment name

### Backup Cluster Resources
Backs up all cluster resources to YAML files.

**Usage**: Click "Run" - creates timestamped backup directory

### Check Cluster Health
Comprehensive health check of nodes, pods, services, and storage.

**Usage**: Click "Run" - can be scheduled to run automatically

### Scale Deployment
Change the number of replicas for a deployment.

**Parameters**:
- `namespace`: Target namespace
- `deployment`: Deployment name
- `replicas`: Desired replica count (0 to stop)

### List LoadBalancer Services
Shows all LoadBalancer services with their external IPs.

### List All Pods
Quick view of all pods across all namespaces.

### List PersistentVolumeClaims
Shows all PVCs and their status.

## User Management

### Creating Additional Users

1. Go to System Menu (gear icon) → User Profiles
2. Click "New User"
3. Set username and roles
4. For read-only users: assign "user" role
5. For operators: assign "admin" role

### RBAC Recommendations

For family members who need limited access:

```yaml
# Edit values.yaml before deployment
rbac:
  clusterAdmin: false  # Limit to specific namespaces
```

Then create RoleBindings for specific namespaces instead of ClusterRoleBinding.

## Customization

### Adding New Jobs

1. Create job definition in Rundeck UI or YAML
2. Export and add to `helm-charts/rundeck/jobs.yaml`
3. Scripts go in ConfigMap: `helm-charts/rundeck/templates/configmap.yaml`

### Adding Scripts

Edit the ConfigMap to add new maintenance scripts:

```yaml
data:
  my-script.sh: |
    #!/bin/bash
    # Your script here
```

Then reference in job definition:

```yaml
commands:
  - exec: /scripts/my-script.sh
```

## Troubleshooting

### Rundeck Pod Won't Start

```bash
kubectl logs -n rundeck deployment/rundeck
kubectl describe pod -n rundeck -l app=rundeck
```

Common issues:
- PVC not bound (check storage class)
- Resource limits too low (increase in values.yaml)

### Jobs Fail with Permission Errors

The ServiceAccount needs proper RBAC. Verify:

```bash
kubectl get clusterrolebinding rundeck-admin
```

Should show cluster-admin role bound to rundeck ServiceAccount.

### LoadBalancer IP Not Assigned

Check MetalLB:

```bash
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l component=speaker
```

## Backup and Restore

### Backup Rundeck Data

Rundeck data is stored in PVC `rundeck-data`. Back up:

```bash
kubectl exec -n rundeck deployment/rundeck -- tar czf - /home/rundeck/server/data > rundeck-backup.tar.gz
```

### Restore

```bash
kubectl exec -n rundeck deployment/rundeck -i -- tar xzf - -C / < rundeck-backup.tar.gz
kubectl rollout restart deployment/rundeck -n rundeck
```

## Integration with Lab

Rundeck is designed to work with the automated Kubernetes lab:

- **Portainer** - For visual container management
- **Rundeck** - For operational tasks and automation
- **Backup/Restore** - Integrate with existing backup scripts

Family members can use Portainer for viewing containers and Rundeck for running maintenance tasks without needing kubectl expertise.

## Security Notes

### Production Use

For production or internet-exposed deployments:

1. **Change default password** in values.yaml
2. **Enable TLS** - Configure ingress with cert-manager
3. **Limit RBAC** - Use namespace-specific roles instead of cluster-admin
4. **Enable authentication** - Integrate with LDAP/OAuth
5. **Network policies** - Restrict Rundeck pod access

### Home Lab Use

The default configuration is suitable for trusted home networks:
- Basic authentication
- cluster-admin access for full management
- LoadBalancer on private network

## Resources

- CPU: 250m-1000m
- Memory: 512Mi-2Gi
- Storage: 10Gi PVC

Adjust in `values.yaml` based on usage.

## Uninstallation

```bash
helm uninstall rundeck -n rundeck
kubectl delete namespace rundeck
```

This removes all Rundeck resources. PVC data is retained unless manually deleted.
