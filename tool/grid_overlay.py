#!/usr/bin/env python3
"""Draw a percentage grid over a body sprite so axle centres can be read off.

Lines every 5% of the sprite's own width/height, labelled 0-100 along the
top and left edges. Read an axle as (x%, y%) and convert with:
    anchor.x = (x% / 100 - 0.5) * spriteSize.x
    anchor.y = (y% / 100 - 0.5) * spriteSize.y
"""
import sys
from PIL import Image, ImageDraw

OUT_W = 1100


def annotate(path, out):
    im = Image.open(path).convert("RGBA")
    scale = OUT_W / im.width
    im = im.resize((OUT_W, int(im.height * scale)), Image.LANCZOS)
    card = Image.new("RGBA", im.size, (18, 18, 24, 255))
    card.alpha_composite(im)
    d = ImageDraw.Draw(card)
    w, h = card.size
    for p in range(0, 101, 5):
        x = w * p / 100
        y = h * p / 100
        major = p % 25 == 0
        col = (255, 90, 90, 255) if major else (110, 190, 255, 120)
        d.line([(x, 0), (x, h)], fill=col, width=2 if major else 1)
        d.line([(0, y), (w, y)], fill=col, width=2 if major else 1)
        if p % 10 == 0:
            d.text((x + 3, 2), str(p), fill=(255, 255, 120, 255))
            d.text((3, y + 2), str(p), fill=(255, 255, 120, 255))
    card.convert("RGB").save(out)


if __name__ == "__main__":
    for slug in sys.argv[2:]:
        annotate(f"assets/images/{slug}_body.png", f"{sys.argv[1]}/{slug}.png")
        print(slug)
