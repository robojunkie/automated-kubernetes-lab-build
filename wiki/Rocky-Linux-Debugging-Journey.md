# The Rocky Linux Debugging Journey

This page documents the complete debugging journey for Rocky Linux 9.6 support - a story of persistence, systematic troubleshooting, and eventual triumph.

## Starting Point

**Goal**: Make the automation work on Rocky Linux 9.6, not just Ubuntu 24.04.

**Known Challenges**:
- Different package manager (dnf vs apt)
- SELinux enabled by default
- Firewalld active by default
- Different repository structure

**Expected Difficulty**: Medium (a few hours)
**Actual Difficulty**: High (several debugging iterations)
**Key Learning**: Never underestimate firewall complexity

## Iteration 1: Basic Installation

### Attempt
Adapted package installation for dnf:

```bash
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
EOF

# Install packages
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```

### Result
✅ Packages install successfully  
✅ Containerd starts  
❌ kubeadm init fails with "port 6443 connection refused"

### Analysis
API server can't bind to port 6443. Checking:
```bash
sudo ss -tlnp | grep 6443
# Nothing listening
```

Not a port conflict. Something else is blocking.

### Hypothesis
Firewall is blocking. Let's add basic Kubernetes ports.

## Iteration 2: Basic Firewall Rules

### Attempt
Added Kubernetes control plane ports:

```bash
sudo firewall-cmd --permanent --add-port=6443/tcp        # API server
sudo firewall-cmd --permanent --add-port=2379-2380/tcp   # etcd
sudo firewall-cmd --permanent --add-port=10250/tcp       # kubelet
sudo firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort range
sudo firewall-cmd --reload
```

Disabled SELinux for simplicity:
```bash
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### Result
✅ kubeadm init succeeds  
✅ Master node shows Ready  
✅ Workers join successfully  
❌ Pods stuck in ContainerCreating  
❌ kubectl get pods -A shows Calico pods not running

### Analysis
```bash
kubectl describe pod calico-node-xxxxx -n calico-system
```

Output:
```
Events:
  Warning  FailedCreatePodSandbox  CNI failed to set up pod network
  Normal   SandboxChanged          Pod sandbox changed, recreating
```

Calico can't establish pod network. Must be missing CNI-related ports.

### Hypothesis
Calico uses BGP (port 179) and VXLAN (port 4789). Add those.

## Iteration 3: CNI Ports

### Attempt
Added Calico networking ports:

```bash
sudo firewall-cmd --permanent --add-port=179/tcp   # Calico BGP
sudo firewall-cmd --permanent --add-port=4789/udp  # Calico VXLAN
sudo firewall-cmd --reload
```

Restarted Calico:
```bash
kubectl delete pods -n calico-system --all
```

### Result
✅ Calico pods start and show Running  
✅ All nodes show Ready  
✅ Cluster seems healthy  
❌ MetalLB webhook validation fails  

### Analysis
Trying to deploy MetalLB:
```bash
kubectl apply -f metallb-namespace.yaml  # Works
kubectl apply -f metallb.yaml             # Works
kubectl apply -f ipaddresspool.yaml       # FAILS
```

Error:
```
Error from server (InternalError): error when creating "ipaddresspool.yaml": 
Internal error occurred: failed calling webhook "ipaddresspoolvalidationwebhook.metallb.io": 
Post "https://metallb-webhook-service.metallb-system.svc:443/validate-metallb-io-v1beta1-ipaddresspool": 
dial tcp 10.96.x.x:443: connect: connection refused
```

MetalLB webhook can't be reached. Firewall blocking webhook ports?

### Hypothesis
Webhooks use HTTPS (443) and often custom ports (9443). Add those.

## Iteration 4: Webhook Ports

### Attempt
Added webhook-related ports:

```bash
sudo firewall-cmd --permanent --add-port=443/tcp   # HTTPS
sudo firewall-cmd --permanent --add-port=9443/tcp  # Webhook server
sudo firewall-cmd --reload
```

Redeployed MetalLB:
```bash
kubectl delete ns metallb-system
# Wait for cleanup
# Redeploy MetalLB
```

### Result
✅ MetalLB webhook validation succeeds  
✅ IPAddressPool and L2Advertisement created  
✅ MetalLB speaker pods running  
❌ LoadBalancer services don't get external IPs  

### Analysis
```bash
kubectl get svc -A | grep LoadBalancer
```

Output shows `<pending>` in EXTERNAL-IP column.

Check MetalLB logs:
```bash
kubectl logs -n metallb-system <speaker-pod>
```

Logs show:
```
failed to announce 192.168.1.220: no interface found
unable to send gratuitous ARP
```

MetalLB can't reach the network. Something blocking Layer 2 traffic?

### Hypothesis
Need to trust the pod and service networks. Add trusted zones.

## Iteration 5: Trusted Zones

### Attempt
Added pod and service CIDRs to trusted zone:

```bash
# Trust pod and service networks completely
sudo firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16  # Pods
sudo firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/12   # Services
sudo firewall-cmd --reload
```

### Result
✅ MetalLB assigns external IPs  
✅ Services show actual IP addresses  
❌ Can't reach services from outside cluster  
❌ curl http://192.168.1.220 times out

### Analysis
Services have IPs but aren't reachable. Checking connectivity:

```bash
# From master node
curl http://192.168.1.220
# Works!

