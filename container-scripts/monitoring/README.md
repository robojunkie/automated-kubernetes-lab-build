# Monitoring Deployment Script

Deploy comprehensive monitoring and observability for your Kubernetes cluster.

---

## 📊 Prometheus + Grafana Monitoring Stack

**Script**: `deploy-monitoring.sh`

### What It Does
Deploys the kube-prometheus-stack, which includes:
- **Prometheus**: Time-series database for metrics
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification (optional)
- **Node Exporter**: Collects host-level metrics
- **Kube-State-Metrics**: Kubernetes object metrics
- **Pre-configured dashboards**: 20+ dashboards for Kubernetes

### Why You Would Use It
- **Cluster visibility**: See what's happening in your cluster at a glance
- **Performance monitoring**: CPU, memory, disk, network metrics
- **Troubleshooting**: Identify bottlenecks and issues quickly
- **Capacity planning**: Understand resource usage trends
- **Alerting**: Get notified when things go wrong
- **Production standard**: Industry-standard monitoring solution

### When You Need It
- You want to monitor cluster health and performance
- You need to troubleshoot resource issues
- You want to track application metrics
- You're building a production environment
- You need historical metrics for capacity planning
- You want beautiful dashboards for presentations
- You're learning Kubernetes and want to see what's happening

### Installation

**Basic (NodePort)**:
```bash
./container-scripts/monitoring/deploy-monitoring.sh <master-ip>
```
- Grafana: `http://<node-ip>:30300`
- Prometheus: `http://<node-ip>:30090`

### What Gets Deployed
- **Prometheus Operator**: Manages Prometheus instances
- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and visualization
- **Node Exporter**: Metrics from each node
- **Kube-State-Metrics**: Kubernetes object state metrics
- **Service Monitors**: Auto-discover services to monitor
- **Pre-built Dashboards**: 20+ dashboards included

### Default Credentials

**Grafana**:
- Username: `admin`
- Password: `admin` (change on first login)

**Prometheus**:
- No authentication (accessible via NodePort)

### Example Use Cases

**Monitor Cluster Health**:
```bash
# Deploy monitoring
./deploy-monitoring.sh 192.168.1.202

# Access Grafana
# Browser: http://192.168.1.202:30300
# Login: admin / admin

# Navigate to pre-built dashboards:
# - Kubernetes / Compute Resources / Cluster
# - Kubernetes / Compute Resources / Namespace (Pods)
# - Kubernetes / Networking / Cluster
# - Node Exporter / Nodes
```

**Track Application Metrics**:
```bash
# Your app exposes /metrics endpoint
kubectl create deployment myapp --image=myapp:latest

# Create ServiceMonitor to scrape metrics
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
EOF

# Metrics automatically appear in Prometheus!
```

**Set Up Alerts**:
```bash
# Create PrometheusRule for alerts
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-alerts
  namespace: monitoring
spec:
  groups:
  - name: nodes
    interval: 30s
    rules:
    - alert: HighNodeMemory
      expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Node {{ \$labels.instance }} is low on memory"
        description: "Only {{ \$value | humanizePercentage }} memory available"
EOF

# View alerts in Prometheus UI
# Browser: http://192.168.1.202:30090/alerts
```

**Query Metrics Directly**:
```bash
# PromQL examples (paste in Prometheus UI)

# CPU usage per node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per pod
container_memory_usage_bytes{namespace="default"}

# Network traffic per namespace
sum(rate(container_network_transmit_bytes_total[5m])) by (namespace)

# Disk usage per node
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes
```

### Pre-Configured Dashboards

Grafana includes these dashboards out-of-the-box:

**Cluster Overview**:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Namespace (Workloads)
- Kubernetes / Compute Resources / Node (Pods)
- Kubernetes / Compute Resources / Pod

**Networking**:
- Kubernetes / Networking / Cluster
- Kubernetes / Networking / Namespace (Pods)
- Kubernetes / Networking / Namespace (Workload)
- Kubernetes / Networking / Pod

**Storage**:
- Kubernetes / Persistent Volumes

**System**:
- Node Exporter / Nodes
- Node Exporter / USE Method / Node
- Node Exporter / USE Method / Cluster

**Components**:
- Kubernetes / API Server
- Kubernetes / Kubelet
- Kubernetes / Scheduler
- Kubernetes / Controller Manager

### Configuration
- **Namespace**: `monitoring`
- **Prometheus Port**: 30090 (NodePort)
- **Grafana Port**: 30300 (NodePort)
- **Data Retention**: 15 days (default)
- **Scrape Interval**: 30 seconds
- **Storage**: Uses cluster default StorageClass

### Verification
```bash
# Check pods (should see ~10 pods)
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Access Grafana
# Browser: http://<node-ip>:30300

# Access Prometheus
# Browser: http://<node-ip>:30090

# Check Prometheus targets (should see many targets)
# Prometheus UI → Status → Targets
```

### Common Tasks

**Change Grafana Password**:
```bash
# After first login, click profile → Change Password
# Or via CLI:
kubectl exec -n monitoring deployment/monitoring-grafana -- \
  grafana-cli admin reset-admin-password newpassword
```

**Add Custom Dashboard**:
```bash
# In Grafana UI:
# 1. Click "+" → Import
# 2. Enter dashboard ID from https://grafana.com/grafana/dashboards/
# 3. Popular IDs:
#    - 315: Kubernetes cluster monitoring
#    - 12740: Kubernetes Monitoring
#    - 6417: Kubernetes Deployment Statefulset Daemonset metrics
```

**Increase Data Retention**:
```bash
# Edit Prometheus resource
kubectl edit prometheus -n monitoring

# Add/modify:
spec:
  retention: 30d  # Increase from 15d to 30d
```

