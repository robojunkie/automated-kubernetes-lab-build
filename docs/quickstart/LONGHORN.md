# Longhorn Storage Quick Start Guide

Distributed, cloud-native storage for Kubernetes with replication and snapshots.

## What is Longhorn?

Longhorn provides persistent storage for your Kubernetes cluster with enterprise features:
- **Replication** - Data copied across multiple nodes (high availability)
- **Snapshots** - Point-in-time backups
- **Disaster Recovery** - Backup to S3/NFS and restore
- **Volume Management** - Easy resize, attach/detach
- **Web UI** - Visual storage management

**Think of it as**: Enterprise SAN storage, but cloud-native and open-source

## When to Use Longhorn vs Local-Path

| Feature | Local-Path | Longhorn |
|---------|-----------|----------|
| Speed | Fast (local disk) | Moderate (network replication) |
| High Availability | ❌ No (pod dies if node dies) | ✅ Yes (replicated across nodes) |
| Snapshots | ❌ No | ✅ Yes |
| Backups | ❌ Manual | ✅ Automated to S3/NFS |
| Complexity | Simple | More complex |
| Resources | Minimal | Higher (3 replicas = 3x storage) |

**Use Local-Path for**: Development, testing, non-critical data
**Use Longhorn for**: Production, databases, critical applications

## Accessing Longhorn UI

**With LoadBalancer**:
```bash
kubectl get svc -n longhorn-system longhorn-frontend

# Access at: http://<EXTERNAL-IP>
```

**With NodePort**:
```bash
# Access at: http://<any-node-ip>:30800
# Example: http://192.168.1.206:30800
```

**No authentication** by default (this is a lab setup)

## Longhorn Dashboard Tour

### Main Sections

**📦 Volume** - Manage persistent volumes
**🖥️ Node** - View storage on each node
**📸 Recurring Job** - Automated snapshots and backups
**⚙️ Setting** - Configuration
**🚨 Events** - Recent activity and errors

### Volume Tab

Shows all Longhorn volumes:
- **Name** - PVC name
- **Size** - Volume size
- **Replicas** - Number of copies (default: 3)
- **State** - Attached, Detached, Degraded
- **Robustness** - Healthy, Degraded, Faulted

**Click a volume** to see:
- Detailed stats
- Snapshot management
- Backup configuration
- Volume operations (attach, detach, resize)

### Node Tab

Shows storage capacity per node:
- **Schedulable** - Can new volumes be placed here?
- **Allocatable** - Available storage
- **Used** - Storage in use
- **Reserved** - Reserved for system

**Click a node** to see:
- Disks on that node
- Replicas stored on that node
- Node health

## Creating Your First Longhorn Volume

### Method 1: Via PVC (Recommended)

```yaml
# pvc-longhorn.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-longhorn-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

```bash
kubectl apply -f pvc-longhorn.yaml
kubectl get pvc my-longhorn-pvc
# Should show Bound status
```

Check in Longhorn UI → **Volume** tab - you'll see `pvc-xxx-my-longhorn-pvc`!

### Method 2: Via Longhorn UI

1. **Volume** tab → **Create Volume**
2. **Name**: `test-volume`
3. **Size**: `5 Gi`
4. **Number of Replicas**: `3` (for 3 workers) or `2` (for smaller cluster)
5. **Access Mode**: `ReadWriteOnce`
6. Click **OK**

Volume created! But it's **Detached** - needs to be attached to a pod.

## Using Longhorn Volumes

### Deploy Application with Longhorn

```yaml
# app-with-longhorn.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1  # Databases typically run 1 replica with shared storage
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_PASSWORD
          value: "mysecretpassword"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
```

```bash
kubectl apply -f app-with-longhorn.yaml

# Check PVC
kubectl get pvc postgres-data
# Should be Bound

# Check pod
kubectl get pods -l app=postgres
# Should be Running
```

**In Longhorn UI**:
- Volume tab shows `pvc-xxx-postgres-data` as **Attached**
- 3 replicas distributed across nodes
- Data is now being replicated!

## Taking Snapshots

### Manual Snapshot

**Via Longhorn UI**:
1. **Volume** tab → Click your volume
2. **Take Snapshot** button
3. Snapshot appears in **Snapshot and Backups** section
4. Name it: "before-upgrade" or similar

**Via kubectl** (snapshot custom resource):
```yaml
apiVersion: longhorn.io/v1beta2
kind: Snapshot
metadata:
  name: postgres-snapshot-001
  namespace: longhorn-system
spec:
  volume: pvc-xxx-postgres-data
