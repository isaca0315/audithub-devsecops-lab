#!/bin/sh
# Comprobación mínima del entorno: no consulta la ruta del incidente.
set -eu

base=${1:-http://localhost:3100}
health=$(curl -fsS "$base/health")
case "$health" in
  *'"status":"ok"'*) ;;
  *) echo "health inesperado: $health" >&2; exit 1 ;;
esac
curl -fsS "$base/events" >/dev/null
echo "OK: proxy y API responden en $base"
