# Fire TV Stick Lite: tema "apocalipse zumbi" com navegação que muda a imagem — pesquisa (10/11/2026)

**Mudou de novo (11/11): tudo vai para a TV TCL, num tema só com assassinos de filmes slasher e filmes de zumbi, e o Fire Stick fica no padrão. Veja as seções 11 e 12 (a segunda volta: sem repetição, aproximação visível, efeitos e sons).** Base original: o launcher do fork instalado hoje no stick (`com.gathin.tvhome` 2.0). Contexto do aparelho em `claude/firestick-lite-limpeza.md`.

## Resumo

- **O launcher do stick não tem sistema de temas.** O do cleanyourtv (3.4, o da TCL) tem: uma pasta com `config.json` + fotos, enviada por `tools/theme.ps1`. O tema do Lula do seu amigo provavelmente foi feito assim. Só que o cleanyourtv não pega o Home no Fire OS (`docs/TROUBLESHOOTING.md`, seção Fire TV), e o fork já tem o redirecionamento do Home funcionando neste stick. Por isso, aqui o tema vira imagens + código dentro do APK do fork, compilado no Windows pelo `instalar-launcher.ps1`.
- **O efeito "cada navegação mostra uma imagem diferente" já existe no Apple TV**: é o Top Shelf. Quando um app da fileira de cima está selecionado, o topo da tela mostra conteúdo dele. No fork, o ponto de entrada é `MainActivity.onDockFocused()` → `showHero()`. Hoje ele só troca o nome do app e a cor do brilho.
- **Recomendação: um tema único, "ABRIGO 7".** Cada app é uma câmera de segurança, e trocar de app troca a câmera com chiado. De madrugada, a tela vira lanterna. O Wi-Fi vira rádio e a grade (Baixo) vira o porão. Se você ficar parado, a horda se aproxima. Há outros 6 conceitos na seção 3.
- **Cabe no stick** se as imagens de cada app forem decodificadas em 960x540 (≈1 MB cada) fora da thread principal. O fundo de cada hora do dia continua em 1920x1080.
- **Começo mais barato (Fase 0):** trocar as 4 fotos da hora, as 12 do protetor e as saudações. Não precisa de código, só de um build.

## 1. O que o launcher do stick já tem (e onde mexer)

| Na tela | Hoje | Gancho no código | No tema |
|---|---|---|---|
| Fundo | 4 fotos de Manhattan por período (manhã 5–12 h, tarde 12–17, noite 17–22, madrugada 22–5), troca com fade de 600/900 ms | `updateBackground()`, `dayPart()`, `BACKGROUNDS[]`, `res/drawable-nodpi/bg_*.jpg` | cena base do abrigo, uma por período |
| Saudação | "Bom dia / Boa tarde / Boa noite" | `updateGreeting()`, `res/values-pt/strings.xml` | "DIA 47 DO SURTO", "TOQUE DE RECOLHER" ou legenda da câmera |
| Relógio e data | TextClock com Open Sans | `activity_main.xml` | carimbo de hora da câmera (fonte mono) |
| Dock (6 apps) | lupa estilo macOS, nome em cima do app focado, ponto embaixo, brilho na cor do app | `onDockFocused()`, `showHero()`, `setAmbient()`, `magnifyDock()` | **troca de fundo, legenda e cor por app (o coração do tema)** |
| Wi-Fi e Configurações | botões redondos; Wi-Fi fica âmbar (sem internet) ou vermelho (sem rede) | `updateWifiLabel()` (`COLOR_WARN`, `COLOR_ERROR`) | antena/rádio no telhado, oficina |
| Grade (aparece com Baixo) | destaque de vidro com mola | `onTileFocused()` | porão/arsenal |
| Protetor de tela (5 min) | PhotoDream: 12 fotos, 20 s cada, zoom até 1,08, fade de 2,5 s, relógio | `PhotoDream.java`, `saver_*.jpg` | rodízio das câmeras |
| Fontes | Open Sans e Outfit em `res/font` | layouts | + 1 ou 2 fontes temáticas |

Detalhes que mudam o projeto:

- **O dock é editável na TV e fica salvo no aparelho.** Por isso, ligue as imagens ao pacote do app, não à posição. Os pacotes são `com.amazon.firetv.youtube`, `com.amazon.firebat` (Prime Video), `com.stremio.one`, `com.crunchyroll.crunchyroid`, `tv.twitch.android.viewer` e `com.kick.mobile`. Qualquer outro app usa uma imagem genérica.
- **`setImageResource()` decodifica a foto inteira na thread principal.** Para a troca de hora em hora isso serve. Para cada foco, trava a animação.
- **Composição medida no print `52-icones.png` (1920x1080):**
  - Saudação, relógio e data ocupam x 115–905, y 55–210.
  - Os botões do topo ficam em x 1620–1810, y 130–215.
  - O dock, com o nome do app, ocupa y 760–1010. Os ícones são centrados em x ≈ 560, 720, 880, 1040, 1200 e 1360 (160 px entre eles).
  - O assunto de cada imagem deve ficar na faixa y 250–720, com o terço de baixo escuro.

## 2. Mecânicas de navegação (servem para qualquer conceito)

