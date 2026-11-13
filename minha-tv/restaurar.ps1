<#
  Desfaz a limpeza desta TV TCL (Android TV 11): reativa tudo o que está em debloat.txt,
  devolve a tela inicial original, o protetor de tela de fotos, o DNS automático, as animações
  como vieram de fábrica (desligadas) e o Stremio, a Twitch e a Kick sem restrição em segundo
  plano, e remove o launcher novo (com.gathin.tvhome).
  A Alexa volta a ficar ativada, mas sem conta: para usar de novo, abra o app Alexa da TV e
  escolha "Habilitar Alexa".

  Antes de rodar: na TV, ligue de novo Configurações > Preferências do dispositivo >
  Opções do desenvolvedor > Depuração USB e Depuração de rede. Precisa do adb.exe
  (C:\platform-tools\adb.exe, ou: winget install --id Google.PlatformTools -e).

  Uso (PowerShell):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\restaurar.ps1" -Tv <ip da TV>
  Opções:
    -ManterLauncher   volta para a tela inicial original, mas deixa o launcher novo instalado
    -Adb <caminho>    caminho do adb.exe, se ele não for encontrado sozinho

  Pacotes que já vinham desativados de fábrica (Chromecast, Stan, Rakuten TV, voz do Google)
  não estão em debloat.txt e continuam como estavam. Para reativar um só app:
    adb -s <ip>:5555 shell pm enable <pacote>
#>
param(
    [Parameter(Mandatory = $true)][string]$Tv,
    [string]$Adb = '',
    [switch]$ManterLauncher
)
$ErrorActionPreference = 'Continue'
$List = Join-Path $PSScriptRoot 'debloat.txt'
$StockHome = 'com.google.android.tvlauncher'
$NewHome = 'com.gathin.tvhome'

function Find-Adb([string]$Given) {
    if ($Given) { return $Given }
    $cmd = Get-Command 'adb.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Path }
    $c = @('C:\platform-tools\adb.exe')
    if ($env:LOCALAPPDATA) {
        $c += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
        $c += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\adb.exe')
    }
    foreach ($p in $c) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}

$AdbExe = Find-Adb $Adb
if (-not $AdbExe) { Write-Host 'adb.exe não encontrado. Rode: winget install --id Google.PlatformTools -e' -ForegroundColor Yellow; exit 1 }
$Serial = $Tv
if ($Serial -notmatch ':\d+$') { $Serial = "$($Tv):5555" }

function Invoke-TvShell([string]$Command) {
    $out = & $AdbExe -s $Serial shell $Command
    return (($out | Out-String).Trim())
}

& $AdbExe connect $Serial | Out-Host
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    $state = ((& $AdbExe -s $Serial get-state) | Out-String).Trim()
    if ($state -eq 'device') { $ok = $true; break }
    if ($i -eq 0) { Write-Host 'Na TV: aceite "Permitir depuração USB?" (Sempre permitir deste computador).' -ForegroundColor Yellow }
    Start-Sleep -Seconds 2
}
if (-not $ok) { Write-Host "A TV $Serial não respondeu/autorizou. Confira a Depuração de rede e o IP." -ForegroundColor Red; exit 1 }

$pkgs = @(Get-Content -LiteralPath $List -Encoding UTF8 | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' })
Write-Host ("Reativando {0} pacotes de debloat.txt..." -f $pkgs.Count) -ForegroundColor Cyan
foreach ($p in $pkgs) {
    $r = Invoke-TvShell "pm enable $p"
    Write-Host ("  {0}: {1}" -f $p, $r)
}

Write-Host 'Tela inicial original...' -ForegroundColor Cyan
Write-Host ('  ' + (Invoke-TvShell "pm enable $StockHome"))
Write-Host ('  ' + (Invoke-TvShell "cmd package set-home-activity $StockHome/.MainActivity"))
if (-not $ManterLauncher) {
    Write-Host ('  remover launcher novo: ' + (Invoke-TvShell "pm uninstall $NewHome"))
}

Write-Host 'Protetor de tela de fotos, DNS automático, animações de fábrica e apps sem restrição...' -ForegroundColor Cyan
[void](Invoke-TvShell 'settings put secure screensaver_components com.google.android.backdrop/.Backdrop')
[void](Invoke-TvShell 'settings put global private_dns_mode opportunistic')
[void](Invoke-TvShell 'settings delete global private_dns_specifier')
[void](Invoke-TvShell 'settings put global animator_duration_scale 0')
foreach ($p in @('com.stremio.one', 'tv.twitch.android.app', 'com.kick.mobile')) {
    if (Invoke-TvShell "pm path $p") { [void](Invoke-TvShell "cmd appops set $p RUN_ANY_IN_BACKGROUND allow") }
}
[void](Invoke-TvShell 'cmd appops write-settings')

Write-Host ''
Write-Host 'Desativados agora:' -ForegroundColor Cyan
Write-Host (Invoke-TvShell 'pm list packages -d')
Write-Host ('Home: ' + (Invoke-TvShell 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'))
Write-Host ''
Write-Host 'Pronto. Aperte Home no controle. Depois desligue de novo a Depuração USB e a Depuração de rede na TV.' -ForegroundColor Green
