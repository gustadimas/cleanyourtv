# Minha TV: TCL Android TV 11 (plataforma C06)

O que foi feito nesta TV em 10/11/2026 (e os ajustes de 12/11) com o [cleanyourtv](https://github.com/Gathin23/cleanyourtv), e como desfazer ou mudar cada parte. Nada foi desinstalado: os apps foram **desativados** e voltam com um comando.

## A TV

- TCL "Smart TV", plataforma C06 (`C06_2K_GB`), MediaTek MT9221 (`mt5867`), ~920 MB de RAM, painel 1280×720
- Android TV 11 (SDK 30), build AR2101 / AR21, software V8-T221T05-LF1V355, patch de segurança 2025-03-05, `TCL-LA-MT9221-01` (América Latina)
- Lista de referência do repositório: `examples/tcl-40s5400a` (tem uma unidade brasileira igual a esta)

## O que mudou

| Lote | Pacote | O que é |
|---|---|---|
| 1 | `com.tcl.usercenter` | Conta TCL. **O próprio sistema religa a cada boot** (normal nesta plataforma); fica ociosa |
| 1 | `com.tcl.guard` | TGuard, "limpador"/suporte da TCL |
| 1 | `com.tcl.partnercustomizer` | Linhas promocionais da tela inicial original |
| 1 | `com.tcl.waterfall.overseas` | TCL Channel / portal de vídeos |
| 1 | `com.tcl.esticker` | Adesivo de demonstração de loja |
| 1 | `android.autoinstalls.config.tcl.device` | Instalação automática de apps parceiros |
| 1 | `com.google.android.feedback` | Envio de feedback ao Google |
| 2 | `com.google.android.play.games` | Play Games |
| 2 | `com.google.android.syncadapters.calendar` | Sincronização de agenda |
| 2 | `com.google.android.apps.nbu.smartconnect.tv` | Medidor/economia de dados do Google |
| 2 | `com.google.android.tvrecommendations` | Recomendações patrocinadas da tela inicial original |
| 2 | `com.google.android.tungsten.setupwraith` | Assistente da 1ª configuração (o Wi-Fi salvo não é dele; conferido) |
| 3 | `com.netflix.ninja` | Netflix |
| 3 | `com.google.android.youtube.tvmusic` | YouTube Music |
| 3 | `com.google.android.videos` | Google TV (filmes) |
| 3 | `com.google.android.katniss` | Google Assistente / busca por voz |
| 3 | `com.google.android.backdrop` | Protetor de tela com fotos |
| 4 | `com.tcl.t_solo` | T-Solo ("ouvir sozinho": som só no fone Bluetooth) |
| 4 | `com.tcl.suspension` | Painel rápido da TCL |
| 5 | `com.google.android.inputmethod.latin` | Gboard (o teclado em uso é o da TCL, que continua) |
| 6 | `com.tcl.smartalexa` | Alexa da TCL (12/11). **O atualizador da TCL religa a cada boot**; sem conta ela fica parada, e o launcher esconde o ícone. Veja [Alexa](#alexa) |
| - | `com.google.android.tvlauncher` | Tela inicial original, trocada pelo launcher novo (`com.gathin.tvhome`) |

- **Já vinham desativados de fábrica** (não mexi): Chromecast (`com.google.android.apps.mediashell`), Stan, Rakuten TV, voz do Google (`com.google.android.tts`).
- **Mantidos por escolha**: YouTube, Prime Video, Stremio, Crunchyroll (instalado pela Play Store), controle pelo celular (`com.google.android.tv.remote.service`), mídia por USB, atualizador de firmware da TCL (`com.tcl.ttvs`).
- **Intocados (a TV precisa)**: TV ao vivo/HDMI (`com.tcl.tv`, `com.tcl.tvinput`), controle e Bluetooth, configurações TCL, teclados, Play Store e Play Services.
- **DNS privado**: `dns.adguard-dns.com` (bloqueia anúncios e rastreadores por DNS; **não** bloqueia anúncios do YouTube).
- **Protetor de tela**: relógio do launcher novo. **Tema**: `twilight`.
- **Resultado**: RAM livre de ~293 MB para ~365 MB; o launcher novo usa ~30 MB, contra ~116 MB do original.
- **Desempenho dos apps** (10/11, à tarde): veja a seção [Desempenho](#desempenho).
- **Transições do tema** (12/11): voltaram com a escala de animação em 0,5. Veja [Transições do tema](#transições-do-tema).
- **Twitch e Kick** (12/11): instaladas pela Play Store e medidas. Veja [Twitch e Kick](#twitch-e-kick).
- **Barra de cima** (12/11): Central de Mídia e Play Store viraram ícones ao lado de Configurações; embaixo ficam só os apps. Veja [Barra de cima](#barra-de-cima).
- **Design da tela inicial** (12/11): auditoria e ajustes de ícones, hierarquia e legibilidade. Veja [Design da tela inicial](#design-da-tela-inicial).

## Arquivos

| Arquivo | Para quê |
|---|---|
| `debloat.txt` | A lista completa aplicada (os 6 lotes) |
| `lote1-tcl.txt` … `lote6-alexa.txt` | Os lotes, na ordem em que foram aplicados |
| `otimizar-apps.ps1` | Refaz os ajustes de desempenho (rode de novo depois que um app atualizar) |
| `desempenho\` | Medições de desempenho antes e depois |
| `restaurar.ps1` | Desfaz tudo |
| `instalar-launcher.ps1` | Compila e instala o launcher; aplica temas e papel de parede |
| `temas-disponiveis.jpg` | Prévia dos 25 temas oficiais |
| `instalar-tema-terror.ps1` | Instala o tema de terror (assassinos e zumbis de filmes) e o launcher que troca o fundo a cada movimento |
| `terror\` | O tema de terror: imagens dos filmes, o gerador e a pasta `tema\` que vai para a TV (veja `terror\LEIA-ME.md`) |
| `tema-terror-launcher.patch` | A mudança no código do launcher (o original está em `launcher-original\`) |
| `_antigo\` | O tema zumbi com imagens de jogos, que saiu |
| `..\backup\20261110-035758-before\` | Backup de antes: pacotes, getprop, todas as configurações |
| `..\backup\20261110-045117-depois\` | Estado de depois, mais os registros de restauração do `tools/disable.sh` |
| `..\shots\` | Prints da sessão. Mostram o nome do seu Wi-Fi: não publique |

## Antes de qualquer comando: ligar a depuração

Os scripts falam com a TV pelo ADB, que fica **desligado** no dia a dia (a porta 5555 não tem criptografia).

1. Na TV: Configurações > Preferências do dispositivo > Sobre > Opções do desenvolvedor > ligue **Depuração USB** e **Depuração de rede**.
2. O IP da TV está em Configurações > Rede e Internet > sua rede.
3. Rode o comando. Na primeira vez, a TV pergunta "Permitir depuração USB?": escolha Permitir.
4. **Terminou? Desligue as duas opções de novo** e reinicie a TV.

Os comandos abaixo são para o PowerShell. Troque `<ip>` pelo IP da TV.

## Reativar um app

Um só (exemplo: Netflix):

```
C:\platform-tools\adb.exe connect <ip>:5555
C:\platform-tools\adb.exe -s <ip>:5555 shell pm enable com.netflix.ninja
```

Sem PC, na própria TV: Configurações > Apps > Ver todos os apps (mostrando os apps do sistema) > o app > Ativar.

Tudo de uma vez, voltando a tela inicial original, o protetor de fotos e o DNS automático:

```
powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\restaurar.ps1" -Tv <ip>
```

Com `-ManterLauncher`, ele devolve a tela original mas deixa o launcher novo instalado. Os pacotes que já vinham desativados de fábrica continuam como estavam.

## Mudar o dock

- **Na própria TV, sem PC**: segure OK em um app e escolha **Mover**; ou segure OK na pílula **Configurações** > **Editar dock** / **Reordenar apps**. Lá também ficam as **Configurações do launcher** (apps por linha de 4 a 7, relógio de 12/24 h, papel de parede, animações).
- **Como padrão permanente**: edite `launcher\app\src\main\res\values\config.xml` (`dock_apps` na ordem da esquerda para a direita, `columns`, `hidden_apps`, `greeting_name`) e reinstale:

```
powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-launcher.ps1" -Tv <ip>
```

O script compila com o JDK 17 portátil (`%LOCALAPPDATA%\cleanyourtv\jdk-17`) e o Android SDK mínimo (`%LOCALAPPDATA%\Android\Sdk`) que já estão no PC. Só compilar: `-SoCompilar`. Só instalar o APK já compilado: `-SemCompilar`.

## Barra de cima

Desde 12/11 a barra de cima tem os ícones da **Central de Mídia** e da **Play Store**, depois **Entradas** e **Configurações**. Embaixo ficam só os apps:

- Configurações (`com.android.tv.settings`), Central de Mídia e Play Store saíram da grade. A pílula Configurações abre o mesmo app de configurações.
- O botão do Wi-Fi (com o nome da rede) saiu, para os dois ícones caberem sem cortar a data ao lado do relógio. A rede continua em Configurações > Rede e Internet.

Isso está no `config.json` da TV, onde já vale, e no `config.xml` do launcher (`top_bar_apps`, `hidden_apps`, `show_network_pill`), para valer também quando o launcher for recompilado. Trocar de tema com `instalar-launcher.ps1 -Tema` regrava o `config.json` e não recompila: se a barra voltar ao jeito antigo depois disso, rode `instalar-launcher.ps1 -Tv <ip>` uma vez (o `instalar-tema-terror.ps1` já recompila).

Para outro app virar ícone lá em cima, acrescente o pacote em `top_bar_apps` no `config.xml` e reinstale o launcher. A posição dos ícones é `top_bar_apps_position`: `start` (antes de Entradas, o atual), `end` (depois de Configurações) ou `network` (ao lado do Wi-Fi, o padrão do launcher). Para o Wi-Fi voltar, `show_network_pill` em `true` (a data volta a ficar apertada com os dois ícones).

## Design da tela inicial

Auditoria de 12/11, medida na própria TV (posição de cada elemento pelo `uiautomator` e contraste dos textos sobre os fundos do tema). O que mudou:

| Problema | Ajuste | Onde |
|---|---|---|
| Barra de cima com dois estilos: ícones brancos (Entradas, Configurações) e logotipos coloridos (Central de Mídia, Play Store); o da Central de Mídia era um quadrado azul ilegível | Glifos brancos no mesmo estilo (Material "video_library" e "shop"), que ficam escuros no foco como as pílulas | `top_bar_icons` no `config.xml`, `res/drawable/ic_top_*.xml` (recompila) |
| Ícones redondos entre as duas pílulas com nome (pílula, ícone, ícone, pílula), sem agrupamento | Ícones antes de Entradas: os dois redondos juntos, as duas pílulas com nome juntas, e Configurações no canto superior direito, onde se procura | `top_bar_apps_position` = start (recompila) |
| Dois textos gigantes disputando: o relógio e o nome do app em foco ("YouTube") acima do dock, fora da linha dos tiles | Sem o nome grande; o brilho do foco já mostra o app | `dock_title` = false |
| Fileira de baixo cortada pela borda (só 29 px da Kick e da Twitch) | Testei a fileira inteira (`rows_below_dock` = 1), mas ela ocupava muito da tela e acabava com a descida para ver os apps de baixo. Voltou ao jeito anterior, que deixa o fundo à mostra | `rows_below_dock` = 0 (como era) |
| Saudação e data a 55% e 65% de branco, sem sombra, sobre fotos escurecidas só 12%: contraste de 1,3 a 1,8:1 em fundos claros (o mínimo para texto pequeno é 4,5:1) | Data em branco cheio, saudação a 70%, e um degradê escuro suave só no alto da tela (o resto da foto fica intacto) | `header_white` = true, `top_scrim` = true, `res/drawable/top_scrim.xml` (recompila) |

Ficou como estava, por já estar bom: o vidro com branco nas pílulas, o foco invertido igual em todos os botões, os espaços (13 px) e alturas (56 px) da barra, as margens dentro da área segura da TV. Detalhes aceitáveis: a legenda do fundo termina 8 px antes da borda da barra, e a barra fica uns 8 px abaixo do centro do relógio.

Para desfazer um item: o valor antigo no `config.xml` (`dock_title` true, `header_white` false, `top_scrim` false, `top_bar_icons` vazio, `top_bar_apps_position` network) e `instalar-launcher.ps1 -Tv <ip>`. Os dois primeiros também valem na hora pelo `config.json` da TV.

## Papel de parede e temas

Com o mesmo script, sem recompilar nada. O seu dock e a saudação continuam os mesmos (use `-TrocarDock` se quiser que o tema mude isso também):

```
# um dos 25 temas oficiais (veja temas-disponiveis.jpg)
...\instalar-launcher.ps1 -Tv <ip> -Tema "E:\Misc Projects\cleanyourtv\themes\aerial"
# uma foto sua (ideal 1280x720 ou 1920x1080)
...\instalar-launcher.ps1 -Tv <ip> -PapelDeParede "C:\Fotos\minha-foto.jpg"
# voltar ao fundo preto
...\instalar-launcher.ps1 -Tv <ip> -SemTema
```

**Tema próprio**, como o do seu amigo: uma pasta com um `config.json` (só `{}` já serve) e uma `wallpaper.jpg`, ou uma subpasta `wallpapers\` com várias imagens (nomes só com letras, números, `-`, `_` e `.`) e, no `config.json`, `{"wallpaper_rotation_minutes": 30}` para trocar a cada 30 minutos. Uma `wallpapers\captions.txt` com linhas `arquivo.jpg<TAB>Legenda` mostra a legenda embaixo dos botões. As opções de tema estão em `themes\README.md`.

**Tema de terror** (assassinos de filmes slasher e filmes de zumbi): `instalar-tema-terror.ps1 -Tv <ip>` compila o launcher com a troca de fundo a cada movimento e envia os 240 fundos. Cada movimento sorteia um filme; parado na tela inicial, a ameaça se aproxima. Detalhes em `terror\LEIA-ME.md`.

Forks com visual diferente (lista em `SHOWCASE.md`) não são temas: trocam o launcher inteiro por outro APK.

## Botões do controle

- Home, Input, engrenagem e os botões de apps funcionam (testado com o controle).
- **Microfone**: sem função, porque o Assistente foi desativado. Para voltar: `pm enable com.google.android.katniss`.
- **Netflix**: sem função, porque a Netflix foi desativada.

## DNS AdGuard

Para desfazer: Configurações > Rede e Internet > DNS privado > Automático. Ou:

```
C:\platform-tools\adb.exe -s <ip>:5555 shell settings put global private_dns_mode opportunistic
```

Se um dia você usar Pi-hole/AdGuard Home ou VPN no roteador, desligue o DNS privado da TV: ele passa por cima do DNS do roteador.

## Depois de uma atualização de firmware

O atualizador da TCL foi mantido. Depois de uma atualização, ligue a depuração e confira se algo voltou comparando com `debloat.txt`:

```
C:\platform-tools\adb.exe -s <ip>:5555 shell pm list packages -d
```

Se voltou algum (além da conta TCL e da Alexa, que sempre voltam), desative de novo: `shell pm disable-user --user 0 <pacote>`. Veja também `docs\firmware-updates.md`.

## A ponte desta sessão

A pasta `..\work\bridge\` (o `bridge.ps1`) só serviu para o Claude falar com a TV nesta sessão. Pode apagar a pasta inteira.

## Desempenho

O limite desta TV é o hardware: 4 núcleos Cortex-A55 a 1,45 GHz e ~920 MB de RAM. Os apps grandes ocupam muita memória: o Prime Video sozinho usa ~250 MB, mais ~80 MB comprimidos na swap. Medido com a mesma sequência de teclas, antes e depois dos ajustes:

| | Prime Video antes | Prime Video depois | Crunchyroll antes | Crunchyroll depois |
|---|---|---|---|---|
| Quadros lentos navegando (>33 ms) | 19–20% | 11–13% | 10–16% | 0–5% |
| 10% mais lentos (p90) | 50–66 ms | 34 ms | 65–81 ms | 17–44 ms |
| Piores travadas (p99) | 200–250 ms | 83–100 ms | 85–233 ms | 33–48 ms |
| Memória livre com o app aberto | 165–178 MB | 208–261 MB | ~295–315 MB | ~315–330 MB |

O que foi feito:

- **Compilação completa** (`cmd package compile -m speed`) de YouTube, Prime Video, Stremio e Crunchyroll (e da Kick, em 12/11), em vez de só os trechos mais usados. Foi o que mais reduziu as travadas. Custou ~130 MB de armazenamento. **Uma atualização do app pela Play Store desfaz isso**: depois de atualizar, rode `otimizar-apps.ps1 -Tv <ip>` de novo.
- **Stremio restrito em segundo plano**: o servidor dele (~200 MB com o app aberto) era recriado pelo Android sem parar depois que você saía, ocupando ~100 MB à toa. Agora ele roda só com o Stremio aberto. Se um dia usar um player externo no Stremio (VLC, Just Player…), rode `otimizar-apps.ps1 -Tv <ip> -Desfazer`.
- **Twitch e Kick restritas em segundo plano** (12/11): veja [Twitch e Kick](#twitch-e-kick).
- **Gboard desativado** (lote 5): ~15 MB; o teclado da TCL continua (testado).

Testado e descartado:

- **DNS AdGuard**: só ~30 ms a mais por consulta nova (~114 ms contra ~82 ms pelo roteador); não pesa.
- **Animações do sistema**: vinham zeradas de fábrica, o que também apagava as transições do tema. Em 12/11 a do animador foi para 0,5: veja [Transições do tema](#transições-do-tema).
- **Trailers automáticos no Prime**: o destaque é uma imagem parada; nenhum vídeo tocava.
- **Liberar memória em segundo plano**: não muda a fluidez dentro do app, mas reduz as vezes em que o sistema mata o app e ele precisa abrir do zero (no dia dos ajustes, antes deles, o Prime foi morto 3 vezes).
- **Alexa**: era mantida por escolha; saiu em 12/11. Veja [Alexa](#alexa).

Dica: desligar pelo controle **não reinicia** esta TV (ela entra num modo de espera rápido; ficou mais de 12 h sem reiniciar). Com o tempo a memória comprimida enche (433 MB depois de 12 h, contra bem menos logo após ligar). Se os apps começarem a ficar lentos, **reinicie de verdade**: Configurações > Preferências do dispositivo > Sobre > Reiniciar.

Os números de cada medição estão em `desempenho\` (1-antes, 2-sem-pesos, 3-speed, 4-depois; 5-escala0/05/1 e 6-anim05 para as transições; 7-twitch-kick, 8-kick-speed e 8-twitch-speed para os apps novos).

## Transições do tema

O tema troca o papel de parede com efeitos (esmaecer, aproximar, "estática", "lâmpada"), mas esta TV veio de fábrica com as três escalas de animação do Android em 0. Com a **escala de duração do animador** em 0, o Android pula todas as animações feitas com o animador do sistema, e as transições do launcher usam esse animador: o fundo trocava de uma vez, sem efeito nenhum.

Em 12/11 só essa escala foi para **0,5** (metade da duração normal). As outras duas (janela e transição) continuam em 0, então os apps continuam abrindo sem animação de janela. Medido na tela inicial, andando pelo dock:

| Escala do animador | Cada movimento | Custo |
|---|---|---|
| 0 (de fábrica) | troca seca, ~150 ms | nenhum |
| **0,5 (atual)** | transição de ~500 ms, ~28 quadros (~56 por segundo) | quase nenhum: com a tela parada nada é desenhado |
| 1 (padrão do Android) | ~830 ms, ~49 quadros | o mesmo, só mais lento de navegar |

Prime Video e Crunchyroll medidos de novo com 0,5 ficaram dentro da variação normal (Prime 14% de quadros lentos, Crunchyroll 4%; Crunchyroll abriu no mesmo tempo).

Para mudar: Configurações > Preferências do dispositivo > Sobre > Opções do desenvolvedor > **Escala de duração do Animator** (só essa). Ou pelo PC:

```
C:\platform-tools\adb.exe -s <ip>:5555 shell settings put global animator_duration_scale 1
C:\platform-tools\adb.exe -s <ip>:5555 shell settings put global animator_duration_scale 0
```

(1: transição mais longa; 0: como veio de fábrica, sem transição.) O `restaurar.ps1` volta para 0.

**Uma transição só, a de TV** (12/11): o tema de terror sorteava a troca de fundo (quase sempre um empurrão, às vezes estática ou lâmpada falhando). Agora toda troca, inclusive as etapas da aproximação, usa a **estática de TV**, com **0,6 s** na tela, contra uns 0,16 s antes (os 320 ms dela, cortados pela metade pela escala do animador). O launcher ganhou duas opções no `config.json` do tema, também gravadas em `terror\tema\config.json` e no `terror\gerar_tema.py`:

- `"focus_style"`: `"static"` (a de TV), ou `"mix"` para voltar à mistura; também aceita `"push"`, `"fade"`, `"flicker"` e `"slow"`.
- `"focus_style_ms"`: quanto tempo a transição fica na tela, em milissegundos de verdade (o launcher compensa a escala do animador). Mais tempo, mais aparente; 0 usa o tempo próprio de cada efeito.

De quebra, a "lâmpada falhando" ficou presa a no máximo 3 piscadas por segundo mesmo com a escala em 0,5 (com a escala, ela piscava rápido demais).

## Twitch e Kick

Instaladas em 12/11 pela Play Store da própria TV (Twitch 13.0.0.3, Kick 1.10.0) e medidas com a mesma sequência de teclas dos outros apps:

| | Twitch | Kick (padrão) | Kick (compilada) |
|---|---|---|---|
| Abrir do zero | 1,7–3,3 s | 1,1 s | 1,2 s |
| Quadros lentos navegando (>33 ms) | 15% | 9% | 5% |
| Piores travadas (p99) | 100–133 ms | 84 ms | 67–101 ms |
| Memória com o app aberto (PSS) | ~120–130 MB | ~173 MB | ~175–180 MB |

- **Fechadas, não pesam**: ao sair, a TV encerra as duas e a memória livre volta ao mesmo valor (~380 MB). No boot, o gerenciador da própria TCL já impede as duas de iniciar sozinhas (conferido em dois reboots).
- **Armazenamento**: ~140 MB juntas (apps, compilação e cache); sobram ~1,3 GB.
- **Kick compilada por inteiro** (`speed`): os quadros lentos caíram de 9% para 5%. Está no `otimizar-apps.ps1`.
- **Twitch não**: a tela dela é uma página web dentro do WebView. Compilada, continuou em 16%, então voltou ao padrão. Navegando, ela fica no nível do Prime Video; a Kick compilada, no do Crunchyroll.
- **As duas restritas em segundo plano**: a Twitch deixava uma tarefa a cada ~15 min para alimentar os canais da tela inicial original do Google (que não é usada aqui), e a Kick acordava para mandar telemetria. Com o app aberto nada muda, e a TV não mostra notificações desses apps. Para desfazer: `otimizar-apps.ps1 -Tv <ip> -Desfazer`.
- **O que não dá para mudar**: a tela inicial da Kick toca uma live no fundo (é o que mais pesa nela), e o app não tem opção para desligar isso; nas configurações dela só há idioma e filtro de conteúdo. A Twitch também não tem ajustes de desempenho (só perfil, ajuda e privacidade). A qualidade do vídeo se escolhe no player; em Automático ela se ajusta à rede.
- **Uma atualização pela Play Store** volta a Kick à compilação padrão: rode `otimizar-apps.ps1` de novo. A restrição em segundo plano continua.

## Alexa

Desativada em 12/11 (lote 6), a pedido:

1. Com `pm disable-user` ela saiu, mas **voltou depois do reboot**: quem religa é o `com.tcl.ttvs`, o atualizador da TCL (mantido). Como a TV estava conectada à conta Amazon, ele também abria o processo da Alexa a cada boot (~80 MB).
2. A conta foi **desconectada** no próprio app da TV (Funciona com Alexa > Sair); o servidor da TCL confirmou.
3. Desativada de novo e reboot: ela volta ativada (o TTVS faz isso sempre), mas agora **fica parada**, sem processo nenhum (conferido 5 minutos depois do boot).
4. O ícone dela foi escondido na tela inicial (`hidden_apps`), já que o TTVS a religa a cada boot. Está no `config.json` da TV e no `config.xml` do launcher. Trocar de tema com `instalar-launcher.ps1 -Tema` regrava o `config.json` sem essa lista e não recompila; se o ícone da Alexa reaparecer depois disso, rode `instalar-launcher.ps1 -Tv <ip>` uma vez (recompila com o `config.xml` novo). O `instalar-tema-terror.ps1` já recompila.

`com.tcl.micmanager` (o microfone da TCL) ficou como estava: ele não roda nesta TV.

Para usar a Alexa de novo:

```
C:\platform-tools\adb.exe -s <ip>:5555 shell pm enable com.tcl.smartalexa
C:\platform-tools\adb.exe -s <ip>:5555 shell am start -n com.tcl.smartalexa/.view.activity.MainActivity
```

e escolha **Habilitar Alexa**. Para o ícone voltar, tire `com.tcl.smartalexa` de `hidden_apps` no `config.xml`, reinstale o launcher e reaplique o tema (isso regrava o `config.json` da TV sem a lista).
