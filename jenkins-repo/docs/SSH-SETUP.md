# SSH Pipeline Setup for Username/Password Authentication

## Quick Setup for YOUR_NODE.homelab.local

This pipeline uses **username/password** authentication instead of SSH keys.

### 1. Create Jenkins Credentials

1. Go to **Jenkins** → **Manage Jenkins** → **Credentials**
2. Click on **(global)** domain
3. Click **Add Credentials**
4. Fill in:
   - **Kind**: Username with password
   - **Scope**: Global
   - **Username**: `homelab`
   - **Password**: `homelab`
   - **ID**: `deploy-ssh-creds`
   - **Description**: SSH credentials for YOUR_NODE.homelab.local
5. Click **Create**

### 2. Install sshpass on Jenkins Agent

The pipeline uses `sshpass` for password-based SSH. Install it on your Jenkins agent:

#### On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y sshpass
```

#### On RHEL/CentOS/Fedora:
```bash
sudo yum install -y sshpass
```

#### On macOS:
```bash
brew install hudochenkov/sshpass/sshpass
```

### 3. Configure Jenkins Pipeline Job

1. **Create New Item** → **Pipeline**
2. **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/YOUR_GITHUB_USERNAME/jenkins-repo.git`
   - **Script Path**: `pipelines/ssh-simple.yaml`
3. **Save**

### 4. Run the Pipeline

1. Click **Build with Parameters** (or **Build Now**)
2. Parameters:
   - **SERVER**: `YOUR_NODE.homelab.local` (default)
   - **REMOTE_USER**: `homelab` (default)
3. Click **Build**

## What the Pipeline Does

1. **Build Package**: Creates a tar.gz with sample files
2. **SSH Deploy**: Uses sshpass to copy files to `/tmp/` on remote server
3. **Verify**: Checks the deployed files on the remote server

## Alternative: Using Expect (if sshpass unavailable)

If `sshpass` is not available, you can use `expect`:

```yaml
- stage: "SSH Deploy with Expect"
  steps:
    - withCredentials:
        bindings:
          - usernamePassword:
              credentialsId: 'deploy-ssh-creds'
              usernameVariable: 'SSH_USER'
              passwordVariable: 'SSH_PASS'
        script: |
          expect << EOF
          spawn scp -o StrictHostKeyChecking=no deploy.tar.gz ${SSH_USER}@${SERVER}:/tmp/
          expect "password:"
          send "${SSH_PASS}\r"
          expect eof
          EOF
```

## Security Considerations

⚠️ **Important Security Notes**:

1. **Password in Credentials**: The password is stored in Jenkins credentials (encrypted)
2. **Better Alternative**: Use SSH keys instead of passwords for better security
3. **Network Security**: Ensure Jenkins-to-server connection is over secure network
4. **Least Privilege**: Use a dedicated deploy user with limited permissions

### Recommended: Switch to SSH Keys

For production, use SSH key authentication instead:

1. Generate SSH key pair:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins_deploy_key
   ```

2. Copy public key to server:
   ```bash
   ssh-copy-id -i ~/.ssh/jenkins_deploy_key.pub admin@homelab.local
   ```

3. Add private key to Jenkins credentials:
   - Kind: SSH Username with private key
   - ID: `YOUR_NODE-ssh-key`
   - Username: `homelab`
   - Private Key: [paste content of jenkins_deploy_key]

4. Use `sshagent` in pipeline (see `ssh-deployment-yaml.yaml`)

## Testing the Connection

Test SSH connection from Jenkins agent:

```bash
# With sshpass
sshpass -p 'homelab' ssh -o StrictHostKeyChecking=no admin@homelab.local "echo 'Connection successful'"

# Manual test
ssh admin@homelab.local
# Enter password: homelab
```

## Troubleshooting

### Issue: "sshpass: command not found"
**Solution**: Install sshpass on Jenkins agent (see step 2 above)

### Issue: "Permission denied"
**Solution**: 
- Verify credentials ID matches: `deploy-ssh-creds`
- Check username/password are correct
- Try manual SSH: `ssh admin@homelab.local

### Issue: "Host key verification failed"
**Solution**: Already handled with `-o StrictHostKeyChecking=no` in pipeline

### Issue: "Password authentication failed"
**Solution**:
- Check server allows password authentication:
  ```bash
  # On server, check /etc/ssh/sshd_config
  grep PasswordAuthentication /etc/ssh/sshd_config
  # Should be: PasswordAuthentication yes
  ```

## File Locations on Remote Server

After successful deployment:
- Package location: `/tmp/package/`
- Archive: `/tmp/deploy.tar.gz`
- Application file: `/tmp/package/app.txt`

## Next Steps

Once this works:
1. Try the full-featured `ssh-deployment-yaml.yaml`
2. Implement proper backup/rollback
3. Deploy to custom paths (not /tmp)
4. Add service restart commands
5. Switch to SSH key authentication for security
