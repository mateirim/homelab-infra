# Quick Reference: Kubernetes Deployment Pipelines

## Pipeline Selection Guide

Choose the right pipeline for your use case:

| Pipeline | Use Case | Complexity | Best For |
|----------|----------|------------|----------|
| **k8s-quick-test.yaml** | Quick container testing | ⭐ Simple | Testing new images quickly |
| **k8s-preset-deploy.yaml** | Common services | ⭐⭐ Easy | Deploying standard services (nginx, redis, etc.) |
| **k8s-container-deploy.yaml** | Full configuration | ⭐⭐⭐ Advanced | Production deployments with custom settings |

---

## Quick Start Examples

### 1. Test a New Container Image (k8s-quick-test.yaml)

**Fastest way to test any container:**

```
IMAGE: myapp:latest
NAME: myapp-test
PORT: 8080
ENV: DEBUG=true,LOG_LEVEL=info
```

**Time to deploy:** ~30 seconds

---

### 2. Deploy Common Services (k8s-preset-deploy.yaml)

**NGINX Web Server:**
```
PRESET: nginx
DEPLOYMENT_NAME: (leave empty for auto)
NAMESPACE: default
```

**Redis Cache:**
```
PRESET: redis
EXTRA_ENV: 
  REDIS_PASSWORD=mysecretpass
```

**PostgreSQL Database:**
```
PRESET: postgres
EXTRA_ENV:
  POSTGRES_PASSWORD=mypassword
  POSTGRES_DB=myapp
```

**MySQL Database:**
```
PRESET: mysql
EXTRA_ENV:
  MYSQL_ROOT_PASSWORD=rootpass
  MYSQL_DATABASE=myapp
```

**MongoDB:**
```
PRESET: mongodb
EXTRA_ENV:
  MONGO_INITDB_ROOT_USERNAME=admin
  MONGO_INITDB_ROOT_PASSWORD=secret
```

**RabbitMQ:**
```
PRESET: rabbitmq
EXTRA_ENV:
  RABBITMQ_DEFAULT_USER=admin
  RABBITMQ_DEFAULT_PASS=secret
```

**Custom Container:**
```
PRESET: custom
CUSTOM_IMAGE: myregistry.io/myapp:v1.0
CUSTOM_PORT: 3000
EXTRA_ENV:
  NODE_ENV=production
  API_KEY=xyz123
```

---

### 3. Advanced Deployment (k8s-container-deploy.yaml)

**Production Web Application:**
```
CONTAINER_IMAGE: myapp:v2.1.0
DEPLOYMENT_NAME: myapp-prod
REPLICAS: 5
CONTAINER_PORT: 8080
NAMESPACE: production
ENV_VARS:
  DATABASE_URL=postgresql://db.prod:5432/myapp
  REDIS_URL=redis://cache.prod:6379
  API_KEY=prod-key-123
  LOG_LEVEL=warn
  ENVIRONMENT=production
CREATE_SERVICE: true
SERVICE_PORT: 80
```

**Microservice with Multiple Replicas:**
```
CONTAINER_IMAGE: user-service:latest
DEPLOYMENT_NAME: user-service
REPLICAS: 3
CONTAINER_PORT: 9090
NAMESPACE: microservices
ENV_VARS:
  SERVICE_NAME=user-service
  GRPC_PORT=9090
  METRICS_PORT=9091
CREATE_SERVICE: true
SERVICE_PORT: 9090
```

---

## Common Workflows

### Testing a New Feature Branch

1. **Build your container:**
   ```bash
   docker build -t myapp:feature-xyz .
   docker push myregistry.io/myapp:feature-xyz
   ```

2. **Deploy with k8s-quick-test.yaml:**
   ```
   IMAGE: myregistry.io/myapp:feature-xyz
   NAME: feature-xyz-test
   PORT: 8080
   ENV: FEATURE_FLAG=xyz,DEBUG=true
   ```

3. **Test and verify:**
   ```bash
   kubectl get service feature-xyz-test -n default
   # Get the LoadBalancer IP and test
   ```

4. **Cleanup:**
   ```bash
   kubectl delete deployment,service feature-xyz-test -n default
   ```

---

### Setting Up a Development Database

1. **Use k8s-preset-deploy.yaml:**
   ```
   PRESET: postgres
   DEPLOYMENT_NAME: dev-db
   EXTRA_ENV:
     POSTGRES_PASSWORD=devpass
     POSTGRES_DB=myapp_dev
     POSTGRES_USER=developer
   ```

2. **Connect to it:**
   ```bash
   # Get service details
   kubectl get service dev-db-service -n default
   
   # Port forward for local access
   kubectl port-forward service/dev-db-service 5432:5432 -n default
   
   # Connect with psql
   psql -h localhost -U developer -d myapp_dev
   ```

