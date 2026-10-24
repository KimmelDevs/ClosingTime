"""Render the game's sounds to WAV files (godot/audio). Every sound is synthesized; replace any WAV with your own."""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'audio')
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(1989)

def t_(d): return np.arange(int(SR * d)) / SR
def noise(d): return R.uniform(-1, 1, int(SR * d))
def osc(kind, f, d):
    """f may be a scalar or an array (frequency over time)."""
    n = int(SR * d)
    if np.ndim(f) == 0: f = np.full(n, float(f))
    else: f = np.asarray(f, float); f = np.pad(f, (0, max(0, n - len(f))), mode='edge')[:n]  # hold the last frequency
    ph = np.cumsum(f) / SR
    if kind == 'sine': return np.sin(2 * np.pi * ph)
    if kind == 'tri': return 2 * np.abs(2 * (ph % 1) - 1) - 1
    if kind == 'square': return np.sign(np.sin(2 * np.pi * ph))
    return 2 * (ph % 1) - 1  # saw
def sweep(f0, f1, d): return np.geomspace(f0, f1, int(SR * d))
def env(n, a, d, peak=1.0):
    """attack seconds, then exponential decay over d seconds"""
    tt = np.arange(n) / SR
    e = np.where(tt < a, tt / max(a, 1e-4), np.exp(-(tt - a) / max(d, 1e-4) * 5))
    return e * peak
def ffilt(x, kind, f, q=0.7):
    """frequency-domain filter (offline, so we can afford it)"""
    X = np.fft.rfft(x); fr = np.fft.rfftfreq(len(x), 1 / SR) + 1e-6
    if kind == 'lp': H = 1 / np.sqrt(1 + (fr / f) ** 4)
    elif kind == 'hp': H = 1 / np.sqrt(1 + (f / fr) ** 4)
    else:  # band
        bw = f / max(q, 0.1); H = 1 / np.sqrt(1 + ((fr - f) / (bw / 2)) ** 2)
    return np.fft.irfft(X * H, len(x))
def pad(x, d):
    n = int(SR * d)
    return np.pad(x, (0, max(0, n - len(x))))[:n]
def mix(*parts, d=None):
    n = max(len(p) for p in parts) if d is None else int(SR * d)
    out = np.zeros(n)
    for p in parts: out[:min(n, len(p))] += p[:min(n, len(p))]
    return out
def at(x, sec, total):
    out = np.zeros(int(SR * total)); i = int(SR * sec); n = min(len(x), len(out) - i)
    if n > 0: out[i:i + n] += x[:n]
    return out
def reverb(x, sec=2.6, wet=0.35):
    n = int(SR * sec); ir = R.uniform(-1, 1, n) * (1 - np.arange(n) / n) ** 2.6
    L = len(x) + n; y = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)
    y = y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))
    return np.pad(x, (0, n)) * (1 - wet) + y * wet
def loopify(x, fade=0.4):
    """crossfade the tail into the head so the loop is seamless"""
    n = int(SR * fade); head, tail = x[:n].copy(), x[-n:]
    w = np.linspace(0, 1, n); x = x[:-n].copy(); x[:n] = head * w + tail * (1 - w); return x
def save(name, x, norm=0.9, stereo=False):
    x = np.asarray(x, float); m = np.max(np.abs(x)) + 1e-9
    x = np.clip(x / m * norm, -1, 1)
    data = (x * 32767).astype('<i2')
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

# ---------- loops ----------
d = 16
drone = sum(osc('saw', f, d) for f in (41.2, 41.7, 82.1))
drone = ffilt(drone, 'lp', 150) * 0.6 + ffilt(noise(d), 'band', 160, 0.7) * 0.8
save('drone_loop', loopify(drone), 0.7)
tension = sum(osc('sine', f, 8) for f in (233.1, 246.9, 349.2)) * 0.5 + ffilt(osc('saw', 58, 8), 'lp', 500)
save('tension_loop', loopify(tension), 0.7)
hum = sum(osc('saw', f, 4) * (20 / f) for f in (60, 120, 180))
save('hum_loop', loopify(ffilt(hum, 'lp', 900), 0.2), 0.5)

