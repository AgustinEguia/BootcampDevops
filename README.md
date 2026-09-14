# devops-bootcamp-demo

Repositorio demo del **bootcamp de DevOps/CI-CD** (10 días). Es una app
FastAPI mínima (CRUD de tareas en memoria) acompañada de TODO el stack
que se recorre durante el curso: contenedores, dos pipelines de CI/CD
equivalentes (GitLab CI y Jenkins), Kubernetes (manifiestos crudos +
Helm), Terraform sobre AWS, observabilidad (Prometheus/Grafana) y
seguridad (gitleaks, Trivy, SonarQube, Kyverno).

La app en sí es intencionalmente simple (no tiene base de datos real):
el objetivo del curso no es la lógica de negocio, sino todo lo que hace
falta ALREDEDOR de una app para llevarla de forma segura y confiable
hasta producción.

## ¿Qué es este repo?

Un proyecto "de punta a punta" que un trainee junior puede clonar,
correr localmente en minutos, y después ir recorriendo carpeta por
carpeta a medida que avanza el curso (ver la tabla de más abajo). Cada
archivo está comentado pensando en que **se lee como material de
estudio**, no sólo como configuración.

## Cómo correrlo local (sin AWS, sin Kubernetes)

Requisitos: Docker + Docker Compose. Opcionalmente Python 3.11+ si querés
correr la app sin contenedores.

```bash
git clone <este-repo>
cd devops-bootcamp-demo

# Opción A: todo con un solo comando (usa Make + docker compose)
make up
# App:        http://localhost:8000  (docs interactivas en /docs)
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000  (admin/admin)

# Para bajar todo:
make down
```

```bash
# Opción B: sin Docker, corriendo la app directo con uvicorn
python3 -m venv .venv
source .venv/bin/activate
pip install -r app/requirements-dev.txt
make test    # corre pytest con cobertura
make run     # levanta la app con reload automático en :8000
```

```bash
# Opción C: script que levanta todo Y verifica los endpoints
./scripts/bootstrap-local.sh
```

### Probar la API

```bash
curl http://localhost:8000/healthz
curl http://localhost:8000/readyz
curl -X POST http://localhost:8000/api/tasks -H "Content-Type: application/json" -d '{"title":"Aprender Docker"}'
curl http://localhost:8000/api/tasks
```

O directamente desde el navegador: `http://localhost:8000/docs` (Swagger
UI autogenerado por FastAPI).

## Mapa del repo por día del curso

| Día | Tema | Archivos que se tocan |
|---|---|---|
| 1 | Linux para DevOps + repos y estrategia de ramas | `app/`, `Makefile`, `.gitignore`, `README.md` |
| 2 | Docker: imágenes, capas, multi-stage, registry | `Dockerfile`, `.dockerignore`, `docker-compose.yml` |
| 3 | CI: conceptos + GitLab CI de punta a punta | `.gitlab-ci.yml`, `ci/gitlab/00-variables.yml`, `ci/gitlab/10-build.yml`, `ci/gitlab/20-test.yml` |
| 4 | Jenkins: el mismo pipeline en otra herramienta | `Jenkinsfile`, `ci/jenkins/vars/*.groovy`, `ci/jenkins/README.md` |
| 5 | Testing, calidad y versionado de artefactos | `app/tests/`, `security/sonar-project.properties`, `ci/gitlab/20-test.yml` |
| 6 | DevSecOps I: shift-left (secretos, SAST, SCA, SBOM) | `ci/gitlab/30-security.yml`, `security/.gitleaks.toml`, `security/trivy/.trivyignore`, `security/README.md` |
| 7 | Kubernetes: fundamentos y primer despliegue | `k8s/base/`, `k8s/overlays/dev/`, `k8s/overlays/prod/`, `scripts/kind-cluster.sh` |
| 8 | CD a Kubernetes: Helm, estrategias, políticas | `helm/demo-app/`, `ci/gitlab/40-deploy.yml`, `k8s/rbac/`, `security/policies/kyverno-*.yaml`, `scripts/smoke-test.sh` |
| 9 | Observabilidad: Prometheus, Grafana, alertas, SLO | `app/metrics.py`, `monitoring/prometheus/`, `monitoring/grafana/` |
| 10 | Terraform + AWS + proyecto integrador | `terraform/`, `ci/gitlab/50-terraform.yml`, y todo el repo |

## Estructura del repo

```
devops-bootcamp-demo/
├── app/                 # API FastAPI + tests + métricas Prometheus
├── ci/                  # includes de GitLab CI + shared library de Jenkins
├── k8s/                 # manifiestos crudos + Kustomize (base + overlays dev/prod)
├── helm/demo-app/        # chart de Helm equivalente a k8s/, parametrizado
├── terraform/             # infraestructura AWS: backend, red, ECR, EKS
├── monitoring/              # Prometheus (scrape config + alertas) y Grafana (dashboards)
├── security/                 # config de gitleaks/Sonar/Trivy + políticas Kyverno
├── scripts/                    # bootstrap local, cluster kind, smoke test
├── Dockerfile, docker-compose.yml, Makefile, .gitlab-ci.yml, Jenkinsfile
```

## Comandos del Makefile

Corré `make help` para ver la lista completa con descripciones. Los más
usados:

| Comando | Qué hace |
|---|---|
| `make run` | Corre la app local con uvicorn (sin Docker) |
| `make test` | Corre pytest con cobertura |
| `make lint` | Corre ruff + bandit |
| `make build` | Construye la imagen Docker |
| `make scan` | Escanea la imagen con Trivy |
| `make up` / `make down` | Levanta/baja el stack completo con docker compose |
| `make k8s-deploy` | Aplica `k8s/overlays/dev` con kubectl+kustomize |
| `make tf-plan` | Corre `terraform plan` (usar `TF_DIR=terraform/<módulo>`) |

## Los dos pipelines de CI/CD (GitLab y Jenkins)

`.gitlab-ci.yml` (que incluye los archivos de `ci/gitlab/`) y
`Jenkinsfile` (que usa la shared library de `ci/jenkins/`) implementan
**el mismo flujo de 10 etapas**, para que los alumnos vean cómo el mismo
concepto se expresa en dos herramientas distintas:

`lint → test → sast → secrets → sca → build → image-scan → deploy-dev → smoke-test → deploy-prod`

- **deploy-dev** y **smoke-test** corren automáticamente en cada push a
  la rama principal.
- **deploy-prod** requiere aprobación manual (`when: manual` en GitLab,
  `input` en Jenkins) — el procedimiento de rollback está documentado en
  `ci/gitlab/40-deploy.yml`.

## Advertencia sobre Terraform/AWS

Todo lo que hay en `terraform/` crea recursos REALES y FACTURABLES en
AWS (EKS, NAT Gateways, EC2). Leer `terraform/README.md` antes de correr
`terraform apply` — incluye el orden correcto de aplicación y una
estimación de costos. Para practicar Kubernetes sin gastar en AWS, usar
`scripts/kind-cluster.sh` en su lugar.

## Licencia

Material educativo para uso interno del bootcamp.
