# syntax=docker/dockerfile:1
#
# Dockerfile multi-stage para la app FastAPI del bootcamp.
#
# ¿Por qué multi-stage? Separamos la etapa de "builder" (donde instalamos
# dependencias, algunas de las cuales necesitan compiladores/headers) de la
# etapa "runtime" (la imagen final que se despliega). Así la imagen final
# no arrastra herramientas de compilación ni cache de pip, quedando más
# chica y con menos superficie de ataque.

# ---- Etapa 1: builder --------------------------------------------------
FROM python:3.11-slim AS builder

# ARG vs ENV: ARG sólo existe durante el build, ENV persiste en la imagen
# final. Acá build-args nos permite parametrizar sin tocar el Dockerfile.
ARG APP_VERSION=0.0.0-dev

# Evitamos que pip guarde cache (no la necesitamos, es una imagen efímera)
# y que Python genere archivos .pyc innecesarios durante la instalación.
ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Copiamos primero SÓLO el archivo de dependencias. Docker cachea cada
# instrucción por capas: si requirements.txt no cambió, esta capa se
# reusa desde cache y no hace falta reinstalar todo de nuevo en cada
# build, aunque el código de la app sí haya cambiado. Esto acelera
# muchísimo los builds en CI.
COPY app/requirements.txt .

# Instalamos las dependencias dentro de un virtualenv propio que después
# vamos a copiar completo a la imagen final. Esto es más prolijo que
# instalar con --user y evita mezclar paquetes del sistema.
#
# OJO: el venv se crea directamente en /opt/venv, la MISMA ruta que va a
# tener en la imagen final. Los "console scripts" de un venv (uvicorn,
# pip, etc.) llevan grabado un shebang con la ruta ABSOLUTA del intérprete
# en el momento de instalarlos; si el venv se crea en /build/.venv y
# después se copia a /opt/venv, el shebang sigue apuntando a /build/.venv
# y el contenedor muere al arrancar con "exec ...: no such file or
# directory". Un venv no es relocalizable.
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ---- Etapa 2: runtime ---------------------------------------------------
FROM python:3.11-slim AS runtime

ARG APP_VERSION=0.0.0-dev

# Buenas prácticas de seguridad en contenedores:
#  - Crear un usuario NO root dedicado (nunca correr como root en runtime).
#  - No instalar herramientas de build ni shells de más.
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /usr/sbin/nologin --create-home appuser

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}

WORKDIR /app

# Copiamos el virtualenv ya armado desde el builder: así la imagen final
# no necesita pip, ni compiladores, ni el cache de instalación.
COPY --from=builder /opt/venv /opt/venv

# Copiamos sólo el código de la aplicación (no tests, no docs: ver
# .dockerignore) y le damos ownership al usuario no-root.
COPY --chown=appuser:appuser app/main.py app/metrics.py /app/app/
COPY --chown=appuser:appuser app/__init__.py /app/app/

# Labels OCI: metadata estándar que herramientas de seguridad (Trivy),
# de inventario de imágenes y de trazabilidad usan para saber qué es esta
# imagen, de qué commit/versión salió y quién la mantiene.
LABEL org.opencontainers.image.title="devops-bootcamp-demo" \
      org.opencontainers.image.description="API demo FastAPI para el bootcamp de DevOps/CI-CD" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://gitlab.com/tu-org/devops-bootcamp-demo" \
      org.opencontainers.image.licenses="MIT"

USER appuser

EXPOSE 8000

# HEALTHCHECK: le permite a Docker (y a docker-compose) saber si el
# contenedor está "sano" sin depender de Kubernetes. En K8s las probes del
# deployment.yaml son las que realmente importan, pero este HEALTHCHECK es
# muy útil para levantar la app con docker-compose durante el curso.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz', timeout=2)" || exit 1

# Usamos exec form (JSON array) para que uvicorn sea el proceso PID 1 y
# reciba correctamente las señales de terminación (SIGTERM) que manda
# Kubernetes al hacer un rolling update o un scale-down.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
