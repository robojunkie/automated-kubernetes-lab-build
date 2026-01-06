# Troubleshooting Guide

## Common Issues and Solutions

### 1. SSH Connectivity Problems

#### Issue: Cannot connect to cluster nodes via SSH

**Symptoms:**
```
ERROR: Cannot connect via SSH to: 192.168.1.10
```

**Solutions:**

1. **Check SSH connectivity manually:**
   ```bash
   ssh -v root@192.168.1.10 echo "test"
   ```

2. **Verify SSH is running on nodes:**
   ```bash
   systemctl status sshd
   ```

3. **Check firewall rules:**
   ```bash
   # On the node
   sudo firewall-cmd --list-all
   # If needed, allow SSH
   sudo firewall-cmd --permanent --add-service=ssh
   sudo firewall-cmd --reload
   ```

4. **Verify SSH key permissions:**
   ```bash
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   ```

5. **Check network connectivity:**
   ```bash
   ping 192.168.1.10
   ```

---

### 2. kubeadm Initialization Fails

#### Issue: Master node initialization fails during kubeadm init

**Symptoms:**
```
ERROR: kubeadm init failed
```

**Solutions:**

1. **Check system requirements:**
   ```bash
   # On the node
   free -h          # Check RAM (minimum 2GB)
   nproc             # Check CPU cores (minimum 2)
   ```

2. **Verify containerd is running:**
   ```bash
   systemctl status containerd
   systemctl restart containerd
   ```

3. **Check disk space:**
   ```bash
   df -h /var
   ```

4. **Clear previous installation:**
   ```bash
   sudo kubeadm reset --force
   sudo rm -rf /etc/kubernetes /var/lib/kubelet
   sudo iptables -F
   ```

5. **Verify DNS resolution:**
   ```bash
   nslookup kubernetes.default
   nslookup google.com
   ```

---

### 3. Nodes Not Becoming Ready

#### Issue: kubectl get nodes shows nodes as NotReady

**Symptoms:**
```
NAME           STATUS     ROLES           AGE   VERSION
master         NotReady   control-plane   10m   v1.28.0
worker-1       NotReady   <none>          5m    v1.28.0
```

**Solutions:**

1. **Check CNI plugin status:**
   ```bash
   kubectl get daemonset -n kube-system
   ```

2. **Verify kubelet is running:**
   ```bash
   # On the node
   systemctl status kubelet
   journalctl -u kubelet -n 100
   ```

3. **Check kubelet logs for errors:**
   ```bash
   journalctl -u kubelet -f --no-pager | grep -i error
   ```

4. **Verify container runtime:**
   ```bash
   # On the node
   systemctl status containerd
   crictl ps
   ```

5. **Check node resources:**
   ```bash
   kubectl describe node <node-name>
   ```

---

### 4. Pods Stuck in Pending

#### Issue: Pods remain in Pending state indefinitely

**Symptoms:**
```
NAME                      READY   STATUS    RESTARTS   AGE
nginx-deployment-xxx      0/1     Pending   0          10m
```

**Solutions:**

1. **Check pod events:**
   ```bash
   kubectl describe pod <pod-name>
   # Look for "Events" section
   ```

2. **Check node resources:**
   ```bash
   kubectl top nodes
   kubectl describe node
   ```

3. **Verify CNI is working:**
   ```bash
   kubectl get pods -n kube-system | grep -i cni
   ```

4. **Check persistent volume claims:**
   ```bash
   kubectl get pvc
   kubectl describe pvc <pvc-name>
   ```

---

### 5. Pod-to-Pod Communication Fails

#### Issue: Pods cannot communicate with each other

**Symptoms:**
```
Pod A cannot reach Pod B
DNS resolution fails within cluster
```

**Solutions:**

1. **Test basic connectivity:**
   ```bash
   kubectl exec <pod-a> -- ping <pod-b-ip>
   kubectl exec <pod-a> -- nc -zv <pod-b-ip> 8080
   ```

2. **Check CNI plugin:**
   ```bash
   kubectl get daemonset -n kube-system
   kubectl logs -n kube-system <cni-daemonset-pod>
   ```

3. **Verify network policies:**
   ```bash
   kubectl get networkpolicies -A
   # If policies exist, check they allow traffic
   ```

4. **Check DNS:**
   ```bash
   kubectl exec <pod-name> -- nslookup kubernetes.default
   kubectl exec <pod-name> -- cat /etc/resolv.conf
   ```

5. **Verify iptables rules:**
   ```bash
   # On node
   sudo iptables -L -n -v
   sudo iptables -t nat -L -n -v
   ```

---

### 6. Service LoadBalancer Stuck in Pending

#### Issue: External IP never gets assigned

