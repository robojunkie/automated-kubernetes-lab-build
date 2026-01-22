# AWX Kubernetes Management Setup Guide

This directory contains Ansible playbooks for managing your Kubernetes cluster via AWX.

## Playbooks

### 1. fix-metallb.yml
**Purpose**: Restart MetalLB speaker pods to fix LoadBalancer connectivity issues  
**Variables**: None  
**Use Case**: When LoadBalancer services become unreachable after cluster restarts

### 2. restart-deployment.yml
**Purpose**: Perform a rolling restart of a deployment  
**Variables**:
- `deployment_name` (required): Name of the deployment
- `namespace` (required): Namespace of the deployment  
**Example**: Restart portainer deployment in portainer namespace

### 3. check-cluster-health.yml
**Purpose**: Comprehensive cluster health check  
**Variables**: None  
**Reports**: Nodes, pods, MetalLB, LoadBalancers, PVCs, and problem pods

### 4. scale-deployment.yml
**Purpose**: Scale a deployment to specific number of replicas  
**Variables**:
- `deployment_name` (required): Name of the deployment
- `namespace` (required): Namespace
- `replicas` (required): Target number of replicas  
**Use Case**: Scale up/down workloads

### 5. backup-cluster.yml
**Purpose**: Backup all Kubernetes resources to YAML files  
**Variables**: None  
**Output**: `/tmp/k8s-backups/YYYY-MM-DD-HHMM/`

### 6. list-loadbalancers.yml
**Purpose**: Display all LoadBalancer services and their IPs  
**Variables**: None  
**Use Case**: Quick overview of exposed services

## AWX Setup Instructions

### 1. Add Kubernetes Credential

1. Go to **Resources → Credentials**
2. Click **Add**
3. Fill in:
   - **Name**: `Kubernetes Cluster`
   - **Credential Type**: `OpenShift or Kubernetes API Bearer Token`
   - **OpenShift or Kubernetes API Endpoint**: `https://192.168.1.202:6443`
   - **API authentication bearer token**: Get from master node:
     ```bash
     kubectl create serviceaccount awx-operator -n awx
     kubectl create clusterrolebinding awx-operator --clusterrole=cluster-admin --serviceaccount=awx:awx-operator
     kubectl create token awx-operator -n awx --duration=87600h
     ```
   - **Verify SSL**: Unchecked (for home lab)
4. Click **Save**

### 2. Create Project for Playbooks

1. Go to **Resources → Projects**
2. Click **Add**
3. Fill in:
   - **Name**: `Kubernetes Management`
   - **Organization**: `Default`
   - **Source Control Type**: `Manual`
4. Click **Save**
5. Copy playbooks to AWX:
   ```bash
   kubectl cp awx-playbooks/ awx/awx-web-<pod-id>:/var/lib/awx/projects/kubernetes-management/
   ```

### 3. Create Job Templates

For each playbook, create a job template:

#### Fix MetalLB Template
1. Go to **Resources → Templates**
2. Click **Add → Add job template**
3. Fill in:
   - **Name**: `Fix MetalLB LoadBalancers`
   - **Job Type**: `Run`
   - **Inventory**: `Localhost` (create if needed)
   - **Project**: `Kubernetes Management`
   - **Playbook**: `fix-metallb.yml`
   - **Credentials**: `Kubernetes Cluster`
   - **Options**: Check "Enable Fact Storage"
4. Click **Save**

#### Restart Deployment Template
1. **Name**: `Restart Deployment`
2. **Playbook**: `restart-deployment.yml`
3. **Credentials**: `Kubernetes Cluster`
4. **Variables** (in YAML):
   ```yaml
   ---
   deployment_name: ""
   namespace: ""
   ```
5. **Survey**: Add survey with:
   - `deployment_name` (Text, Required)
   - `namespace` (Text, Required, Default: default)

#### Check Cluster Health Template
1. **Name**: `Check Cluster Health`
2. **Playbook**: `check-cluster-health.yml`
3. **Credentials**: `Kubernetes Cluster`

#### Scale Deployment Template
1. **Name**: `Scale Deployment`
2. **Playbook**: `scale-deployment.yml`
3. **Credentials**: `Kubernetes Cluster`
4. **Survey**: Add:
   - `deployment_name` (Text, Required)
   - `namespace` (Text, Required)
   - `replicas` (Integer, Required, Min: 0)

#### Backup Cluster Template
1. **Name**: `Backup Cluster Resources`
2. **Playbook**: `backup-cluster.yml`
3. **Credentials**: `Kubernetes Cluster`

#### List LoadBalancers Template
1. **Name**: `List LoadBalancer Services`
2. **Playbook**: `list-loadbalancers.yml`
3. **Credentials**: `Kubernetes Cluster`

### 4. Create Users and Teams

#### Create Operators Team
1. Go to **Access → Teams**
2. Click **Add**
3. **Name**: `Operators`
4. **Organization**: `Default`
5. Click **Save**

#### Add Family Members
1. Go to **Access → Users**
2. Click **Add**
3. Fill in user details
4. **User Type**: `Normal User`
5. Add to **Operators** team

#### Set Permissions
1. On each job template, click **Access**
2. Add **Operators** team with **Execute** permission
3. For admins, use **Admin** permission

### 5. Create Dashboard (Optional)

1. Go to **Views → Dashboard**
2. Pin frequently used job templates
3. Create workflow templates for complex operations

## Quick Start Commands

### Copy Playbooks to AWX
```bash
# Get the web pod name
kubectl get pods -n awx | grep awx-web

# Copy playbooks
kubectl cp awx-playbooks/ awx/<web-pod-name>:/var/lib/awx/projects/kubernetes-management/ -c awx-web

# Verify
kubectl exec -n awx <web-pod-name> -c awx-web -- ls -la /var/lib/awx/projects/kubernetes-management/
```

### Create Service Account Token
```bash
# Create service account and binding
kubectl create serviceaccount awx-operator -n awx
kubectl create clusterrolebinding awx-operator --clusterrole=cluster-admin --serviceaccount=awx:awx-operator

# Generate long-lived token (10 years)
kubectl create token awx-operator -n awx --duration=87600h
```

## Ansible Collection Requirements

The playbooks use the `kubernetes.core` collection. It's pre-installed in AWX execution environments, but if needed:

```yaml
collections:
  - name: kubernetes.core
    version: ">=2.3.0"
```

## Troubleshooting

### Connection Issues
- Verify kubeconfig/token is valid
- Check API endpoint is accessible from AWX pods
- Ensure service account has proper RBAC permissions

### Playbook Failures
- Check AWX job output logs
- Verify variables are correctly passed
- Test playbook manually: `ansible-playbook -vvv playbook.yml`

### Permission Errors
- Verify service account has cluster-admin role
- Check namespace access if using namespace-scoped credentials

## Security Notes

For production use:
1. Use namespace-scoped service accounts instead of cluster-admin
2. Enable SSL verification
3. Use shorter-lived tokens with regular rotation
4. Implement approval workflows for destructive operations
5. Enable audit logging in AWX
6. Use secrets management for sensitive data