**Configure Alertmanager** (Optional):
```bash
# Create secret with Alertmanager config
cat <<EOF | kubectl create secret generic alertmanager-monitoring-kube-prometheus-alertmanager --from-file=alertmanager.yaml=/dev/stdin -n monitoring
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack'

receivers:
- name: 'slack'
  slack_configs:
  - channel: '#alerts'
    title: 'Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
EOF
```

### Resource Requirements
- **Minimum**: 2GB RAM total across cluster
- **Recommended**: 4GB+ RAM for full stack
- **Storage**: ~10GB for metrics (15 days retention)
- **CPU**: Minimal (spikes during scraping)

### What Metrics Are Collected

**Node Metrics** (from Node Exporter):
- CPU usage, load average
- Memory usage, available memory
- Disk I/O, disk space
- Network traffic, errors
- Temperature, hardware info

**Kubernetes Metrics** (from kube-state-metrics):
- Pod status, restarts, resource usage
- Deployment status, replicas
- Node status, capacity
- PVC usage
- Service endpoints

**Application Metrics** (via ServiceMonitors):
- Custom metrics from your apps
- HTTP request rates, latency
- Database connection pools
- Cache hit rates
- Any metrics your app exposes

---

## Monitoring Workflows

### Basic Monitoring Workflow
```bash
# 1. Deploy monitoring
./deploy-monitoring.sh 192.168.1.202

# 2. Access Grafana
# http://192.168.1.202:30300
# Login: admin / admin

# 3. Explore dashboards
# Dashboards → Browse → "Kubernetes" folder

# 4. Start with "Compute Resources / Cluster"
# See cluster-wide CPU, memory, network

# 5. Drill down to specific namespace
# "Compute Resources / Namespace (Pods)"
```

### Troubleshooting High CPU
```bash
# 1. Open "Compute Resources / Cluster" dashboard
# 2. Identify namespace with high CPU
# 3. Open "Compute Resources / Namespace (Pods)"
# 4. Select problematic namespace
# 5. See which pod is consuming CPU
# 6. Investigate that specific pod

# Or query directly in Prometheus:
# http://192.168.1.202:30090

# Top CPU consumers:
topk(10, rate(container_cpu_usage_seconds_total{container!=""}[5m]))
```

### Capacity Planning
```bash
# View historical trends in Grafana
# - Set time range to "Last 30 days"
# - View "Compute Resources / Cluster"
# - Note peak usage times
# - Plan for 20-30% overhead

# Export dashboard as PDF for reports:
# Dashboard → Share → Export → Save as PDF
```

### Setting Up for Production
```bash
# 1. Change Grafana password immediately
# 2. Configure Alertmanager (see above)
# 3. Increase retention to 30+ days
# 4. Configure persistent storage for Prometheus
# 5. Set up ServiceMonitors for your apps
# 6. Create custom dashboards for your workloads
# 7. Test alert delivery
```

---

## Troubleshooting

### Prometheus Not Scraping Targets
```bash
# Check Prometheus UI → Status → Targets
# http://192.168.1.202:30090/targets

# Common issues:
# - Firewall blocking ports
# - Service has no endpoints
# - ServiceMonitor selector doesn't match

# Check ServiceMonitors
kubectl get servicemonitor -n monitoring

# Check if service has endpoints
kubectl get endpoints <service-name>
```

### Grafana Dashboards Empty
```bash
# Verify Prometheus is set as data source
# Grafana → Configuration → Data Sources

# Test Prometheus connectivity
# Data Sources → Prometheus → "Test"

# Check Prometheus has data
# http://192.168.1.202:30090
# Try query: up
```

### High Memory Usage
```bash
# Prometheus stores metrics in RAM
# Reduce retention or increase RAM

# Check current usage
kubectl top pod -n monitoring

# Reduce retention
kubectl edit prometheus -n monitoring
# Change: retention: 7d
```

### Pods Not Starting
```bash
# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Check pod status
kubectl describe pod -n monitoring <pod-name>

# Common issue: Insufficient resources
# Solution: Add more RAM to nodes or reduce replica count
```

---

## Integration Examples

### Monitor Custom Application
```python
# Python app exposing Prometheus metrics
from prometheus_client import start_http_server, Counter, Gauge
import time

# Define metrics
requests = Counter('myapp_requests_total', 'Total requests')
cpu_usage = Gauge('myapp_cpu_usage', 'CPU usage')

# Start metrics server
start_http_server(8000)

# In your application code
requests.inc()  # Increment counter
cpu_usage.set(45.2)  # Set gauge value

# Expose via service
# kubectl expose deployment myapp --port=8000 --name=myapp-metrics

# Create ServiceMonitor (see examples above)
```

### Alert on Application Errors
```yaml
# Create PrometheusRule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
spec:
  groups:
  - name: application
    rules:
    - alert: HighErrorRate
      expr: rate(myapp_errors_total[5m]) > 0.05
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High error rate in myapp"
        description: "Error rate is {{ $value }} errors/sec"
```

---

## Additional Resources

- **Prometheus Docs**: https://prometheus.io/docs/
- **Grafana Docs**: https://grafana.com/docs/
- **PromQL Tutorial**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Grafana Dashboards**: https://grafana.com/grafana/dashboards/
- **Awesome Prometheus**: https://github.com/roaldnefs/awesome-prometheus
- **Main Project Docs**: [../../GETTING_STARTED.md](../../GETTING_STARTED.md)

---

**Tip**: Start by exploring the pre-built "Kubernetes / Compute Resources / Cluster" dashboard. It gives you a great overview of your cluster's health and performance!
