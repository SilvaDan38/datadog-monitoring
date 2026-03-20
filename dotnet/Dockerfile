FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY dotnet-crud.csproj .
RUN dotnet restore dotnet-crud.csproj
COPY . .
RUN dotnet publish dotnet-crud.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# ─── Instala Datadog .NET Tracer ──────────────────────────────────────────────
ARG DD_TRACER_VERSION=2.54.0
RUN apt-get update && apt-get install -y curl && \
    curl -Lo /tmp/datadog-dotnet-apm.deb \
      https://github.com/DataDog/dd-trace-dotnet/releases/download/v${DD_TRACER_VERSION}/datadog-dotnet-apm_${DD_TRACER_VERSION}_amd64.deb && \
    dpkg -i /tmp/datadog-dotnet-apm.deb && \
    rm /tmp/datadog-dotnet-apm.deb

COPY --from=build /app/publish .

# Variáveis de ambiente Datadog
ENV DD_SERVICE=dotnet-crud
ENV DD_ENV=docker
ENV DD_VERSION=1.0.0
ENV DD_LOGS_INJECTION=true
ENV DD_RUNTIME_METRICS_ENABLED=true
ENV DD_PROFILING_ENABLED=true
ENV DD_DBM_PROPAGATION_MODE=full
ENV DD_APPSEC_ENABLED=true

# Habilita auto-instrumentação .NET
ENV CORECLR_ENABLE_PROFILING=1
ENV CORECLR_PROFILER={846F5F1C-F9AE-4B07-969E-05C26BC060D8}
ENV CORECLR_PROFILER_PATH=/opt/datadog/Datadog.Trace.ClrProfiler.Native.so
ENV DD_DOTNET_TRACER_HOME=/opt/datadog

EXPOSE 8080

ENTRYPOINT ["dotnet", "app.dll"]