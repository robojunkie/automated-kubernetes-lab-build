# Networking Deployment Scripts

Deploy networking components to enable advanced routing and TLS certificate management in your Kubernetes cluster.

---

## 🌐 Nginx Ingress Controller

**Script**: `deploy-ingress.sh`

### What It Does
Deploys the Nginx Ingress Controller, which acts as a reverse proxy and load balancer for your Kubernetes services. Instead of accessing services via IP:Port, you can use friendly hostnames.

### Why You Would Use It
- **Hostname-based routing**: Access services via `app.yourdomain.com` instead of `192.168.1.100:30080`
- **Single entry point**: One IP/port for all services (HTTP/HTTPS)
- **Path-based routing**: Route `mydomain.com/api` to one service, `mydomain.com/web` to another
- **SSL termination**: Handle TLS certificates at the ingress level
- **Production standard**: Industry-standard way to expose Kubernetes services

### When You Need It
- You want to access multiple services through a single IP
- You're building a production-like environment
- You need hostname-based routing for your apps
- You want to use friendly URLs instead of NodePorts
- You're preparing for cert-manager (TLS certificates)

### Installation

**Basic (NodePort)**:
```bash
./container-scripts/networking/deploy-ingress.sh <master-ip>
```
Access via: `http://<node-ip>:30080` (HTTP), `http://<node-ip>:30443` (HTTPS)

**With LoadBalancer (requires MetalLB)**:
```bash
./container-scripts/networking/deploy-ingress.sh <master-ip> true
```
Access via: `http://<loadbalancer-ip>` (HTTP), `https://<loadbalancer-ip>` (HTTPS)

### Example Use Case
```bash
# Deploy ingress controller
./deploy-ingress.sh 192.168.1.202

# Deploy your application
kubectl create deployment myapp --image=nginx
kubectl expose deployment myapp --port=80

# Create ingress rule
kubectl create ingress myapp --rule="myapp.local/*=myapp:80"

# Add to /etc/hosts
echo "192.168.1.202 myapp.local" | sudo tee -a /etc/hosts

# Access via hostname
curl http://myapp.local
```

### Configuration
- **Namespace**: `ingress-nginx`
- **Service Type**: NodePort (default) or LoadBalancer
- **HTTP Port**: 30080 (NodePort) or 80 (LoadBalancer)
- **HTTPS Port**: 30443 (NodePort) or 443 (LoadBalancer)
- **Version**: v1.11.1

### Verification
```bash
# Check pods
kubectl get pods -n ingress-nginx

# Check service
kubectl get svc -n ingress-nginx

# Test ingress (should return 404 - no backends configured yet)
curl http://<node-ip>:30080
```

### Requirements
- Kubernetes cluster with at least 1 worker node
- 256MB RAM minimum for ingress controller
- MetalLB (optional, for LoadBalancer mode)

---

## 🔒 Cert-Manager

**Script**: `deploy-cert-manager.sh`

### What It Does
Deploys cert-manager, which automates the management and issuance of TLS certificates. It can automatically obtain certificates from Let's Encrypt or use self-signed certificates for testing.

### Why You Would Use It
- **Automatic TLS**: No manual certificate creation or renewal
- **Let's Encrypt integration**: Free, automated SSL certificates
- **Certificate lifecycle**: Auto-renewal before expiration
- **Kubernetes-native**: Manage certificates as Kubernetes resources
- **Multiple issuers**: Self-signed, Let's Encrypt, custom CA

### When You Need It
- You want HTTPS for your ingress resources
- You need TLS certificates for services
- You're building a production environment with SSL
- You want to avoid manual certificate management
- You need self-signed certs for testing

### Installation

```bash
./container-scripts/networking/deploy-cert-manager.sh <master-ip>
```

This installs:
- Cert-manager controller
- Webhook component
- CRDs (Custom Resource Definitions)
- Self-signed ClusterIssuer (for testing)

### Example Use Case

**Self-Signed Certificate (Testing)**:
```bash
# Deploy cert-manager
./deploy-cert-manager.sh 192.168.1.202

# Create ingress with TLS
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-tls
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
spec:
  tls:
  - hosts:
    - myapp.local
    secretName: myapp-tls
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
EOF

# Certificate auto-created!
kubectl get certificate
```

**Let's Encrypt (Production)**:
```bash
# After deploying cert-manager, create Let's Encrypt issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Use in ingress
# Change annotation to: cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### Configuration
- **Namespace**: `cert-manager`
- **Version**: v1.15.0
- **Default Issuer**: Self-signed ClusterIssuer
- **Components**: controller, webhook, cainjector

### Verification
```bash
# Check pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuer

# Check certificates
kubectl get certificate -A
```

### Requirements
- Kubernetes cluster
- Ingress controller (recommended, not required)
- For Let's Encrypt: publicly accessible ingress with valid domain

---

## Common Workflows

### Basic Web App with HTTPS
```bash
# 1. Deploy ingress controller
./deploy-ingress.sh 192.168.1.202

# 2. Deploy cert-manager
./deploy-cert-manager.sh 192.168.1.202

# 3. Deploy your app (example)
kubectl create deployment webapp --image=nginx
kubectl expose deployment webapp --port=80

# 4. Create ingress with TLS
kubectl create ingress webapp \
  --rule="webapp.local/*=webapp:80" \
  --annotation cert-manager.io/cluster-issuer=selfsigned-issuer \
  --class=nginx

# 5. Add TLS configuration
kubectl patch ingress webapp --type=json -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [{
      "hosts": ["webapp.local"],
      "secretName": "webapp-tls"
    }]
  }
]'

# 6. Access via HTTPS
echo "192.168.1.202 webapp.local" | sudo tee -a /etc/hosts
curl -k https://webapp.local  # -k ignores self-signed cert warning
```

### Multiple Apps on Same IP
```bash
# Deploy ingress once
./deploy-ingress.sh 192.168.1.202

# Deploy multiple apps
kubectl create deployment app1 --image=nginx
kubectl create deployment app2 --image=httpd
kubectl expose deployment app1 --port=80
kubectl expose deployment app2 --port=80

# Create ingress rules for each
kubectl create ingress app1 --rule="app1.local/*=app1:80"
kubectl create ingress app2 --rule="app2.local/*=app2:80"

# Access both via same IP, different hostnames
curl http://192.168.1.202:30080 -H "Host: app1.local"
curl http://192.168.1.202:30080 -H "Host: app2.local"
```

---

## Troubleshooting

### Ingress Controller Not Starting
```bash
# Check pod status
kubectl describe pod -n ingress-nginx <pod-name>

# Check logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Common issue: Port already in use
sudo netstat -tulpn | grep -E '30080|30443'
```

### Cert-Manager Certificate Not Issued
```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate request
kubectl get certificaterequest
kubectl describe certificaterequest <request-name>
```

### 404 on Ingress
- Verify backend service exists: `kubectl get svc`
- Check ingress rules: `kubectl describe ingress <ingress-name>`
- Ensure hostname matches (use `-H "Host: hostname"` with curl)

---

## Additional Resources

- **Nginx Ingress Docs**: https://kubernetes.github.io/ingress-nginx/
- **Cert-Manager Docs**: https://cert-manager.io/docs/
- **Let's Encrypt**: https://letsencrypt.org/
- **Main Project Docs**: [../../GETTING_STARTED.md](../../GETTING_STARTED.md)

---

**Tip**: Always deploy the ingress controller first, then cert-manager. This order ensures certificates can be properly validated through HTTP-01 challenges.
