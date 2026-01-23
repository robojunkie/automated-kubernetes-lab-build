# Kubernetes Monitoring with Prometheus & Grafana

Complete monitoring solution for your Kubernetes cluster and home lab infrastructure.

## Overview

The kube-prometheus-stack includes:
- **Prometheus**: Time-series database and metric collection
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notifications
- **Node Exporter**: Hardware and OS metrics
- **Kube State Metrics**: Kubernetes object metrics
- **Prometheus Operator**: Manages Prometheus instances

## Quick Start

### Deploy Monitoring Stack

```bash
cd ~/automated-kubernetes-lab-build
chmod +x container-scripts/monitoring/deploy-monitoring.sh
./container-scripts/monitoring/deploy-monitoring.sh
```

### Access Grafana

1. Get the LoadBalancer IP:
   ```bash
   kubectl get svc -n monitoring kube-prometheus-stack-grafana
   ```

2. Add DNS to pfSense:
   - Host: `grafana`
   - Domain: `home.lab`
   - IP: [LoadBalancer IP from step 1]

3. Login at http://grafana.home.lab:3000
   - **Username**: admin
   - **Password**: changeme123 (change this!)

## Pre-configured Dashboards

Grafana comes with excellent pre-loaded dashboards:

### Kubernetes Cluster Monitoring
- **Kubernetes / Compute Resources / Cluster** - Overall cluster resource usage
- **Kubernetes / Compute Resources / Namespace (Pods)** - Pod-level metrics
- **Kubernetes / Compute Resources / Node (Pods)** - Node-level pod metrics
- **Kubernetes / Networking / Cluster** - Network traffic and bandwidth
- **Kubernetes / Persistent Volumes** - Storage metrics

### Node Monitoring
- **Node Exporter / Nodes** - CPU, memory, disk, network per node
- **Node Exporter / USE Method / Node** - Utilization, Saturation, Errors

### Application Monitoring
- **Kubernetes / API Server** - Control plane health
- **Kubernetes / Kubelet** - Kubelet metrics
- **Prometheus / Overview** - Prometheus internals

## Monitor External LAN Devices

### 1. Install Node Exporter on External Servers

On any Linux server you want to monitor:

```bash
# Download and install node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Verify
curl http://localhost:9100/metrics
```

### 2. Add External Targets to Prometheus

Edit `configs/monitoring-values.yaml` and add targets:

```yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: 'external-nodes'
      static_configs:
      - targets:
        - '192.168.1.10:9100'  # Your NAS
        - '192.168.1.15:9100'  # Your standalone server
        labels:
          environment: 'home-lan'
```

Update the deployment:
```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f configs/monitoring-values.yaml
```

### 3. Monitor pfSense Router

Install the pfSense Prometheus exporter:

1. In pfSense, go to **System → Package Manager → Available Packages**
2. Search for and install **node_exporter**
3. Go to **Services → node_exporter**
4. Enable it on port 9100

Add to Prometheus config:
```yaml
- job_name: 'pfsense'
  static_configs:
  - targets:
    - '192.168.1.1:9100'
    labels:
      device: 'pfsense-router'
```

### 4. Monitor Network Devices (SNMP)

For switches, routers, etc. that support SNMP:

1. Deploy SNMP exporter:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install snmp-exporter prometheus-community/prometheus-snmp-exporter -n monitoring
   ```

2. Add to Prometheus config:
   ```yaml
   - job_name: 'snmp-devices'
     static_configs:
     - targets:
       - '192.168.1.20'  # Cisco switch
       labels:
         device: 'cisco-3560x'
     metrics_path: /snmp
     params:
       module: [if_mib]
     relabel_configs:
     - source_labels: [__address__]
       target_label: __param_target
     - target_label: __address__
       replacement: snmp-exporter-prometheus-snmp-exporter:9116
   ```

## Configure Alertmanager

### Email Notifications

Edit `configs/monitoring-values.yaml`:

```yaml
alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alerts@yourdomain.com'
      smtp_auth_username: 'your-email@gmail.com'
      smtp_auth_password: 'your-app-password'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'email-alerts'
    
    receivers:
    - name: 'email-alerts'
      email_configs:
      - to: 'admin@yourdomain.com'
        headers:
          Subject: 'K8s Alert: {{ .GroupLabels.alertname }}'
