# Git Server Quick Start Guide (Gitea / GitLab)

Your own private Git server for version control, collaboration, and CI/CD.

## Which Git Server Do You Have?

This guide covers **both Gitea and GitLab**. Check which one you installed:

```bash
# Check for Gitea
kubectl get pods -n git | grep gitea

# Check for GitLab
kubectl get pods -n git | grep gitlab
```

- **Gitea** - Lightweight, fast, great for small teams
- **GitLab** - Full-featured, includes CI/CD, package registry, wikis

---

## Gitea Quick Start

### Accessing Gitea

**With LoadBalancer**:
```bash
kubectl get svc -n git gitea

# Access at: http://<EXTERNAL-IP>:3000
```

**With NodePort**:
```bash
# Access at: http://<any-node-ip>:30030
# Example: http://192.168.1.206:30030
```

### First-Time Setup

1. **Open Gitea in browser**
2. You'll see the "Initial Configuration" page
3. **Database Settings** - Leave as SQLite (already configured)
4. **General Settings**:
   - **Site Title**: Your Lab Git
   - **Repository Root Path**: `/data/git/repositories` (default)
   - **Git LFS Root Path**: `/data/git/lfs` (default)
5. **Server and Third-Party Settings**:
   - **SSH Server Domain**: Your node IP or hostname
   - **Gitea Base URL**: `http://192.168.1.206:30030` (adjust to your URL)
   - **Disable Registration**: Check this (for private lab)
   - **Enable OpenID Sign-In**: Uncheck (unless you need it)
6. **Administrator Account**:
   - **Username**: `admin`
   - **Password**: Create a strong password
   - **Email**: Your email
7. Click **Install Gitea**

**Setup complete!** 🎉

### Creating Your First Repository

1. **Log in** with admin credentials
2. Click **+** (top-right) → **New Repository**
3. **Repository Name**: `my-first-repo`
4. **Description**: Optional
5. **Visibility**: Private (or Public)
6. **Initialize Repository**: 
   - ✅ Check "Initialize Repository"
   - ✅ Add README
   - ✅ Add .gitignore (select language)
7. Click **Create Repository**

### Cloning the Repository

```bash
# HTTP(S) clone
git clone http://192.168.1.206:30030/admin/my-first-repo.git

# Enter username and password when prompted
```

### Adding SSH Key (Recommended)

