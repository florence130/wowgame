# Hand-painted full-colour textures for the city chunk materials (assets/textures/city_v7/*.png, loaded by src/world/city_mat.gd).
# Same names / layouts as the old canvas textures (tools/city_plan_v6/src/tex.js) but painted: per-stone colour, soft edge shading, brush streaks,
# painted window panes with warm interiors, no specular.   py tools/texgen/paint_city_v7.py [out_dir] [only,names]
import colorsys
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paint_building_v2 as pb  # noqa: E402
from paintlib import F32, blur, courses, edge_masks, fnoise, gnoise, hsh, smooth, voronoi  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/city_v7"
ONLY = set(sys.argv[2].split(",")) if len(sys.argv) > 2 else None
os.makedirs(OUT, exist_ok=True)


def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h / 360.0, l / 100.0, s / 100.0)
    return np.array([r, g, b], F32)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], F32)


def save(rgb, name, size=None):
    a = np.clip(np.asarray(rgb, F32), 0, 1)
    im = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGB")
    if size and size != a.shape[0]:
        im = im.resize((size, size), Image.LANCZOS)
    im.save(os.path.join(OUT, name + ".png"), optimize=True)
    print("painted", name, im.size)


def absolute(mult, base):
    """multiplier pattern (mean ~1) x base colour; keeps the base as the mean colour."""
    m = np.asarray(mult, F32)
    m = m / m.reshape(-1, 3).mean(0)
    return m * np.asarray(base, F32)[None, None, :]


def rr_mask(du, dv, R, gap):
    """Soft rounded-rect mask from per-pixel distances (px) to the block's vertical / horizontal borders."""
    cx, cy = np.maximum(R + gap - du, 0), np.maximum(R + gap - dv, 0)
    corner = np.hypot(cx, cy) - R
    edge = np.minimum(du, dv) - gap
    d = np.where((du < R + gap) & (dv < R + gap), -corner, edge)
    return smooth(-1.4, 1.4, d)


def shapes(S, draw_fn, ss=2):
    """Anti-aliased mask from a PIL draw callback (drawn at ss x resolution)."""
    im = Image.new("L", (S * ss, S * ss), 0)
    d = ImageDraw.Draw(im)
    draw_fn(d, ss)
    if ss > 1:
        im = im.resize((S, S), Image.LANCZOS)
    return np.asarray(im, F32) / 255.0


def over(img, m, col):
    c = np.asarray(col, F32)
    if c.ndim == 1:
        c = c[None, None, :]
    return img * (1 - m[..., None]) + c * m[..., None]


# ================================================================== ground
def cobble(S=1024):
    pb.S = S
    c = courses(S, 26, [18] * 26, 41, shift=0.0, wob=0.0016, wob_sigma=40, width_jitter=0.42, row_jitter=0.10)
    u, v, w, h = c["u"], c["v"], c["w"], c["h"]
    du, dv, dm = edge_masks(u, v, w, h, S, 0)
    inb = rr_mask(du, dv, S / 95.0, S / 300.0)
    a = hsh(c["rid"], c["cid"], seed=41) * 2 - 1
    t = hsh(c["rid"], c["cid"], seed=42) * 2 - 1
    val = 1 + 0.10 * a
    base = np.stack([val * (1 + 0.035 * t), val * (1 + 0.003 * t), val * (1 - 0.05 * t)], -1)
    shade = 1 + 0.16 * (0.5 - v) + 0.04 * gnoise(S, 5, seed=43)
    rim = smooth(S / 38.0, 0.0, dm)
    shade = shade - 0.20 * rim + 0.10 * smooth(S / 90.0, 0.0, v * h * S)
    col = base * shade[..., None]
    wash = 1 + 0.05 * gnoise(S, 70, seed=44)
    gap = np.array([0.55, 0.52, 0.49], F32)
    mult = col * inb[..., None] + gap * (1 - inb[..., None])
    return absolute(mult * wash[..., None], hsl(33, 9, 50))


