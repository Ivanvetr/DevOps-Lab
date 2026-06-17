# DevOps Lab — Pipeline CI/CD con seguridad y monitoreo

> Laboratorio técnico · Universidad de La Sabana · Unidad 3: Ecosistema DevOps — Herramientas para CI/CD y monitoreo

---

## Descripción del proyecto

Aplicación web en **Python/Flask** que sirve como base para un pipeline CI/CD completo,
integrando análisis de seguridad (SonarQube, Snyk), despliegue en **Kubernetes**, y
monitoreo con **Prometheus + Grafana**.

Este repositorio extiende el laboratorio de la Unidad 2 (estructura de pipelines CI/CD)
añadiendo las tres capas que pide esta unidad:
1. Integración continua con análisis de seguridad (SonarQube + Snyk).
2. Despliegue real en un clúster Kubernetes.
3. Monitoreo continuo con Prometheus y dashboards en Grafana.

---

## Estructura del repositorio

```
devops-lab/
├── .github/
│   └── workflows/
│       └── ci.yml              # CI: lint, test, SonarQube, Snyk, build
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 02-deployment.yaml      # 2 réplicas, probes, anotaciones Prometheus
│   ├── 03-service.yaml         # NodePort 30080
│   └── 04-servicemonitor.yaml  # Descubrimiento por Prometheus Operator
├── monitoring/
│   ├── grafana-dashboard.json  # Dashboard listo para importar
│   └── prometheus-scrape-config.yaml  # Alternativa sin Operator
├── scripts/
│   └── bootstrap.sh             # Levanta todo el stack en k3d con un comando
├── src/
│   └── app.py                  # App Flask + endpoint /metrics
├── tests/
│   └── test_app.py
├── Dockerfile
├── Jenkinsfile                  # CD: seguridad, build, push, despliegue K8s
├── requirements.txt
├── sonar-project.properties
└── README.md
```

---

## Flujo CI/CD completo

```
Push / PR
   │
   ▼
GitHub Actions (CI)
   ├── lint (flake8)
   ├── test (pytest, cobertura ≥80%)
   ├── security-sonarqube (análisis estático + quality gate)
   ├── security-snyk (vulnerabilidades en dependencias + imagen Docker)
   └── build-docker (verificación de imagen)
   │
   ▼  (merge a main)
Jenkins (CD)
   ├── Clonar repo
   ├── Instalar dependencias
   ├── Análisis estático (flake8)
   ├── Pruebas unitarias + cobertura
   ├── SonarQube + Quality Gate
   ├── Snyk (dependencias + imagen)
   ├── Build Docker
   ├── Push a DockerHub
   ├── Deploy a Kubernetes (kubectl apply + rollout)
   └── Verificar despliegue
   │
   ▼
Kubernetes (namespace: devops-lab)
   ├── Deployment (2 réplicas, probes de salud)
   └── Service NodePort :30080
   │
   ▼
Prometheus ── scrape /metrics cada 15s
   │
   ▼
Grafana ── dashboard con peticiones, latencia, errores, CPU, memoria, pods activos
```

---

## Herramientas y justificación

| Herramienta | Rol | Justificación |
|-------------|-----|----------------|
| GitHub Actions | CI | Integración nativa con el repo, ejecución en cada push/PR |
| Jenkins | CD | Control total de stages, integración con credenciales y plugins de seguridad |
| SonarQube | Análisis estático | Detecta code smells, bugs y vulnerabilidades; Quality Gate bloquea merges riesgosos |
| Snyk | Seguridad de dependencias | Escanea `requirements.txt` y la imagen Docker en busca de CVEs conocidos |
| Docker | Empaquetado | Imagen multi-stage, ligera y reproducible |
| Kubernetes (k3d) | Orquestación | Réplicas, autorecuperación (probes), exposición vía NodePort |
| Prometheus | Métricas | Scrapea `/metrics` (expuesto por `prometheus-flask-exporter`) |
| Grafana | Visualización | Dashboard con latencia, throughput, errores 5xx, CPU y memoria por pod |

