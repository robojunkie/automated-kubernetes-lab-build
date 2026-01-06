# MinIO Quick Start Guide

S3-compatible object storage for your Kubernetes cluster.

## What is MinIO?

MinIO provides object storage compatible with Amazon S3 APIs. Perfect for:
- Storing application files (images, videos, documents)
- Backup storage for databases
- Data lakes for analytics
- Serving static website content
- Machine learning datasets

**Think of it as**: Your own private S3 bucket in your cluster

## Accessing MinIO

### MinIO Console (Web UI)

**With LoadBalancer**:
```bash
kubectl get svc -n minio minio-console

# Access at: http://<EXTERNAL-IP>:9001
```

**With NodePort**:
```bash
# Access at: http://<any-node-ip>:30901
# Example: http://192.168.1.206:30901
```

### MinIO API Endpoint

**With LoadBalancer**:
```bash
kubectl get svc -n minio minio

# API at: http://<EXTERNAL-IP>:9000
```

**With NodePort**:
```bash
# API at: http://<any-node-ip>:30900
```

### Default Credentials

- **Username**: `minioadmin`
- **Password**: `minioadmin`

**Important**: Change these in production!

## First Login

1. Open MinIO Console in browser
2. Enter credentials: `minioadmin` / `minioadmin`
3. You'll see the MinIO dashboard

## MinIO Console Tour

### Main Sections

**📦 Buckets** - Storage containers (like folders)
**🔑 Access Keys** - API credentials for applications
**👥 Users** - User management
**⚙️ Settings** - Configuration
**📊 Monitoring** - Usage statistics

### Your First Bucket

1. Click **Buckets** (left sidebar)
2. Click **Create Bucket** button
3. Enter bucket name (e.g., `my-app-data`)
   - Use lowercase, no spaces
   - Can include hyphens
4. Click **Create Bucket**

**Bucket created!** 🎉

## Uploading Files

### Via Web Console

1. **Click on bucket name** (e.g., `my-app-data`)
2. Click **Upload** button
3. **Choose files** or **drag and drop**
4. Files upload automatically

### Create Folders (Prefixes)

1. Inside bucket, click **Create new path**
2. Enter path name (e.g., `images/`)
3. Click **Create**

MinIO uses flat storage with prefixes (not true folders), but looks like folders in UI!

### Download Files

1. Navigate to file
2. Click **⋮** (three dots) next to file
3. Click **Download**

### Delete Files

1. **Select file(s)** with checkbox
2. Click **Delete** button
3. Confirm deletion

## Using MinIO from Applications

### Install MinIO Client (mc)

**Linux/macOS**:
```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

**Windows**:
```powershell
Invoke-WebRequest -Uri "https://dl.min.io/client/mc/release/windows-amd64/mc.exe" -OutFile "mc.exe"
```

### Configure MinIO Client

```bash
# Format: mc alias set <name> <endpoint> <access-key> <secret-key>
mc alias set myminio http://192.168.1.206:30900 minioadmin minioadmin

# Test connection
mc admin info myminio
```

Should show server information!

### Basic mc Commands

**List buckets**:
```bash
mc ls myminio
```

**Create bucket**:
```bash
mc mb myminio/my-bucket
```

**Upload file**:
```bash
mc cp myfile.txt myminio/my-bucket/
```

**Upload folder**:
```bash
mc cp --recursive ./my-folder/ myminio/my-bucket/
```

**Download file**:
```bash
mc cp myminio/my-bucket/myfile.txt ./
```

**List objects in bucket**:
```bash
mc ls myminio/my-bucket
```

**Delete object**:
```bash
mc rm myminio/my-bucket/myfile.txt
```

**Delete bucket** (must be empty):
```bash
mc rb myminio/my-bucket
```

## Using S3 API with AWS CLI

MinIO is S3-compatible! Use standard AWS tools.

### Install AWS CLI

**Linux/macOS**:
```bash
pip install awscli
```

**Windows**:
```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

### Configure AWS CLI

```bash
aws configure

# Enter when prompted:
# AWS Access Key ID: minioadmin
# AWS Secret Access Key: minioadmin
# Default region name: us-east-1
# Default output format: json
```

**Or** set environment variables:
```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export AWS_ENDPOINT_URL=http://192.168.1.206:30900
```

### AWS CLI Commands