```

### Restoring from Snapshot

1. **Volume** → Click volume → **Snapshot and Backups**
2. Find your snapshot
3. Click **⋮** (three dots) → **Restore**
4. Choose:
   - **Restore to new volume** (create separate volume from snapshot)
   - **Restore in place** (overwrite current volume - destructive!)

For new volume:
- **Name**: `postgres-data-restored`
- Click **OK**

Now create new PVC referencing the restored volume, or use Longhorn UI to attach it.

### Automated Snapshots (Recurring Jobs)

**Via Longhorn UI**:
1. **Recurring Job** tab → **Create Recurring Job**
2. **Name**: `daily-snapshot`
3. **Task**: `Snapshot`
4. **Schedule**: `0 2 * * *` (2 AM daily, cron format)
5. **Retain**: `7` (keep 7 snapshots)
6. **Labels**: Add label to select volumes (e.g., `recurring-job=snapshot`)
7. Click **OK**

**Apply to volumes**:
1. **Volume** tab → Click volume
2. **Recurring Jobs** section → **Attach Recurring Job**
3. Select `daily-snapshot`
4. Click **OK**

Now snapshots are taken automatically every day at 2 AM!

## Backups to External Storage

Snapshots are great, but they're stored in the cluster. For true disaster recovery, back up to external storage.

### Configure Backup Target (S3)

**Via Longhorn UI**:
1. **Setting** tab → **General** section
2. **Backup Target**: 
   ```
   s3://my-backup-bucket@us-east-1/longhorn-backups
   ```
   Or with MinIO:
   ```
   s3://longhorn-backups@minio/
   ```
3. **Backup Target Credential Secret**:
   ```yaml
   # Create secret first
   apiVersion: v1
   kind: Secret
   metadata:
     name: minio-credentials
     namespace: longhorn-system
   type: Opaque
   data:
     AWS_ACCESS_KEY_ID: bWluaW9hZG1pbg==     # base64 of "minioadmin"
     AWS_SECRET_ACCESS_KEY: bWluaW9hZG1pbg== # base64 of "minioadmin"
     AWS_ENDPOINTS: aHR0cDovL21pbmlvLm1pbmlvLnN2Yy5jbHVzdGVyLmxvY2FsOjkwMDA= # base64 of MinIO URL
   ```
   
   ```bash
   kubectl apply -f minio-credentials.yaml
   ```
   
   Then in Longhorn UI, enter: `minio-credentials`

4. Click **Save**

### Manual Backup

1. **Volume** tab → Click volume → **Snapshot and Backups**
2. Take a snapshot first (or use existing)
3. Click **⋮** next to snapshot → **Backup**
4. Backup starts - monitor progress in **Volume** tab (look for "backing up")

**Backup complete!** Data is now stored in S3/MinIO, safe even if cluster is destroyed.

### Automated Backups (Recurring Jobs)

1. **Recurring Job** tab → **Create Recurring Job**
2. **Name**: `weekly-backup`
3. **Task**: `Backup` (not Snapshot!)
4. **Schedule**: `0 3 * * 0` (3 AM every Sunday)
5. **Retain**: `4` (keep 4 backups)
6. Click **OK**

Attach to volumes as before.

### Restoring from Backup

**Scenario**: Cluster destroyed, need to rebuild and restore data

1. **Rebuild cluster** with Longhorn
2. **Configure same backup target** in Settings
3. **Volume** tab → **Create Volume** → **Restore from Backup**
4. **Backup Volume**: Select your backup
5. **Volume Name**: `postgres-data-restored`
6. **Number of Replicas**: 3
7. Click **OK**

Volume recreated from backup! Now create PVC to use it.

## Volume Operations

### Resize Volume

**Via kubectl** (easiest):
```bash
# Edit PVC
kubectl edit pvc postgres-data

# Change:
  resources:
    requests:
      storage: 10Gi
# To:
  storage: 20Gi

