# FASE 1 — Auditoria do RustDesk para o fork Windows

Data: 23/11/2026 · Código analisado em `C:\dev\fork\` (clonado nesta sessão)

| Repositório | Versão escolhida | Commit |
|---|---|---|
| rustdesk/rustdesk | **1.5.3** (estável, 09/11/2026) | `95cca3f6` + submódulo `hbb_common` `fae47e02` |
| rustdesk/rustdesk-server | **1.1.16** (estável, 20/07/2026) | submódulo `hbb_common` `83419b65` |

**Por que 1.5.3:** é o último patch da linha 1.5 (1.5.0 → 1.5.1 → 1.5.3, só correções). A 1.4.9 é mais antiga e perderia as correções de segurança do atualizador verificado (`src/platform/windows/verified_update.rs`) e do controle de tentativas de senha. Fixamos o fork nessa tag e só incorporamos tags futuras por merge controlado.

> **O que foi feito de verdade nesta fase:** clone das duas tags com submódulos e leitura do código. **Nada foi compilado ainda** — este PC não tem Rust, Flutter, LLVM, vcpkg nem Visual Studio Build Tools (verificado). Espaço livre em C: = **38,5 GB**, o que é apertado para um build local completo (ver Riscos).

---

## 1. Estrutura do projeto

```
rustdesk/
├─ src/                  Núcleo Rust (biblioteca librustdesk.dll)
│  ├─ client.rs, client/        lado TÉCNICO: conexão, vídeo, input, arquivos
│  ├─ server.rs, server/        lado CLIENTE (máquina acessada)
│  │  ├─ connection.rs          autenticação, permissões, sessão (≈ coração da segurança)
│  │  ├─ login_failure_check.rs bloqueio por tentativas
│  │  ├─ video_service.rs, display_service.rs   captura e multi-monitor
│  │  ├─ input_service.rs, clipboard_service.rs
│  │  └─ portable_service.rs    elevação na versão portátil
│  ├─ rendezvous_mediator.rs    registro no hbbs, NAT punch, fallback relay
│  ├─ ipc.rs                    comunicação serviço ↔ UI ↔ gerenciador de conexão (CM)
│  ├─ platform/windows.rs       instalação, serviço Windows, registro, atalhos
│  ├─ platform/windows/         instalador embutido, atualização verificada, ACL
│  ├─ updater.rs, update_*      atualização automática (aponta para rustdesk.com)
│  ├─ custom_server.rs          servidor via nome do .exe
│  ├─ lang/*.rs                 46 idiomas (pt_PT, ptbr)
│  ├─ flutter_ffi.rs            API exposta à UI Flutter
│  └─ ui/                       UI antiga Sciter (NÃO usaremos)
├─ libs/
│  ├─ hbb_common/   (submódulo) config, protocolo protobuf, criptografia, senhas
│  ├─ scrap/        captura de tela + codecs (VP8/VP9/AV1/H264/H265 por hardware)
│  ├─ enigo/        injeção de teclado/mouse
│  ├─ clipboard/    clipboard incluindo cópia de arquivos
│  ├─ virtual_display/, remote_printer/, portable/ (empacotador do exe portátil)
├─ flutter/         UI desktop (Dart) — é a interface que vamos personalizar
│  ├─ lib/desktop/pages/   desktop_home_page, connection_page, remote_page,
│  │                       file_manager_page, server_page (janela do cliente/CM), settings
│  ├─ lib/common/, lib/models/
│  └─ windows/runner/      executável nativo Win32 (Runner.rc, main.cpp, ícone)
├─ res/             ícones, logos, MSI (WiX, res/msi), portas vcpkg corrigidas
├─ build.py         script oficial de build
└─ .github/workflows/flutter-build.yml   receita de build Windows de referência
```

## 2. Arquitetura

```
 TÉCNICO (Flutter UI → librustdesk.dll)            CLIENTE (serviço SYSTEM + UI + CM)
        │  1. pergunta "onde está o ID X?"                │  registra ID + chave pública
        └──────────► hbbs (21115-21116 TCP/UDP) ◄─────────┘
                        │ 2. tenta hole-punch (P2P direto, TCP/UDP)
                        │ 3. se falhar → ambos vão ao hbbr (21117)
                        ▼
                     hbbr (relay)
 Criptografia: troca de chaves Curve25519 + assinatura Ed25519 do servidor (RS_PUB_KEY),
 sessão com secretbox (libsodium). Já existe — não vamos criar criptografia própria.
```

Processos no Windows instalado: `rustdesk.exe --service` (serviço, SYSTEM) → `--server` (captura/entrada na sessão do usuário) → `--cm` (janela "Gerenciador de conexão", que mostra quem está conectado e permite desconectar) + UI principal. Tudo é o mesmo executável com argumentos diferentes.

## 3. Módulos por funcionalidade pedida

| Funcionalidade | Onde está | Situação |
|---|---|---|
| ID e senha temporária | `hbb_common/src/password_security.rs`, `config.rs` | **Existe**. Rotação automática após falhas (`connection.rs:2574`) |
| Senha permanente (não assistido) | `password_security.rs`, `connection.rs:2544` (`validate_password_storage`) | **Existe**, armazenada criptografada (`encrypt_str_or_original`) |
| Aceitar/recusar conexão | `approve_mode()` + `server_page.dart` (CM) | **Existe** (modo clique / senha / ambos) |
| Proteção contra força bruta | `server/login_failure_check.rs` | **Existe** |
| Serviço Windows | `platform/windows.rs:3443 install_service`, `:4101 sc create` | **Existe** |
| Instalador / desinstalador | `platform/windows.rs:1628 install_me`, `:1914 uninstall_me`; MSI em `res/msi` | **Existe** |
| Portátil | `libs/portable`, `build.py --portable` | **Existe** |
| Transferência de arquivos | `client/io_loop.rs`, `file_manager_page.dart` | **Existe** |
| Clipboard (texto+arquivos) | `libs/clipboard`, `server/clipboard_service.rs` | **Existe** |
| Múltiplos monitores / qualidade / resolução | `display_service.rs`, `video_qos.rs`, `remote_page.dart` toolbar | **Existe** |
| Indicador direto/relay | `remote_page.dart` (ícone de conexão) | **Existe** |
| Histórico / recentes | `flutter/lib/common/widgets/peers_view.dart`, `peer_tab_page` | **Existe** |
| Log de sessões | `connection.rs` (log), audit só no Server Pro | **Parcial** — ver abaixo |
| Atualização automática | `updater.rs` → `api.rustdesk.com` | **Precisa redirecionar ou desligar** |

Conclusão: **praticamente todas as funcionalidades pedidas já existem.** O trabalho real é marca, servidor embutido, endurecimento de opções e empacotamento — não desenvolvimento de recursos.

## 4. Arquivos que serão modificados

### 4.1 Servidor e chave embutidos (crítico)
- `libs/hbb_common/src/config.rs:116-117` — `RENDEZVOUS_SERVERS` e `RS_PUB_KEY` → seu domínio e sua chave `id_ed25519.pub`.
- `libs/hbb_common/src/config.rs:57,71` — `ORG` e `APP_NAME` (define pasta de config `%APPDATA%\<Nome>`, nome do serviço, nome do pipe IPC).
- `libs/hbb_common/src/config.rs:103` (`HELPER_URL`) e URLs de `rustdesk.com` em `src/` e `flutter/lib` (25 ocorrências: privacidade, download, docs, API de versão).
- `src/updater.rs` / `src/common.rs:1179` — atualizador: apontar para seu servidor de releases ou desligar na v1.
- **Opções travadas** via `HARD_SETTINGS`/`OVERWRITE_SETTINGS` (`config.rs:75-82`, já suportado): bloquear troca de servidor pelo usuário final e **forçar `allow-hide-cm = N`** (`password_security.rs:91`; o RustDesk permite esconder a janela de conexão; no nosso produto isso fica desligado, para o cliente sempre ver que está sendo acessado).

> `hbb_common` é submódulo: faremos fork dele também (`seu-org/hbb_common`) e apontaremos `.gitmodules` para ele. Mudança mínima e isolada.

**Não usaremos** `custom.txt`/`custom_server.rs` para isso: o arquivo de cliente customizado é verificado com a chave privada da RustDesk (Server Pro, `custom_server.rs:27`). Alterar as constantes no fonte é o caminho correto no OSS.

### 4.2 Identidade do executável e instalador
- `Cargo.toml:261-265` `[package.metadata.winres]` e `flutter/windows/runner/Runner.rc:92-98` — CompanyName, ProductName, FileDescription, Copyright (manter crédito "baseado no RustDesk, AGPL-3.0" em texto "Sobre").
- `flutter/windows/CMakeLists.txt` / `runner/main.cpp` — nome do binário e da janela (a DLL `librustdesk.dll` pode manter o nome interno; trocá-la mexe em vários pontos sem ganho visível).
- `build.py:1048-1059` — renomeação final do exe e pacote portátil.
- `res/icon.ico`, `res/tray-icon.ico`, `res/*.png`, `res/logo*.svg`, `flutter/assets/*`, `flutter/windows/runner/resources/app_icon.ico`.
- `res/msi/` (WiX + `preprocess.py`, aceita `--app-name`/`--manufacturer`) — instalador MSI.
- `src/platform/windows.rs` usa `APP_NAME` para serviço, atalhos e chaves de registro → muda automaticamente com o item 4.1.

### 4.3 Interface (Flutter)
- `flutter/lib/consts.dart`, tema em `flutter/lib/common.dart` (`MyTheme`) — cores.
- `desktop/pages/desktop_home_page.dart` — tela do cliente (ID, senha, copiar).
- `desktop/pages/connection_page.dart` — tela do técnico (campo ID, recentes).
- `desktop/pages/server_page.dart` — janela de sessão ativa / encerrar.
- `desktop/pages/desktop_setting_page.dart` — esconder aba "Rede/ID Server" do usuário comum.
- `src/lang/ptbr.rs` — textos em português; strings com "RustDesk" (2.113 ocorrências nos 46 idiomas) trocadas por script reaplicável, não à mão.

**Modo técnico × modo cliente:** em vez de dois programas diferentes, o mesmo binário com dois perfis (o RustDesk já tem isso: `config::is_incoming_only()`, `src/client.rs:436`, cliente que só recebe conexões, base do "QuickSupport"). Geraremos:
1. `<Nome>-Suporte.exe` — portátil, *incoming-only*, só mostra ID/senha.
2. `<Nome>-Setup.exe` — instalável completo, com serviço opcional (não assistido).
3. `<Nome>-Tecnico.exe` — o seu, *outgoing* com recentes/histórico.

## 5. Arquivos que devem permanecer intactos
`libs/scrap`, `libs/enigo`, `libs/clipboard`, `libs/virtual_display`, `src/server/connection.rs` (exceto travas de opção), `src/client/*`, `src/rendezvous_mediator.rs`, `libs/hbb_common/src/{tcp,udp,stream,protos,password_security}.rs`, `src/platform/windows/verified_update.rs`, portas vcpkg em `res/vcpkg`. Toda customização vai em poucos arquivos + script `branding/apply.py` reaplicável após cada merge do upstream.

## 6. Dependências e ferramentas de compilação (Windows x64)
Versões **fixadas** pela CI oficial (`flutter-build.yml`) — usaremos exatamente estas:

| Ferramenta | Versão |
|---|---|
| Visual Studio 2022 Build Tools (C++ desktop, Windows SDK) | 17.x |
| Rust (toolchain MSVC) | **1.75** (exigido para Windows) |
| LLVM/Clang (bindgen) | **15.0.6** |
| Flutter | **3.24.5** + engine customizada `rustdesk/engine` + patch `.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff` |
| flutter_rust_bridge_codegen | **1.80** (gera ponte Dart↔Rust) |
| vcpkg | commit `9e593bb1…`, triplet `x64-windows-static` |
| Libs C via vcpkg | libvpx, libyuv, opus, aom, libjpeg-turbo, mfx-dispatch, ffmpeg (amf/nvcodec/qsv) |
| Python 3 | já instalado (3.11) |
| WiX Toolset | para o MSI (opcional, há instalador embutido) |
| Servidor | Rust estável qualquer, ou binários/Docker oficiais 1.1.16 |

Comando de build oficial: `python build.py --portable --flutter --skip-portable-pack --hwcodec --vram`.

## 7. Infraestrutura (rustdesk-server OSS 1.1.16)
- `hbbs` (21115 TCP, 21116 TCP/UDP, 21118 WS) e `hbbr` (21117 TCP, 21119 WS).
- Chave Ed25519 gerada no 1º start (`id_ed25519` / `.pub`); `-k _` / `KEY` obriga clientes a usar a mesma chave → bloqueia quem não é seu cliente.
- Vários relays: `hbbs -r relay1:21117,relay2:21117` — escala horizontal suportada no OSS.
- **Não existe no OSS** (só Server Pro): console web, catálogo de endereços central, log de auditoria central, contas de técnicos, controle de acesso por grupo. Alternativas sem custo: histórico/recentes locais no app do técnico; log de sessões local em cada máquina (já existe) + coleta opcional; servidor API próprio compatível (ex.: projetos comunitários `lejianwen/rustdesk-api`, AGPL) — avaliar na Fase 5 antes de adotar.

## 8. Riscos técnicos
1. **Build pesado**: vcpkg compila ffmpeg/aom (1-2 h na 1ª vez), `target/` passa de 15 GB. Com 38 GB livres é arriscado → recomendação: build de release no **GitHub Actions** do fork (mesma receita oficial) e build local só para iteração da UI.
2. Caminho com espaço (`C:\Users\DCL - Luiz Tolotti`) quebra scripts do vcpkg/CMake → trabalhar em `C:\dev\fork` (já feito).
3. Toolchain antigo (Rust 1.75, Flutter 3.24.5 com engine customizada) — não atualizar; trocar quebra o build.
4. Merges futuros: 2.800+ ocorrências de "RustDesk" — por isso marca via script e constantes, não edição manual espalhada.
5. **Antivírus/SmartScreen**: executável de acesso remoto não assinado é marcado como suspeito. Assinatura com certificado de code signing (OV/EV) é praticamente obrigatória para distribuir a clientes.
6. Drivers incluídos no build oficial (`usbmmidd_v2` monitor virtual, driver de impressora) vêm de binários do upstream; podemos omitir na v1.
7. Atualizador: se não for redirecionado, o app tentaria baixar o RustDesk oficial — deve ser desligado ou apontado para seu servidor **antes** da primeira distribuição.

## 9. Riscos de licenciamento
- **AGPL-3.0** (cliente e servidor). Uso comercial é **permitido**. Obrigações ao distribuir binários: oferecer o **código-fonte correspondente completo** (incluindo suas modificações e o script de marca) sob AGPL, manter `LICENCE` e avisos de copyright, informar que é obra modificada com data. Se você modificar o *servidor* e oferecê-lo pela rede, o fonte modificado também deve estar disponível aos usuários.
- Consequência prática: **não é possível ter código fechado** nem proibir clientes de redistribuir. É possível cobrar pelo serviço/suporte. Um repositório público no GitHub resolve a obrigação de forma simples.
- **Marca**: "RustDesk", o logotipo e os ícones são marca da Purslane Tech; AGPL não dá direito de uso da marca. Por isso trocar nome, ícones, logos e `CompanyName` não é só estético, é necessário. Manter crédito textual "Baseado no RustDesk (AGPL-3.0)" na tela Sobre é permitido e recomendado.
- Copyright do `Runner.rc`/`Cargo.toml` ("Purslane Tech… All rights reserved") deve virar algo como "© 2026 Sua Empresa; contém código © Purslane Tech, AGPL-3.0" — não remover o crédito original.
- Dependências: `enigo`, `scrap` MIT; crates Rust majoritariamente MIT/Apache; ffmpeg compilado como LGPL/GPL conforme features — verificar com `cargo-deny` e a lista do vcpkg na Fase 2 (ainda **não verificado**, depende do toolchain instalado).
- Engine Flutter customizada e drivers vêm de releases binárias do upstream — documentar a origem no pacote de fonte.

## 10. Plano da FASE 2 (proposta)
1. Criar fork no GitHub (`rustdesk` + `hbb_common`), branch `produto` sobre a tag 1.5.3, upstream como remote para merges.
2. Configurar o workflow de build Windows no fork (cópia enxuta do `flutter-build.yml`, só x64, sem assinatura) → **gerar o primeiro executável sem alterações**.
3. Em paralelo, montar o ambiente local em `C:\dev` (VS Build Tools, Rust 1.75, LLVM 15, Flutter 3.24.5, vcpkg) — exige ~25-30 GB.
4. Validar: executar o portátil, conectar contra o servidor público só para teste de fumaça, registrar resultado.
5. Seguir para FASE 3 com `branding/apply.py` + constantes do servidor.

Para avançar preciso de 3 decisões suas: **nome do produto**, **domínio do servidor** (pode ser provisório) e **onde compilar** (GitHub Actions, local ou ambos).
