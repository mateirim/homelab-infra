# Jenkins Pipelines

CI/CD pipeline examples and Groovy shared libraries.

## Structure

- **groovy/** — Jenkinsfiles (declarative and scripted pipelines)
- **pipelines/** — YAML pipeline configurations
- **vars/** — Shared pipeline libraries
- **k8s/** — Kubernetes RBAC for Jenkins agents
- **docs/** — Detailed guides

## Use

Add repo to Jenkins as a Pipeline library under `Manage Jenkins → Global Pipeline Libraries`.

Reference in your pipeline:
```groovy
@Library('jenkins-repo') _

pipeline {
  agent kubernetes
  stages {
    stage('Build') {
      steps {
        script {
          standardBuild()
        }
      }
    }
  }
}
```

## Examples

- **simple-build.jenkinsfile** — Basic build
- **docker-build.jenkinsfile** — Docker image build and push
- **multi-stage.jenkinsfile** — Parallel execution
- **k8s-container-deploy.yaml** — Kubernetes deployment

See docs/ for detailed usage.
