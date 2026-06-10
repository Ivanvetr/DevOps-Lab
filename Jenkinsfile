pipeline {
    agent any

    environment {
        DOCKER_IMAGE     = 'ivanvetr/devops-lab'
        DOCKER_TAG       = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'local'}"
        DOCKER_REGISTRY  = 'docker.io'
        REGISTRY_CREDS   = credentials('dockerhub-credentials')
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
                        -v
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                }
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

        stage('Verificar imagen publicada') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    docker manifest inspect ${DOCKER_IMAGE}:${DOCKER_TAG} | \
                        python3 -c "import sys, json; m=json.load(sys.stdin); print('Arquitecturas:', [p['platform']['architecture'] for p in m.get('manifests', [])])"
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
