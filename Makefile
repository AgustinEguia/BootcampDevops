# Makefile
# ---------
# Atajos para las tareas más comunes del curso. La idea es que los alumnos
# no tengan que memorizar comandos largos de docker/kubectl/terraform: acá
# están documentados y centralizados.
#
# Uso: `make <target>` (ej: `make test`). `make help` lista todos los targets.

APP_VERSION ?= local-dev
IMAGE_NAME  ?= devops-bootcamp-demo
IMAGE_TAG   ?= $(APP_VERSION)
NAMESPACE   ?= dev
TF_DIR      ?= terraform/10-network

.PHONY: help run test lint build scan up down k8s-deploy tf-plan clean

help: ## Muestra esta ayuda
	@echo "Targets disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

run: ## Corre la app localmente con uvicorn (sin Docker), útil para desarrollar rápido
	# Corremos desde la raíz del repo (no "cd app") porque app/main.py importa con
	# `from app.metrics import ...` (import absoluto): así el mismo código funciona
	# igual acá, en los tests (rootdir=repo) y dentro del contenedor (donde el
	# Dockerfile copia todo a /app/app/).
	APP_VERSION=$(APP_VERSION) uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test: ## Corre los tests con pytest y reporte de cobertura
	cd app && python -m pytest tests -v \
		--cov=. --cov-report=term-missing --cov-report=xml:coverage.xml \
		--junitxml=junit.xml

lint: ## Corre ruff (estilo/errores Python) y bandit (seguridad estática)
	ruff check app/
	bandit -r app/main.py app/metrics.py -q

build: ## Construye la imagen Docker con BuildKit
	DOCKER_BUILDKIT=1 docker build \
		--build-arg APP_VERSION=$(APP_VERSION) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		.

scan: ## Escanea la imagen ya buildeada con Trivy (falla en vulnerabilidades CRITICAL)
	trivy image --severity CRITICAL,HIGH --exit-code 1 $(IMAGE_NAME):$(IMAGE_TAG)

up: ## Levanta todo el stack local (app + prometheus + grafana) con docker compose
	docker compose up --build -d
	@echo "App:        http://localhost:8000"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana:    http://localhost:3000 (admin/admin)"

down: ## Baja el stack local de docker compose
	docker compose down -v

k8s-deploy: ## Deploya al cluster actual (contexto de kubectl) usando kustomize, overlay dev
	kubectl apply -k k8s/overlays/dev

tf-plan: ## Corre `terraform plan` en el módulo indicado por TF_DIR (default: terraform/10-network)
	cd $(TF_DIR) && terraform init -input=false && terraform plan

clean: ## Limpia artefactos generados localmente
	rm -rf app/.pytest_cache app/htmlcov app/coverage.xml app/junit.xml app/.coverage
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
