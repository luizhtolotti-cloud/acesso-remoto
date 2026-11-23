# Servidor DCL Remoto

rustdesk-server OSS **1.1.16** (hbbs + hbbr), imagem Docker oficial fixada por digest.

| Item | Valor |
|---|---|
| Endereço | `remoto.dclassistencia.com.br` |
| Chave pública (embutida no cliente) | `4K26EpKjUMWle4dLO7XilVKe2Gs7x93gLF80nwMV1NY=` |
| Chave privada | **não está no repositório**; gerada com `gerar_chaves.py`, guardada fora do Git |
| Exigência de chave | `-k _` em hbbs e hbbr: só clientes com esta chave registram/usam relay |

## Portas
| Porta | Protocolo | Uso |
|---|---|---|
| 21115 | TCP | hbbs: teste de NAT |
| 21116 | TCP + **UDP** | hbbs: registro de ID e hole punching |
| 21117 | TCP | hbbr: relay |
| 21118, 21119 | TCP | WebSocket (opcional) |

## Requisitos da máquina
- IP público fixo **sem CGNAT** (VPS é o mais simples). 1 vCPU / 1 GB RAM bastam para começar; o
  consumo cresce com sessões em relay (banda).
- Ubuntu 22.04/24.04 ou Debian 12.

## Implantação
1. **DNS (Locaweb → Zona DNS de dclassistencia.com.br):** criar registro `A` `remoto` → IP do servidor
   (TTL 3600). Não mexer em `www`, `@` nem MX.
2. Copiar a pasta `servidor/` e as chaves:
   ```
   scp -r servidor root@IP:/root/dcl-servidor
   ssh root@IP mkdir -p /opt/dcl-remoto/data
   scp C:\dev\fork\segredos\servidor\id_ed25519* root@IP:/opt/dcl-remoto/data/
   ```
3. `ssh root@IP bash /root/dcl-servidor/instalar.sh`
   - instala Docker, abre firewall (ufw), sobe os containers, agenda backup diário e
     verificação a cada 5 min (reinicia se uma porta cair).
   - recusa rodar se a chave pública não for a embutida no cliente.
4. Conferir: `docker logs dcl-hbbs` deve mostrar `Key: 4K26EpKj...`.

## Operação
- Logs: `docker logs -f dcl-hbbs`, `docker logs -f dcl-hbbr` (rotação 5×20 MB).
- Backups: `/opt/dcl-remoto/backup/` (30 dias). **Copiar periodicamente para fora do servidor.**
- Atualização controlada: trocar a tag/digest em `docker-compose.yml`, testar, `docker compose up -d`.
- Mais relays: outro hbbr com a mesma chave em outra máquina e acrescentar em `-r` do hbbs.

## Se a chave privada vazar ou se perder
Gerar novo par, atualizar `res/produto/produto.json`, recompilar e **reinstalar todos os clientes**.
Por isso: backup fora do servidor e acesso restrito.
