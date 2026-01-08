# DevTools Deployment Scripts

Deploy development and version control infrastructure for your Kubernetes cluster.

---

## 📦 Container Registry

**Script**: `deploy-registry.sh`

### What It Does
Deploys a private Docker container registry with a web UI (Joxit). Store and manage your own container images without relying on Docker Hub or other public registries.

### Why You Would Use It
- **Private images**: Store proprietary or internal images securely
- **No rate limits**: Docker Hub has pull limits; your registry doesn't
- **Faster pulls**: Images are local to your cluster/network
- **Air-gapped environments**: Work without internet access
- **Custom images**: Store your own built images for testing
- **Cost savings**: No need to pay for private Docker Hub/GCR repos

### When You Need It
- You're building custom Docker images for your apps
- You want to store images locally for faster deployment
- You need a private registry for proprietary software
- You're working in an air-gapped or restricted network
- You want to avoid Docker Hub rate limits
- You're building CI/CD pipelines that push images

### Installation

**Basic (NodePort, 20Gi storage)**:
```bash
./container-scripts/devtools/deploy-registry.sh <master-ip>
```
- Registry API: `http://<node-ip>:30500`
- Web UI: `http://<node-ip>:30501`

**With LoadBalancer**:
```bash
./container-scripts/devtools/deploy-registry.sh <master-ip> true
```

**Custom Storage Size**:
```bash
./container-scripts/devtools/deploy-registry.sh <master-ip> false 50Gi
```

### What Gets Deployed
- Docker Registry v2 (official registry server)
- Joxit Docker Registry UI (web interface)
- Persistent volume (for image storage)
- Two services: API endpoint + Web UI

### Example Use Cases

**Push Local Image to Registry**:
```bash
# Deploy registry
./deploy-registry.sh 192.168.1.202

# Build your image
docker build -t myapp:v1.0 .

# Tag for your registry
docker tag myapp:v1.0 192.168.1.202:30500/myapp:v1.0

# Configure Docker to use insecure registry
# Add to /etc/docker/daemon.json:
{
  "insecure-registries": ["192.168.1.202:30500"]
}

# Restart Docker
sudo systemctl restart docker

# Push image
docker push 192.168.1.202:30500/myapp:v1.0

# View in Web UI
# Browser: http://192.168.1.202:30501
```

**Use in Kubernetes Deployment**:
```bash
# Deploy app using your registry image
kubectl create deployment myapp \
  --image=192.168.1.202:30500/myapp:v1.0

# Or via YAML
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: 192.168.1.202:30500/myapp:v1.0
        ports:
        - containerPort: 8080
EOF
```

**Configure Nodes to Trust Registry** (Better than insecure-registries):
```bash
# On each Kubernetes node, create containerd config
ssh root@<node-ip>

# For containerd (most common)
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."192.168.1.202:30500"]
  endpoint = ["http://192.168.1.202:30500"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."192.168.1.202:30500".tls]
  insecure_skip_verify = true
EOF

# Restart containerd
systemctl restart containerd

# Verify
crictl pull 192.168.1.202:30500/myapp:v1.0
```

**CI/CD Pipeline Integration**:
```yaml
# GitHub Actions example
name: Build and Push
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Build image
      run: docker build -t myapp:${{ github.sha }} .
    
    - name: Tag for registry
      run: docker tag myapp:${{ github.sha }} 192.168.1.202:30500/myapp:${{ github.sha }}
    
    - name: Push to registry
      run: |
        echo '{"insecure-registries":["192.168.1.202:30500"]}' | sudo tee /etc/docker/daemon.json
        sudo systemctl restart docker
        docker push 192.168.1.202:30500/myapp:${{ github.sha }}
```

### Configuration
- **Namespace**: `registry`
- **Storage**: 20Gi (default, configurable)
- **Registry Port**: 30500 (NodePort) or 5000 (LoadBalancer)
- **UI Port**: 30501 (NodePort) or 80 (LoadBalancer)
- **Version**: Registry v2 (latest)