| # | Mecânica | O que se vê | Como fazer no fork | Esforço |
|---|---|---|---|---|
| 1 | **Top Shelf zumbi** | cada app focado troca o fundo | crossfade de 200–300 ms entre 2 ImageViews (o PhotoDream já faz assim); imagem escolhida pelo pacote | P |
| 2 | **Transição-assinatura** | chiado/corte de câmera, piscar da lanterna, giro de dial, pan do mapa | overlay curto (120–200 ms) ou animação de transformação | P |
| 3 | **Legenda viva** | nome do local + uma frase sorteada de uma lista do app, sem repetir em seguida; mesmo voltando ao mesmo app, o texto muda | `string-array` por app em `values-pt` | P |
| 4 | **Raridade** | 1 a cada ~20 focos mostra a versão rara (zumbi na câmera, porta arrombada) | 1 imagem extra por app + sorteio | P |
| 5 | **Zonas** | Cima = telhado (rádio), Baixo = porão (arsenal) | o listener de foco global que já existe + `onTileFocused()` | P |
| 6 | **Horda ociosa** | parado no Home, a horda chega mais perto a cada minuto; qualquer tecla a faz recuar | Handler reiniciado a cada tecla; 3 estágios da cena base, todos antes dos 5 min do protetor | P |
| 7 | **Lanterna** | tela escura; um círculo de luz segue o app focado e revela coisas diferentes acima de cada posição | View com `RadialGradient`, sem bitmap grande, animada com a mesma mola do destaque | P–M |
| 8 | **Paralaxe** | o fundo desliza uns dp no sentido contrário ao foco | `translationX` no `bgPhoto`, com escala 1,05 para não aparecer a borda | P |
| 9 | Hora do dia (já existe) | manhã = saque; tarde = calor e silêncio; noite = horda e fogo; madrugada = toque de recolher | `BACKGROUNDS[]` + saudações | 0 |
| 10 | **Rede = rádio** | online "SINAL LIMPO", sem internet "SÓ ESTÁTICA", sem rede "SEM CONTATO" | `updateWifiLabel()` + ícone de antena | P |
| 11 | **Dia N** | "DIA 47", contado a partir de uma data (ex.: 10/11/2026 = Dia 1) | `updateGreeting()` | P |
| 12 | **O abrigo evolui** | com os dias, a cena base melhora (barricada reforçada, horta, holofote) | contador em SharedPreferences que escolhe a variante | P |
| 13 | Easter egg | ↑↑↓↓←→←→ dispara um alarme: a tela pisca vermelho e a horda aparece no vidro | buffer das últimas teclas | P |
| 14 | Som (opcional, desligado de fábrica) | clique de rádio/chiado curto na troca | SoundPool com 2 ou 3 OGG pequenos | P |
| 15 | **Protetor temático** | rodízio de câmeras com carimbo de hora e "● REC" | `PhotoDream`: trocar fotos e fonte, overlay de linhas, ponto vermelho piscando | P |

Referências das mecânicas:

- **Zonas:** no Days Gone (2019), o menu de pausa abre em uma direção do touchpad, e cada direção leva a um componente (mapa, histórias, habilidades, inventário). É a mesma lógica das zonas.
- **O abrigo evolui:** no The Last of Us Part II, o menu mostra um barco na neblina e, depois que você termina o jogo, passa a mostrar uma praia clara. É a mesma ideia de a cena mudar com o uso.

## 3. Conceitos

| Conceito | Cada navegação… | Clima | Esforço |
|---|---|---|---|
| C1 CFTV do abrigo ★ | troca de câmera | tensão, found footage | P–M |
| C2 Mapa do sobrevivente | viaja pelo mapa até o lugar | exploração, artesanal | M |
| C3 Rádio de emergência | sintoniza outra frequência | urgência, notícia | P–M |
| C4 Lanterna | ilumina outra parte da escuridão | medo puro | P–M |
| C5 Mural do abrigo | levanta uma polaroide | memória, drama | M |
| C6 Casa segura / Código X | revela uma porta marcada a spray | sobrevivência, rua | M |
| C7 Laboratório de contenção | abre a ficha de uma amostra | clínico, frio | P–M |

### C1. CFTV do abrigo: cada app é uma câmera ★

- **Navegação:** trocar de app troca a câmera. São 150 ms de chiado com a imagem rolando, como uma perda de sincronia vertical, e então entra a câmera nova.
- **Topo da tela:** o bloco do topo-esquerdo vira a legenda da câmera, com "CAM 03 · DRIVE-IN", o relógio como carimbo de hora e "● REC" piscando.
- **Madrugada:** a imagem passa a infravermelho (P&B esverdeado) por `ColorMatrixColorFilter`, sem precisar de arte extra.
- **Por que é o melhor ponto de partida:** grão e baixa resolução são o próprio visual. Isso combina com imagens em 960x540 e perdoa arte gerada que não ficou perfeita.
- **Visual:**
  - Cores: fundo #0A0F0B, texto do infravermelho #9FE870, carimbo #E8E8E8, REC #FF3B30.
  - Fonte: VT323 ou Share Tech Mono.
  - Linhas de varredura, grão e vinheta já aplicados direto na imagem.

### C2. Mapa do sobrevivente: cada app é um lugar no mapa

- **Navegação:** o fundo é um mapa da cidade desenhado à mão, em papel manchado e dobrado, com marcador vermelho. Ao focar um app:
  - a "câmera" faz pan e zoom até o lugar (≈400 ms);
  - cai um alfinete;
  - desliza uma polaroide do local com uma nota à mão ("LIMPO 12/03 — 2 SOBREVIVENTES" ou "NÃO ENTRAR").
- **Zonas:** Cima = rosa dos ventos e rádio; Baixo = legenda do mapa.
- **Visual:**
  - Cores: papel #E8DCC0, nanquim #2B2118, marcador #B3261E, verde militar #4B5D3A.
  - Fontes: Permanent Marker ou Rock Salt nas notas, Special Elite no texto datilografado, Saira Stencil One nos títulos.
- **Técnica:** um mapa de 2560x1440 (~7,4 MB em RGB_565, decodificado uma vez) + 6 polaroides pequenas. Pan e zoom são transformação de GPU, que é barata.
- **É o mais original dos sete.**

### C3. Rádio de emergência: cada app é uma frequência

- **Navegação:** há um dial no topo. Trocar de app gira o ponteiro (88.1 → 107.1), com 150 ms de estática, e entra a "transmissão": uma imagem e um letreiro rolando com recados sorteados ("Abrigo no estádio aceita sobreviventes", "A ponte norte caiu", "Não abra a porta depois das 22h").
- **Visual:**
  - Cores: preto, amarelo de alerta #FFC400, vermelho #D7261E, branco #F2F2F2.
  - Fontes: Oswald ou Bebas Neue, com Share Tech Mono.
  - Faixas diagonais de zona de perigo.
