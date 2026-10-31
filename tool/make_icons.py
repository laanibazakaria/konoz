"""Génère les icônes de l'application (PWA, iPhone, favicon) : la mascotte sur fond de ciel.

Usage : python3 tool/make_icons.py   (depuis la racine du dépôt)
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "app" / "web"
S = 1024  # dessin en haute résolution, puis réduction


def sky(size):
    img = Image.new("RGB", (size, size))
    top, bottom = (0x55, 0xD8, 0xF2), (0x9B, 0xE1, 0x5D)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img.convert("RGBA")


def mascot(img, scale):
    """Dessine la mascotte centrée ; scale = part de la largeur occupée par le corps."""
    d = ImageDraw.Draw(img)
    w = S * scale
    cx, cy = S / 2, S / 2 + w * 0.08
    x0, y0, x1, y1 = cx - w / 2, cy - w * 0.5, cx + w / 2, cy + w * 0.55
    # plumes bleues
    for dx, ang in ((-0.22, -18), (0, 0), (0.22, 18)):
        f = Image.new("RGBA", (S, S))
        fd = ImageDraw.Draw(f)
        fw, fh = w * 0.11, w * 0.38
        fx = cx + dx * w
        fd.rounded_rectangle([fx - fw / 2, y0 - fh * 0.75, fx + fw / 2, y0 + fh * 0.25], radius=fw / 2, fill="#5CC8F0")
        img.alpha_composite(f.rotate(-ang, center=(fx, y0)))
    d.rounded_rectangle([x0, y0, x1, y1], radius=w * 0.2, fill="#A62BA0")
    # yeux
    for ex in (cx - w * 0.17, cx + w * 0.17):
        ey, r = y0 + w * 0.36, w * 0.14
        d.ellipse([ex - r, ey - r, ex + r, ey + r], fill="white")
        p = r * 0.32
        d.ellipse([ex - p, ey - p, ex + p, ey + p], fill="black")
    # crocs
    for tx in (cx - w * 0.3, cx + w * 0.3):
        ty = y0 + w * 0.62
        d.rounded_rectangle([tx - w * 0.04, ty, tx + w * 0.04, ty + w * 0.1], radius=w * 0.03, fill="white")
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, mask=mask)
    return out


def save(img, name, size):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print("✓", path.relative_to(OUT.parent.parent), f"{size}×{size}")


standard = rounded(mascot(sky(S), 0.62), S * 0.22)  # icône « any » arrondie
maskable = mascot(sky(S), 0.50)  # zone sûre : le système découpe les bords
full = mascot(sky(S), 0.62)  # iPhone arrondit lui-même

for size in (192, 512):
    save(standard, f"icons/Icon-{size}.png", size)
    save(maskable, f"icons/Icon-maskable-{size}.png", size)
save(full, "icons/apple-touch-icon.png", 180)
save(standard, "favicon.png", 64)