# From jump box (outside cluster)
curl http://192.168.1.220
# Timeout
```

Traffic from external network can't reach pods. Need masquerading/NAT?

### Hypothesis
Enable masquerading and add rich rules for bidirectional traffic.

## Iteration 6: Masquerading and Rich Rules

### Attempt
Added masquerading and explicit allow rules:

```bash
# Enable NAT/masquerading
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --permanent --zone=trusted --add-masquerade

# Bidirectional rules for pod/service CIDRs
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.244.0.0/16 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.244.0.0/16 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.96.0.0/12 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.96.0.0/12 accept'
sudo firewall-cmd --reload
```

### Result
✅ Services reachable from jump box  
✅ curl to LoadBalancer IPs works  
✅ Deployed nginx test pod, accessible  
✅ Deployed Portainer...  
❌ Portainer pod crashes with CrashLoopBackOff

### Analysis
```bash
kubectl logs portainer-xxxxx -n portainer
```

Logs show:
```
Failed to connect to Kubernetes API
Connection refused
Unable to list nodes
```

Portainer can't talk to API server. But other pods can (MetalLB works). What's different?

Checking Portainer's communication pattern:
- Uses in-cluster service account
- Talks to api-server via service IP (10.96.0.1:443)
- Seems to work initially, then fails

Sporadic nature suggests... synchronization issue with Calico?

### Hypothesis
Calico Typha port (5473) might be blocked. Typha handles scaling and synchronization.

## Iteration 7: The Typha Port (BREAKTHROUGH!)

### Attempt
Added Calico Typha port:

```bash
sudo firewall-cmd --permanent --add-port=5473/tcp  # Calico Typha
sudo firewall-cmd --reload
```

Restarted Calico and Portainer:
```bash
kubectl delete pods -n calico-system --all
kubectl delete pods -n portainer --all
```

### Result
✅ Portainer pod starts successfully  
✅ Portainer UI accessible  
✅ All services working  
✅ Pod-to-pod communication stable  
✅ Cross-node networking works  
✅ Everything just works!

**User confirmation**: "That worked!"

### Analysis - Why Port 5473 Was Critical

**What is Typha?**
- Typha is a Calico component that sits between the datastore (etcd) and Calico nodes
- Acts as a proxy/cache to reduce load on etcd
- Required for large-scale deployments
- Handles network policy distribution

**Why was it breaking things?**
Without port 5473 open:
1. Calico nodes can't reliably sync with Typha
2. Network policy updates don't propagate
3. IP address allocation becomes inconsistent
4. Some pods work, others mysteriously fail
5. Intermittent failures make debugging hard

**Why didn't Ubuntu have this issue?**
Ubuntu typically has no firewall by default (or uses ufw which we don't configure). Rocky Linux has firewalld active by default, blocking everything not explicitly allowed.

## The Complete Firewall Configuration

After 7 iterations, here's what works:

```bash
#!/bin/bash

