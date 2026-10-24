"""Generate the game's textures as PNG files (godot/textures). Re-run to regenerate; edit the PNGs freely."""
import os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'textures')
os.makedirs(OUT, exist_ok=True)
rng = random.Random(1989)

def save(img, name):
    img.save(os.path.join(OUT, name + '.png'))

def grime(img, n, alpha, color=(0, 0, 0)):
    w, h = img.size
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for _ in range(n):
        r = rng.uniform(10, w * 0.25)
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        blob = Image.new('L', (w, h), 0)
        ImageDraw.Draw(blob).ellipse([x - r, y - r, x + r, y + r], fill=int(255 * alpha * rng.random()))
        blob = blob.filter(ImageFilter.GaussianBlur(r * 0.5))
        layer = Image.composite(Image.new('RGBA', (w, h), color + (255,)), layer, blob)
    return Image.alpha_composite(img.convert('RGBA'), layer)

def speckle(img, n, colors, size=(1, 3)):
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        s = rng.uniform(*size)
        d.rectangle([x, y, x + s, y + s], fill=rng.choice(colors))
    return img

def font(size, bold=True):
    for f in (['impact.ttf', 'arialbd.ttf'] if bold else ['arial.ttf']):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()

# terrazzo floor tiles: 4x4 tiles per 2m
img = Image.new('RGBA', (512, 512))
d = ImageDraw.Draw(img)
s = 128
for i in range(4):
    for j in range(4):
        b = int(150 + rng.random() * 12) if (i + j) % 2 == 0 else int(196 + rng.random() * 12)
        d.rectangle([i * s, j * s, i * s + s, j * s + s], fill=(b, b - 6, b - 16, 255))
speckle(img, 9000, [(60, 55, 50, 140), (240, 235, 225, 140), (140, 90, 70, 120)])
img = grime(img, 14, 0.22)
d = ImageDraw.Draw(img)
for i in range(5):
    d.line([(i * s, 0), (i * s, 512)], fill=(40, 34, 28, 230), width=3)
    d.line([(0, i * s), (512, i * s)], fill=(40, 34, 28, 230), width=3)
save(img, 'floor')

# floor roughness (grout rough, tiles glossy, dirty patches rougher)
img = Image.new('RGBA', (256, 256), (74, 74, 74, 255))
img = grime(img, 18, 0.9, (200, 200, 200))
d = ImageDraw.Draw(img)
for i in range(5):
    d.line([(i * 64, 0), (i * 64, 256)], fill=(220, 220, 220, 255), width=3)
    d.line([(0, i * 64), (256, i * 64)], fill=(220, 220, 220, 255), width=3)
save(img.convert('L'), 'floor_rough')

