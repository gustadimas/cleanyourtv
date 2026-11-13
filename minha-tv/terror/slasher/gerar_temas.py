# Gera tema-slasher/temas/<assassino>/<slot>.jpg (1280x720) a partir das imagens TMDB baixadas.
# Uso: python gerar_temas.py <pasta tema-slasher>   (precisa do Pillow: pip install pillow)
# Também gera visao-geral/temas.jpg com todas as imagens lado a lado.
import sys, os
from PIL import Image, ImageEnhance, ImageOps, ImageDraw, ImageFont
root = sys.argv[1]
out_root = os.path.join(root, 'temas')
W, H = 1280, 720
# slot -> 'NN' ou ('NN', {flip, z, fx, fy, b, c})
K = {
 'halloween': {'grade': (1.0, 0.95, 1.08, None), 'slots': {
   'youtube': '03', 'prime': '12', 'stremio': '13', 'crunchyroll': '01', 'twitch': '07', 'kick': ('05', {'flip': 1}),
   'telhado': '14', 'porao': '06', 'perto1': '02', 'perto2': ('11', {'flip': 1}), 'perto3': ('04', {'flip': 1}), 'raro': '15'}},
 'sexta13': {'grade': (0.9, 1.0, 1.06, (10, 30, 42, 0.08)), 'slots': {
   'youtube': '09', 'prime': '12', 'stremio': ('02', {'b': 1.1}), 'crunchyroll': ('04', {'b': 1.25}), 'twitch': '11', 'kick': '03',
   'telhado': '10', 'porao': ('05', {'b': 1.15}), 'perto1': '06', 'perto2': ('02', {'z': 1.3, 'fx': .5, 'fy': .35, 'b': 1.1}), 'perto3': '08', 'raro': '01'}},
 'pesadelo': {'grade': (0.95, 0.93, 1.06, None), 'slots': {
   'youtube': '01', 'prime': '03', 'stremio': '02', 'crunchyroll': '09', 'twitch': '11', 'kick': '06',
   'telhado': '05', 'porao': '13', 'perto1': '10', 'perto2': '12', 'perto3': '14', 'raro': '04'}},
 'panico': {'grade': (0.85, 0.88, 1.05, (18, 24, 40, 0.10)), 'slots': {
   'youtube': '05', 'prime': '12', 'stremio': '04', 'crunchyroll': '08', 'twitch': '15', 'kick': '06',
   'telhado': ('01', {'b': 0.82}), 'porao': '02', 'perto1': '07', 'perto2': '03', 'perto3': '11', 'raro': '13'}},
 'massacre': {'grade': (0.95, 0.93, 1.05, None), 'slots': {
   'youtube': ('06', {'b': 0.88}), 'prime': '15', 'stremio': ('10', {'b': 0.92}), 'crunchyroll': '13', 'twitch': '07', 'kick': '01',
   'telhado': '05', 'porao': '12', 'perto1': '04', 'perto2': '09', 'perto3': '08', 'raro': '14'}},
 'chucky': {'grade': (0.9, 0.92, 1.06, None), 'slots': {
   'youtube': '03', 'prime': '05', 'stremio': '11', 'crunchyroll': '06', 'twitch': ('02', {'b': 0.72, 'c': 1.1}), 'kick': '15',
   'telhado': '01', 'porao': '10', 'perto1': '09', 'perto2': '12', 'perto3': '04', 'raro': '07'}},
 'freddyjason': {'grade': (0.95, 0.93, 1.05, None), 'slots': {
   'youtube': '13', 'prime': '07', 'stremio': '05', 'crunchyroll': '09', 'twitch': '03', 'kick': '02',
   'telhado': '04', 'porao': '06', 'perto1': '15', 'perto2': '01', 'perto3': '12', 'raro': '11'}},
 'terrifier': {'grade': (0.9, 0.92, 1.06, None), 'slots': {
   'youtube': ('12', {'b': 0.88, 'flip': 1}), 'prime': '06', 'stremio': '04', 'crunchyroll': '02', 'twitch': '11', 'kick': '03',
   'telhado': '05', 'porao': '13', 'perto1': '08', 'perto2': '14', 'perto3': '07', 'raro': '10'}},
}
SLOTS = ['youtube', 'prime', 'stremio', 'crunchyroll', 'twitch', 'kick', 'telhado', 'porao', 'perto1', 'perto2', 'perto3', 'raro']

def crop(im, z, fx, fy):
    w, h = im.size; tr = W / H
    if w / h > tr: nw, nh = int(h * tr), h
    else: nw, nh = w, int(w / tr)
    nw, nh = int(nw / z), int(nh / z)
    x = int((w - nw) * fx); y = int((h - nh) * fy)
    return im.crop((x, y, x + nw, y + nh)).resize((W, H), Image.LANCZOS)

rep = []
for k, cfg in K.items():
    od = os.path.join(out_root, k); os.makedirs(od, exist_ok=True)
    sat, bri, con, tint = cfg['grade']
    for slot in SLOTS:
        v = cfg['slots'][slot]
        src, o = (v, {}) if isinstance(v, str) else v
        im = Image.open(os.path.join(root, k, src + '.jpg')).convert('RGB')
        im = crop(im, o.get('z', 1.0), o.get('fx', .5), o.get('fy', .5))
        if o.get('flip'): im = ImageOps.mirror(im)
        im = ImageEnhance.Color(im).enhance(sat)
        im = ImageEnhance.Brightness(im).enhance(bri * o.get('b', 1.0))
        im = ImageEnhance.Contrast(im).enhance(con * o.get('c', 1.0))
        if tint: im = Image.blend(im, Image.new('RGB', im.size, tint[:3]), tint[3])
        p = os.path.join(od, slot + '.jpg'); im.save(p, quality=88, optimize=True, progressive=True)
        rep.append(f'{k}/{slot} <- {src} {o} {os.path.getsize(p)//1024}KB')
print('\n'.join(rep[:4]), '...', len(rep), 'imagens')

# folha de conferência: linhas = assassinos, colunas = slots
try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15)
except OSError:
    try: font = ImageFont.truetype('arialbd.ttf', 15)
    except OSError: font = ImageFont.load_default()
TW, TH = 240, 135
S = Image.new('RGB', (len(SLOTS) * (TW + 4) + 4, len(K) * (TH + 4) + 4), (25, 25, 25)); d = ImageDraw.Draw(S)
for r, k in enumerate(K):
    for c, sl in enumerate(SLOTS):
        im = Image.open(os.path.join(out_root, k, sl + '.jpg')).resize((TW, TH))
        x, y = 4 + c * (TW + 4), 4 + r * (TH + 4); S.paste(im, (x, y))
        lab = f'{k}/{sl}'; w = d.textlength(lab, font=font); d.rectangle([x, y, x + w + 8, y + 19], fill=(0, 0, 0)); d.text((x + 4, y + 1), lab, fill=(255, 220, 0), font=font)
S.save(os.path.join(root, 'visao-geral', 'temas.jpg'), quality=82); print('folha', S.size)