# Kubernetes control plane ports
sudo firewall-cmd --permanent --add-port=6443/tcp        # API server
sudo firewall-cmd --permanent --add-port=2379-2380/tcp   # etcd
sudo firewall-cmd --permanent --add-port=10250-10252/tcp # kubelet, scheduler, controller
sudo firewall-cmd --permanent --add-port=10255/tcp       # read-only kubelet
sudo firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort services

# CNI ports - Calico
sudo firewall-cmd --permanent --add-port=179/tcp   # BGP (Bird daemon)
sudo firewall-cmd --permanent --add-port=4789/udp  # VXLAN encapsulation
sudo firewall-cmd --permanent --add-port=5473/tcp  # Typha (CRITICAL!)

# CNI ports - Other options (for flexibility)
sudo firewall-cmd --permanent --add-port=8472/udp  # Flannel VXLAN
sudo firewall-cmd --permanent --add-port=6783/tcp  # Weave control
sudo firewall-cmd --permanent --add-port=6783/udp  # Weave data (sleeve)
sudo firewall-cmd --permanent --add-port=6784/udp  # Weave data (fastdp)

# Webhook and service ports
sudo firewall-cmd --permanent --add-port=443/tcp   # HTTPS
sudo firewall-cmd --permanent --add-port=9443/tcp  # Webhook server

# Trust pod and service networks
sudo firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16  # Pod CIDR
sudo firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/12   # Service CIDR

# Enable masquerading for NAT
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --permanent --zone=trusted --add-masquerade

# Bidirectional rules for external access to pods/services
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.244.0.0/16 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.244.0.0/16 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.96.0.0/12 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.96.0.0/12 accept'

# Apply all changes
sudo firewall-cmd --reload
```

## Calico Configuration Optimization

During debugging, we also discovered that BGP mode caused issues with firewalld. The solution:

### Ubuntu: VXLANCrossSubnet (Hybrid)
```yaml
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
```
- Uses BGP within subnet (fast)
- Falls back to VXLAN for cross-subnet
- No firewall to worry about

### Rocky Linux: Pure VXLAN
```yaml
spec:
  calicoNetwork:
    bgp: Disabled
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLAN
```
- Disables BGP entirely
- Pure VXLAN overlay
- Works reliably through firewall
- Slight performance cost (~5-10%) but worth it for stability

## Debugging Tools Used

### Port Connectivity Testing
```bash
# Check if port is open
sudo firewall-cmd --list-ports

# Check if something is listening
sudo ss -tlnp | grep <port>

# Test connectivity from outside
nc -zv <node-ip> <port>

# Check firewall rules
sudo firewall-cmd --list-all --zone=public
sudo firewall-cmd --list-all --zone=trusted
```

### Kubernetes Debugging
```bash
# Node status
kubectl get nodes -o wide

# Pod status with details
kubectl get pods -A -o wide

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Pod logs
kubectl logs <pod-name> -n <namespace>

# Previous container logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous

# Check endpoints
kubectl get endpoints -A

# Check services
kubectl get svc -A
```

### Calico Debugging
```bash
# Check Calico status
kubectl get installation default -o yaml

# Calico node status
kubectl get pods -n calico-system

# Calico logs
kubectl logs -n calico-system <calico-node-pod>

# Check for Typha
kubectl get pods -n calico-system | grep typha

# BGP peering status (if using BGP)
kubectl exec -n calico-system <calico-node-pod> -- calicoctl node status
```

### MetalLB Debugging
```bash
# Check MetalLB resources
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Speaker logs
kubectl logs -n metallb-system <speaker-pod>

