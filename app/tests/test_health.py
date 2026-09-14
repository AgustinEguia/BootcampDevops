"""
test_health.py
---------------
Tests de los endpoints "de infraestructura": /, /healthz, /readyz y /metrics.

Estos son los endpoints que va a usar Kubernetes (probes) y Prometheus
(scraping), así que es importante que nunca se rompan silenciosamente.
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_devuelve_saludo_y_version():
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert "message" in body
    assert "version" in body


def test_healthz_ok():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readyz_ok():
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_metrics_expone_formato_prometheus():
    # Primero generamos algo de tráfico para que el Counter tenga datos.
    client.get("/healthz")

    response = client.get("/metrics")
    assert response.status_code == 200
    # El formato de exposición de Prometheus es texto plano, no JSON.
    assert "http_requests_total" in response.text
    assert "http_request_duration_seconds" in response.text
