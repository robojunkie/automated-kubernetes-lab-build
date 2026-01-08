# Storage Deployment Scripts

Deploy persistent storage solutions for your Kubernetes cluster.

---

## 💾 Longhorn - Distributed Block Storage

**Script**: `deploy-longhorn.sh`

### What It Does
Deploys Longhorn, a lightweight and powerful distributed block storage system for Kubernetes. It provides enterprise-grade storage with replication, snapshots, backups, and a web UI.

### Why You Would Use It
- **Data redundancy**: Automatic replication across nodes (no data loss if node fails)
- **Persistent storage**: Survives pod/node failures
- **Snapshots**: Point-in-time backups of volumes
- **Disaster recovery**: Backup to S3/NFS, restore to any cluster
- **Web UI**: Visual management of volumes and replicas
- **Production-ready**: Used in production by many organizations

### When You Need It
- You need persistent storage with high availability
- You want protection against hardware failures
- You need volume snapshots for backup/restore
- You're running stateful applications (databases, file servers)
- Local-path storage isn't enough (single node = single point of failure)
- You want a visual interface for storage management

### Installation

**Basic (NodePort)**:
```bash
./container-scripts/storage/deploy-longhorn.sh <master-ip>
```
Access UI via: `http://<node-ip>:30900`

**With LoadBalancer (requires MetalLB)**:
```bash
./container-scripts/storage/deploy-longhorn.sh <master-ip> true
```
Access UI via: `http://<loadbalancer-ip>`

### What Gets Installed
- Longhorn Manager (storage orchestration)
- Longhorn Driver (CSI driver)
- Longhorn UI (web interface)
- Longhorn Engine (volume management)
- iSCSI prerequisites (auto-detected and installed per OS)

### Prerequisites
The script automatically installs iSCSI packages based on your OS:

**Ubuntu/Debian**:
- `open-iscsi`
- `nfs-common`

**Rocky Linux/RHEL**:
- `iscsi-initiator-utils`
- `nfs-utils`

### Example Use Cases

**Create Persistent Volume**:
```bash
# Deploy Longhorn
./deploy-longhorn.sh 192.168.1.202

# Create PVC (Persistent Volume Claim)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
EOF

# Use in pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-with-storage
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-data
EOF
```

**Replicated Database**:
```bash
# Deploy PostgreSQL with Longhorn storage
kubectl create deployment postgres --image=postgres:15
kubectl set env deployment/postgres POSTGRES_PASSWORD=mysecret

# Create PVC for database
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
EOF

# Add volume to deployment
kubectl set volume deployment/postgres \
  --add --name=data \
  --type=persistentVolumeClaim \
  --claim-name=postgres-data \
  --mount-path=/var/lib/postgresql/data

# Data is now replicated and survives pod/node failures!
```

### Configuration
- **Namespace**: `longhorn-system`
- **Version**: v1.7.0
- **Default Replicas**: 1 (change via UI or values)
- **Storage Path**: `/var/lib/longhorn` on each node
- **UI Port**: 30900 (NodePort) or 80 (LoadBalancer)

### Verification
```bash
# Check pods (should see manager, driver, engine, ui)
kubectl get pods -n longhorn-system

# Check storage class
kubectl get storageclass longhorn

# Access UI
# Browser: http://<node-ip>:30900

# Create test volume
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/master/examples/simple_pvc.yaml
kubectl get pvc
```

### Making Longhorn the Default Storage Class
```bash
# Remove default from local-path
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Set Longhorn as default
kubectl patch storageclass longhorn -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify
kubectl get storageclass
```

### Resource Requirements
- **Minimum**: 3 nodes with 10GB free disk space each
- **Recommended**: 3+ nodes with 50GB+ each
- **RAM**: ~500MB per node
- **Network**: Low latency between nodes (same datacenter/rack)

---

## 🗄️ MinIO - S3-Compatible Object Storage

**Script**: `deploy-minio.sh`

