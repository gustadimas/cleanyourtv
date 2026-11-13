# Fire TV Stick Lite: limpeza e tela inicial nova (10/11/2026)

Fire TV Stick Lite 1ª geração (AFTSS, "sheldon"), Fire OS 7.7.1.7 (PS7717.5746N), Android 9 (SDK 28),
~920 MB de RAM, 1080p. Tudo é reversível: nada foi desinstalado.

## O que foi feito

- **41 pacotes desativados** (`pm disable-user --user 0`), em 4 lotes com print entre eles, todos em `debloat.txt`:
  - `lote1-telemetria.txt` (14): métricas, logs, ACR, o envio de senhas de Wi-Fi para a Amazon (`wifilocker`)...
  - `lote2-anuncios.txt` (15): anúncios da tela inicial, ID de publicidade, recomendações, Shopping, Fire TV
    Channels, aba "Ao vivo", pop-ups e "novidades".
  - `lote3-apps-amazon.txt` (8): Amazon Kids, Music, Photos, Silk e atalhos de sites, tutoriais.
  - `lote4-streaming.txt` (4): Netflix, Disney+, IBO Pro e miniTV (escolha sua).
  - Base: `cleanyourtv/examples/amazon-fire-tv-stick-lite-2020` (mesmo modelo e build, testada com reboot).
- **Mantidos por escolha**: Alexa completa (voz, alarmes, música, multi-room, dicas, casa inteligente),
  app Fire TV no celular, espelhamento (Miracast), transmitir do celular (DIAL/fling), atualizações do
  Fire OS, YouTube, Prime Video, Stremio, Crunchyroll, Twitch, Kick, VLC, Aptoide e Downloader.
  O launcher da Amazon continua ativo (ele abriga as Configurações).
- **Privacidade** (Configurações > Preferências > Configurações de privacidade): desligados "Dados de uso
  do dispositivo", "Coletar dados de uso de aplicativos" e "Anúncios baseados em interesses".
- **Conteúdo em destaque**: autoplay de vídeo e de áudio já vinham desligados.
- **Animações em 0,5x** (janela, transição e animador).
- **DNS privado AdGuard** (`dns.adguard-dns.com`): bloqueia anúncios e rastreio por DNS (testado: anúncios
  do Google e da Amazon e as métricas da Amazon caem em 127.0.0.1). **Não** bloqueia anúncios do YouTube.
  YouTube conferido tocando vídeo depois.
- **Tela inicial nova**: o launcher do `fire-tv-cleanup` (`com.gathin.tvhome`) com dock de 6 (YouTube,
  Prime Video, Stremio, Crunchyroll, Twitch, Kick), fotos que mudam com a hora do dia, redirecionamento do
  Home (serviço de acessibilidade "Tela inicial") e protetor de tela de fotos com relógio, sem anúncios.

## Medido (antes → depois)

| | Antes (11 dias ligado, sem limpeza) | Depois (7 min após reiniciar, com tudo) |
|---|---|---|
| Estado da memória (`dumpsys meminfo`) | **critical** | **normal** |
| RAM livre (inclui cache) | 118 MB | 263 MB |
| RAM usada | 903 MB | 731 MB |
| Em swap (zram) | 226 MB | 190 MB |
| MemAvailable | 209 MB | 237 MB |

Parte do ganho é do próprio reinício: reinicie de vez em quando (Configurações > Minha Fire TV > Reiniciar).
O launcher novo usa ~55 MB na frente e ~50 MB atrás de um app; o da Amazon continua carregado (~40-70 MB).
DNS: consulta nova a sites populares ~45 ms pelo AdGuard contra ~17 ms pelo roteador (+30 ms, igual à TCL;
o Android guarda as respostas em cache, então não se sente).

## Como usar a tela nova

- **Home**: a tela da Amazon aparece por **~5 s** antes da nova. É uma proteção do Android (por 5 s depois do
  Home, apps comuns não podem abrir telas) e o Fire OS não deixa trocar o Home (testado: `set-home-activity`
  é ignorado). **Voltar** (←) a partir de um app volta direto, sem espera.
- **Baixo**: a grade com os outros apps (Aptoide, Downloader, VLC).
- **Menu (≡) ou segurar OK num app**: Fixar no dock / Tirar do dock / Mover à esquerda ou direita /
  Informações do app. O dock fica salvo no aparelho.
- **Engrenagem**: abre as Configurações; Voltar retorna à tela nova. **Menu na engrenagem**: "Usar a tela
  inicial da Amazon" (desliga o redirecionamento; Menu de novo para voltar a "Usar esta tela inicial").
- **Segurar Home**: Perfis, **Aplicativos** (todos os apps e a **Appstore**), Modo de suspensão,
  Espelhamento e Configurações.
- O botão "Entradas" fica escondido: o stick não tem HDMI de entrada nem TV ao vivo.

## Desfazer

- **Tudo**: `powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\fire-tv-cleanup\meu-firestick\restaurar.ps1" -Tv <ip>`
  (reativa os 41 pacotes, devolve a tela e o protetor da Amazon, remove o launcher, animações 1x, DNS
  automático). Com `-ManterLauncher`, só volta para a tela da Amazon e deixa o launcher instalado.
