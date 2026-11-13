<#
  Desfaz a limpeza deste Fire TV Stick Lite (Fire OS 7): reativa tudo o que está em debloat.txt,
  desliga o redirecionamento para o launcher novo, devolve o protetor de tela da Amazon, remove
  o launcher novo (com.gathin.tvhome), volta as animações para 1x e o DNS para automático.
  As opções de privacidade (dados de uso, anúncios por interesse) voltam pelo menu:
  Configurações > Preferências > Configurações de privacidade.

  Antes de rodar: no Fire TV, ligue de novo Configurações > Minha Fire TV > Opções do desenvolvedor >
  Depuração ADB (no Fire TV ela desliga a cada reinício). Precisa do adb.exe (neste PC está em
  %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe e em C:\platform-tools\adb.exe).

  Uso (PowerShell):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\fire-tv-cleanup\meu-firestick\restaurar.ps1" -Tv <ip do Fire Stick>
  Opções:
    -ManterLauncher   volta para a tela inicial da Amazon, mas deixa o launcher novo instalado
    -Adb <caminho>    caminho do adb.exe, se ele não for encontrado sozinho

  Para reativar um só app:
    adb -s <ip>:5555 shell pm enable <pacote>
#>
param(
    [Parameter(Mandatory = $true)][string]$Tv,
    [string]$Adb = '',
    [switch]$ManterLauncher
)
$ErrorActionPreference = 'Continue'
$List = Join-Path $PSScriptRoot 'debloat.txt'
$NewHome = 'com.gathin.tvhome'
$AmazonSaver = 'com.amazon.ftv.screensaver/.app.services.ScreensaverService'

function Find-Adb([string]$Given) {
    if ($Given) { return $Given }
    $cmd = Get-Command 'adb.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Path }
    $c = @()
    if ($env:LOCALAPPDATA) {
        $c += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
        $c += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\adb.exe')
    }
    $c += 'C:\platform-tools\adb.exe'
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
    if ($i -eq 0) { Write-Host 'No Fire TV: aceite "Permitir depuração USB?" (Sempre permitir deste computador).' -ForegroundColor Yellow }
    Start-Sleep -Seconds 2
}
if (-not $ok) { Write-Host "O Fire TV $Serial não respondeu/autorizou. Confira a Depuração ADB e o IP." -ForegroundColor Red; exit 1 }

$pkgs = @(Get-Content -LiteralPath $List -Encoding UTF8 | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' })
Write-Host ("Reativando {0} pacotes de debloat.txt..." -f $pkgs.Count) -ForegroundColor Cyan
foreach ($p in $pkgs) {
    $r = Invoke-TvShell "pm enable $p"
    Write-Host ("  {0}: {1}" -f $p, $r)
}

Write-Host 'Tela inicial e protetor de tela da Amazon...' -ForegroundColor Cyan
$cur = Invoke-TvShell 'settings get secure enabled_accessibility_services'
if ($cur -match 'com\.gathin\.tvhome') {
    $rest = @($cur -split ':' | Where-Object { $_ -and ($_ -notmatch 'com\.gathin\.tvhome') }) -join ':'
    if ($rest) {
        [void](Invoke-TvShell "settings put secure enabled_accessibility_services $rest")
    } else {
        [void](Invoke-TvShell 'settings delete secure enabled_accessibility_services')
        [void](Invoke-TvShell 'settings put secure accessibility_enabled 0')
    }
    Write-Host '  redirecionamento para o launcher novo: desligado'
}
$saver = Invoke-TvShell 'settings get secure screensaver_components'
if ($saver -match 'com\.gathin\.tvhome') {
    [void](Invoke-TvShell "settings put secure screensaver_components $AmazonSaver")
    Write-Host '  protetor de tela: o da Amazon'
}
if (-not $ManterLauncher) {
    Write-Host ('  remover launcher novo: ' + (Invoke-TvShell "pm uninstall $NewHome"))
}
Write-Host 'Animações 1x e DNS automático...' -ForegroundColor Cyan
foreach ($k in @('window_animation_scale', 'transition_animation_scale', 'animator_duration_scale')) {
    [void](Invoke-TvShell "settings put global $k 1.0")
}
[void](Invoke-TvShell 'settings put global private_dns_mode opportunistic')
[void](Invoke-TvShell 'settings delete global private_dns_specifier')
[void](Invoke-TvShell 'input keyevent KEYCODE_HOME')

Write-Host ''
Write-Host 'Pronto. Se algo não voltar, reinicie o Fire TV (Configurações > Minha Fire TV > Reiniciar).' -ForegroundColor Green
Write-Host 'Depois, desligue a Depuração ADB em Configurações > Minha Fire TV > Opções do desenvolvedor.' -ForegroundColor Green