**List buckets**:
```bash
aws --endpoint-url http://192.168.1.206:30900 s3 ls
```

**Create bucket**:
```bash
aws --endpoint-url http://192.168.1.206:30900 s3 mb s3://my-bucket
```

**Upload file**:
```bash
aws --endpoint-url http://192.168.1.206:30900 s3 cp myfile.txt s3://my-bucket/
```

**Download file**:
```bash
aws --endpoint-url http://192.168.1.206:30900 s3 cp s3://my-bucket/myfile.txt ./
```

**Sync directory** (like rsync):
```bash
aws --endpoint-url http://192.168.1.206:30900 s3 sync ./local-dir s3://my-bucket/remote-dir
```

## Using MinIO in Applications

### Python (boto3)

```python
import boto3

# Create S3 client
s3 = boto3.client('s3',
    endpoint_url='http://192.168.1.206:30900',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin'
)

# Create bucket
s3.create_bucket(Bucket='my-app-data')

# Upload file
with open('data.json', 'rb') as f:
    s3.put_object(Bucket='my-app-data', Key='uploads/data.json', Body=f)

# Download file
response = s3.get_object(Bucket='my-app-data', Key='uploads/data.json')
data = response['Body'].read()

# List objects
response = s3.list_objects_v2(Bucket='my-app-data')
for obj in response['Contents']:
    print(obj['Key'])

# Delete object
s3.delete_object(Bucket='my-app-data', Key='uploads/data.json')
```

### Node.js (aws-sdk)

```javascript
const AWS = require('aws-sdk');

const s3 = new AWS.S3({
    endpoint: 'http://192.168.1.206:30900',
    accessKeyId: 'minioadmin',
    secretAccessKey: 'minioadmin',
    s3ForcePathStyle: true,
    signatureVersion: 'v4'
});

// Upload file
const fs = require('fs');
const fileContent = fs.readFileSync('data.json');

s3.putObject({
    Bucket: 'my-app-data',
    Key: 'uploads/data.json',
    Body: fileContent
}, (err, data) => {
    if (err) console.error(err);
    else console.log('Upload successful:', data);
});

// Download file
s3.getObject({
    Bucket: 'my-app-data',
    Key: 'uploads/data.json'
}, (err, data) => {
    if (err) console.error(err);
    else console.log('File content:', data.Body.toString());
});
```

### Go

```go
package main

import (
    "log"
    "github.com/minio/minio-go/v7"
    "github.com/minio/minio-go/v7/pkg/credentials"
)

func main() {
    endpoint := "192.168.1.206:30900"
    accessKey := "minioadmin"
    secretKey := "minioadmin"
    
    // Initialize client
    minioClient, err := minio.New(endpoint, &minio.Options{
        Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
        Secure: false,
    })
    if err != nil {
        log.Fatal(err)
    }
    
    // Upload file
    _, err = minioClient.FPutObject(ctx, "my-app-data", "data.json", "local-file.json", minio.PutObjectOptions{})
    if err != nil {
        log.Fatal(err)
    }
    
    log.Println("Successfully uploaded")
}
```

## Creating Access Keys

For applications, create separate access keys instead of using root credentials!

### Via Console

1. **Identity → Service Accounts** (left sidebar)
2. Click **Create service account**
3. **Access Key** and **Secret Key** generated automatically
4. **Optional**: Add policy to restrict permissions
5. Click **Create**
6. **Copy credentials** - Secret shown only once!

### Via mc Client

```bash
mc admin user add myminio myappuser myapppassword

# Create policy (optional)
cat > readonly-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::my-bucket/*"]
    }
  ]
}
EOF

mc admin policy create myminio readonly-policy readonly-policy.json
mc admin policy attach myminio readonly-policy --user myappuser
```

## Bucket Policies

Control access to buckets without managing user credentials.

### Make Bucket Public (Read-Only)

```bash
# Using mc
mc anonymous set download myminio/my-public-bucket

# Using AWS CLI
cat > public-read-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::my-public-bucket/*"]
    }
  ]
}
EOF

aws --endpoint-url http://192.168.1.206:30900 s3api put-bucket-policy \
  --bucket my-public-bucket \
  --policy file://public-read-policy.json
```

Now anyone can access files:
```
http://192.168.1.206:30900/my-public-bucket/image.jpg
```

### Bucket Versioning

