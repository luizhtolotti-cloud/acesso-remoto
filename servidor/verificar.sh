#!/usr/bin/env bash
# Verifica se hbbs/hbbr estão escutando; se não, reinicia os containers.
DIR=/opt/dcl-remoto
falha=0
for p in 21115 21116 21117; do
  ss -ltn "sport = :$p" | grep -q LISTEN || { echo "$(date -Is) porta TCP $p fechada"; falha=1; }
done
ss -lun "sport = :21116" | grep -q 21116 || { echo "$(date -Is) porta UDP 21116 fechada"; falha=1; }
if [ "$falha" = 1 ]; then
  cd "$DIR" && docker compose up -d && docker compose restart
  echo "$(date -Is) serviços reiniciados"
  exit 1
fi
echo "$(date -Is) ok"
