# Jenkins RBAC Configuration Guide

## The Problem

Jenkins pipelines running in Kubernetes need permissions to deploy containers and manage resources. By default, the service account doesn't have these permissions, resulting in errors like:

```
deployments.apps "quick-test" is forbidden: User "system:serviceaccount:jenkins:default" 
cannot get resource "deployments" in API group "apps" in the namespace "jenkins"
```

## Solutions

You have **two options** depending on your security requirements:

---

## Option 1: Cluster-Wide Permissions (Recommended for Testing)

**File:** `k8s/jenkins-rbac.yaml`

Grants Jenkins permissions across **all namespaces** in the cluster.

### Apply the Configuration

```bash
kubectl apply -f k8s/jenkins-rbac.yaml
```

### What It Does

- ✅ Creates a `ClusterRole` named `jenkins-deployer` with permissions for:
  - Deployments (create, update, delete, get, list)
  - Services (create, update, delete, get, list)
  - Pods (get, list, view logs)
  - Events (for debugging)
  - Namespaces (check/create)

- ✅ Creates a `ClusterRoleBinding` that grants these permissions to:
  - Service Account: `default`
  - Namespace: `jenkins`

### Use This If:
- You want Jenkins to deploy to **multiple namespaces**
- You're in a development/testing environment
- You trust Jenkins to manage cluster resources

---

## Option 2: Namespace-Only Permissions (Recommended for Production)

**File:** `k8s/jenkins-rbac-namespace-only.yaml`

Grants Jenkins permissions **only within the jenkins namespace**.

### Apply the Configuration

```bash
kubectl apply -f k8s/jenkins-rbac-namespace-only.yaml
```

### What It Does

- ✅ Creates a `Role` (not ClusterRole) named `jenkins-deployer` with permissions for:
  - Deployments (create, update, delete, get, list)
  - Services (create, update, delete, get, list)
  - Pods (get, list, view logs)
  - Events (for debugging)

- ✅ Creates a `RoleBinding` (not ClusterRoleBinding) that grants these permissions to:
  - Service Account: `default`
  - Namespace: `jenkins`
  - **Scope:** jenkins namespace only

### Use This If:
- You want to follow the **principle of least privilege**
- You're in a production environment
- Jenkins should only deploy to the `jenkins` namespace

---

## Quick Start

### For Testing/Development (Cluster-Wide):

```bash
# Apply cluster-wide permissions
kubectl apply -f k8s/jenkins-rbac.yaml

# Verify the ClusterRole was created
kubectl get clusterrole jenkins-deployer

# Verify the ClusterRoleBinding was created
kubectl get clusterrolebinding jenkins-deployer-binding

# Test permissions
kubectl auth can-i create deployments --as=system:serviceaccount:jenkins:default -n jenkins
# Should return: yes
```

### For Production (Namespace-Only):

```bash
# Apply namespace-scoped permissions
kubectl apply -f k8s/jenkins-rbac-namespace-only.yaml

# Verify the Role was created
kubectl get role jenkins-deployer -n jenkins

# Verify the RoleBinding was created
kubectl get rolebinding jenkins-deployer-binding -n jenkins

# Test permissions
kubectl auth can-i create deployments --as=system:serviceaccount:jenkins:default -n jenkins
# Should return: yes

# Verify it DOESN'T work in other namespaces
kubectl auth can-i create deployments --as=system:serviceaccount:jenkins:default -n default
# Should return: no
```

---

## Verifying Permissions

After applying either configuration, verify the permissions:

```bash
# Check if Jenkins can create deployments
kubectl auth can-i create deployments \
  --as=system:serviceaccount:jenkins:default \
  -n jenkins

# Check if Jenkins can create services
kubectl auth can-i create services \
  --as=system:serviceaccount:jenkins:default \
  -n jenkins

# Check if Jenkins can view pods
kubectl auth can-i get pods \
  --as=system:serviceaccount:jenkins:default \
  -n jenkins

# Check if Jenkins can view logs
kubectl auth can-i get pods/log \
  --as=system:serviceaccount:jenkins:default \
  -n jenkins
```

All commands should return `yes`.

---

## Troubleshooting

### Error: "cannot get resource 'deployments'"

**Cause:** RBAC not applied or service account mismatch

**Solution:**
1. Apply the RBAC configuration: `kubectl apply -f k8s/jenkins-rbac.yaml`
2. Verify the service account name matches (should be `default` in `jenkins` namespace)
3. Wait a few seconds for permissions to propagate

### Error: "cannot create resource 'deployments' in namespace 'default'"

**Cause:** Using namespace-only RBAC but trying to deploy to a different namespace

**Solution:**
- Either use cluster-wide RBAC (`jenkins-rbac.yaml`)
- Or update your pipeline to only deploy to the `jenkins` namespace

### Permissions Not Working After Applying

**Solution:**
```bash
# Delete and recreate the pod to pick up new permissions
kubectl delete pod -n jenkins -l jenkins/label-digest

# Or restart Jenkins
kubectl rollout restart deployment jenkins -n jenkins
```

---

## Security Best Practices

### For Production Environments:

1. **Use namespace-scoped permissions** (`jenkins-rbac-namespace-only.yaml`)
2. **Create a dedicated service account** instead of using `default`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-deployer
  namespace: jenkins
---
# Update RoleBinding to use jenkins-deployer instead of default
subjects:
- kind: ServiceAccount
  name: jenkins-deployer
  namespace: jenkins
```

3. **Update Jenkins pod to use the service account:**

```yaml
# In your Jenkins Helm values or pod spec
serviceAccountName: jenkins-deployer
```

4. **Limit permissions** to only what's needed:
   - Remove `delete` verbs if Jenkins shouldn't delete resources
   - Remove `update` verbs if Jenkins should only create new resources
   - Remove namespace permissions if not needed

### For Development/Testing:

- Cluster-wide permissions are fine for convenience
- Still consider using a dedicated service account for clarity

---

## Removing Permissions

If you need to remove the permissions:

### Cluster-Wide:
```bash
kubectl delete clusterrolebinding jenkins-deployer-binding
kubectl delete clusterrole jenkins-deployer
```

### Namespace-Only:
```bash
kubectl delete rolebinding jenkins-deployer-binding -n jenkins
kubectl delete role jenkins-deployer -n jenkins
```

---

## Next Steps

After applying the RBAC configuration:

1. ✅ Apply the appropriate RBAC file
2. ✅ Verify permissions with `kubectl auth can-i`
3. ✅ Run your Jenkins pipeline again
4. ✅ The pipeline should now successfully deploy containers!

---

## Additional Resources

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [kubectl auth can-i](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access)