---

### Deploying Multiple Environments

**Development:**
```
CONTAINER_IMAGE: myapp:dev
DEPLOYMENT_NAME: myapp-dev
NAMESPACE: development
REPLICAS: 1
ENV_VARS:
  ENVIRONMENT=development
  DEBUG=true
```

**Staging:**
```
CONTAINER_IMAGE: myapp:staging
DEPLOYMENT_NAME: myapp-staging
NAMESPACE: staging
REPLICAS: 2
ENV_VARS:
  ENVIRONMENT=staging
  DEBUG=false
```

**Production:**
```
CONTAINER_IMAGE: myapp:v1.0.0
DEPLOYMENT_NAME: myapp-prod
NAMESPACE: production
REPLICAS: 5
ENV_VARS:
  ENVIRONMENT=production
  DEBUG=false
  LOG_LEVEL=warn
```

---

## Useful kubectl Commands

### Viewing Deployments

```bash
# List all deployments
kubectl get deployments -n default

# Get deployment details
kubectl describe deployment <name> -n default

# View deployment YAML
kubectl get deployment <name> -n default -o yaml
```

### Viewing Pods

```bash
# List pods
kubectl get pods -n default

# Watch pods in real-time
kubectl get pods -n default -w

# Get pod logs
kubectl logs <pod-name> -n default

# Follow logs
kubectl logs -f <pod-name> -n default

# Get logs from all pods with a label
kubectl logs -l app=<deployment-name> -n default --tail=50
```

### Viewing Services

```bash
# List services
kubectl get services -n default

# Get service details
kubectl describe service <name> -n default

# Get LoadBalancer IP
kubectl get service <name> -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Debugging

```bash
# Execute command in pod
kubectl exec <pod-name> -n default -- <command>

# Get shell access
kubectl exec -it <pod-name> -n default -- sh

# Get events
kubectl get events -n default --sort-by='.lastTimestamp'

# Describe pod for troubleshooting
kubectl describe pod <pod-name> -n default
```

### Cleanup

```bash
# Delete specific deployment
kubectl delete deployment <name> -n default

# Delete specific service
kubectl delete service <name> -n default

# Delete both deployment and service
kubectl delete deployment,service <name> -n default

# Delete all resources with a label
kubectl delete all -l app=<name> -n default

# Delete all Jenkins-managed resources
kubectl delete all -l managed-by=jenkins -n default
```

---

## Troubleshooting Guide

### Pod is Pending

**Check:**
```bash
kubectl describe pod <pod-name> -n default
```

**Common causes:**
- Insufficient resources
- Image pull errors
- Node selector issues

### Pod is CrashLoopBackOff

**Check logs:**
```bash
kubectl logs <pod-name> -n default
kubectl logs <pod-name> -n default --previous
```

**Common causes:**
- Application errors
- Missing environment variables
- Port conflicts

### Image Pull Errors

**Check:**
```bash
kubectl describe pod <pod-name> -n default
```

**Solutions:**
- Verify image name and tag
- Check registry credentials
- Ensure image exists

### Service Not Accessible

**Check service:**
```bash
kubectl get service <name> -n default
kubectl describe service <name> -n default
```

**Verify:**
- Service selector matches pod labels
- Ports are correctly configured
- LoadBalancer is provisioned

---

## Environment Variables Format

### k8s-quick-test.yaml
Comma-separated:
```
KEY1=value1,KEY2=value2,KEY3=value3
```

### k8s-container-deploy.yaml & k8s-preset-deploy.yaml
One per line:
```
KEY1=value1
KEY2=value2
KEY3=value3
```

---

## Best Practices

1. **Use descriptive deployment names** - Makes it easier to identify resources
2. **Always specify namespace** - Avoid accidental deployments to wrong namespace
3. **Use version tags** - Avoid `:latest` in production
4. **Set resource limits** - Prevent resource exhaustion
5. **Use health checks** - Ensure reliable deployments
6. **Clean up test deployments** - Don't leave orphaned resources
7. **Use labels** - Makes filtering and cleanup easier
8. **Monitor logs** - Check logs after deployment
9. **Test in dev first** - Always test in development before production
10. **Document environment variables** - Keep track of required configuration

---

## Getting Help

- **Full Documentation:** [K8S-DEPLOYMENT-GUIDE.md](K8S-DEPLOYMENT-GUIDE.md)
- **YAML Pipeline Guide:** [../docs/YAML-PIPELINE-GUIDE.md](../docs/YAML-PIPELINE-GUIDE.md)
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
