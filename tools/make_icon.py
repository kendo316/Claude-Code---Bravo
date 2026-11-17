"""Draws the app icon: a gold card with a keyhole on top of two paper cards."""
from PIL import Image, ImageDraw
import pathlib
S = 1024 * 4                                  # draw big, shrink for smooth edges
NAVY, GOLD, PAPER, DEEP = (19, 32, 59), (246, 168, 33), (242, 237, 226), (12, 21, 40)

def card(color, angle, dx, dy, shadow=True):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h, r = int(S * .40), int(S * .56), int(S * .055)
    x0, y0 = (S - w) // 2, (S - h) // 2
    if shadow:
        d.rounded_rectangle((x0 + S * .012, y0 + S * .02, x0 + w + S * .012, y0 + h + S * .02), r, fill=(0, 0, 0, 70))
    d.rounded_rectangle((x0, y0, x0 + w, y0 + h), r, fill=color)
    layer = layer.rotate(angle, resample=Image.BICUBIC, center=(S // 2, S // 2))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(layer, (int(dx * S), int(dy * S)), layer)
    return out

img = Image.new("RGBA", (S, S), NAVY + (255,))
ImageDraw.Draw(img).ellipse((-S * .2, -S * .35, S * 1.2, S * .75), fill=(26, 43, 78, 255))   # soft top light
for color, angle, dx, dy in [((214, 208, 194), 13, -.085, .02), (PAPER, -9, .08, .015), (GOLD, 0, 0, -.01)]:
    img = Image.alpha_composite(img, card(color, angle, dx, dy))
d = ImageDraw.Draw(img)
cx, cy, r = S // 2, int(S * .455), int(S * .062)                                           # keyhole
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=DEEP)
d.polygon([(cx - r * .48, cy + r * .5), (cx + r * .48, cy + r * .5), (cx + r * .95, cy + r * 2.7), (cx - r * .95, cy + r * 2.7)], fill=DEEP)
out = pathlib.Path(__file__).resolve().parent.parent / "FindersKeepers/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out)
print("icon written")
