<#
  Compila o launcher (pasta launcher\) e instala na TV como tela inicial, só com o adb.exe
  (sem Python). Feito para esta TV TCL (Android TV 11), seguindo a mesma ordem segura do
  launcher\build-and-install.sh do repositório: o launcher novo abre primeiro, só então o
  original (com.google.android.tvlauncher) é desativado; se a Home não ficar com o novo, o
  original é reativado na hora.

  Uso (PowerShell):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-launcher.ps1" -Tv <ip da TV>
  Opções:
    -SoCompilar    só compila (gera launcher\app\build\outputs\apk\release\app-release.apk)
    -SemCompilar   instala o APK que já está compilado
    -Adb <caminho> caminho do adb.exe, se não for encontrado sozinho
  Temas (não recompila nem reinstala nada):
    -Tema <pasta>            aplica uma pasta de tema (config.json + wallpaper.jpg ou wallpapers\),
                             ex.: -Tema ..\themes\aerial  ou uma pasta sua
    -PapelDeParede <imagem>  usa uma foto sua (JPG/PNG, de preferência 1280x720 ou 1920x1080) como fundo
    -SemTema                 tira o tema e o papel de parede (volta ao fundo preto)
    -TrocarDock              deixa o tema mudar também o dock, colunas e saudação (padrão: mantém os seus)

  Para compilar precisa de JDK 17+ (winget install --id Microsoft.OpenJDK.17 -e) e Android SDK
  (platform 34 + build-tools 34.0.0; sem SDK, o script cria um mínimo se você aceitar a licença). O script
  procura no Android Studio, no Unity (módulo Android), em JAVA_HOME/ANDROID_HOME e nas pastas
  comuns de JDK; sem isso, usa o Docker Desktop (tools\docker-build.ps1) se estiver instalado.
  Na TV: Depuração USB e Depuração de rede ligadas (para instalar).
#>
param(
    [string]$Tv = '',
    [string]$Adb = '',
    [switch]$SoCompilar,
    [switch]$SemCompilar,
    [string]$Tema = '',
    [string]$PapelDeParede = '',
    [switch]$SemTema,
    [switch]$TrocarDock
)
$ErrorActionPreference = 'Stop'
$Repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Launcher = Join-Path $Repo 'launcher'
$Apk = Join-Path $Launcher 'app\build\outputs\apk\release\app-release.apk'
$Pkg = 'com.gathin.tvhome'
$Main = "$Pkg/.MainActivity"
$KnownStock = @('com.google.android.tvlauncher', 'com.google.android.apps.tv.launcherx', 'com.google.android.leanbacklauncher', 'com.mitv.tvhome')

function Get-UnityEditors {
    $list = @()
    $roots = @()
    if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'Unity\Hub\Editor') }
    if ($env:APPDATA) {
        $cfg = Join-Path $env:APPDATA 'UnityHub\secondaryInstallPath.json'
        if (Test-Path -LiteralPath $cfg) {
            try { $p = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json; if ($p) { $roots += [string]$p } } catch { }
        }
    }
    foreach ($r in $roots) {
        if ($r -and (Test-Path -LiteralPath $r)) {
            $list += @(Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'Editor' })
        }
    }
    return $list
}

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
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'bin\jlink.exe'))) { return $false }
    return ((Get-JdkVersion $Dir) -ge 17)
}

