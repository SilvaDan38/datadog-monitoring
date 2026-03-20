# Datadog Monitoring Lab 🚀

Projeto de homelab focado em **Observability**, utilizando **Docker Compose**, **multi-language microservices** e **Datadog APM**.

Este lab simula um ambiente de microserviços em produção para estudo de:

* Monitoramento distribuído
* Tracing (APM)
* Geração de tráfego e testes
* Observabilidade em containers
* Integração com PostgreSQL

---

## 🧠 Arquitetura do Lab

O ambiente sobe múltiplos serviços CRUD escritos em diferentes linguagens:

* Python
* NodeJS
* Java
* .NET
* Ruby

Todos integrados com:

* Datadog Agent
* PostgreSQL
* Docker Network compartilhada

---

## ⚙️ Pré-requisitos

Antes de iniciar, garanta que você possui:

* Docker Desktop instalado
* WSL2 habilitado
* Docker Compose disponível
* Conta no Datadog

No Docker Desktop:

```
Settings → General → Use the WSL 2 based engine (habilitado)
```

---

## 🔐 Configuração da API Key do Datadog

No terminal Linux (WSL):

```
export DD_API_KEY="SUA_API_KEY_AQUI"
echo $DD_API_KEY
```

---

## 🐳 Subindo o ambiente

Na pasta do projeto:

```
docker compose up -d
```

Isso irá criar:

* Network compartilhada
* Volume PostgreSQL
* Containers das aplicações
* Datadog Agent

---

## ✅ Verificar status dos containers

```
docker compose ps -a
```

Todos os serviços devem estar com status **Up** ou **Healthy**.

---

## 🔥 Gerar tráfego nas aplicações

Entre na pasta de scripts:

```
cd scripts
chmod +x *.sh
```

Execute os testes:

```
./test-crud.sh
./testa-tudo.sh
```

Esses scripts simulam carga nas aplicações para geração de métricas e traces.

---

## 📊 Visualizar no Datadog

Após gerar tráfego, acesse o Datadog:

* APM → Services
* APM → Traces
* Metrics → Containers

Você poderá visualizar:

* Latência entre serviços
* Throughput
* Dependências
* Erros
* Database calls

---

## 🎯 Objetivo do Projeto

Este laboratório tem como objetivo estudar:

* Observabilidade em arquitetura distribuída
* Instrumentação de aplicações
* Monitoramento em Kubernetes/Docker
* Troubleshooting de performance
* Boas práticas de SRE

---

## 🧪 Próximos passos (evolução do lab)

* Deploy em Kubernetes
* Dashboards customizados
* Alertas automáticos
---

## 👨‍💻 Autor

Powered by Danilo Silva - Especialista em Observabilidade - Pré-Sales Engineer Datadog
