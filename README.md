# DevOps Lab — Pipeline CI/CD

> Laboratorio técnico · Universidad de La Sabana · Unidad 2: Flujos de entrega eficientes

---

## Descripción del proyecto

Aplicación web minimalista en **Python/Flask** que sirve como base para demostrar la implementación
de pipelines de **Integración Continua (CI)** con GitHub Actions y **Entrega Continua (CD)** con Jenkins.

El proyecto cubre las tres fases del laboratorio técnico:
1. Estructura de pipelines CI/CD con código alojado en GitHub.
2. Implementación en un clúster Kubernetes (fase posterior).
3. Habilitación de conectores de seguridad y monitoreo (fase posterior).

---

## Estructura del repositorio

```
devops-lab/
├── .github/
│   └── workflows/
│       └── ci.yml              # Pipeline CI con GitHub Actions
├── src/
│   └── app.py                  # Aplicación Flask
├── tests/
│   └── test_app.py             # Pruebas unitarias con pytest
├── Dockerfile                  # Imagen multi-stage (test + production)
├── Jenkinsfile                 # Pipeline CD con Jenkins
├── requirements.txt            # Dependencias Python
└── README.md
```

---

## Flujo CI/CD

```
Push / PR  →  GitHub Actions CI
                 ├── lint (flake8)
                 ├── test (pytest + cobertura ≥80%)
                 └── build Docker (verificación)

Merge a main  →  Jenkins CD
                     ├── Clonar repo
                     ├── Instalar dependencias
                     ├── Análisis estático
                     ├── Pruebas unitarias
                     ├── Construir imagen Docker
                     ├── Publicar en DockerHub
                     └── Limpieza local
```

---

## Pipeline A: CI con GitHub Actions (`.github/workflows/ci.yml`)

Se activa automáticamente en cada **push** a `main`/`develop` y en cada **pull request** a `main`.

### Stages

| # | Stage | Herramienta | Descripción |
|---|-------|-------------|-------------|
| 1 | Checkout | `actions/checkout@v4` | Descarga el código fuente |
| 2 | Setup Python | `actions/setup-python@v5` | Configura Python 3.12 con caché de pip |
| 3 | Instalar dependencias | `pip` | Instala `requirements.txt` |
| 4 | Análisis estático | `flake8` | Verifica estilo y calidad del código |
| 5 | Pruebas + cobertura | `pytest` + `pytest-cov` | Ejecuta tests, falla si cobertura < 80% |
| 6 | Build Docker | `docker/build-push-action@v5` | Construye la imagen sin publicarla |

### Herramientas seleccionadas

- **GitHub Actions**: integración nativa con el repositorio, sin infraestructura adicional.
- **flake8**: análisis estático ligero, fácil de configurar con `--max-line-length`.
- **pytest-cov**: reporte de cobertura con umbral configurable (`--cov-fail-under`).
- **Docker Buildx**: construcción multi-plataforma con caché de capas.

---

## Pipeline B: CD con Jenkins (`Jenkinsfile`)

Diseñado para ejecutarse en un servidor Jenkins con acceso a Docker y credenciales de DockerHub.

### Stages

| # | Stage | Descripción |
|---|-------|-------------|
| 1 | Clonar repositorio | `checkout scm` + log de commits recientes |
| 2 | Instalar dependencias | Entorno virtual Python (`venv`) |
| 3 | Análisis estático | `flake8` sobre `src/` y `tests/` |
| 4 | Pruebas unitarias | `pytest` con cobertura XML |
| 5 | Construir imagen Docker | `docker build --target production` con etiquetas de versión |
| 6 | Publicar en DockerHub | `docker push` (solo en rama `main`) |
| 7 | Verificar imagen | Inspección del manifest publicado |
| 8 | Limpieza | Elimina imágenes locales y limpia workspace |

### Credenciales requeridas en Jenkins

```
ID: dockerhub-credentials
Tipo: Username with password
Usuario: ivanvetr
Password: <Docker Hub access token>
```

---

## Dockerfile — Imagen multi-stage

```dockerfile
# Stage 1: base — instala dependencias
FROM python:3.12-slim AS base

# Stage 2: test — ejecuta pruebas durante build
FROM base AS test

# Stage 3: production — imagen liviana solo con código de app
FROM base AS production
```

La imagen de producción no contiene pytest ni flake8, reduciendo la superficie de ataque y el tamaño.

---

## Cómo ejecutar localmente

### 1. Prerequisitos

- Python 3.12+
- Docker 24+

### 2. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 3. Ejecutar pruebas

```bash
python -m pytest tests/ -v --cov=src
```

### 4. Levantar la app

```bash
python src/app.py
# → http://localhost:5000
```

### 5. Construir y ejecutar con Docker

```bash
docker build --target production -t devops-lab:local .
docker run -p 5000:5000 devops-lab:local
```

---

## Endpoints de la API

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/` | Info general de la API |
| GET | `/salud` | Health check (usado por K8s) |
| GET | `/suma/<a>/<b>` | Suma dos números enteros |

---

## Justificación de herramientas

| Herramienta | Rol en el ciclo DevOps | Justificación |
|-------------|------------------------|---------------|
| GitHub Actions | CI | Integración nativa, marketplace extenso, sin infraestructura propia |
| Jenkins | CD | Control total del pipeline, ideal para despliegues complejos |
| Docker | Empaquetado | Portabilidad garantizada entre entornos dev/staging/prod |
| DockerHub | Registro | Registro público gratuito, ampliamente soportado |
| pytest + flake8 | Calidad | Estándar de facto en Python, fácil de integrar en pipelines |
| Kubernetes (próxima fase) | Orquestación | Escalabilidad horizontal, declarativo, autorecuperación |

---

## Referencias

- Kim, G., Humble, J., Debois, P., Willis, J. y Forsgren, N. (2022). *Manual de DevOps* (2.ª ed.). dpunkt.
- Lwakatare, L. E. et al. (2016). Relationship of DevOps to Agile, Lean and Continuous Deployment. Springer.
- Turnbull, J. (2014). *The Docker Book*. Turnbull Press.
- Documentación oficial GitHub Actions: https://docs.github.com/en/actions
- Documentación oficial Jenkins Pipeline: https://www.jenkins.io/doc/book/pipeline/