function Find-Jdk {
    $c = New-Object System.Collections.Generic.List[string]
    if ($env:JAVA_HOME) { $c.Add($env:JAVA_HOME) }
    foreach ($root in @((Join-Path $env:ProgramFiles 'Android'), (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        if (Test-Path -LiteralPath $root) {
            foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Android Studio*' })) {
                $c.Add((Join-Path $d.FullName 'jbr'))
            }
        }
    }
    $portable = Join-Path $env:LOCALAPPDATA 'cleanyourtv\jdk-17'
    if (Test-Path -LiteralPath $portable) { foreach ($d in @(Get-ChildItem -LiteralPath $portable -Directory -ErrorAction SilentlyContinue)) { $c.Add($d.FullName) } }
    foreach ($u in @(Get-UnityEditors)) { $c.Add((Join-Path $u 'Data\PlaybackEngines\AndroidPlayer\OpenJDK')) }
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
    foreach ($u in @(Get-UnityEditors)) { $c += (Join-Path $u 'Data\PlaybackEngines\AndroidPlayer\SDK') }
    foreach ($d in $c) {
        if ($d -and (Test-Path -LiteralPath (Join-Path $d 'platforms\android-34')) -and (Test-Path -LiteralPath (Join-Path $d 'build-tools\34.0.0'))) { return $d }
    }
    return $null
}

function Get-PortableJdk {
    # Sem JDK: baixa o Microsoft Build of OpenJDK 17 (zip portátil, sem instalador e sem admin) do link
    # oficial de "última versão" da Microsoft, confere o SHA-256 publicado ao lado e extrai em
    # %LOCALAPPDATA%\cleanyourtv\jdk-17.
    $base = Join-Path $env:LOCALAPPDATA 'cleanyourtv'
    $target = Join-Path $base 'jdk-17'
    $url = 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip'
    Write-Host ''
    Write-Host 'Não há JDK 17 neste PC. Posso baixar o Microsoft Build of OpenJDK 17 (zip portátil, ~190 MB,' -ForegroundColor Yellow
    Write-Host "sem instalador e sem admin) de $url"
    Write-Host "para $target"
    $ans = Read-Host 'Baixar? (S/N)'
    if ($ans -notmatch '^\s*[sSyY]') { return $null }
    [void](New-Item -ItemType Directory -Force -Path $base)
    $zip = Join-Path $base 'microsoft-jdk-17-windows-x64.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Write-Host 'Baixando o JDK (alguns minutos)...'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        $sum = (Invoke-WebRequest -Uri ($url + '.sha256sum.txt') -UseBasicParsing).Content
    } finally { $ProgressPreference = $oldProgress }
    if ($sum -is [byte[]]) { $sum = [System.Text.Encoding]::ASCII.GetString($sum) }
    $expected = (([string]$sum).Trim() -split '\s+')[0].ToLower()
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) { throw "o SHA-256 do zip não confere (baixado $actual, publicado $expected). Apague $zip e tente de novo." }
    Write-Host 'SHA-256 confere. Extraindo...'
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    [void](New-Item -ItemType Directory -Force -Path $target)
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path -LiteralPath $tar) { & $tar -xf $zip -C $target } else { Expand-Archive -LiteralPath $zip -DestinationPath $target -Force }
    foreach ($d in @(Get-ChildItem -LiteralPath $target -Directory)) { if (Test-Jdk $d.FullName) { Write-Host "JDK pronto: $($d.FullName)" -ForegroundColor Green; return $d.FullName } }
    throw "o JDK extraído em $target não tem bin\java.exe e bin\jlink.exe"
}

function New-MinimalSdk {
    # Sem Android SDK: cria um mínimo em %LOCALAPPDATA%\Android\Sdk, só com a licença aceita pelo dono,
    # e o próprio Gradle (Android Gradle Plugin) baixa do Google o que faltar: platform 34 + build-tools 34.0.0.
    $dir = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    Write-Host ''
    Write-Host 'Não há Android SDK neste PC. Posso criar um mínimo em:' -ForegroundColor Yellow
    Write-Host "  $dir"
    Write-Host 'e o Gradle baixa do Google só o necessário (SDK Platform 34 + Build-Tools 34.0.0, ~150 MB).'
    Write-Host 'Para isso você precisa aceitar a licença do Android SDK: https://developer.android.com/studio/terms'
    $ans = Read-Host 'Aceita a licença do Android SDK? (S/N)'
    if ($ans -notmatch '^\s*[sSyY]') { return $null }
    $lic = Join-Path $dir 'licenses'
    [void](New-Item -ItemType Directory -Force -Path $lic)
    [System.IO.File]::WriteAllText((Join-Path $lic 'android-sdk-license'), "`n24333f8a63b6825ea9c5514f83c2829b004d1fee")
    return $dir
}

