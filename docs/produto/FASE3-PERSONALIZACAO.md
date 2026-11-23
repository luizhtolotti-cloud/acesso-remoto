# FASE 3 — Personalização DCL Remoto

## Mecanismo
`src/produto.rs` aplica `res/produto/produto.json` na inicialização, reaproveitando o código de
"cliente personalizado" do upstream (`apply_custom_client_data`, separado de `read_custom_client`).
`custom.txt` externo é ignorado. Mudanças em arquivos do upstream ficaram em poucas linhas, todas
marcadas com o comentário `DCL Remoto`:

| Arquivo | Mudança |
|---|---|
| `src/common.rs` | `load_custom_client` chama `produto::aplicar`; separa verificação/aplicação; bloqueia consulta de versão em api.rustdesk.com |
| `src/updater.rs` | `check_update` não roda fora do RustDesk oficial |
| `src/lang.rs` | textos trocam "RustDesk" por "DCL Remoto" |
| `src/flutter.rs`, `src/core_main.rs` | título da janela principal "DCL Remoto" (runner localiza a janela por ele) |
| `flutter/lib/common.dart` | cores do tema; `kNomeExibicao` nos títulos de janela |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | tela Sobre: crédito ao RustDesk, AGPL-3.0, link do código-fonte |
| `Cargo.toml`, `libs/portable/Cargo.toml`, `flutter/windows/runner/Runner.rc` | metadados do executável |
| `res/*.png`, `res/*.ico`, `flutter/assets/*` | ícones e logo gerados por `res/produto/gerar_icones.py` (provisórios) |

## Configuração travada (override-settings)
- Servidor `remoto.dclassistencia.com.br` (ID e relay) e chave pública própria; aba de servidor oculta.
- `allow-hide-cm = N`: a janela que mostra a sessão ativa nunca pode ser escondida.
- Sem atualização automática / consulta de versão.
- `allow-remote-config-modification = N`.
- Padrões: aceitar por senha **ou** clique; senha temporária e permanente; descoberta na LAN desligada.

## Nomes
- Exibido: **DCL Remoto**. Interno: **DCL-Remoto** (serviço do Windows, `%APPDATA%\DCL-Remoto`,
  URI `dcl-remoto://`) — espaço quebraria `sc create` e o esquema de URI.
- Binário interno continua `rustdesk.exe` (descrição do processo: "DCL Remoto - Acesso Remoto").
  Distribuído como `DCL-Remoto-portatil-x64.exe`.

## Validado (run 45216883538, 23/11/2026, Windows 11)
- ProductName "DCL Remoto", CompanyName "DCL", copyright com crédito ao RustDesk.
- Janela principal com título "DCL Remoto"; configuração criada em `%APPDATA%\DCL-Remoto`.
- SHA-256 do portátil confere.
- Não verificado visualmente: logo, tela Sobre (sem captura de tela).
