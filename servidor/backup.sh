#!/usr/bin/env bash
# Backup de chaves e banco de IDs (db_v2.sqlite3). Mantém 30 dias.
# IMPORTANTE: copie também os backups para fora do servidor (a chave privada é insubstituível:
# se ela se perder, todos os clientes instalados precisam ser reinstalados).
set -euo pipefail
DIR=/opt/dcl-remoto
ARQ="$DIR/backup/dcl-remoto-$(date +%Y%m%d-%H%M).tar.gz"
# sqlite consistente: cópia via .backup se o sqlite3 existir, senão cópia simples
TMP=$(mktemp -d)
cp "$DIR/data/id_ed25519" "$DIR/data/id_ed25519.pub" "$TMP/"
if command -v sqlite3 >/dev/null && [ -f "$DIR/data/db_v2.sqlite3" ]; then
  sqlite3 "$DIR/data/db_v2.sqlite3" ".backup '$TMP/db_v2.sqlite3'"
elif [ -f "$DIR/data/db_v2.sqlite3" ]; then
  cp "$DIR/data/db_v2.sqlite3" "$TMP/"
fi
tar -czf "$ARQ" -C "$TMP" .
chmod 600 "$ARQ"
rm -rf "$TMP"
find "$DIR/backup" -name 'dcl-remoto-*.tar.gz' -mtime +30 -delete
echo "$(date -Is) backup ok: $ARQ"