- **Cuidado: não copie alertas reais** (o EAS dos EUA, a Defesa Civil). Em 11/02/2013, invasores colocaram no ar, em emissoras como a KRTV (Great Falls, Montana), um falso alerta de que "os corpos dos mortos estão saindo das sepulturas". Use uma emissora fictícia ("RÁDIO LIVRE — ZONA 7") e um visual claramente estilizado, para ninguém em casa levar um susto de verdade.

### C4. Lanterna: cada navegação ilumina outra coisa

- **Navegação:** a tela é escura. Um círculo de luz quente segue o app focado e revela a parte da cena logo acima dele. De vez em quando a pilha falha, com uma tremulação de 300 ms.
- **A cena:** uma imagem larga com um "segredo" acima de cada posição do dock, em x ≈ 560, 720, 880, 1040, 1200 e 1360 px (29, 37, 46, 54, 62 e 71% da largura).
- **Visual:**
  - Cores: preto e luz de #FFE7B0 para âmbar.
  - Poeira no feixe de luz.
- **Técnica:** um `RadialGradient` desenhado numa View por cima do fundo. É barato e funciona bem como modo madrugada de qualquer outro conceito.

### C5. Mural do abrigo: cada app levanta uma polaroide

- **Navegação:** o fundo é uma parede de cortiça com polaroides e barbante.
  - O app focado levanta a foto dele (escala + sombra), e o fundo vira a cena dessa foto, escurecida.
  - Uma legenda à mão é sorteada a cada foco.
  - Um contador "DIA 47" a giz fica no canto.
  - Com o tempo, aparecem mais fotos no mural (mecânica 12).
- **Visual:**
  - Cores: parede #2A2522, polaroide #F3EEE3, caneta azul #1D3557, vermelho seco #7A1712.
  - Fontes: Permanent Marker ou Rock Salt, com Special Elite.

### C6. Casa segura / Código X: cada app é uma porta marcada

- **Navegação:** cada app é uma porta com tábuas. Ao focar, aparece o "X" de busca pintado a spray, com os quadrantes preenchidos. Se você ficar parado, há batidas na porta e as tábuas tremem.
- **O código é real.** É a marcação das equipes de busca e resgate dos EUA, que ficou famosa depois do furacão Katrina:
  - barra simples = busca em andamento; X completo = busca terminada;
  - esquerda = equipe; topo = data e hora da saída; direita = perigos; base = vivos/mortos ("0/0" = ninguém);
  - X dentro de um quadrado = não entre.
  - Exemplo para a Twitch: `T-5 | 10/11 22h | GÁS | 3/0`.
- **Visual:**
  - Cores: concreto #1C1C1C, spray laranja #FF6B1A, branco #F1F1F1.
  - Fontes: Rubik Spray Paint ou Rubik Wet Paint, com Black Ops One.
- **Inspiração:** os recados de outros sobreviventes nas paredes dos abrigos do Left 4 Dead.

### C7. Laboratório de contenção: cada app é uma amostra

- **Navegação:**
  - Cada app abre uma ficha de amostra, com foto e "NÍVEL DE CONTAMINAÇÃO" de 12% a 87%.
  - Uma linha de ECG no topo muda de cor e de ritmo conforme o app: verde, âmbar ou vermelho.
  - Configurações = sala de controle.
- **Visual:** é o oposto do grunge, clínico e mais legível.
  - Cores: #0E1A17, verde #39FF88, branco #F5F7F6, laranja #FF5A1F.
  - Fontes: Share Tech Mono, com Rubik Microbe nos títulos (fonte com textura de micróbio, licença OFL).
- **O símbolo de risco biológico** foi criado em 1966 por uma equipe da Dow Chemical liderada por Charles Baldwin, com Robert Runkle (NCI). Foi pensado para ser "memorável e sem significado" e virou padrão da ANSI (1969) e da ISO (1986).
- **Técnica do ECG:** um Path animado ou um WebP animado pequeno. O Android 9 já toca WebP e GIF animados pelo `AnimatedImageDrawable`.

### Estilos que valem para qualquer conceito

- **Sessão da meia-noite (P&B, TV de tubo):** "A Noite dos Mortos-Vivos" (1968) está em domínio público nos EUA porque foi lançado sem aviso de copyright. Frames do filme podem virar fundos e protetor de tela. Use a versão P&B original; colorizações e remakes são outras obras.
- **HQ (retícula + contorno grosso):** referência no Z-PURIFY, no Behance. Bônus: em 2011 o CDC fez a campanha "Preparedness 101: Zombie Apocalypse" e lançou a HQ "Preparedness 101: Zombie Pandemic". O registro da HQ no CDC Stacks está marcado como Public Domain, então os painéis podem virar fundos de "manual de sobrevivência".
- **Versão Brasil/sua cidade:**
  - Troque as locações genéricas por lugares que você conhece: orla, farol, estádio, mercado, ladeira, manguezal.
  - Acrescente placa azul de rua, orelhão e Kombi.
  - Referência nacional: "Mangue Negro" (2008, Rodrigo Aragão), com zumbis num manguezal.
  - Extra sazonal: modo horda em 2/11 (Finados), quando acontece a Zombie Walk de São Paulo.

## 4. Proposta: ABRIGO 7

| Onde | O que aparece |
|---|---|
| Dock (6 apps) | C1: uma câmera por app, chiado na troca, legenda + frase sorteada, 5% de chance de versão rara |
| Topo | Wi-Fi = rádio no telhado (SINAL LIMPO / SÓ ESTÁTICA / SEM CONTATO); Configurações = oficina |
| Grade (Baixo) | porão/arsenal |
| Sem foco ou parado | janela do abrigo; horda em 3 estágios (1, 2 e 3 min); qualquer tecla faz recuar |
| Madrugada (22–5 h) | lanterna (C4) por cima da câmera em infravermelho |
| Saudação | "DIA N DO SURTO"; "TOQUE DE RECOLHER" depois das 22 h |
| Protetor (5 min) | rodízio das câmeras com carimbo e REC |
| Com o tempo | a cena base evolui |