**Symptoms:**
```
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
service   LoadBalancer   10.96.0.1      <pending>     80:30080/TCP
```

**Solutions:**

1. **Verify MetalLB is installed:**
   ```bash
   kubectl get pods -n metallb-system
   ```

2. **Check MetalLB configuration:**
   ```bash
   kubectl get ipaddresspool -n metallb-system
   kubectl get l2advertisement -n metallb-system
   ```

3. **Check MetalLB logs:**
   ```bash
   kubectl logs -n metallb-system deployment/metallb-controller -f
   kubectl logs -n metallb-system daemonset/metallb-speaker -f
   ```

4. **Verify IP pool configuration:**
   ```bash
   kubectl describe ipaddresspool -n metallb-system
   ```

---

### 7. Ingress Not Routing Traffic

#### Issue: Ingress rules not working, traffic not routed

**Symptoms:**
```
curl http://app.local returns 404 or connection refused
```

**Solutions:**

1. **Verify ingress controller:**
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl get svc -n ingress-nginx
   ```

2. **Check ingress resource:**
   ```bash
   kubectl get ingress
   kubectl describe ingress <ingress-name>
   ```

3. **Verify DNS:**
   ```bash
   # From your local machine
   nslookup app.local
   # Should return ingress IP
   ```

4. **Check DNS in /etc/hosts:**
   ```
   192.168.1.10 app.local
   ```

5. **Check backend service:**
   ```bash
   kubectl get svc <backend-service>
   kubectl get endpoints <backend-service>
   ```

---

### 8. Worker Node Cannot Join Master

#### Issue: Worker node join command fails

**Symptoms:**
```
ERROR: kubeadm join failed on worker
Failed to validate DnsName ...
```

**Solutions:**

1. **Verify join command:**
   ```bash
   # On master
   kubeadm token list
   kubeadm token create --print-join-command
   ```

2. **Check network connectivity:**
   ```bash
   # From worker to master
   ping <master-ip>
   telnet <master-ip> 6443
   ```

3. **Verify DNS:**
   ```bash
   # On worker
   nslookup <master-ip>
   ```

4. **Check kubelet logs:**
   ```bash
   # On worker
   journalctl -u kubelet -n 100
   ```

---

### 9. Certificate Issues

#### Issue: TLS certificate errors or authentication failures

**Symptoms:**
```
x509: certificate has expired
certificate signed by unknown authority
```

**Solutions:**

1. **Check certificate expiry:**
   ```bash
   # On master
   kubeadm certs check-expiration
   ```

2. **Renew certificates:**
   ```bash
   # On master
   sudo kubeadm certs renew all
   sudo systemctl restart kubelet
   ```

3. **Verify kubeconfig:**
   ```bash
   kubectl auth can-i get pods
   ```

---

### 10. High CPU/Memory Usage

#### Issue: Cluster consuming excessive resources

**Solutions:**

1. **Identify resource-heavy pods:**
   ```bash
   kubectl top pods -A
   kubectl top nodes
   ```

2. **Check pod resource requests/limits:**
   ```bash
   kubectl describe pod <pod-name>
   ```

3. **Set resource quotas:**
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: compute-quota
   spec:
     hard:
       requests.cpu: "10"
       requests.memory: 20Gi
       limits.cpu: "20"
       limits.memory: 40Gi
   ```

---

## Debugging Commands Reference

### Cluster Status
```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
```

### Node Debugging
```bash
kubectl describe node <node-name>
kubectl debug node/<node-name>
```

### Pod Debugging
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # For crashed pods
kubectl exec -it <pod-name> -- /bin/sh
kubectl describe pod <pod-name>
```

### Network Debugging
```bash
kubectl run debug --image=alpine --rm -it -- sh
# Inside pod:
ping <ip>
nslookup <service>
telnet <ip> <port>
```

### Events
```bash
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get events -n <namespace>
```

### System Logs
```bash
# On nodes
journalctl -u kubelet -f
journalctl -u containerd -f
dmesg
```

---

## Getting Help

1. **Check the logs**: Start with kubelet and container runtime logs
2. **Describe resources**: Use `kubectl describe` for detailed information
3. **Check Kubernetes documentation**: https://kubernetes.io/docs/
4. **Search GitHub issues**: https://github.com/kubernetes/kubernetes/issues
5. **Community forums**: Stack Overflow, Kubernetes Slack

## Reporting Issues

When reporting issues, include:
- Kubernetes version: `kubectl version`
- Cluster info: `kubectl cluster-info`
- Node info: `kubectl get nodes -o wide`
- Pod status: `kubectl describe pod <pod>`
- Relevant logs: `kubectl logs <pod>`
- Configuration: `kubectl get <resource> -o yaml`
