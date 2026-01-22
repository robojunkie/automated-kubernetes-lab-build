# AWX Kubernetes Management - Quick Setup

## ✅ Credentials Created

Service Account Token (valid for 10 years):
```
eyJhbGciOiJSUzI1NiIsImtpZCI6ImxNTnJjQTRlOHpzVFR2M3NBYmhjRGdlTGJnOV9ISVBidXYwTjBVQTVRcjAifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoyMDg0NDcwNzcwLCJpYXQiOjE3NjkxMTA3NzAsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJhd3giLCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiYXd4LW9wZXJhdG9yIiwidWlkIjoiYzE5YWU1Y2ItZjAwNy00OTA4LTg2YzQtYTczNjBiMGFhMmFiIn19LCJuYmYiOjE3NjkxMTA3NzAsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDphd3g6YXd4LW9wZXJhdG9yIn0.jG_hk8gu1_jCg3Is4EQFGLUa0K9TOM3dv81--Z9gsBYXPJVxKyqU_2WEYehwi0vNvqmbnu73i0N12DcgthOrhXcXAF4_lOVRkvXmn6ESWRZXCAnz_FlvGfkUQpOsqHC-PqmFQhPW61tv__KfyA3rsM4OEMzjjZGq1PULsWGL4j3d05K09-GvKpBj24284bv8DsGA4EWFwUhxqFpw9mqkvP0dqAfuCM1BSLgIlt4_ML-50zSt5LkjFt97v_NsmUF_ouNjqAnvBaA4gKOs4n-gwSv4HkdDZFkrvipyJE9bBLklJyM4lPPwtdTcJrj1RZ3lYVmlTEuQkd75NnN6s26mfA
```

## Step 1: Login to AWX

- **URL**: http://awx.home.lab (or http://192.168.1.54)
- **Username**: `admin`
- **Password**: `changeme123`

## Step 2: Add Kubernetes Credential

1. Go to **Resources → Credentials**
2. Click **Add**
3. Fill in:
   - **Name**: `Kubernetes Cluster`
   - **Organization**: `Default`
   - **Credential Type**: `OpenShift or Kubernetes API Bearer Token`
   - **OpenShift or Kubernetes API Endpoint**: `https://192.168.1.202:6443`
   - **API authentication bearer token**: [paste token above]
   - **Verify SSL**: **UNCHECKED** ✓
4. Click **Save**

## Step 3: Add Project from GitHub

Since the playbooks are in your local repo, let's use AWX's built-in playbook creation:

1. Go to **Resources → Projects**
2. Click **Add**
3. Fill in:
   - **Name**: `Kubernetes Management`
   - **Organization**: `Default`
   - **Execution Environment**: `Default execution environment`
   - **Source Control Type**: `Git`
   - **Source Control URL**: `https://github.com/yourusername/automated-kubernetes-lab-build.git`
   - **Source Control Branch**: `main`
   - **Update Revision on Launch**: Checked
4. Click **Save**

### Alternative: Manual Project Setup

If you don't want to use Git:

1. SSH to master node:
   ```bash
   ssh rswanson@192.168.1.202
   ```

2. Copy playbooks to AWX via kubectl:
   ```bash
   # Create a configmap with playbooks
   kubectl create configmap k8s-playbooks -n awx \
     --from-file=awx-playbooks/fix-metallb.yml \
     --from-file=awx-playbooks/restart-deployment.yml \
     --from-file=awx-playbooks/check-cluster-health.yml \
     --from-file=awx-playbooks/scale-deployment.yml \
     --from-file=awx-playbooks/backup-cluster.yml \
     --from-file=awx-playbooks/list-loadbalancers.yml
   ```

