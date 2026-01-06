#!/bin/bash

# Quick setup guide - Print this to help new users get started

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║     Automated Kubernetes Lab Build - Quick Start Guide          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

## STEP 1: Prerequisites

Before starting, ensure you have:

1. A jump box with:
   - Linux operating system (Ubuntu, Debian, CentOS)
   - Bash shell
   - SSH client
   - Network access to all cluster nodes

2. Pre-provisioned cluster nodes:
   - Ubuntu 20.04+ OR Debian 10+ OR CentOS 7+
   - Minimum 2 CPUs per node
   - Minimum 2GB RAM for master, 1GB for workers
   - SSH access with password or key authentication
   - Network connectivity between all nodes

3. Network setup:
   - All nodes on same or routable network
   - Know your subnet (e.g., 192.168.1.0/24)
   - Cluster nodes have static IPs or known hostnames

## STEP 2: Clone the Repository

On your jump box, clone the repository:

```bash
git clone https://github.com/robojunkie/automated-kubernetes-lab-build.git
cd automated-kubernetes-lab-build
```

## STEP 3: Run the Build Script

Start the interactive deployment:

```bash
bash scripts/build-lab.sh
```

The script will prompt you for:
- Cluster name
- Master node hostname/IP
- Worker node count and addresses
- Subnet for pod networking
- Whether to enable public container access
- Kubernetes version
- CNI plugin choice (Calico, Flannel, Weave)

## STEP 4: Answer the Prompts

Example session:
```
Enter cluster name [default: k8s-lab]: my-k8s-lab
Enter master node hostname or IP: 192.168.1.10
Enter number of worker nodes [default: 2]: 2
Enter hostname or IP of worker node 1: 192.168.1.11
Enter hostname or IP of worker node 2: 192.168.1.12
Enter subnet for cluster networking (e.g., 192.168.1.0/24): 10.244.0.0/16
Make containers publicly accessible? (yes/no) [default: no]: no
Enter Kubernetes version [default: 1.28]: 1.28
Select CNI plugin (calico|flannel|weave) [default: calico]: calico
```

Review the summary and type 'yes' to proceed.

## STEP 5: Wait for Deployment

The script will:
1. Validate network connectivity
2. Configure networking prerequisites
3. Install Kubernetes binaries
4. Initialize the master node
5. Join worker nodes
6. Install CNI plugin
7. Setup optional add-ons

This typically takes 10-20 minutes depending on network speed.

## STEP 6: Verify Cluster

Once complete, verify your cluster:

```bash
# Set kubeconfig (path provided at end of deployment)
export KUBECONFIG=./my-k8s-lab-kubeconfig.yaml

# Check nodes
kubectl get nodes

# Check pods
kubectl get pods -A

# Check services
kubectl get svc -A
```

Expected output:
```
NAME      STATUS   ROLES           AGE   VERSION
master    Ready    control-plane   5m    v1.28.0
worker-1  Ready    <none>          3m    v1.28.0
worker-2  Ready    <none>          3m    v1.28.0
```

## STEP 7: Deploy Your First Application

Create a simple deployment:

```bash
kubectl apply -f examples/simple-deployment.yaml
```

Check the deployment:
```bash
kubectl get deployments
kubectl get pods
```

## Useful Next Steps

### Access the Dashboard (if installed)
```bash
kubectl proxy
# Visit http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### Test Pod Networking
```bash
kubectl run debug --image=alpine --rm -it -- sh
# Inside pod
ping 8.8.8.8
nslookup kubernetes.default
```

### Check Node Status
```bash
kubectl describe node <node-name>
kubectl top nodes
kubectl top pods -A
```

### View Logs
```bash
kubectl logs -f <pod-name>
kubectl logs -n kube-system <pod-name>
```

## Configuration File Option

Instead of interactive prompts, use a configuration file:

```bash
cp examples/example-config.env my-config.env
# Edit my-config.env with your settings
bash scripts/build-lab.sh -c my-config.env
```

## Dry-Run Mode

Test without making changes:

```bash
bash scripts/build-lab.sh -d -c my-config.env
```

## Troubleshooting

If something goes wrong:

1. Check the log file: `deployment.log`
2. Review [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. Check SSH connectivity manually
4. Verify node requirements
5. Check firewall rules

## Documentation

For more detailed information:

- [README.md](README.md) - Project overview
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Design details
- [NETWORKING.md](docs/NETWORKING.md) - Networking guide
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues
- [CONTRIBUTING.md](docs/CONTRIBUTING.md) - Contribution guidelines

## Support

- GitHub Issues: https://github.com/robojunkie/automated-kubernetes-lab-build/issues
- GitHub Discussions: https://github.com/robojunkie/automated-kubernetes-lab-build/discussions

## What's Included

✓ Automated Kubernetes cluster deployment
✓ Production-grade kubeadm setup
✓ Flexible networking (Calico, Flannel, Weave)
✓ Optional MetalLB for load balancing
✓ Optional NGINX Ingress Controller
✓ Optional Kubernetes Dashboard
✓ Comprehensive documentation
✓ Example deployments
✓ Troubleshooting guides

## Next: Monetization Ideas

Once you have a working lab, you can:

1. **Create templates**: Package this for Proxmox, VirtualBox, etc.
2. **Develop tutorials**: Make video guides on YouTube
3. **Build add-ons**: Create additional tools for this lab
4. **Offer services**: Deploy labs for others (Upwork/Freelancer)
5. **Publish tools**: Create utilities that simplify usage

This project demonstrates your cloud engineering skills and can be a foundation
for your side hustles mentioned in our earlier conversation.

Good luck with your lab and your cloud engineering journey!

═══════════════════════════════════════════════════════════════════

Need help? Check the documentation or open an issue on GitHub.

EOF

EOF