# Save and exit
```

**Via Longhorn UI**:
1. Volume must be **Detached**
2. **Volume** tab → Click volume → **Expand Volume**
3. Enter new size → **OK**
4. Reattach to pod

### Attach/Detach Volume

**Detach** (stop pod using it):
```bash
kubectl scale deployment postgres --replicas=0
```

Volume becomes **Detached** in Longhorn UI.

**Attach** (start pod again):
```bash
kubectl scale deployment postgres --replicas=1
```

Volume becomes **Attached**.

### Clone Volume

1. Take a snapshot
2. Restore snapshot to new volume
3. Create new PVC referencing new volume
4. Use in new deployment

Useful for testing with production data!

## Monitoring Longhorn

### Check Volume Health

**Via Longhorn UI**:
- **Volume** tab → Check **Robustness** column
- **Healthy** ✅ - All replicas good
- **Degraded** ⚠️ - Some replicas down (still working, but at risk)
- **Faulted** ❌ - Too many replicas down (data loss possible)

### Check Node Health

**Via Longhorn UI**:
- **Node** tab → Check each node's status
- Green = Schedulable and healthy
- Red = Down or unschedulable

### Check Events

**Via Longhorn UI**:
- Events button (top-right) → Recent activity
- Look for warnings or errors

**Via kubectl**:
```bash
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'
```

## Troubleshooting

### Volume Stuck in "Attaching"

**Check pod events**:
```bash
kubectl describe pod <pod-name>
```

**Common causes**:
- Node where pod is scheduled has no space
- Replicas can't be placed (not enough nodes)
- Network issues between nodes

**Solution**:
1. Check node capacity in Longhorn UI
2. Reduce replica count if cluster is small
3. Check network connectivity between nodes

### Volume "Degraded" Status

**What it means**: One or more replicas are down

**Check replicas**:
1. Longhorn UI → Volume → Click volume
2. Look at **Replica** section
3. See which replicas are down

**Common causes**:
- Node went down
- Disk full on that node
- Network partition

**Solution**:
- If node is permanently down: Longhorn will rebuild replica on another node (automatic)
- If disk full: Free up space or add more disk
- If temporary: Wait for node to come back, replica will sync

### Backup Fails

**Check backup target**:
```bash
# Test S3 connectivity
kubectl exec -it -n longhorn-system <longhorn-manager-pod> -- sh
aws s3 ls --endpoint-url http://minio.minio.svc.cluster.local:9000
```

**Check credentials**:
```bash
kubectl get secret -n longhorn-system minio-credentials
kubectl get secret -n longhorn-system minio-credentials -o yaml
# Verify base64 values are correct
```

**Check logs**:
```bash
kubectl logs -n longhorn-system <longhorn-manager-pod>
```

### High Disk Usage

**Each replica consumes disk space**:
- 3 replicas = 3x storage used
- 10Gi volume with 3 replicas = 30Gi used across cluster

**Check usage**:
Longhorn UI → **Node** tab → See **Used** column

**Solutions**:
- Reduce replica count (2 instead of 3)
- Add more nodes with storage
- Delete unused volumes
- Clean up old snapshots/backups

### Pod Stuck "ContainerCreating" with Longhorn PVC

**Check volume status**:
```bash
kubectl get pv | grep longhorn
kubectl describe pv <pv-name>
```

**Check Longhorn engine**:
```bash
kubectl get pods -n longhorn-system
# All pods should be Running
```

**Check events**:
```bash
kubectl describe pod <pod-name>
# Look for volume attachment errors
```

## Best Practices

### ✅ Do
- Use Longhorn for stateful applications (databases, file storage)
- Set up automated snapshots for critical data
- Configure backup target for disaster recovery
- Monitor volume health regularly
- Use 3 replicas for production, 2 for development
- Test restore procedures before you need them

### ❌ Don't
- Use Longhorn for temporary data (logs, caches - use emptyDir)
- Set too many replicas (uses 3x storage)
- Ignore "Degraded" status (means you're at risk)
- Forget to configure backup target
- Run Longhorn on nodes with slow disks (HDD instead of SSD)
- Create more volumes than your nodes can handle

## Advanced: Disaster Recovery Workflow

### Scenario: Complete Cluster Loss

**Backup Phase** (do this regularly):
1. Configure backup target (S3/MinIO)
2. Set up automated backups (recurring jobs)
3. Verify backups are in S3: `mc ls myminio/longhorn-backups`

**Disaster Strikes** - Cluster is gone!

**Recovery Phase**:
1. **Rebuild cluster** from scratch with this automation framework
2. **Install Longhorn** (already done by script)
3. **Configure same backup target** in Longhorn Settings
4. **Restore volumes**:
   - Longhorn UI → Volume → Create Volume → Restore from Backup
   - Select each backup and restore
5. **Recreate PVCs** (same names as before)
6. **Redeploy applications** (kubectl apply -f ...)
7. **Data is back!** Applications resume with old data

**Test this** before you need it!

## Performance Tuning

### For Better Performance

**Use fast disks**:
- NVMe SSD > SATA SSD > HDD
- Check node disk speed: `dd if=/dev/zero of=/tmp/testfile bs=1G count=1 oflag=direct`

**Reduce replica count**:
- 2 replicas instead of 3 (less network replication)
- Edit volume in Longhorn UI → Change replica count

**Use local-path for read-heavy workloads**:
- Logs, caches, temporary data
- Reserve Longhorn for data that needs HA

**Tune Longhorn settings**:
- Settings → General → **Guaranteed Instance Manager CPU** (increase for faster ops)

## Storage Class Comparison

```yaml
# local-path (default)
storageClassName: local-path
# - Fast (local disk)
# - No HA (pod dies if node dies)
# - Good for: dev, test, logs, caches

# longhorn (replicated)
storageClassName: longhorn
# - Moderate speed (network replication)
# - High availability (survives node failures)
# - Snapshots and backups
# - Good for: databases, production apps, critical data
```

## Next Steps

- Set up automated backups to [MinIO](MINIO.md) or external S3
- Configure [monitoring](MONITORING.md) for Longhorn metrics
- Test disaster recovery by restoring volumes
- Explore Longhorn's Volume Cloning for testing environments
- Integrate Longhorn backups with your overall backup strategy

## References

- Longhorn Docs: https://longhorn.io/docs/
- Best Practices: https://longhorn.io/docs/latest/best-practices/
- Troubleshooting: https://longhorn.io/docs/latest/troubleshooting/
- Architecture: https://longhorn.io/docs/latest/concepts/

---

**Pro tip**: Set up automated backups immediately - you'll thank yourself later when something goes wrong!