function Invoke-Build {
    $jdk = Find-Jdk
    if (-not $jdk -and -not (Get-Command docker -ErrorAction SilentlyContinue)) { $jdk = Get-PortableJdk }
    $sdk = Find-Sdk
    if ($jdk -and -not $sdk -and -not (Get-Command docker -ErrorAction SilentlyContinue)) { $sdk = New-MinimalSdk }
    if ($jdk -and $sdk) {
        Write-Host "JDK: $jdk"
        Write-Host "SDK: $sdk"
        $env:JAVA_HOME = $jdk
        $env:ANDROID_HOME = $sdk
        $env:Path = (Join-Path $jdk 'bin') + ';' + $env:Path
        $lp = Join-Path $Launcher 'local.properties'
        $want = 'sdk.dir=' + ($sdk -replace '\\', '/')
        $cur = ''
        if (Test-Path -LiteralPath $lp) { $cur = [System.IO.File]::ReadAllText($lp) }
        if (-not $cur.Contains($want)) { [System.IO.File]::WriteAllText($lp, $want + "`n") }
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
        if ($code -ne 0) { throw "o Gradle falhou (código $code); veja $log" }
    } elseif (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host 'Sem JDK 17 + Android SDK neste PC; compilando no Docker (tools\docker-build.ps1)...' -ForegroundColor Cyan
        & (Join-Path $Repo 'tools\docker-build.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'a compilação no Docker falhou' }
    } else {
        Write-Host ''
        [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'compilacao.log'), "SEM_FERRAMENTAS jdk=$jdk sdk=$sdk`r`n")
        Write-Host 'Não achei JDK 17+ com Android SDK (platform 34 + build-tools 34.0.0), nem o Docker.' -ForegroundColor Yellow
        if ($jdk) { Write-Host "  JDK encontrado: $jdk" } else { Write-Host '  JDK 17+: não encontrado' }
        if ($sdk) { Write-Host "  SDK encontrado: $sdk" } else { Write-Host '  Android SDK com platform 34 + build-tools 34.0.0: não encontrado' }
        Write-Host 'O jeito mais leve: instale o JDK 17 e rode este script de novo:'
        Write-Host '    winget install --id Microsoft.OpenJDK.17 -e' -ForegroundColor White
        Write-Host '(o script então se oferece para preparar o Android SDK mínimo).'
        Write-Host 'Alternativas: Android Studio (winget install Google.AndroidStudio) ou Docker Desktop.'
        exit 1
    }
    if (-not (Test-Path -LiteralPath $Apk)) { throw "o APK não apareceu em $Apk" }
    Write-Host ('APK pronto: {0} ({1:N0} bytes)' -f $Apk, (Get-Item -LiteralPath $Apk).Length) -ForegroundColor Green
}

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
    throw 'adb.exe não encontrado. Rode: winget install --id Google.PlatformTools -e'
}

function Invoke-TvShell([string]$Command) {
    $out = & $script:AdbExe -s $script:Serial shell $Command
    return (($out | Out-String).Trim())
}

function Get-HomeComponent {
    $lines = @((Invoke-TvShell 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -split "`r?`n" | Where-Object { $_ -match '\S' })
    if ($lines.Count -eq 0) { return '' }
    return $lines[$lines.Count - 1].Trim()
}

function Install-Launcher {
    if (-not $Tv) { throw 'passe -Tv <ip da TV>' }
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
        if ($i -eq 0) { Write-Host 'Na TV: aceite "Permitir depuração USB?".' -ForegroundColor Yellow }
        Start-Sleep -Seconds 2
    }
    if (-not $ok) { throw "a TV $($script:Serial) não respondeu ou não autorizou" }

    $tvSdk = [int]((Invoke-TvShell 'getprop ro.build.version.sdk') -replace '\D', '')
    if ($tvSdk -lt 26) { throw "a TV tem SDK $tvSdk; o launcher precisa de 26 ou mais. Nada foi instalado." }

    $homeBefore = Get-HomeComponent
    $homePkg = ($homeBefore -split '/')[0]
    if ($homePkg -eq $Pkg) { $stock = '' ; Write-Host 'A Home já é o launcher novo: só atualizo o APK.' }
    elseif ($KnownStock -contains $homePkg) { $stock = $homePkg ; Write-Host "Launcher original: $stock" }
    else { throw "a Home hoje é '$homeBefore', que não é um launcher original conhecido. Nada foi mudado." }

    & $script:AdbExe -s $script:Serial push $Apk /data/local/tmp/tvhome.apk | Out-Host
    $out = Invoke-TvShell 'pm install -r /data/local/tmp/tvhome.apk; rm -f /data/local/tmp/tvhome.apk'
    Write-Host $out
    if ($out -notmatch 'Success') { throw 'o pm install falhou; o launcher original não foi tocado.' }

    [void](Invoke-TvShell "am force-stop $Pkg")
    $start = Invoke-TvShell "am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n $Main"
    Write-Host $start
    if ($start -notmatch 'Status: ok' -or $start -match '(?m)^Error') { throw 'o launcher novo não abriu; o original continua ativo.' }
    [void](Invoke-TvShell "pm grant $Pkg android.permission.ACCESS_FINE_LOCATION")
    [void](Invoke-TvShell "cmd package compile -m speed -f $Pkg")
    if ($stock) { Write-Host (Invoke-TvShell "pm disable-user --user 0 $stock") }
    Write-Host (Invoke-TvShell "cmd package set-home-activity --user 0 $Main")

    $homeNow = Get-HomeComponent
    if ($homeNow -notlike "$Pkg/*") {
        if ($stock) {
            [void](Invoke-TvShell "pm enable --user 0 $stock")
            [void](Invoke-TvShell "cmd package set-home-activity --user 0 $homeBefore")
        }
        throw "a Home ficou em '$homeNow' e não no launcher novo; o original foi reativado."
    }
    [void](Invoke-TvShell 'input keyevent KEYCODE_HOME')
    Start-Sleep -Seconds 3
    $focus = Invoke-TvShell 'dumpsys activity activities | grep mFocusedApp'
    Write-Host $focus
    if ($focus -notmatch [regex]::Escape($Pkg)) { Write-Warning 'A tela da TV ainda não mostra o launcher novo; aperte Home no controle e confira.' }
    [void](Invoke-TvShell "settings put secure screensaver_components $Pkg/.ClockDream")
    $ErrorActionPreference = $prev
    Write-Host "Pronto: a Home é $homeNow. Protetor de tela: relógio do launcher." -ForegroundColor Green
}