```

### Slack Notifications

```yaml
receivers:
- name: 'slack-alerts'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    channel: '#k8s-alerts'
    title: 'K8s Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Common Alerts

The stack includes pre-configured alerts for:

### Cluster Health
- **KubeAPIDown** - API server unavailable
- **KubeNodeNotReady** - Node in NotReady state
- **KubePodCrashLooping** - Pod repeatedly crashing
- **KubePodNotReady** - Pod not ready for extended time

### Resource Usage
- **NodeMemoryPressure** - Node memory usage > 85%
- **NodeDiskPressure** - Node disk usage > 85%
- **KubeCPUOvercommit** - CPU overcommitted
- **KubeMemoryOvercommit** - Memory overcommitted

### Storage
- **KubePersistentVolumeFillingUp** - PV filling up
- **KubePersistentVolumeErrors** - PV mount errors

### Networking
- **KubeNetworkUnavailable** - Network plugin issues
- **KubeProxyDown** - kube-proxy unavailable

## Custom Dashboards

### Import Community Dashboards

1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID from https://grafana.com/grafana/dashboards/
3. Popular IDs:
   - **15760** - Kubernetes Cluster Monitoring (via Prometheus)
   - **13639** - Node Exporter Quickstart
   - **7362** - Kubernetes Cluster
   - **12006** - Kubernetes API Server

### Create Custom Dashboard for MetalLB

1. Go to Grafana → Dashboards → New → New Dashboard
2. Add panel with query:
   ```promql
   # MetalLB speaker pod status
   kube_pod_status_ready{namespace="metallb-system", condition="true"}
   
   # LoadBalancer services
   kube_service_info{type="LoadBalancer"}
   
   # MetalLB logs errors
   rate(metallb_speaker_announced{job="metallb-speaker"}[5m])
   ```

## Useful Prometheus Queries

### Cluster Resource Usage
```promql
# Total CPU usage
sum(rate(container_cpu_usage_seconds_total[5m]))

# Total memory usage
sum(container_memory_usage_bytes)

# Pod count by namespace
count(kube_pod_info) by (namespace)

# Node CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### LoadBalancer Monitoring
```promql
# LoadBalancer service count
count(kube_service_info{type="LoadBalancer"})

# Services without external IP (stuck)
kube_service_status_load_balancer_ingress{} == 0
```

### Storage Monitoring
```promql
# PVC usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100

# Node disk usage
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

## Maintenance

### Check Monitoring Stack Health
```bash
kubectl get pods -n monitoring
kubectl top pods -n monitoring
```

### View Prometheus Targets
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open http://localhost:9090/targets
```

### Backup Grafana Dashboards
```bash
# Export dashboard JSON from Grafana UI
# Or backup the PVC
kubectl get pvc -n monitoring
```

### Update Stack
```bash
helm repo update
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f configs/monitoring-values.yaml
```

## Troubleshooting

### Prometheus Not Scraping Targets
1. Check ServiceMonitor/PodMonitor resources
2. Verify network policies allow scraping
3. Check Prometheus logs:
   ```bash
   kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
   ```

### Grafana Can't Query Prometheus
1. Verify data source config in Grafana
2. Default should be `http://kube-prometheus-stack-prometheus.monitoring.svc:9090`

### High Memory Usage
1. Reduce retention period in monitoring-values.yaml
2. Adjust scrape intervals
3. Increase resource limits

### External Targets Not Working
1. Verify firewall allows access from cluster to external IPs
2. Check node_exporter is running on target
3. Test with curl from a cluster pod:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://192.168.1.10:9100/metrics
   ```

## Integration with AWX

Create AWX job template to check monitoring health:

```yaml
---
- name: Check Monitoring Stack Health
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Get monitoring pods
      kubernetes.core.k8s_info:
        kind: Pod
        namespace: monitoring
      register: monitoring_pods
      
    - name: Display status
      debug:
        msg: "{{ item.metadata.name }}: {{ item.status.phase }}"
      loop: "{{ monitoring_pods.resources }}"
```

## Security Best Practices

1. **Change default passwords** immediately
2. **Enable authentication** on Prometheus/Alertmanager
3. **Use TLS** for external access (Ingress with cert-manager)
4. **Restrict network policies** for scraping
5. **Regular backups** of Grafana dashboards and Prometheus data
6. **Monitor the monitors** - set up external health checks

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
