#!/usr/bin/env groovy

/**
 * Shared library for standard build pipeline
 * Usage in Jenkinsfile:
 *   @Library('jenkins-shared-library') _
 *   standardBuild {
 *       appName = 'myapp'
 *       buildTool = 'gradle'
 *   }
 */

def call(Map config = [:]) {
    pipeline {
        agent any
        
        environment {
            APP_NAME = config.appName ?: 'application'
            BUILD_TOOL = config.buildTool ?: 'maven'
            DEPLOY_ENABLED = config.deploy ?: false
        }
        
        stages {
            stage('Checkout') {
                steps {
                    script {
                        echo "Checking out ${APP_NAME}..."
                        checkout scm
                    }
                }
            }
            
            stage('Build') {
                steps {
                    script {
                        echo "Building with ${BUILD_TOOL}..."
                        
                        switch(BUILD_TOOL) {
                            case 'maven':
                                sh 'mvn clean package -DskipTests'
                                break
                            case 'gradle':
                                sh './gradlew clean build -x test'
                                break
                            case 'npm':
                                sh 'npm install && npm run build'
                                break
                            case 'go':
                                sh 'go build -v'
                                break
                            default:
                                error("Unsupported build tool: ${BUILD_TOOL}")
                        }
                    }
                }
            }
            
            stage('Test') {
                steps {
                    script {
                        echo "Running tests with ${BUILD_TOOL}..."
                        
                        switch(BUILD_TOOL) {
                            case 'maven':
                                sh 'mvn test'
                                break
                            case 'gradle':
                                sh './gradlew test'
                                break
                            case 'npm':
                                sh 'npm test'
                                break
                            case 'go':
                                sh 'go test -v ./...'
                                break
                        }
                    }
                }
            }
            
            stage('Deploy') {
                when {
                    expression { return DEPLOY_ENABLED }
                }
                steps {
                    script {
                        echo "Deploying ${APP_NAME}..."
                        // Add deployment logic
                    }
                }
            }
        }
        
        post {
            success {
                echo "${APP_NAME} build completed successfully!"
            }
            failure {
                echo "${APP_NAME} build failed!"
            }
            always {
                cleanWs()
            }
        }
    }
}
