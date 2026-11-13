<#
  Tema zumbi na TV TCL: compila o launcher com a troca de fundo a cada movimento (chave focus_wallpapers)
  e envia o tema (45 imagens de Left 4 Dead, The Walking Dead, DayZ, Back 4 Blood e Project Zomboid).
  Cada vez que você mexe no controle, o fundo sorteia um jogo diferente para aquele app.

  Uso (PowerShell), com a Depuração USB e a Depuração de rede ligadas na TV:
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-tema-zumbi.ps1" -Tv <ip da TV>

  Só reenviar o tema, sem compilar de novo:
    ... instalar-tema-zumbi.ps1 -Tv <ip> -SoTema

  Voltar ao tema de antes (twilight):
    powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-launcher.ps1" -Tv <ip> -Tema "E:\Misc Projects\cleanyourtv\themes\twilight"

  O código original do launcher está em minha-tv\launcher-original\ (WallpaperPlayer.java e MainActivity.java).
#>
param(
    [Parameter(Mandatory = $true)][string]$Tv,
    [switch]$SoTema
)
$ErrorActionPreference = 'Stop'
$Instalar = Join-Path $PSScriptRoot 'instalar-launcher.ps1'
$Tema = Join-Path $PSScriptRoot 'tema-zumbi'
if (-not $SoTema) {
    Write-Host '1/2 Compilando e instalando o launcher (alguns minutos)...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Instalar -Tv $Tv
    if ($LASTEXITCODE -ne 0) { throw 'a compilação ou a instalação falhou; veja as mensagens acima' }
}
Write-Host '2/2 Enviando o tema zumbi (45 imagens)...' -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File $Instalar -Tv $Tv -Tema $Tema
if ($LASTEXITCODE -ne 0) { throw 'o envio do tema falhou; veja as mensagens acima' }
Write-Host 'Pronto. Mexa no controle: cada movimento troca o fundo.' -ForegroundColor Green