def mtof(m): return 440 * 2 ** ((m - 69) / 12)
chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
total = 2.4 * 4 * 2
muz = np.zeros(int(SR * total))
for rep in range(2):
    for i, ch in enumerate(chords):
        st = (rep * 4 + i) * 2.4
        for m in ch: muz += at(osc('sine', mtof(m), 2.6) * env(int(SR * 2.6), 0.25, 2.2, 0.25), st, total)
        muz += at(osc('sine', mtof(ch[0] - 12), 2.4) * env(int(SR * 2.4), 0.05, 2.0, 0.35), st, total)
        for k in range(3):
            muz += at(osc('tri', mtof(R.choice(ch) + 12), 0.8) * env(int(SR * 0.8), 0.01, 0.7, 0.12), st + k * 0.8, total)
save('muzak_loop', loopify(ffilt(reverb(muz, 2.0, 0.3)[:len(muz)], 'lp', 2200), 0.3), 0.6)

waltz = [(7, 1), (3, 1), (5, 1), (7, 2), (10, 1), (8, 1), (7, 1), (5, 1), (3, 3), (5, 1), (3, 1), (2, 1), (3, 2), (7, 1), (5, 1), (3, 1), (0, 1), (2, 3),
         (7, 1), (3, 1), (5, 1), (12, 2), (10, 1), (8, 1), (7, 1), (3, 1), (5, 3), (3, 1), (2, 1), (-2, 1), (0, 2), (3, 1), (2, 1), (-1, 1), (2, 1), (0, 3)]
beat = 0.36; total = sum(b for _, b in waltz) * beat
mb = np.zeros(int(SR * (total + 1.5))); tt = 0
for semi, b in waltz:
    f = 880 * 2 ** (semi / 12) * (1 + R.uniform(-0.004, 0.004))
    for mul, a in ((1, 1), (2.01, 0.35), (4.17, 0.12)):
        dd = 1.3 / mul + 0.2
        mb += at(osc('sine', f * mul, dd) * env(int(SR * dd), 0.002, dd, a), tt, total + 1.5)
    tt += b * beat
mb = mb[:int(SR * total)] + np.pad(mb[int(SR * total):], (0, int(SR * total) - len(mb[int(SR * total):])))[:int(SR * total)]
save('musicbox_loop', mb, 0.8)

# ---------- one-shots ----------
for i in range(4):
    p = R.uniform(0.85, 1.15); n = noise(0.25)
    heel = ffilt(n, 'lp', 260 * p) * env(len(n), 0.001, 0.12) + ffilt(n, 'band', 2100 * p, 3.5) * env(len(n), 0.001, 0.04, 0.8)
    heel += osc('sine', sweep(140 * p, 70 * p, 0.25), 0.25) * env(len(n), 0.001, 0.06, 0.5)
    toe = ffilt(noise(0.1), 'band', 3200 * p, 4) * env(int(SR * 0.1), 0.001, 0.03, 0.45)
    save(f'step_{i}', mix(heel, at(toe, 0.065, 0.25)))
for i in range(3):
    n = noise(0.2)
    save(f'clack_{i}', ffilt(n, 'band', R.uniform(1500, 2100), 5) * env(len(n), 0.001, 0.05) + osc('sine', R.uniform(500, 750), 0.2) * env(len(n), 0.001, 0.07, 0.35))
