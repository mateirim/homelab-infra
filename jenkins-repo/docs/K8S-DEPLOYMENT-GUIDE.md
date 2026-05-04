# Kubernetes Container Deployment Pipelines

This directory contains Jenkins YAML pipelines for deploying and testing containers in Kubernetes.

## Available Pipelines

### 1. `k8s-container-deploy.yaml` - Full-Featured Deployment Pipeline

A comprehensive pipeline for deploying containers to Kubernetes with full configuration options.

#### Features
- ✅ Configurable container image, replicas, and ports
- ✅ Custom environment variables support
- ✅ Optional LoadBalancer service creation
- ✅ Deployment validation and health checks
- ✅ Detailed deployment summary
- ✅ Automatic namespace creation if needed

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CONTAINER_IMAGE` | `nginx:latest` | Container image to deploy |
| `DEPLOYMENT_NAME` | `test-deployment` | Name of the Kubernetes deployment |
| `REPLICAS` | `1` | Number of pod replicas |
| `CONTAINER_PORT` | `80` | Container port to expose |
| `NAMESPACE` | `default` | Kubernetes namespace |
| `ENV_VARS` | _(empty)_ | Environment variables (one per line, format: `KEY=VALUE`) |
| `CREATE_SERVICE` | `true` | Whether to create a LoadBalancer service |
| `SERVICE_PORT` | `80` | Service port (if CREATE_SERVICE is enabled) |

#### Example Usage

**Deploy NGINX with custom environment:**
```
CONTAINER_IMAGE: nginx:alpine
DEPLOYMENT_NAME: my-nginx
REPLICAS: 3
CONTAINER_PORT: 80
NAMESPACE: default
ENV_VARS:
  NGINX_HOST=REPLACE_WITH_YOUR_DOMAIN
  NGINX_PORT=80
CREATE_SERVICE: true
SERVICE_PORT: 80
```

**Deploy Redis:**
```
CONTAINER_IMAGE: redis:7-alpine
DEPLOYMENT_NAME: redis-cache
REPLICAS: 1
CONTAINER_PORT: 6379
ENV_VARS:
  REDIS_PASSWORD=mypassword
CREATE_SERVICE: true
SERVICE_PORT: 6379
```

**Deploy Custom Application:**
```
CONTAINER_IMAGE: myregistry.io/myapp:v1.2.3
DEPLOYMENT_NAME: myapp-prod
REPLICAS: 5
CONTAINER_PORT: 8080
ENV_VARS:
  DATABASE_URL=postgresql://db.REPLACE_WITH_YOUR_DOMAIN:5432/mydb
  API_KEY=secret123
  LOG_LEVEL=info
  ENVIRONMENT=production
CREATE_SERVICE: true
SERVICE_PORT: 8080
```

---

### 2. `k8s-quick-test.yaml` - Quick Test Pipeline

A simplified pipeline for rapid container testing with minimal configuration.

#### Features
- ✅ Fast deployment with sensible defaults
- ✅ Automatic service exposure
- ✅ Quick validation and logs
- ✅ Ideal for testing new images

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `IMAGE` | `nginx:latest` | Container image to test |
| `NAME` | `quick-test` | Deployment name |
| `PORT` | `80` | Container port |
| `ENV` | _(empty)_ | Environment variables (comma-separated: `KEY1=val1,KEY2=val2`) |

#### Example Usage

**Quick NGINX test:**
```
IMAGE: nginx:latest
NAME: nginx-test
PORT: 80
```

**Test with environment variables:**
```
IMAGE: postgres:15-alpine
NAME: postgres-test
PORT: 5432
ENV: POSTGRES_PASSWORD=testpass,POSTGRES_DB=testdb
```

**Test custom application:**
```
IMAGE: myapp:dev
NAME: myapp-test
PORT: 3000
ENV: NODE_ENV=development,DEBUG=true
```

---

## Prerequisites

### Required Jenkins Plugins
- Pipeline (Workflow Aggregator)
- Pipeline: YAML Plugin (`pipeline-as-yaml`)
- Kubernetes Plugin
- Credentials Plugin

### Kubernetes Configuration

1. **Kubeconfig Setup**: Ensure Jenkins has access to Kubernetes cluster
   - Default location: `/var/jenkins_home/.kube/config`
   - Or configure via environment variable: `KUBECONFIG`

2. **Permissions**: Jenkins service account needs permissions to:
   - Create/update deployments
   - Create/update services
   - Create namespaces
   - Get/describe pods and events

3. **Example RBAC Configuration**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-deployer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services", "pods", "namespaces", "events"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-deployer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-deployer
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: default
```