Keep multiple versions of objects:

```bash
# Enable versioning
mc version enable myminio/my-bucket

# List versions
mc ls --versions myminio/my-bucket/file.txt
```

## Example: Application with MinIO Storage

### Deployment with MinIO

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: photo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: photo-app
  template:
    metadata:
      labels:
        app: photo-app
    spec:
      containers:
      - name: app
        image: my-photo-app:latest
        env:
        - name: S3_ENDPOINT
          value: "http://minio.minio.svc.cluster.local:9000"
        - name: S3_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: access-key
        - name: S3_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: secret-key
        - name: S3_BUCKET
          value: "photo-uploads"
```

### Secret for Credentials

```bash
kubectl create secret generic minio-credentials \
  --from-literal=access-key=minioadmin \
  --from-literal=secret-key=minioadmin
```

## Storage Management

### Check Storage Usage

```bash
# Via console: Monitoring → Usage

# Via mc:
mc admin info myminio
```

### Expand Storage

MinIO uses a PVC for storage. To expand:

```bash
# Check current size
kubectl get pvc -n minio

# Edit PVC
kubectl edit pvc minio-data -n minio

# Change:
  resources:
    requests:
      storage: 10Gi
# To:
  resources:
    requests:
      storage: 50Gi

# Restart MinIO pod to recognize new size
kubectl delete pod -n minio <minio-pod-name>
```

## Troubleshooting

### Can't Access Console

**Check pod status**:
```bash
kubectl get pods -n minio
# Should be Running
```

**Check service**:
```bash
kubectl get svc -n minio
# Should have minio and minio-console services
```

**Check logs**:
```bash
kubectl logs -n minio <minio-pod-name>
```

### "Access Denied" Errors

**Check credentials**:
- Verify access key and secret key are correct
- Check user has permission (policy attached)

**Check bucket policy**:
```bash
mc anonymous get myminio/my-bucket
```

### Slow Upload/Download

**Check network**:
```bash
# Test speed to MinIO
time mc cp largefile.bin myminio/test-bucket/
```

**Check storage performance**:
- Local-path storage is limited by node disk speed
- Consider using Longhorn for better performance

### Objects Not Appearing

**Wait a moment** - Large uploads take time

**Check upload success**:
```bash
mc ls myminio/my-bucket/path/to/object
```

**Check logs** for errors:
```bash
kubectl logs -n minio <minio-pod-name>
```

## Best Practices

### ✅ Do
- Create separate access keys per application
- Use bucket policies to limit access
- Enable versioning for important data
- Use lifecycle policies to auto-delete old objects
- Back up important buckets externally

### ❌ Don't
- Share root credentials (minioadmin/minioadmin)
- Make all buckets public
- Store credentials in code (use secrets/environment)
- Forget about storage limits
- Use as primary database (it's object storage, not a DB)

## Advanced: Multi-Tenant Setup

### Create Separate Users

```bash
# User 1 - can only access app1-bucket
mc admin user add myminio app1user App1Pass123

cat > app1-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": ["arn:aws:s3:::app1-bucket/*"]
    }
  ]
}
EOF

mc admin policy create myminio app1-policy app1-policy.json
mc admin policy attach myminio app1-policy --user app1user
```

### Bucket Lifecycle Policies

Auto-delete old objects:

```bash
# Delete objects older than 90 days
cat > lifecycle.json <<EOF
{
  "Rules": [
    {
      "ID": "DeleteOldObjects",
      "Status": "Enabled",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
EOF

aws --endpoint-url http://192.168.1.206:30900 s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket \
  --lifecycle-configuration file://lifecycle.json
```

## Next Steps

- [Use ingress](INGRESS.md) to access via `minio.lab.local`
- Set up [monitoring](MONITORING.md) to track storage usage
- Integrate with your applications for file storage
- Set up bucket replication (requires multiple MinIO instances)
- Explore MinIO Gateway for multi-cloud storage

## References

- MinIO Docs: https://min.io/docs/minio/kubernetes/upstream/
- MinIO Client (mc): https://min.io/docs/minio/linux/reference/minio-mc.html
- AWS S3 API Compatibility: https://docs.aws.amazon.com/AmazonS3/latest/API/

---

**Pro tip**: Use MinIO for development/testing with S3 API, then switch to real AWS S3 in production with minimal code changes!
