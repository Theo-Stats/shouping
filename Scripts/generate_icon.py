#!/usr/bin/env python3
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
ICONSET = RESOURCES / "AppIcon.iconset"


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


size = 1024
image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
pixels = image.load()

for y in range(size):
    t = y / (size - 1)
    color = (
        lerp(10, 18, t),
        lerp(25, 34, t),
        lerp(42, 54, t),
        255,
    )
    for x in range(size):
        pixels[x, y] = color

mask = Image.new("L", (size, size), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle((72, 72, 952, 952), radius=224, fill=255)
image.putalpha(mask)

glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
glow_draw.ellipse((520, -180, 1120, 420), fill=(35, 221, 213, 60))
glow_draw.ellipse((-320, 580, 340, 1240), fill=(65, 117, 255, 45))
image = Image.alpha_composite(image, glow)
image.putalpha(mask)

draw = ImageDraw.Draw(image)
shield = [(512, 190), (754, 284), (724, 574), (512, 838), (300, 574), (270, 284)]
draw.polygon(shield, fill=(59, 224, 214, 255))

inner = [(512, 252), (687, 320), (665, 550), (512, 750), (359, 550), (337, 320)]
draw.polygon(inner, fill=(16, 45, 62, 235))

draw.line([(408, 493), (484, 570), (635, 404)], fill=(114, 250, 232, 255), width=48, joint="curve")

RESOURCES.mkdir(exist_ok=True)
image.save(RESOURCES / "AppIcon-1024.png")

if ICONSET.exists():
    for child in ICONSET.iterdir():
        child.unlink()
else:
    ICONSET.mkdir()

for base in (16, 32, 128, 256, 512):
    resized = image.resize((base, base), Image.Resampling.LANCZOS)
    resized.save(ICONSET / f"icon_{base}x{base}.png")
    doubled = image.resize((base * 2, base * 2), Image.Resampling.LANCZOS)
    doubled.save(ICONSET / f"icon_{base}x{base}@2x.png")

print(RESOURCES / "AppIcon-1024.png")
