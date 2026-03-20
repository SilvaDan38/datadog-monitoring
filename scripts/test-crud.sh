#!/bin/bash

# ─── Configuração ─────────────────────────────────────────────
SERVICES=(
  "Python  |8001"
  "Node.js |8002"
  "Java    |8003"
  ".NET    |8004"
  "Ruby    |8005"
)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✔ $1${NC}"; }
fail() { echo -e "  ${RED}✖ $1${NC}"; }
info() { echo -e "  ${YELLOW}→ $1${NC}"; }
section() { echo -e "  ${CYAN}◆ $1${NC}"; }

# ─── Verifica se status é 5xx ──────────────────────────────────
is_5xx() {
  local STATUS=$1
  [[ "$STATUS" =~ ^5[0-9]{2}$ ]]
}

# ─── Testes de erros 5xx ──────────────────────────────────────
test_5xx() {
  local NAME=$1
  local PORT=$2
  local BASE="http://localhost:$PORT"
  local ERRORS=0

  echo ""
  section "Testes 5xx — Cenários de Erro do Servidor"

  # ── Payload inválido / corrompido ─────────────────────────
  info "5xx — POST com payload malformado (simula erro interno)"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/products" \
    -H "Content-Type: application/json" \
    -d '{INVALID_JSON:::}')
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if is_5xx "$STATUS"; then
    pass "POST /products payload inválido → $STATUS (5xx esperado)"
  elif [[ "$STATUS" == "400" ]]; then
    info "POST /products payload inválido → $STATUS (400 Bad Request — aceitável)"
  else
    fail "POST /products payload inválido → $STATUS | $BODY"
    ((ERRORS++))
  fi

  # ── Campos obrigatórios ausentes (pode causar 500 em impl. ruins) ──
  info "5xx — POST sem campos obrigatórios"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/products" \
    -H "Content-Type: application/json" \
    -d '{}')
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if is_5xx "$STATUS"; then
    fail "POST /products vazio → $STATUS (5xx — erro não tratado no servidor!)"
    ((ERRORS++))
  elif [[ "$STATUS" == "400" || "$STATUS" == "422" ]]; then
    pass "POST /products vazio → $STATUS (erro de validação tratado corretamente)"
  else
    info "POST /products vazio → $STATUS | $BODY"
  fi

  # ── ID inexistente causando erro interno ───────────────────
  info "5xx — GET /products/ID inválido (string no lugar de número)"
  RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE/products/nao-e-um-id-valido-@@@@")
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if is_5xx "$STATUS"; then
    fail "GET /products/ID-inválido → $STATUS (5xx — erro não tratado no servidor!)"
    ((ERRORS++))
  elif [[ "$STATUS" == "400" || "$STATUS" == "404" ]]; then
    pass "GET /products/ID-inválido → $STATUS (tratado corretamente)"
  else
    info "GET /products/ID-inválido → $STATUS | $BODY"
  fi

  # ── PUT em recurso com ID inválido ────────────────────────
  info "5xx — PUT /products/ID inválido"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$BASE/products/999999999999999999" \
    -H "Content-Type: application/json" \
    -d '{"name":"Teste","category":"test","price":1.0,"stock":1}')
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if is_5xx "$STATUS"; then
    fail "PUT /products/999999999999999999 → $STATUS (5xx — erro não tratado!)"
    ((ERRORS++))
  elif [[ "$STATUS" == "404" || "$STATUS" == "400" ]]; then
    pass "PUT /products/999999999999999999 → $STATUS (não encontrado, tratado corretamente)"
  else
    info "PUT /products/999999999999999999 → $STATUS | $BODY"
  fi

  # ── DELETE em recurso inexistente ─────────────────────────
  info "5xx — DELETE /products/ID inexistente"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE/products/999999999999999999")
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if is_5xx "$STATUS"; then
    fail "DELETE /products/999999999999999999 → $STATUS (5xx — erro não tratado!)"
    ((ERRORS++))
  elif [[ "$STATUS" == "404" || "$STATUS" == "204" || "$STATUS" == "200" ]]; then
    pass "DELETE /products/999999999999999999 → $STATUS (tratado corretamente)"
  else
    info "DELETE /products/999999999999999999 → $STATUS | $BODY"
  fi

  # ── Tipo de conteúdo errado ───────────────────────────────
  info "5xx — POST com Content-Type errado (text/plain)"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/products" \
    -H "Content-Type: text/plain" \
    -d 'nome=teclado&preco=100')
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)
  if is_5xx "$STATUS"; then
    fail "POST /products text/plain → $STATUS (5xx — erro não tratado!)"
    ((ERRORS++))
  elif [[ "$STATUS" == "400" || "$STATUS" == "415" || "$STATUS" == "422" ]]; then
    pass "POST /products text/plain → $STATUS (Content-Type rejeitado corretamente)"
  else
    info "POST /products text/plain → $STATUS | $BODY"
  fi

  # ── Resumo 5xx ────────────────────────────────────────────
  echo ""
  if [ "$ERRORS" -eq 0 ]; then
    echo -e "  ${GREEN}✔ $NAME — nenhum 5xx inesperado encontrado${NC}"
  else
    echo -e "  ${RED}✖ $NAME — $ERRORS erro(s) 5xx não tratado(s)${NC}"
  fi

  return $ERRORS
}

