<#
  Compila o launcher do fire-tv-cleanup (pasta launcher\) e instala no Fire TV Stick, só com o adb.exe
  (sem Python). No Fire TV o launcher da Amazon continua ativo (ele abriga as Configurações): este
  script liga o redirecionamento do Home (serviço de acessibilidade HomeRedirectService do launcher
  novo), o protetor de tela de fotos dele e abre a tela nova.

  Uso (PowerShell):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\fire-tv-cleanup\meu-firestick\instalar-launcher.ps1" -Tv <ip do Fire Stick>
  Opções:
    -SoCompilar    só compila (gera launcher\app\build\outputs\apk\release\app-release.apk)
    -SemCompilar   instala o APK que já está compilado
    -Adb <caminho> caminho do adb.exe, se não for encontrado sozinho

  Para mudar o dock, as colunas ou os apps escondidos: edite launcher\app\src\main\res\values\config.xml
  e rode este script de novo. O dock salvo na TV (Fixar/Tirar/Mover) vale mais que o config.xml; para
  voltar ao do config.xml: adb -s <ip>:5555 shell pm clear com.gathin.tvhome (e rode este script de novo).
  Compilar precisa do JDK 17 e do Android SDK (platform 34 + build-tools 34.0.0), que já estão neste PC
  (%LOCALAPPDATA%\cleanyourtv\jdk-17 e %LOCALAPPDATA%\Android\Sdk).
  No Fire TV: Depuração ADB ligada (ela desliga a cada reinício).
#>
param(
    [string]$Tv = '',
    [string]$Adb = '',
    [switch]$SoCompilar,
    [switch]$SemCompilar
)
$ErrorActionPreference = 'Stop'
$Repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Launcher = Join-Path $Repo 'launcher'
$Apk = Join-Path $Launcher 'app\build\outputs\apk\release\app-release.apk'
$Pkg = 'com.gathin.tvhome'
$Redirect = "$Pkg/$Pkg.HomeRedirectService"
$Saver = "$Pkg/$Pkg.PhotoDream"

function Get-JdkVersion([string]$Dir) {
    $rel = Join-Path $Dir 'release'
    if (-not (Test-Path -LiteralPath $rel)) { return 0 }
    $m = Select-String -LiteralPath $rel -Pattern 'JAVA_VERSION="(\d+)' | Select-Object -First 1
    if ($m) { return [int]$m.Matches[0].Groups[1].Value }
    return 0
}

function Test-Jdk([string]$Dir) {
    if (-not $Dir) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'bin\java.exe'))) { return $false }
    return ((Get-JdkVersion $Dir) -ge 17)
}

function Find-Jdk {
    $c = New-Object System.Collections.Generic.List[string]
    if ($env:JAVA_HOME) { $c.Add($env:JAVA_HOME) }
    $portable = Join-Path $env:LOCALAPPDATA 'cleanyourtv\jdk-17'
    if (Test-Path -LiteralPath $portable) { foreach ($d in @(Get-ChildItem -LiteralPath $portable -Directory -ErrorAction SilentlyContinue)) { $c.Add($d.FullName) } }
    foreach ($root in @((Join-Path $env:ProgramFiles 'Android'), (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        if (Test-Path -LiteralPath $root) {
            foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Android Studio*' })) { $c.Add((Join-Path $d.FullName 'jbr')) }
        }
    }
    foreach ($name in @('Eclipse Adoptium', 'Microsoft', 'Java', 'Zulu', 'Amazon Corretto', 'BellSoft')) {
        $root = Join-Path $env:ProgramFiles $name
        if (Test-Path -LiteralPath $root) {
            foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) { $c.Add($d.FullName) }
        }
    }
    foreach ($d in $c) { if (Test-Jdk $d) { return $d } }
    return $null
}

function Find-Sdk {
    $c = @()
    if ($env:ANDROID_HOME) { $c += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $c += $env:ANDROID_SDK_ROOT }
    if ($env:LOCALAPPDATA) { $c += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
    foreach ($d in $c) {
        if ($d -and (Test-Path -LiteralPath (Join-Path $d 'licenses'))) { return $d }
    }
    return $null
}

function Invoke-Build {
    $jdk = Find-Jdk
    $sdk = Find-Sdk
    if (-not $jdk -or -not $sdk) {
        if ($jdk) { Write-Host "JDK: $jdk" } else { Write-Host 'JDK 17: não encontrado' -ForegroundColor Yellow }
        if ($sdk) { Write-Host "SDK: $sdk" } else { Write-Host 'Android SDK (com a licença aceita): não encontrado' -ForegroundColor Yellow }
        Write-Host 'O instalador da TCL prepara os dois: E:\Misc Projects\cleanyourtv\minha-tv\instalar-launcher.ps1 -SoCompilar'
        exit 1
    }
    Write-Host "JDK: $jdk"
    Write-Host "SDK: $sdk"
    $env:JAVA_HOME = $jdk
    $env:ANDROID_HOME = $sdk
    $env:Path = (Join-Path $jdk 'bin') + ';' + $env:Path
    # local.properties: sdk.dir deste PC; linhas tvhome.* (ex.: tvhome.userName=Dimas) são mantidas.
    $lp = Join-Path $Launcher 'local.properties'
    $keep = @()
    if (Test-Path -LiteralPath $lp) { $keep = @([System.IO.File]::ReadAllLines($lp) | Where-Object { $_ -match '^\s*tvhome\.' }) }
    $lines = @('sdk.dir=' + ($sdk -replace '\\', '/')) + $keep
    [System.IO.File]::WriteAllText($lp, (($lines -join "`n") + "`n"))
    $log = Join-Path $PSScriptRoot 'compilacao.log'
    [System.IO.File]::WriteAllText($log, "JDK: $jdk`r`nSDK: $sdk`r`n")
    Push-Location $Launcher
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & cmd.exe /c 'gradlew.bat assembleRelease --console=plain 2>&1' | ForEach-Object {
            Write-Host $_
            [System.IO.File]::AppendAllText($log, "$_`r`n")
        }
        $code = $LASTEXITCODE
    } finally { Pop-Location; $ErrorActionPreference = $prevPref }
    [System.IO.File]::AppendAllText($log, "SAIDA $code`r`n")
    if ($code -ne 0) { throw "o Gradle falhou (código $code); veja $log" }
    if (-not (Test-Path -LiteralPath $Apk)) { throw "o APK não apareceu em $Apk" }
    Write-Host ('APK pronto: {0} ({1:N0} bytes)' -f $Apk, (Get-Item -LiteralPath $Apk).Length) -ForegroundColor Green
}

# Mesma ordem de busca da ponte (bridge.ps1): os dois usam o mesmo adb.exe e o mesmo servidor adb.
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
    throw 'adb.exe não encontrado. Rode: winget install --id Google.PlatformTools -e'
}