Locações (servem para todos os conceitos):

| App | Local | Câmera | Frase de exemplo |
|---|---|---|---|
| YouTube | torre de transmissão no morro, luzes vermelhas | CAM 01 TORRE | "Alguém ainda está transmitindo." |
| Prime Video | shopping/centro de distribuição saqueado (homenagem a "Despertar dos Mortos", 1978) | CAM 02 GALPÃO | "Caixas lacradas no setor B." |
| Stremio | drive-in abandonado, telão rasgado ainda projetando | CAM 03 DRIVE-IN | "O projetor ligou sozinho." |
| Crunchyroll | rua de lanternas vermelhas e fliperama | CAM 04 FLIPERAMA | "As máquinas ainda acendem." |
| Twitch | estúdio de stream no bunker, luz roxa | CAM 05 ESTÚDIO | "AO VIVO: dia 47, 3 espectadores." |
| Kick | estádio virado abrigo, barracas no gramado | CAM 06 ESTÁDIO | "Portão norte fecha às 18h." |
| Wi-Fi | antena no telhado | — | "SINAL LIMPO" |
| Configurações | oficina/bancada | — | "Ferramentas: 4/7" |
| Grade | porão/arsenal | — | "Munição: pouca." |
| Outro app | rua genérica | CAM ?? | "Câmera sem identificação." |

Arte total: 6 câmeras + 6 raras + 4 bases por hora + 3 estágios + telhado + porão + 12 do protetor (pode reaproveitar as câmeras) ≈ 25–30 imagens.

## 5. Direção de arte

- **Tamanho e peso.**
  - Fundo: 1920x1080, escuro, JPEG com qualidade 80–85 e até ~300 KB. É a regra do cleanyourtv; os 4 fundos atuais têm 305–530 KB.
  - Imagens de foco (uma por app): salve direto em 960x540 (~80–150 KB). O launcher estica para a tela, e o grão e o escurecido escondem a diferença.
- **Composição.**
  - Deixe o topo-esquerdo calmo e o terço de baixo escuro (gradiente).
  - Ponha o assunto na faixa y 250–720.
  - Margem de segurança de ~5%: 48 dp nas laterais e 27 dp em cima e embaixo pelo guia do Android TV, o que no stick dá ≈ 96 px e 54 px.
- **Efeitos já aplicados no arquivo:** blur, vinheta, grão e linhas de varredura entram na imagem, não em tempo real. O Fire OS 7 é Android 9, e o blur por GPU do Android (`RenderEffect`) só existe a partir do Android 12.
- **Tipografia.** Todas são do Google Fonts, com licenças abertas que permitem embutir no APK.
  - Títulos curtos: Creepster, Nosifer, Rubik Microbe, Rubik Wet Paint, Rubik Spray Paint, Black Ops One, Saira Stencil One.
  - Legendas, carimbos e rádio: VT323, Share Tech Mono, Oswald, Bebas Neue.
  - À mão ou datilografado: Permanent Marker, Rock Salt, Special Elite.
  - Regra: o relógio e os nomes dos apps continuam em fonte limpa; a fonte "assustadora" fica só nos títulos curtos.
  - Teste acentos: ATENÇÃO, INFECÇÃO, CONTAMINAÇÃO.
- **Ícones:** mantenha o ícone original, porque a marca precisa ser reconhecida rápido, e ponha uma moldura temática por cima (fita adesiva nos cantos, ferrugem, crachá de quarentena).
- **Nível de terror:** decida antes de gerar a arte.
  - Leve: clima e silhuetas.
  - Médio: zumbis visíveis, sem sangue.
  - Pesado: gore.
  - Susto (easter egg) e som vêm desligados de fábrica, porque é a TV da sala.

## 6. De onde tirar as imagens

- **Gerar com IA.** É o melhor para manter as 6 câmeras consistentes.
  - Sufixo fixo em todas: `cinematic still, post-apocalyptic city, overcast, muted desaturated colors, volumetric haze, 35mm film grain, 16:9, no text, no letters, no logos, no watermark`.
  - Para o CFTV, acrescente: `security camera footage, high wide-angle view, slight fisheye, low resolution CCTV look`.
  - Prompts por local:
    - Torre: `hilltop TV broadcast tower with blinking red lights at dusk, abandoned cars on the access road, survivors with a generator at its base`
    - Galpão: `looted shopping mall / distribution warehouse, scattered cardboard boxes, stopped conveyor belts, emergency lights, a shambling crowd far in the background`
    - Drive-in: `abandoned drive-in cinema at night, torn screen still lit by a projector beam, cars with open doors, silhouettes between the cars`
    - Fliperama: `street with red paper lanterns and dead neon signs, abandoned arcade with glowing cabinets, rain puddles`
    - Estúdio: `makeshift streaming studio inside a concrete bunker, purple RGB light, ring light, monitors showing static, barricaded door`
    - Estádio: `football stadium turned into a refugee camp, tents on the pitch, floodlights, chain-link fences, a horde outside the gates in the distance`
    - Bases e zonas: `view from a barricaded window to an empty street`, `rooftop with a radio antenna, water tanks, smoking skyline`, `basement armory, shelves of canned food and tools, flashlight beams`
  - **Estágios da horda e versões raras:** gere a cena base uma vez e crie as variações editando a mesma imagem (inpainting). Gerar de novo muda a composição.
  - **Lanterna:** peça `six points of interest evenly spaced horizontally between 29% and 71% of the width, at mid height`.
  - **Texto sempre no launcher, nunca na imagem** (legendas, carimbos, X-code). Os geradores erram letras, e o texto do launcher fica nítido na TV.
- **Fotos livres + edição.**
  - Bancos: Unsplash (uso livre, crédito não obrigatório; só não pode montar um serviço concorrente) e Pexels (livre, sem crédito; pessoas identificáveis não podem aparecer de forma ofensiva, e não pode revender a foto sem modificar).
  - Busque lugares abandonados de verdade ("abandoned mall", "drive-in", "stadium at night") e acrescente a horda por edição.