# ─── Função principal por serviço ─────────────────────────────
test_service() {
  local NAME=$1
  local PORT=$2
  local BASE="http://localhost:$PORT"
  local ERRORS=0

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BLUE}  $NAME — porta $PORT${NC}"
  echo -e "${BLUE}═══════════════════════════════════════${NC}"

  # ── Health Check ──────────────────────────────────────────
  info "Health check"
  STATUS=$(curl -sL -o /dev/null -w "%{http_code}" "$BASE/health")
  if [ "$STATUS" == "200" ]; then
    pass "GET /health → $STATUS"
  else
    fail "GET /health → $STATUS"
    ((ERRORS++))
  fi

  # ── CREATE ────────────────────────────────────────────────
  info "CREATE — POST /products"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE/products" \
    -H "Content-Type: application/json" \
    -d '{"name":"Teclado Mecânico","category":"hardware","price":299.90,"stock":50}')
  STATUS=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)

  if [[ "$STATUS" == "201" || "$STATUS" == "200" ]]; then
    pass "POST /products → $STATUS"
    ID=$(echo "$BODY" | grep -oP '"id"\s*:\s*"?\K[0-9]+' | head -1)
    info "ID criado: $ID"
  else
    fail "POST /products → $STATUS | $BODY"
    ((ERRORS++))
    ID=1
  fi

  # ── READ ALL ──────────────────────────────────────────────
  info "READ ALL — GET /products"
  STATUS=$(curl -sL -o /dev/null -w "%{http_code}" "$BASE/products")
  if [ "$STATUS" == "200" ]; then
    pass "GET /products → $STATUS"
  else
    fail "GET /products → $STATUS"
    ((ERRORS++))
  fi

  # ── READ ONE ──────────────────────────────────────────────
  info "READ ONE — GET /products/$ID"
  STATUS=$(curl -sL -o /dev/null -w "%{http_code}" "$BASE/products/$ID")
  if [ "$STATUS" == "200" ]; then
    pass "GET /products/$ID → $STATUS"
  else
    fail "GET /products/$ID → $STATUS"
    ((ERRORS++))
  fi

  # ── UPDATE ────────────────────────────────────────────────
  info "UPDATE — PUT /products/$ID"
  STATUS=$(curl -sL -o /dev/null -w "%{http_code}" -X PUT "$BASE/products/$ID" \
    -H "Content-Type: application/json" \
    -d '{"name":"Teclado Atualizado","category":"hardware","price":349.90,"stock":30}')
  if [ "$STATUS" == "200" ]; then
    pass "PUT /products/$ID → $STATUS"
  else
    fail "PUT /products/$ID → $STATUS"
    ((ERRORS++))
  fi

  # ── DELETE ────────────────────────────────────────────────
  info "DELETE — DELETE /products/$ID"
  STATUS=$(curl -sL -o /dev/null -w "%{http_code}" -X DELETE "$BASE/products/$ID")
  if [[ "$STATUS" == "200" || "$STATUS" == "204" ]]; then
    pass "DELETE /products/$ID → $STATUS"
  else
    fail "DELETE /products/$ID → $STATUS"
    ((ERRORS++))
  fi

  # ── Confirma deleção ──────────────────────────────────────
  info "Confirma deleção — GET /products/$ID"
  STATUS=$(curl -sL -o /dev/null -w "%{http_code}" "$BASE/products/$ID")
  if [ "$STATUS" == "404" ]; then
    pass "GET /products/$ID → $STATUS (deletado com sucesso)"
  else
    fail "GET /products/$ID → $STATUS (esperava 404)"
    ((ERRORS++))
  fi

  # ── Testes 5xx ────────────────────────────────────────────
  test_5xx "$NAME" "$PORT"
  ERRORS_5XX=$?
  ((ERRORS+=ERRORS_5XX))

  # ── Resumo ────────────────────────────────────────────────
  echo ""
  if [ "$ERRORS" -eq 0 ]; then
    echo -e "  ${GREEN}✔ $NAME — todos os testes passaram${NC}"
  else
    echo -e "  ${RED}✖ $NAME — $ERRORS erro(s) encontrado(s)${NC}"
  fi
}

# ─── Execução ─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     CRUD TEST — Todos os Serviços     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"

for SERVICE in "${SERVICES[@]}"; do
  NAME=$(echo $SERVICE | cut -d'|' -f1 | xargs)
  PORT=$(echo $SERVICE | cut -d'|' -f2 | xargs)
  test_service "$NAME" "$PORT"
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Teste concluído!${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""