function Invoke-TvShell([string]$Command) {
    $out = & $script:AdbExe -s $script:Serial shell $Command
    return (($out | Out-String).Trim())
}

function Install-Launcher {
    if (-not $Tv) { throw 'passe -Tv <ip do Fire Stick>' }
    if (-not (Test-Path -LiteralPath $Apk)) { throw "não há APK em $Apk; rode sem -SemCompilar" }
    $script:AdbExe = Find-Adb $Adb
    $script:Serial = $Tv
    if ($script:Serial -notmatch ':\d+$') { $script:Serial = "$($Tv):5555" }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $script:AdbExe connect $script:Serial | Out-Host
    $ok = $false
    for ($i = 0; $i -lt 60; $i++) {
        if (((& $script:AdbExe -s $script:Serial get-state) | Out-String).Trim() -eq 'device') { $ok = $true; break }
        if ($i -eq 0) { Write-Host 'No Fire TV: aceite "Permitir depuração USB?".' -ForegroundColor Yellow }
        Start-Sleep -Seconds 2
    }
    if (-not $ok) { throw "o Fire TV $($script:Serial) não respondeu ou não autorizou (Depuração ADB ligada?)" }

    $maker = Invoke-TvShell 'getprop ro.product.manufacturer'
    if ($maker -ne 'Amazon') { throw "este script é para o Fire TV; o aparelho diz '$maker'. Nada foi instalado." }
    $tvSdk = [int]((Invoke-TvShell 'getprop ro.build.version.sdk') -replace '\D', '')
    if ($tvSdk -lt 26) { throw "o aparelho tem SDK $tvSdk; o launcher precisa de 26 ou mais. Nada foi instalado." }

    Write-Host 'Instalando o APK...' -ForegroundColor Cyan
    & $script:AdbExe -s $script:Serial push $Apk /data/local/tmp/tvhome.apk | Out-Host
    $out = Invoke-TvShell 'pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk'
    Write-Host $out
    if ($out -notmatch 'Success') { throw 'o pm install falhou; nada mais foi mudado.' }
    Write-Host (Invoke-TvShell "cmd package compile -m speed -f $Pkg")

    # Permite ao launcher ligar/desligar o redirecionamento pela própria TV (Menu no botão Configurações).
    [void](Invoke-TvShell "pm grant $Pkg android.permission.WRITE_SECURE_SETTINGS")
    $cur = Invoke-TvShell 'settings get secure enabled_accessibility_services'
    if ($cur -notmatch [regex]::Escape($Redirect)) {
        $list = $Redirect
        if ($cur -and $cur -ne 'null') { $list = "$($cur):$Redirect" }
        [void](Invoke-TvShell "settings put secure enabled_accessibility_services $list")
    }
    [void](Invoke-TvShell 'settings put secure accessibility_enabled 1')
    [void](Invoke-TvShell "settings put secure screensaver_components $Saver")

    [void](Invoke-TvShell "am start -n $Pkg/.MainActivity")
    Start-Sleep -Seconds 3
    $focus = Invoke-TvShell 'dumpsys activity activities | grep mResumedActivity'
    Write-Host $focus
    if ($focus -notmatch [regex]::Escape($Pkg)) { Write-Warning 'A tela nova ainda não apareceu; aperte Home no controle e confira.' }
    Write-Host ('Redirecionamento: ' + (Invoke-TvShell 'settings get secure enabled_accessibility_services'))
    Write-Host ('Protetor de tela: ' + (Invoke-TvShell 'settings get secure screensaver_components'))
    $ErrorActionPreference = $prev
    Write-Host ''
    Write-Host 'Pronto. Home abre a tela nova (a da Amazon aparece por um instante antes).' -ForegroundColor Green
    Write-Host 'Para voltar à tela da Amazon pela TV: Menu (ou segure OK) no botão Configurações > Usar a tela inicial da Amazon.'
}

if (-not $SemCompilar) { Invoke-Build }
if (-not $SoCompilar) { Install-Launcher }
