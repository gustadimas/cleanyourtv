<#
  Reaplica a limpeza deste Fire TV Stick: desativa de novo (para o usuário 0, sem desinstalar) cada
  pacote de debloat.txt, um por comando. Use se uma atualização do Fire OS religar algum app.
  A lista já foi conferida neste aparelho; só pacotes dela são tocados.

  Uso (PowerShell):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\fire-tv-cleanup\meu-firestick\desativar.ps1" -Tv <ip do Fire Stick>
  Desfazer: restaurar.ps1 -Tv <ip>
#>
param(
    [Parameter(Mandatory = $true)][string]$Tv,
    [string]$Adb = ''
)
$ErrorActionPreference = 'Continue'
$List = Join-Path $PSScriptRoot 'debloat.txt'

function Find-Adb([string]$Given) {
    if ($Given) { return $Given }
    $cmd = Get-Command 'adb.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Path }
    $c = @()
    foreach ($v in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) { if ($v) { $c += (Join-Path $v 'platform-tools\adb.exe') } }
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
    if (((& $AdbExe -s $Serial get-state) | Out-String).Trim() -eq 'device') { $ok = $true; break }
    if ($i -eq 0) { Write-Host 'No Fire TV: aceite "Permitir depuração USB?".' -ForegroundColor Yellow }
    Start-Sleep -Seconds 2
}
if (-not $ok) { Write-Host "O Fire TV $Serial não respondeu/autorizou. Confira a Depuração ADB e o IP." -ForegroundColor Red; exit 1 }
if ((Invoke-TvShell 'getprop ro.product.model') -ne 'AFTSS') { Write-Host 'Esta lista é do Fire TV Stick Lite (AFTSS); o aparelho conectado é outro. Nada foi feito.' -ForegroundColor Red; exit 1 }

$already = @((Invoke-TvShell 'pm list packages -d') -split "`r?`n" | ForEach-Object { ($_ -replace '^package:', '').Trim() })
$pkgs = @(Get-Content -LiteralPath $List -Encoding UTF8 | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' })
$n = 0
foreach ($p in $pkgs) {
    if ($already -contains $p) { continue }
    $r = Invoke-TvShell "pm disable-user --user 0 $p"
    Write-Host ("  {0}: {1}" -f $p, $r)
    $n++
}
if ($n -eq 0) { Write-Host 'Nada a fazer: todos os pacotes de debloat.txt já estão desativados.' -ForegroundColor Green }
else {
    [void](Invoke-TvShell 'sync')
    Write-Host ("Pronto: {0} pacote(s) desativado(s) de novo. Espere ~1 min antes de reiniciar." -f $n) -ForegroundColor Green
}
