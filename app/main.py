"""
main.py
-------
API demo para el bootcamp de DevOps/CI-CD.

Es intencionalmente simple: un CRUD de "tasks" en memoria (no hay base de
datos) para que el foco del curso esté en el pipeline, el contenedor y el
despliegue, y no en la lógica de negocio. En un proyecto real reemplazarías
el diccionario en memoria por una base de datos real (Postgres, etc.).

Endpoints:
  GET  /                 -> saludo, útil para probar que la app responde
  GET  /healthz           -> liveness probe: "¿el proceso está vivo?"
  GET  /readyz             -> readiness probe: "¿puedo recibir tráfico?"
  GET  /metrics             -> métricas en formato Prometheus
  GET  /api/tasks             -> lista todas las tareas
  POST /api/tasks              -> crea una tarea
  GET  /api/tasks/{task_id}     -> obtiene una tarea
  PUT  /api/tasks/{task_id}      -> reemplaza una tarea
  DELETE /api/tasks/{task_id}     -> borra una tarea
"""
import os
from itertools import count
from typing import Dict

from fastapi import FastAPI, HTTPException, status
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from pydantic import BaseModel, Field
from starlette.responses import Response

from app.metrics import PrometheusMiddleware

# --- Configuración por variables de entorno ---------------------------------
# Leer configuración de variables de entorno (y no hardcodearla) es una de
# las reglas de "The Twelve-Factor App": permite que la MISMA imagen Docker
# se comporte distinto en dev/staging/prod sin tener que reconstruirla.
#
# APP_VERSION la vamos a inyectar en el Dockerfile (ARG/ENV) y también la
# vamos a ver reflejada en el tag de la imagen y en el pipeline de CI/CD:
# así los alumnos pueden "seguirle el rastro" a un commit hasta el pod
# corriendo en Kubernetes.
APP_VERSION = os.getenv("APP_VERSION", "0.0.0-dev")
GREETING = os.getenv("GREETING", "Hola desde el bootcamp de DevOps!")

app = FastAPI(
    title="devops-bootcamp-demo",
    description="API demo usada en el bootcamp de DevOps/CI-CD",
    version=APP_VERSION,
)

# Registramos el middleware que instrumenta cada request con métricas
# Prometheus (ver app/metrics.py para el detalle y el porqué).
app.add_middleware(PrometheusMiddleware)


# --- Modelos ------------------------------------------------------------
class TaskIn(BaseModel):
    """Datos que recibimos del cliente para crear/actualizar una tarea."""

    title: str = Field(..., min_length=1, max_length=200, examples=["Aprender Kubernetes"])
    done: bool = False


class Task(TaskIn):
    """Una tarea ya persistida (con id asignado)."""

    id: int


# --- "Base de datos" en memoria ------------------------------------------
# ADVERTENCIA PEDAGÓGICA: esto vive en la memoria del proceso. Si el pod se
# reinicia (por un deploy, un crash, un scale-down) se pierde todo. Es una
# decisión deliberada para mantener el demo simple: el foco de este curso
# es el pipeline y la infraestructura, no la persistencia de datos.
_tasks: Dict[int, Task] = {}
_id_counter = count(start=1)


# --- Endpoints de infraestructura -----------------------------------------
@app.get("/", tags=["infra"])
def root():
    """Endpoint raíz: sirve para verificar rápidamente que la app está viva."""
    return {"message": GREETING, "version": APP_VERSION}


@app.get("/healthz", tags=["infra"])
def healthz():
    """
    Liveness probe.

    Responde a la pregunta "¿el proceso sigue vivo o está colgado?". NO
    debería depender de servicios externos (bases de datos, otras APIs):
    si dependiera de ellos, un problema en una dependencia externa haría
    que Kubernetes reinicie el pod en loop sin que eso resuelva nada
    (esto se conoce como el problema de las "liveness probes con
    dependencias externas", una trampa muy común en producción).
    """
    return {"status": "ok"}


@app.get("/readyz", tags=["infra"])
def readyz():
    """
    Readiness probe.

    Responde a la pregunta "¿puedo recibir tráfico ahora mismo?". A
    diferencia de /healthz, acá sí tendría sentido chequear dependencias
    (conexión a la base, a una cola, etc.) porque si algo no está listo,
    Kubernetes va a sacar el pod del Service (dejar de mandarle tráfico)
    sin reiniciarlo, dándole tiempo a recuperarse.

    En este demo no tenemos dependencias externas, así que siempre estamos
    "ready", pero se deja el endpoint separado de /healthz para que quede
    claro el patrón: son cosas conceptualmente distintas aunque acá
    respondan igual.
    """
    return {"status": "ready"}


@app.get("/metrics", tags=["infra"])
def metrics():
    """
    Expone las métricas en el formato de texto que Prometheus sabe
    scrapear. No usamos response_model de FastAPI acá porque el formato
    no es JSON sino el "exposition format" propio de Prometheus.
    """
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


# --- CRUD de tasks --------------------------------------------------------
@app.get("/api/tasks", response_model=list[Task], tags=["tasks"])
def list_tasks():
    """Devuelve todas las tareas, ordenadas por id."""
    return sorted(_tasks.values(), key=lambda t: t.id)


@app.post("/api/tasks", response_model=Task, status_code=status.HTTP_201_CREATED, tags=["tasks"])
def create_task(task_in: TaskIn):
    """Crea una tarea nueva y le asigna un id autoincremental."""
    task_id = next(_id_counter)
    task = Task(id=task_id, **task_in.model_dump())
    _tasks[task_id] = task
    return task


@app.get("/api/tasks/{task_id}", response_model=Task, tags=["tasks"])
def get_task(task_id: int):
    """Busca una tarea por id. Devuelve 404 si no existe."""
    task = _tasks.get(task_id)
    if task is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task no encontrada")
    return task


@app.put("/api/tasks/{task_id}", response_model=Task, tags=["tasks"])
def update_task(task_id: int, task_in: TaskIn):
    """Reemplaza los datos de una tarea existente. Devuelve 404 si no existe."""
    if task_id not in _tasks:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task no encontrada")
    task = Task(id=task_id, **task_in.model_dump())
    _tasks[task_id] = task
    return task


@app.delete("/api/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["tasks"])
def delete_task(task_id: int):
    """Borra una tarea por id. Devuelve 404 si no existe."""
    if task_id not in _tasks:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task no encontrada")
    del _tasks[task_id]
    return None