### Verification
```bash
# Check pods
kubectl get pods -n registry

# Check services
kubectl get svc -n registry

# Test API
curl http://192.168.1.202:30500/v2/_catalog

# Access Web UI
# Browser: http://192.168.1.202:30501
```

### Web UI Features
- Browse all images and tags
- View image details (layers, size, created date)
- Delete images (if configured)
- Search for images
- View manifest and config

---

## 📝 Gitea - Lightweight Git Server

**Script**: `deploy-gitea.sh`

### What It Does
Deploys Gitea, a painless self-hosted Git service. It's a lightweight alternative to GitLab, providing Git hosting, code review, issue tracking, and wikis.

### Why You Would Use It
- **Lightweight**: Uses minimal resources (< 100MB RAM)
- **Fast**: Much lighter than GitLab
- **Full Git features**: Repositories, branches, PRs, issues
- **Web interface**: GitHub-like UI for managing repos
- **Self-hosted**: Keep your code on your own infrastructure
- **Free**: No per-user licensing costs
- **API**: Automate via REST API

### When You Need It
- You want Git hosting without GitHub/GitLab costs
- You need a lightweight alternative to GitLab
- You're building internal tools and want version control
- You need a private Git server for your lab
- You want to learn Git workflows in a safe environment
- You need code review features (pull requests)

### Installation

**Basic (NodePort)**:
```bash
./container-scripts/devtools/deploy-gitea.sh <master-ip>
```
Access: `http://<node-ip>:30300`

### What Gets Deployed
- Gitea server (Git service + web UI)
- PostgreSQL database (metadata storage)
- Persistent volumes (for repos and database)
- Service (NodePort or LoadBalancer)

### Default Configuration
- **Admin User**: `gitea_admin`
- **Admin Password**: `gitea123` (⚠️ CHANGE THIS!)
- **Email**: `admin@gitea.local`

### Example Use Cases

**Create Your First Repository**:
```bash
# Deploy Gitea
./deploy-gitea.sh 192.168.1.202

# Access web UI
# Browser: http://192.168.1.202:30300

# Login with credentials above
# Click "+" → "New Repository"
# Name: myproject
# Initialize with README
# Click "Create Repository"

# Clone to your machine
git clone http://192.168.1.202:30300/gitea_admin/myproject.git
cd myproject

# Make changes
echo "Hello World" > hello.txt
git add hello.txt
git commit -m "Add hello.txt"
git push
```

**Use in CI/CD Pipeline**:
```bash
# Clone from Gitea in your CI/CD job
git clone http://192.168.1.202:30300/username/myproject.git

# Or with credentials
git clone http://username:password@192.168.1.202:30300/username/myproject.git

# Better: Use access tokens
# Gitea UI → Settings → Applications → Generate New Token
git clone http://username:TOKEN@192.168.1.202:30300/username/myproject.git
```

**Pull Request Workflow**:
```bash
# Developer 1: Create feature branch
git checkout -b feature/new-api
# ... make changes ...
git push -u origin feature/new-api

# In Gitea UI:
# - Click "New Pull Request"
# - Select branches: feature/new-api → main
# - Add description
# - Click "Create Pull Request"

# Developer 2: Review in UI
# - View diff
# - Add comments
# - Approve or Request Changes

# Developer 1: Merge when approved
# Click "Merge Pull Request" in UI
```

**Webhook Integration**:
```bash
# In Gitea UI:
# Repository → Settings → Webhooks → Add Webhook

# Example: Trigger CI on push
# Payload URL: http://jenkins:8080/github-webhook/
# Content Type: application/json
# Events: Push, Pull Request

# Now pushes automatically trigger builds!
```

### Configuration
- **Namespace**: `gitea`
- **Port**: 30300 (NodePort) or 3000 (LoadBalancer)
- **Storage**: 10Gi for repositories
- **Database**: PostgreSQL (included)

### Verification
```bash
# Check pods
kubectl get pods -n gitea

# Check services
kubectl get svc -n gitea

# Access UI
# Browser: http://<node-ip>:30300
```

