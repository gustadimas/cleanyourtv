> Agora estas imagens fazem parte do tema de terror da TV (veja `..\LEIA-ME.md`). A `previa.html` e a pasta `temas\` eram do plano antigo, para o Fire Stick.

# Tema slasher do Fire Stick — cenas de filmes

- `previa.html`: abra com dois cliques. As imagens já estão dentro do arquivo.
  - A tela é a do launcher do Fire Stick, com os ícones de verdade, e as setas do teclado fazem o papel do controle.
  - Cada movimento sorteia um assassino diferente para o fundo.
  - `N` apaga a luz (lanterna) e `R` mostra a versão rara.
  - Se ficar 8 s parado, o assassino se aproxima em 3 etapas (na TV seriam minutos). Qualquer tecla e ele some.
  - Embaixo da data aparece quanto falta para a próxima sexta-feira 13 ou Halloween. Nesses dias, o assassino da data aparece mais.
- `temas/<assassino>/`: 12 imagens por assassino, em 1280x720, já cortadas e tratadas. São estas que vão para o stick.
  - Uma para cada app: `youtube`, `prime`, `stremio`, `crunchyroll`, `twitch`, `kick`.
  - `telhado`: botões de cima (Wi-Fi e configurações).
  - `porao`: grade de apps.
  - `perto1` a `perto3`: o assassino chegando quando a TV fica parada.
  - `raro`: versão rara (5% das vezes).
- Assassinos: Halloween (Michael Myers), Sexta-Feira 13 (Jason), A Hora do Pesadelo (Freddy), Pânico (Ghostface), O Massacre da Serra Elétrica (Leatherface), Brinquedo Assassino (Chucky), Freddy vs. Jason e Terrifier (Art, o palhaço).
- `halloween`, `sexta13`, `pesadelo`, `panico`, `massacre`, `chucky`, `freddyjason`, `terrifier`: as 119 imagens originais, como vieram do TMDB.
- `fontes.txt` diz de onde veio cada uma, e `visao-geral/` tem miniaturas de tudo.
- `gerar_temas.py` refaz `temas/` a partir das originais: diz qual imagem vai em cada slot, quais são espelhadas e o tratamento de cor de cada assassino. Rode com `python gerar_temas.py .` dentro desta pasta (precisa do Pillow).

As imagens são de divulgação dos filmes (via TMDB) e têm dono. Use só na sua TV: não publique nem compartilhe o tema com elas.
