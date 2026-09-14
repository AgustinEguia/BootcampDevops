"""
test_tasks.py
--------------
Tests del CRUD de /api/tasks.

Nota pedagógica: FastAPI crea una única instancia de la app (importada de
app.main) para todo el módulo de tests, y como las "tasks" viven en un
diccionario en memoria, el estado se comparte entre tests. Por eso el
orden de estos tests importa un poco (creamos antes de leer/actualizar/
borrar). En un proyecto real con base de datos usaríamos fixtures de
pytest que resetean el estado antes de cada test para evitar este
acoplamiento.
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_list_tasks_vacio_al_principio():
    response = client.get("/api/tasks")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_crear_task():
    response = client.post("/api/tasks", json={"title": "Aprender Docker"})
    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Aprender Docker"
    assert body["done"] is False
    assert "id" in body


def test_crear_task_titulo_vacio_falla_validacion():
    # title tiene min_length=1 en el modelo Pydantic: un string vacío
    # debe rechazarse con 422 (Unprocessable Entity), sin llegar a tocar
    # la "base de datos" en memoria.
    response = client.post("/api/tasks", json={"title": ""})
    assert response.status_code == 422


def test_obtener_task_existente():
    creada = client.post("/api/tasks", json={"title": "Aprender Helm"}).json()
    task_id = creada["id"]

    response = client.get(f"/api/tasks/{task_id}")
    assert response.status_code == 200
    assert response.json()["title"] == "Aprender Helm"


def test_obtener_task_inexistente_da_404():
    response = client.get("/api/tasks/999999")
    assert response.status_code == 404


def test_actualizar_task():
    creada = client.post("/api/tasks", json={"title": "Aprender Terraform"}).json()
    task_id = creada["id"]

    response = client.put(
        f"/api/tasks/{task_id}", json={"title": "Aprender Terraform", "done": True}
    )
    assert response.status_code == 200
    assert response.json()["done"] is True


def test_actualizar_task_inexistente_da_404():
    response = client.put("/api/tasks/999999", json={"title": "no existe"})
    assert response.status_code == 404


def test_borrar_task():
    creada = client.post("/api/tasks", json={"title": "Tarea a borrar"}).json()
    task_id = creada["id"]

    response = client.delete(f"/api/tasks/{task_id}")
    assert response.status_code == 204

    # Después de borrarla, ya no debería existir.
    response = client.get(f"/api/tasks/{task_id}")
    assert response.status_code == 404


def test_borrar_task_inexistente_da_404():
    response = client.delete("/api/tasks/999999")
    assert response.status_code == 404


def test_list_tasks_incluye_las_creadas():
    client.post("/api/tasks", json={"title": "Tarea para listar"})
    response = client.get("/api/tasks")
    assert response.status_code == 200
    titles = [t["title"] for t in response.json()]
    assert "Tarea para listar" in titles