### What It Does
Deploys MinIO, an S3-compatible object storage server. It provides a simple, high-performance storage solution for unstructured data like images, videos, backups, and logs.

### Why You Would Use It
- **S3 compatibility**: Works with AWS SDK and tools (s3cmd, aws-cli)
- **Simple backup target**: Store application backups, database dumps
- **Media storage**: Store images, videos for web applications
- **Artifact storage**: Store build artifacts, container images
- **No cloud costs**: Free alternative to AWS S3 for lab/testing
- **Web UI**: Upload/download files through browser

### When You Need It
- You need object storage for backups or artifacts
- You're building applications that use S3 API
- You want to store large files (videos, images, logs)
- You need a backup target for Longhorn, Velero, or databases
- You're testing S3-compatible applications locally
- You want to reduce cloud storage costs for testing

### Installation

**Basic (NodePort, 10Gi storage)**:
```bash
./container-scripts/storage/deploy-minio.sh <master-ip>
```
- Console: `http://<node-ip>:30901`
- API: `http://<node-ip>:30900`

**With LoadBalancer**:
```bash
./container-scripts/storage/deploy-minio.sh <master-ip> true
```

**Custom Storage Size**:
```bash
./container-scripts/storage/deploy-minio.sh <master-ip> false 50Gi
```

### What Gets Deployed
- MinIO server (object storage engine)
- MinIO Console (web UI)
- Persistent volume (for data storage)
- Two services: API endpoint + Console

### Default Credentials
- **Username**: `admin`
- **Password**: `minio123`

⚠️ **CHANGE THESE IN PRODUCTION!**

### Example Use Cases

**Store Application Backups**:
```bash
# Deploy MinIO
./deploy-minio.sh 192.168.1.202 false 20Gi

# Install MinIO client (mc)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure client
mc alias set mylab http://192.168.1.202:30900 admin minio123

# Create bucket
mc mb mylab/backups

# Upload backup
mc cp /path/to/backup.tar.gz mylab/backups/

# List files
mc ls mylab/backups
```

**Database Backup Target**:
```bash
# PostgreSQL backup to MinIO
PGPASSWORD=secret pg_dump -h postgres-ip mydb | \
  mc pipe mylab/backups/mydb-$(date +%Y%m%d).sql

# MySQL backup to MinIO
mysqldump -u root -p mydb | \
  mc pipe mylab/backups/mydb-$(date +%Y%m%d).sql
```

**Web Application Image Storage**:
```python
# Python example using boto3 (AWS SDK)
import boto3

s3 = boto3.client('s3',
    endpoint_url='http://192.168.1.202:30900',
    aws_access_key_id='admin',
    aws_secret_access_key='minio123'
)

# Upload image
s3.upload_file('photo.jpg', 'images', 'photo.jpg')

# Download image
s3.download_file('images', 'photo.jpg', 'downloaded.jpg')

# Generate presigned URL (temporary access)
url = s3.generate_presigned_url('get_object',
    Params={'Bucket': 'images', 'Key': 'photo.jpg'},
    ExpiresIn=3600)
```

**Longhorn Backup Target**:
```bash
# Configure Longhorn to backup to MinIO
# In Longhorn UI (http://<node-ip>:30900)
# Settings → General → Backup Target:
s3://backups@us-east-1/longhorn?endpoint=http://minio.minio.svc.cluster.local:9000&region=us-east-1

# Backup Target Credential Secret:
# Create secret in longhorn-system namespace:
kubectl create secret generic minio-secret \
  -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID=admin \
  --from-literal=AWS_SECRET_ACCESS_KEY=minio123 \
  --from-literal=AWS_ENDPOINTS=http://minio.minio.svc.cluster.local:9000
```

### Configuration
- **Namespace**: `minio`
- **Storage**: 10Gi (default, configurable)
- **Console Port**: 30901 (NodePort) or 9001 (LoadBalancer)
- **API Port**: 30900 (NodePort) or 9000 (LoadBalancer)
- **Mode**: Standalone (single instance)

