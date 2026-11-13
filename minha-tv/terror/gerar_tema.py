# Gera o tema da TV (pasta tema/): 20 conjuntos (8 assassinos + 12 filmes/série de zumbi) x 12 slots.
# Uso: python gerar_tema.py .        (dentro da pasta terror; precisa do Pillow: pip install pillow)
#  - lê slasher/<assassino>/NN.jpg e zumbi/<filme>/NN.jpg (backdrops do TMDB, 1280x720)
#  - escreve tema/wallpapers/<conjunto>-<slot>.jpg, tema/wallpapers/captions.txt e tema/config.json
#  - e visao-geral/tema.jpg com todos os fundos lado a lado.
# Slots: youtube prime stremio crunchyroll twitch kick (um por app do dock), telhado (botões de cima),
# porao (grade), raro (1 em 20), perto1-3 (a ameaça chegando quando a TV fica parada na tela inicial).
import sys, os, json
from PIL import Image, ImageEnhance, ImageOps, ImageDraw, ImageFont

root = sys.argv[1] if len(sys.argv) > 1 else '.'
W, H = 1280, 720
SLOTS = ['youtube', 'prime', 'stremio', 'crunchyroll', 'twitch', 'kick', 'telhado', 'porao', 'perto1', 'perto2', 'perto3', 'raro']
ASSASSINOS = ['halloween', 'sexta13', 'pesadelo', 'panico', 'massacre', 'chucky', 'freddyjason', 'terrifier']
ZUMBIS = ['noite68', 'despertar78', 'madrugada04', 'dia85', 'exterminio', 'exterminio2', 'rec', 'guerraz', 'busan', 'peninsula', 'alive', 'twd']

