# Container Registry Quick Start Guide

Your own private Docker registry for storing and managing container images.

## What is a Container Registry?

Think of it like GitHub, but for Docker images instead of code. Instead of pulling images from Docker Hub, you can:
- Store your own application images
- Keep proprietary code private
- Deploy faster (no internet dependency)
- Version and tag images

## Components

This setup includes:
1. **Docker Registry** - The actual storage backend
2. **Joxit UI** - A beautiful web interface to browse images

## Accessing the Registry

### Web UI (Joxit)

**With LoadBalancer**:
```bash
kubectl get svc registry-ui -n registry
# Access at: http://<EXTERNAL-IP>
```

**With NodePort**:
```bash
# Access at: http://<any-node-ip>:30501
# Example: http://192.168.1.206:30501
```

### Registry API

**With LoadBalancer**:
```bash
kubectl get svc registry -n registry
# API at: http://<EXTERNAL-IP>:5000
```

**With NodePort**:
```bash
# API at: http://<any-node-ip>:30500
```

## Configuring Docker to Use Your Registry

By default, Docker only trusts HTTPS registries. Since this is a lab setup using HTTP:

### On Your Local Machine

**Linux/macOS** - Edit `/etc/docker/daemon.json`:
```json
{
  "insecure-registries": ["<registry-ip>:5000"]
}
```

**Windows** - Docker Desktop → Settings → Docker Engine → Add:
```json
{
  "insecure-registries": ["<registry-ip>:5000"]
}
```

**Restart Docker**:
```bash
# Linux
sudo systemctl restart docker

# macOS/Windows
# Restart Docker Desktop
```

### On Kubernetes Nodes

Already configured! The setup script adds this to all nodes' containerd configuration.

## Your First Image Push

### 1. Tag an Existing Image

Let's use nginx as an example:

```bash
# Pull from Docker Hub
docker pull nginx:latest

# Tag for your registry
# Format: <registry-ip>:5000/<name>:<tag>
docker tag nginx:latest 192.168.1.206:30500/my-nginx:v1
```

**Understanding the format**:
- `192.168.1.206:30500` - Your registry location
- `my-nginx` - Your image name
- `v1` - Your version tag

### 2. Push to Your Registry

```bash
docker push 192.168.1.206:30500/my-nginx:v1
```

You should see:
```
The push refers to repository [192.168.1.206:30500/my-nginx]
...
v1: digest: sha256:abcd1234... size: 1234
```

### 3. Verify in Web UI

1. Open the Joxit UI in your browser
2. You should see `my-nginx` with tag `v1`
3. Click on it to see layers, size, and metadata

### 4. Pull from Your Registry

On any machine with Docker configured:

```bash
docker pull 192.168.1.206:30500/my-nginx:v1
```

On your Kubernetes cluster:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-registry
spec:
  containers:
  - name: nginx
    image: 192.168.1.206:30500/my-nginx:v1
```

## Building and Pushing Your Own App

### Example: Simple Python App

**1. Create app directory**:
```bash
mkdir my-python-app
cd my-python-app
```

**2. Create `app.py`**:
```python
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from my registry!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

**3. Create `requirements.txt`**:
```
Flask==2.3.0
```

**4. Create `Dockerfile`**:
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 8080
CMD ["python", "app.py"]
```

**5. Build the image**:
```bash
docker build -t 192.168.1.206:30500/my-python-app:1.0 .
```

**6. Push to registry**:
```bash
docker push 192.168.1.206:30500/my-python-app:1.0
```

**7. Deploy to Kubernetes**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-python-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-python-app
  template:
    metadata:
      labels:
        app: my-python-app
    spec:
      containers:
      - name: app
        image: 192.168.1.206:30500/my-python-app:1.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: my-python-app
spec:
  selector:
    app: my-python-app
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer  # or NodePort
```

```bash
kubectl apply -f my-app.yaml
kubectl get svc my-python-app
# Access the app!
```

## Using the Web UI (Joxit)

### Features

1. **Browse Images**
   - See all images and tags
   - Click on an image to see details

2. **Image Details**
   - Layers and their sizes
   - Creation date
   - Pull command (copy to clipboard)
   - Manifest JSON

3. **Search**
   - Search by image name
   - Filter by tags

4. **Delete Images**
   - Click trash icon on a tag
   - Requires registry configured with `DELETE_IMAGES=true` (already set!)

## Registry Management

### List All Images via API

```bash
# Replace with your registry IP:port
REGISTRY="192.168.1.206:30500"

# List all repositories
curl http://$REGISTRY/v2/_catalog

# Example output:
# {"repositories":["my-nginx","my-python-app"]}
```

### List Tags for an Image

```bash
curl http://$REGISTRY/v2/my-nginx/tags/list

# Example output:
# {"name":"my-nginx","tags":["v1","v2","latest"]}
```

### Delete an Image Tag

```bash
# Get the digest first
curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://$REGISTRY/v2/my-nginx/manifests/v1

# Look for Docker-Content-Digest header
# Then delete:
curl -X DELETE http://$REGISTRY/v2/my-nginx/manifests/<digest>
```

Or just use the Web UI trash icon!

## Best Practices

### Image Naming Conventions

```
<registry>/<project>/<app>:<version>
```

Examples:
```
192.168.1.206:30500/web/frontend:1.0.0
192.168.1.206:30500/web/frontend:1.0.1
192.168.1.206:30500/api/backend:2.3.0
192.168.1.206:30500/api/backend:latest
```

