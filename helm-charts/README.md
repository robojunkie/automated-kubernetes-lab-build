# Helm Charts

This directory contains custom Helm charts for deploying applications to your Kubernetes cluster.

## Available Charts

### WordPress
Full WordPress installation with MySQL database.

**Features:**
- Latest WordPress version
- MySQL 8.0 database
- Persistent storage for both WordPress and MySQL
- Configurable resource limits
- LoadBalancer or NodePort service options

**Deploy:**
```bash
bash scripts/deploy-wordpress.sh
```

**Customize values:**
Edit `helm-charts/wordpress/values.yaml` to change:
- Service type (LoadBalancer/NodePort)
- Storage sizes
- Resource limits
- MySQL credentials
- WordPress image version

**Manual deployment:**
```bash
helm install wordpress helm-charts/wordpress -n wordpress --create-namespace
```

**Uninstall:**
```bash
helm uninstall wordpress -n wordpress
```

## Creating New Charts

To add more applications:

1. Create chart directory:
   ```bash
   mkdir -p helm-charts/myapp/templates
   ```

2. Create Chart.yaml:
   ```yaml
   apiVersion: v2
   name: myapp
   version: 1.0.0
   appVersion: "latest"
   ```

3. Create values.yaml with configuration

4. Create templates in `templates/` directory

5. Create deployment script in `scripts/deploy-myapp.sh`

## Chart Structure

```
helm-charts/
├── wordpress/
│   ├── Chart.yaml          # Chart metadata
│   ├── values.yaml         # Default configuration
│   └── templates/          # Kubernetes manifests
│       ├── namespace.yaml
│       ├── pvcs.yaml
│       ├── mysql-secret.yaml
│       ├── mysql-deployment.yaml
│       └── wordpress-deployment.yaml
```

## Tips

- Test charts locally before committing
- Use `helm lint` to validate charts
- Document all values in values.yaml with comments
- Version your charts properly
- Include README in each chart directory