---

## 🦊 GitLab - Full DevOps Platform

**Script**: `deploy-gitlab.sh`

### What It Does
Deploys GitLab Community Edition, a complete DevOps platform with Git hosting, CI/CD, container registry, issue tracking, wikis, and more.

### Why You Would Use It
- **Complete DevOps**: Everything in one platform
- **Built-in CI/CD**: GitLab Runners for automated testing/deployment
- **Container Registry**: Store Docker images alongside code
- **Advanced features**: Code quality, security scanning, monitoring
- **Issue tracking**: Agile boards, milestones, epics
- **Wiki**: Documentation integrated with code

### When You Need It
- You want a complete DevOps platform (not just Git)
- You need integrated CI/CD pipelines
- You want GitOps workflows
- You're replacing GitHub Enterprise or Bitbucket
- You need advanced project management features
- You want container registry + Git in one place

### Resource Requirements
⚠️ **WARNING**: GitLab is resource-intensive!
- **Minimum**: 4GB RAM, 20GB storage
- **Recommended**: 8GB+ RAM, 50GB+ storage
- **CPU**: 2+ cores recommended

💡 **For lightweight needs, use Gitea instead!**

### Installation

**Basic (requires Helm)**:
```bash
./container-scripts/devtools/deploy-gitlab.sh <master-ip>
```

**With custom storage**:
```bash
./container-scripts/devtools/deploy-gitlab.sh <master-ip> false 50Gi
```

⏱️ **Deployment time**: 15-20 minutes

### What Gets Deployed
- GitLab Rails (main application)
- GitLab Shell (Git SSH access)
- GitLab Workhorse (HTTP proxy)
- Gitaly (Git RPC service)
- PostgreSQL (database)
- Redis (cache)
- Sidekiq (background jobs)

### Default Credentials
```bash
# Username: root
# Password: Retrieved from secret after deployment

# Get password:
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath='{.data.password}' | base64 -d
```

⚠️ **Change password immediately after first login!**

### Example Use Cases

**Complete CI/CD Pipeline**:
```yaml
# .gitlab-ci.yml in your repository
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

test:
  stage: test
  script:
    - pytest tests/

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/myapp myapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  only:
    - main
```

**GitOps Workflow**:
```bash
# 1. Store Kubernetes manifests in GitLab repo
# 2. Configure GitLab Runner in cluster
# 3. Create CI/CD pipeline that applies manifests on merge to main
# 4. Changes to manifests automatically deploy to cluster

# Install GitLab Runner in cluster
helm install gitlab-runner gitlab/gitlab-runner \
  --set gitlabUrl=http://gitlab.gitlab.svc.cluster.local \
  --set runnerRegistrationToken=YOUR_TOKEN
```

### Configuration
- **Namespace**: `gitlab`
- **Storage**: 30Gi (default, configurable)
- **Deployment time**: 15-20 minutes
- **Initial setup**: Complete in web UI on first access

### Verification
```bash
# Check pods (many pods, be patient!)
kubectl get pods -n gitlab

# All pods should eventually be Running
# This can take 10-15 minutes

# Get service info
kubectl get svc -n gitlab

# Get root password
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath='{.data.password}' | base64 -d
```

---

## Comparison: Gitea vs GitLab

| Feature | Gitea | GitLab |
|---------|-------|--------|
| **Resource Usage** | ⭐⭐⭐⭐⭐ Very Low | ⭐⭐ High |
| **RAM Required** | ~100MB | 4GB+ |
| **Deployment Time** | 2-3 minutes | 15-20 minutes |
| **Git Hosting** | ✅ Yes | ✅ Yes |
| **Web UI** | ✅ GitHub-like | ✅ Advanced |
| **Pull Requests** | ✅ Yes | ✅ Yes (Merge Requests) |
| **CI/CD** | ❌ No | ✅ Built-in |
| **Container Registry** | ❌ No | ✅ Built-in |
| **Issue Tracking** | ✅ Basic | ✅ Advanced (boards, epics) |
| **Wiki** | ✅ Yes | ✅ Yes |
| **API** | ✅ REST | ✅ REST + GraphQL |
| **Best For** | Lightweight Git hosting | Complete DevOps platform |

