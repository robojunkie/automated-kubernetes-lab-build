# Multi-OS Support: Design and Implementation

One of the core features of this project is seamless support for multiple Linux distributions. Here's how we architected it.

## Design Philosophy

### Goal
Write **once**, deploy **everywhere** (within reason).

### Constraints
- Different package managers (apt vs dnf/yum)
- Different default configurations (firewall, SELinux)
- Different package names (iscsi-initiator vs iscsi-initiator-utils)
- Must not require user to know their OS

### Solution
**OS detection + dispatch pattern** with OS-specific functions.

## Architecture

### Layer 1: OS Detection

```bash
detect_os_family() {
    local node_ip=$1
    
    # Read /etc/os-release
    local os_info=$(ssh_execute "$node_ip" "cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'")
    
    case "$os_info" in
        ubuntu|debian)
            echo "debian"
            ;;
        rocky|rhel|centos|almalinux)
            echo "rhel"
            ;;
        *)
            log_error "Unsupported OS: $os_info on $node_ip"
            exit 1
            ;;
    esac
}
```

**Key Decision**: Check `ID` field in `/etc/os-release` (standardized across modern Linux).

**Why not uname?**: `uname -a` returns kernel info, not distribution.

**Why not lsb_release?**: Not always installed by default.

### Layer 2: Dispatcher Functions

```bash
install_kubernetes_binaries() {
    local node_ip=$1
    local k8s_version=$2
    local os_family=$(detect_os_family "$node_ip")
    
    case "$os_family" in
        debian)
            install_kubernetes_binaries_debian "$node_ip" "$k8s_version"
            ;;
        rhel)
            install_kubernetes_binaries_rhel "$node_ip" "$k8s_version"
            ;;
        *)
            log_error "Unsupported OS family: $os_family"
            exit 1
            ;;
    esac
}
```

**Pattern**: Public function → OS detection → Dispatch to OS-specific implementation.

**Benefits**:
- Caller doesn't need to know OS
- Easy to add new OS families
- Clear separation of concerns

### Layer 3: OS-Specific Implementations

Each OS family gets its own implementation:

```bash
install_kubernetes_binaries_debian() { ... }
install_kubernetes_binaries_rhel() { ... }

ensure_container_runtime_ready_debian() { ... }
ensure_container_runtime_ready_rhel() { ... }
```

## Ubuntu 24.04 Implementation

### Package Management
```bash
# Update repos
sudo apt-get update -o Acquire::ForceIPv4=true

# Install packages
sudo apt-get install -y kubelet kubeadm kubectl

# Hold versions
sudo apt-mark hold kubelet kubeadm kubectl
```

**IPv4 Flag**: Force IPv4 to avoid dual-stack issues in some networks.

### GPG Key Handling
Modern Ubuntu uses signed-by in sources.list:

```bash
# Download and convert key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key -o /tmp/k8s-key.asc
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg /tmp/k8s-key.asc

# Add repo with signed-by
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

**Key Learning**: Download key locally first (avoid shell escaping issues), then copy and process on target node.

### Containerd Configuration
```bash
# Install from Docker repo (newer version)
sudo apt-get install -y containerd.io || sudo apt-get install -y containerd

# Generate default config
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart
sudo systemctl restart containerd
```

**Fallback Strategy**: Try Docker repo first, fall back to Ubuntu repo if unreachable.

### Firewall
Ubuntu typically has no firewall by default, or uses ufw. We don't configure it (not needed).

## Rocky Linux 9.6 Implementation

### Package Management
```bash
# Disable swap (required for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Add Kubernetes repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Install packages
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable kubelet
sudo systemctl enable kubelet
```

**Exclusions**: Prevent accidental upgrades with exclude list.

### SELinux Configuration
```bash
# Set to permissive (for lab use)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

**Why permissive?**: Lab environment, want containers to work without complex SELinux policies.

**Production**: Would create proper SELinux policies instead.

### Firewalld Configuration (The Complex Part)

#### Control Plane Ports
```bash
sudo firewall-cmd --permanent --add-port=6443/tcp        # Kubernetes API
sudo firewall-cmd --permanent --add-port=2379-2380/tcp   # etcd
sudo firewall-cmd --permanent --add-port=10250-10252/tcp # kubelet, scheduler, controller-manager
sudo firewall-cmd --permanent --add-port=10255/tcp       # read-only kubelet API
sudo firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort range
```

