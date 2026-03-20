#!/bin/bash
# test-errors.sh — gera tráfego com erros 4xx e 5xx para o Datadog

BASE_URL="${1:-http://localhost:8080}"
DELAY=0.5

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[TEST]${NC} $1"; }
ok()    { echo -e "${GREEN}[2xx]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[4xx]${NC}  $1"; }
error() { echo -e "${RED}[5xx]${NC}  $1"; }
sep()   { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

call() {
  local METHOD=$1
  local URL=$2
  local BODY=$3
  local DESC=$4

  if [ -n "$BODY" ]; then
    STATUS=$(curl -s -o /tmp/dd_resp.json -w "%{http_code}" \
      -X "$METHOD" "$URL" \
      -H "Content-Type: application/json" \
      -d "$BODY")
  else
    STATUS=$(curl -s -o /tmp/dd_resp.json -w "%{http_code}" \
      -X "$METHOD" "$URL")
  fi

  BODY_RESP=$(cat /tmp/dd_resp.json 2>/dev/null)

  if [[ $STATUS -ge 500 ]]; then
    error "[$STATUS] $METHOD $URL — $DESC"
    echo "         Response: $BODY_RESP"
  elif [[ $STATUS -ge 400 ]]; then
    warn  "[$STATUS] $METHOD $URL — $DESC"
    echo "         Response: $BODY_RESP"
  elif [[ $STATUS -ge 200 ]]; then
    ok    "[$STATUS] $METHOD $URL — $DESC"
  fi
  sleep $DELAY
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Datadog Error Testing — java-crud      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo -e "Target: ${YELLOW}$BASE_URL${NC}\n"

# ─── 1. Health check ──────────────────────────────────────────────────────────
sep
log "1. Health Check"
call GET "$BASE_URL/health" "" "health check"

# ─── 2. Cria produtos válidos (2xx) ───────────────────────────────────────────
sep
log "2. Criando produtos validos (201)"
call POST "$BASE_URL/products" \
  '{"name":"Notebook","price":4999.90,"category":"eletronicos","stock":10}' \
  "produto valido"

call POST "$BASE_URL/products" \
  '{"name":"Mouse","price":199.90,"category":"eletronicos","stock":50}' \
  "produto valido"

call POST "$BASE_URL/products" \
  '{"name":"Teclado","price":299.90,"category":"eletronicos","stock":30}' \
  "produto valido"

# ─── 3. Erros 400 / 422 — payload invalido ────────────────────────────────────
sep
log "3. Erros 4xx — payload invalido"

call POST "$BASE_URL/products" \
  '{}' \
  "400 - body vazio sem campos obrigatorios"

call POST "$BASE_URL/products" \
  '{"name":"","price":-1}' \
  "400 - nome vazio e preco negativo"

call POST "$BASE_URL/products" \
  'invalid json' \
  "400 - JSON malformado"

call POST "$BASE_URL/products" \
  '{"name":"Produto sem preco"}' \
  "400 - preco ausente"

# ─── 4. Erros 404 — recurso nao encontrado ────────────────────────────────────
sep
log "4. Erros 404 — recurso nao encontrado"

call GET    "$BASE_URL/products/99999"  "" "404 - produto inexistente"
call PUT    "$BASE_URL/products/99999"  '{"price":100}' "404 - update produto inexistente"
call DELETE "$BASE_URL/products/99999"  "" "404 - delete produto inexistente"
call GET    "$BASE_URL/produtos"        "" "404 - rota inexistente (typo)"
call GET    "$BASE_URL/products/abc"    "" "404/400 - ID nao numerico"

# ─── 5. Erros 405 — metodo nao permitido ─────────────────────────────────────
sep
log "5. Erros 405 — metodo nao permitido"

call PATCH  "$BASE_URL/products/1"   '{"price":100}' "405 - PATCH nao implementado"
call DELETE "$BASE_URL/products"     "" "405 - DELETE em colecao"

# ─── 6. Operacoes validas (2xx) ───────────────────────────────────────────────
sep
log "6. Operacoes validas — GET, PUT, DELETE"

call GET    "$BASE_URL/products"     "" "200 - lista todos"
call GET    "$BASE_URL/products/1"   "" "200 - busca por ID"
call PUT    "$BASE_URL/products/1"   '{"price":4599.90,"stock":8}' "200 - update valido"
call GET    "$BASE_URL/products/1"   "" "200 - confirma update"
call DELETE "$BASE_URL/products/3"   "" "200 - delete valido"
call GET    "$BASE_URL/products/3"   "" "404 - confirma delete"

# ─── 7. Flood de erros 404 para gerar volume no Datadog ──────────────────────
sep
log "7. Flood de 404s para gerar volume no APM"
for i in {100..115}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products/$i")
  echo -ne "  ${YELLOW}[$STATUS]${NC} GET /products/$i  \r"
  sleep 0.1
done
echo ""

# ─── 8. Flood de requests validos ────────────────────────────────────────────
sep
log "8. Flood de 200s para gerar throughput"
for i in {1..20}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products")
  echo -ne "  ${GREEN}[$STATUS]${NC} GET /products  \r"
  sleep 0.1
done
echo ""

# ─── Resumo ───────────────────────────────────────────────────────────────────
sep
echo ""
echo -e "${GREEN}Testes concluidos!${NC}"
echo ""
echo -e "Verifique no Datadog:"
echo -e "  APM Traces:  ${YELLOW}https://app.datadoghq.com/apm/traces${NC}"
echo -e "  APM Service: ${YELLOW}https://app.datadoghq.com/apm/services/java-crud${NC}"
echo -e "  Errors:      ${YELLOW}https://app.datadoghq.com/apm/services/java-crud?env=local${NC}"
echo ""
echo -e "Filtros uteis no APM:"
echo -e "  status:error          — apenas traces com erro"
echo -e "  http.status_code:404  — apenas 404s"
echo -e "  http.status_code:5*   — apenas 5xx"
echo ""