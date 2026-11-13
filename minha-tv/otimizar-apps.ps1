<#
  Deixa os apps principais mais fluidos nesta TV TCL (Android TV 11), do jeito medido em 10/11 e 12/11/2026:
    - compila YouTube, Prime Video, Stremio, Crunchyroll e Kick por inteiro (cmd package compile -m speed),
      em vez de só os trechos mais usados (speed-profile, o padrão do Android). A Twitch fica de fora: a tela
      dela é uma página web dentro do WebView, e compilar não mudou nada na medição;
    - restringe em segundo plano (RUN_ANY_IN_BACKGROUND ignore) o Stremio, a Twitch e a Kick:
        Stremio: o servidor dele roda só com o Stremio aberto, em vez de ser recriado o tempo todo (~100 MB).
                 Se um dia usar player externo no Stremio, rode com -Desfazer.
        Twitch:  deixava uma tarefa a cada ~15 min para alimentar os canais da tela inicial original do
                 Google, que nem é usada aqui.
        Kick:    acordava em segundo plano para mandar telemetria (Firebase).
      Com o app aberto nada muda; a TV não mostra notificações desses apps.
  Uma atualização do app pela Play Store volta a compilação ao padrão: rode de novo depois de atualizar.

  Antes: na TV, ligue Depuração USB e Depuração de rede (e desligue depois).
  Uso (PowerShell):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\otimizar-apps.ps1" -Tv <ip da TV>
    -Desfazer        volta tudo ao padrão do Android (speed-profile e os três apps sem restrição)
    -Adb <caminho>   caminho do adb.exe, se não for encontrado sozinho
#>
param(
    [Parameter(Mandatory = $true)][string]$Tv,
    [string]$Adb = '',
    [switch]$Desfazer
)
$ErrorActionPreference = 'Continue'
$Apps = @('com.google.android.youtube.tv', 'com.amazon.amazonvideo.livingroom', 'com.stremio.one', 'com.crunchyroll.crunchyroid', 'com.kick.mobile')
$Restritos = @('com.stremio.one', 'tv.twitch.android.app', 'com.kick.mobile')

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
    if (((& $AdbExe -s $Serial get-state) | Out-String).Trim() -eq 'device') { $ok = $true; break }
    if ($i -eq 0) { Write-Host 'Na TV: aceite "Permitir depuração USB?".' -ForegroundColor Yellow }
    Start-Sleep -Seconds 2
}
if (-not $ok) { Write-Host "A TV $Serial não respondeu/autorizou. Confira a Depuração de rede e o IP." -ForegroundColor Red; exit 1 }

$mode = 'speed'
$op = 'ignore'
if ($Desfazer) { $mode = 'speed-profile'; $op = 'allow' }

foreach ($p in $Apps) {
    if (-not (Invoke-TvShell "pm path $p")) { Write-Host "$p não está instalado; pulando."; continue }
    Write-Host "Compilando $p ($mode), pode levar alguns minutos..." -ForegroundColor Cyan
    Write-Host ('  ' + (Invoke-TvShell "cmd package compile -m $mode -f $p"))
}

foreach ($p in $Restritos) {
    if (-not (Invoke-TvShell "pm path $p")) { continue }
    [void](Invoke-TvShell "cmd appops set $p RUN_ANY_IN_BACKGROUND $op")
}
[void](Invoke-TvShell 'cmd appops write-settings')
foreach ($p in $Restritos) {
    if (-not (Invoke-TvShell "pm path $p")) { continue }
    Write-Host ("$p em segundo plano: " + (Invoke-TvShell "cmd appops get $p RUN_ANY_IN_BACKGROUND"))
}

Write-Host ''
Write-Host 'Situação:' -ForegroundColor Cyan
$dex = Invoke-TvShell 'dumpsys package dexopt'
foreach ($p in $Apps) {
    $m = [regex]::Match($dex, '\[' + [regex]::Escape($p) + '\][\s\S]*?status=([a-z-]+)')
    if ($m.Success) { Write-Host ("  {0}: {1}" -f $p, $m.Groups[1].Value) }
}
Write-Host 'Pronto. Lembre de desligar a Depuração USB e a Depuração de rede na TV.' -ForegroundColor Green
