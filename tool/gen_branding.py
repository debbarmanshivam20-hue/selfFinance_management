"""Generates FinVault's original brand artwork (icon, adaptive layers, splash).

Everything here is drawn from scratch with primitive shapes - no third-party
logo, trademark or downloaded artwork is involved. Run with:
    python3 tool/gen_branding.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")
FONT = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "Inter.ttf")
os.makedirs(OUT, exist_ok=True)

SS = 4  # supersampling factor for smooth anti-aliased edges

EMERALD_A = (16, 185, 129)   # #10B981
EMERALD_B = (4, 120, 87)     # #047857
INK = (11, 15, 20)           # #0B0F14
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(size, c1, c2):
    """Diagonal linear gradient."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(c1, c2, t)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def draw_mark(canvas_size, glyph_span, color=WHITE, bar_alpha=110):
    """The FinVault mark: three ascending columns with a rising trend arrow."""
    S = canvas_size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    span = glyph_span * SS
    ox = (S - span) / 2.0
    oy = (S - span) / 2.0

    def P(nx, ny):
        return (ox + nx * span, oy + ny * span)

    bar_w = 0.20
    heights = [0.46, 0.66, 0.88]
    for i, h in enumerate(heights):
        x0 = i * 0.40
        left, top = P(x0, 1.0 - h)
        right, bottom = P(x0 + bar_w, 1.0)
        d.rounded_rectangle([left, top, right, bottom],
                            radius=bar_w * span * 0.42,
                            fill=color + (bar_alpha,))

    pts = [P(0.10, 0.72), P(0.42, 0.46), P(0.62, 0.585), P(0.90, 0.20)]
    d.line(pts, fill=color + (255,), width=int(0.105 * span), joint="curve")
    r = 0.0525 * span
    for p in pts[:-1]:
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color + (255,))

    # arrow head, rotated to follow the direction of the final segment
    import math
    (x1, y1), (x2, y2) = pts[-2], pts[-1]
    ln = math.hypot(x2 - x1, y2 - y1)
    ux, uy = (x2 - x1) / ln, (y2 - y1) / ln
    px_, py_ = -uy, ux
    tip = (x2 + ux * 0.085 * span, y2 + uy * 0.085 * span)
    L, Wd = 0.20 * span, 0.135 * span
    bx, by = tip[0] - ux * L, tip[1] - uy * L
    d.polygon([tip,
               (bx + px_ * Wd, by + py_ * Wd),
               (bx - px_ * Wd, by - py_ * Wd)], fill=color + (255,))

    return img.resize((canvas_size, canvas_size), Image.LANCZOS)


def font_at(size, weight=700):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([32, weight])
    except Exception:
        pass
    return f


# 1. Legacy launcher icon --------------------------------------------------
N = 1024
bg = gradient(N, EMERALD_A, EMERALD_B)
icon = Image.new("RGBA", (N, N), (0, 0, 0, 0))
icon.paste(bg, (0, 0), rounded_mask(N, int(N * 0.225)))
icon.alpha_composite(draw_mark(N, int(N * 0.56)))
icon.save(os.path.join(OUT, "app_icon.png"))

# 2. Adaptive icon layers ---------------------------------------------------
gradient(N, EMERALD_A, EMERALD_B).save(os.path.join(OUT, "app_icon_background.png"))
draw_mark(N, int(N * 0.50)).save(os.path.join(OUT, "app_icon_foreground.png"))
draw_mark(N, int(N * 0.50), color=WHITE, bar_alpha=140).save(
    os.path.join(OUT, "app_icon_monochrome.png"))

# 3. Splash artwork ---------------------------------------------------------
def splash(word_color, path):
    W, H = 1024, 1024
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    tile = 460
    t = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    t.paste(gradient(tile, EMERALD_A, EMERALD_B), (0, 0), rounded_mask(tile, int(tile * 0.225)))
    t.alpha_composite(draw_mark(tile, int(tile * 0.56)))
    img.alpha_composite(t, ((W - tile) // 2, 210))

    d = ImageDraw.Draw(img)
    f = font_at(132, 700)
    text = "FinVault"
    bbox = d.textbbox((0, 0), text, font=f)
    d.text(((W - (bbox[2] - bbox[0])) // 2 - bbox[0], 740), text, font=f, fill=word_color)

    f2 = font_at(46, 500)
    sub = "Personal Finance"
    b2 = d.textbbox((0, 0), sub, font=f2)
    d.text(((W - (b2[2] - b2[0])) // 2 - b2[0], 905), sub, font=f2,
           fill=word_color[:3] + (150,))
    img.save(path)


splash(INK + (255,), os.path.join(OUT, "splash_light.png"))
splash((233, 240, 247, 255), os.path.join(OUT, "splash_dark.png"))

A12 = 1152
a12 = Image.new("RGBA", (A12, A12), (0, 0, 0, 0))
tile = 700
t = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
t.paste(gradient(tile, EMERALD_A, EMERALD_B), (0, 0), rounded_mask(tile, int(tile * 0.5)))
t.alpha_composite(draw_mark(tile, int(tile * 0.52)))
a12.alpha_composite(t, ((A12 - tile) // 2, (A12 - tile) // 2))
a12.save(os.path.join(OUT, "splash_android12.png"))

print("branding written to", os.path.normpath(OUT))
