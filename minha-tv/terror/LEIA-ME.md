# Tema de terror da TV — assassinos e zumbis de filmes

Na tela inicial da TV, cada movimento no controle sorteia um filme e uma cena para o fundo:

- nunca o mesmo filme duas vezes seguidas e, se der, nenhum dos últimos 4;
- uma cena só volta depois que três quartos das 160 cenas já passaram (a TV guarda esse histórico mesmo desligando);
- uma vez em 20 aparece a versão rara, com um pulso vermelho nas bordas.

A troca tem um efeito só, desde 12/11: estática de TV (como uma fita VHS perdendo o sinal), com 0,6 s na tela, em toda troca, inclusive nas etapas da aproximação. Fica no `config.json` do tema: `"focus_style": "static"` e `"focus_style_ms": 600` (mais tempo, mais aparente). Com `"focus_style": "mix"` volta a mistura de antes: quase sempre a cena nova entra deslizando do lado para onde você moveu, às vezes com estática ou acendendo como uma lâmpada falhando (nunca duas vezes em 2 segundos).

Parado na tela inicial, a ameaça do filme que está na tela se aproxima, uma etapa por minuto:

1. um aviso grande ("Tem alguém lá fora"; nos zumbis, "Movimento lá fora") e as bordas escurecendo;
2. "A porta está aberta" / "Estão na cerca", com estática e a imagem chegando mais perto;
3. "Ele está dentro de casa" / "Eles entraram", em vermelho, com a borda pulsando como um coração e um tranco.

Qualquer tecla manda embora ("Ele sumiu." / "Eles recuaram."). Na sexta-feira 13, Jason aparece mais; no Halloween, Michael Myers e o palhaço do Terrifier.

## Instalar

Com a Depuração USB e a Depuração de rede ligadas na TV, no PowerShell:

```
powershell -ExecutionPolicy Bypass -File "E:\Misc Projects\cleanyourtv\minha-tv\instalar-tema-terror.ps1" -Tv <ip da TV>
```

- Sem opções, compila o launcher (alguns minutos) e envia os 240 fundos. Depois de uma mudança no código, é preciso rodar assim.
- `-SoTema` reenvia só as imagens e as opções, sem compilar.
- `-Parado 0.25` deixa 15 segundos por etapa, para ver a aproximação sem esperar; `-Parado 0` desliga. O padrão é 1 minuto.
- `-Som` liga os sons: estática, coração e um impacto na última etapa e na imagem rara. Vêm desligados porque é a TV da sala.
- `-SemEfeitos` volta à troca simples, se a TV ficar lenta.
- `-Conjunto assassinos` ou `-Conjunto zumbis` instala só um dos grupos (o padrão é `tudo`).
- `-Diagnostico` não instala nada: mostra o registro da aproximação na TV (as teclas que ela viu e as etapas). Se a aproximação não aparecer, rode e mande o resultado.
- Se o fundo não mudar ao navegar: nas configurações do launcher na TV, deixe **Papel de parede** em **Padrão do tema** (não em uma imagem fixa nem em Nenhum).
- Para voltar ao tema de antes: `instalar-launcher.ps1 -Tv <ip> -Tema "E:\Misc Projects\cleanyourtv\themes\twilight"`.

## O que tem

- **Assassinos** (`slasher\`): Halloween (Michael Myers), Sexta-Feira 13 (Jason), A Hora do Pesadelo (Freddy), Pânico (Ghostface), O Massacre da Serra Elétrica (Leatherface), Brinquedo Assassino (Chucky), Freddy vs. Jason e Terrifier (Art, o palhaço).
- **Zumbis** (`zumbi\`): A Noite dos Mortos-Vivos (1968), Despertar dos Mortos (1978), Madrugada dos Mortos (2004), Dia dos Mortos (1985), Extermínio, Extermínio 2, [REC], Guerra Mundial Z, Invasão Zumbi, Península, #Alive e a série The Walking Dead.
- Cada filme tem 12 fundos em `tema\wallpapers\`, com nome `<filme>-<slot>.jpg`:
  - 8 cenas (`youtube`, `prime`, `stremio`, `crunchyroll`, `twitch`, `kick`, `telhado`, `porao`), que entram todas no mesmo sorteio;
  - `perto1` a `perto3`: as etapas da aproximação;
  - `raro`: a versão rara.
- `tema\wallpapers\captions.txt` traz a legenda de cada fundo, que aparece no canto de cima, à direita. Os lugares, as frases e os avisos foram escritos para o tema; não são falas dos filmes.
- `visao-geral\tema.jpg` mostra os 240 fundos lado a lado.

## Mudar alguma coisa

- **Imagens e legendas:** `gerar_tema.py` diz qual imagem original vai em cada slot, com a legenda e o tratamento de cor. Troque e rode `python gerar_tema.py .` dentro desta pasta (precisa do Pillow: `pip install pillow`).
- **Avisos, tempo e efeitos:** ficam no fim de `gerar_tema.py` (`focus_idle_alerts`, `focus_idle_minutes`, `focus_days` etc.).
- **Sons:** `gerar_sons.py` sintetiza os três (não são gravações de ninguém) em `launcher\app\src\main\res\raw\`. Mudou, recompile.
- Depois, `instalar-tema-terror.ps1 -Tv <ip> -SoTema` (ou sem `-SoTema`, se mexeu nos sons).

As originais estão em `slasher\<assassino>\` e `zumbi\<filme>\`, e `fontes.txt` em cada uma diz de onde veio cada imagem.

## Direitos

São imagens de divulgação dos filmes (via TMDB) e têm dono. Use só na sua TV: não publique nem compartilhe o tema com elas.
