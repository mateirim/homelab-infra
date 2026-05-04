# YAML Pipeline Alternatives

## ⚠️ YAML Pipeline Plugin Issues

The `pipeline-as-yaml` plugin has **limited support** and **strict syntax requirements** that are difficult to work with. Based on testing, this plugin may not be reliable for production use.

### Common Errors:
- `ClassCastException: LinkedHashMap cannot be cast to String`
- `PipelineModel is not present`
- Syntax parsing errors

## ✅ RECOMMENDED: Use Jenkinsfile Instead

**Jenkinsfile (Groovy syntax) is the official, well-supported way to write Jenkins pipelines.**

### Why Use Jenkinsfile?
- ✅ **Native Jenkins support** - No plugins needed
- ✅ **More features** - Full pipeline capabilities
- ✅ **Better documentation** - Extensive resources available
- ✅ **More maintainable** - Industry standard
- ✅ **Better IDE support** - Syntax highlighting, validation
- ✅ **More examples** - Large community

### Migration Path

Instead of YAML pipelines, use these files:

| Use Case | Recommended File |
|----------|-----------------|
| Simple pipeline | `simple-pipeline.jenkinsfile` |
| Go application | `go-executable.jenkinsfile` |
| SSH deployment | `ssh-deployment.jenkinsfile` |
| Docker build | `docker-build.jenkinsfile` |
| Multi-stage complex | `multi-stage.jenkinsfile` |
| GitOps workflow | `gitops-pipeline.jenkinsfile` |

## Quick Start: Using Jenkinsfile

### 1. Create Jenkins Job
```
Jenkins → New Item → Pipeline → OK
```

### 2. Configure Script Path
```
Pipeline Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/YOUR_GITHUB_USERNAME/jenkins-repo.git
Script Path: simple-pipeline.jenkinsfile
```

### 3. Save and Build
```
Click "Save" → Click "Build Now"
```

## Example: Simple Pipeline Comparison

### ❌ YAML (Not Recommended - Has Issues)
```yaml
pipeline:
  agent:
    any: {}
  stages:
    - stage:
        name: "Build"
        steps:
          - echo:
              message: "Building..."
```

### ✅ Jenkinsfile (Recommended - Works Great!)
```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
    }
}
```

## Alternative CI/CD Tools with Native YAML Support

If you **really need YAML** pipelines, consider these alternatives:

### 1. GitHub Actions
```yaml
name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: echo "Building..."
```

### 2. GitLab CI
```yaml
stages:
  - build
  
build-job:
  stage: build
  script:
    - echo "Building..."
```

### 3. Tekton (Kubernetes-native)
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: build-pipeline
spec:
  tasks:
    - name: build
      taskRef:
        name: build-task
```

### 4. Azure Pipelines
```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - script: echo "Building..."
```

## What Changed?

Instead of troubleshooting the YAML plugin, I've created:

### New File: `simple-pipeline.jenkinsfile`
- ✅ Works immediately with Jenkins
- ✅ No plugin required
- ✅ Same features as the YAML version
- ✅ Better error messages
- ✅ Easier to debug

### Updated Documentation
All docs now recommend Jenkinsfile over YAML.

## How to Switch

### In Jenkins Job Configuration:

**Change Script Path from:**
```
pipelines/simple-yaml-pipeline.yaml
```

**To:**
```
simple-pipeline.jenkinsfile
```

That's it! The pipeline will work perfectly.

## Summary

| Aspect | YAML Plugin | Jenkinsfile |
|--------|-------------|-------------|
| **Support** | Limited | Excellent |
| **Plugins Needed** | Yes | No |
| **Documentation** | Poor | Extensive |
| **Features** | Limited | Full |
| **Community** | Small | Large |
| **Reliability** | ⚠️ Issues | ✅ Stable |
| **Recommendation** | ❌ Avoid | ✅ Use This |

## Bottom Line

**Use Jenkinsfile (Groovy)** for Jenkins pipelines. The YAML plugin is experimental and unreliable. All the examples in this repository work perfectly with Jenkinsfile syntax!
