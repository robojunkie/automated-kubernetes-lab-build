# Cluster Backup & Restore Guide

## Overview

Sometimes you need to rebuild your Kubernetes cluster (upgrade, fix issues, start fresh) but **don't want to lose your deployed applications and configurations**. This guide shows you how to preserve your work using the built-in backup and restore system.

---

## When to Use Backup/Restore

### ✅ Good Reasons to Rebuild with Backup
- **Upgrade Kubernetes version**
- **Fix corrupted cluster state**
- **Change cluster networking (CNI, IP ranges)**
- **Restructure node layout**
- **Test cluster rebuild process**
- **Migrate to different hardware**

### ❌ When You DON'T Need This
- **Adding/removing worker nodes** - Just modify existing cluster
- **Deploying new applications** - Use Portainer or kubectl
- **Updating existing apps** - Use Portainer or kubectl apply
- **Minor configuration changes** - Modify in place

---

## What Gets Backed Up

### 🎯 Portainer (Always)
- **Configuration**: Settings, endpoints, users
- **Data**: Stored in PersistentVolumeClaims
- **Manifests**: Deployment, services, secrets

### 📦 Optional: All Applications
Use `--all-namespaces` flag to backup:
- **User deployments**: All your deployed apps
- **ConfigMaps & Secrets**: Application configuration
- **Services & Ingresses**: Network configuration
- **PersistentVolumeClaims**: Application data
- **RBAC**: ServiceAccounts, Roles, RoleBindings

### ⚙️ Cluster Configuration
- **MetalLB IP pools**: LoadBalancer IP ranges
- **Cluster info**: Node information, versions

### ❌ What's NOT Backed Up
- **System namespaces**: kube-system, calico-system, metallb-system
- **Node OS configuration**: Installed packages, system settings
- **Container images**: Re-download from registry after restore
- **Ephemeral data**: Logs, temporary files

---

## Quick Start Guide

### Method 1: Automated (Recommended)

When you run `./scripts/build-lab.sh`, it automatically detects existing clusters:

```bash
cd automated-kubernetes-lab-build
./scripts/build-lab.sh
```

**You'll see**:
```
========================================
EXISTING CLUSTER DETECTED!
========================================

You have the following options:
  1. NUCLEAR OPTION - Fresh install (destroys everything)
  2. PRESERVE & REBUILD - Backup data, rebuild cluster, restore data
  3. CANCEL - Exit without making changes

Choose option [1/2/3]:
```

**Choose Option 2** for preservation:
1. ✅ Script backs up your cluster automatically
2. ✅ Cluster is rebuilt from scratch
3. ✅ After rebuild, you're prompted to restore
4. ✅ Your applications and data are back!

### Method 2: Manual Backup/Restore

If you prefer manual control:

**Step 1: Backup Current Cluster**
```bash
# Backup Portainer only (faster)
./scripts/backup-cluster.sh

# Or backup everything
./scripts/backup-cluster.sh --all-namespaces
```

**Step 2: Rebuild Cluster**
```bash
./scripts/build-lab.sh
# Choose option 1 (Nuclear) or option 3 (Cancel) since you already have backup
```

**Step 3: Restore After Rebuild**
```bash
# Find your backup directory
ls -d cluster-backup-*

# Restore
./scripts/restore-cluster.sh --backup-dir cluster-backup-20260108-143000
```

---

## Detailed Workflow Examples

### Example 1: Upgrading Kubernetes Version

**Scenario**: You want to upgrade from Kubernetes 1.28 to 1.29

```bash
# 1. Backup current cluster
./scripts/backup-cluster.sh --all-namespaces

# Output: Backup saved to cluster-backup-20260108-143000

# 2. Modify build-lab.sh to use K8s 1.29 (or wait for update)
# Edit: K8S_VERSION="1.29"

# 3. Rebuild cluster
./scripts/build-lab.sh
# Choose option 1 (Nuclear)

# 4. After rebuild completes, restore
export KUBECONFIG=./my-lab-kubeconfig.yaml
./scripts/restore-cluster.sh --backup-dir cluster-backup-20260108-143000 --all-namespaces

# 5. Verify
kubectl get nodes
kubectl get pods -A
```

### Example 2: Changing Networking Setup

**Scenario**: You want to change from Calico VXLAN to IPIP mode