- **Um app só**: `C:\platform-tools\adb.exe -s <ip>:5555 shell pm enable <pacote>` (os nomes estão em `debloat.txt`).
- **DNS**: `adb -s <ip>:5555 shell settings put global private_dns_mode opportunistic`.
  Se um dia o roteador tiver Pi-hole/AdGuard Home ou VPN por domínio, desligue o DNS privado do stick: ele
  passa por cima do DNS do roteador.
- **Animações**: `settings put global window_animation_scale 1.0` (e `transition_animation_scale`, `animator_duration_scale`).
- **Privacidade**: pelo mesmo menu (Configurações > Preferências > Configurações de privacidade).
- **Depois de uma atualização do Fire OS** que religar algo: `desativar.ps1 -Tv <ip>` reaplica a lista, e
  `instalar-launcher.ps1 -Tv <ip> -SemCompilar` refaz o redirecionamento e o protetor de tela.

## Mudar o dock, as colunas ou o papel de parede

- **Dock**: o mais fácil é na TV (Menu num app). O dock inicial está em
  `launcher\app\src\main\res\values\config.xml` (`dock_apps`, na ordem). O dock salvo na TV vale mais que o
  config.xml; para voltar ao do arquivo: `adb -s <ip>:5555 shell pm clear com.gathin.tvhome` e rode o instalador.
- **Colunas** (`columns`, hoje 6): é também o máximo de apps no dock. A grade alarga sozinha (células de 80 dp).
- **Apps escondidos**: `hidden_apps` no mesmo arquivo.
- **Papel de parede**: 4 fotos por hora do dia em `launcher\app\src\main\res\drawable-nodpi\`:
  `bg_morning.jpg` (5-12 h), `bg_afternoon.jpg` (12-17 h), `bg_evening.jpg` (17-22 h), `bg_night.jpg` (22-5 h).
  Troque por JPGs seus de 1920x1080 com os mesmos nomes. O protetor de tela usa `saver_01.jpg` a `saver_12.jpg`.
- **Nome na saudação**: em `launcher\local.properties`, acrescente `tvhome.userName=Dimas`.
- Depois de qualquer mudança: `instalar-launcher.ps1 -Tv <ip>` (compila e instala; ~1 min).

## Ajustes feitos no launcher do fire-tv-cleanup (só nesta cópia)

- `res/values/config.xml`: dock de 6, `columns` 6, sem TV ao vivo, "FireTV Troubleshooting" escondido (é um stub sem ícone).
- `res/values-pt/strings.xml`: textos em português; `strings.xml` ganhou 2 textos que estavam fixos no código.
- `MainActivity`: grade com células de 80 dp para qualquer número de colunas (com 6 o dock se encostava);
  "Entradas" some quando não há entradas; Esquerda no Wi-Fi não sai da barra; a engrenagem abre as
  Configurações avulsas do Fire OS 7 (`MainSettingsActivity`), das quais o Voltar retorna ao launcher.
- `AppAdapter`: o ícone do próprio app, em alta resolução, preenche o quadrado inteiro (cantos arredondados pelo
  próprio launcher), como no exemplo do autor; ícones redondos ou com borda ficam pequenos no quadrado cinza.
  O exemplo do autor usa desenhos dos logotipos feitos por `tools/make_dock_icons.py`, que não foi usado aqui.
- `HomeRedirectService`: quando a Amazon abre as Configurações como aba da tela dela (por exemplo pela Alexa),
  abre as Configurações avulsas por cima, para o Voltar não deixar você preso na tela da Amazon.
- `build.gradle`: build release assinado com a chave de debug, e a regra de lint da Google Play desligada
  (o app é instalado por ADB).
- `ic_launcher.png` e `banner.png`: eram JPEG com extensão .png e o compilador recusava; convertidos para PNG.

## Arquivos

- `debloat.txt` e `lote1..4`: o que foi desativado. `restaurar.ps1`, `desativar.ps1`, `instalar-launcher.ps1`.
- `compilacao.log`: o log da última compilação.
- Backups: `..\backup\20261110-150625-antes` (pacotes, getprop, settings, memória) e `..\backup\*-depois`.
- Prints: `..\screenshots` (não compartilhe: aparecem a conta do YouTube e o perfil).

## Particularidades deste Fire Stick

- A **Depuração ADB continuou ligada depois de reiniciar** (no Fire OS 7 deste stick; a anotação de que ela
  desliga a cada reinício veio de um Fire TV com Fire OS 8). Ela **ficou ligada por escolha sua** (porta 5555
  aberta na rede, só para computadores já autorizados). Para desligar: Configurações > Minha Fire TV >
  Opções do desenvolvedor > Depuração ADB, ou `adb -s <ip>:5555 shell settings put global adb_enabled 0`.
- Nenhum pacote da lista foi recusado como "protegido".
- `com.android.nfc` já vinha desativado de fábrica.
- No teste do `set-home-activity`, o launcher da Amazon ficou registrado como Home preferido: é o mesmo que o
  Fire OS já abre, então não muda nada (e some se você restaurar de fábrica).