# wall panel: 2m wide x 4m tall
img = Image.new('RGBA', (256, 512), (180, 170, 152, 255))
speckle(img, 1500, [(0, 0, 0, 6), (255, 255, 255, 8)], (1, 2))
d = ImageDraw.Draw(img)
d.rectangle([0, 512 - 46, 256, 512], fill=(91, 74, 59, 255))
d.rectangle([0, 512 - 48, 256, 512 - 45], fill=(0, 0, 0, 90))
d.rectangle([0, int(512 * 0.62), 256, int(512 * 0.62) + 6], fill=(143, 133, 116, 255))
d.rectangle([127, 0, 129, 512 - 48], fill=(0, 0, 0, 64))
streaks = Image.new('RGBA', img.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(streaks)
for _ in range(7):
    x, ln, wd = rng.uniform(0, 256), rng.uniform(60, 280), rng.uniform(3, 11)
    for k in range(int(ln)):
        sd.line([(x, k), (x + wd, k)], fill=(70, 50, 30, int(55 * (1 - k / ln))))
img = Image.alpha_composite(img, streaks)
img = grime(img, 6, 0.18)
save(img, 'wall')

# acoustic ceiling tiles
img = Image.new('RGBA', (256, 256), (138, 135, 128, 255))
speckle(img, 3000, [(40, 40, 40, 90)], (1.5, 1.5))
d = ImageDraw.Draw(img)
for i in range(2):
    for j in range(2):
        if rng.random() < 0.3:
            r = 30 + rng.random() * 30
            d.ellipse([i * 128 + 64 - r, j * 128 + 64 - r, i * 128 + 64 + r, j * 128 + 64 + r], fill=(110, 80, 40, int(60 + rng.random() * 70)))
for i in range(3):
    d.line([(i * 128, 0), (i * 128, 256)], fill=(75, 73, 68, 255), width=4)
    d.line([(0, i * 128), (256, i * 128)], fill=(75, 73, 68, 255), width=4)
save(img, 'ceiling')

# carpet (grey, tinted per store by material color)
img = Image.new('RGBA', (256, 256), (154, 154, 154, 255))
d = ImageDraw.Draw(img)
for i in range(-8, 16):
    d.line([(i * 32, 0), (i * 32 + 256, 256)], fill=(0, 0, 0, 64), width=2)
    d.line([(i * 32 + 256, 0), (i * 32, 256)], fill=(0, 0, 0, 64), width=2)
speckle(img, 9000, [(0, 0, 0, 20), (255, 255, 255, 20)], (1, 1))
img = grime(img, 8, 0.3)
save(img, 'carpet')

# rolling shutter
img = Image.new('RGBA', (256, 256))
d = ImageDraw.Draw(img)
for y in range(0, 256, 16):
    for k in range(16):
        t = k / 15
        c = int(139 - 99 * t)
        d.line([(0, y + k), (256, y + k)], fill=(c, c + 2, c + 4, 255))
img = grime(img, 12, 0.4, (90, 45, 20))
save(img, 'shutter')

# handwritten paper
img = Image.new('RGBA', (128, 160), (233, 225, 205, 255))
d = ImageDraw.Draw(img)
for y in range(20, 150, 10):
    d.line([(12, y), (12 + rng.random() * 90 + 10, y + rng.uniform(-1, 1))], fill=(30, 30, 60, 140), width=1)
save(img, 'paper')

# book spines
img = Image.new('RGBA', (256, 64), (20, 18, 16, 255))
d = ImageDraw.Draw(img)
x = 0
while x < 256:
    bw = 5 + rng.random() * 10
    import colorsys
    r, g, b = colorsys.hls_to_rgb(rng.random(), 0.18 + rng.random() * 0.25, 0.2 + rng.random() * 0.3)
    d.rectangle([x, 64 * rng.random() * 0.25, x + bw, 64], fill=(int(r * 255), int(g * 255), int(b * 255), 255))
    x += bw + 1
save(img, 'spines')

# jack-o'-lantern face + glow mask
def pumpkin(face_col, base):
    img = Image.new('RGBA', (256, 128), base)
    d = ImageDraw.Draw(img)
    if base[0] > 0:
        for i in range(8):
            d.rectangle([i * 32, 0, i * 32 + 3, 128], fill=(90, 30, 0, 90))
    d.polygon([(42, 50), (54, 30), (66, 50)], fill=face_col)
    d.polygon([(72, 50), (84, 30), (96, 50)], fill=face_col)
    pts = [(38, 70)] + [(38 + k * 10, 92 if k % 2 else 74) for k in range(7)] + [(98, 70)]
    d.polygon(pts, fill=face_col)
    return img
save(pumpkin((26, 8, 0, 255), (210, 102, 26, 255)), 'pumpkin')
save(pumpkin((255, 176, 48, 255), (0, 0, 0, 255)), 'pumpkin_glow')

# night skylight
img = Image.new('RGBA', (512, 256))
arr = np.zeros((256, 512, 4), np.uint8)
for y in range(256):
    for x in range(0, 512, 8):
        t = (x / 512 + y / 256) / 2
        arr[y, x:x + 8] = [int(29 - 19 * t), int(39 - 25 * t), int(64 - 40 * t), 255]
img = Image.fromarray(arr, 'RGBA')
d = ImageDraw.Draw(img)
for _ in range(40):
    x, y = rng.uniform(0, 512), rng.uniform(0, 256)
    d.rectangle([x, y, x + 1.5, y + 1.5], fill=(220, 230, 255, 160))
for x in range(0, 513, 64):
    d.line([(x, 0), (x, 256)], fill=(5, 6, 10, 255), width=8)
for y in range(0, 257, 64):
    d.line([(0, y), (512, y)], fill=(5, 6, 10, 255), width=8)
d.rectangle([64 * 3 + 4, 68, 64 * 3 + 60, 124], fill=(0, 0, 0, 200))
save(img, 'skylight')

# bloody handprints on glass
img = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
def hand(cx, cy):
    col = (70, 14, 10, 160)
    d.ellipse([cx - 26, cy - 32, cx + 26, cy + 32], fill=col)
    for fx, ln in [(-20, 38), (-7, 46), (7, 44), (20, 36)]:
        d.ellipse([cx + fx - 6, cy - 34 - ln, cx + fx + 6, cy - 34], fill=col)
    d.ellipse([cx - 40, cy - 22, cx - 26, cy + 10], fill=col)
    for k in range(6):
        d.rectangle([cx - 20 + k * 7, cy + 28, cx - 17 + k * 7, cy + 28 + 20 + rng.random() * 50], fill=col)
hand(80, 150); hand(180, 120)
save(img, 'hands')

# signs on flat plates (text baked so Blender/Godot just map them)
def plate(name, lines, bg, fg, size=(1024, 256)):
    img = Image.new('RGBA', size, bg)
    d = ImageDraw.Draw(img)
    f1, f2 = font(int(size[1] * 0.33)), font(int(size[1] * 0.19), False)
    W = size[0]
    tw = d.textlength(lines[0], font=f1)
    d.text(((W - tw) / 2, size[1] * 0.18), lines[0], font=f1, fill=fg)
    if len(lines) > 1:
        tw = d.textlength(lines[1], font=f2)
        d.text(((W - tw) / 2, size[1] * 0.62), lines[1], font=f2, fill=fg)
    img = grime(img, 10, 0.35)
    save(img, name)
plate('banner_sale', ['HALLOWEEN NIGHT SALE', 'TUESDAY OCT 31 - OPEN TIL MIDNIGHT'], (27, 14, 5, 255), (255, 138, 30, 255))
plate('poster_closing', ['STORE CLOSING', 'EVERYTHING MUST GO'], (232, 224, 204, 255), (176, 20, 28, 255))
plate('poster_renovation', ['CLOSED FOR RENOVATION', 'HALVORSEN & CO. REOPENS SPRING 1990'], (232, 224, 204, 255), (42, 42, 42, 255))
plate('out_of_order', ['OUT OF ORDER'], (226, 194, 28, 255), (17, 17, 17, 255), (256, 96))

# outside the main gate: night parking lot
img = Image.new('RGBA', (256, 128))
arr = np.zeros((128, 256, 4), np.uint8)
for y in range(128):
    t = y / 127
    c = np.array([5, 7, 13]) * (1 - t) + np.array([58, 42, 20]) * t if t > 0.6 else np.array([5, 7, 13]) * (1 - t / 0.6) + np.array([28, 26, 32]) * (t / 0.6)
    arr[y, :, :3] = c.astype(np.uint8); arr[y, :, 3] = 255
img = Image.fromarray(arr, 'RGBA')
d = ImageDraw.Draw(img)
for i in range(5):
    d.ellipse([20 + i * 55 - 3, 67, 20 + i * 55 + 3, 73], fill=(255, 170, 60, 160))
save(img, 'outside')

# escalator steps
img = Image.new('RGBA', (256, 64), (74, 76, 79, 255))
d = ImageDraw.Draw(img)
for x in range(0, 256, 6):
    d.rectangle([x, 0, x + 1, 64], fill=(43, 44, 46, 255))
for x in range(0, 256, 32):
    d.rectangle([x, 0, x + 1, 64], fill=(201, 176, 40, 255))
save(img, 'escalator_steps')

print('textures ->', os.path.abspath(OUT))