```bash
# 1. Backup (Portainer only is fine)
./scripts/backup-cluster.sh

# 2. Rebuild with new CNI settings
./scripts/build-lab.sh
# Choose option 1 (Nuclear)
# Configure with new networking options

# 3. Restore Portainer
./scripts/restore-cluster.sh --backup-dir cluster-backup-20260108-143000 --portainer-only

# 4. Redeploy your apps through Portainer UI
# (Networking change may require app redeployment anyway)
```

### Example 3: Testing Cluster Rebuild

**Scenario**: You want to practice rebuilding before you actually need to

```bash
# 1. Backup current working cluster
./scripts/backup-cluster.sh --all-namespaces

# 2. Test rebuild process
./scripts/build-lab.sh
# Choose option 2 (Preserve & Rebuild)
# Let it backup and rebuild automatically

# 3. Verify restore worked
kubectl get pods -A
# Access Portainer and verify your apps are there

# 4. If test failed, you still have your backup!
```

---

## Backup Script Options

### Basic Usage
```bash
./scripts/backup-cluster.sh [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--backup-dir PATH` | Custom backup location | `./cluster-backup-TIMESTAMP` |
| `--kubeconfig PATH` | Path to kubeconfig | `~/.kube/config` |
| `--portainer-only` | Only backup Portainer | ✅ Yes (default) |
| `--all-namespaces` | Backup all user namespaces | ❌ No |
| `--help` | Show help | - |

### Examples

**Portainer Only (Fast)**:
```bash
./scripts/backup-cluster.sh
# Takes 2-3 minutes
# Backup size: ~10-50MB
```

**Everything (Slower but Complete)**:
```bash
./scripts/backup-cluster.sh --all-namespaces
# Takes 5-15 minutes depending on data
# Backup size: Varies by your applications
```

**Custom Location**:
```bash
./scripts/backup-cluster.sh --backup-dir /mnt/backup/k8s-backup
```

---

## Restore Script Options

### Basic Usage
```bash
./scripts/restore-cluster.sh --backup-dir PATH [options]
```

### Options

| Option | Description | Required |
|--------|-------------|----------|
| `--backup-dir PATH` | Backup directory location | ✅ Yes |
| `--portainer-only` | Only restore Portainer | Default |
| `--all-namespaces` | Restore all backed up namespaces | Optional |
| `--help` | Show help | - |

### Examples

**Restore Portainer Only**:
```bash
./scripts/restore-cluster.sh --backup-dir cluster-backup-20260108-143000
```

**Restore Everything**:
```bash
./scripts/restore-cluster.sh --backup-dir cluster-backup-20260108-143000 --all-namespaces
```

---

## What Happens During Backup

### Phase 1: Cluster Information
- ✅ Saves cluster info, node list, version
- ✅ Copies kubeconfig file

### Phase 2: Resource Manifests
- ✅ Exports all Kubernetes resources as YAML
- ✅ Includes: Deployments, Services, ConfigMaps, Secrets, PVCs, etc.
- ✅ Organized by namespace

### Phase 3: Persistent Data
- ✅ Creates backup jobs for each PVC
- ✅ Tars up volume data
- ✅ Saves to backup directory

### Phase 4: Metadata
- ✅ Creates backup manifest
- ✅ Generates restore instructions
- ✅ Timestamps everything

**Backup Directory Structure**:
```
cluster-backup-20260108-143000/
├── backup-manifest.txt          # What was backed up
├── HOW_TO_RESTORE.txt          # Instructions
├── cluster-info.txt            # Cluster details
├── nodes.txt                   # Node information
├── configs/
│   ├── kubeconfig.yaml
│   ├── metallb-ipaddresspools.yaml
│   └── metallb-l2advertisements.yaml
├── portainer/
│   └── portainer/
│       ├── deployments.yaml
│       ├── services.yaml
│       ├── persistentvolumeclaims.yaml
│       └── secrets.yaml
├── pvcs/
│   ├── portainer-portainer-pvc.yaml
│   └── data/
│       └── portainer-pvc.tar.gz  # Actual data!
└── resources/                    # If --all-namespaces
    ├── my-app-namespace/
    └── another-namespace/
```

---

## What Happens During Restore

### Phase 1: Pre-Check
- ✅ Verifies backup directory exists
- ✅ Confirms cluster is accessible
- ✅ Shows backup information
- ✅ Asks for confirmation

### Phase 2: MetalLB Configuration
- ✅ Restores IP address pools
- ✅ Restores L2 advertisements
- ✅ Ensures LoadBalancer IPs are preserved

### Phase 3: Portainer Restore
- ✅ Creates portainer namespace
- ✅ Applies all Portainer resources
- ✅ Waits for pods to be ready
- ✅ Restores PVC data
- ✅ Shows access URL

