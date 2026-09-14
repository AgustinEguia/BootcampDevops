# Shared Library de Jenkins — cómo registrarla

Esta carpeta (`ci/jenkins/`) contiene una **shared library** de Jenkins de
ejemplo: funciones reusables (`vars/buildApp.groovy`,
`vars/dockerBuildPush.groovy`) que el `Jenkinsfile` de este repo invoca
como si fueran comandos nativos (`buildApp()`, `dockerBuildPush(...)`).

## ¿Qué es una shared library?

Es la forma que tiene Jenkins de compartir código de pipeline entre
distintos proyectos, en vez de copiar/pegar bloques de `sh` en cada
`Jenkinsfile`. Funciona muy parecido a los `include: local:` de
`.gitlab-ci.yml`, pero con Groovy en vez de YAML.

## Cómo registrarla en una instancia de Jenkins

Hay dos formas: **global** (para toda la instancia) o **por proyecto**
("Folder-level Shared Library"). Para el curso alcanza con la global:

1. Ir a **Manage Jenkins → System → Global Trusted Pipeline Libraries**
   (en versiones más viejas: **Global Pipeline Libraries**).
2. Click en **Add**.
3. Completar:
   - **Name**: `devops-bootcamp-shared-lib` (este nombre es el que se usa
     en el `@Library(...)` del Jenkinsfile, si se decide usar esa
     sintaxis explícita en vez de auto-carga por carpeta).
   - **Default version**: `main` (la rama del repo que se va a usar).
   - **Retrieval method**: `Modern SCM` → `Git`.
   - **Project Repository**: la URL de este mismo repo.
4. Importante: Jenkins espera que la shared library tenga la carpeta
   `vars/` en la **raíz** del repositorio que se registra. Como en este
   demo `vars/` vive dentro de `ci/jenkins/vars/` (para mantener todo el
   material de Jenkins agrupado junto al resto de `ci/`), hay dos
   opciones:
   - **Opción A (recomendada para el curso)**: en el campo
     **Library Path** (disponible en Jenkins 2.x con el plugin
     `pipeline-groovy-lib` reciente) indicar `ci/jenkins` como subcarpeta
     raíz de la librería.
   - **Opción B**: si tu versión de Jenkins no soporta subcarpeta,
     registrar la shared library apuntando a un repo/carpeta separada
     donde `vars/` esté en la raíz (típico en organizaciones grandes,
     donde la shared library vive en SU PROPIO repositorio,
     versionado independientemente de las apps que la usan).

5. Una vez registrada, cualquier `Jenkinsfile` de la organización puede
   usar `buildApp()` y `dockerBuildPush(...)` sin declarar `@Library`
   explícitamente (si se marcó "Load implicitly"), o agregando al inicio
   del Jenkinsfile:

   ```groovy
   @Library('devops-bootcamp-shared-lib') _
   ```

## Probarla localmente antes de subirla

Groovy no tiene un "linter" tan directo como `ruff`, pero como mínimo se
puede validar la sintaxis con:

```bash
groovy -e "new GroovyShell().parse(new File('ci/jenkins/vars/buildApp.groovy'))"
```

o, si tenés el CLI de Jenkins configurado contra una instancia:

```bash
java -jar jenkins-cli.jar -s http://localhost:8080/ declarative-linter < Jenkinsfile
```

## Para profundizar

Documentación oficial: <https://www.jenkins.io/doc/book/pipeline/shared-libraries/>
