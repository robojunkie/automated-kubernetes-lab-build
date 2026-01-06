# Monitoring Quick Start Guide (Prometheus + Grafana)

Monitor your Kubernetes cluster with beautiful dashboards and powerful metrics.

## What is This?

This setup includes:
- **Prometheus** - Collects metrics from all cluster components
- **Grafana** - Visualizes metrics in beautiful dashboards
- **Alertmanager** - Sends alerts when things go wrong (configured separately)
- **Node Exporter** - Exposes hardware/OS metrics from each node
- **kube-state-metrics** - Exposes Kubernetes object metrics

## Accessing Grafana

### Find Grafana URL

**With LoadBalancer**:
```bash
kubectl get svc -n monitoring grafana

# Access at: http://<EXTERNAL-IP>:3000
```

**With NodePort**:
```bash
# Access at: http://<any-node-ip>:30300
# Example: http://192.168.1.206:30300
```

### Default Login

- **Username**: `admin`
- **Password**: `admin`

**First login**: Grafana will ask you to change the password. Choose a strong one!

## Grafana Dashboard Tour

### Home Screen

After logging in:
- 📊 **Dashboards** - Pre-installed Kubernetes dashboards
- 🔍 **Explore** - Query metrics directly
- ⚙️ **Configuration** - Data sources, users, plugins
- 🔔 **Alerting** - Set up alert rules

### Pre-Installed Dashboards

Navigate: **Dashboards → Browse**

You'll find dashboards for:
1. **Kubernetes / Compute Resources / Cluster**
   - Overall cluster CPU/memory usage
   - Resource requests vs limits
   - Pod counts

2. **Kubernetes / Compute Resources / Namespace (Pods)**
   - Resource usage per namespace
   - Top pods by CPU/memory

3. **Kubernetes / Compute Resources / Node (Pods)**
   - Resource usage per node
   - Top pods on each node

4. **Kubernetes / Compute Resources / Pod**
   - Individual pod metrics
   - Container CPU/memory usage

5. **Kubernetes / Networking / Cluster**
   - Network I/O
   - Bandwidth usage
   - Packet rates

6. **Node Exporter Full**
   - Hardware metrics (CPU, memory, disk, network)
   - System metrics (load average, processes)

## Your First Dashboard: Cluster Overview

### 1. Open the Cluster Dashboard

**Path**: Dashboards → Browse → "Kubernetes / Compute Resources / Cluster"

### 2. What You'll See

**Top Section** - Key Metrics:
- CPU Usage (percentage of total cluster CPU)
- Memory Usage (percentage of total cluster RAM)
- Pod Count (running pods vs capacity)

