# Seguridad — qué escanea cada herramienta y en qué etapa

Este proyecto usa varias herramientas de seguridad, cada una mirando una
capa distinta del "supply chain" de software (defensa en profundidad:
ninguna herramienta sola cubre todo). Esta tabla resume qué hace cada una
y en qué stage del pipeline corre (ver `.gitlab-ci.yml` / `Jenkinsfile`
para el detalle exacto de cada job).

| Herramienta | Qué escanea | Etapa del pipeline | ¿Bloquea el pipeline? |
|---|---|---|---|
| **ruff** | Estilo y errores comunes del código Python propio | `lint` | Sí |
| **hadolint** | Malas prácticas en el `Dockerfile` (correr como root, no fijar versión de base, etc.) | `lint` | Sí |
| **bandit** | Patrones de código Python inseguros (eval, subprocess con shell=True, credenciales hardcodeadas) en NUESTRO código | `sast` | Sí |
| **SonarQube** | Calidad de código en general (bugs, code smells, duplicación, complejidad) + un Quality Gate configurable | `sast` | **No** (`allow_failure: true`) — ver por qué abajo |
| **gitleaks** | Secretos (API keys, tokens, passwords) commiteados en el HISTORIAL de git, no sólo el working tree actual | `secrets` | Sí |
| **Trivy (modo `fs`)** | CVEs conocidas en las DEPENDENCIAS declaradas (`requirements.txt`) | `sca` | No (informativo, `exit-code 0`) |
| **Syft/Trivy (SBOM)** | No "escanea" en sí: genera un inventario formal (SBOM) de todo lo que compone el software, con versiones y licencias | `sca` | No aplica |
| **Trivy (modo `image`)** | CVEs conocidas en la IMAGEN DOCKER final ya construida (incluye el SO base y todas sus librerías) | `image-scan` | **Sí, en CRITICAL** |
| **Kyverno** | Políticas sobre los MANIFIESTOS de Kubernetes en tiempo de admisión al cluster (no en CI): bloquea Pods que corren como root o usan el tag `:latest` | En el cluster (admission controller), no en CI | Sí (bloquea el `kubectl apply`/`helm upgrade` si viola la policy) |

## Por qué SonarQube tiene `allow_failure: true`

A diferencia de bandit (que no necesita nada más que Python instalado),
SonarQube requiere un **servidor corriendo** (con su propio
`SONAR_HOST_URL` y un token `SONAR_TOKEN` configurado como variable
protegida del proyecto en GitLab, o una credencial en Jenkins). No todos
los ambientes de práctica del curso van a tener ese servidor levantado
en todo momento, así que dejamos el job "permitido a fallar": si el
servidor no está disponible, el job va a fallar (no puede conectarse)
pero **no bloquea** el resto del pipeline.

En un proyecto real, una vez que el equipo tiene SonarQube bien
configurado y confía en su Quality Gate, este job debería pasar a
`allow_failure: false` para que sea realmente bloqueante — de lo
contrario, el Quality Gate es sólo decorativo.

## Defensa en profundidad: por qué hay 3 escáneres de vulnerabilidades distintos

Puede parecer redundante tener bandit + Trivy (fs) + Trivy (image) + el
scan-on-push nativo de ECR (ver `terraform/20-ecr/main.tf`), pero cada
uno mira algo distinto:

- **bandit**: sólo nuestro código Python (`app/main.py`, `app/metrics.py`).
- **Trivy fs**: las dependencias de terceros que declaramos
  (`requirements.txt`), ANTES de buildear la imagen.
- **Trivy image**: la imagen final completa, incluyendo el sistema
  operativo base (`python:3.11-slim`) y TODAS las librerías del sistema
  que trae, no sólo las de Python.
- **ECR scan-on-push**: la misma idea que Trivy image, pero corriendo del
  lado del registry, protegiendo incluso imágenes pusheadas por fuera
  del pipeline (por ejemplo, alguien probando algo a mano).

Si sólo tuviéramos uno de estos, quedaría un punto ciego: bandit no ve
CVEs de dependencias, Trivy fs no ve vulnerabilidades del SO base, y
ninguno de los dos in-pipeline protege contra un push manual fuera del
CI/CD.

## Gitleaks vs. secretos en Kubernetes

Gitleaks protege el REPOSITORIO DE GIT (que nunca llegue un secreto real
commiteado). Una vez que el secreto YA está en Kubernetes (ver
`k8s/base/secret.example.yaml`), la protección es distinta: por default
un `Secret` de K8s sólo está en base64 (NO encriptado), así que en un
cluster real conviene sumar Sealed Secrets, External Secrets Operator o
SOPS — gitleaks no cubre esa capa.
