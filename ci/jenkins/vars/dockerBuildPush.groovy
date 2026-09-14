// dockerBuildPush.groovy
// -------------------------
// Shared library step que encapsula "buildear la imagen con BuildKit y
// pushearla al registry". Centralizar esto evita que cada equipo invente
// su propia forma (a veces insegura, por ejemplo con --password en texto
// plano) de hacer login al registry.
//
// Uso desde un Jenkinsfile:
//   dockerBuildPush(
//       imageName: 'mi-registry.com/mi-app',
//       tag: env.GIT_COMMIT.take(8),
//       credentialsId: 'registry-creds'   // credencial tipo "usuario y contraseña" en Jenkins
//   )
def call(Map config) {
    // Validamos los parámetros obligatorios temprano: si falta alguno,
    // preferimos que el pipeline falle acá con un mensaje claro, en vez
    // de fallar más adelante con un error críptico de Docker.
    def required = ['imageName', 'tag', 'credentialsId']
    required.each { key ->
        if (!config.containsKey(key)) {
            error "dockerBuildPush: falta el parámetro obligatorio '${key}'"
        }
    }

    def imageName = config.imageName
    def tag = config.tag
    def credentialsId = config.credentialsId
    def appVersion = config.get('appVersion', tag)

    // withCredentials inyecta el usuario/password como variables de
    // entorno SOLO durante este bloque, y Jenkins las enmascara
    // automáticamente en los logs (aparecen como ****). Es la forma
    // segura de manejar credenciales, en contraste con hardcodearlas en
    // el Jenkinsfile o pasarlas como parámetro de texto plano.
    withCredentials([usernamePassword(
        credentialsId: credentialsId,
        usernameVariable: 'REGISTRY_USER',
        passwordVariable: 'REGISTRY_PASS'
    )]) {
        sh """
          echo "\$REGISTRY_PASS" | docker login -u "\$REGISTRY_USER" --password-stdin "${imageName.split('/')[0]}"

          DOCKER_BUILDKIT=1 docker build \
            --build-arg APP_VERSION=${appVersion} \
            -t ${imageName}:${tag} \
            .

          docker push ${imageName}:${tag}
        """
    }
}