- **Texturas** (papel, concreto, ferrugem, cortiça): Poly Haven, licença CC0, sem crédito.
- **Domínio público:** "A Noite dos Mortos-Vivos" (1968) e a HQ do CDC (2011), na seção 3.
- **Wallpapers prontos:** wallhaven.cc e 4kwallpapers.com, os sites que o guia de temas do cleanyourtv sugere. Servem para uso pessoal; para publicar, só imagem com licença livre e um `CREDITS.md`.
- **Sons**, se usar: Freesound, filtrando por CC0.
- **Referência visual** (para inspirar, não copiar):
  - Game UI Database (gameuidatabase.com), de Edd Coates: mais de 55 mil telas de jogos, com filtro por tipo de tela, textura, HUD e cor. Busque lá Days Gone, State of Decay 2, The Last of Us Part II, Resident Evil 2 (2019), Dying Light 2, Project Zomboid e Left 4 Dead 2.
  - O Z-PURIFY no Behance, para o estilo HQ.
- **Fora:** logos e personagens de franquias (Umbrella, The Walking Dead, The Last of Us).

## 7. Limites do Fire Stick Lite

- **Hardware (Amazon):** MT8695D com 4 núcleos de 1,7 GHz, GPU IMG GE8300, 1 GB DDR4, Android 9 (API 28), Fire OS 7. Vídeo H.264/H.265/VP9 por hardware até 1080p60. Medido aqui: ~920 MB de RAM, e o launcher usa ~55 MB na frente.
- **Memória por imagem decodificada.** Em 1920x1080 são ~4 MB em RGB_565 (8 MB em 32 bits); em 960x540, ~1 MB.
  - Fundo da hora: 1080p.
  - Imagens de foco: 960x540 em `RGB_565` (salvas nesse tamanho, ou em 1080p decodificadas com `inSampleSize=2`), com cache das 3 a 6 mais recentes (≈3–6 MB).
- **Troca suave.**
  - Decodifique fora da thread principal.
  - Espere ~120 ms de foco parado antes de trocar, para que rolar rápido pelo dock não decodifique 6 imagens.
  - Pré-carregue as imagens dos apps vizinhos.
- **Animação:** prefira alpha, translação e escala (GPU). WebP ou GIF animado só em áreas pequenas, com `AnimatedImageDrawable` (Android 9+). Vídeo só no protetor.
- **Overlays de linhas e grão:** use uma textura pequena repetida (`BitmapShader` REPEAT), não um PNG de tela cheia.
- **Tamanho do APK:** ~25–30 imagens (as de foco com ~100 KB e as de 1080p com até 300 KB) somam ≈ 4–8 MB a mais.
- **Medição:** compare antes e depois como nas outras sessões, com `dumpsys meminfo com.gathin.tvhome` e `dumpsys gfxinfo com.gathin.tvhome` usando a mesma sequência de teclas.
- **Fora de alcance sem root:**
  - animação de boot;
  - a tela da Amazon, que aparece por alguns segundos ao apertar Home antes do launcher;
  - as Configurações e a Appstore da Amazon.
  - Uma ideia que ficou de fora na sessão da limpeza: uma capa de acessibilidade por cima da tela da Amazon nesses segundos (dá para fazer uma "TRANSMISSÃO INTERROMPIDA"), mas o controle fica sem resposta enquanto ela está na tela.

## 8. Caminho de implementação (quando decidir)

- **Fase 0, só arte** (um build, sem código): trocar os `bg_*.jpg` (4) e os `saver_*.jpg` (12), as saudações em `values-pt/strings.xml` e a fonte do relógio.
- **Fase 1, Top Shelf zumbi:**
  - mapa pacote → imagem, legenda e frases em `res/values`;
  - troca em `onDockFocused()` / `showHero()`;
  - crossfade A/B, decodificação assíncrona, espera de ~120 ms e transição-assinatura.
- **Fase 2, mecânicas:** zonas, horda ociosa, lanterna na madrugada, rádio no Wi-Fi, Dia N, raridade e protetor CFTV.
- **Fase 3 (opcional), tema sem recompilar**, no estilo do cleanyourtv: o launcher lê `config.json` + imagens de uma pasta do app, e um script ADB (como o `tools/theme.ps1`) envia. Aí trocar a arte não exige build.

## 9. Decisões (10/11, noite) e protótipo