# conjunto: (pasta de origem, (saturação, brilho, contraste, tinta), {slot: (imagem, opções, legenda)})
# opções: flip (espelha), z (zoom), fx/fy (ponto do zoom, 0..1), b/c (brilho/contraste extra)
T = {
 'halloween': ('slasher/halloween', (1.0, 0.95, 1.08, None), {
  'youtube': ('03', {}, 'Haddonfield — Ele some quando você olha de novo.'),
  'prime': ('12', {}, 'Noite de babá — A luz do corredor não acende.'),
  'stremio': ('13', {}, 'Vigília — O doutor espera do outro lado da rua.'),
  'crunchyroll': ('01', {}, 'Armário — Um cabide é a única arma que sobrou.'),
  'twitch': ('07', {}, 'Fantasia — Um lençol e um par de óculos.'),
  'kick': ('05', {'flip': 1}, 'Escada — Ele desce devagar. Nunca corre.'),
  'telhado': ('14', {}, '31 de outubro — As abóboras ainda estão acesas.'),
  'porao': ('06', {}, 'Casa da esquina — Ninguém mora lá. A luz acendeu.'),
  'perto1': ('02', {}, 'Calçada — Alguém está te seguindo.'),
  'perto2': ('11', {'flip': 1}, 'Porta da frente — A porta ficou aberta.'),
  'perto3': ('04', {'flip': 1}, 'Atrás da porta — Ele está aqui.'),
  'raro': ('15', {}, 'Armário — Atrás de você.')}),
 'sexta13': ('slasher/sexta13', (0.9, 1.0, 1.06, (10, 30, 42, 0.08)), {
  'youtube': ('09', {}, 'Crystal Lake — A luz da varanda apagou sozinha.'),
  'prime': ('12', {}, 'Trilha do lago — Não solte a mão dela.'),
  'stremio': ('02', {'b': 1.1}, 'Floresta — Ele anda. Você corre. Ele chega antes.'),
  'crunchyroll': ('04', {'b': 1.25}, 'Cemitério — Chuva forte e um facão.'),
  'twitch': ('11', {}, 'Máscara de hóquei — Atrás dela não tem ninguém.'),
  'kick': ('03', {}, 'Túmulo — Nunca deviam ter desenterrado.'),
  'telhado': ('10', {}, 'Cabana 4 — Vazia desde o verão.'),
  'porao': ('05', {'b': 1.15}, 'Barracão — O facão sumiu do gancho.'),
  'perto1': ('06', {}, 'Margem do lago — Tem alguém entre as árvores.'),
  'perto2': ('02', {'z': 1.3, 'fx': .5, 'fy': .35, 'b': 1.1}, 'Clareira — Ele está vindo para a cabana.'),
  'perto3': ('08', {}, 'Varanda — Ele colocou a máscara.'),
  'raro': ('01', {}, 'Acampamento — Conte quantos são. Conte de novo.')}),
 'pesadelo': ('slasher/pesadelo', (0.95, 0.93, 1.06, None), {
  'youtube': ('01', {}, 'Banheira — Não feche os olhos.'),
  'prime': ('03', {}, 'Escola — Um rastro vermelho até o fim do corredor.'),
  'stremio': ('02', {}, '3h da manhã — Tem um rosto na parede.'),
  'crunchyroll': ('09', {}, 'Sala de aula — Isso não estava aqui antes.'),
  'twitch': ('11', {}, 'Elm Street — Faz três noites que ela não dorme.'),
  'kick': ('06', {}, 'Garras — Lâminas riscando a parede.'),
  'telhado': ('05', {}, 'Elm Street — Todas as luzes acesas às 3h.'),
  'porao': ('13', {}, 'Caldeira — Aqui embaixo é sempre quente.'),
  'perto1': ('10', {}, 'Neblina — Tem alguém no fim da neblina.'),
  'perto2': ('12', {}, 'Beco — Os braços dele crescem.'),
  'perto3': ('14', {}, 'Caldeira — Você dormiu.'),
  'raro': ('04', {}, 'Corredor — Ela quer te mostrar uma coisa.')}),
 'panico': ('slasher/panico', (0.85, 0.88, 1.05, (18, 24, 40, 0.10)), {
  'youtube': ('05', {}, 'Woodsboro — Tem uma faca faltando no bloco.'),
  'prime': ('12', {}, 'Telefone — A voz sabia o nome dela.'),
  'stremio': ('04', {}, 'Festa — Todo mundo é suspeito.'),
  'crunchyroll': ('08', {}, 'Cozinha — Ele está vendo você agora.'),
  'twitch': ('15', {}, 'Quarto — Ele sabe a cor da sua blusa.'),
  'kick': ('06', {}, 'Janela — Ele entrou pela janela. De novo.'),
  'telhado': ('01', {'b': 0.82}, 'Escola — Toque de recolher às 21h.'),
  'porao': ('02', {}, 'Suspeitos — Um deles está mentindo.'),
  'perto1': ('07', {}, 'Sala — O telefone tocou.'),
  'perto2': ('03', {}, 'Varanda — Ele sabe onde você está.'),
  'perto3': ('11', {}, 'Sala — Ele já entrou.'),
  'raro': ('13', {}, 'Jornal — Mais um caso sem suspeito.')}),
 'massacre': ('slasher/massacre', (0.95, 0.93, 1.05, None), {
  'youtube': ('06', {'b': 0.88}, 'Texas — Cinco amigos e uma van.'),
  'prime': ('15', {}, 'Van — Ninguém devia ter dado carona.'),
  'stremio': ('10', {'b': 0.92}, 'Campo — Não vá até a casa vizinha.'),
  'crunchyroll': ('13', {}, 'Cemitério — Alguém andou abrindo túmulos.'),
  'twitch': ('07', {}, 'Jantar — O jantar está servido.'),
  'kick': ('01', {}, 'Olho — Não pisque.'),
  'telhado': ('05', {}, 'Lua cheia — Noite quente. Ninguém dorme.'),
  'porao': ('12', {}, 'Sala dos ossos — Os móveis são feitos de quê?'),
  'perto1': ('04', {}, 'Pôr do sol — Tem alguém andando no campo.'),
  'perto2': ('09', {}, 'Casa da família — Você entrou na casa errada.'),
  'perto3': ('08', {}, 'Cozinha — Ouviu o motor?'),
  'raro': ('14', {}, 'Estrada — A serra ligou.')}),
 'chucky': ('slasher/chucky', (0.9, 0.92, 1.06, None), {
  'youtube': ('03', {}, 'Quarto — Ele mexeu a cabeça. Juro.'),
  'prime': ('05', {}, 'Aniversário — Sem pilha. Ele fala mesmo assim.'),
  'stremio': ('11', {}, 'Presente — Uma faca no lugar do laço.'),
  'crunchyroll': ('06', {}, 'Tempestade — Raio no prédio. As luzes apagam.'),
  'twitch': ('02', {'b': 0.72, 'c': 1.1}, 'Loja — Um raio, um ritual, um boneco.'),
  'kick': ('15', {}, 'Prateleira — Ele é pequeno. A faca não.'),
  'telhado': ('01', {}, 'Sala — Ele adora desenho animado.'),
  'porao': ('10', {}, 'Porão — Passinhos no andar de cima.'),
  'perto1': ('09', {}, 'Parapeito — Passos pequenos lá fora.'),
  'perto2': ('12', {}, 'Cozinha — Ele achou a faca.'),
  'perto3': ('04', {}, 'Escuro — Ele está embaixo da cama.'),
  'raro': ('07', {}, 'Debaixo da cama — Ele não é de brinquedo.')}),
 'freddyjason': ('slasher/freddyjason', (0.95, 0.93, 1.05, None), {
  'youtube': ('13', {}, 'Acampamento — Dois monstros e uma noite só.'),
  'prime': ('07', {}, 'Píer — Ninguém nada à noite.'),
  'stremio': ('05', {}, 'Springwood — Ele precisa que você tenha medo.'),
  'crunchyroll': ('09', {}, 'Fogo — Fogo não mata quem já morreu.'),
  'twitch': ('03', {}, 'Cara a cara — Nenhum dos dois pisca.'),
  'kick': ('02', {}, 'Neblina — Garras contra facão.'),
  'telhado': ('04', {}, 'Crystal Lake — O lago está calmo demais.'),
  'porao': ('06', {}, 'Duelo — O vencedor ainda está por aí.'),
  'perto1': ('15', {}, 'Rua — Alguém de chapéu na calçada.'),
  'perto2': ('01', {}, 'Caldeiras — Os dois estão aqui embaixo.'),
  'perto3': ('12', {}, 'Escuro — Os dois te viram.'),
  'raro': ('11', {}, 'Pesadelo duplo — Hoje são dois.')}),
 'terrifier': ('slasher/terrifier', (0.9, 0.92, 1.06, None), {
  'youtube': ('12', {'b': 0.88, 'flip': 1}, 'Quarto infantil — Ele não fala. Só sorri.'),
  'prime': ('06', {}, 'Cortina vermelha — O show está começando.'),
  'stremio': ('04', {}, 'Porta dos fundos — Ele acenou. Não acene de volta.'),
  'crunchyroll': ('02', {}, 'Halloween — Doces ou travessuras? Nenhum dos dois.'),
  'twitch': ('11', {}, 'Lua vermelha — Ele voltou na noite errada.'),
  'kick': ('03', {}, 'Parque — A roda-gigante girou sozinha.'),
  'telhado': ('05', {}, 'Halloween — As fantasias estão em liquidação.'),
  'porao': ('13', {}, 'Palco — Ele ensaia no porão.'),
  'perto1': ('08', {}, 'Loja de fantasias — Tem um palhaço parado na loja.'),
  'perto2': ('14', {}, 'Corredor — Ele está encostado na sua porta.'),
  'perto3': ('07', {}, 'Aqui — Ele está acenando para você.'),
  'raro': ('10', {}, 'Balcão da loja — Não vire.')}),
 'noite68': ('zumbi/noite68', (1.0, 0.95, 1.08, None), {
  'youtube': ('13', {}, 'Cemitério — Era só para deixar flores no túmulo.'),
  'prime': ('16', {}, 'Fazenda — Pregue as tábuas antes do anoitecer.'),
  'stremio': ('20', {}, 'Janela — O fogo afasta eles. Por um tempo.'),
  'crunchyroll': ('07', {}, 'Patrulha — Eles andam devagar. Mas não param.'),
  'twitch': ('09', {}, 'Quintal — Estão cercando a casa.'),
  'kick': ('19', {}, 'Noite — A caminhonete pegou fogo.'),
  'telhado': ('08', {}, 'Casa da fazenda — Ninguém sai até amanhecer.'),
  'porao': ('14', {}, 'Porão — O porão é mais seguro. Ele jura.'),
  'perto1': ('05', {}, 'Campo aberto — Eles vêm pelo campo.'),
  'perto2': ('06', {}, 'Noite — Estão na varanda.'),
  'perto3': ('02', {}, 'Escuro — Ela acordou com fome.'),
  'raro': ('03', {}, 'Escada — Tem alguém no andar de cima.')}),
 'despertar78': ('zumbi/despertar78', (0.9, 0.92, 1.05, None), {
  'youtube': ('02', {}, 'Shopping — Eles voltam para onde viviam.'),
  'prime': ('17', {}, 'Loja de departamentos — Tudo de graça. Ninguém no caixa.'),
  'stremio': ('06', {}, 'Corredor — Quatro sobreviventes e um shopping.'),
  'crunchyroll': ('15', {}, 'Loja — Eles lembram de fazer compras.'),
  'twitch': ('13', {}, 'Escritório — Ninguém quer ficar aqui para sempre.'),
  'kick': ('18', {}, 'Depósito — Feche a porta de aço.'),
  'telhado': ('03', {}, 'Telhado — O helicóptero ainda tem combustível.'),
  'porao': ('19', {}, 'Depósito — Munição contada, porta trancada.'),
  'perto1': ('04', {}, 'Estacionamento — O estacionamento está cheio.'),
  'perto2': ('14', {}, 'Corredor — Eles entraram no shopping.'),
  'perto3': ('01', {}, 'Porta — Estão na porta.'),
  'raro': ('12', {}, 'Quarto — Ele acordou diferente.')}),
 'madrugada04': ('zumbi/madrugada04', (0.9, 0.9, 1.05, None), {
  'youtube': ('05', {'b': 0.9}, 'Rua — Eles correm.'),
  'prime': ('12', {}, 'Shopping — Mais sobreviventes. Mais problemas.'),
  'stremio': ('03', {}, 'Elevador — Ninguém aperta o botão do subsolo.'),
  'crunchyroll': ('01', {}, 'Viatura — Dirija. Não pare para ninguém.'),
  'twitch': ('19', {}, 'Mercado — Ela foi mordida. Ela diz que não.'),
  'kick': ('02', {}, 'Janela — Uma mão no vidro.'),
  'telhado': ('07', {}, 'Sala de segurança — As câmeras mostram o estacionamento.'),
  'porao': ('20', {}, 'Garagem — Os ônibus blindados estão prontos.'),
  'perto1': ('09', {}, 'Rodovia — São milhares.'),
  'perto2': ('04', {}, 'Pôr do sol — Eles vêm do sol.'),
  'perto3': ('06', {}, 'Rua — Ele está correndo na sua direção.'),
  'raro': ('15', {}, 'Horizonte — O dia acabou.')}),
 'dia85': ('zumbi/dia85', (0.9, 0.92, 1.05, None), {
  'youtube': ('03', {}, 'Laboratório — Ele aprende a ouvir música.'),
  'prime': ('13', {}, 'Bunker — Cientistas e soldados não se entendem.'),
  'stremio': ('06', {}, 'Corredor — Ele bateu continência.'),
  'crunchyroll': ('15', {}, 'Arsenal — O capitão perdeu a paciência.'),
  'twitch': ('09', {}, 'Laboratório — Ele lembra como se barbeia.'),
  'kick': ('04', {}, 'Laboratório — Ele achou uma arma.'),
  'telhado': ('08', {}, 'Bunker — Um dia comum no fim do mundo.'),
  'porao': ('11', {}, 'Curral — Eles ficam presos na caverna.'),
  'perto1': ('18', {}, 'Cerca — A cerca está cedendo.'),
  'perto2': ('17', {}, 'Elevador — O elevador desceu sozinho.'),
  'perto3': ('05', {}, 'Escuro — Ele está a um passo.'),
  'raro': ('02', {}, 'Parede — Mãos atravessando a parede.')}),
 'exterminio': ('zumbi/exterminio', (0.9, 0.92, 1.06, None), {
  'youtube': ('05', {'b': 0.85}, 'Londres — Ponte vazia. Cidade vazia.'),
  'prime': ('06', {}, 'Táxi — Ninguém dirige à noite.'),
  'stremio': ('09', {}, 'Apartamento — Uma família improvisada.'),
  'crunchyroll': ('10', {}, 'Túnel — A lanterna atrai eles.'),
  'twitch': ('11', {}, 'Posto — Gasolina para mais um dia.'),
  'kick': ('17', {'b': 0.85}, 'Igreja — Não entre na igreja.'),
  'telhado': ('14', {'b': 0.9}, 'Telhado — Água da chuva e um rádio.'),
  'porao': ('13', {}, 'Escada — Ninguém sobe sozinho.'),
  'perto1': ('20', {}, 'Hospital — Você acordou sozinho.'),
  'perto2': ('08', {}, 'Chuva — Um soldado infectado.'),
  'perto3': ('02', {}, 'Olhos vermelhos — Vinte segundos para virar.'),
  'raro': ('18', {}, 'Mansão — Ninguém aqui está salvo.')}),
 'exterminio2': ('zumbi/exterminio2', (0.9, 0.9, 1.05, None), {
  'youtube': ('13', {'b': 0.9}, 'Zona verde — Os soldados te escoltam.'),
  'prime': ('19', {'b': 0.9}, 'Telhado — O atirador tem ordens novas.'),
  'stremio': ('16', {'b': 0.9}, 'Rua — Corram para o metrô.'),
  'crunchyroll': ('12', {}, 'Helicóptero — Nenhum lugar é seguro.'),
  'twitch': ('08', {}, 'Túnel — Siga a luz. Não pare.'),
  'kick': ('20', {}, 'Crianças — Eles têm os olhos da mãe.'),
  'telhado': ('17', {}, 'Estádio — O ponto de encontro está vazio.'),
  'porao': ('14', {'b': 0.9}, 'Portão — A quarentena falhou.'),
  'perto1': ('10', {}, 'Cidade — Eles voltaram para Londres.'),
  'perto2': ('06', {}, 'Fazenda — Ele correu. Ela ficou.'),
  'perto3': ('18', {}, 'Píer — O barco não vai esperar.'),
  'raro': ('07', {'b': 0.85}, 'Código vermelho — Contaminação confirmada.')}),
 'rec': ('zumbi/rec', (0.95, 0.97, 1.05, None), {
  'youtube': ('08', {}, 'Quartel — Uma noite tranquila com os bombeiros.'),
  'prime': ('16', {}, 'Prédio — O prédio foi lacrado por fora.'),
  'stremio': ('02', {}, 'Apartamento — Tem alguém no escuro.'),
  'crunchyroll': ('17', {}, 'Escada — Vista de cima, é pior.'),
  'twitch': ('19', {}, 'Câmera — Continue gravando.'),
  'kick': ('07', {}, 'Térreo — Um bombeiro caiu da escada.'),
  'telhado': ('09', {}, 'Quartel — Reportagem ao vivo.'),
  'porao': ('06', {}, 'Cobertura — Ninguém sobe à cobertura.'),
  'perto1': ('10', {}, 'Escada — Eles estão subindo.'),
  'perto2': ('18', {}, 'Corredor — Ela ainda é uma menina?'),
  'perto3': ('01', {}, 'Luz da câmera — Não baixe a câmera.'),
  'raro': ('14', {}, 'Visão noturna — Não faça barulho.')}),
 'guerraz': ('zumbi/guerraz', (0.85, 0.88, 1.06, None), {
  'youtube': ('13', {'b': 0.9}, 'Filadélfia — O trânsito parou de vez.'),
  'prime': ('17', {'b': 0.9}, 'Táxi — Dirija. Não olhe para trás.'),
  'stremio': ('10', {}, 'Cidade em chamas — Família primeiro.'),
  'crunchyroll': ('04', {'b': 0.9}, 'Muralha — Soldados e civis na mesma fila.'),
  'twitch': ('02', {}, 'Corredor vermelho — Doze segundos para virar.'),
  'kick': ('09', {}, 'Helicóptero — A cidade caiu.'),
  'telhado': ('06', {}, 'Telhado — A cidade inteira, lá embaixo.'),
  'porao': ('07', {'b': 1.35}, 'Laboratório — Ala B. Silêncio total.'),
  'perto1': ('11', {}, 'Horizonte — Fumaça em todas as direções.'),
  'perto2': ('18', {}, 'Muralha — Eles escalam uns aos outros.'),
  'perto3': ('01', {'z': 1.3, 'fx': .95, 'fy': .5}, 'Muralha — Passaram a muralha.'),
  'raro': ('14', {'b': 0.85}, 'Fim do mundo — Ninguém sabe onde começou.')}),
 'busan': ('zumbi/busan', (0.85, 0.9, 1.05, None), {
  'youtube': ('01', {}, 'Trem — Vagão 13. Ninguém sai.'),
  'prime': ('06', {}, 'Vagão — Fita adesiva nos braços.'),
  'stremio': ('18', {}, 'Vagão — Ele não abre a porta para ninguém.'),
  'crunchyroll': ('03', {}, 'Estação — Corram para a próxima estação.'),
  'twitch': ('07', {}, 'Trilhos — Pai e filha nos destroços.'),
  'kick': ('17', {}, 'Corredor — Eles não enxergam no escuro.'),
  'telhado': ('15', {}, 'Trilhos — A cidade caiu atrás do trem.'),
  'porao': ('12', {}, 'Vagão — Ele trancou a porta por dentro.'),
  'perto1': ('16', {'b': 0.9}, 'Estação — Fuja. Agora.'),
  'perto2': ('11', {}, 'Vagão — Estão no vagão ao lado.'),
  'perto3': ('09', {}, 'Vagão — Atrás de você.'),
  'raro': ('13', {}, 'Busan — Última parada.')}),
 'peninsula': ('zumbi/peninsula', (0.9, 0.95, 1.05, None), {
  'youtube': ('17', {}, 'Península — Quatro anos depois.'),
  'prime': ('02', {}, 'Arena — Lá dentro, eles apostam vidas.'),
  'stremio': ('10', {}, 'Mercado — Luzes vermelhas atraem eles.'),
  'crunchyroll': ('07', {}, 'Abrigo — Uma família sobreviveu aqui.'),
  'twitch': ('05', {}, 'Ruína — Ninguém aqui é seu amigo.'),
  'kick': ('15', {}, 'Rua — Eles ouvem o motor.'),
  'telhado': ('12', {}, 'Pôr do sol — O caminhão ainda anda.'),
  'porao': ('08', {}, 'Escada rolante — Ela parou no meio.'),
  'perto1': ('14', {}, 'Rua escura — Tem alguém na rua.'),
  'perto2': ('01', {}, 'Luz — A luz chama eles.'),
  'perto3': ('16', {}, 'Carro — O carro está cercado.'),
  'raro': ('13', {}, 'Noite — Não pare o carro.')}),
 'alive': ('zumbi/alive', (0.9, 0.93, 1.05, None), {
  'youtube': ('01', {}, 'Apartamento — O drone ainda voa.'),
  'prime': ('09', {}, 'Varanda — Ela está viva do outro lado.'),
  'stremio': ('16', {}, 'Rádio — Alguém responde no rádio.'),
  'crunchyroll': ('13', {}, 'Corredor — A porta do vizinho está aberta.'),
  'twitch': ('02', {}, 'Corredor — A comida acabou ontem.'),
  'kick': ('19', {'b': 0.85}, 'Varanda — Corda improvisada.'),
  'telhado': ('04', {}, 'Prédio — Sem sinal. Sem internet.'),
  'porao': ('15', {}, 'Sala — Dia 20 sem sair de casa.'),
  'perto1': ('08', {}, 'Lá embaixo — Eles estão no térreo.'),
  'perto2': ('06', {}, 'Corredor — Estão no seu andar.'),
  'perto3': ('07', {}, 'Janela — Ele está escalando.'),
  'raro': ('03', {}, 'Porta — Não abra para ninguém.')}),
 'twd': ('zumbi/twd', (0.85, 0.9, 1.06, None), {
  'youtube': ('03', {}, 'Atlanta — A cidade está tomada.'),
  'prime': ('06', {}, 'Prisão — O lugar mais seguro que achamos.'),
  'stremio': ('08', {}, 'Cerca — A cerca aguenta mais um dia.'),
  'crunchyroll': ('10', {}, 'Clareira — Ajoelhados, em fila.'),
  'twitch': ('18', {}, 'Mata — Ninguém fica para trás.'),
  'kick': ('22', {}, 'Comunidade — Regras novas.'),
  'telhado': ('01', {}, 'Rodovia — A saída de Atlanta está parada.'),
  'porao': ('19', {}, 'Celeiro — O celeiro está trancado. Por quê?'),
  'perto1': ('25', {}, 'Colina — Fumaça no horizonte.'),
  'perto2': ('05', {}, 'Rua — A horda está passando.'),
  'perto3': ('12', {}, 'Mata — Mãos saindo da neblina.'),
  'raro': ('23', {}, 'Sussurradores — Fale baixo.')}),
}

