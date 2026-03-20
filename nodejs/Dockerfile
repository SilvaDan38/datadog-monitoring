FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

ENV DD_SERVICE=nodejs-crud
ENV DD_ENV=docker
ENV DD_VERSION=1.0.0
ENV DD_LOGS_INJECTION=true
ENV DD_RUNTIME_METRICS_ENABLED=true
ENV DD_PROFILING_ENABLED=true
ENV DD_DBM_PROPAGATION_MODE=full
ENV DD_APPSEC_ENABLED=true

EXPOSE 3000

CMD ["node", "-r", "dd-trace/init", "server.js"]