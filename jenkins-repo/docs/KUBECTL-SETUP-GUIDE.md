# Kubernetes Pipeline kubectl Setup Guide

## The Problem

The Kubernetes deployment pipelines require `kubectl` to be available in the Jenkins agent. By default, most Jenkins agents don't have `kubectl` pre-installed.

## Solutions

You have **three options** to solve this:

---

### Option 1: Use Kubernetes Pod Agent with kubectl (Recommended) ⭐

**Best for:** Jenkins running in Kubernetes

The pipeline dynamically creates a Kubernetes pod with `kubectl` pre-installed.

**Pipelines using this approach:**
- `k8s-quick-test.yaml`
- `k8s-container-deploy.yaml` (coming soon)
- `k8s-preset-deploy.yaml` (coming soon)

**Agent configuration:**
```yaml
agent:
  kubernetes:
    yaml: |
      apiVersion: v1
      kind: Pod
      spec:
        containers:
        - name: kubectl
          image: alpine/k8s:1.28.3
          command:
          - sleep
          args:
          - "99999"
          workingDir: /home/jenkins/agent
```

**Pros:**
- ✅ Clean and isolated
- ✅ No installation needed
- ✅ Always uses latest kubectl
- ✅ Works out of the box in Kubernetes

**Cons:**
- ❌ Only works if Jenkins is running in Kubernetes
- ❌ Requires Kubernetes plugin

---

### Option 2: Dynamic kubectl Installation

**Best for:** Any Jenkins agent (VM, Docker, etc.)

The pipeline automatically downloads and installs `kubectl` if it's not available.

**Pipelines using this approach:**
- `k8s-quick-test-any-agent.yaml`

**How it works:**
```groovy
// Check if kubectl exists
if (sh(script: 'which kubectl', returnStatus: true) != 0) {
  // Download and install kubectl
  sh '''
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/ || mv kubectl ${WORKSPACE}/kubectl
  '''
}
```

**Pros:**
- ✅ Works with any agent type
- ✅ No manual setup required
- ✅ Automatically handles missing kubectl

**Cons:**
- ❌ Downloads kubectl on every run (slower)
- ❌ May require sudo permissions
- ❌ Network dependency

---

### Option 3: Pre-install kubectl in Agent Image

**Best for:** Production environments with custom agent images

Modify your Jenkins agent Docker image to include `kubectl`.

**Example Dockerfile:**
```dockerfile
FROM jenkins/inbound-agent:latest

USER root

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \\
    chmod +x kubectl && \\
    mv kubectl /usr/local/bin/

# Install other tools you need
RUN apt-get update && apt-get install -y \\
    git \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

USER jenkins
```

**Build and push:**
```bash
docker build -t your-registry/jenkins-kubectl-agent:latest .
docker push your-registry/jenkins-kubectl-agent:latest
```

**Update Jenkins agent configuration** to use your custom image.

**Pros:**
- ✅ Fastest execution (no download/install)
- ✅ Consistent environment
- ✅ Can include other tools
- ✅ Best for production

**Cons:**
- ❌ Requires maintaining custom image
- ❌ Need to rebuild for kubectl updates
- ❌ More setup work initially

---

## Recommended Approach by Environment

| Environment | Recommended Option | Pipeline to Use |
|-------------|-------------------|-----------------|
| **Jenkins in Kubernetes** | Option 1: Kubernetes Pod Agent | `k8s-quick-test.yaml` |
| **Jenkins on VM/Docker** | Option 2: Dynamic Installation | `k8s-quick-test-any-agent.yaml` |
| **Production** | Option 3: Custom Agent Image | Any pipeline with `agent: any:` |

---

## Kubeconfig Setup

Regardless of which option you choose, Jenkins needs access to your Kubernetes cluster via kubeconfig.

### Method 1: Service Account (Recommended for Jenkins in K8s)

If Jenkins is running in Kubernetes, it can use the pod's service account:

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

### Method 2: Kubeconfig File

For Jenkins running outside Kubernetes:

1. **Create kubeconfig secret in Jenkins:**
   - Go to Jenkins → Manage Jenkins → Credentials
   - Add → Secret file
   - Upload your kubeconfig file
   - ID: `kubeconfig`

2. **Use in pipeline:**
   ```groovy
   withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
     sh 'kubectl get nodes'
   }
   ```

### Method 3: Environment Variable

Set `KUBECONFIG` environment variable in Jenkins configuration:

```yaml
environment:
  - "KUBECONFIG = '/var/jenkins_home/.kube/config'"
```

---

## Testing Your Setup

### Test 1: Check kubectl availability

Run this in Jenkins Script Console or pipeline:

```groovy
sh 'kubectl version --client'
```

### Test 2: Check cluster connectivity

```groovy
sh 'kubectl cluster-info'
sh 'kubectl get nodes'
```

### Test 3: Check permissions

```groovy
sh 'kubectl auth can-i create deployments'
sh 'kubectl auth can-i create services'
```

---

## Troubleshooting

### Error: `kubectl: not found`

**Solution:** Use Option 1 (Kubernetes pod agent) or Option 2 (dynamic installation)

### Error: `The connection to the server localhost:8080 was refused`

**Cause:** kubectl can't find kubeconfig

**Solutions:**
1. Set `KUBECONFIG` environment variable
2. Mount kubeconfig file to `/root/.kube/config`
3. Use service account (if in Kubernetes)

### Error: `User "system:serviceaccount:default:default" cannot create deployments`

**Cause:** Insufficient RBAC permissions

**Solution:** Apply the RBAC configuration from Method 1 above

### Error: `error: You must be logged in to the server (Unauthorized)`

**Cause:** Invalid or expired credentials

**Solutions:**
1. Update kubeconfig with fresh credentials
2. Regenerate service account token
3. Check certificate expiration

---

## Quick Start

**For Jenkins in Kubernetes:**
```bash
# Use the kubectl pod agent version
git clone https://github.com/YOUR_GITHUB_USERNAME/jenkins-repo
# Create Jenkins pipeline pointing to: pipelines/k8s-quick-test.yaml
```

**For Jenkins on VM/Docker:**
```bash
# Use the any-agent version
git clone https://github.com/YOUR_GITHUB_USERNAME/jenkins-repo
# Create Jenkins pipeline pointing to: pipelines/k8s-quick-test-any-agent.yaml
```

**Test it:**
- IMAGE: `nginx:latest`
- NAME: `test-nginx`
- PORT: `80`
- ENV: _(leave empty)_

---

## Additional Resources

- [kubectl Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
