# FASE 2 — Ambiente e primeiro build (sem alterações funcionais)

Data: 23/11/2026

## Repositório
- GitHub: https://github.com/luizhtolotti-cloud/acesso-remoto (público, AGPL-3.0)
- Branch de trabalho: `produto`, criada sobre a tag oficial `1.5.3` (`95cca3f6`)
- Remote `upstream` = https://github.com/rustdesk/rustdesk (para incorporar correções futuras por merge de tag)
- Submódulo `libs/hbb_common` ainda aponta para o upstream (`fae47e02`); o fork dele será criado na Fase 3, quando houver a primeira alteração
- A tag `1.5.3` **não** é enviada ao fork: ela dispara `fdroid.yml` e `flutter-tag.yml` do upstream

## Build
Workflow próprio: `.github/workflows/produto-windows.yml` (cópia enxuta do job Windows oficial).
Dispara em push na `produto` (exceto docs/*.md) e manualmente (`workflow_dispatch`).

| Job | Função |
|---|---|
| `bridge` (Ubuntu) | gera a ponte Dart↔Rust com flutter_rust_bridge 1.80.1 / Flutter 3.22.3 |
| `topmost` | compila WindowInjection.dll (modo privacidade), workflow reutilizado do upstream |
| `windows` (windows-2022) | Rust 1.75, LLVM 15.0.6, Flutter 3.24.5 + engine RustDesk, vcpkg `9e593bb1` x64-windows-static, `build.py --portable --flutter --skip-portable-pack --hwcodec --vram`, monitor virtual, driver de impressora (checksum verificado), teste `--version`, executável portátil + SHA256SUMS |

Artefatos: `windows-x64-portatil` (exe único autoextraível + SHA256SUMS.txt) e `windows-x64-pasta` (pasta completa).

## Resultado do primeiro build — run 45202468794
| Item | Resultado |
|---|---|
| Status | **success** nos 3 jobs |
| Duração do job Windows | 46 min (15:19 → 16:05 UTC), sem cache |
| Portátil | `portable-x64.exe`, 26.115.072 bytes, SHA-256 `3cbb15e393f665d4696ea7af74d837fac3a0696be0b67c365128467421fe56b4` |
| Checksum após download | confere com o publicado pelo build |

## Validação local (Windows 11 Pro 22631, executado em 23/11/2026)
O que foi **efetivamente** testado, usando a pasta `windows-x64-pasta`:
- `rustdesk.exe --version` → `1.5.3`
- Metadados do exe: ProductName `RustDesk`, CompanyName `Purslane Tech Pte. Ltd.` (esperado: ainda sem marca)
- Assinatura digital: `NotSigned` (esperado)
- Abriu a janela principal ("RustDesk"), 2 processos, respondendo após 15 s
- Log: contatou o servidor público `rs-ny.rustdesk.com:21116` (latência 211 ms), NAT detectado `ASYMMETRIC`, `key_confirmed = true` (ID registrado)
- Codec por hardware detectado: Intel QSV H.264/H.265 (codificação) e D3D11VA (decodificação)
- Programa encerrado após o teste; nenhum serviço Windows instalado

**Não testado ainda:** conexão entre duas máquinas, executável portátil autoextraível (só o checksum), instalação/serviço. Isso fica para a Fase 4, já com o servidor próprio.

Efeito colateral do teste: criou `%APPDATA%\RustDesk\` (config e log) neste PC. Pode ser apagado; o produto final usará outra pasta (definida por `APP_NAME`).

## Pendências conhecidas
- Workflows agendados do upstream (`flutter-nightly.yml`, `update-webpki-roots.yml`) ainda não foram registrados pelo GitHub, então não puderam ser desativados. Verificar em `Actions` e desativar se aparecerem.
- Assinatura de código: precisa de certificado (OV/EV) antes da distribuição a clientes.
