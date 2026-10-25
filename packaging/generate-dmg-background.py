#!/usr/bin/env python3
"""Build packaging/dmg-background.png for the macOS DMG window."""
from pathlib import Path

from PIL import Image, ImageDraw

W, H = 660, 400
OUT = Path(__file__).resolve().parent / "dmg-background.png"

img = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(img)
for y in range(H):
    t = y / max(H - 1, 1)
    r = int(0xf4 + (0xe4 - 0xf4) * t)
    g = int(0xf2 + (0xe0 - 0xf2) * t)
    b = int(0xff + (0xf8 - 0xff) * t)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

accent = (91, 79, 232)
light = (232, 228, 255)
# Soft arrow behind icons (left → right)
x0, y0, x1, y1 = 230, 186, 400, 214
head = [(430, 200), (395, 168), (395, 232)]
draw.rounded_rectangle([x0, y0, x1, y1], radius=8, fill=light)
draw.polygon(head, fill=accent)
draw.rounded_rectangle([x0 + 4, y0 + 4, x1 - 10, y1 - 4], radius=6, fill=accent)

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, optimize=True)
print("Wrote", OUT)