FOCUS = ['com.google.android.youtube.tv=youtube', 'com.amazon.amazonvideo.livingroom=prime', 'com.stremio.one=stremio',
         'com.crunchyroll.crunchyroid=crunchyroll', 'tv.twitch.android.app=twitch', 'tv.twitch.android.viewer=twitch',
         'com.kick.mobile=kick', '*dock=twitch', '*grid=porao']
CONFIG = {'wallpaper': True, 'wallpaper_rotation_minutes': 1440, 'wallpaper_order': 'shuffle', 'wallpaper_captions': True,
          'wallpaper_dim': 12, 'ambient_glow': False, 'dock_glass': True, 'dock_opacity': 55,
          'focus_wallpapers': FOCUS,
          # todos os fundos de cena num sorteio só, sem repetir até passar 3/4 deles (o histórico fica salvo na TV)
          'focus_mix': True,
          # transições (empurrão na direção do movimento, estática de fita, lâmpada falhando) e efeitos da aproximação
          'focus_effects': True,
          # uma transição só para todas as trocas (12/11, pedido do dono): a estática de TV, com 0,6 s na tela.
          # "mix" volta à mistura (quase sempre empurrão, às vezes estática ou lâmpada)
          'focus_style': 'static',
          'focus_style_ms': 600,
          # sons da aproximação e do raro (res/raw do launcher); o instalador liga com -Som
          'focus_sounds': False,
          # minutos parado por etapa da aproximação (aceita fração: 0.25 = 15 s, para testar)
          'focus_idle_minutes': 1,
          'focus_sets': ['assassino=' + ','.join(ASSASSINOS), 'zumbi=' + ','.join(ZUMBIS)],
          # avisos grandes de cada etapa e o da volta, por tipo de filme
          'focus_idle_alerts': ['assassino=Tem alguém lá fora|A porta está aberta|Ele está dentro de casa|Ele sumiu.',
                                'zumbi=Movimento lá fora|Estão na cerca|Eles entraram|Eles recuaram.'],
          # sexta-feira 13 e Halloween: esses filmes aparecem mais
          'focus_days': ['F13=sexta13,freddyjason', '10-31=halloween,terrifier']}