### Verification
```bash
# Check pods
kubectl get pods -n minio

# Check PVC
kubectl get pvc -n minio

# Access console
# Browser: http://<node-ip>:30901
# Login: admin / minio123

# Test API with curl
curl http://192.168.1.202:30900/minio/health/live
```

### Resource Requirements
- **Storage**: Based on your needs (10Gi minimum)
- **RAM**: ~256MB minimum
- **CPU**: Minimal

---

## Comparison: Longhorn vs MinIO

| Feature | Longhorn | MinIO |
|---------|----------|-------|
| **Storage Type** | Block (volumes) | Object (files) |
| **Use Case** | Databases, apps needing volumes | Backups, media, artifacts |
| **Access Method** | Kubernetes PVC | S3 API / Web UI |
| **Replication** | Built-in across nodes | Single instance (unless HA mode) |
| **Snapshots** | Yes | No (use versioning) |
| **Best For** | Stateful apps, databases | File storage, backups |
| **Complexity** | Moderate | Low |
| **Resource Usage** | Higher (replicas) | Lower |

**Rule of Thumb**:
- Use **Longhorn** for application data that needs volume access (databases, file servers)
- Use **MinIO** for file storage and backups (images, videos, logs, archives)

---

## Common Workflows

### Setup Complete Storage Solution
```bash
# 1. Deploy Longhorn for application volumes
./deploy-longhorn.sh 192.168.1.202

# 2. Deploy MinIO for backups
./deploy-minio.sh 192.168.1.202 false 50Gi

# 3. Configure Longhorn to backup to MinIO (see MinIO section)

# Now you have:
# - High-availability storage for apps (Longhorn)
# - Backup target for disaster recovery (MinIO)
```

### Database with Backups
```bash
# 1. Deploy storage
./deploy-longhorn.sh 192.168.1.202
./deploy-minio.sh 192.168.1.202

# 2. Deploy database with Longhorn volume (see Longhorn examples)

# 3. Schedule backups to MinIO
# Create CronJob for database backups
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgres mydb | mc pipe mylab/backups/db-\$(date +%Y%m%d).sql
            env:
            - name: PGPASSWORD
              value: "secret"
          restartPolicy: OnFailure
EOF
```

---

## Troubleshooting

### Longhorn: Pods Stuck in Pending
```bash
# Check if iSCSI is installed
sudo systemctl status iscsid

# Check node disk space
df -h /var/lib/longhorn

# Check Longhorn manager logs
kubectl logs -n longhorn-system deployment/longhorn-manager
```

### Longhorn: Volume Not Mounting
```bash
# Check volume status in UI (http://<node-ip>:30900)

# Check engine pods
kubectl get pods -n longhorn-system | grep engine

# Check volume attachment
kubectl describe pv <pv-name>
```

### MinIO: Console Not Accessible
```bash
# Check service
kubectl get svc -n minio

# Check pod logs
kubectl logs -n minio deployment/minio

# Verify NodePort
kubectl get svc -n minio minio-console -o jsonpath='{.spec.ports[0].nodePort}'
```

### MinIO: Cannot Upload Files
```bash
# Check PVC is bound
kubectl get pvc -n minio

# Check available storage
kubectl describe pvc -n minio

# Check pod has write permissions
kubectl exec -n minio deployment/minio -- ls -la /data
```

---

## Additional Resources

- **Longhorn Docs**: https://longhorn.io/docs/
- **MinIO Docs**: https://min.io/docs/
- **Longhorn Best Practices**: https://longhorn.io/docs/latest/best-practices/
- **MinIO Client (mc)**: https://min.io/docs/minio/linux/reference/minio-mc.html
- **Main Project Docs**: [../../GETTING_STARTED.md](../../GETTING_STARTED.md)

---

**Tip**: Deploy both! Longhorn for application volumes, MinIO for backups. This gives you a complete storage solution with disaster recovery capabilities.