---

## Setting Up in Jenkins

### Method 1: Pipeline Job from SCM

1. Create a new **Pipeline** job in Jenkins
2. Under **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `<your-repo-url>`
   - Script Path: `pipelines/k8s-container-deploy.yaml` (or `k8s-quick-test.yaml`)
3. Save and build with parameters

### Method 2: Direct Pipeline Script

1. Create a new **Pipeline** job
2. Under **Pipeline** section:
   - Definition: **Pipeline script**
   - Copy the contents of the desired YAML file
3. Save and build with parameters

---

## Common Use Cases

### 1. Testing New Container Images
Use `k8s-quick-test.yaml` to quickly validate a new image:
```
IMAGE: myregistry.io/myapp:feature-branch
NAME: feature-test
PORT: 8080
```

### 2. Deploying Databases for Testing
```
CONTAINER_IMAGE: mysql:8
DEPLOYMENT_NAME: mysql-test
CONTAINER_PORT: 3306
ENV_VARS:
  MYSQL_ROOT_PASSWORD=rootpass
  MYSQL_DATABASE=testdb
  MYSQL_USER=testuser
  MYSQL_PASSWORD=testpass
```

### 3. Deploying Web Applications
```
CONTAINER_IMAGE: httpd:2.4-alpine
DEPLOYMENT_NAME: apache-web
REPLICAS: 3
CONTAINER_PORT: 80
CREATE_SERVICE: true
SERVICE_PORT: 80
```

### 4. Deploying Message Queues
```
CONTAINER_IMAGE: rabbitmq:3-management
DEPLOYMENT_NAME: rabbitmq
CONTAINER_PORT: 5672
ENV_VARS:
  RABBITMQ_DEFAULT_USER=admin
  RABBITMQ_DEFAULT_PASS=secret
CREATE_SERVICE: true
SERVICE_PORT: 5672
```

---

## Troubleshooting

### Deployment Fails to Start

Check pod status:
```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
```

### Service Not Accessible

Check service status:
```bash
kubectl get service -n default
kubectl describe service <service-name> -n default
```

### Image Pull Errors

Ensure:
- Image name is correct
- Registry is accessible from cluster
- Image pull secrets are configured if using private registry

### Permission Errors

Verify Jenkins service account has required RBAC permissions:
```bash
kubectl auth can-i create deployments --as=system:serviceaccount:default:jenkins
kubectl auth can-i create services --as=system:serviceaccount:default:jenkins
```

---

## Cleanup

To remove deployments created by these pipelines:

```bash
# Delete deployment
kubectl delete deployment <deployment-name> -n default

# Delete service
kubectl delete service <deployment-name>-service -n default
# or for quick-test pipeline:
kubectl delete service <deployment-name> -n default
```

Or delete everything with a specific label:
```bash
kubectl delete all -l managed-by=jenkins -n default
```

---

## Advanced Configuration

### Using Private Container Registries

1. Create a Docker registry secret:
```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>
```

2. Modify the deployment manifest in the pipeline to include:
```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
```

### Custom Resource Limits

Modify the deployment manifest to add resource limits:
```yaml
containers:
- name: ${params.DEPLOYMENT_NAME}
  resources:
    limits:
      cpu: "1"
      memory: "512Mi"
    requests:
      cpu: "100m"
      memory: "128Mi"
```

### Health Checks

Add liveness and readiness probes:
```yaml
containers:
- name: ${params.DEPLOYMENT_NAME}
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5
```

---

## Related Documentation

- [YAML Pipeline Guide](../docs/YAML-PIPELINE-GUIDE.md)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