f = np.concatenate([np.linspace(R.uniform(55, 115), R.uniform(55, 115), int(SR * 0.07)) for _ in range(9)])
save('creak', ffilt(osc('saw', f, 0.63), 'band', 1100, 9) * env(int(SR * 0.63), 0.05, 0.5))
d = 2.6
st = sum(osc('saw', sweep(fr, fr * 0.97, d), d) for fr in (196, 207.7, 293.7, 415.3, 554.4, 587.3))
lpcut = ffilt(st, 'lp', 1800) * env(int(SR * d), 0.01, 2.4, 0.5) + ffilt(noise(d), 'hp', 3000) * env(int(SR * d), 0.01, 1.1, 0.35)
lpcut += osc('sine', sweep(70, 30, d), d) * env(int(SR * d), 0.005, 1.4, 0.8)
save('stinger', reverb(lpcut, 2.0, 0.3))
# the death screech: detuned shrieks with fast vibrato, distorted, plus clang, grind and hit; hard stop at 1.45 s
d = 1.45; tt = t_(d); vib = np.sin(2 * np.pi * np.linspace(24, 38, len(tt)) * tt) * 110
scr = np.zeros(len(tt))
for fr, kind in ((1180, 'saw'), (1243, 'saw'), (1760, 'square'), (905, 'saw'), (2390, 'square'), (597, 'saw'), (3150, 'saw')):
    base = np.concatenate([np.geomspace(fr * 1.45, fr, int(SR * 0.12)), np.geomspace(fr, fr * 0.78, len(tt) - int(SR * 0.12))])
    scr += osc(kind, np.maximum(base + vib, 40), d) * 0.16
scr = np.tanh(scr * 14) * 0.5 + ffilt(noise(d), 'hp', 700) * np.geomspace(1.1, 0.35, len(tt))
for fr in (431, 1187, 2093, 3301, 4710, 6170): scr += osc('sine', fr, d) * env(len(tt), 0.001, 0.7, 0.22)
grind = osc('square', 41, d) * (0.5 + 0.5 * osc('square', 17, d)) * 0.35
scr += ffilt(grind, 'lp', 1100) + osc('sine', sweep(140, 28, d), d) * env(len(tt), 0.001, 0.6, 1.6)
scr[-int(SR * 0.03):] *= np.linspace(1, 0, int(SR * 0.03))
save('jumpscare', scr, 0.98)
save('static_blast', ffilt(noise(0.75), 'band', 3200, 0.4) * np.geomspace(1, 0.0002, int(SR * 0.75)))
save('static_loop', loopify(ffilt(noise(3), 'band', 2200, 0.5)), 0.4)
ch = np.zeros(int(SR * 3.2))
for fr, o in ((659.3, 0), (523.3, 0.55), (392, 1.1)):
    ch += at(osc('sine', fr, 1.7) * env(int(SR * 1.7), 0.01, 1.6, 0.4) + osc('tri', fr * 2, 1.7) * env(int(SR * 1.7), 0.01, 0.8, 0.1), o, 3.2)