def paving(S=1024):
    pb.S = S
    c = courses(S, 8, [4] * 8, 51, shift=0.5, wob=0.0022, wob_sigma=44, width_jitter=0.08)
    u, v, w, h = c["u"], c["v"], c["w"], c["h"]
    du, dv, dm = edge_masks(u, v, w, h, S, 0)
    inb = rr_mask(du, dv, S / 130.0, S / 190.0)
    a = hsh(c["rid"], c["cid"], seed=51) * 2 - 1
    t = hsh(c["rid"], c["cid"], seed=52) * 2 - 1
    val = 1 + 0.07 * a
    base = np.stack([val * (1 + 0.03 * t), val, val * (1 - 0.045 * t)], -1)
    shade = 1 + 0.05 * (0.5 - v) + 0.03 * gnoise(S, 30, seed=53) + 0.02 * gnoise(S, 6, seed=54)
    shade = shade + 0.07 * smooth(S / 70.0, 0.0, v * h * S) - 0.10 * smooth(S / 50.0, 0.0, dm)
    crack = smooth(0.05, 0.0, np.abs(gnoise(S, 9, seed=55))) * smooth(1.3, 2.0, gnoise(S, 80, seed=56))
    shade = shade - 0.25 * crack
    mult = base * shade[..., None] * inb[..., None] + np.array([0.58, 0.55, 0.52], F32) * (1 - inb[..., None])
    return absolute(mult, hsl(36, 10, 70))


def plaza(S=1024):
    pb.S = S
    c = courses(S, 6, [6] * 6, 61, shift=0.0, wob=0.0014, wob_sigma=50)
    u, v, w, h = c["u"], c["v"], c["w"], c["h"]
    du, dv, dm = edge_masks(u, v, w, h, S, 0)
    inb = rr_mask(du, dv, S / 100.0, S / 150.0)
    chk = ((c["rid"] + c["cid"]) % 2).astype(F32)
    a = hsh(c["rid"], c["cid"], seed=61) * 2 - 1
    light, dark = hsl(38, 14, 76), hsl(30, 11, 63)
    base = (light[None, None, :] * chk[..., None] + dark[None, None, :] * (1 - chk[..., None])) * (1 + 0.04 * a)[..., None]
    # inlaid painted border + soft bevel + faint dabs
    inner = smooth(S / 25.0 + 2, S / 25.0 - 2, np.minimum(du, dv))
    border = smooth(S / 40.0, S / 40.0 - 3, np.abs(np.minimum(du, dv) - S / 24.0))
    shade = 1 + 0.06 * (0.5 - v) + 0.035 * gnoise(S, 26, seed=62) + 0.02 * gnoise(S, 5, seed=63)
    shade = shade + 0.08 * smooth(S / 60.0, 0.0, v * h * S) - 0.12 * smooth(S / 45.0, 0.0, dm)
    crack = smooth(0.05, 0.0, np.abs(gnoise(S, 8, seed=64))) * smooth(1.4, 2.0, gnoise(S, 90, seed=65))
    shade = shade - 0.22 * crack
    img = base * shade[..., None] * inb[..., None] + np.array([0.50, 0.47, 0.44], F32) * (1 - inb[..., None])
    return img


def grass(S=512):
    pb.S = S
    n1 = gnoise(S, 22, seed=71)
    n2 = gnoise(S, 6, seed=72)
    base = np.stack([0.34 + 0.012 * n1, 0.53 + 0.03 * n1 + 0.015 * n2, 0.23 + 0.01 * n1], -1)
    hue = smooth(-0.2, 1.2, gnoise(S, 40, seed=73))
    base = base * (1 - 0.35 * hue[..., None]) + np.array([0.46, 0.60, 0.26], F32) * 0.35 * hue[..., None]
    # painted blade dabs: short vertical light / dark strokes
    st = gnoise(S, 1.2, 5.5, 0.0, seed=74)
    light = smooth(1.2, 2.4, st)
    dark = smooth(1.3, 2.6, -gnoise(S, 1.2, 5.0, 0.0, seed=75))
    base = base * (1 + 0.22 * light - 0.20 * dark)[..., None]
    return base