# ---------------------------------------------------------------------------------------------
# Temas e papel de parede (mesmo protocolo do tools\theme.sh do repositório: os arquivos vão para o
# provedor content://com.gathin.tvhome.theme, ou para /sdcard/Android/data/com.gathin.tvhome/files,
# e a tela inicial reinicia). Sem -TrocarDock, o tema muda só o visual: dock, apps ocultos, colunas
# e saudação continuam os do config.xml.
$ThemeUri = 'content://com.gathin.tvhome.theme'
$ThemeDir = '/sdcard/Android/data/com.gathin.tvhome/files'
$LayoutKeys = @('dock_apps', 'hidden_apps', 'live_tv_package', 'columns', 'greeting_name', 'show_greeting')

function Push-ThemeFile([string]$Local, [string]$Name) {
    $stage = '/data/local/tmp/cyt-theme-' + ($Name -replace '/', '-')
    & $script:AdbExe -s $script:Serial push $Local $stage | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "adb push falhou: $Local" }
    $parent = $ThemeDir
    if ($Name.Contains('/')) { $parent = $ThemeDir + '/' + $Name.Substring(0, $Name.LastIndexOf('/')) }
    # Sem aspas duplas: o Windows PowerShell 5.1 não as repassa direito para programas nativos.
    $cmd = 'o=$(content write --uri ' + $ThemeUri + '/' + $Name + ' < ' + $stage + ' 2>&1) && case $o in *Unsupported*|*Error*) false ;; esac || { mkdir -p ' + $parent + '; cp ' + $stage + ' ' + $ThemeDir + '/' + $Name + '; }; rm -f ' + $stage
    [void](Invoke-TvShell $cmd)
}

function Remove-ThemeFile([string]$Name) {
    [void](Invoke-TvShell ('rm -f ' + $ThemeDir + '/' + $Name + ' 2>/dev/null; content delete --uri ' + $ThemeUri + '/' + $Name + ' 2>/dev/null'))
}

function Clear-ThemeWallpapers {
    [void](Invoke-TvShell ('rm -f ' + $ThemeDir + '/wallpapers/*.[jJ][pP][gG] ' + $ThemeDir + '/wallpapers/*.[jJ][pP][eE][gG] ' + $ThemeDir + '/wallpapers/*.[pP][nN][gG] ' + $ThemeDir + '/wallpapers/*.[wW][eE][bB][pP] 2>/dev/null; content delete --uri ' + $ThemeUri + '/wallpapers 2>/dev/null'))
}

function Restart-Home {
    $rev = [guid]::NewGuid().ToString('N')
    [void](Invoke-TvShell ("printf '%s' '" + $rev + "' > /data/local/tmp/cyt-theme-theme_revision"))
    $cmd = 'o=$(content write --uri ' + $ThemeUri + '/theme_revision < /data/local/tmp/cyt-theme-theme_revision 2>&1) && case $o in *Unsupported*|*Error*) false ;; esac || { mkdir -p ' + $ThemeDir + '; cp /data/local/tmp/cyt-theme-theme_revision ' + $ThemeDir + '/theme_revision; }; rm -f /data/local/tmp/cyt-theme-theme_revision'
    [void](Invoke-TvShell $cmd)
    [void](Invoke-TvShell "am force-stop $Pkg")
    [void](Invoke-TvShell 'am start -a android.intent.action.MAIN -c android.intent.category.HOME')
}