save('chime', reverb(ch, 1.8, 0.35))
save('buzz', (osc('square', 118, 0.7) * 0.5 + ffilt(noise(0.7), 'band', 4000, 3)) * env(int(SR * 0.7), 0.005, 0.7))
d = 2.4
pdn = ffilt(osc('saw', sweep(120, 18, d), d), 'lp', 900) * env(int(SR * d), 0.01, 2.3, 0.6)
pdn += osc('sine', sweep(70, 28, 1.5), d) * env(int(SR * d), 0.002, 1.4) + ffilt(noise(d), 'lp', 900) * env(int(SR * d), 0.002, 0.5, 0.5)
save('power_down', pdn)
d = 1.8
save('power_up', osc('sine', sweep(80, 35, d), d) * env(int(SR * d), 0.003, 1.6) + ffilt(noise(d), 'lp', 600) * env(int(SR * d), 0.003, 1.2, 0.5))
d = 3.4; sh = ffilt(noise(d), 'lp', 380) * env(int(SR * d), 0.3, 3.2, 0.45)
for i in range(26): sh += at(ffilt(noise(0.08), 'band', R.uniform(900, 1300), 4) * env(int(SR * 0.08), 0.001, 0.05, 0.12), i * 0.12, d)
save('shutter', sh)
d = 1.2; save('thunk', reverb(osc('sine', sweep(95, 45, d), d) * env(int(SR * d), 0.002, 0.3) + ffilt(noise(d), 'band', 1800, 3) * env(int(SR * d), 0.002, 0.06, 0.6), 2.4, 0.45))
d = 0.8; pp = ffilt(noise(d), 'hp', 2500) * env(int(SR * d), 0.001, 0.25, 0.6)
for _ in range(9): pp += at(osc('sine', R.uniform(2500, 6500), 0.16) * env(int(SR * 0.16), 0.001, 0.15, 0.05), R.uniform(0.04, 0.44), d)
save('pop', pp)
d = 2.0; cp = np.zeros(int(SR * d))
for i in range(34): cp += at(osc('square', R.choice([262, 311, 392, 466, 523, 622, 784, 932]) * (0.5 if R.random() < 0.2 else 1), 0.055) * 0.07, i * 0.055, d)
save('chip', cp + ffilt(noise(d), 'band', 5000, 1) * 0.04)
d = 0.6; save('heartbeat', at(osc('sine', sweep(62, 40, 0.16), 0.16) * env(int(SR * 0.16), 0.01, 0.14), 0, d) + at(osc('sine', sweep(58, 38, 0.18), 0.18) * env(int(SR * 0.18), 0.01, 0.16, 0.7), 0.2, d))
d = 0.6; save('pickup', at(osc('tri', 880, 0.3) * env(int(SR * 0.3), 0.005, 0.25), 0, d) + at(osc('tri', 1320, 0.4) * env(int(SR * 0.4), 0.005, 0.35, 0.75), 0.08, d))
save('paper', ffilt(noise(0.3), 'hp', 2800) * env(int(SR * 0.3), 0.02, 0.25))
save('ratchet', mix(ffilt(noise(0.05), 'band', 2800, 6) * env(int(SR * 0.05), 0.001, 0.025), osc('square', 900, 0.05) * env(int(SR * 0.05), 0.001, 0.02, 0.12)))
save('gasp', mix(ffilt(noise(0.95), 'band', 1400, 1.2) * env(int(SR * 0.95), 0.12, 0.8), at(ffilt(noise(0.7), 'band', 900, 1) * env(int(SR * 0.7), 0.05, 0.6, 0.5), 0.85, 1.6)))
save('breath', mix(ffilt(noise(0.9), 'band', 1100, 0.8) * env(int(SR * 0.9), 0.25, 0.6), at(ffilt(noise(0.9), 'band', 800, 0.8) * env(int(SR * 0.9), 0.2, 0.7, 0.8), 0.8, 1.8)))
save('cloth', ffilt(noise(0.4), 'hp', 1800) * env(int(SR * 0.4), 0.05, 0.35))
d = 2.05; am = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 20 * t_(d)))
save('phone_ring', (osc('sine', 440, d) + osc('sine', 480, d)) * am * np.clip(np.minimum(t_(d) / 0.02, (d - t_(d)) / 0.1), 0, 1))
save('drip', mix(osc('sine', sweep(1500, 650, 0.1), 0.1) * env(int(SR * 0.1), 0.002, 0.09), at(osc('sine', sweep(900, 500, 0.08), 0.08) * env(int(SR * 0.08), 0.002, 0.07, 0.4), 0.11, 0.3)))
save('tape_stop', osc('saw', sweep(320, 35, 0.8), 0.8) * env(int(SR * 0.8), 0.01, 0.7))
save('click', osc('square', 1800, 0.04) * env(int(SR * 0.04), 0.001, 0.03))
save('whisper_air', ffilt(noise(1.5), 'band', 3500, 1.5) * env(int(SR * 1.5), 0.3, 1.2))
print('audio ->', os.path.abspath(OUT), len(os.listdir(OUT)), 'files')
