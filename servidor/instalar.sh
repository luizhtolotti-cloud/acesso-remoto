#!/usr/bin/env bash
# DCL Remoto — instalação do servidor em Ubuntu 22.04/24.04 ou Debian 12 (executar como root).
#
# Antes de rodar, copie as chaves geradas no PC de desenvolvimento para /opt/dcl-remoto/data:
#   scp id_ed25519 id_ed25519.pub root@SERVIDOR:/opt/dcl-remoto/data/
# O script NÃO gera chaves novas: se elas faltarem, ele para (o cliente já vem com a
# chave pública embutida e só aceita este par).
set -euo pipefail

DIR=/opt/dcl-remoto
PUB_ESPERADA="4K26EpKjUMWle4dLO7XilVKe2Gs7x93gLF80nwMV1NY="

[ "$(id -u)" = 0 ] || { echo "Execute como root."; exit 1; }
mkdir -p "$DIR/data" "$DIR/backup"
cp "$(dirname "$0")/docker-compose.yml" "$DIR/"
cp "$(dirname "$0")/backup.sh" "$(dirname "$0")/verificar.sh" "$DIR/"
chmod 700 "$DIR/data" "$DIR/backup"; chmod 755 "$DIR"/*.sh

# 1. Chaves
if [ ! -s "$DIR/data/id_ed25519" ] || [ ! -s "$DIR/data/id_ed25519.pub" ]; then
  echo "ERRO: chaves ausentes em $DIR/data (id_ed25519 e id_ed25519.pub)."; exit 1
fi
if [ "$(tr -d '\r\n' < "$DIR/data/id_ed25519.pub")" != "$PUB_ESPERADA" ]; then
  echo "ERRO: id_ed25519.pub não é a chave embutida no cliente DCL Remoto."; exit 1
fi
chmod 600 "$DIR/data/id_ed25519"

# 2. Docker (repositório oficial)
if ! command -v docker >/dev/null; then
  apt-get update -y
  apt-get install -y ca-certificates curl
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

# 3. Firewall
if command -v ufw >/dev/null || apt-get install -y ufw; then
  ufw allow OpenSSH
  ufw allow 21115:21117/tcp comment 'DCL Remoto hbbs/hbbr'
  ufw allow 21116/udp      comment 'DCL Remoto hbbs NAT/punch'
  ufw allow 21118:21119/tcp comment 'DCL Remoto websocket'
  ufw --force enable
fi

# 4. Serviço
cd "$DIR"
docker compose pull
docker compose up -d

# 5. Backup diário (03:15) e verificação a cada 5 min (reinicia se cair)
cat > /etc/cron.d/dcl-remoto <<CRON
15 3 * * * root $DIR/backup.sh >> /var/log/dcl-remoto-backup.log 2>&1
*/5 * * * * root $DIR/verificar.sh >> /var/log/dcl-remoto-verificar.log 2>&1
CRON

sleep 3
"$DIR/verificar.sh"
echo "Instalação concluída. Logs: docker logs dcl-hbbs / docker logs dcl-hbbr"
