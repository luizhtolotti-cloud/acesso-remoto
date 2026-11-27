<#
DCL Remoto - instala o servidor (hbbs + hbbr, rustdesk-server OSS 1.1.16) num PC Windows.

- Copia hbbs.exe/hbbr.exe e o par de chaves para C:\DCL-Remoto-Servidor (acesso só SYSTEM/Administradores).
- Cria duas tarefas agendadas que iniciam com o Windows como SYSTEM e reiniciam se caírem.
- Libera no Firewall do Windows: TCP 21115-21119 e UDP 21116.

Uso (PowerShell como administrador):
  .\instalar-servidor.ps1 -Binarios <pasta com hbbs.exe> -Chaves <pasta com id_ed25519 e id_ed25519.pub>
Reexecutar é seguro: para as tarefas, atualiza os arquivos e sobe de novo.
#>
param(
    [Parameter(Mandatory)] [string] $Binarios,
    [Parameter(Mandatory)] [string] $Chaves,
    [string] $Destino = 'C:\DCL-Remoto-Servidor',
    [string] $Endereco = 'remoto.dclassistencia.com.br',
    [string] $RedeLocal = '192.168.10.0/24'
)
$ErrorActionPreference = 'Stop'
$PubEsperada = '4K26EpKjUMWle4dLO7XilVKe2Gs7x93gLF80nwMV1NY='

$pub = (Get-Content (Join-Path $Chaves 'id_ed25519.pub') -Raw).Trim()
if ($pub -ne $PubEsperada) { throw "id_ed25519.pub não é a chave embutida no cliente DCL Remoto." }
foreach ($f in 'hbbs.exe', 'hbbr.exe') { if (-not (Test-Path (Join-Path $Binarios $f))) { throw "$f não encontrado em $Binarios" } }

# Para versões anteriores
foreach ($t in 'DCL Remoto - hbbs', 'DCL Remoto - hbbr') {
    if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $t; Unregister-ScheduledTask -TaskName $t -Confirm:$false }
}
Get-Process hbbs, hbbr -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Destino\*" } | Stop-Process -Force
Start-Sleep 1

# Arquivos
New-Item -ItemType Directory -Force $Destino, "$Destino\logs" | Out-Null
Copy-Item (Join-Path $Binarios 'hbbs.exe'), (Join-Path $Binarios 'hbbr.exe') $Destino -Force
Copy-Item (Join-Path $Chaves 'id_ed25519'), (Join-Path $Chaves 'id_ed25519.pub') $Destino -Force
icacls $Destino /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null

# Scripts de execução (redirecionam a saída para log)
$hbbsArgs = "-r ${Endereco}:21117 -k _ --mask $RedeLocal"
# DB_URL: banco de IDs junto do servidor (padrão seria o perfil do SYSTEM em C:\Windows\...).
Set-Content "$Destino\hbbs.cmd" -Encoding ASCII -Value "@echo off`r`ncd /d `"$Destino`"`r`nset DB_URL=$Destino\db_v2.sqlite3`r`nhbbs.exe $hbbsArgs >> logs\hbbs.log 2>&1"
Set-Content "$Destino\hbbr.cmd" -Encoding ASCII -Value "@echo off`r`ncd /d `"$Destino`"`r`nhbbr.exe -k _ >> logs\hbbr.log 2>&1"

# Tarefas agendadas: início com o Windows, SYSTEM, reinício automático, sem limite de tempo
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$gatilho = New-ScheduledTaskTrigger -AtStartup
$config = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
foreach ($n in 'hbbr', 'hbbs') {
    $acao = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\cmd.exe" -Argument "/c `"$Destino\$n.cmd`"" -WorkingDirectory $Destino
    Register-ScheduledTask -TaskName "DCL Remoto - $n" -Description "DCL Remoto: servidor $n (rustdesk-server 1.1.16)" `
        -Action $acao -Trigger $gatilho -Principal $principal -Settings $config | Out-Null
}

# Firewall
Get-NetFirewallRule -DisplayName 'DCL Remoto Servidor*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'DCL Remoto Servidor TCP' -Direction Inbound -Protocol TCP -LocalPort 21115-21119 -Action Allow -Profile Any | Out-Null
New-NetFirewallRule -DisplayName 'DCL Remoto Servidor UDP' -Direction Inbound -Protocol UDP -LocalPort 21116 -Action Allow -Profile Any | Out-Null

Start-ScheduledTask -TaskName 'DCL Remoto - hbbr'
Start-ScheduledTask -TaskName 'DCL Remoto - hbbs'
Start-Sleep 4
Get-NetTCPConnection -State Listen -LocalPort 21115, 21116, 21117 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table
Get-NetUDPEndpoint -LocalPort 21116 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table
Write-Host "Instalado em $Destino. Logs em $Destino\logs."
