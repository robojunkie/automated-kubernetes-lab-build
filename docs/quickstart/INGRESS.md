# Nginx Ingress Quick Start Guide

Route external traffic to your services using hostnames instead of IP addresses and ports.

## What is Ingress?

Without Ingress:
- Each service needs its own LoadBalancer IP or NodePort
- Users access: `http://192.168.1.206:30777`, `http://192.168.1.207:30800`, etc.
- Hard to remember, not user-friendly

With Ingress:
- One LoadBalancer IP for multiple services
- Users access: `http://app1.lab.local`, `http://app2.lab.local`, etc.
- Hostname-based routing (like a reverse proxy)

## How It Works

```
User requests app1.lab.local
         ↓
    Load Balancer (MetalLB)
         ↓
    Nginx Ingress Controller
         ↓
   Routes to correct service based on hostname
         ↓
    Your application pods
```

## Accessing Ingress Controller

### Find the Ingress IP

**With LoadBalancer**:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Example output:
# NAME                       TYPE           EXTERNAL-IP      PORT(S)
# ingress-nginx-controller   LoadBalancer   192.168.1.210    80:32080/TCP,443:32443/TCP
```

Access at: `http://192.168.1.210`

**With NodePort**:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Example output:
# NAME                       TYPE       PORT(S)
# ingress-nginx-controller   NodePort   80:32080/TCP,443:32443/TCP
```

Access at: `http://<any-node-ip>:32080`

## Your First Ingress Route

### 1. Deploy a Sample Application

```yaml
# app1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app1
spec:
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP  # Note: ClusterIP, not LoadBalancer!
```

```bash
kubectl apply -f app1.yaml
```

**Important**: Service type is `ClusterIP` because ingress will route to it!

### 2. Create an Ingress Resource

```yaml
# app1-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app1-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app1.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
```

```bash
kubectl apply -f app1-ingress.yaml
```

### 3. Configure DNS or /etc/hosts

Since `app1.lab.local` isn't a real domain, you need to map it to your ingress IP.

**Linux/macOS** - Edit `/etc/hosts`:
```bash
sudo nano /etc/hosts

# Add this line (use your actual ingress IP):
192.168.1.210 app1.lab.local
```

**Windows** - Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator:
```
192.168.1.210 app1.lab.local
```

### 4. Test It!

```bash
curl http://app1.lab.local
# Should return nginx welcome page

# Or open in browser:
# http://app1.lab.local
```

## Multiple Apps on One IP

### Deploy Second App

```yaml
# app2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: httpd
        image: httpd:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app2
spec:
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### Add Ingress Route

```yaml
# app2-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app2-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: app2.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
```

### Update /etc/hosts

```
192.168.1.210 app1.lab.local
192.168.1.210 app2.lab.local
```

### Test Both Apps

```bash
curl http://app1.lab.local  # Nginx
curl http://app2.lab.local  # Apache

# Same IP, different apps based on hostname!
```

## Path-Based Routing

Route different paths to different services:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.lab.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

Access:
- `http://myapp.lab.local/api` → API service
- `http://myapp.lab.local/web` → Web service

## Common Annotations

### Rewrite Target

Remove path prefix before sending to backend:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
```

Example:
- Request: `http://myapp.lab.local/api/users`
- Without rewrite: Backend receives `/api/users`
- With rewrite to `/`: Backend receives `/users`

### CORS Configuration

Enable Cross-Origin Resource Sharing:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, OPTIONS"
```

### Custom Timeouts

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
```

### Rate Limiting

Limit requests per IP:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
```

### Client Body Size

Allow larger file uploads:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
```

## HTTPS with Cert-Manager

If you installed cert-manager, you can get automatic TLS certificates!

### Self-Signed Certificate (Lab Use)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app1-ingress
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app1.lab.local
    secretName: app1-tls
  rules:
  - host: app1.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
```

Cert-manager will:
1. See the annotation
2. Generate a self-signed certificate
3. Store it in secret `app1-tls`
4. Ingress will use it for HTTPS

Access: `https://app1.lab.local`

**Note**: Browser will warn about self-signed cert (click "Advanced" → "Proceed")

### Redirect HTTP to HTTPS

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

Now `http://app1.lab.local` automatically redirects to `https://app1.lab.local`

## Real-World Examples

### Portainer with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portainer-ingress
  namespace: portainer
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
  - host: portainer.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: portainer
            port:
              number: 9000
```

Add to `/etc/hosts`:
```
192.168.1.210 portainer.lab.local
```

Access: `http://portainer.lab.local` (much nicer than remembering the IP!)