3. Mount configmap to AWX (I'll provide deployment patch)

## Step 4: Create Inventory

1. Go to **Resources → Inventories**
2. Click **Add → Add inventory**
3. Fill in:
   - **Name**: `Localhost`
   - **Organization**: `Default`
4. Click **Save**
5. Click **Hosts** tab → **Add**
6. Fill in:
   - **Name**: `localhost`
   - **Variables** (YAML):
     ```yaml
     ---
     ansible_connection: local
     ansible_python_interpreter: /usr/bin/python3
     ```
7. Click **Save**

## Step 5: Create Job Templates

### Template 1: Fix MetalLB LoadBalancers

1. Go to **Resources → Templates → Add → Add job template**
2. Fill in:
   - **Name**: `Fix MetalLB LoadBalancers`
   - **Job Type**: `Run`
   - **Inventory**: `Localhost`
   - **Project**: `Kubernetes Management`
   - **Playbook**: `awx-playbooks/fix-metallb.yml`
   - **Credentials**: Select `Kubernetes Cluster`
   - **Verbosity**: `0 (Normal)`
   - **Options**: Check "Enable Privilege Escalation" if needed
3. Click **Save**

### Template 2: Check Cluster Health

1. **Name**: `Check Cluster Health`
2. **Playbook**: `awx-playbooks/check-cluster-health.yml`
3. **Inventory**: `Localhost`
4. **Credentials**: `Kubernetes Cluster`
5. Click **Save**

### Template 3: Restart Deployment

1. **Name**: `Restart Deployment`
2. **Playbook**: `awx-playbooks/restart-deployment.yml`
3. **Credentials**: `Kubernetes Cluster`
4. **Variables** (YAML):
   ```yaml
   ---
   deployment_name: ""
   namespace: "default"
   ```
5. Click **Save**
6. Click **Survey** tab → **Add**
7. Add questions:
   - **Prompt**: "Deployment Name"
   - **Answer Variable Name**: `deployment_name`
   - **Answer Type**: Text
   - **Required**: Yes
   
   - **Prompt**: "Namespace"
   - **Answer Variable Name**: `namespace`
   - **Answer Type**: Text
   - **Default**: `default`
   - **Required**: Yes
8. Click **Save**

### Template 4: Scale Deployment

1. **Name**: `Scale Deployment`
2. **Playbook**: `awx-playbooks/scale-deployment.yml`
3. Add survey with:
   - `deployment_name` (Text, Required)
   - `namespace` (Text, Required, Default: default)
   - `replicas` (Integer, Required, Min: 0, Max: 10)

### Template 5: List LoadBalancers

1. **Name**: `List LoadBalancer Services`
2. **Playbook**: `awx-playbooks/list-loadbalancers.yml`

### Template 6: Backup Cluster

1. **Name**: `Backup Cluster Resources`
2. **Playbook**: `awx-playbooks/backup-cluster.yml`

## Step 6: Test a Job

1. Go to **Resources → Templates**
2. Click the rocket 🚀 icon next to **Check Cluster Health**
3. Click **Launch**
4. Watch the job run!

## Step 7: Create Family User Accounts

1. Go to **Access → Users → Add**
2. Fill in:
   - **Username**: Family member name
   - **Password**: Set password
   - **User Type**: `Normal User`
3. Click **Save**

### Set Permissions

1. Go to **Resources → Templates**
2. Click on a template
3. Click **Access** tab → **Add**
4. Select the user
5. Grant **Execute** permission
6. Repeat for each template

## Quick Test Commands

Test the playbooks locally first:

```bash
cd ~/awx-playbooks

# Test fix metallb (requires kubernetes.core collection)
ansible-playbook fix-metallb.yml

# Test health check
ansible-playbook check-cluster-health.yml

# Test with variables
ansible-playbook restart-deployment.yml -e "deployment_name=portainer namespace=portainer"
```

## Available Playbooks

| Playbook | Purpose | Variables |
|----------|---------|-----------|
| fix-metallb.yml | Restart MetalLB speakers | None |
| check-cluster-health.yml | Cluster health report | None |
| restart-deployment.yml | Rolling restart | deployment_name, namespace |
| scale-deployment.yml | Scale replicas | deployment_name, namespace, replicas |
| backup-cluster.yml | Backup resources | None |
| list-loadbalancers.yml | List LB services | None |

## Troubleshooting

### "kubernetes.core not found"
The kubernetes.core collection should be included in AWX's execution environment. If not, add it via:
- **Administration → Execution Environments**
- Use an EE with kubernetes.core pre-installed

### Connection refused to API
- Verify the token is correct
- Check the API endpoint URL
- Ensure SSL verification is disabled for self-signed certs

### Permission denied
- Verify service account has cluster-admin role
- Check the token hasn't expired

## Next Steps

- Set up email notifications for job failures
- Create workflow templates for complex operations
- Set up scheduling for health checks
- Enable audit logging
- Create teams for different permission levels
