#!/bin/bash

PORTS=(8001 8002 8003 8004 8005)
NAMES=("Python" "Node.js" "Java" ".NET" "Ruby")

for i in "${!PORTS[@]}"; do
  PORT=${PORTS[$i]}
  NAME=${NAMES[$i]}
  BASE="http://localhost:$PORT"

  echo ""
  echo "==============================="
  echo " $NAME — porta $PORT"
  echo "==============================="

  echo "→ CREATE"
  ID=$(curl -s -X POST $BASE/products \
    -H "Content-Type: application/json" \
    -d '{"name":"Produto Teste","price":99.99,"stock":10}' \
    | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
  echo "   ID criado: $ID"

  echo "→ READ ALL"
  curl -s $BASE/products | head -c 100
  echo ""

  echo "→ READ ONE"
  curl -s $BASE/products/$ID
  echo ""

  echo "→ UPDATE"
  curl -s -X PUT $BASE/products/$ID \
    -H "Content-Type: application/json" \
    -d '{"name":"Produto Atualizado","price":149.99,"stock":5}'
  echo ""

  echo "→ DELETE"
  curl -s -X DELETE $BASE/products/$ID
  echo ""
done