def ashlar_wall(S=1024):
    pb.S = S
    m = pb.ashlar(seed=81, rows=8, per_row=(4, 3, 4, 3, 4, 3, 4, 3), contrast=1.1, jitter=0.4)
    return absolute(m, hsl(35, 9, 66))


# ================================================================== roofs (absolute colours)
ROOF_BASE = {"slate": (215, 18, 36), "tile": (12, 56, 44), "copper": (165, 30, 46), "lead": (210, 8, 52), "violet": (262, 30, 40), "royal": (222, 44, 36)}


def roof(kind, S=512):
    pb.S = S
    if kind == "tile":
        m = pb.roof_tile(91)
    elif kind in ("copper",):
        m = pb.copper(92)
    elif kind == "lead":
        m = pb.shingle(6, 4, 93, lambda a, b, c: np.stack([1 + 0.05 * a, 1 + 0.05 * a, 1 + 0.06 * a], -1), scallop=0.0, overlap=0.22, shadow=0.34, edge_light=0.12)
    else:
        m = pb.roof_slate(94 + len(kind))
    base = hsl(*ROOF_BASE[kind])
    out = absolute(m, base)
    if kind == "violet":
        out = out * np.array([1.0, 0.96, 1.06], F32)
    return out


def awning(S=256):
    pb.S = S
    x = np.arange(S, dtype=F32)[None, :] / S
    wob = gnoise(S, 40, seed=101) * 0.004
    stripe = np.mod((x + wob) * 4.0, 1.0) < 0.5
    col = np.where(stripe[..., None], 0.97, 0.76).astype(F32) * np.ones((S, S, 3), F32)
    weave = 0.025 * gnoise(S, 0.8, 0.8, seed=102)
    fold = 0.05 * np.sin(2 * np.pi * (x * 4.0 + 0.5 * wob)) * 0 + 0.04 * gnoise(S, 30, 4, 0.0, seed=103)
    return col * (1 + weave + fold)[..., None]


# ================================================================== facades / shop fronts
def _glass(S, x0, y0, ww, wh, arch):
    """Window glass as a painted sky-reflecting pane: returns (mask, colour image)."""
    def drw(d, ss):
        d.rectangle([x0 * ss, y0 * ss, (x0 + ww) * ss, (y0 + wh) * ss], fill=255)
        if arch:
            d.ellipse([x0 * ss, (y0 - arch) * ss, (x0 + ww) * ss, (y0 + arch) * ss], fill=255)
    m = shapes(S, drw)
    ys = (np.arange(S, dtype=F32)[:, None] - (y0 - arch)) / (wh + arch)
    top, bot = np.array([0.36, 0.47, 0.58], F32), np.array([0.11, 0.16, 0.23], F32)
    t = np.clip(ys, 0, 1)[..., None]
    g = top * (1 - t) + bot * t
    g = np.broadcast_to(g, (S, S, 3)).copy()
    return m, g