### Phase 4: Application Restore (if --all-namespaces)
- ✅ Creates user namespaces
- ✅ Restores resources in dependency order
- ✅ Restores PVC data for each app
- ✅ Waits for pods to stabilize

**Restore takes**: 5-10 minutes typically

---

## Troubleshooting

### Backup Issues

**Problem**: "Cannot connect to Kubernetes cluster"
```bash
# Solution: Ensure cluster is running and kubeconfig is set
kubectl cluster-info
export KUBECONFIG=/path/to/kubeconfig.yaml
```

**Problem**: "Backup job timed out for PVC"
```bash
# Solution: PVC might be very large or slow storage
# The manifest is still backed up, but data might not be
# Check: ls -lh cluster-backup-*/pvcs/data/
```

**Problem**: "No permission to access PVC"
```bash
# Solution: Ensure you're using admin kubeconfig
# Run backup as the user who deployed the cluster
```

### Restore Issues

**Problem**: "PVC not binding"
```bash
# Solution: Ensure storage class is available
kubectl get storageclass

# If using Longhorn, deploy it first:
./container-scripts/storage/deploy-longhorn.sh <master-ip>
```

**Problem**: "Pods stuck in Pending"
```bash
# Solution: Check events and resources
kubectl get events -n portainer --sort-by='.lastTimestamp'
kubectl describe pod -n portainer <pod-name>

# Common: Insufficient resources or storage
```

**Problem**: "Portainer data is empty after restore"
```bash
# Solution: Check if data backup exists
ls -lh cluster-backup-*/pvcs/data/

# If no data backup: PVC data wasn't captured
# Restore will work but Portainer starts fresh
```

---

## Best Practices

### 📅 Regular Backups
```bash
# Create cron job for weekly backups
crontab -e

# Add: Weekly backup on Sunday at 2 AM
0 2 * * 0 /path/to/automated-kubernetes-lab-build/scripts/backup-cluster.sh --all-namespaces
```

### 💾 Backup Storage
- **Keep backups separate** from cluster nodes
- **Store on NAS** or external storage
- **Test restores regularly** (monthly)
- **Keep multiple backups** (last 3-4)
- **Document what's backed up**

### ⚡ Before Major Changes
Always backup before:
- Upgrading Kubernetes
- Changing CNI plugin
- Modifying networking
- Adding/removing nodes
- Major application updates

### 🧪 Test Your Backups
```bash
# Every month, test restore process:
# 1. Backup current cluster
# 2. Restore to test environment
# 3. Verify applications work
# 4. Document any issues
```

---

## Limitations

### ⚠️ Important Notes

**Container Images**:
- Images are NOT backed up
- They're re-downloaded from registry after restore
- **Solution**: Use your own container registry deployed in the cluster

**System Components**:
- CNI plugins are redeployed (not restored)
- MetalLB is redeployed (but config is restored)
- Ingress controllers need redeployment

**StatefulSets**:
- Data is backed up from PVCs
- Restore may require manual ordering
- Test StatefulSet restores carefully

**External Dependencies**:
- LoadBalancer IPs (restored from MetalLB config)
- External DNS (needs reconfiguration)
- External databases (not backed up)

---

## FAQ

**Q: How long does backup take?**  
A: Portainer only: 2-3 minutes. All namespaces: 5-15 minutes depending on data size.

**Q: How much disk space do I need?**  
A: Depends on your PVC data. Typically 100MB - 10GB. Check with `du -sh cluster-backup-*`

**Q: Can I restore to a different cluster?**  
A: Yes! But ensure similar configuration (storage classes, networking). Test thoroughly.

**Q: Do I need to backup every time I rebuild?**  
A: No, only when you have data you want to preserve. Fresh labs don't need backup.

**Q: What if restore fails partway through?**  
A: Restore script is idempotent - run it again. Or manually apply from backup directory YAMLs.

**Q: Can I schedule automatic backups?**  
A: Yes! Use cron. See "Best Practices" section above.

**Q: Does this work with all storage types?**  
A: Works best with local-path and Longhorn. Other storage types may need testing.

---

## Additional Resources

- **Backup Script**: [scripts/backup-cluster.sh](../scripts/backup-cluster.sh)
- **Restore Script**: [scripts/restore-cluster.sh](../scripts/restore-cluster.sh)
- **Main Documentation**: [GETTING_STARTED.md](../GETTING_STARTED.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Remember**: Test your backup and restore process before you actually need it! 🔒💾