**Generate SSH key** (if you don't have one):
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
# Press Enter for defaults
```

**Copy public key**:
```bash
cat ~/.ssh/id_ed25519.pub
# Copy the output
```

**Add to Gitea**:
1. Click your **profile picture** (top-right) → **Settings**
2. **SSH / GPG Keys** tab
3. Click **Add Key**
4. Paste your public key
5. Give it a name (e.g., "My Laptop")
6. Click **Add Key**

**Clone with SSH**:
```bash
# SSH clone (no password needed!)
git clone ssh://git@192.168.1.206:30022/admin/my-first-repo.git
```

### Basic Git Workflow

```bash
# Clone repository
git clone http://192.168.1.206:30030/admin/my-first-repo.git
cd my-first-repo

# Make changes
echo "# My Project" > README.md

# Stage changes
git add README.md

# Commit
git commit -m "Update README"

# Push to Gitea
git push origin main
```

Refresh Gitea in browser - you'll see your changes!

### Creating New Users

1. **Admin Settings** → Click your profile → **Site Administration**
2. **User Accounts** tab
3. Click **Create User Account**
4. Fill in:
   - Username
   - Email
   - Password
5. Click **Create User Account**

Send credentials to the user - they can now log in and create repositories!

### Organizations and Teams

**Create Organization**:
1. Click **+** → **New Organization**
2. **Organization Name**: `my-team`
3. **Visibility**: Public or Private
4. Click **Create Organization**

**Add Team Members**:
1. Go to organization → **Teams**
2. **Owners** team → **Add Member**
3. Select user → Add

Now team members can collaborate on organization repositories!

---

## GitLab Quick Start

### Accessing GitLab

**With LoadBalancer**:
```bash
kubectl get svc -n git gitlab

# Access at: http://<EXTERNAL-IP>
```

**With NodePort**:
```bash
# Access at: http://<any-node-ip>:30080
# Example: http://192.168.1.206:30080
```

**Note**: GitLab takes 3-5 minutes to fully start. Be patient!

### First Login

**Default Credentials**:
- **Username**: `root`
- **Password**: `Password123!`

**Important**: Change this immediately after first login!

### Change Root Password

1. Click **profile icon** (top-right) → **Edit profile**
2. **Password** section (left sidebar)
3. **Current password**: `Password123!`
4. **New password**: Your strong password
5. **Password confirmation**: Repeat new password
6. Click **Save password**

### Creating Your First Project

1. Click **New project** button
2. **Create blank project**
3. **Project name**: `my-first-project`
4. **Project URL**: Leave as default (under root user)
5. **Visibility Level**: Private
6. **Initialize repository with a README**: Check this
7. Click **Create project**

### Cloning the Repository

```bash
# HTTP(S) clone
git clone http://192.168.1.206:30080/root/my-first-project.git

# Enter username (root) and password when prompted
```

### Adding SSH Key

**Generate SSH key** (if you don't have one):
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

**Copy public key**:
```bash
cat ~/.ssh/id_ed25519.pub
```

**Add to GitLab**:
1. Click **profile icon** → **Edit profile**
2. **SSH Keys** (left sidebar)
3. Paste your public key in **Key** field
4. **Title**: "My Laptop"
5. Click **Add key**

**Clone with SSH**:
```bash
git clone ssh://git@192.168.1.206:30222/root/my-first-project.git
```

### Basic Git Workflow

```bash
# Clone repository
git clone http://192.168.1.206:30080/root/my-first-project.git
cd my-first-project

# Make changes
echo "# My Project" > README.md

# Stage and commit
git add README.md
git commit -m "Update README"

# Push to GitLab
git push origin main
```

### Creating New Users

1. **Admin Area** → Click **profile icon** → **Admin Area**
2. **Users** (left sidebar)
3. Click **New user**
4. Fill in:
   - Name
   - Username
   - Email
5. Click **Create user**
6. Click **Edit** on the new user
7. **Password** section → Set password
8. Send credentials to user

### Groups and Projects

**Create Group** (like GitHub organizations):
1. Click **Groups** → **Create group**
2. **Group name**: `my-team`
3. **Visibility**: Private
4. Click **Create group**

**Add Members**:
1. Go to group → **Group information** → **Members**
2. **Invite members**
3. Enter username or email
4. Select role: Guest, Reporter, Developer, Maintainer, Owner
5. Click **Invite**

### GitLab CI/CD (Quick Example)

GitLab includes built-in CI/CD!

Create `.gitlab-ci.yml` in your project:

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - echo "Building application..."
    - docker build -t my-app:latest .

test:
  stage: test
  script:
    - echo "Running tests..."
    - pytest tests/

deploy:
  stage: deploy
  script:
    - echo "Deploying to Kubernetes..."
    - kubectl apply -f k8s/deployment.yaml
  only:
    - main
```

Push to GitLab → CI/CD pipeline runs automatically!

**View pipelines**: Project → **CI/CD** → **Pipelines**

---

## Common Tasks (Both Platforms)

### Webhooks

Trigger actions on push, merge, etc.

**Gitea**:
1. Repository → **Settings** → **Webhooks**
2. **Add Webhook** → Choose type (Gitea, Slack, Discord, etc.)
3. **Target URL**: Your webhook endpoint
4. **Trigger On**: Push, Pull Request, etc.
5. **Add Webhook**

**GitLab**:
1. Project → **Settings** → **Webhooks**
2. **URL**: Your webhook endpoint
3. **Trigger**: Push events, Tag events, Merge requests, etc.
4. **Add webhook**

### Protected Branches

Prevent direct pushes to main branch.

**Gitea**:
1. Repository → **Settings** → **Branches**
2. **Enable Branch Protection**
3. **Branch name pattern**: `main`
4. **Protect this branch**: Check all options
5. **Save**

**GitLab**:
1. Project → **Settings** → **Repository** → **Protected branches**
2. **Branch**: `main`
3. **Allowed to push**: No one (or Maintainers)
4. **Allowed to merge**: Developers + Maintainers
5. **Protect**

### Pull/Merge Requests

**Gitea** (Pull Requests):
1. Create feature branch: `git checkout -b feature/new-feature`
2. Make changes, commit, push: `git push origin feature/new-feature`
3. Go to repository in Gitea → **New Pull Request**
4. **Compare changes**: `main` ← `feature/new-feature`
5. **Create Pull Request**
6. Review, approve, merge

**GitLab** (Merge Requests):
1. Create feature branch: `git checkout -b feature/new-feature`
2. Push branch: `git push origin feature/new-feature`
3. GitLab shows notification → **Create merge request**
4. Fill in title, description
5. **Submit merge request**
6. Review, approve, merge

### Releases and Tags

```bash
# Create tag locally
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tag
git push origin v1.0.0
```

**Create Release** (both platforms):
1. Go to **Releases** section
2. **New Release** or **Create Release**
3. **Tag**: v1.0.0
4. **Release title**: "Version 1.0.0"
5. **Description**: Release notes
6. **Attach binaries** (optional)
7. **Publish release**

## Integrating with Kubernetes

### Automated Deployments

**Example**: Deploy to Kubernetes on push to main

**Gitea** (with Drone CI or similar):
```yaml
# .drone.yml
kind: pipeline
name: default

steps:
- name: deploy
  image: bitnami/kubectl:latest
  commands:
  - kubectl set image deployment/my-app my-app=registry.lab.local/my-app:${DRONE_COMMIT_SHA}
  when:
    branch:
    - main
```

**GitLab** (built-in CI/CD):
```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl config set-cluster k8s --server=$K8S_SERVER
    - kubectl config set-credentials gitlab --token=$K8S_TOKEN
    - kubectl config set-context default --cluster=k8s --user=gitlab
    - kubectl config use-context default
    - kubectl set image deployment/my-app my-app=registry.lab.local/my-app:$CI_COMMIT_SHA
  only:
    - main
```

### Git Webhooks → Kubernetes Events

Use tools like **Argo CD** or **Flux CD** for GitOps:

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Add your Git repository
argocd repo add http://192.168.1.206:30030/admin/k8s-manifests.git

# Create application
argocd app create my-app \
  --repo http://192.168.1.206:30030/admin/k8s-manifests.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

Now pushing to Git automatically deploys to Kubernetes!

## Storage Management

### Check Storage Usage

```bash
kubectl get pvc -n git
kubectl describe pvc git-data -n git  # Gitea
kubectl describe pvc gitlab-data -n git  # GitLab
```

### Expand Storage

```bash
# Edit PVC
kubectl edit pvc git-data -n git  # or gitlab-data

# Change storage size:
  resources:
    requests:
      storage: 10Gi
# To:
  storage: 50Gi

# Restart pod
kubectl delete pod -n git <git-pod-name>
```

## Troubleshooting

### Can't Access Git Server

**Check pod status**:
```bash
kubectl get pods -n git
# Should be Running (GitLab may take 3-5 minutes)
```

**Check logs**:
```bash
kubectl logs -n git <git-pod-name>
```

**Check service**:
```bash
kubectl get svc -n git
```

### Git Push Fails

**Check credentials**:
- Verify username and password
- For SSH, ensure key is added

**Check repository exists**:
- Verify repository URL is correct
- Check you have push permissions

**Check network**:
```bash
# Test connection
curl http://192.168.1.206:30030  # Gitea
curl http://192.168.1.206:30080  # GitLab
```

### GitLab: "502 Bad Gateway"

**GitLab is still starting** - Wait 3-5 minutes

**Check all components**:
```bash
kubectl logs -n git <gitlab-pod-name>
# Look for "gitlab Reconfigured!"
```

**Restart if needed**:
```bash
kubectl delete pod -n git <gitlab-pod-name>
```

### SSH Clone Not Working

**Check SSH port is accessible**:
```bash
# Gitea
telnet 192.168.1.206 30022

# GitLab
telnet 192.168.1.206 30222
```

**Check firewall** (on nodes):
```bash
sudo firewall-cmd --list-ports
# Should include 30022/tcp (Gitea) or 30222/tcp (GitLab)
```

**Add port if missing**:
```bash
sudo firewall-cmd --permanent --add-port=30022/tcp  # Gitea
sudo firewall-cmd --permanent --add-port=30222/tcp  # GitLab
sudo firewall-cmd --reload
```

## Best Practices

### ✅ Do
- Use SSH keys instead of passwords
- Enable branch protection for main/master
- Require pull/merge requests for important branches
- Use .gitignore files appropriately
- Tag releases with semantic versioning
- Back up your Git server regularly

### ❌ Don't
- Commit secrets or API keys
- Force push to shared branches
- Create huge commits (break them up)
- Store large binary files (use Git LFS instead)
- Leave default passwords unchanged

## Advanced: Git LFS (Large File Storage)

For large files (images, videos, datasets):

### Enable Git LFS

**Install locally**:
```bash
# Linux/macOS
brew install git-lfs  # or use package manager

# Windows
# Download from: https://git-lfs.github.com/
```

**Initialize**:
```bash
cd my-repository
git lfs install
```

**Track large files**:
```bash
# Track all .psd files
git lfs track "*.psd"

# Track specific file
git lfs track "large-dataset.bin"

# Commit .gitattributes
git add .gitattributes
git commit -m "Track large files with Git LFS"
```

**Use normally**:
```bash
git add large-file.psd
git commit -m "Add large Photoshop file"
git push origin main
```

Git LFS stores large files efficiently!

## Next Steps

- [Set up ingress](INGRESS.md) for `git.lab.local` access
- [Integrate with container registry](REGISTRY.md) for CI/CD image builds
- Set up automated deployments with Argo CD or Flux
- Configure webhooks for external integrations (Slack, Discord, etc.)
- Explore GitLab CI/CD runners for custom pipelines

## References

- Gitea: https://docs.gitea.io/
- GitLab: https://docs.gitlab.com/
- Git LFS: https://git-lfs.github.com/
- Argo CD: https://argo-cd.readthedocs.io/

---

**Pro tip**: Use Git hooks and webhooks to automate everything - from code quality checks to automatic Kubernetes deployments!
