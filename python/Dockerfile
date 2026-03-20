FROM python:3.12-slim

WORKDIR /app

# Instala dependências
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Datadog APM — variáveis de ambiente padrão
ENV DD_SERVICE=python-crud
ENV DD_ENV=docker
ENV DD_VERSION=1.0.0
ENV DD_LOGS_INJECTION=true
ENV DD_TRACE_SAMPLE_RATE=1
ENV DD_PROFILING_ENABLED=true
ENV DD_RUNTIME_METRICS_ENABLED=true
# DBM — propaga query tags
ENV DD_DBM_PROPAGATION_MODE=full
# Security — habilita IAST/RASP
ENV DD_APPSEC_ENABLED=true
ENV DD_IAST_ENABLED=true

EXPOSE 8000

CMD ["ddtrace-run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]