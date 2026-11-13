# Gera os 3 sons do tema (opcionais, ligados com instalar-tema-terror.ps1 -Som) direto em síntese, sem samples de
# terceiros: estática de fita, batimento cardíaco e um impacto grave com um acorde dissonante.
# Uso: python gerar_sons.py      (precisa do numpy). Escreve em ..\..\launcher\app\src\main\res\raw\
import os, wave
import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'launcher', 'app', 'src', 'main', 'res', 'raw')
rng = np.random.default_rng(13)

def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE

def env(n, attack, release_tau):
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / release_tau)

def lowpass(x, alpha):
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc); y[i] = acc
    return y

def write(name, x, peak=0.85):
    x = np.tanh(x * 1.2)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = min(len(x), int(0.01 * RATE)); x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(data)
    print(name, f'{len(x) / RATE:.2f}s', os.path.getsize(os.path.join(OUT, name)) // 1024, 'KB')

# estática: ruído branco com estalos, um pouco abafado, 0,32 s
n = len(t(0.32))
noise = rng.uniform(-1, 1, n)
crackle = (rng.random(n) > 0.995) * rng.uniform(-1, 1, n) * 3
static = 0.6 * lowpass(noise, 0.55) + 0.4 * noise + crackle
static *= np.clip(np.arange(n) / (0.008 * RATE), 0, 1) * np.clip((n - np.arange(n)) / (0.12 * RATE), 0, 1)
write('fx_estatica.wav', static, 0.6)

# batimento: dois baques graves (tum-tum) com o tom caindo; 0,95 s para repetir no ritmo de ~63 bpm
def thump(start_hz, end_hz, dur, amp):
    x = t(dur); f = start_hz + (end_hz - start_hz) * (x / dur)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    body = np.sin(phase) * env(len(x), 0.004, 0.07)
    click = lowpass(rng.uniform(-1, 1, len(x)), 0.08) * env(len(x), 0.001, 0.012) * 0.6
    return (body + click) * amp
beat = np.zeros(len(t(0.95)))
a = thump(72, 38, 0.30, 1.0); beat[:len(a)] += a
b = thump(64, 34, 0.30, 0.72); s = int(0.24 * RATE); beat[s:s + len(b)] += b
write('fx_coracao.wav', beat, 0.9)

# impacto: estrondo grave + acorde agudo dissonante que treme e some; 1,8 s
x = t(1.8)
boom_f = 50 - 18 * (x / 1.8)
boom = np.sin(2 * np.pi * np.cumsum(boom_f) / RATE) * env(len(x), 0.003, 0.5)
hit = lowpass(rng.uniform(-1, 1, len(x)), 0.15) * env(len(x), 0.001, 0.06) * 0.8
cluster = sum(np.sin(2 * np.pi * f * x + 0.004 * np.sin(2 * np.pi * 6.5 * x) * f) for f in (1046.5, 1108.7, 1174.7, 1661.2))
cluster *= env(len(x), 0.03, 0.55) * 0.09
write('fx_impacto.wav', boom + hit + cluster, 0.85)
