# Portainer Quick Start Guide

Portainer is your visual gateway to Kubernetes - perfect if you're new to containers and Kubernetes!

## What is Portainer?

Portainer provides a web-based interface to manage your Kubernetes cluster without needing to memorize kubectl commands. Think of it as a "control panel" for your cluster.

## Accessing Portainer

### Find Your Portainer URL

**With MetalLB (LoadBalancer mode)**:
```bash
kubectl get svc -n portainer
# Look for EXTERNAL-IP column
# Access at: http://<EXTERNAL-IP>:9000
```

**Without MetalLB (NodePort mode)**:
```bash
# Access at: http://<any-node-ip>:30777
# Example: http://192.168.1.206:30777
```

## First-Time Setup

1. **Open Port

ainer in your browser** using the URL above

2. **Create admin account**
   - Username: `admin` (or your choice)
   - Password: Create a strong password (min 12 characters)
   - Click "Create user"

3. **Get started immediately**
   - Click "Get Started" (it will automatically connect to your cluster)

## Dashboard Overview

After logging in, you'll see:

- **📊 Cluster status** - Node count, running containers, resource usage
- **🎯 Quick actions** - Deploy apps, create services, view logs
- **📁 Namespaces** - Logical separations in your cluster

## Common Tasks for Beginners

### 1. View Your Cluster Nodes

**Path**: Home → Cluster → Nodes

You'll see:
- All nodes (master + workers)
- CPU and memory usage
- Status (Ready/NotReady)
- Kubernetes version

### 2. Explore Namespaces

**Path**: Home → Namespaces

What are namespaces?
- Logical subdivisions of your cluster
- Like "folders" for your applications
- Default namespaces:
  - `default` - Your apps go here by default
  - `kube-system` - Kubernetes core components
  - `calico-system` - Networking components
  - `metallb-system` - Load balancer (if enabled)

### 3. View Running Pods

**Path**: Home → Cluster → Applications

Pods are the smallest deployable units in Kubernetes (one or more containers).

You can:
- ✅ See all running applications
- ✅ Filter by namespace
- ✅ View pod status (Running, Pending, etc.)
- ✅ Click a pod to see details

### 4. Check Pod Logs

**Path**: Applications → Click a pod → Logs tab

Super useful for troubleshooting! You'll see:
- Real-time application output
- Error messages
- Debug information

**Auto-refresh**: Toggle "Auto-refresh" to stream logs live

### 5. Execute Commands in a Container

**Path**: Applications → Click a pod → Console tab

This gives you a shell inside the container!

Example commands to try:
```bash
# Check container's OS
cat /etc/os-release

# List files
ls -la

# Check environment variables
env

# Test network connectivity
ping google.com  # (if ping is installed)
```

### 6. Deploy Your First Application

**Path**: Applications → Add application

Let's deploy nginx as an example:

1. **Fill in the form**:
   - **Name**: `my-nginx`
   - **Image**: `nginx:latest`
   - **Port mapping**:
     - Container port: `80`
     - Service type: Choose `LoadBalancer` or `NodePort`

2. **Click "Deploy application"**

3. **Wait for pod to be Ready** (usually 30-60 seconds)

4. **Access your app**:
   ```bash
   # Get service URL
   kubectl get svc my-nginx
   # Access at the EXTERNAL-IP or http://<node-ip>:<nodePort>
   ```

### 7. Scale an Application

**Path**: Applications → Click deployment → Scroll to "Instances"

- **Increase replicas**: Change number and click "Update"
- Watch as Kubernetes creates more pods automatically
- **Decrease replicas**: Change to lower number

**Why scale?**
- Handle more traffic
- High availability (if one pod fails, others keep running)
- Testing load balancing

### 8. Update an Application Image

**Path**: Applications → Click deployment → Edit → Update image

Example: Change from `nginx:latest` to `nginx:alpine` for a smaller image

Kubernetes will:
1. Create new pods with the new image
2. Wait for them to be ready
3. Terminate old pods (zero-downtime update!)

### 9. View Services and Endpoints

**Path**: Cluster → Services

Services expose your pods to the network.

Types:
- **ClusterIP**: Internal only (pod-to-pod)
- **NodePort**: Accessible on each node's IP
- **LoadBalancer**: Gets an external IP (requires MetalLB)

### 10. Check Resource Usage

**Path**: Cluster → Nodes → Click a node → Stats tab

See real-time:
- CPU usage
- Memory usage
- Pod count on that node

## Understanding the Interface

### Left Sidebar Sections

- **🏠 Home**: Back to cluster selection
- **📊 Dashboard**: Overview of cluster
- **🎯 Applications**: Pods, Deployments, StatefulSets
- **⚙️ Configurations**: ConfigMaps, Secrets
- **🌐 Services**: Service discovery
- **💾 Volumes**: Persistent storage
- **👥 Cluster**: Nodes, namespaces, roles

### Top Bar

- **🔔 Notifications**: Alerts and messages
- **⚙️ Settings**: Portainer configuration
- **👤 User menu**: Account settings, logout

## Useful Portainer Features

### Create from YAML

**Path**: Applications → Advanced deployment

Paste Kubernetes YAML directly:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
```

### View Events

**Path**: Cluster → Events

See what's happening in your cluster:
- Pod creations
- Failed scheduling
- Image pulls
- Errors and warnings

**Tip**: Filter by namespace to focus on specific apps

### Resource Templates

**Path**: App Templates

Pre-made application configurations:
- WordPress
- MySQL
- Redis
- And more!

Click any template and adjust settings to deploy quickly.

## Troubleshooting with Portainer

### Pod Stuck in "Pending"

1. **Click the pod** → Details tab
2. **Look at Events** section
3. **Common causes**:
   - "Insufficient memory" → Need more resources
   - "No nodes available" → All nodes are full
   - "PVC not bound" → Storage issue

### Pod Crashing (CrashLoopBackOff)

1. **Check logs** → Look for error messages
2. **Check recent events** → See what Kubernetes tried
3. **Exec into container** (if it stays up long enough) → Debug interactively

### Service Not Accessible

1. **Check service** → Make sure it has Endpoints
2. **Check pods** → Must be Running and Ready
3. **Check selectors** → Service must match pod labels
4. **Check firewalls** → NodePort/LoadBalancer must be accessible

## Best Practices

### ✅ Do
- Use namespaces to organize applications
- Check logs when something doesn't work
- Start with small resource limits, then increase if needed
- Use health checks (readiness/liveness probes)

### ❌ Don't
- Run everything in `default` namespace
- Deploy without resource limits (can crash nodes)
- Delete system namespaces (kube-system, calico-system, etc.)
- Expose sensitive services without authentication

## Beyond Portainer

Once comfortable with Portainer, you can:

1. **Learn kubectl** - Command-line tool (more powerful)
2. **Write YAML manifests** - Infrastructure as code
3. **Use Helm** - Package manager for Kubernetes
4. **Set up CI/CD** - Automatic deployments

But Portainer is always there when you need a visual overview!

## Next Steps

- [Deploy a multi-tier application](../../examples/simple-deployment.yaml)
- [Set up ingress routing](INGRESS.md) for hostname-based access
- [Configure monitoring](MONITORING.md) to track resource usage
- [Use container registry](REGISTRY.md) for your own images

## Portainer Documentation

Official docs: https://docs.portainer.io/

---

**Tip**: Bookmark your Portainer URL for quick access to your cluster!
