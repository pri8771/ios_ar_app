#!/usr/bin/env python3
"""Generate the Umbra app icon.

Concept: a sundial gnomon standing on a ground plane, casting a long shadow
(the *umbra*) away from a low golden sun, under a twilight-to-gold sky.
Literal to the app (objects cast shadows on a detected plane), distinctive,
and legible at small sizes. Rendered with 4x supersampling.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Umbra", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")
FINAL = 1024
SS = 4
S = FINAL * SS  # supersampled canvas


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_color(c1, c2, t):
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))


def multi_stop(stops, t):
    """stops: list of (pos, (r,g,b)). Returns color at t in [0,1]."""
    if t <= stops[0][0]:
        return stops[0][1]
    if t >= stops[-1][0]:
        return stops[-1][1]
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        if p0 <= t <= p1:
            lt = (t - p0) / (p1 - p0)
            return lerp_color(c0, c1, lt)
    return stops[-1][1]


# ---- Palette (twilight indigo -> warm gold) --------------------------------
SKY = [
    (0.00, (24, 20, 64)),    # deep zenith indigo  #181440
    (0.34, (43, 32, 96)),    # violet              #2B2060
    (0.60, (110, 58, 110)),  # mauve dusk          #6E3A6E
    (0.80, (214, 121, 71)),  # warm horizon        #D67947
    (1.00, (247, 184, 92)),  # gold horizon glow   #F7B85C
]
HORIZON_Y = 0.615  # fraction of height where ground begins

GROUND = [
    (0.00, (60, 44, 92)),    # near horizon (warm-lit indigo)
    (0.45, (40, 30, 70)),
    (1.00, (20, 16, 44)),    # foreground deep umbra tone
]

SUN_CORE = (255, 246, 214)
SUN_MID = (255, 206, 102)
SUN_EDGE = (250, 170, 70)


def render():
    img = Image.new("RGB", (S, S), (0, 0, 0))
    px = img.load()
    horizon_px = int(S * HORIZON_Y)

    # Sky + ground vertical gradients.
    for y in range(S):
        if y < horizon_px:
            t = y / horizon_px
            col = multi_stop(SKY, t)
        else:
            t = (y - horizon_px) / (S - horizon_px)
            col = multi_stop(GROUND, t)
        for x in range(S):
            px[x, y] = col
    base = img

    # ---- Sun glow (radial), drawn additively over the sky -----------------
    sun_cx, sun_cy = int(S * 0.69), int(S * 0.40)
    sun_r = int(S * 0.118)

    glow = Image.new("RGB", (S, S), (0, 0, 0))
    gpx = glow.load()
    glow_r = int(S * 0.46)
    for y in range(max(0, sun_cy - glow_r), min(S, sun_cy + glow_r)):
        for x in range(max(0, sun_cx - glow_r), min(S, sun_cx + glow_r)):
            d = math.hypot(x - sun_cx, y - sun_cy)
            if d < glow_r:
                f = (1 - d / glow_r) ** 2.2
                gpx[x, y] = (int(250 * f), int(180 * f), int(96 * f))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.02))
    base = Image.blend(base, ImageOps_screen(base, glow), 1.0)

    draw = ImageDraw.Draw(base, "RGBA")

    # ---- Gnomon geometry ---------------------------------------------------
    # A slim tapered pillar standing on the ground, just left of centre.
    gx = S * 0.40              # base centre x
    gby = S * 0.74             # base y (on the ground)
    gh = S * 0.40              # pillar height
    half_b = S * 0.028         # half width at base
    half_t = S * 0.018         # half width at top
    top_y = gby - gh

    # ---- Cast shadow: long wedge from base toward lower-left --------------
    # Sun is upper-right, so the shadow falls to the lower-left, lengthened.
    shadow_len = S * 0.345
    sdx, sdy = -0.82, 0.57     # shadow direction (down-left), normalized-ish
    n = math.hypot(sdx, sdy)
    sdx, sdy = sdx / n, sdy / n
    tip_x = gx + sdx * shadow_len
    tip_y = gby + sdy * shadow_len
    # perpendicular for width
    pxn, pyn = -sdy, sdx
    base_half = half_b * 1.15
    tip_half = half_b * 2.1
    shadow_poly = [
        (gx - pxn * base_half, gby - pyn * base_half),
        (gx + pxn * base_half, gby + pyn * base_half),
        (tip_x + pxn * tip_half, tip_y + pyn * tip_half),
        (tip_x - pxn * tip_half, tip_y - pyn * tip_half),
    ]
    shadow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_layer, "RGBA")
    sdraw.polygon(shadow_poly, fill=(8, 6, 24, 200))
    # soft tip: ellipse at the tip
    sdraw.ellipse([tip_x - tip_half * 1.4, tip_y - tip_half * 0.7,
                   tip_x + tip_half * 1.4, tip_y + tip_half * 0.7],
                  fill=(8, 6, 24, 150))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(S * 0.012))
    base = Image.alpha_composite(base.convert("RGBA"), shadow_layer).convert("RGB")
    draw = ImageDraw.Draw(base, "RGBA")

    # ---- Sun disc (drawn on top of glow, behind nothing) ------------------
    # Soft outer ring then a warm radial core.
    sun_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sdr = ImageDraw.Draw(sun_layer)
    for i in range(sun_r, 0, -1):
        t = i / sun_r
        col = lerp_color(SUN_CORE, SUN_EDGE, t ** 1.3)
        sdr.ellipse([sun_cx - i, sun_cy - i, sun_cx + i, sun_cy + i], fill=col + (255,))
    base = Image.alpha_composite(base.convert("RGBA"), sun_layer).convert("RGB")
    draw = ImageDraw.Draw(base, "RGBA")

    # ---- Gnomon pillar (lit on the sun-facing right side) -----------------
    # Body as a quad; right edge catches warm light, left edge in shade.
    body = [
        (gx - half_b, gby),
        (gx + half_b, gby),
        (gx + half_t, top_y),
        (gx - half_t, top_y),
    ]
    # Shade base then a lit sliver on the right.
    draw.polygon(body, fill=(46, 38, 74, 255))
    lit = [
        (gx + half_b * 0.15, gby),
        (gx + half_b, gby),
        (gx + half_t, top_y),
        (gx + half_t * 0.15, top_y),
    ]
    draw.polygon(lit, fill=(206, 150, 96, 255))
    # rounded cap
    draw.ellipse([gx - half_t, top_y - half_t * 0.9, gx + half_t, top_y + half_t * 0.9],
                 fill=(150, 110, 80, 255))
    draw.ellipse([gx - half_t * 0.55, top_y - half_t * 0.9, gx + half_t, top_y + half_t * 0.2],
                 fill=(224, 168, 104, 255))

    # ---- Subtle ground highlight line at horizon --------------------------
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(hl)
    hy = int(S * HORIZON_Y)
    hdraw.rectangle([0, hy - S * 0.004, S, hy + S * 0.004], fill=(247, 184, 92, 70))
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.01))
    base = Image.alpha_composite(base.convert("RGBA"), hl).convert("RGB")

    # ---- Gentle vignette for focus and a premium finish -------------------
    vig = Image.new("L", (S, S), 0)
    vdraw = ImageDraw.Draw(vig)
    margin = int(S * 0.02)
    vdraw.ellipse([-S * 0.18, -S * 0.18, S * 1.18, S * 1.18], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(S * 0.08))
    dark = Image.new("RGB", (S, S), (6, 5, 18))
    base = Image.composite(base, dark, vig)

    # Downsample with high-quality filter.
    final = base.resize((FINAL, FINAL), Image.LANCZOS)
    final.save(OUT)
    print("wrote", OUT)


def ImageOps_screen(a, b):
    """Screen blend a and b (both RGB)."""
    import PIL.ImageChops as C
    return C.screen(a, b)


if __name__ == "__main__":
    render()
