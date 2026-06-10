import sys
import os
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from app import app  # noqa: E402


@pytest.fixture
def cliente():
    app.config["TESTING"] = True
    with app.test_client() as cliente:
        yield cliente


def test_home_retorna_200(cliente):
    respuesta = cliente.get("/")
    assert respuesta.status_code == 200


def test_home_tiene_version(cliente):
    respuesta = cliente.get("/")
    datos = respuesta.get_json()
    assert "version" in datos
    assert datos["version"] == "1.0.0"


def test_salud_retorna_ok(cliente):
    respuesta = cliente.get("/salud")
    assert respuesta.status_code == 200
    datos = respuesta.get_json()
    assert datos["estado"] == "saludable"


def test_suma_correcta(cliente):
    respuesta = cliente.get("/suma/3/7")
    assert respuesta.status_code == 200
    datos = respuesta.get_json()
    assert datos["resultado"] == 10


def test_suma_numeros_grandes(cliente):
    respuesta = cliente.get("/suma/100/200")
    assert respuesta.status_code == 200
    datos = respuesta.get_json()
    assert datos["resultado"] == 300