### Registry with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: registry-ingress
  namespace: registry
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"  # No limit for image uploads
spec:
  ingressClassName: nginx
  rules:
  - host: registry.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: registry
            port:
              number: 5000
```

Configure Docker:
```json
{
  "insecure-registries": ["registry.lab.local"]
}
```

Push images:
```bash
docker tag nginx:latest registry.lab.local/my-nginx:v1
docker push registry.lab.local/my-nginx:v1
```

### Grafana with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

## Monitoring Ingress

### View Ingress Resources

```bash
# All ingresses
kubectl get ingress --all-namespaces

# Details
kubectl describe ingress app1-ingress

# YAML
kubectl get ingress app1-ingress -o yaml
```

### Check Ingress Controller Logs

```bash
# Find the controller pod
kubectl get pods -n ingress-nginx

# View logs
kubectl logs -n ingress-nginx <ingress-nginx-controller-pod> -f

# Look for:
# - Access logs (requests coming in)
# - Routing decisions
# - Backend errors
```

### Test Backend Connectivity

```bash
# From ingress controller to your service
kubectl exec -n ingress-nginx <ingress-nginx-controller-pod> -- curl http://app1.default.svc.cluster.local
```

## Troubleshooting

### "404 Not Found" on Valid Hostname

**Check ingress exists**:
```bash
kubectl get ingress
# Should show your ingress resource
```

**Check hostname matches exactly**:
```bash
kubectl get ingress app1-ingress -o jsonpath='{.spec.rules[0].host}'
# Should match what you're requesting
```

**Check ingress class**:
```bash
kubectl get ingress app1-ingress -o jsonpath='{.spec.ingressClassName}'
# Should be "nginx"
```

### "503 Service Temporarily Unavailable"

**Check backend service exists**:
```bash
kubectl get svc app1
# Should exist and have endpoints
```

**Check pods are running**:
```bash
kubectl get pods -l app=app1
# Should be Running and Ready
```

**Check service selector matches pods**:
```bash
kubectl get svc app1 -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels | grep app1
# Labels should match
```

### Can't Reach Ingress IP

**Check ingress controller is running**:
```bash
kubectl get pods -n ingress-nginx
# ingress-nginx-controller should be Running
```

**Check service has external IP**:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Should have EXTERNAL-IP (LoadBalancer) or NodePort
```

**Check firewall**:
```bash
# On nodes
sudo firewall-cmd --list-ports  # Rocky Linux
# Should include 32080/tcp and 32443/tcp (NodePort)
```

### "default backend - 404"

Means ingress controller received the request but no ingress rule matched.

**Common causes**:
- Hostname doesn't match any ingress rule
- Forgot to add hostname to `/etc/hosts`
- Typo in hostname
- Ingress class mismatch

## Best Practices

### ✅ Do
- Use meaningful hostnames (`app-name.lab.local`, not `app1.lab.local`)
- Group related ingresses in the same namespace as the apps
- Use TLS/HTTPS for anything with passwords
- Set appropriate body size limits for uploads
- Use path-based routing to consolidate services

### ❌ Don't
- Expose services directly with LoadBalancer if ingress can do it
- Use wildcard CORS (`*`) in production
- Forget to update `/etc/hosts` when adding new hostnames
- Set infinite timeouts (can cause resource exhaustion)

## Advanced: Wildcard DNS (Optional)

For easier management, set up wildcard DNS in your home network:

**On your DNS server** (like Pi-hole, router DNS, or local BIND):
```
*.lab.local    A    192.168.1.210
```

Now **any** hostname ending in `.lab.local` points to your ingress!

No more `/etc/hosts` editing:
- `app1.lab.local` → works
- `anything.lab.local` → works
- `new-app.lab.local` → works

Just create the ingress resource and access immediately!

## Next Steps

- [Set up cert-manager](CERTMANAGER.md) for automatic TLS certificates
- [Access monitoring](MONITORING.md) via `grafana.lab.local`
- [Access Portainer](PORTAINER.md) via `portainer.lab.local`
- Deploy a full-stack application with frontend/backend/database using ingress

## References

- Nginx Ingress Controller: https://kubernetes.github.io/ingress-nginx/
- Ingress Annotations: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
- Cert-Manager Integration: https://cert-manager.io/docs/usage/ingress/

---

**Pro tip**: Create a DNS server (dnsmasq, Pi-hole) with `*.lab.local` → ingress IP for seamless access to all your services!
