// Jenkinsfile
// ------------
// Pipeline declarativo equivalente al de GitLab CI (.gitlab-ci.yml).
// Mismas 10 etapas, mismo orden, mismo comportamiento (deploy-dev
// automático, deploy-prod con aprobación manual). La idea de tener AMBOS
// pipelines (GitLab y Jenkins) en el mismo repo es pedagógica: que los
// alumnos vean cómo el MISMO flujo de CI/CD se expresa distinto según la
// herramienta, pero los conceptos (stages, artifacts, gates manuales) son
// los mismos.
//
// Este Jenkinsfile usa dos funciones de la shared library del proyecto
// (ver ci/jenkins/vars/ y ci/jenkins/README.md para cómo registrarla):
//   - buildApp()         encapsula lint + test, para no repetir lógica
//   - dockerBuildPush()  encapsula el build y push de la imagen
//
// Requiere un agente con Docker, kubectl, helm y trivy disponibles (o,
// como alternativa "cloud native", correr cada stage en su propio pod de
// Kubernetes vía el plugin kubernetes de Jenkins).
pipeline {
    agent any

    options {
        // Evita que dos builds del mismo pipeline corran en paralelo y
        // pisen recursos compartidos (por ejemplo, el mismo tag de imagen).
        disableConcurrentBuilds()
        // Timeout global de seguridad: si algo se cuelga (por ejemplo,
        // esperando una aprobación manual que nadie ve), no queremos que
        // el agente quede bloqueado para siempre.
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        // Equivalente al IMAGE_NAME de GitLab CI: acá vendría de la
        // configuración del registry (ECR, Docker Hub, GitLab registry).
        IMAGE_NAME     = 'tu-registry.example.com/devops-bootcamp-demo'
        IMAGE_TAG_SHA  = "${env.GIT_COMMIT.take(8)}"
        K8S_NS_DEV     = 'dev'
        K8S_NS_PROD    = 'prod'
    }

    stages {

        // --- 1. lint --------------------------------------------------
        stage('lint') {
            steps {
                sh 'pip install --quiet ruff==0.6.9'
                sh 'ruff check app/'
                // hadolint corre vía Docker para no tener que instalarlo
                // en el agente de Jenkins.
                sh 'docker run --rm -i hadolint/hadolint:v2.12.0-alpine < Dockerfile'
            }
        }

        // --- 2. test ----------------------------------------------------
        stage('test') {
            steps {
                // buildApp() viene de ci/jenkins/vars/buildApp.groovy:
                // instala requirements-dev.txt y corre pytest con cobertura,
                // generando junit.xml y coverage.xml igual que en GitLab.
                buildApp()
            }
            post {
                always {
                    junit 'app/junit.xml'
                    // El plugin de cobertura de Jenkins lee el XML formato
                    // Cobertura, igual que hace GitLab con coverage_report.
                    recordCoverage(tools: [[parser: 'COBERTURA', pattern: 'app/coverage.xml']])
                }
            }
        }

        // --- 3. sast ------------------------------------------------------
        stage('sast') {
            parallel {
                stage('bandit') {
                    steps {
                        sh 'bandit -r app/main.py app/metrics.py -f json -o bandit-report.json || true'
                        sh 'bandit -r app/main.py app/metrics.py'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'bandit-report.json', allowEmptyArchive: true
                        }
                    }
                }
                stage('sonarqube') {
                    // Igual que en GitLab: SonarQube requiere un servidor
                    // configurado (SONAR_HOST_URL, credencial SONAR_TOKEN
                    // en el credentials store de Jenkins). Marcamos el
                    // stage como "puede fallar" con catchError, para que
                    // no bloquee el resto del pipeline si el servidor no
                    // está disponible en el ambiente de práctica del curso.
                    steps {
                        catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                            withSonarQubeEnv('sonarqube-server') {
                                sh 'sonar-scanner -Dsonar.projectKey=devops-bootcamp-demo'
                            }
                        }
                    }
                }
            }
        }

        // --- 4. secrets ----------------------------------------------------
        stage('secrets') {
            steps {
                sh '''
                  docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:v8.18.4 \
                    detect --source=/repo --config=/repo/security/.gitleaks.toml \
                    --report-format json --report-path /repo/gitleaks-report.json --verbose
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        // --- 5. sca -----------------------------------------------------
        stage('sca') {
            steps {
                sh '''
                  docker run --rm -v "$PWD:/repo" aquasec/trivy:0.55.2 \
                    fs --scanners vuln --severity CRITICAL,HIGH --exit-code 0 \
                    --format table /repo/app/requirements.txt

                  docker run --rm -v "$PWD:/repo" aquasec/trivy:0.55.2 \
                    fs --format cyclonedx --output /repo/sbom.cyclonedx.json /repo/app/requirements.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'sbom.cyclonedx.json', allowEmptyArchive: true
                }
            }
        }

        // --- 6. build ------------------------------------------------------
        stage('build') {
            steps {
                // dockerBuildPush() viene de
                // ci/jenkins/vars/dockerBuildPush.groovy: builda con
                // BuildKit y pushea al registry usando las credenciales
                // configuradas en Jenkins (credentialsId: 'registry-creds').
                dockerBuildPush(
                    imageName: env.IMAGE_NAME,
                    tag: env.IMAGE_TAG_SHA,
                    credentialsId: 'registry-creds'
                )
            }
        }

        // --- 7. image-scan --------------------------------------------------
        stage('image-scan') {
            steps {
                sh """
                  docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v "\$PWD/security/trivy/.trivyignore:/.trivyignore" \
                    aquasec/trivy:0.55.2 image --severity CRITICAL --exit-code 1 \
                    ${env.IMAGE_NAME}:${env.IMAGE_TAG_SHA}
                """
            }
        }

        // --- 8. deploy-dev --------------------------------------------------
        // Automático: corre siempre que el pipeline llegó hasta acá en la
        // rama main, sin pedir aprobación (dev es de integración continua).
        stage('deploy-dev') {
            when { branch 'main' }
            steps {
                sh """
                  helm upgrade --install demo-app helm/demo-app \
                    --namespace ${K8S_NS_DEV} --create-namespace \
                    --values helm/demo-app/values-dev.yaml \
                    --set image.tag=${env.IMAGE_TAG_SHA} \
                    --wait --timeout 3m
                """
            }
        }

        // --- 9. smoke-test -----------------------------------------------
        stage('smoke-test') {
            when { branch 'main' }
            steps {
                sh 'sh scripts/smoke-test.sh https://demo-app-dev.tu-dominio.com'
            }
        }

        // --- 10. deploy-prod --------------------------------------------
        // `input` es el equivalente en Jenkins de `when: manual` en
        // GitLab: pausa el pipeline y espera que un humano con permisos
        // apruete el paso, mostrando un botón en la UI de Jenkins. Se
        // puede restringir QUIÉN puede aprobar con el parámetro
        // `submitter`.
        stage('deploy-prod') {
            when { branch 'main' }
            steps {
                script {
                    input message: '¿Confirmás el deploy a PRODUCCIÓN?',
                          ok: 'Deployar',
                          submitter: 'devops-leads'
                }
                sh """
                  helm upgrade --install demo-app helm/demo-app \
                    --namespace ${K8S_NS_PROD} --create-namespace \
                    --values helm/demo-app/values-prod.yaml \
                    --set image.tag=${env.IMAGE_TAG_SHA} \
                    --wait --timeout 5m
                """
            }
        }
    }

    post {
        always {
            // Limpia el workspace para no acumular basura entre builds
            // (importante en agentes compartidos con espacio limitado).
            cleanWs()
        }
        failure {
            echo "Pipeline falló. Si fue en deploy-prod, ver la sección de ROLLBACK en ci/gitlab/40-deploy.yml (el procedimiento es el mismo, independientemente de qué herramienta de CI se usó para deployar)."
        }
    }
}