#### CNI Ports (All Options Supported)
```bash
# Calico
sudo firewall-cmd --permanent --add-port=179/tcp   # BGP (Bird)
sudo firewall-cmd --permanent --add-port=4789/udp  # VXLAN
sudo firewall-cmd --permanent --add-port=5473/tcp  # Typha (CRITICAL!)

# Flannel
sudo firewall-cmd --permanent --add-port=8472/udp  # VXLAN

# Weave
sudo firewall-cmd --permanent --add-port=6783/tcp  # Control
sudo firewall-cmd --permanent --add-port=6783/udp  # Data (sleeve)
sudo firewall-cmd --permanent --add-port=6784/udp  # Data (fastdp)
```

**Port 5473 Discovery**: This took 5 debugging iterations to discover. Calico Typha is critical for node-to-datastore communication. Without it, pods get IPs inconsistently and networking is flaky.

#### Webhook Ports
```bash
sudo firewall-cmd --permanent --add-port=443/tcp   # HTTPS
sudo firewall-cmd --permanent --add-port=9443/tcp  # Webhook server (MetalLB, etc.)
```

#### Trusted Zones for Pod/Service Networks
```bash
# Trust pod and service CIDRs completely
sudo firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16  # Pod CIDR
sudo firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/12   # Service CIDR
```

**Why trusted zone?**: Internal cluster traffic shouldn't be filtered.

#### Masquerading and Rich Rules
```bash
# Enable NAT
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --permanent --zone=trusted --add-masquerade

# Bidirectional rules for pod/service CIDRs in public zone
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.244.0.0/16 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.244.0.0/16 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 source address=10.96.0.0/12 accept'
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family=ipv4 destination address=10.96.0.0/12 accept'

# Apply changes
sudo firewall-cmd --reload
```

**Why rich rules?**: Need bidirectional allow for both source and destination within Kubernetes CIDRs.

## Calico CNI Optimization

Different OSes get different Calico configurations:

### Ubuntu: VXLANCrossSubnet Mode
```yaml
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
```

**Why VXLANCrossSubnet?**:
- BGP within subnet (faster, no encapsulation)
- VXLAN for cross-subnet (when needed)
- No firewall to worry about
- Best performance for most scenarios

### Rocky Linux: Pure VXLAN Mode
```yaml
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    bgp: Disabled
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLAN
```

**Why disable BGP?**:
- Firewalld makes BGP (port 179) complex
- BIRD daemon (BGP speaker) can have issues with firewall
- Pure VXLAN works reliably through firewall
- Slight performance cost, but worth the stability

**Trade-off**: ~5-10% performance vs 100% reliability.

## Storage Package Names

Different package names across distributions:

### Ubuntu/Debian
```bash
# iSCSI (for Longhorn)
sudo apt-get install -y open-iscsi

# NFS
sudo apt-get install -y nfs-common
```

### Rocky/RHEL
```bash
# iSCSI (for Longhorn)
sudo dnf install -y iscsi-initiator-utils

# NFS
sudo dnf install -y nfs-utils
```

**Pattern**: Check OS family, use appropriate package name.

## Testing Strategy

### Test Matrix
| OS | Package Install | Containerd | Firewall | CNI | MetalLB | Portainer | Full Stack |
|----|----------------|------------|----------|-----|---------|-----------|------------|
| Ubuntu 24.04 | ✅ | ✅ | N/A | ✅ | ✅ | ✅ | ✅ |
| Rocky 9.6 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### What We Test
1. **Clean Install**: Fresh OS → Full stack deployment
2. **Idempotency**: Run script twice, second run should succeed
3. **Component Selection**: All combinations of optional components
4. **Network Access**: LoadBalancer IPs work, NodePorts work
5. **Pod Communication**: Cross-node pod-to-pod works
6. **Service Discovery**: DNS resolution works
7. **Storage**: PVCs can be created and mounted

