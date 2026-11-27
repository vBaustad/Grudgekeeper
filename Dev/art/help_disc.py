"""Draw Media/help_disc.tga: a dark disc in a thin gold ring (demo A's "?" button), 64x64, 32-bit TGA.

Also writes preview.png: the disc at in-game size (26 px) and 4x, with a soft halo and a "?", beside the demo.
"""
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out_tga, preview, demo = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None
S, SS = 64, 8                     # size, supersampling
N = S * SS
c = (N - 1) / 2
R_OUT = 30.5 * SS                 # ring outer edge
GOLD_OUT = 24.5 * SS              # gold ring, outer and inner edge (the rim is outside it)
GOLD_IN = 21.5 * SS
img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
px = img.load()


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


for y in range(N):
    for x in range(N):
        dx, dy = x - c, y - c
        r = math.hypot(dx, dy)
        if r > R_OUT:
            continue
        # demo A: a thick near-black rim, a thin soft gold ring inside it, a flat dark-brown face
        if r >= GOLD_OUT:
            col = (22, 19, 15)
        elif r >= GOLD_IN:
            m = (GOLD_OUT + GOLD_IN) / 2
            t = 1 - abs(r - m) / ((GOLD_OUT - GOLD_IN) / 2)   # brightest mid-ring, soft edges
            col = lerp((60, 48, 30), (214, 178, 100), t)
        else:
            t = min(1, r / GOLD_IN)
            col = lerp((44, 37, 28), (36, 30, 23), t)
        px[x, y] = col + (255,)

disc = img.resize((S, S), Image.LANCZOS)
disc.save(out_tga)                 # PIL writes 32-bit uncompressed TGA for RGBA

# preview: halo + disc + "?" at in-game size (scaled 1x and 4x), on the window's dark parchment
def button(size):
    W = size * 3
    bg = Image.new("RGBA", (W, W), (30, 22, 14, 255))
    halo = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hr = size * 0.95
    hd.ellipse([W / 2 - hr, W / 2 - hr, W / 2 + hr, W / 2 + hr], fill=(255, 204, 90, 110))
    halo = halo.filter(ImageFilter.GaussianBlur(size * 0.35))
    bg = Image.alpha_composite(bg, halo)
    d = disc.resize((size, size), Image.LANCZOS)
    bg.alpha_composite(d, ((W - size) // 2, (W - size) // 2))
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", int(size * 0.42))
    except OSError:
        f = ImageFont.load_default()
    dr = ImageDraw.Draw(bg)
    dr.text((W / 2, W / 2), "?", fill=(214, 178, 100, 255), font=f, anchor="mm")
    return bg

small, big = button(26), button(104)
parts = [small.resize((small.width * 4, small.height * 4), Image.NEAREST), big]
if demo:
    dm = Image.open(demo).convert("RGBA")
    parts.append(dm.resize((dm.width * 312 // dm.height, 312), Image.LANCZOS))
H = max(p.height for p in parts)
sheet = Image.new("RGBA", (sum(p.width for p in parts) + 20 * len(parts), H), (12, 12, 12, 255))
x = 0
for p in parts:
    sheet.alpha_composite(p, (x, 0))
    x += p.width + 20
sheet.save(preview)
