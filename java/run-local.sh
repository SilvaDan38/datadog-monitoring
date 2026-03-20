#!/bin/bash
set -e

LOG_DIR="/tmp/java-crud-logs"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

echo "=== Compilando ==="
mvn package -DskipTests -q \
  -Dmaven.compiler.fork=true \
  -Dmaven.compiler.executable=$(which javac)

echo "=== Build OK — iniciando java-crud ==="
echo "=== Logs em: $LOG_DIR/app.log ==="

DD_SERVICE=java-crud \
DD_ENV=dev \
DD_VERSION=1.0.2 \
DD_LOGS_INJECTION=true \
DD_PROFILING_ENABLED=true \
DD_PROFILING_ALLOCATION_ENABLED=true \
DD_PROFILING_HEAP_ENABLED=true \
DD_RUNTIME_METRICS_ENABLED=true \
DD_DBM_PROPAGATION_MODE=full \
DD_APPSEC_ENABLED=true \
DD_IAST_ENABLED=true \
DD_DATA_STREAMS_ENABLED=true \
DD_TRACE_SAMPLE_RATE=1 \
java \
  -Ddd.service=java-crud \
  -Ddd.env=dev \
  -Ddd.version=1.0.2 \
  -Ddd.logs.injection=true \
  -Ddd.profiling.enabled=true \
  -Ddd.runtime.metrics.enabled=true \
  -Ddd.dbm.propagation.mode=full \
  -Ddd.appsec.enabled=true \
  -Ddd.iast.enabled=true \
  -Ddd.data.streams.enabled=true \
  -Ddd.trace.sample.rate=1 \
  -jar target/app.jar 2>&1 | tee "$LOG_DIR/app.log"
