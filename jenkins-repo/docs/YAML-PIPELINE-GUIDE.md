# YAML Pipeline Guide for Jenkins

## Important Note About YAML Pipelines

⚠️ **Jenkins does not natively support YAML pipelines**. You need to use a plugin to enable YAML syntax.

## Plugin Options

### Option 1: pipeline-as-yaml Plugin (Recommended for this repo)

The `pipeline-as-yaml` plugin allows you to write Jenkins pipelines in YAML format that gets converted to Jenkinsfile syntax.

**Installation:**
```
Jenkins → Manage Jenkins → Manage Plugins → Available → Search "pipeline-as-yaml" → Install
```

**Plugin Repository:** https://github.com/jenkinsci/pipeline-as-yaml-plugin

### Option 2: Use Native Jenkinsfile (Recommended Generally)

For production use, **Jenkinsfile (Groovy)** is the recommended approach because:
- ✅ Native Jenkins support
- ✅ More features and flexibility
- ✅ Better documentation and community support
- ✅ No plugin dependency
- ✅ More mature and stable

### Option 3: Use Other CI/CD Tools

If you prefer YAML pipelines, consider these alternatives:
- **GitLab CI** - Native YAML support (`.gitlab-ci.yml`)
- **GitHub Actions** - Native YAML support (`.github/workflows/`)
- **Tekton** - Kubernetes-native, YAML-based
- **Azure Pipelines** - Native YAML support (`azure-pipelines.yml`)

## YAML Pipeline Syntax (pipeline-as-yaml)

### Basic Structure

```yaml
pipeline:
  agent:
    any: {}
  
  stages:
    - stage:
        name: "Stage Name"
        steps:
          - echo:
              message: "Hello World"
          - sh:
              script: "echo 'Shell command'"
```

### Complete Example

```yaml
pipeline:
  agent:
    any: {}
  
  environment:
    MY_VAR: "value"
  
  parameters:
    - string:
        name: "PARAM_NAME"
        defaultValue: "default"
        description: "Description"
  
  stages:
    - stage:
        name: "Build"
        steps:
          - echo:
              message: "Building..."
          - sh:
              script: |
                echo "Multi-line"
                echo "shell script"
  
  post:
    success:
      - echo:
          message: "Success!"
```

### Common Step Types

#### Echo
```yaml
- echo:
    message: "Your message here"
```

#### Shell Script
```yaml
- sh:
    script: "echo 'Single line'"

# Or multi-line:
- sh:
    script: |
      echo "Line 1"
      echo "Line 2"
```

#### Checkout SCM
```yaml
- checkout:
    scm: {}
```

#### Archive Artifacts
```yaml
- archiveArtifacts:
    artifacts: "*.jar"
    fingerprint: true
```

#### Clean Workspace
```yaml
- cleanWs: {}
```

### Parallel Stages

```yaml
- stage:
    name: "Tests"
    parallel:
      - stage:
          name: "Unit Tests"
          steps:
            - sh:
                script: "run-unit-tests"
      
      - stage:
          name: "Integration Tests"
          steps:
            - sh:
                script: "run-integration-tests"
```

### Conditional Stages (When)

```yaml
- stage:
    name: "Deploy"
    when:
      expression: "params.DEPLOY == true"
    steps:
      - echo:
          message: "Deploying..."
```

### Post Actions

```yaml
post:
  always:
    - echo:
        message: "Always runs"
  
  success:
    - echo:
        message: "Only on success"
  
  failure:
    - echo:
        message: "Only on failure"
  
  unstable:
    - echo:
        message: "Only when unstable"
```

## Converting Jenkinsfile to YAML

### Jenkinsfile (Groovy)
```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                sh 'make build'
            }
        }
    }
}
```

### YAML Equivalent
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
          - sh:
              script: "make build"
```

## Setting Up a YAML Pipeline in Jenkins

### Method 1: Using Pipeline-as-YAML Plugin

1. **Install the plugin**:
   - Go to `Manage Jenkins` → `Manage Plugins`
   - Search for "pipeline-as-yaml"
   - Install and restart Jenkins

2. **Create a new Pipeline job**:
   - Click `New Item`
   - Enter name and select `Pipeline`
   - Click `OK`

3. **Configure the pipeline**:
   - Under `Pipeline` section
   - Select `Pipeline script from SCM` or `Pipeline script`
   - If using SCM, point to your YAML file
   - If using script, paste your YAML content

4. **Run the pipeline**

### Method 2: Convert to Jenkinsfile (Recommended)

Use the provided Jenkinsfile examples instead:
- `simple-build.jenkinsfile`
- `go-executable.jenkinsfile`
- `ssh-deployment.jenkinsfile`
- `gitops-pipeline.jenkinsfile`

These are production-ready and don't require additional plugins!

## Troubleshooting

### "PipelineModel is not present"

This error means the YAML format is incorrect or the plugin isn't installed properly.

**Solutions:**
1. Verify the plugin is installed: `Manage Jenkins` → `Manage Plugins` → `Installed`
2. Check YAML syntax using a validator
3. Ensure you're using the correct YAML structure
4. **Recommended**: Use native Jenkinsfile instead!

### "YAML parsing error"

- Check YAML indentation (use spaces, not tabs)
- Validate YAML syntax: https://www.yamllint.com/
- Ensure all required fields are present

### Plugin not working

If the `pipeline-as-yaml` plugin has issues:

**Alternative**: Convert your YAML to a Jenkinsfile:

```bash
# Use the provided Jenkinsfile examples
cp simple-build.jenkinsfile Jenkinsfile
```

## Recommendations

### ✅ For Production Use:
1. **Use Jenkinsfile (Groovy)** - Most stable and feature-rich
2. See the examples in this repo:
   - `simple-build.jenkinsfile`
   - `go-executable.jenkinsfile`
   - `ssh-deployment.jenkinsfile`
   - `gitops-pipeline.jenkinsfile`

### ⚠️ For Experimentation:
1. Use YAML pipelines with the plugin
2. Great for learning and testing

### 🔄 For New Projects:
Consider GitLab CI, GitHub Actions, or Tekton if YAML is a requirement

## Examples in This Repository

### Simple YAML Pipeline
**File**: `pipelines/simple-yaml-pipeline.yaml`

Basic example showing pipeline structure.

### Complex YAML Pipeline
**File**: `pipelines/yaml-pipeline.yaml`

Full-featured example with:
- Parameters
- Environment variables
- Parallel stages
- Conditional execution
- Post actions

### Equivalent Jenkinsfiles
Check the root directory for production-ready Jenkinsfile examples that don't require plugins:
- `simple-build.jenkinsfile`
- `multi-stage.jenkinsfile`
- `docker-build.jenkinsfile`
- `gitops-pipeline.jenkinsfile`

## Further Reading

- [Pipeline-as-YAML Plugin](https://github.com/jenkinsci/pipeline-as-yaml-plugin)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Declarative Pipeline](https://www.jenkins.io/doc/book/pipeline/syntax/#declarative-pipeline)