def crop(im, z, fx, fy):
    w, h = im.size; tr = W / H
    if w / h > tr: nw, nh = int(h * tr), h
    else: nw, nh = w, int(w / tr)
    nw, nh = int(nw / z), int(nh / z)
    x = int((w - nw) * fx); y = int((h - nh) * fy)
    return im.crop((x, y, x + nw, y + nh)).resize((W, H), Image.LANCZOS)

assert list(T) == ASSASSINOS + ZUMBIS
out = os.path.join(root, 'tema', 'wallpapers'); os.makedirs(out, exist_ok=True)
for f in os.listdir(out):   # tira fundos de conjuntos que saíram do tema (os atuais são regravados abaixo)
    if f.endswith('.jpg') and f.split('-')[0] not in T:
        try: os.remove(os.path.join(out, f))
        except OSError: print('não consegui apagar', f)
caps = []
for name, (src, grade, slots) in T.items():
    assert set(slots) == set(SLOTS), name
    sat, bri, con, tint = grade
    for slot in SLOTS:
        nn, o, cap = slots[slot]
        assert len(cap) <= 64, (name, slot, len(cap))
        im = Image.open(os.path.join(root, src, nn + '.jpg')).convert('RGB')
        im = crop(im, o.get('z', 1.0), o.get('fx', .5), o.get('fy', .5))
        if o.get('flip'): im = ImageOps.mirror(im)
        im = ImageEnhance.Color(im).enhance(sat)
        im = ImageEnhance.Brightness(im).enhance(bri * o.get('b', 1.0))
        im = ImageEnhance.Contrast(im).enhance(con * o.get('c', 1.0))
        if tint: im = Image.blend(im, Image.new('RGB', im.size, tint[:3]), tint[3])
        fn = f'{name}-{slot}.jpg'
        im.save(os.path.join(out, fn), quality=82, optimize=True, progressive=True)
        caps.append(f'{fn}\t{cap}')
