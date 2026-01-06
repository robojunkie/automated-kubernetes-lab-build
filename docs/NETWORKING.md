# Networking Guide

## Overview

This guide explains the networking setup and how to configure your lab environment for proper pod communication and external access.

## Pod Network (CNI)

### What is a CNI Plugin?

A Container Network Interface (CNI) plugin manages pod networking. It:
- Assigns IP addresses to pods
- Routes traffic between pods
- Implements network policies (optional)

### Choosing a CNI

| Plugin | Use Case | Performance | Network Policies | Complexity |
|--------|----------|-------------|------------------|------------|
| Calico | Production use, network policies needed | High | Yes | Medium |
| Flannel | Simple, lightweight overlay | Medium | No | Low |
| Weave | Full mesh, DNS support | Low | Yes | Medium |

**Recommendation**: Use **Calico** for labs that mimic production environments.

## Network Configuration

### Pod CIDR (Container Subnet)

Default: `10.244.0.0/16`

This subnet is used for pod IP addresses. Change it if conflicts with your LAN.

```bash
# Example: Use different pod subnet
bash build-lab.sh
# When prompted: Enter subnet for cluster networking: 10.100.0.0/16
```

### Service CIDR

Default: `10.96.0.0/12`

This subnet is for Kubernetes services (ClusterIP, LoadBalancer, etc.). Change if conflicts exist.

### Host Network

- Master node: e.g., `192.168.1.10/24`
- Worker node 1: e.g., `192.168.1.11/24`
- Worker node 2: e.g., `192.168.1.12/24`

## LAN Access

### How It Works

By default, pods are NOT directly accessible from your LAN. To enable LAN access:

#### Option 1: Use NodePort Services
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

Access from LAN: `http://192.168.1.10:30080` (or any node IP)

#### Option 2: Use LoadBalancer Services + MetalLB
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

Access from LAN: Uses external IP assigned by MetalLB

**Requirement**: MetalLB must be installed during deployment.

#### Option 3: Use Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  rules:
  - host: app.local
    http:
      paths:
      - path: /
        backend:
          service:
            name: my-service
            port:
              number: 80
```

Access from LAN: Configure DNS or /etc/hosts to point `app.local` to ingress IP.

## Public Container Access

### Enabling Public Access

When deploying, answer "yes" to public container access:

```
Make containers publicly accessible? (yes/no) [default: no]: yes
```

This installs:
- **MetalLB**: Assigns external IPs from your LAN subnet
- **NGINX Ingress Controller**: Routes HTTP/HTTPS traffic

### Firewall Configuration

If using a firewall:
1. Open port 80 (HTTP) and 443 (HTTPS)
2. Open NodePort range: 30000-32767
3. Allow traffic between cluster nodes

### Security Considerations

- Use NetworkPolicies to restrict pod-to-pod traffic
- Use RBAC to control API access
- Consider ingress TLS for external services
- Regularly update your Kubernetes version

## Network Policy Examples

### Allow traffic only from specific pods

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Block all traffic except specific

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Note**: Network policies only work with Calico, not Flannel.

## DNS

### Kubernetes DNS

Services are accessible via DNS:
- Format: `<service-name>.<namespace>.svc.cluster.local`
- Example: `nginx-service.default.svc.cluster.local`

### External DNS (Optional)

For external access, create DNS records:
```
api.example.com  A  192.168.1.10  (LoadBalancer IP)
```

Or use `/etc/hosts`:
```
192.168.1.10  app.local
192.168.1.10  api.local
```

## Troubleshooting Network Issues

### Pods cannot communicate

```bash
# Check CNI status
kubectl get daemonset -n kube-system

# Check pod networking
kubectl exec <pod-name> -- ip addr
kubectl exec <pod-name> -- ip route

# Test connectivity
kubectl exec <pod-a> -- ping <pod-b-ip>
```

### Service unreachable

```bash
# Check service
kubectl get svc <service-name>
kubectl describe svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Check service DNS
kubectl exec <pod-name> -- nslookup <service-name>
```

### LoadBalancer stuck in pending

```bash
# Check MetalLB
kubectl get pods -n metallb-system

# Check IP pool
kubectl get ipaddresspool -n metallb-system

# Check events
kubectl describe svc <service-name>
```

## Performance Tuning

### MTU (Maximum Transmission Unit)

Default: 1450 (for overlay networks)

Lower MTU = lower throughput, higher CPU
Higher MTU = higher throughput, potential fragmentation

Adjust in CNI config if needed:
```bash
# For Calico
kubectl patch configmap calico-config -n kube-system \
  -p '{"data":{"veth_mtu":"1500"}}'
```

### Enable BGP for better performance (Calico)

```yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  asNumber: 64512
```

## Advanced: Multiple Networks

For advanced use cases, consider CNI plugins that support multiple networks:
- Multus: Attach multiple networks to pods
- Whereabouts: More flexible IP allocation

## References

- [Kubernetes Networking](https://kubernetes.io/docs/concepts/services-networking/)
- [Calico Documentation](https://docs.projectcalico.org/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
