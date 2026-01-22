#!/bin/bash
# Setup AWX with Kubernetes management playbooks

set -e

echo "=== AWX Kubernetes Management Setup ==="
echo ""

# Get AWX web pod name
AWX_POD=$(kubectl get pods -n awx -l app.kubernetes.io/name=awx-web -o jsonpath='{.items[0].metadata.name}')
echo "AWX Web Pod: $AWX_POD"

# Create project directory in AWX
echo "Creating project directory in AWX..."
kubectl exec -n awx $AWX_POD -c awx-web -- mkdir -p /var/lib/awx/projects/kubernetes-management

# Copy playbooks
echo "Copying playbooks to AWX..."
for playbook in fix-metallb.yml restart-deployment.yml check-cluster-health.yml scale-deployment.yml backup-cluster.yml list-loadbalancers.yml; do
    kubectl cp awx-playbooks/$playbook awx/$AWX_POD:/var/lib/awx/projects/kubernetes-management/$playbook -c awx-web
    echo "  ✓ $playbook"
done

# Verify
echo ""
echo "Verifying playbooks..."
kubectl exec -n awx $AWX_POD -c awx-web -- ls -la /var/lib/awx/projects/kubernetes-management/

echo ""
echo "=== Creating Kubernetes Credentials ==="

# Create service account for AWX
echo "Creating service account..."
kubectl create serviceaccount awx-operator -n awx --dry-run=client -o yaml | kubectl apply -f -

# Create cluster admin binding
echo "Creating cluster role binding..."
kubectl create clusterrolebinding awx-operator \
    --clusterrole=cluster-admin \
    --serviceaccount=awx:awx-operator \
    --dry-run=client -o yaml | kubectl apply -f -

# Generate token
echo ""
echo "=== IMPORTANT: Save this token for AWX credential setup ==="
echo ""
TOKEN=$(kubectl create token awx-operator -n awx --duration=87600h)
echo "$TOKEN"
echo ""

echo "=== Next Steps ==="
echo ""
echo "1. Login to AWX at http://awx.home.lab"
echo "   Username: admin"
echo "   Password: changeme123"
echo ""
echo "2. Create Kubernetes Credential:"
echo "   - Go to Resources → Credentials → Add"
echo "   - Name: Kubernetes Cluster"
echo "   - Type: OpenShift or Kubernetes API Bearer Token"
echo "   - API Endpoint: https://192.168.1.202:6443"
echo "   - Bearer Token: [paste token above]"
echo "   - Verify SSL: Unchecked"
echo ""
echo "3. Create Project:"
echo "   - Go to Resources → Projects → Add"
echo "   - Name: Kubernetes Management"
echo "   - Source Control Type: Manual"
echo "   - Playbook Directory: /var/lib/awx/projects/kubernetes-management"
echo ""
echo "4. Create Job Templates (see README.md for details)"
echo ""
echo "Setup complete! See awx-playbooks/README.md for full configuration guide."