**Recommendation**:
- **Use Gitea** if you primarily need Git hosting with web UI
- **Use GitLab** if you need CI/CD, container registry, and advanced DevOps features

---

## Common Workflows

### Development Workflow with Registry + Git
```bash
# 1. Deploy infrastructure
./deploy-registry.sh 192.168.1.202
./deploy-gitea.sh 192.168.1.202

# 2. Create Git repository in Gitea
# (via web UI)

# 3. Clone and develop
git clone http://192.168.1.202:30300/username/myapp.git
cd myapp
# ... make changes ...

# 4. Build and push image
docker build -t 192.168.1.202:30500/myapp:v1.0 .
docker push 192.168.1.202:30500/myapp:v1.0

# 5. Commit code
git add .
git commit -m "Release v1.0"
git push

# 6. Deploy to Kubernetes
kubectl create deployment myapp \
  --image=192.168.1.202:30500/myapp:v1.0

# Now you have: version-controlled code + versioned images!
```

### Complete DevOps Stack
```bash
# Deploy everything for full development environment
./deploy-gitea.sh 192.168.1.202          # Git hosting
./deploy-registry.sh 192.168.1.202       # Container images
../../monitoring/deploy-monitoring.sh 192.168.1.202  # Metrics
../../networking/deploy-ingress.sh 192.168.1.202     # Routing

# Result: Complete local DevOps environment
# - Git: Gitea
# - Images: Container Registry  
# - Metrics: Prometheus + Grafana
# - Routing: Nginx Ingress
```

---

## Troubleshooting

### Registry: Cannot Push Images
```bash
# Check Docker daemon.json has insecure-registries
cat /etc/docker/daemon.json

# Should include:
# {"insecure-registries": ["<registry-ip>:30500"]}

# Restart Docker
sudo systemctl restart docker

# Test connection
curl http://192.168.1.202:30500/v2/

# Should return: {}
```

### Registry: Images Not Showing in UI
```bash
# Check registry logs
kubectl logs -n registry deployment/registry

# Check UI logs
kubectl logs -n registry deployment/registry-ui

# Verify UI can reach registry API
kubectl exec -n registry deployment/registry-ui -- \
  curl http://registry:5000/v2/_catalog
```

### Gitea: Cannot Clone Repository
```bash
# Check service is accessible
curl http://192.168.1.202:30300

# Test Git clone with verbose output
GIT_CURL_VERBOSE=1 git clone http://192.168.1.202:30300/user/repo.git

# Check Gitea logs
kubectl logs -n gitea deployment/gitea
```

### GitLab: Pods Not Starting
```bash
# GitLab requires significant resources
# Check node resources
kubectl top nodes

# Check pod events
kubectl get events -n gitlab --sort-by='.lastTimestamp'

# Common issue: Insufficient memory
# Solution: Add more RAM or reduce replica counts

# Check specific pod
kubectl describe pod -n gitlab <pod-name>
```

### GitLab: Slow Performance
```bash
# GitLab needs resources
# Increase limits in Helm values:

helm upgrade gitlab gitlab/gitlab \
  --set gitlab.webservice.resources.requests.memory=2Gi \
  --set gitlab.webservice.resources.limits.memory=4Gi \
  --reuse-values
```

---

## Additional Resources

- **Docker Registry Docs**: https://docs.docker.com/registry/
- **Joxit Registry UI**: https://github.com/Joxit/docker-registry-ui
- **Gitea Docs**: https://docs.gitea.io/
- **GitLab Docs**: https://docs.gitlab.com/
- **GitLab CI/CD**: https://docs.gitlab.com/ee/ci/
- **Main Project Docs**: [../../GETTING_STARTED.md](../../GETTING_STARTED.md)

---

**Tip**: Start with Gitea + Container Registry for a lightweight development environment. You can always upgrade to GitLab later if you need CI/CD features!