- **Conceito:** apocalipse zumbi "normal", com zumbis no estilo dos walkers de The Walking Dead (lentos, magros, roupa rasgada).
- **Nível de terror:** terror de sobrevivência, com imagens mais esquisitas.
- **Inspiração:** Left 4 Dead, Back 4 Blood, The Walking Dead (Telltale), DayZ e Project Zomboid, só como referência de clima. Nada de copiar telas, logos ou personagens.
- **Imagens:** ainda em aberto. Esta sessão não gera imagem por IA. O protótipo aceita uma imagem arrastada, colada ou escolhida, para comparar na mesma tela.
- **Protótipo no navegador:** [Abrigo 7](https://claude.ai/artifact/3J2Sg9Ni7mZZxxKiYxUfMa).
  - Usa o layout do launcher do stick, e as setas trocam a cena de cada app.
  - Teclas: C alterna câmera/cena, N liga a noite (lanterna na cena, infravermelho na câmera), R mostra a versão rara.
  - Se ficar 8 s parado, a horda chega em 3 estágios.
  - As cenas são desenhadas por código (silhuetas em névoa). No stick, viram imagens 960x540 ou o mesmo desenho portado para o `Canvas` do Android.
- **Atualização (10/11, ~21h30):** o usuário pediu imagens reais de jogos, sem IA.
  - Baixei as 111 screenshots oficiais das páginas da Steam: L4D1, L4D2, Back 4 Blood, TWD Telltale (Definitive, S1, S2, A New Frontier, Final Season), DayZ e Project Zomboid.
  - A nuvem não alcança a Steam (proxy 403). O download foi feito pelo navegador do app no PC: um zip montado na página do CDN, que o usuário salvou e extraiu na pasta.
  - Ficou em `E:\Misc Projects\fire-tv-cleanup\meu-firestick\tema-zumbi\`.
  - 5 temas em `temas/<tema>/`: `twd`, `left4dead`, `dayz`, `b4b` e `zomboid`.
  - Cada tema tem 12 imagens 1920x1080 tratadas (6 apps, telhado, porão, horda1–3, raro).
  - Prévia local em `previa.html` (T troca o tema). `LEIA-ME.md` e `fontes.txt` ficam junto.
  - Scripts no VM do Cowork: `~/tools/build_themes.py` (corte, tratamento, mapa slot → screenshot) e `~/tools/sheets.py`.
  - Uso só pessoal: as imagens têm dono. Não publicar o tema nem mandar como PR.
- **Ajustes pedidos (10/11, ~22h):**
  - Sem nome de tema na tela.
  - Ícones de verdade, recortados do print `53-icones-grade.png` do launcher do stick.
  - Sem o modo câmera.
  - Os jogos se misturam: cada movimento sorteia um jogo, nunca o mesmo duas vezes seguidas, e cada horda sorteia um jogo.
  - A `previa.html` agora leva as imagens dentro do arquivo (1280x720 WebP, ~4,4 MB). A primeira versão buscava a pasta `temas` e ficava preta quando aberta pelo chat.
- **Para o stick:** o launcher precisa das imagens dos 5 jogos para cada app (60 imagens, ~6 MB em 960x540). O sorteio entra no `onDockFocused()`.
- **Depois disso o plano mudou:** veja a seção 10.

## 10. Mudança de rumo (10/11, ~23h): zumbi na TCL, slasher no Fire Stick

Pedido: os temas zumbi vão para a TV padrão (TCL), e o stick ganha terror de assassinos slasher, com cenas de filmes.

**TV TCL (launcher cleanyourtv 3.4)**

- O launcher da TCL já aceita temas (`config.json` + `wallpapers/`, enviados pelo content provider `content://com.gathin.tvhome.theme`), mas só troca o fundo por tempo. A troca a cada movimento precisou de código:
  - `WallpaperPlayer.java`: chave nova `focus_wallpapers` no `config.json` (`pacote=slot`, mais `*dock` e `*grid`). Cada foco sorteia um `<jogo>-<slot>.jpg` de um jogo diferente do atual, com crossfade de ~400 ms, e 1 em 20 vira o `raro`. Decodifica fora da thread principal e guarda o pedido que chega no meio de outro.
  - `MainActivity.java`: o foco de um app chama `focus(pacote, estáNoDock)`; os botões de cima (Configurações, Wi-Fi, Entradas) pedem o slot `telhado`.
  - Diff em `cleanyourtv/minha-tv/tema-zumbi-launcher.patch`; os originais estão em `minha-tv/launcher-original/`.
- Tema em `cleanyourtv/minha-tv/tema-zumbi/`: 45 imagens 1280x720 (5 jogos × youtube, prime, stremio, crunchyroll, twitch, kick, telhado, porão e raro), `captions.txt` com o lugar de cada uma e `config.json` com rotação de 1440 min (só para a coleção carregar) e 12% de escurecimento.
- Instalar (Windows, com ADB ligado na TV): `powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-tema-zumbi.ps1" -Tv <ip>`. Com `-SoTema`, reenvia só as imagens. Para voltar: `instalar-launcher.ps1 -Tv <ip> -Tema "...\themes\twilight"`.
- **Ainda não compilado nem testado na TV**, porque só compila no Windows. Conferido aqui: o javac analisa os dois arquivos sem erro, e os métodos e campos usados existem.

**Fire Stick: tema slasher**

- 8 assassinos: Halloween (Michael Myers), Sexta-Feira 13 (Jason), A Hora do Pesadelo (Freddy), Pânico (Ghostface), O Massacre da Serra Elétrica (Leatherface), Brinquedo Assassino (Chucky), Freddy vs. Jason e Terrifier (Art).
- Imagens: 119 backdrops do TMDB (1280x720, sem texto), baixados pelo navegador do app no PC num zip. Ficam em `E:\Misc Projects\fire-tv-cleanup\meu-firestick\tema-slasher\`, com `fontes.txt` e `LEIA-ME.md`.
- 12 slots por assassino em `temas/<assassino>/`:
  - os 6 apps, `telhado` (botões de cima), `porao` (grade) e `raro`;
  - `perto1` a `perto3`: o assassino se aproximando quando a TV fica parada (longe, na porta, na cara).
  - São 96 imagens 1280x720. O `gerar_temas.py` da pasta refaz todas: escolha da imagem por slot, espelhamento para tirar o assunto de baixo do relógio e cor por assassino.
- Prévia `previa.html` (5,2 MB, imagens embutidas), com o mesmo motor da prévia zumbi:
  - cada movimento sorteia um assassino, `N` apaga a luz e `R` mostra a versão rara;
  - parado, o assassino chega em 8, 16 e 24 s (na TV seriam minutos), e qualquer tecla mostra "ELE SUMIU.";
  - embaixo da data aparece a contagem para a próxima sexta-feira 13 ou Halloween, e no dia o assassino da data aparece em 40% dos movimentos;
  - o Wi-Fi vira telefone ("com linha, ninguém do outro lado" ou "mudo, cortaram o fio");
  - lugares e frases escritos do zero em PT-BR, sem citar falas dos filmes.
  - Conferida com Playwright: as 96 combinações carregam, sem erro no console e sem rolagem lateral no celular.
- Uso pessoal: as imagens são de divulgação dos filmes e têm dono. Não publicar.
- **Depois disso o plano mudou de novo:** veja a seção 11.

## 11. Decisão (11/11): tudo na TV, Fire Stick no padrão

Pedido: o usuário vai usar mais a TV. Todos os temas de terror e de zumbi vão para ela, os jogos saem e entram filmes de zumbi. O Fire Stick fica com o tema que já tem; nada do tema slasher foi instalado nele.

**O tema da TV:** um só, com 20 filmes misturados. Cada movimento sorteia um filme diferente do que está na tela.

- 8 assassinos (seção 10) e 12 de zumbi, escolhidos pelo usuário (clássicos, infectados rápidos e coreanos; de série, só The Walking Dead):
  - A Noite dos Mortos-Vivos (1968), Despertar dos Mortos (1978), Madrugada dos Mortos (2004), Dia dos Mortos (1985);
  - Extermínio, Extermínio 2, [REC], Guerra Mundial Z;
  - Invasão Zumbi, Península, #Alive;
  - The Walking Dead.
- 245 backdrops novos do TMDB (1280x720, sem texto), baixados pelo navegador do app num zip que o usuário salvou. A nuvem e o VM não alcançam o TMDB.
- 12 fundos por filme: os 6 apps, `telhado`, `porao`, `perto1`–`perto3` e `raro`. São 240 fundos 1280x720 (33 MB), cada um com legenda "Lugar — frase" de até 56 caracteres, escrita do zero (nada de falas dos filmes).

**Aproximação parado** (o usuário quis): código novo no launcher da TCL, por cima do `focus_wallpapers`.

- Chave nova `focus_idle_minutes` no `config.json` (o tema usa 1). Parado na tela inicial, o fundo mostra `<filme>-perto1`, depois `perto2` e `perto3` do mesmo filme, um por minuto. Qualquer tecla volta ao fundo do item em foco.
- `WallpaperPlayer`: `approach(etapa)` e `showSlot(slot, filme, podeSerRaro)`. A primeira imagem e a rotação simples nunca usam `perto` nem `raro`.
- `MainActivity`: a contagem usa o mesmo `onUserInteraction` do relógio parado e para em `onPause`.
- Conferido aqui: o javac analisa os dois arquivos sem erro, e os 240 fundos têm nome válido, legenda e os 12 slots por filme. **Ainda não compilado nem testado na TV.**

**Pastas** (em `E:\Misc Projects\cleanyourtv\minha-tv\`):

- `terror\slasher\` (veio de `fire-tv-cleanup\meu-firestick\tema-slasher`), `terror\zumbi\` (originais, zip e `fontes.txt`) e `terror\tema\` (o que vai para a TV).
- `terror\gerar_tema.py` (imagem, ajuste e legenda por slot), `terror\LEIA-ME.md` e `terror\visao-geral\tema.jpg`.
- `instalar-tema-terror.ps1`, com `-SoTema`, `-Conjunto tudo|assassinos|zumbis` e `-Parado <min>`.
- `tema-terror-launcher.patch` (diff contra `launcher-original\`).
- O tema de jogos e o instalador dele foram para `_antigo\`, sem apagar.

**Instalar:** `powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-tema-terror.ps1" -Tv <ip>`. Se o fundo não mudar ao navegar, o Papel de parede nas configurações do launcher tem que estar em "Padrão do tema": uma escolha feita na TV passa por cima do tema.

**Resultado na TV (11/11):** compilou e instalou. O usuário viu três problemas: fundos repetindo muito, a aproximação "não indo", e a troca sem efeito. Ele pediu juice no tema todo. Veja a seção 12.

## 12. Segunda volta na TV (11/11): sem repetição, aproximação visível, efeitos e sons

**Por que repetia:** cada app tinha só os seus 20 fundos (um por filme), sorteados ao acaso. Na TV, o dock tem 4 apps; o resto cai na grade (`porao`) e os 3 botões de cima no `telhado`. Andar pela grade ou pelo topo girava em 20 imagens, e o sorteio puro repete logo.

- **Correção (`focus_mix`):** todas as 160 cenas (os 8 slots que não são `perto`/`raro`) entram num sorteio só.
- Uma cena só volta depois que 3/4 delas passaram. O histórico (`focus_recent`) fica nas preferências e sobrevive a reinícios.
- Nunca o mesmo filme em seguida e, se der, nenhum dos últimos 4.

**Por que a aproximação "não ia":** sem como olhar a TV, a hipótese é que funcionava, mas era sutil demais. Era só uma troca de foto por minuto, com a legenda pequena no canto, e a etapa 1 pegava outro filme. Também pode ser algo apertando teclas sozinho e zerando o tempo. Mudanças:

- A etapa 1 usa o filme que está na tela.
- Cada etapa mostra um aviso grande no meio de cima (`focus_idle_alerts`, por tipo: assassino/zumbi), e a volta tem o seu ("Ele sumiu." / "Eles recuaram.").
- Efeitos por etapa:
  - as bordas escurecem cada vez mais (vinheta);
  - a imagem vai chegando perto (escala 1,02 → 1,08 em 9 s);
  - a etapa 2 entra com estática;
  - a etapa 3 acende como lâmpada falhando, com borda vermelha que pulsa como coração e um tranco.
- `focus_idle_minutes` aceita fração (0.25 = 15 s), para testar.
- Registro em `TvHome.Approach`: liga/desliga, teclas recebidas (com o dispositivo), etapas e "mandada embora". O instalador lê com `-Diagnostico`.

**Juice** (pesquisa: "Juice it or lose it", de Martin Jonasson e Petri Purho, a WCAG 2.3.1 sobre flashes e o guia de aceleração por hardware do Android):

- **Troca em duas camadas** (`FocusFx`): a cena nova entra por cima, empurrada 46 dp do lado para onde o foco foi e saindo de um zoom de 1,05, em 460 ms com desaceleração. Antes era um mergulho no escuro numa camada só.
- 20% das trocas usam **estática de fita**: 3 quadros de ruído 192x108 esticados sem filtro, com tremida, 320 ms. 10% usam **lâmpada falhando**: duas quedas de brilho em 560 ms.
- Estática e lâmpada nunca se repetem em menos de 2 s, para ficar abaixo de 3 flashes por segundo (WCAG 2.3.1).
- A imagem **rara** traz um pulso vermelho nas bordas; a **legenda** troca deslizando.
- **Sexta-feira 13 e Halloween** (`focus_days`): Jason e Freddy vs. Jason, ou Michael e Terrifier, em 40% das trocas.
- **Sons opcionais** (`focus_sounds`, `-Som`): estática, coração e impacto, sintetizados por `terror/gerar_sons.py` (nada de terceiros), em `res/raw`, tocados pelo SoundPool. Vêm desligados.
- **Custo:** só alpha, translação e escala, por instantes. A tela inicial volta a não desenhar nada quando a troca termina. `-SemEfeitos` volta à troca simples. A TV está com `reduced_motion` ligado no config.xml.

**Código:** `FocusFx.java` (novo), mais mudanças em `WallpaperPlayer.java` (sorteio, histórico, estilos, aproximação, alertas) e `MainActivity.java` (direção do movimento, log). Novas chaves de config: `focus_mix`, `focus_effects`, `focus_sounds`, `focus_sets`, `focus_idle_alerts` e `focus_days`.

- Conferido: `FocusFx.java` e `WallpaperPlayer.java` compilam (javac 11 do VM) contra stubs das APIs Android usadas, junto com os helpers reais. A `MainActivity` passa na análise do javac.
- Não deu para compilar contra o android.jar: Maven e TMDB estão bloqueados no proxy, e o SDK do usuário está fora da pasta conectada.
- `tema-terror-launcher.patch` refeito; os WAV ficam fora do diff.

**Instalador:** `-Parado` aceita fração; novas opções `-Som`, `-SemEfeitos` e `-Diagnostico`. É preciso recompilar (rodar sem `-SoTema`) para pegar o código novo.

**Falta:** o usuário recompilar e testar. Sugestão: `-Parado 0.25` para ver a aproximação logo e, se não aparecer, `-Diagnostico`.

## Fontes

Locais (PC, `E:\Misc Projects`):

- `fire-tv-cleanup/launcher/.../MainActivity.java`, `PhotoDream.java`, `res/values/config.xml`
- print `fire-tv-cleanup/screenshots/52-icones.png`
- `cleanyourtv/themes/README.md`, `cleanyourtv/themes/CREATE_A_THEME.md`, `cleanyourtv/docs/TROUBLESHOOTING.md`

Web:

- [TMDB — imagens de fundo dos filmes do tema slasher](https://www.themoviedb.org/)
- ["Juice it or lose it" — resumo da palestra de Jonasson e Purho](https://gamejuice.pages.dev/articles/juice-it-or-lose-it-lessons)
- [W3C — Understanding SC 2.3.1: Three Flashes or Below Threshold](https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold)
- [Android — aceleração por hardware](https://developer.android.com/topic/performance/hardware-accel) e [Dan Lew — hardware layers em animações](https://blog.danlew.net/2015/10/20/using-hardware-layers-to-improve-animation-performance)
- [Kill Screen — o terror das fitas VHS](https://www.killscreen.com/vhs-horror/)
- [Amazon — especificações do Fire TV Stick (inclui o Lite, AFTSS)](https://developer.amazon.com/docs/fire-tv/device-specifications-fire-tv-stick.html)
- [Android TV — layouts (960x540 dp, margem de 5%)](https://developer.android.com/design/ui/tv/guides/styles/layouts)
- [Android 9 — ImageDecoder e AnimatedImageDrawable](https://developer.android.com/about/versions/pie/android-9.0)
- [Apple HIG — Top Shelf](https://developer.apple.com/design/human-interface-guidelines/top-shelf)
- [Game UI Database](https://www.gameuidatabase.com/) e [matéria da Aftermath sobre ela](https://aftermath.site/game-ui-database/)
- [Push Square — os menus de Days Gone](https://www.pushsquare.com/news/2019/03/hands_on_days_gone_has_some_of_the_flashiest_menus_on_ps4)
- [GameSpot — o menu do The Last of Us Part II muda no fim](https://www.gamespot.com/articles/the-last-of-us-2-heres-what-the-new-game-plus-menu/1100-6479110/)
- [Z-PURIFY (Behance)](https://www.behance.net/gallery/132228931/Z-PURIFY)
- [Plagiarism Today — por que "A Noite dos Mortos-Vivos" é domínio público](https://www.plagiarismtoday.com/2016/10/25/why-night-of-the-living-dead-is-public-domain/)
- [Wikipedia — Preparedness 101: Zombie Apocalypse](https://en.wikipedia.org/wiki/Preparedness_101:_Zombie_Apocalypse) e [CDC Stacks — Preparedness 101: Zombie Pandemic](https://stacks.cdc.gov/view/cdc/6023)
- [Science History Institute — o símbolo de risco biológico](https://www.sciencehistory.org/collections/blog/the-biohazard-warning-symbol/)
- [Marcações de busca e resgate (X-code)](https://trueprepper.com/urban-search-rescue-markings-know/) e [Boing Boing — marcações do Katrina](https://boingboing.net/2005/09/10/katrina-code-marks-o.html)
- [Wikipedia — falsos alertas zumbis de 2013](https://en.wikipedia.org/wiki/2013_Emergency_Alert_System_hijackings)
- Fontes [Rubik Microbe](https://fontsource.org/fonts/rubik-microbe/about) e [Rubik Wet Paint](https://fontsource.org/fonts/rubik-wet-paint/about)
- Licenças: [Unsplash](https://unsplash.com/license), [Pexels](https://www.pexels.com/license/), [Poly Haven](https://polyhaven.com/license)
- [AdoroCinema — Mangue Negro](https://www.adorocinema.com/filmes/filme-202626/) e [Gazeta do Povo — Mangue Negro](https://www.gazetadopovo.com.br/blogs/espanto/mangue-negro-retrata-horror-com-zumbis-e-pobreza/)
- [Vanguardia — Zombie Walk 2026 em São Paulo](https://www.vanguardia.com/entretenimiento/tendencias/2026/11/02/zombie-walk-2026-cientos-de-zombis-se-tomaron-las-calles-de-sao-paulo-en-brasil/)
