"""
metrics.py
----------
Instrumentación de métricas Prometheus para la app.

¿Por qué un módulo aparte y no todo mezclado en main.py?
Porque en un proyecto real la instrumentación (qué medimos y cómo)
suele evolucionar por separado de la lógica de negocio, y separarla
facilita testearla y reusarla en otros servicios del mismo equipo.

Usamos el patrón RED (Rate, Errors, Duration) que es el estándar de facto
para monitorear servicios HTTP:
  - Rate:     cuántos requests por segundo llegan (lo derivamos de un Counter)
  - Errors:   cuántos de esos requests terminan en error (lo derivamos del
              mismo Counter filtrando por status code)
  - Duration: cuánto tardan en responder (lo medimos con un Histogram)
"""
import time
from typing import Callable

from prometheus_client import Counter, Histogram
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Counter: valor que sólo crece. Ideal para contar eventos (requests, errores).
# Las labels (method, path, status_code) nos permiten después, en Grafana,
# filtrar y agrupar (por ejemplo: "sólo requests a /api/tasks que dieron 5xx").
#
# OJO pedagógico: usamos el *path template* (ej "/api/tasks/{task_id}") y no
# la URL cruda, para no explotar la cardinalidad de la métrica. Si usáramos
# el id real de cada tarea como label, Prometheus terminaría guardando una
# serie temporal distinta por cada id que haya existido alguna vez: esto se
# llama "cardinality explosion" y es una de las causas más comunes de que
# un Prometheus se quede sin memoria en producción.
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Cantidad total de requests HTTP recibidos",
    labelnames=("method", "path", "status_code"),
)

# Histogram: además de contar, agrupa las observaciones en "buckets" de
# duración. Con eso podemos calcular percentiles (p50, p95, p99) en Grafana
# usando la función histogram_quantile() de PromQL.
#
# Los buckets están pensados para una API REST simple: la mayoría de los
# requests debería resolverse en pocos milisegundos, pero dejamos buckets
# más grandes por si hay una degradación (por ejemplo problemas de I/O).
HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "Duración de los requests HTTP en segundos",
    labelnames=("method", "path"),
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)


class PrometheusMiddleware(BaseHTTPMiddleware):
    """
    Middleware ASGI que envuelve cada request para medir su duración y
    contarlo, sin que cada endpoint tenga que instrumentarse a mano.

    ¿Por qué un middleware y no decoradores en cada endpoint?
    Porque así garantizamos que TODOS los endpoints (incluso los que se
    agreguen en el futuro) queden instrumentados por igual, sin depender
    de que cada desarrollador se acuerde de agregar el decorador.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()

        # Usamos route.path (el template, ej "/api/tasks/{task_id}") en vez
        # de request.url.path (la URL real, ej "/api/tasks/42") para evitar
        # la cardinalidad explosiva que mencionamos arriba.
        response = await call_next(request)

        duration = time.perf_counter() - start_time
        route = request.scope.get("route")
        path_template = route.path if route is not None else request.url.path

        HTTP_REQUESTS_TOTAL.labels(
            method=request.method,
            path=path_template,
            status_code=str(response.status_code),
        ).inc()

        HTTP_REQUEST_DURATION_SECONDS.labels(
            method=request.method,
            path=path_template,
        ).observe(duration)

        return response