---

## Cómo levantar todo el stack localmente (con capturas reales)

### Prerrequisitos

Instala en tu máquina (Windows con WSL2, macOS o Linux):

```bash
# Docker Desktop (con WSL2 en Windows)
# k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Levantar todo con un comando

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

Esto crea el clúster k3d, construye e importa la imagen, despliega la app,
instala `kube-prometheus-stack` (Prometheus + Grafana vía Helm) y aplica el ServiceMonitor.

### Accesos una vez levantado

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| App Flask | http://localhost:30080 | — |
| Métricas | http://localhost:30080/metrics | — |
| Prometheus | http://localhost:30090 | — |
| Grafana | http://localhost:30030 | admin / admin123 |

### Importar el dashboard en Grafana

1. Entra a Grafana (http://localhost:30030)
2. Menú lateral → **Dashboards** → **New** → **Import**
3. Sube `monitoring/grafana-dashboard.json`
4. Selecciona la fuente de datos **Prometheus** y clic en **Import**

---

## Análisis de seguridad

### SonarQube

- Configurado vía `sonar-project.properties`.
- En GitHub Actions corre con `SonarSource/sonarqube-scan-action`, requiere los secrets
  `SONAR_TOKEN` y `SONAR_HOST_URL` (puede usarse SonarCloud gratis para repos públicos).
- El Quality Gate bloquea el pipeline si no se cumplen los umbrales de calidad definidos.

### Snyk

- Escanea `requirements.txt` (vulnerabilidades en dependencias Python) y la imagen Docker
  construida (vulnerabilidades del sistema base `python:3.12-slim`).
- Requiere el secret `SNYK_TOKEN` (cuenta gratuita en snyk.io).
- Resultados con severidad `high` o mayor se reportan en el resumen del workflow.

---

## Cómo ejecutar localmente (sin Kubernetes)

```bash
pip install -r requirements.txt
python -m pytest tests/ -v --cov=src
python src/app.py
# → http://localhost:5000
# → http://localhost:5000/metrics
```

---

## Endpoints de la API

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/` | Info general de la API |
| GET | `/salud` | Health check (usado por probes de K8s) |
| GET | `/suma/<a>/<b>` | Suma dos números enteros |
| GET | `/metrics` | Métricas en formato Prometheus |

---

## Reflexión sobre eficiencia operativa

La combinación de SonarQube y Snyk en el pipeline traslada la detección de problemas
de seguridad y calidad al momento del commit, en lugar de descubrirlos en producción —
esto es el principio de "shift left" de DevSecOps. El Quality Gate de SonarQube actúa
como un punto de control automático que evita que código con vulnerabilidades críticas
o baja cobertura llegue a `main`.

Por su parte, exponer `/metrics` y conectarlo a Prometheus/Grafana cierra el ciclo de
retroalimentación: cualquier cambio desplegado es observable en tiempo real (latencia,
tasa de errores, consumo de recursos), lo que permite detectar degradaciones de
rendimiento minutos después del despliegue en lugar de a través de reportes de usuarios.

En conjunto, este pipeline reduce el tiempo entre "se introduce un problema" y
"se detecta el problema" en las tres dimensiones que importan en DevOps: calidad de
código, seguridad de dependencias, y salud operativa del sistema en producción.

---

## Referencias

- Kim, G., Humble, J., Debois, P., Willis, J. y Forsgren, N. (2022). *Manual de DevOps* (2.ª ed.). dpunkt.
- Lwakatare, L. E. et al. (2016). Relationship of DevOps to Agile, Lean and Continuous Deployment. Springer.
- Documentación oficial de Prometheus: https://prometheus.io/docs/
- Documentación oficial de Grafana: https://grafana.com/docs/
- Documentación oficial de SonarQube: https://docs.sonarsource.com/
- Documentación oficial de Snyk: https://docs.snyk.io/