def facade(kind, S=1024):
    pb.S = S
    k = S / 512.0
    r = np.random.default_rng(len(kind) * 31)
    walls = {"haus": "e4d7bd", "brick": "a5543d", "plaster": "f2ece2", "warehouse": "8f4632", "academy": "e9e3d6", "timber": "efe4cc"}
    wall = hexc(walls[kind])
    if kind in ("brick", "warehouse"):
        c = courses(S, 38, [14] * 38, 111, shift=0.5, wob=0.0012, wob_sigma=40)
        u, v, w, h = c["u"], c["v"], c["w"], c["h"]
        du, dv, dm = edge_masks(u, v, w, h, S, 0)
        inb = smooth(S / 520.0, S / 520.0 + 2.0, dm)
        a = hsh(c["rid"], c["cid"], seed=111) * 2 - 1
        t = hsh(c["rid"], c["cid"], seed=112) * 2 - 1
        mult = np.stack([1 + 0.08 * a + 0.04 * t, 1 + 0.28 * a - 0.05 * t, 1 + 0.32 * a - 0.05 * t], -1)
        shade = 1 + 0.12 * (0.5 - v) + 0.04 * gnoise(S, 40, 3.0, 0.0, seed=113) + 0.14 * smooth(S / 120.0, 0, v * h * S) - 0.18 * smooth(S / 90.0, 0, dm)
        brickc = wall[None, None, :] * mult * shade[..., None]
        mortar = np.array([0.80, 0.75, 0.66], F32)
        img = brickc * inb[..., None] + mortar * (1 - inb[..., None])
    elif kind == "academy":
        m = pb.ashlar(seed=121, rows=10, per_row=(4,) * 10, contrast=0.55, jitter=0.2)
        img = absolute(1 + 0.8 * (m - 1), hexc('d9d0bd'))
    else:
        m = pb.plaster(seed=131 + len(kind))
        img = absolute(1 + 0.6 * (m - 1), wall)
        if kind == "haus":
            # painted horizontal wash bands under each floor
            yy = np.arange(S, dtype=F32)[:, None] / S
            band = smooth(0.0, 0.02, np.abs(yy - 0.5)) * 0 + smooth(0.014, 0.0, np.abs(yy - 0.5))
            img = img * (1 - 0.10 * band[..., None])
    em = np.zeros((S, S, 3), F32)
    if kind == "timber":
        beam = hexc("5a3a26")
        wood = pb.wood(seed=141)
        wood = absolute(wood, beam)

        def drw(d, ss):
            for x in (0, S / 2 - 6 * k, S - 12 * k):
                d.rectangle([x * ss, 0, (x + 12 * k) * ss, S * ss], fill=255)
            for y in (0, S / 2 - 8 * k):
                d.rectangle([0, y * ss, S * ss, (y + 14 * k) * ss], fill=255)
            for kk in range(2):
                x0 = kk * S / 2
                d.line([(x0 + 12 * k) * ss, (S / 2 - 8 * k) * ss, (x0 + S / 2 - 6 * k) * ss, 14 * k * ss], fill=255, width=int(10 * k * ss))
                d.line([(x0 + 12 * k) * ss, (S - 4 * k) * ss, (x0 + S / 2 - 6 * k) * ss, (S / 2 + 6 * k) * ss], fill=255, width=int(10 * k * ss))
        bm = shapes(S, drw)
        # soft painted edge: lighter top-left rim, dark outer line
        ring = np.clip(blur(bm, 2.0 * k) * 1.8 - bm, 0, 1)
        img = over(img, ring * 0.55, hexc("2a1a10"))
        img = over(img, bm, wood * (1 + 0.1 * (blur(bm, 3 * k) - 0.5))[..., None])
    bw, fh = S / 2, S / 2
    surround = {"brick": "e8dfcc", "warehouse": "e8dfcc", "plaster": "d9cfbf"}.get(kind, "d2c3a2")
    for fy in range(2):
        for bx in range(2):
            x0, y0 = bx * bw, fy * fh
            ww = bw * (0.5 if kind == "warehouse" else 0.38)
            wh = fh * (0.5 if kind == "warehouse" else 0.6)
            wx, wy = x0 + (bw - ww) / 2, y0 + fh * 0.22
            arch = 22 * k if kind in ("brick", "warehouse") else 0
            # stone surround
            def drw_s(d, ss):
                d.rectangle([(wx - 10 * k) * ss, (wy - 12 * k) * ss, (wx + ww + 10 * k) * ss, (wy + wh + 12 * k) * ss], fill=255)
                if arch:
                    d.ellipse([(wx - 10 * k) * ss, (wy - 22 * k - arch * 0.0) * ss, (wx + ww + 10 * k) * ss, (wy + 22 * k) * ss], fill=255)
            sm = shapes(S, drw_s)
            sc = hexc(surround)
            surf = np.broadcast_to(sc, (S, S, 3)).copy() * (1 + 0.05 * gnoise(S, 12, seed=150 + fy * 2 + bx))[..., None]
            outline = np.clip(blur(sm, 1.6 * k) * 1.9 - sm, 0, 1)
            img = over(img, outline * 0.7, wall * 0.45)
            img = over(img, sm, surf)
            # soft inner shadow under the lintel
            gm, gc = _glass(S, wx, wy, ww, wh, 16 * k if arch else 0)
            img = over(img, np.clip(blur(gm, 2.5 * k) * 1.5 - gm, 0, 1) * 0.55, np.array([0.12, 0.10, 0.09], F32))
            # reflection streaks
            refl = shapes(S, lambda d, ss: d.polygon([((wx + ww * 0.12) * ss, (wy + wh * 0.04) * ss), ((wx + ww * 0.42) * ss, (wy + wh * 0.04) * ss), ((wx + ww * 0.18) * ss, (wy + wh * 0.5) * ss), ((wx + ww * 0.04) * ss, (wy + wh * 0.5) * ss)], fill=255))
            gc = gc * (1 - 0.22 * refl[..., None]) + 0.22 * refl[..., None] * np.array([0.9, 0.95, 1.0], F32)
            img = over(img, gm, gc)
            # mullions
            r.random()
            lit = (fy * 2 + bx + len(kind)) % 3 != 0
            mm = shapes(S, lambda d, ss: (d.rectangle([(wx + ww / 2 - 3 * k) * ss, wy * ss, (wx + ww / 2 + 3 * k) * ss, (wy + wh) * ss], fill=255), d.rectangle([wx * ss, (wy + wh * 0.4 - 2 * k) * ss, (wx + ww) * ss, (wy + wh * 0.4 + 3 * k) * ss], fill=255), d.rectangle([wx * ss, wy * ss, (wx + ww) * ss, (wy + 3 * k) * ss], fill=255)))
            img = over(img, mm * gm, hexc("efe9dc"))
            # sill
            sill = shapes(S, lambda d, ss: d.rectangle([(wx - 14 * k) * ss, (wy + wh + 4 * k) * ss, (wx + ww + 14 * k) * ss, (wy + wh + 12 * k) * ss], fill=255))
            sh = np.clip(blur(sill, 3 * k) * 1.3, 0, 1) * (1 - sill)
            sh = np.roll(sh, int(5 * k), axis=0)
            img = over(img, sh * 0.35, np.array([0.08, 0.06, 0.05], F32))
            img = over(img, sill, hexc("efe6d4") if kind == "brick" else hexc("cdbd9d"))
            if kind in ("haus", "academy"):
                lint = shapes(S, lambda d, ss: d.rectangle([(wx - 16 * k) * ss, (wy - 26 * k) * ss, (wx + ww + 16 * k) * ss, (wy - 14 * k) * ss], fill=255))
                img = over(img, lint, hexc("c8b791"))
                # little iron balcony
                def drw_r(d, ss):
                    for kk in range(9):
                        xx = wx - 6 * k + kk * (ww + 12 * k) / 8
                        d.line([xx * ss, (wy + wh * 0.68) * ss, xx * ss, (wy + wh) * ss], fill=255, width=int(2 * k * ss))
                    d.rectangle([(wx - 8 * k) * ss, (wy + wh * 0.66) * ss, (wx + ww + 8 * k) * ss, (wy + wh * 0.66 + 4 * k) * ss], fill=255)
                img = over(img, shapes(S, drw_r), hexc("2b2b2b"))
            if kind == "plaster":
                col = hexc("4f7a63") if r.random() < 0.5 else hexc("4c6b8a")
                for sx in (wx - 34 * k, wx + ww + 12 * k):
                    shut = shapes(S, lambda d, ss, sx=sx: d.rectangle([sx * ss, wy * ss, (sx + 22 * k) * ss, (wy + wh) * ss], fill=255))
                    lou = 0.5 + 0.5 * np.sin(np.arange(S, dtype=F32)[:, None] / (3.0 * k) * 2.0)
                    img = over(img, np.clip(blur(shut, 1.2 * k) * 1.6 - shut, 0, 1) * 0.7, col * 0.4)
                    img = over(img, shut, col[None, None, :] * (0.85 + 0.2 * lou[..., None] * np.ones((S, S, 1), F32)))
            # emission: lit pane (centre brighter), curtains darker at the sides
            if lit:
                warm = hsl(36 + r.random() * 10, 92, 56 + r.random() * 18)
                xs = (np.arange(S, dtype=F32)[None, :] - (wx + ww / 2)) / (ww / 2)
                ys = (np.arange(S, dtype=F32)[:, None] - (wy + wh * 0.5)) / (wh / 2)
                glow = np.clip(1.15 - 0.45 * np.sqrt(xs ** 2 + ys ** 2), 0.4, 1.1)
                cur = 1 - 0.35 * smooth(0.55, 1.0, np.abs(xs))
                em = over(em, gm, warm[None, None, :] * (glow * cur)[..., None])
            em = em * (1 - np.clip(mm * gm, 0, 1))[..., None]
    img = img * (1 + 0.025 * gnoise(S, 20, seed=160))[..., None]
    return np.clip(img, 0, 1), np.clip(em, 0, 1)


