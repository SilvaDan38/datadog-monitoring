# 🚀 Kubernetes Cluster com Datadog + CRUD Multi-Linguagens

Este guia sobe um cluster **Kind**, realiza o deploy de aplicações CRUD em várias linguagens e instala o **Datadog Agent via Helm**.

---

## 🔑 Exportar API Key do Datadog

```bash
export DD_API_KEY="suaapikeyaqui"
```

Validar:

```bash
echo $DD_API_KEY
```

---

## 🐳 Build das imagens Docker

Ir até a pasta `docker` e buildar as imagens:

```bash
cd docker
docker-compose build
```

---

## ☸️ Criar cluster com Kind

```bash
kind create cluster --config kind-cluster.yaml
```

---

## 📦 Carregar imagens no cluster

```bash
kind load docker-image docker-python-crud:latest --name datadog-cluster
kind load docker-image docker-nodejs-crud:latest --name datadog-cluster
kind load docker-image docker-java-crud:latest   --name datadog-cluster
kind load docker-image docker-dotnet-crud:latest --name datadog-cluster
kind load docker-image docker-ruby-crud:latest   --name datadog-cluster
```

Confirmar que as imagens foram carregadas:

```bash
docker exec -it datadog-cluster-worker crictl images | grep crud
```

---

## 📄 Aplicar manifestos Kubernetes

```bash
kubectl apply -f ~/datadog-monitoring/k8s/namespace.yaml
kubectl apply -f ~/datadog-monitoring/k8s/postgres/
kubectl apply -f ~/datadog-monitoring/k8s/python/
kubectl apply -f ~/datadog-monitoring/k8s/nodejs/
kubectl apply -f ~/datadog-monitoring/k8s/java/
kubectl apply -f ~/datadog-monitoring/k8s/dotnet/
kubectl apply -f ~/datadog-monitoring/k8s/ruby/
```

---

## 🌐 Port-forward dos serviços

```bash
kubectl port-forward svc/python-crud 8001:8000 -n crud-app &
kubectl port-forward svc/nodejs-crud 8002:3000 -n crud-app &
kubectl port-forward svc/java-crud   8003:8080 -n crud-app &
kubectl port-forward svc/dotnet-crud 8004:8080 -n crud-app &
kubectl port-forward svc/ruby-crud   8005:4567 -n crud-app &
```

---

## 📊 Instalar Datadog via Helm (em outro terminal)

Exportar novamente a API Key:

```bash
export DD_API_KEY="suaapikeyaqui"
```

Validar:

```bash
echo $DD_API_KEY
```

Adicionar repositório Helm:

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

Criar namespace:

```bash
kubectl create namespace datadog
```

Criar secret:

```bash
kubectl create secret generic datadog-secret \
  --from-literal api-key=$DD_API_KEY \
  -n datadog
```

Instalar chart:

```bash
helm install datadog datadog/datadog \
  -n datadog \
  -f datadog-values.yaml
```

---

## 🔎 Visualizar pods com K9s

```bash
k9s
```

Pressione:

```bash
0
```

Para visualizar todos os pods do cluster.

---

## 🧹 Deletar cluster

```bash
kind delete cluster --name datadog-cluster
```

Possíveis mensagens ao deletar:

```text
error: lost connection to pod
Deleted nodes: ["datadog-cluster-worker2" "datadog-cluster-control-plane" "datadog-cluster-worker"]

Exit 1 kubectl port-forward svc/python-crud 8001:8000 -n crud-app
Exit 1 kubectl port-forward svc/nodejs-crud 8002:3000 -n crud-app
Exit 1 kubectl port-forward svc/java-crud 8003:8080 -n crud-app
Exit 1 kubectl port-forward svc/ruby-crud 8005:4567 -n crud-app
```

Isso ocorre porque os **port-forwards são encerrados automaticamente quando o cluster é destruído**.
