pipeline {
    agent any

    environment {
        DOCKER_IMAGE     = 'ivanvetr/devops-lab'
        DOCKER_TAG       = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'local'}"
        DOCKER_REGISTRY  = 'docker.io'
        REGISTRY_CREDS   = credentials('dockerhub-credentials')
        SONAR_TOKEN      = credentials('sonar-token')
        SNYK_TOKEN       = credentials('snyk-token')
        K8S_NAMESPACE    = 'devops-lab'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Clonar repositorio') {
            steps {
                echo "Clonando repositorio desde ${env.GIT_URL}"
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Instalar dependencias') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Análisis estático') {
            steps {
                sh '''
                    . .venv/bin/activate
                    flake8 src/ tests/ --max-line-length=100 --statistics
                '''
            }
        }

        stage('Pruebas unitarias') {
            steps {
                sh '''
                    . .venv/bin/activate
                    python -m pytest tests/ \
                        --cov=src \
                        --cov-report=xml \
                        --cov-fail-under=80 \
                        --junitxml=test-results.xml \
                        -v
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results.xml'
                }
            }
        }

        stage('Análisis de seguridad - SonarQube') {
            steps {
                withSonarQubeEnv('sonarqube-server') {
                    sh '''
                        . .venv/bin/activate
                        sonar-scanner \
                            -Dsonar.projectKey=devops-lab \
                            -Dsonar.sources=src \
                            -Dsonar.tests=tests \
                            -Dsonar.python.coverage.reportPaths=coverage.xml \
                            -Dsonar.python.xunit.reportPath=test-results.xml
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Análisis de seguridad - Snyk') {
            steps {
                sh '''
                    . .venv/bin/activate
                    npm install -g snyk
                    snyk auth ${SNYK_TOKEN}
                    snyk test --file=requirements.txt --severity-threshold=high || true
                    snyk monitor --file=requirements.txt || true
                '''
            }
        }

        stage('Construir imagen Docker') {
            steps {
                script {
                    echo "Construyendo imagen: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    sh """
                        docker build \
                            --target production \
                            --tag ${DOCKER_IMAGE}:${DOCKER_TAG} \
                            --tag ${DOCKER_IMAGE}:latest \
                            --label "build.number=${env.BUILD_NUMBER}" \
                            --label "git.commit=${env.GIT_COMMIT?.take(7)}" \
                            .
                    """
                }
            }
        }

        stage('Snyk - Escaneo de imagen Docker') {
            steps {
                sh """
                    snyk container test ${DOCKER_IMAGE}:${DOCKER_TAG} \
                        --severity-threshold=high \
                        --file=Dockerfile || true
                """
            }
        }

        stage('Publicar en DockerHub') {
            when {
                branch 'main'
            }
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'dockerhub-credentials') {
                        sh """
                            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                            docker push ${DOCKER_IMAGE}:latest
                        """
                    }
                }
            }
        }

        stage('Desplegar en Kubernetes') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    kubectl apply -f k8s/00-namespace.yaml
                    kubectl apply -f k8s/01-configmap.yaml
                    kubectl apply -f k8s/02-deployment.yaml
                    kubectl apply -f k8s/03-service.yaml

                    kubectl set image deployment/devops-lab-app \
                        devops-lab=${DOCKER_IMAGE}:${DOCKER_TAG} \
                        -n ${K8S_NAMESPACE}

                    kubectl rollout status deployment/devops-lab-app \
                        -n ${K8S_NAMESPACE} --timeout=120s
                """
            }
        }

        stage('Verificar despliegue') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    kubectl get svc -n ${K8S_NAMESPACE}
                """
            }
        }

        stage('Limpieza local') {
            steps {
                sh """
                    docker rmi ${DOCKER_IMAGE}:${DOCKER_TAG} || true
                    docker image prune -f || true
                    rm -rf .venv
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completado exitosamente. Imagen: ${DOCKER_IMAGE}:${DOCKER_TAG}"
        }
        failure {
            echo "Pipeline fallido en la etapa: ${env.STAGE_NAME}"
        }
        always {
            cleanWs()
        }
    }
}
