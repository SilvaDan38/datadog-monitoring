FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .

# Instala curl para o mvnw conseguir baixar o Maven
RUN apk add --no-cache curl
RUN ./mvnw package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Baixa o Datadog Java Agent
ADD https://dtdg.co/latest-java-tracer dd-java-agent.jar

COPY --from=builder /app/target/app.jar app.jar

# Variáveis Datadog
ENV DD_SERVICE=java-crud
ENV DD_ENV=docker
ENV DD_VERSION=1.0.0
ENV DD_LOGS_INJECTION=true
ENV DD_PROFILING_ENABLED=true
ENV DD_RUNTIME_METRICS_ENABLED=true
ENV DD_DBM_PROPAGATION_MODE=full
ENV DD_APPSEC_ENABLED=true
ENV DD_IAST_ENABLED=true

EXPOSE 8080

# As ENV já definem DD_SERVICE, DD_ENV etc.
# O agente Datadog lê essas variáveis de ambiente automaticamente
CMD ["java", "-javaagent:dd-java-agent.jar", "-jar", "app.jar"]