open(os.path.join(out, 'captions.txt'), 'w', encoding='utf-8', newline='\n').write('\n'.join(caps) + '\n')
open(os.path.join(root, 'tema', 'config.json'), 'w', encoding='utf-8', newline='\n').write(json.dumps(CONFIG, indent=2, ensure_ascii=False) + '\n')
size = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
print(f'{len(caps)} fundos, {size / 1e6:.1f} MB em tema/wallpapers')

# folha de conferência
try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 13)
except OSError:
    try: font = ImageFont.truetype('arialbd.ttf', 13)
    except OSError: font = ImageFont.load_default()
TW, TH = 192, 108
S = Image.new('RGB', (len(SLOTS) * (TW + 3) + 3, len(T) * (TH + 3) + 3), (25, 25, 25)); d = ImageDraw.Draw(S)
for r, name in enumerate(T):
    for c, slot in enumerate(SLOTS):
        im = Image.open(os.path.join(out, f'{name}-{slot}.jpg')).resize((TW, TH))
        x, y = 3 + c * (TW + 3), 3 + r * (TH + 3); S.paste(im, (x, y))
        lab = f'{name}-{slot}'; w = d.textlength(lab, font=font); d.rectangle([x, y, x + w + 6, y + 16], fill=(0, 0, 0)); d.text((x + 3, y + 1), lab, fill=(255, 220, 0), font=font)
os.makedirs(os.path.join(root, 'visao-geral'), exist_ok=True)
S.save(os.path.join(root, 'visao-geral', 'tema.jpg'), quality=80); print('folha', S.size)