def shopfront(variant, S=512):
    pb.S = S
    k = S / 256.0
    r = np.random.default_rng(91 + variant)
    frame = hexc(["1f3a4d", "4a2a22", "24402f", "2a2a2a"][variant % 4])
    img = absolute(pb.plaster(seed=170 + variant), hexc("d8ccb4"))
    em = np.zeros((S, S, 3), F32)
    wood = pb.wood(seed=171 + variant)

    def box(x0, y0, x1, y1):
        return shapes(S, lambda d, ss: d.rectangle([x0 * k * ss, y0 * k * ss, x1 * k * ss, y1 * k * ss], fill=255))
    fm = box(14, 30, 242, 256)
    img = over(img, np.clip(blur(fm, 2 * k) * 1.8 - fm, 0, 1) * 0.6, np.array([0.12, 0.09, 0.07], F32))
    img = over(img, fm, absolute(wood, frame) * (1 + 0.1 * smooth(8 * k, 0, np.arange(S, dtype=F32)[None, :] - 14 * k))[..., None])
    sign = box(20, 36, 236, 62)
    gold = hexc("c9a65a")
    img = over(img, np.clip(blur(sign, 1.6 * k) * 1.8 - sign, 0, 1) * 0.6, np.array([0.15, 0.10, 0.05], F32))
    img = over(img, sign, gold[None, None, :] * (0.9 + 0.2 * np.linspace(1, 0, S, dtype=F32)[:, None, None] * 0 + 0.06 * gnoise(S, 8, seed=172)[..., None]))
    # painted lettering squiggles on the sign
    for i in range(7):
        x = (36 + i * 26 + r.random() * 6) * k
        ln = shapes(S, lambda d, ss, x=x: d.rounded_rectangle([x * ss, 44 * k * ss, (x + (12 + r.random() * 8) * k) * ss, 54 * k * ss], radius=3 * k * ss, fill=255))
        img = over(img, ln * sign, hexc("5a3a1c"))
    win = box(26, 74, 230, 246)
    # shop interior: warm back wall, shelves, painted goods
    yy = (np.arange(S, dtype=F32)[:, None] / k - 74) / 172.0
    xx = (np.arange(S, dtype=F32)[None, :] / k - 26) / 204.0
    inner = np.stack([0.34 + 0.10 * (1 - yy), 0.25 + 0.08 * (1 - yy), 0.20 + 0.05 * (1 - yy)], -1) * np.ones((S, S, 1), F32)
    inner = inner * (1 - 0.35 * smooth(0.6, 1.0, np.abs(xx - 0.5) * 2))[..., None]
    img = over(img, win, inner)
    for sy in (0.32, 0.62):
        shelf = box(26, 74 + 172 * sy, 230, 74 + 172 * sy + 5)
        img = over(img, shelf * win, hexc("6b4a2e"))
        for i in range(9):
            gx = 34 + i * 22 + r.random() * 6
            gh = 14 + r.random() * 16
            gc = hsl(r.random() * 360, 38 + r.random() * 14, 52 + r.random() * 12)
            gm = shapes(S, lambda d, ss, gx=gx, gh=gh, sy=sy: d.rounded_rectangle([gx * k * ss, (74 + 172 * sy - gh) * k * ss, (gx + 12 + r.random() * 6) * k * ss, (74 + 172 * sy) * k * ss], radius=3 * k * ss, fill=255))
            img = over(img, gm * win, gc)
    refl = shapes(S, lambda d, ss: d.polygon([(32 * k * ss, 80 * k * ss), (96 * k * ss, 80 * k * ss), (62 * k * ss, 190 * k * ss), (32 * k * ss, 190 * k * ss)], fill=255))
    img = img * (1 - 0.16 * refl[..., None] * win[..., None]) + 0.16 * refl[..., None] * win[..., None] * np.array([0.92, 0.96, 1.0], F32)
    mull = box(S / k / 2 - 3, 74, S / k / 2 + 3, 246)
    tr = box(26, 150, 230, 155)
    img = over(img, np.clip(mull + tr, 0, 1) * win, absolute(wood, frame)[0:1, 0:1].mean((0, 1)) if False else frame)
    em = over(em, win, hsl(40, 85, 62)[None, None, :] * (0.75 + 0.3 * (1 - yy) * (1 - 0.4 * np.abs(xx - 0.5) * 2))[..., None])
    em = em * (1 - np.clip(mull + tr, 0, 1))[..., None]
    return np.clip(img, 0, 1), np.clip(em, 0, 1)


