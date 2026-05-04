# SSH Pipeline Examples

This directory contains SSH deployment pipeline examples in YAML format.

## Files

### 1. `ssh-simple.yaml` - Minimal SSH Example
**Use this for**: Learning SSH basics in YAML pipelines

**Features**:
- Build package
- SCP file to remote server
- Execute remote commands
- Verify deployment

**Script Path**: `pipelines/ssh-simple.yaml`

### 2. `ssh-deployment-yaml.yaml` - Full Featured SSH Deployment
**Use this for**: Production SSH deployments

**Features**:
- Pre-deployment connectivity check
- Automated backup before deployment
- Multiple deployment stages
- Post-deployment commands
- Health check verification
- Rollback support
- Parameterized (host, user, path, environment)

**Script Path**: `pipelines/ssh-deployment-yaml.yaml`

## Prerequisites

### 1. SSH Credentials in Jenkins
You need to create SSH credentials in Jenkins:

```
Jenkins → Manage Jenkins → Credentials → System → Global credentials
→ Add Credentials
  - Kind: SSH Username with private key
  - ID: ssh-deploy-key
  - Username: deploy
  - Private Key: [paste your private key]
```

### 2. Jenkins Plugins
- **SSH Agent Plugin**: Required for sshagent step
- **pipeline-as-yaml**: Required for YAML syntax

Install via:
```
Manage Jenkins → Manage Plugins → Available → Search "SSH Agent" → Install
```

### 3. Server Setup
On your remote server:

```bash
# Create deploy user
sudo useradd -m -s /bin/bash deploy

# Add your Jenkins public key to authorized_keys
sudo mkdir -p /home/deploy/.ssh
sudo vim /home/deploy/.ssh/authorized_keys
# Paste Jenkins public key

# Set permissions
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh

# Create deployment directory
sudo mkdir -p /opt/app
sudo chown deploy:deploy /opt/app
```

## Usage

### Quick Start (Simple)

1. **Create Jenkins Pipeline Job**
2. **Configure**:
   - Pipeline Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: https://github.com/yourusername/jenkins-repo.git
   - Script Path: `pipelines/ssh-simple.yaml`
3. **Add Parameter** (or use default):
   - SERVER: your-server.com
4. **Build**

### Full Deployment

1. **Create Pipeline Job**
2. **Script Path**: `pipelines/ssh-deployment-yaml.yaml`
3. **Set Parameters**:
   - REMOTE_HOST: production-server.example.com
   - REMOTE_USER: deploy
   - DEPLOY_PATH: /opt/myapp
   - ENVIRONMENT: production
4. **Build**

## SSH Agent Syntax in YAML

The `sshagent` step uses a special code block syntax:

```yaml
- sshagent:
    credentials: ['credential-id']
    script: |
      ssh user@host "command"
      scp file user@host:/path/
```

## Common SSH Commands

### Copy Files
```yaml
- sshagent:
    credentials: ['ssh-deploy-key']
    script: |
      scp -o StrictHostKeyChecking=no file.tar.gz user@host:/path/
```

### Execute Remote Command
```yaml
- sshagent:
    credentials: ['ssh-deploy-key']
    script: |
      ssh -o StrictHostKeyChecking=no user@host "command"
```

### Multi-line Remote Script
```yaml
- sshagent:
    credentials: ['ssh-deploy-key']
    script: |
      ssh -o StrictHostKeyChecking=no user@host "\
        cd /app && \
        ./script.sh && \
        echo 'Done'"
```

## Examples

### Deploy with Restart Service
```yaml
- stage: "Deploy and Restart"
  steps:
    - sshagent:
        credentials: ['ssh-deploy-key']
        script: |
          scp app.jar deploy@server:/opt/app/
          ssh deploy@server "sudo systemctl restart myapp"
```

### Backup and Deploy
```yaml
- stage: "Backup and Deploy"
  steps:
    - sshagent:
        credentials: ['ssh-deploy-key']
        script: |
          # Backup
          ssh deploy@server "cp -r /opt/app /opt/app.backup"
          
          # Deploy
          scp -r dist/* deploy@server:/opt/app/
          
          # Verify
          ssh deploy@server "ls -la /opt/app"
```

### Run Database Migration
```yaml
- stage: "Database Migration"
  steps:
    - sshagent:
        credentials: ['ssh-deploy-key']
        script: |
          ssh deploy@server "\
            cd /opt/app && \
            ./migrate.sh && \
            echo 'Migration complete'"
```

## Troubleshooting

### Issue: "Permission denied (publickey)"
**Solution**: Check SSH key is added to Jenkins credentials and authorized_keys on server

### Issue: "Host key verification failed"
**Solution**: Use `-o StrictHostKeyChecking=no` (shown in examples)

### Issue: "sshagent: command not found"
**Solution**: Install "SSH Agent Plugin" in Jenkins

### Issue: "YAML parsing errors"
**Solution**: Ensure using correct syntax with `script: |` for multi-line

## Related Examples

For Jenkinsfile (Groovy) SSH examples, see:
- `ssh-deployment.jenkinsfile` - Full featured Groovy version
- More robust and recommended for production

## Security Best Practices

1. **Use SSH Keys** (not passwords)
2. **Limit SSH User Permissions** (create dedicated deploy user)
3. **Use Jump Host** for production (don't expose servers directly)
4. **Rotate Keys Regularly**
5. **Use Different Keys per Environment**
6. **Enable SSH Logging** on remote servers

## Next Steps

After mastering SSH pipelines:
- Try the GitOps pipeline: `gitops-pipeline.jenkinsfile`
- Explore Kubernetes deployments
- Learn ArgoCD integration
