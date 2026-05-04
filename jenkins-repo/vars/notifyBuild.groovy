#!/usr/bin/env groovy

/**
 * Shared library function for build notifications
 * Usage in Jenkinsfile:
 *   notifyBuild('STARTED')
 *   notifyBuild('SUCCESS')
 *   notifyBuild('FAILURE')
 */

def call(String buildStatus = 'STARTED') {
    buildStatus = buildStatus ?: 'SUCCESS'
    
    def subject = "${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
    def summary = "${subject} (${env.BUILD_URL})"
    def details = """
        <h2>${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'</h2>
        <p>Check console output at <a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a></p>
        <p><b>Job:</b> ${env.JOB_NAME}</p>
        <p><b>Build Number:</b> ${env.BUILD_NUMBER}</p>
        <p><b>Build URL:</b> ${env.BUILD_URL}</p>
        <p><b>Status:</b> ${buildStatus}</p>
    """
    
    def color = 'gray'
    def emoji = '⚪'
    
    switch(buildStatus) {
        case 'STARTED':
            color = 'blue'
            emoji = '🔵'
            break
        case 'SUCCESS':
            color = 'good'
            emoji = '✅'
            break
        case 'UNSTABLE':
            color = 'warning'
            emoji = '⚠️'
            break
        case 'FAILURE':
            color = 'danger'
            emoji = '❌'
            break
        default:
            color = 'gray'
            emoji = '⚪'
    }
    
    // Slack notification
    try {
        slackSend(
            color: color,
            message: "${emoji} ${summary}",
            channel: '#jenkins-builds'
        )
    } catch (Exception e) {
        echo "Slack notification failed: ${e.message}"
    }
    
    // Email notification
    try {
        emailext(
            subject: subject,
            body: details,
            mimeType: 'text/html',
            recipientProviders: [
                developers(),
                requestor(),
                culprits()
            ]
        )
    } catch (Exception e) {
        echo "Email notification failed: ${e.message}"
    }
    
    // Console output
    echo "Build Notification: ${buildStatus}"
}
