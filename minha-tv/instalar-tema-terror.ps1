<#
  Tema de terror na TV TCL: assassinos de filmes slasher + filmes de zumbi (e a série The Walking Dead).
  Cada movimento no controle sorteia um filme e uma cena que não apareceram há pouco, com um efeito de troca.
  Parado na tela inicial, a ameaça do filme na tela se aproxima em 3 etapas, e qualquer tecla a manda embora.

  Uso (PowerShell), com a Depuração USB e a Depuração de rede ligadas na TV:
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-tema-terror.ps1" -Tv <ip da TV>

  Opções (junte quantas quiser):
    -SoTema                 só reenvia as imagens e as opções, sem compilar de novo
    -Conjunto assassinos    só os assassinos (ou -Conjunto zumbis; o padrão é tudo)
    -Parado 0.25            minutos parado por etapa da aproximação (0.25 = 15 s, bom para testar; 0 desliga)
    -Som                    liga os sons da aproximação e da imagem rara
    -SemEfeitos             troca simples, sem efeitos (se a TV ficar lenta)
    -Diagnostico            não instala nada: mostra o registro da aproximação na TV (para mandar ao Claude)

  Voltar ao tema de antes (twilight):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-launcher.ps1" -Tv <ip> -Tema "E:\Misc Projects\cleanyourtv\themes\twilight"

  O código original do launcher está em minha-tv\launcher-original\, e a mudança em tema-terror-launcher.patch.
#>
param(
    [Parameter(Mandatory = $true)][string]$Tv,
    [switch]$SoTema,
    [ValidateSet('tudo', 'assassinos', 'zumbis')][string]$Conjunto = 'tudo',
    [ValidateRange(0, 60)][double]$Parado = 1,
    [switch]$Som,
    [switch]$SemEfeitos,
    [switch]$Diagnostico
)
$ErrorActionPreference = 'Stop'
$Instalar = Join-Path $PSScriptRoot 'instalar-launcher.ps1'
$Tema = Join-Path $PSScriptRoot 'terror\tema'
$Assassinos = @('halloween', 'sexta13', 'pesadelo', 'panico', 'massacre', 'chucky', 'freddyjason', 'terrifier')
$Zumbis = @('noite68', 'despertar78', 'madrugada04', 'dia85', 'exterminio', 'exterminio2', 'rec', 'guerraz', 'busan', 'peninsula', 'alive', 'twd')

if ($Diagnostico) {
    $adb = $null
    $cmd = Get-Command 'adb.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $adb = $cmd.Source }
    foreach ($c in @('C:\platform-tools\adb.exe', (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'), (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\adb.exe'))) {
        if (-not $adb -and (Test-Path -LiteralPath $c)) { $adb = $c }
    }
    if (-not $adb) { throw 'adb.exe não encontrado' }
    $serial = $Tv
    if ($serial -notmatch ':\d+$') { $serial = "$($Tv):5555" }
    & $adb connect $serial | Out-Null
    Write-Host 'Registro da aproximação (as últimas 60 linhas):' -ForegroundColor Cyan
    & $adb -s $serial logcat -d -s TvHome.Approach:I | Select-Object -Last 60
    return
}

if (-not (Test-Path -LiteralPath (Join-Path $Tema 'config.json'))) { throw "não achei o tema em $Tema" }

if (-not $SoTema) {
    Write-Host '1/2 Compilando e instalando o launcher (alguns minutos)...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Instalar -Tv $Tv
    if ($LASTEXITCODE -ne 0) { throw 'a compilação ou a instalação falhou; veja as mensagens acima' }
}

# Uma pasta temporária com só o conjunto escolhido e as opções pedidas.
$tmp = Join-Path $env:TEMP ('tema-terror-' + [guid]::NewGuid().ToString('N'))
$wp = Join-Path $tmp 'wallpapers'
[void](New-Item -ItemType Directory -Force -Path $wp)
try {
    $sets = switch ($Conjunto) { 'assassinos' { $Assassinos } 'zumbis' { $Zumbis } default { $Assassinos + $Zumbis } }
    $imgs = @(Get-ChildItem -LiteralPath (Join-Path $Tema 'wallpapers') -Filter '*.jpg' -File |
        Where-Object { $sets -contains ($_.BaseName -split '-')[0] })
    if ($imgs.Count -eq 0) { throw "nenhum fundo de '$Conjunto' em $Tema\wallpapers" }
    $names = @{}
    foreach ($img in $imgs) { Copy-Item -LiteralPath $img.FullName -Destination $wp; $names[$img.Name] = $true }
    $caps = @(Get-Content -LiteralPath (Join-Path $Tema 'wallpapers\captions.txt') -Encoding UTF8 |
        Where-Object { $names.ContainsKey(($_ -split "`t")[0]) })
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines((Join-Path $wp 'captions.txt'), [string[]]$caps, $utf8)
    $cfg = Get-Content -LiteralPath (Join-Path $Tema 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $cfg.focus_idle_minutes = $Parado
    $cfg.focus_effects = -not $SemEfeitos.IsPresent
    $cfg.focus_sounds = $Som.IsPresent
    [System.IO.File]::WriteAllText((Join-Path $tmp 'config.json'), ($cfg | ConvertTo-Json -Depth 10), $utf8)

    Write-Host ('2/2 Enviando o tema ({0} fundos, {1}); leva alguns minutos...' -f $imgs.Count, $Conjunto) -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Instalar -Tv $Tv -Tema $tmp
    if ($LASTEXITCODE -ne 0) { throw 'o envio do tema falhou; veja as mensagens acima' }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'Pronto. Mexa no controle: cada movimento troca o fundo. Parado na tela inicial, alguma coisa se aproxima.' -ForegroundColor Green
