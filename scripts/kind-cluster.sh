#!/usr/bin/env bash
#
# kind-cluster.sh
# ------------------
# Crea un cluster de Kubernetes local con "kind" (Kubernetes IN Docker) y
# un registry local, para que los alumnos practiquen los labs de K8s/Helm
# SIN necesitar una cuenta de AWS (y sin gastar un centavo). El cluster
# resultante puede recibir todo lo de k8s/ y helm/ de este repo.
#
# Requisitos: docker, kind (https://kind.sigs.k8s.io/) y kubectl
# instalados.
#
# Uso: ./scripts/kind-cluster.sh
set -euo pipefail

CLUSTER_NAME="devops-bootcamp"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"

command -v kind    >/dev/null 2>&1 || { echo "ERROR: falta instalar 'kind'. Ver https://kind.sigs.k8s.io/docs/user/quick-start/#installation"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: falta instalar 'kubectl'."; exit 1; }
command -v docker  >/dev/null 2>&1 || { echo "ERROR: falta instalar 'docker'."; exit 1; }

# --- 1. Levantar un registry local, si todavía no existe -------------------
# kind corre los nodos del cluster como contenedores Docker. Para poder
# hacer `docker build` y usar la imagen en el cluster SIN pushear a un
# registry externo (Docker Hub, ECR), levantamos un registry Docker local
# y lo conectamos a la red de kind.
if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != "true" ]; then
  echo "==> Levantando registry local en localhost:${REGISTRY_PORT}..."
  docker run -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2
else
  echo "==> El registry local (${REGISTRY_NAME}) ya está corriendo."
fi

# --- 2. Crear el cluster kind, si todavía no existe -------------------------
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "==> Creando cluster kind '${CLUSTER_NAME}'..."
  cat <<KIND_CONFIG | kind create cluster --name "${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
# containerdConfigPatches: le dice al containerd DENTRO de los nodos de
# kind que trate a nuestro registry local como si fuera un registry
# "inseguro" (sin TLS), algo normal para desarrollo local.
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
      endpoint = ["http://${REGISTRY_NAME}:5000"]
nodes:
  - role: control-plane
    # Exponemos el puerto 80/443 del nodo hacia el host, para poder
    # acceder a Ingress sin tener que hacer port-forward manual.
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
        protocol: TCP
      - containerPort: 443
        hostPort: 8443
        protocol: TCP
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
KIND_CONFIG
else
  echo "==> El cluster kind '${CLUSTER_NAME}' ya existe."
fi

# --- 3. Conectar el registry a la red de docker de kind, si no lo está ya ---
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}")" = "null" ]; then
  docker network connect "kind" "${REGISTRY_NAME}"
fi

# --- 4. Documentar el registry local en el propio cluster --------------------
# Este ConfigMap sigue la convención documentada por el proyecto kind
# (KEP-1755) para que herramientas (y humanos) puedan descubrir
# automáticamente que hay un registry local disponible y en qué puerto.
kubectl apply -f - <<CM
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
CM

cat <<MSG

Cluster listo. Próximos pasos sugeridos para los labs de K8s:

  1. Buildear y pushear la imagen al registry local:
       docker build -t localhost:${REGISTRY_PORT}/devops-bootcamp-demo:dev .
       docker push localhost:${REGISTRY_PORT}/devops-bootcamp-demo:dev

  2. Instalar un Ingress Controller (nginx), si vas a usar k8s/base/ingress.yaml:
       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  3. Deployar con kustomize:
       kubectl apply -k k8s/overlays/dev

  4. O con Helm:
       helm upgrade --install demo-app helm/demo-app \\
         --namespace dev --create-namespace \\
         --values helm/demo-app/values-dev.yaml \\
         --set image.repository=localhost:${REGISTRY_PORT}/devops-bootcamp-demo \\
         --set image.tag=dev

Para borrar todo:
  kind delete cluster --name ${CLUSTER_NAME}
  docker rm -f ${REGISTRY_NAME}
MSG