**CPU Section**:
- Usage by namespace (who's using the most CPU?)
- CPU Requests vs Limits vs Actual Usage
- Identify over/under-provisioned workloads

**Memory Section**:
- Usage by namespace
- Memory Requests vs Limits vs Actual Usage

**Network Section**:
- Receive/transmit bandwidth
- Packet rates

### 3. Time Range

**Top-right corner** - Change time range:
- Last 5 minutes
- Last 15 minutes
- Last 1 hour
- Last 24 hours
- Custom range

**Refresh** - Auto-refresh every 30s, 1m, 5m, etc.

## Exploring Node Metrics

### Node Exporter Dashboard

**Path**: Dashboards → Browse → "Node Exporter Full"

**Select a node** - Use the "instance" dropdown at the top

### Key Metrics

**System**:
- Uptime
- Load average (1m, 5m, 15m)
- CPU cores
- Memory total

**CPU**:
- Usage by mode (user, system, idle, iowait)
- Per-core usage
- Context switches

**Memory**:
- Used vs available
- Swap usage (should be minimal!)
- Cache and buffers

**Disk**:
- Usage per filesystem
- I/O operations
- Read/write bandwidth
- Inode usage

**Network**:
- Traffic per interface
- Errors and drops
- Connections state

## Exploring Pod Metrics

### Pod Dashboard

**Path**: Dashboards → Browse → "Kubernetes / Compute Resources / Pod"

**Select namespace and pod** - Use dropdowns at top

### What You'll See

**CPU Usage**:
- Current usage
- Trend over time
- Throttling (if requests are too low)

**Memory Usage**:
- Current usage
- Trend over time
- OOM kills (if limits are too low)

**Network**:
- Bandwidth in/out
- Can identify network-intensive apps

## Creating Your Own Dashboard

### 1. Create New Dashboard

Click **+ (Plus icon) → Dashboard**

### 2. Add a Panel

Click **Add visualization**

### 3. Choose Data Source

Select **Prometheus**

### 4. Write a Query

Example - Total pods in cluster:
```promql
sum(kube_pod_info)
```

Click **Run queries** to see the result

### 5. Choose Visualization

**Panel type**:
- Time series (line graph)
- Gauge (single value with threshold colors)
- Stat (big number)
- Table (tabular data)
- Bar chart
- Pie chart

### 6. Configure Panel

**Panel options**:
- **Title**: "Total Pods"
- **Description**: "Number of pods in the cluster"

**Value options**:
- Units (e.g., "short" for plain numbers)
- Decimals
- Min/max values

**Threshold** (for gauges/stats):
- Green: 0-50 (normal)
- Yellow: 50-80 (warning)
- Red: 80+ (critical)

### 7. Save Dashboard

Click **Save dashboard** (disk icon, top-right)
- Give it a name
- Choose folder (or create new)

## Useful PromQL Queries

### Cluster-Level

**CPU usage by node**:
```promql
sum by (node) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))
```

**Memory usage by node**:
```promql
sum by (node) (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
```

**Total disk usage**:
```promql
sum(node_filesystem_size_bytes - node_filesystem_avail_bytes)
```

### Pod-Level

**Top 10 CPU-consuming pods**:
```promql
topk(10, sum by (pod, namespace) (rate(container_cpu_usage_seconds_total[5m])))
```

**Top 10 memory-consuming pods**:
```promql
topk(10, sum by (pod, namespace) (container_memory_usage_bytes))
```

**Pods with OOM kills**:
```promql
sum by (pod, namespace) (increase(container_oom_events_total[1h]))
```

### Namespace-Level

**CPU usage by namespace**:
```promql
sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))
```

**Memory usage by namespace**:
```promql
sum by (namespace) (container_memory_usage_bytes)
```

### Service-Level

**Request rate for a service**:
```promql
rate(http_requests_total{service="my-app"}[5m])
```

**Error rate**:
```promql
rate(http_requests_total{service="my-app",status=~"5.."}[5m])
```

## Alerting (Basic Setup)

### 1. Create Alert Rule

**Path**: Alerting → Alert rules → New alert rule

### 2. Define Query

Example - High CPU usage:
```promql
sum(rate(node_cpu_seconds_total{mode!="idle"}[5m])) / count(node_cpu_seconds_total{mode="idle"}) > 0.8
```

This triggers when cluster CPU > 80%

### 3. Set Conditions

- **Threshold**: > 0.8
- **For**: 5m (must be true for 5 minutes before alerting)
- **Evaluate every**: 1m

### 4. Add Details

- **Alert name**: "High Cluster CPU"
- **Summary**: "Cluster CPU usage is above 80%"
- **Description**: "CPU: {{ $value }}%"

### 5. Configure Notification

**Contact point** - Where to send alerts:
- Email (configure SMTP in Configuration → Alerting)
- Slack (webhook URL)
- PagerDuty
- Webhook (custom endpoint)

### 6. Save

Click **Save rule and exit**

## Monitoring Your Applications

### Exposing Metrics

Your application should expose metrics in Prometheus format at `/metrics`.

**Example** - Python Flask app:
```python
from flask import Flask
from prometheus_client import Counter, Histogram, generate_latest

app = Flask(__name__)

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

@app.route('/metrics')
def metrics():
    return generate_latest()

@app.route('/api/users')
@REQUEST_DURATION.time()
def users():
    REQUEST_COUNT.labels('GET', '/api/users', '200').inc()
    return {"users": []}
```

### ServiceMonitor Resource

Tell Prometheus to scrape your app:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics  # Name of port in your service
    interval: 30s
    path: /metrics
```

### Verify Scraping

**Grafana → Explore**:
```promql
up{job="my-app"}
```

Should return `1` (up) or `0` (down)

## Accessing Prometheus Directly

### Prometheus UI

```bash
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090
```

Open browser: `http://localhost:9090`

**Use cases**:
- Test PromQL queries
- View scrape targets (Status → Targets)
- View configuration (Status → Configuration)
- Debug service discovery

## Storage Considerations

### Retention

Default retention: **15 days**

Prometheus stores metrics in TSDB (Time Series Database) on local disk.

**Check storage usage**:
```bash
kubectl exec -n monitoring prometheus-k8s-0 -- du -sh /prometheus
```

### Expand Storage (if needed)

```bash
# Check current PVC
kubectl get pvc -n monitoring

# Edit StatefulSet
kubectl edit statefulset -n monitoring prometheus-k8s

# Find:
  volumeClaimTemplates:
  - spec:
      resources:
        requests:
          storage: 10Gi

# Change to:
      storage: 50Gi

# Delete and recreate pods to use new size
kubectl delete pod -n monitoring prometheus-k8s-0
```

## Troubleshooting

### Can't Access Grafana

**Check pod status**:
```bash
kubectl get pods -n monitoring | grep grafana
# Should be Running
```

**Check service**:
```bash
kubectl get svc -n monitoring grafana
# Should have EXTERNAL-IP or NodePort
```

**Check logs**:
```bash
kubectl logs -n monitoring <grafana-pod-name>
```

### No Data in Dashboards

**Check Prometheus is running**:
```bash
kubectl get pods -n monitoring | grep prometheus
# Should see prometheus-k8s-0 and prometheus-k8s-1 Running
```

**Check data source**:
Grafana → Configuration → Data sources → Prometheus
- URL should be `http://prometheus-k8s.monitoring.svc:9090`
- Click "Save & test" - should show green checkmark

**Check Prometheus targets**:
```bash
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090
```
Open `http://localhost:9090/targets`
- All targets should be "UP"

### Some Metrics Missing

**Check ServiceMonitor**:
```bash
kubectl get servicemonitor -n monitoring
```

**Check Prometheus scrape config**:
```bash
kubectl exec -n monitoring prometheus-k8s-0 -- cat /etc/prometheus/config_out/prometheus.env.yaml
```

Look for your service in the scrape configs

### High Memory Usage

Prometheus can use a lot of memory with many metrics.

**Reduce retention**:
```bash
kubectl edit prometheus -n monitoring k8s

# Change:
spec:
  retention: 15d
# To:
spec:
  retention: 7d
```

**Reduce scrape frequency**:
Edit ServiceMonitors to increase `interval` from 30s to 60s or more

## Best Practices

### ✅ Do
- Set up alerts for critical resources (CPU, memory, disk)
- Create dashboards for your applications
- Use meaningful metric names
- Add labels to metrics (app, version, environment)
- Monitor query performance (slow queries can impact Prometheus)

### ❌ Don't
- Scrape too frequently (30s is usually enough)
- Expose unlimited metrics (high cardinality kills performance)
- Store logs in Prometheus (use Loki or similar)
- Run without resource limits (Prometheus can consume a lot)

## Example: Complete Monitoring Setup

### 1. Application with Metrics

```python
# app.py
from flask import Flask
from prometheus_client import Counter, Gauge, Histogram, generate_latest
import time

app = Flask(__name__)

REQUEST_COUNT = Counter('myapp_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('myapp_request_duration_seconds', 'Request duration', ['endpoint'])
ACTIVE_USERS = Gauge('myapp_active_users', 'Currently active users')

@app.route('/metrics')
def metrics():
    return generate_latest()

@app.route('/api/data')
def data():
    start = time.time()
    # Your logic here
    duration = time.time() - start
    
    REQUEST_COUNT.labels('GET', '/api/data', '200').inc()
    REQUEST_DURATION.labels('/api/data').observe(duration)
    
    return {"data": "example"}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### 2. Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        ports:
        - name: http
          containerPort: 8080
        - name: metrics
          containerPort: 8080  # Same port, different name
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: metrics
    port: 8080
    targetPort: 8080
```

### 3. ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - default
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### 4. Grafana Dashboard

Create dashboard with panels for:
- Request rate: `rate(myapp_requests_total[5m])`
- Error rate: `rate(myapp_requests_total{status=~"5.."}[5m])`
- Latency: `histogram_quantile(0.95, myapp_request_duration_seconds_bucket[5m])`
- Active users: `myapp_active_users`

## Next Steps

- Set up alerts for critical metrics
- Create custom dashboards for your applications
- [Integrate with ingress](INGRESS.md) for `grafana.lab.local` access
- Export dashboards as JSON for version control
- Explore Prometheus exporters for databases, message queues, etc.

## References

- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
- PromQL Cheat Sheet: https://promlabs.com/promql-cheat-sheet/
- Kube-Prometheus: https://github.com/prometheus-operator/kube-prometheus

---

**Pro tip**: Create a dashboard for each application you deploy - makes troubleshooting 10x easier!
