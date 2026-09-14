# Observabilidad del proyecto (Día 9)

## Qué hay acá

| Ruta | Qué es |
|---|---|
| `prometheus/prometheus.yml` | configuración de scrape: de dónde saca las métricas Prometheus |
| `prometheus/alerts.yml` | reglas de alerta (app caída, error rate, latencia p95, reinicios) |
| `grafana/provisioning/` | datasource y carga automática de dashboards al arrancar Grafana |
| `grafana/dashboards/demo-app.json` | dashboard con paneles RED + panel DORA |

## De dónde sale cada métrica

Las métricas del dashboard vienen de **dos fuentes distintas**, y es
importante que no las confundas:

**1. Métricas de la aplicación** (`http_requests_total`,
`http_request_duration_seconds`): las expone la app en `/metrics` y las
define `app/metrics.py`. Prometheus las scrapea del pod. Son las que
alimentan los paneles RED (Rate, Errors, Duration).

**2. Métricas DORA** (`demo_app_deploys_total`,
`demo_app_lead_time_seconds`, `demo_app_rollbacks_total`,
`demo_app_incident_restore_time_seconds`): **no las produce la app**, y no
podría producirlas. La app no sabe cuántas veces la desplegaron ni cuánto
tardó un commit en llegar a producción: eso lo sabe el pipeline.

Estas métricas se empujan desde el job de deploy a un **Pushgateway** de
Prometheus, con una línea al final del deploy. Por ejemplo:

```sh
echo "demo_app_deploys_total 1" | \
  curl --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/deploy/env/${ENVIRONMENT}"
```

Hasta que no montes el Pushgateway y agregues ese paso al pipeline, los
paneles DORA del dashboard van a aparecer vacíos (`No data`). **Eso es
esperado, no es un error del dashboard**: es el ejercicio que queda
abierto al final del Día 9.

> Pushgateway es la excepción al modelo pull de Prometheus, y sólo se
> justifica para eventos efímeros como este: un job de CI que termina y
> desaparece no puede ser scrapeado. Para todo lo demás, usá pull.
