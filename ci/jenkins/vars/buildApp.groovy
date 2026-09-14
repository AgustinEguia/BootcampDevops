// buildApp.groovy
// -----------------
// Ejemplo de "shared library step" de Jenkins: una función reusable que
// encapsula "instalar dependencias y correr los tests con cobertura".
//
// ¿Por qué esto en vez de poner el `sh` directo en el Jenkinsfile?
// Porque si mañana el equipo tiene 5 microservicios Python distintos,
// cada uno con su propio Jenkinsfile, todos pueden llamar a
// `buildApp()` en vez de copiar/pegar el mismo bloque de shell en cada
// repo. Si después hay que cambiar algo (por ejemplo, agregar un flag a
// pytest), se cambia en UN solo lugar (esta shared library) y todos los
// pipelines que la usan se actualizan solos.
//
// Convención de Jenkins: un archivo dentro de vars/ cuyo nombre es
// "nombreFuncion.groovy" define automáticamente un "global step" que se
// puede llamar como nombreFuncion() desde cualquier Jenkinsfile, una vez
// que la shared library está registrada (ver README.md en esta carpeta).
def call(Map config = [:]) {
    // config permite parametrizar la función sin romper compatibilidad:
    // quien la llama sin argumentos (buildApp()) usa los defaults de
    // abajo; quien necesita algo distinto puede pasar
    // buildApp(pythonVersion: '3.12').
    def appDir = config.get('appDir', 'app')

    sh "pip install --quiet -r ${appDir}/requirements-dev.txt"
    sh """
      cd ${appDir}
      python -m pytest tests -v \
        --cov=. --cov-report=term-missing \
        --cov-report=xml:coverage.xml \
        --junitxml=junit.xml
    """
}
