#!/usr/bin/env bash
set -e

# ==============================================================================
# Script de bootstrap - DevOps Lab U3
# Despliega: clúster k3d, app Flask, Prometheus, Grafana
# Requiere: docker, k3d, kubectl, helm instalados previamente
# ==============================================================================

CLUSTER_NAME="devops-lab"
NAMESPACE="devops-lab"
MONITORING_NS="monitoring"

echo ">> 1. Creando clúster k3d (si no existe)..."
if ! k3d cluster list | grep -q "${CLUSTER_NAME}"; then
    k3d cluster create "${CLUSTER_NAME}" \
        --port "30080:30080@server:0" \
        --port "30090:30090@server:0" \
        --port "30030:30030@server:0"
else
    echo "   El clúster ${CLUSTER_NAME} ya existe, se reutiliza."
fi

echo ">> 2. Construyendo imagen Docker de la app..."
docker build --target production -t devops-lab:local .

echo ">> 3. Importando imagen al clúster k3d..."
k3d image import devops-lab:local -c "${CLUSTER_NAME}"

echo ">> 4. Aplicando manifiestos de Kubernetes..."
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-deployment.yaml
kubectl apply -f k8s/03-service.yaml

# Usar la imagen local recién construida
kubectl set image deployment/devops-lab-app devops-lab=devops-lab:local -n "${NAMESPACE}"

echo ">> 5. Esperando a que el deployment esté listo..."
kubectl rollout status deployment/devops-lab-app -n "${NAMESPACE}" --timeout=120s

echo ">> 6. Instalando kube-prometheus-stack (Prometheus + Grafana)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace "${MONITORING_NS}" \
    --create-namespace \
    --set prometheus.service.type=NodePort \
    --set prometheus.service.nodePort=30090 \
    --set grafana.service.type=NodePort \
    --set grafana.service.nodePort=30030 \
    --set grafana.adminPassword=admin123 \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo ">> 7. Aplicando ServiceMonitor para la app..."
kubectl apply -f k8s/04-servicemonitor.yaml

echo ""
echo "================================================================"
echo " Listo. Accesos:"
echo "   App Flask:   http://localhost:30080"
echo "   Métricas:    http://localhost:30080/metrics"
echo "   Prometheus:  http://localhost:30090"
echo "   Grafana:     http://localhost:30030  (usuario: admin / clave: admin123)"
echo ""
echo " Para importar el dashboard en Grafana:"
echo "   1. Inicia sesión en Grafana"
echo "   2. Ve a Dashboards > New > Import"
echo "   3. Sube el archivo monitoring/grafana-dashboard.json"
echo "================================================================"