function Set-Theme([string]$Folder, [string]$Picture, [switch]$Reset, [switch]$KeepThemeLayout) {
    $tmp = Join-Path $env:TEMP ('cyt-tema-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Force -Path $tmp)
    try {
        [void](Invoke-TvShell "mkdir -p $ThemeDir")
        if ($Reset) {
            foreach ($n in @('config.json', 'wallpaper.jpg', 'wallpapers/captions.txt')) { Remove-ThemeFile $n }
            Clear-ThemeWallpapers
            Restart-Home
            Write-Host 'Tema removido: a tela inicial voltou ao visual do config.xml.' -ForegroundColor Green
            return
        }
        $json = $null
        if ($Picture) {
            if (-not (Test-Path -LiteralPath $Picture)) { throw "imagem não encontrada: $Picture" }
            $json = $null
        } else {
            $cfg = Join-Path $Folder 'config.json'
            if (-not (Test-Path -LiteralPath $cfg)) { throw "a pasta $Folder não tem config.json" }
            $json = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not ($json -is [System.Management.Automation.PSCustomObject])) { throw "$cfg não é um objeto JSON de tema" }
        }
        if ($json -and -not $KeepThemeLayout) {
            foreach ($k in $LayoutKeys) { if ($json.PSObject.Properties[$k]) { $json.PSObject.Properties.Remove($k) } }
        }
        $cfgOut = Join-Path $tmp 'config.json'
        $text = '{}'
        if ($json) { $text = ($json | ConvertTo-Json -Depth 20) }
        if (-not $text -or $text.Trim() -eq '') { $text = '{}' }
        [System.IO.File]::WriteAllText($cfgOut, $text, (New-Object System.Text.UTF8Encoding($false)))
        Push-ThemeFile $cfgOut 'config.json'
        $single = $null
        if ($Picture) { $single = $Picture } elseif (Test-Path -LiteralPath (Join-Path $Folder 'wallpaper.jpg')) { $single = Join-Path $Folder 'wallpaper.jpg' }
        if ($single) { Push-ThemeFile $single 'wallpaper.jpg' } else { Remove-ThemeFile 'wallpaper.jpg' }
        Clear-ThemeWallpapers
        $captions = $null
        if ($Folder -and (Test-Path -LiteralPath (Join-Path $Folder 'wallpapers'))) {
            $imgs = @(Get-ChildItem -LiteralPath (Join-Path $Folder 'wallpapers') -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' -and $_.Name -match '^[A-Za-z0-9_.-]+$' -and $_.Name -notmatch '\.\.' })
            $i = 0
            foreach ($img in $imgs) {
                $i++
                Write-Host ("  papel de parede {0}/{1}: {2}" -f $i, $imgs.Count, $img.Name)
                Push-ThemeFile $img.FullName ('wallpapers/' + $img.Name)
            }
            $cap = Join-Path $Folder 'wallpapers\captions.txt'
            if (Test-Path -LiteralPath $cap) { $captions = $cap }
        }
        if ($captions) { Push-ThemeFile $captions 'wallpapers/captions.txt' } else { Remove-ThemeFile 'wallpapers/captions.txt' }
        Restart-Home
        Write-Host 'Tema aplicado. Aperte Home no controle se a tela ainda não mudou.' -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Connect-Tv {
    if (-not $Tv) { throw 'passe -Tv <ip da TV>' }
    $script:AdbExe = Find-Adb $Adb
    $script:Serial = $Tv
    if ($script:Serial -notmatch ':\d+$') { $script:Serial = "$($Tv):5555" }
    & $script:AdbExe connect $script:Serial | Out-Host
    for ($i = 0; $i -lt 60; $i++) {
        if (((& $script:AdbExe -s $script:Serial get-state) | Out-String).Trim() -eq 'device') { return }
        if ($i -eq 0) { Write-Host 'Na TV: aceite "Permitir depuração USB?".' -ForegroundColor Yellow }
        Start-Sleep -Seconds 2
    }
    throw "a TV $($script:Serial) não respondeu ou não autorizou"
}

if ($Tema -or $PapelDeParede -or $SemTema) {
    $ErrorActionPreference = 'Continue'
    Connect-Tv
    if ($SemTema) { Set-Theme -Reset }
    elseif ($PapelDeParede) { Set-Theme -Picture ((Resolve-Path -LiteralPath $PapelDeParede).Path) -KeepThemeLayout:$TrocarDock }
    else { Set-Theme -Folder ((Resolve-Path -LiteralPath $Tema).Path) -KeepThemeLayout:$TrocarDock }
    exit 0
}
if (-not $SemCompilar) { Invoke-Build }
if (-not $SoCompilar) { Install-Launcher }
