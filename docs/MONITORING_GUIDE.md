# Guia de Monitoramento Datadog

## APM — Application Performance Monitoring

### O que é monitorado
- **Traces distribuídos** entre todos os serviços (Python → Node.js → DB, etc.)
- **Latência** de cada endpoint HTTP (P50, P75, P95, P99)
- **Taxa de erros** por serviço e endpoint
- **Throughput** (requisições/segundo)
- **Profiling contínuo** — CPU, memória, heap por função

### Como configurar

Cada linguagem usa seu próprio agente/tracer:

| Linguagem | Tracer         | Modo de injeção                        |
|-----------|----------------|----------------------------------------|
| Python    | `ddtrace`      | `ddtrace-run uvicorn main:app`         |
| Node.js   | `dd-trace`     | `node -r dd-trace/init server.js`      |
| Java      | `dd-java-agent`| `-javaagent:dd-java-agent.jar`         |
| .NET      | `Datadog.Trace`| Profiler CLR via variáveis de ambiente |
| Ruby      | `ddtrace`      | `ddtracerb exec ruby app.rb`           |

### Span customizado (exemplo Python)
```python
with tracer.trace("minha.operacao", resource="descricao") as span:
    span.set_tag("user.id", user_id)
    span.set_tag("order.value", total)
    resultado = minha_funcao()
```

### Dashboard APM
https://app.datadoghq.com/apm/services
→ Filtre por `env:local`, `env:docker` ou `env:kubernetes`

---

## DBM — Database Monitoring

### O que é monitorado
- **Queries lentas** com explain plan automático
- **Wait events** — o que está bloqueando queries
- **Conexões ativas** e pool de conexões
- **Query samples** — exemplos de queries com contexto do trace APM
- **Correlação APM ↔ DB** — clique em uma trace e veja a query exata que foi executada

### Configuração (PostgreSQL)

```yaml
# datadog.yaml — seção databases
database_monitoring:
  autodiscovery:
    enabled: true
```

A propagação de contexto APM → DB queries é feita via SQL comments:
```sql
-- Exemplo de query instrumentada pelo DBM
SELECT * FROM products
/*dddbs='postgresql',ddps='python-crud',dde='local',
  ddpv='1.0.0',traceparent='...'*/
```

Habilitar via:
```
DD_DBM_PROPAGATION_MODE=full
```

### Dashboard DBM
https://app.datadoghq.com/databases

---

## CNM — Cloud Network Monitoring

### O que é monitorado
- **Fluxos de rede** entre pods/containers/serviços
- **Latência de rede** ponto-a-ponto
- **Bytes/pacotes transferidos** por conexão
- **Conexões TCP** estabelecidas, retransmissões, timeouts
- **Mapa de dependências** de serviços (visual)

### Requisitos
- `DD_SYSTEM_PROBE_ENABLED=true`
- `DD_NETWORK_ENABLED=true`
- O container `system-probe` precisa de `SYS_ADMIN`, `NET_ADMIN`

```yaml
# No DaemonSet do Agent
- name: system-probe
  command: ["/opt/datadog-agent/embedded/bin/system-probe"]
  securityContext:
    capabilities:
      add: [SYS_ADMIN, SYS_RESOURCE, SYS_PTRACE, NET_ADMIN, IPC_LOCK]
```

### Dashboard CNM
https://app.datadoghq.com/network

---

## Security

### 3 módulos de segurança

#### 1. Application Security Management (ASM / AppSec)
- Detecta ataques em tempo real: SQL injection, XSS, SSRF, RCE, etc.
- Bloqueia requisições maliciosas (modo `blocking`)
- Integrado diretamente no tracer (sem agente separado)

```bash
DD_APPSEC_ENABLED=true
```

Para modo blocking:
```bash
DD_APPSEC_BLOCKING_ENABLED=true
```

#### 2. IAST — Interactive Application Security Testing
- Detecta vulnerabilidades no código em runtime
- Identifica: hardcoded secrets, SQL injection paths, insecure deserialization

```bash
DD_IAST_ENABLED=true
```

#### 3. Runtime Security (CSPM + CWS)
- **CWS (Cloud Workload Security)**: detecta comportamentos suspeitos em runtime
  - Acesso não autorizado a arquivos (`/etc/passwd`, `/etc/shadow`)
  - Execução de processos inesperados dentro de containers
  - Escalada de privilégios

- **CSPM (Cloud Security Posture Management)**: verifica compliance
  - CIS Benchmarks para Kubernetes, Docker, Linux
  - Verifica misconfigurations

```yaml
runtime_security_config:
  enabled: true
  fim_enabled: true  # File Integrity Monitoring
compliance_config:
  enabled: true
```

### Dashboards Security
- ASM: https://app.datadoghq.com/security/appsec
- CWS: https://app.datadoghq.com/security/workload
- CSPM: https://app.datadoghq.com/security/compliance

---

## Tags Unificadas (Unified Service Tagging)

As 3 tags obrigatórias para correlacionar APM + Logs + Métricas:

```
DD_SERVICE=python-crud   # nome do serviço
DD_ENV=production        # ambiente
DD_VERSION=1.0.0         # versão do deploy
```

No Kubernetes, use labels nos Pods:
```yaml
labels:
  tags.datadoghq.com/env:     production
  tags.datadoghq.com/service: python-crud
  tags.datadoghq.com/version: "1.0.0"
```

Isso permite:
- Ver todos os logs de uma versão específica
- Correlacionar um trace com o deploy que o gerou
- Filtrar métricas por ambiente no mesmo dashboard

---

## Checklist de Verificação

### Local
- [ ] `DD_API_KEY` configurado
- [ ] Datadog Agent rodando (`datadog-agent status`)
- [ ] Porta 8126 acessível (APM)
- [ ] Aplicação iniciada com tracer
- [ ] Trace visível em https://app.datadoghq.com/apm/services

### Docker
- [ ] `docker-compose up` sem erros
- [ ] `docker logs datadog-agent | grep "Started"`
- [ ] Serviços visíveis em https://app.datadoghq.com/infrastructure

### Kubernetes
- [ ] `kubectl get pods -n datadog-monitoring` — todos Running
- [ ] `kubectl logs -n datadog-monitoring daemonset/datadog-agent | grep "Loaded"`
- [ ] Cluster visível em https://app.datadoghq.com/infrastructure/kubernetes