# Controller logs
kubectl logs -n metallb-system <controller-pod>

# Check webhook
kubectl get validatingwebhookconfiguration
```

## Lessons Learned

### Technical Lessons

1. **Firewalld blocks everything by default** - Must explicitly allow
2. **Typha is critical** - Not just for scale, required for reliability
3. **Trusted zones are your friend** - Don't fight firewall for pod networking
4. **Rich rules enable external access** - Bidirectional traffic needs explicit rules
5. **BGP + Firewall = Pain** - VXLAN mode is simpler and more reliable

### Debugging Lessons

1. **Work systematically** - Add one thing at a time
2. **Check logs immediately** - Errors tell you what's missing
3. **Test incrementally** - Don't deploy everything at once
4. **Document as you go** - Record what you tried
5. **Celebrate small wins** - Each working component is progress

### User Experience Lessons

1. **Hide complexity** - Users shouldn't need to know about Typha
2. **OS-specific config** - Different platforms need different settings
3. **Comprehensive setup** - Open all CNI ports upfront (avoid iteration)
4. **Test thoroughly** - Multiple OS families is not optional

## Timeline

**Day 1 - Morning**: Basic package installation works  
**Day 1 - Afternoon**: API server blocked, add basic firewall rules  
**Day 1 - Evening**: Pods stuck, add CNI ports  

**Day 2 - Morning**: MetalLB webhook fails, add webhook ports  
**Day 2 - Afternoon**: IPs assigned but unreachable, add trusted zones  
**Day 2 - Evening**: External access blocked, add masquerading and rich rules  

**Day 3 - Morning**: Portainer crashes, research Calico architecture  
**Day 3 - Afternoon**: **BREAKTHROUGH** - Add port 5473, everything works!  
**Day 3 - Evening**: Full testing, user confirms success

**Total debugging time**: ~2.5 days of focused work  
**Number of iterations**: 7  
**Critical discovery**: Port 5473 (Typha)

## The Typha Discovery Story

How did we figure out port 5473 was the issue?

1. **Observation**: Portainer worked briefly then crashed (timing issue)
2. **Hypothesis**: Some Calico component not syncing properly
3. **Research**: Read Calico architecture docs
4. **Discovery**: Typha mentioned as "datastore proxy"
5. **Confirmation**: Checked Calico installation, Typha pods present
6. **Testing**: Added port 5473
7. **Success**: Everything stabilized immediately

**Key insight**: Intermittent failures often indicate synchronization or timing issues, not just simple port blocks.

## Rocky Linux vs Ubuntu Summary

| Aspect | Ubuntu 24.04 | Rocky Linux 9.6 |
|--------|--------------|-----------------|
| Package Manager | apt | dnf |
| Kubernetes Repo | apt sources.list | yum repo file |
| Default Firewall | None/ufw | firewalld (active) |
| SELinux | Disabled | Enforcing (we set permissive) |
| Calico Mode | VXLANCrossSubnet | VXLAN only (bgp disabled) |
| Firewall Rules Needed | 0 | ~25 rules + trusted zones |
| Deployment Time | 15-20 min | 18-22 min |
| Debugging Difficulty | Low | High |

## For Other RHEL-Family Distributions

This firewall configuration works on:
- ✅ Rocky Linux 9.6 (tested)
- ✅ AlmaLinux 9 (should work, same base)
- ✅ RHEL 9 (should work, same base)
- ✅ CentOS Stream 9 (should work, similar)
- ⚠️ CentOS 7 (may need adjustments for older firewalld)

The key is that they all use firewalld with similar syntax.

---

**This debugging journey shows that persistence pays off. What seemed like an impossible firewall problem was solved by systematically adding rules until we found the missing piece: port 5473.**

**Total ports added**: 25+ individual ports + trusted zones + rich rules  
**Critical port**: 5473 (Typha)  
**Result**: Rocky Linux works identically to Ubuntu

**Lesson**: Sometimes the last 1% (one missing port) makes the difference between "completely broken" and "perfectly working."
