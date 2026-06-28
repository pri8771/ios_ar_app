#!/usr/bin/env python3
"""Generate a 1024x1024 opaque App Store icon for Shadow Lens.

No third-party imaging libraries are available, so this writes a PNG directly
(zlib + struct). The motif: a warm sky with a sun, a pole, and the pole's cast
shadow on the ground — a literal picture of what the app does.

    python3 scripts/generate_icon.py
"""
import os, struct, zlib, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ShadowLens", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
N = 1024

def lerp(a, b, t):
    return a + (b - a) * t

def mix(c1, c2, t):
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))

# Palette
SKY_TOP = (255, 198, 88)
SKY_HORIZON = (255, 142, 66)
GROUND_NEAR = (54, 64, 92)
GROUND_FAR = (74, 86, 120)
SUN_CORE = (255, 247, 210)
SUN_EDGE = (255, 210, 120)
POLE = (34, 38, 54)
SHADOW = (28, 30, 44)

horizon_y = int(N * 0.66)
sun_cx, sun_cy, sun_r = int(N * 0.33), int(N * 0.34), int(N * 0.15)

# Pole geometry
pole_cx = int(N * 0.62)
pole_w = int(N * 0.028)
pole_top = int(N * 0.34)
pole_base = horizon_y

# Shadow: triangle-ish polygon from pole base stretching to lower-right.
shadow_len = int(N * 0.30)

def point_in_shadow(x, y):
    if y < horizon_y:
        return 0.0
    # Shadow lies on the ground, fanning from the pole base toward lower-right.
    # Parameterize by depth below horizon.
    depth = (y - horizon_y) / max(1, (N - horizon_y))
    # Center of shadow shifts right with depth; width grows slightly.
    cx = pole_cx + depth * shadow_len
    half = pole_w * 0.6 + depth * pole_w * 1.4
    d = abs(x - cx)
    if d > half:
        return 0.0
    # Fade near the far tip and soft edges.
    edge = 1.0 - (d / half)
    fade = 1.0 - depth * 0.65
    return max(0.0, min(1.0, edge * fade))

rows = bytearray()
for y in range(N):
    rows.append(0)  # PNG filter type 0 for this scanline
    if y < horizon_y:
        t = y / horizon_y
        base = mix(SKY_TOP, SKY_HORIZON, t)
    else:
        t = (y - horizon_y) / max(1, (N - horizon_y))
        base = mix(GROUND_FAR, GROUND_NEAR, t)
    for x in range(N):
        r, g, b = base

        # Sun (with soft glow), only above the horizon.
        if y < horizon_y:
            dx, dy = x - sun_cx, y - sun_cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < sun_r:
                tt = dist / sun_r
                sc = mix(SUN_CORE, SUN_EDGE, tt)
                r, g, b = sc
            elif dist < sun_r * 1.6:
                glow = 1.0 - (dist - sun_r) / (sun_r * 0.6)
                glow = max(0.0, glow) * 0.5
                r = lerp(r, SUN_EDGE[0], glow)
                g = lerp(g, SUN_EDGE[1], glow)
                b = lerp(b, SUN_EDGE[2], glow)

        # Cast shadow on the ground.
        if y >= horizon_y:
            s = point_in_shadow(x, y)
            if s > 0:
                r = lerp(r, SHADOW[0], s * 0.7)
                g = lerp(g, SHADOW[1], s * 0.7)
                b = lerp(b, SHADOW[2], s * 0.7)

        # Pole (rounded vertical bar) drawn on top.
        if pole_top <= y <= pole_base and abs(x - pole_cx) <= pole_w:
            edge = 1.0 - abs(x - pole_cx) / pole_w
            shade = 0.75 + 0.25 * edge
            r, g, b = POLE[0] * shade, POLE[1] * shade, POLE[2] * shade
        # Rounded cap at top of pole.
        capdx, capdy = x - pole_cx, y - pole_top
        if capdx * capdx + capdy * capdy <= pole_w * pole_w and y < pole_top:
            r, g, b = POLE

        rows.append(int(max(0, min(255, r))))
        rows.append(int(max(0, min(255, g))))
        rows.append(int(max(0, min(255, b))))

def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))  # 8-bit RGB
png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
png += chunk(b"IEND", b"")

with open(OUT, "wb") as f:
    f.write(png)
print(f"Wrote {OUT} ({len(png)} bytes, {N}x{N}, opaque RGB)")