### Tagging Strategy

**Semantic Versioning**:
```bash
docker tag myapp:latest 192.168.1.206:30500/myapp:1.0.0
docker tag myapp:latest 192.168.1.206:30500/myapp:1.0
docker tag myapp:latest 192.168.1.206:30500/myapp:1
docker tag myapp:latest 192.168.1.206:30500/myapp:latest
```

Push all tags:
```bash
docker push 192.168.1.206:30500/myapp --all-tags
```

**Why multiple tags?**
- `1.0.0` - Exact version (never changes)
- `1.0` - Latest patch in 1.0.x
- `1` - Latest minor in 1.x.x
- `latest` - Most recent version overall

### Git Commit SHA Tags

Great for CI/CD:
```bash
docker tag myapp:latest 192.168.1.206:30500/myapp:$(git rev-parse --short HEAD)
docker push 192.168.1.206:30500/myapp:$(git rev-parse --short HEAD)
```

Now you can trace any deployment back to exact source code!

## Registry Storage

### Check Storage Usage

```bash
kubectl get pvc -n registry
# Shows size and used space

# For more details:
kubectl describe pvc registry-data -n registry
```

### Expand Storage (if needed)

```bash
# Edit PVC
kubectl edit pvc registry-data -n registry

# Change:
  resources:
    requests:
      storage: 20Gi
# To:
  resources:
    requests:
      storage: 50Gi
```

**Note**: Requires storage class that supports volume expansion (local-path supports this!)

### Cleanup Old Images

Use the Web UI to delete tags you no longer need, or script it:

```bash
# Example: Delete all tags except latest and last 3 versions
# (You'd write a script for this based on your naming convention)
```

## Integrating with CI/CD

### GitHub Actions Example

```yaml
name: Build and Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build image
      run: docker build -t my-app:${{ github.sha }} .
    
    - name: Tag for registry
      run: |
        docker tag my-app:${{ github.sha }} \
          192.168.1.206:30500/my-app:${{ github.sha }}
        docker tag my-app:${{ github.sha }} \
          192.168.1.206:30500/my-app:latest
    
    - name: Push to registry
      run: |
        docker push 192.168.1.206:30500/my-app:${{ github.sha }}
        docker push 192.168.1.206:30500/my-app:latest
```

### GitLab CI Example

```yaml
build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  variables:
    CI_REGISTRY_IMAGE: 192.168.1.206:30500/my-app
```

## Troubleshooting

### Can't Push: "server gave HTTP response to HTTPS client"

**Solution**: Add registry to insecure-registries in Docker config (see "Configuring Docker" section above)

### Can't Pull in Kubernetes: "ErrImagePull"

**Check containerd config on nodes**:
```bash
ssh <node-ip>
sudo cat /etc/containerd/config.toml | grep insecure_registry
# Should show your registry IP
```

**If missing**, the setup script should have added it. You can manually add:
```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."<registry-ip>:5000"]
  endpoint = ["http://<registry-ip>:5000"]

[plugins."io.containerd.grpc.v1.cri".registry.configs."<registry-ip>:5000".tls]
  insecure_skip_verify = true
```

Then restart containerd:
```bash
sudo systemctl restart containerd
```

### Web UI Shows Empty

**Check registry is running**:
```bash
kubectl get pods -n registry
# Should show registry-xxx and registry-ui-xxx as Running
```

**Test API directly**:
```bash
curl http://<registry-ip>:30500/v2/_catalog
# Should return JSON with repositories list
```

**Check Web UI configuration**:
```bash
kubectl logs -n registry <registry-ui-pod-name>
# Look for connection errors to registry
```

### Image Push is Slow

**Check storage performance**:
```bash
kubectl describe pvc registry-data -n registry
# Check where PV is mounted

# On that node:
dd if=/dev/zero of=/tmp/testfile bs=1G count=1 oflag=direct
# Should be reasonably fast (depends on disk)
```

**Consider using Longhorn** for better distributed storage performance

## Security Considerations

### This is a Lab Setup!

Current configuration:
- ✅ No authentication (anyone can push/pull)
- ✅ HTTP only (no encryption)
- ✅ Storage deletion enabled

**For production**, you'd want:
- 🔒 Basic auth or token authentication
- 🔒 HTTPS with valid certificates
- 🔒 Access control and audit logging
- 🔒 Image scanning for vulnerabilities

### Making it More Secure (Optional)

**Add basic authentication**:

1. Create htpasswd file:
```bash
docker run --rm --entrypoint htpasswd httpd:2 -Bbn myuser mypassword > auth.htpasswd
```

2. Create secret:
```bash
kubectl create secret generic registry-auth \
  --from-file=htpasswd=auth.htpasswd \
  -n registry
```

3. Update registry deployment to mount and use it

4. Login when pushing:
```bash
docker login 192.168.1.206:30500
# Enter username and password
```

## Next Steps

- [Set up CI/CD with Gitea/GitLab](GIT.md) for automatic builds
- [Use ingress](INGRESS.md) to access registry via hostname (registry.lab.local)
- [Deploy multi-tier apps](../../examples/simple-deployment.yaml) using your images
- Integrate with [monitoring](MONITORING.md) to track registry usage

## References

- Docker Registry API: https://docs.docker.com/registry/spec/api/
- Joxit UI: https://github.com/Joxit/docker-registry-ui
- Best Practices: https://docs.docker.com/registry/deploying/

---

**Remember**: Replace `192.168.1.206:30500` with your actual registry IP and port!
