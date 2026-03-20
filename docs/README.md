# 🐶 Datadog Monitoring — Multi-Language CRUD Application

Aplicação CRUD completa com monitoramento Datadog em **5 linguagens**, suportando execução **local**, **Docker** e **Kubernetes**.

## 📦 Stack de Monitoramento

| Módulo | Descrição |
|--------|-----------|
| **APM** | Application Performance Monitoring — traces, spans, latências |
| **DBM** | Database Monitoring — queries SQL, slow queries, explain plans |
| **CNM** | Cloud Network Monitoring — tráfego de rede entre serviços |
| **Security** | Runtime Security (CSPM/SIEM) — detecção de ameaças em tempo real |

## 🗂️ Estrutura do Projeto

```
datadog-monitoring/
├── python/              # FastAPI + SQLAlchemy + ddtrace
├── nodejs/              # Express + Sequelize + dd-trace
├── java/                # Spring Boot + dd-java-agent
├── dotnet/              # ASP.NET Core + Datadog.Trace
├── ruby/                # Sinatra + ActiveRecord + ddtrace
├── docker/              # docker-compose.yml (todas as linguagens)
├── kubernetes/          # Manifests K8s com Datadog Agent
└── docs/                # Guias detalhados
```

## 🚀 Quick Start

### Pré-requisitos

- Docker + Docker Compose
- Conta Datadog com API Key
- `DD_API_KEY` configurado

```bash
export DD_API_KEY="sua-api-key-aqui"
export DD_SITE="datadoghq.com"  # ou datadoghq.eu
```

---

## 🐍 Python (FastAPI)

```bash
cd python
pip install -r requirements.txt
DD_SERVICE=python-crud DD_ENV=local ddtrace-run uvicorn main:app --reload
```

**Endpoints:** `GET/POST/PUT/DELETE /products`

---

## 🟢 Node.js (Express)

```bash
cd nodejs
npm install
DD_SERVICE=nodejs-crud DD_ENV=local node -r dd-trace/init server.js
```

---

## ☕ Java (Spring Boot)

```bash
cd java
./mvnw package
java -javaagent:dd-java-agent.jar \
     -Ddd.service=java-crud \
     -Ddd.env=local \
     -jar target/app.jar
```

---

## 🔷 .NET (ASP.NET Core)

```bash
cd dotnet
dotnet run
# Datadog.Trace configurado via appsettings.json
```

---

## 💎 Ruby (Sinatra)

```bash
cd ruby
bundle install
DD_SERVICE=ruby-crud DD_ENV=local ddtracerb exec ruby app.rb
```

---

## 🐳 Docker Compose

```bash
cd docker
docker-compose up --build
```

Serviços disponíveis:
- Python:  http://localhost:8001
- Node.js: http://localhost:8002
- Java:    http://localhost:8003
- .NET:    http://localhost:8004
- Ruby:    http://localhost:8005
- Datadog Agent: porta 8126 (APM), 8125 (StatsD)

---

## ☸️ Kubernetes

```bash
# Aplicar namespace e secrets
kubectl apply -f kubernetes/namespace.yaml
kubectl create secret generic datadog-secret \
  --from-literal=api-key=$DD_API_KEY \
  -n datadog-monitoring

# Deploy do Datadog Agent (DaemonSet)
kubectl apply -f kubernetes/datadog-agent.yaml

# Deploy das aplicações
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/

# Verificar status
kubectl get pods -n datadog-monitoring
```

---

## 🔍 Verificando o Monitoramento

### APM — Traces
- Acesse: https://app.datadoghq.com/apm/services
- Filtre por `env:local` ou `env:docker` ou `env:kubernetes`

### DBM — Database
- Acesse: https://app.datadoghq.com/databases
- Veja queries lentas, explain plans e conexões ativas

### CNM — Network
- Acesse: https://app.datadoghq.com/network
- Veja fluxos entre pods/containers

### Security
- Acesse: https://app.datadoghq.com/security
- Eventos de runtime, CSPM findings

---

## 🏷️ Tags Padrão Utilizadas

```
env: local | docker | kubernetes
service: python-crud | nodejs-crud | java-crud | dotnet-crud | ruby-crud
version: 1.0.0
db.system: postgresql
```
