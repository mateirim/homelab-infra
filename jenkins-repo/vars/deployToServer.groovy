#!/usr/bin/env groovy

/**
 * Shared library function for SSH deployment
 * Usage in Jenkinsfile:
 *   deployToServer(
 *       host: 'server.example.com',
 *       user: 'deploy',
 *       credentialsId: 'ssh-key',
 *       sourcePath: 'dist/*',
 *       targetPath: '/opt/app'
 *   )
 */

def call(Map config) {
    def host = config.host ?: error('Host parameter is required')
    def user = config.user ?: 'deploy'
    def credentialsId = config.credentialsId ?: 'ssh-deploy-key'
    def sourcePath = config.sourcePath ?: '*'
    def targetPath = config.targetPath ?: '/tmp'
    def serviceName = config.serviceName ?: null
    def preDeployCommands = config.preDeployCommands ?: []
    def postDeployCommands = config.postDeployCommands ?: []
    
    echo "Deploying to ${user}@${host}:${targetPath}"
    
    sshagent(credentials: [credentialsId]) {
        // Pre-deployment commands
        if (preDeployCommands) {
            echo 'Running pre-deployment commands...'
            preDeployCommands.each { cmd ->
                sh "ssh -o StrictHostKeyChecking=no ${user}@${host} '${cmd}'"
            }
        }
        
        // Create target directory
        sh """
            ssh -o StrictHostKeyChecking=no ${user}@${host} 'mkdir -p ${targetPath}'
        """
        
        // Copy files
        echo "Copying files from ${sourcePath} to ${targetPath}..."
        sh """
            scp -o StrictHostKeyChecking=no -r ${sourcePath} ${user}@${host}:${targetPath}/
        """
        
        // Restart service if specified
        if (serviceName) {
            echo "Restarting service: ${serviceName}..."
            sh """
                ssh -o StrictHostKeyChecking=no ${user}@${host} 'sudo systemctl restart ${serviceName}'
            """
        }
        
        // Post-deployment commands
        if (postDeployCommands) {
            echo 'Running post-deployment commands...'
            postDeployCommands.each { cmd ->
                sh "ssh -o StrictHostKeyChecking=no ${user}@${host} '${cmd}'"
            }
        }
    }
    
    echo 'Deployment completed successfully!'
}