def groundres(S=512):
    pb.S = S
    k = S / 256.0
    img = absolute(pb.ashlar(seed=181, rows=10, per_row=(3,) * 10, contrast=0.8, jitter=0.2), hexc("cbbd9f"))
    em = np.zeros((S, S, 3), F32)
    gm, gc = _glass(S, 70 * k, 80 * k, 116 * k, 150 * k, 40 * k)
    ring = np.clip(blur(gm, 3 * k) * 1.8 - gm, 0, 1)
    img = over(img, ring * 0.7, np.array([0.18, 0.14, 0.10], F32))
    img = over(img, gm, gc)
    mull = shapes(S, lambda d, ss: d.rectangle([124 * k * ss, 60 * k * ss, 132 * k * ss, 230 * k * ss], fill=255))
    img = over(img, mull * gm, hexc("e7dcc4"))
    r = np.random.default_rng(77)
    if r.random() < 0.5:
        em = over(em, gm, hsl(38, 80, 58)[None, None, :] * 0.9)
        em = em * (1 - mull * gm)[..., None]
    return np.clip(img, 0, 1), np.clip(em, 0, 1)


def build_all():
    jobs = {}
    jobs["cobble"] = lambda: save(cobble(), "cobble")
    jobs["paving"] = lambda: save(paving(), "paving")
    def _plaza():
        p = plaza()
        save(p, "plaza")
        save(p, "quay")
    jobs["plaza"] = _plaza
    jobs["grass"] = lambda: save(grass(), "grass")
    jobs["ashlar"] = lambda: save(ashlar_wall(), "ashlar")
    for kd in ROOF_BASE:
        jobs["roof_" + kd] = (lambda kd=kd: save(roof(kd), "roof_" + kd))
    jobs["awning"] = lambda: save(awning(), "awning")
    for kd in ("haus", "brick", "plaster", "warehouse", "academy", "timber"):
        def _f(kd=kd):
            c, e = facade(kd)
            save(c, "fac_" + kd)
            save(e, "fac_" + kd + "_em")
        jobs["fac_" + kd] = _f
    for i in range(4):
        def _s(i=i):
            c, e = shopfront(i)
            save(c, f"shop{i}")
            save(e, f"shop{i}_em")
        jobs[f"shop{i}"] = _s
    def _g():
        c, e = groundres()
        save(c, "groundres")
        save(e, "groundres_em")
    jobs["groundres"] = _g
    return jobs


if __name__ == "__main__":
    for name, fn in build_all().items():
        if ONLY and name not in ONLY:
            continue
        fn()