### Known Working Configurations
- Ubuntu 24.04 LTS + Calico VXLANCrossSubnet + MetalLB ✅
- Rocky Linux 9.6 + Calico VXLAN + MetalLB ✅
- Both with all optional components ✅

## Adding New OS Support

Want to add Debian 12 or AlmaLinux? Here's how:

### Step 1: Update OS Detection
```bash
detect_os_family() {
    local os_info=$(ssh_execute "$node_ip" "cat /etc/os-release | grep '^ID='")
    
    case "$os_info" in
        ubuntu|debian)  # Add new Debian-family OS here
            echo "debian"
            ;;
        rocky|rhel|centos|almalinux)  # Add new RHEL-family OS here
            echo "rhel"
            ;;
        opensuse|suse)  # New family? Add new case
            echo "suse"
            ;;
        *)
            log_error "Unsupported OS: $os_info"
            exit 1
            ;;
    esac
}
```

### Step 2: Test Existing Implementation
If new OS is in same family (e.g., AlmaLinux = RHEL-family), test with existing functions:
- Package installation
- Containerd setup
- Firewall configuration

### Step 3: Create OS-Specific Overrides (If Needed)
If something differs:

```bash
install_kubernetes_binaries_suse() {
    local node_ip=$1
    local k8s_version=$2
    
    # SUSE-specific implementation
    ssh_execute "$node_ip" "sudo zypper install -y kubelet kubeadm kubectl"
    # ... etc
}
```

Add to dispatcher:
```bash
case "$os_family" in
    debian) install_kubernetes_binaries_debian "$node_ip" "$k8s_version" ;;
    rhel) install_kubernetes_binaries_rhel "$node_ip" "$k8s_version" ;;
    suse) install_kubernetes_binaries_suse "$node_ip" "$k8s_version" ;;  # New!
esac
```

### Step 4: Update Documentation
- Add to supported OS list
- Document any OS-specific quirks
- Add to test matrix

## Lessons Learned

### What Worked Well

1. **OS Detection Pattern**: Simple, extensible
2. **Dispatcher Functions**: Clear separation of concerns
3. **Firewall Pre-Configuration**: All CNI options supported upfront
4. **OS-Specific Calico Config**: Optimizes for each platform

### What Was Challenging

1. **Firewall Rules**: Took multiple iterations to get right
2. **Port 5473 Discovery**: Not documented well in Calico docs
3. **Package Name Variations**: Required research for each OS
4. **GPG Key Handling**: Different across distributions

### What We'd Do Differently

1. **Firewall Testing Framework**: Automated port testing
2. **OS-Specific Config Files**: Templates instead of inline
3. **Parallel Node Setup**: Speed up deployments
4. **Rollback Mechanism**: Revert on failure

## Performance Comparison

| Metric | Ubuntu 24.04 | Rocky Linux 9.6 |
|--------|--------------|-----------------|
| Deployment Time | 15-20 min | 18-22 min |
| Pod Network Latency | ~0.1ms | ~0.2ms |
| Service Response Time | ~1ms | ~1ms |
| Overhead | Minimal | Firewalld + SELinux |

**Conclusion**: Rocky Linux is slightly slower due to firewall overhead, but difference is negligible for lab use.

## Future OS Support

### Planned
- Debian 12 (Bookworm) - Should work with Debian family functions
- AlmaLinux 9 - Should work with RHEL family functions
- CentOS Stream 9 - Should work with RHEL family functions

### Under Consideration
- OpenSUSE Leap/Tumbleweed - New family, needs zypper support
- Arch Linux - Rolling release, different philosophy
- Fedora - Similar to RHEL but faster-moving

### Not Planned
- Windows - WSL2 works differently, out of scope
- macOS - Can't run Kubernetes natively, use Docker Desktop
- *BSD - Different kernel, not Linux

## Contributing OS Support

Want to add support for your favorite distro? We accept PRs!

Requirements:
1. Implement OS detection for your distro
2. Create OS-specific installation functions
3. Test all components (at minimum: K8s + Calico + MetalLB + Portainer)
4. Document any quirks or special configuration
5. Update test matrix

See [Development Guide](Development) for contribution process.

---

**Multi-OS support makes this project useful to more people. The dispatch pattern keeps code maintainable while supporting diverse platforms.**
