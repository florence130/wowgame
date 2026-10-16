# Hand-painted RGB "multiplier" building textures in the Mabinogi-Remake / Breath-of-the-Wild manner:
# individually painted tiles / bricks / stones with hue + value variation, soft painted edge shading, brush streaks, no photo noise, no specular.
# Output: assets/textures/building/pt_*.png   (shader: albedo = base_color * texture * 2, see src/render/building.gdshader)
#   py tools/texgen/paint_building_v2.py [out_dir] [size] [only,names]
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paintlib import F32, blur, courses, coords, edge_masks, finish, fnoise, gnoise, hsh, leaf_dabs, smooth, voronoi, wobble  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/building"
S = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
ONLY = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else None
os.makedirs(OUT, exist_ok=True)


def stack(r, g, b):
    return np.stack([r, g, b], -1).astype(F32)


# ------------------------------------------------------------------ plaster: soft trowel washes
def plaster(seed=1):
    v = 1 + 0.045 * gnoise(S, 70, seed=seed) + 0.025 * gnoise(S, 20, seed=seed + 1)
    warm = gnoise(S, 110, seed=seed + 2)
    sel = gnoise(S, 160, seed=seed + 3)
    strokes = np.zeros((S, S), F32)
    for k, th in enumerate([-0.55, 0.45, 1.45]):
        w = smooth(-0.1, 1.1, sel * (1 if k == 0 else -1)) if k < 2 else smooth(0.2, 1.3, gnoise(S, 130, seed=seed + 5))
        strokes += w * gnoise(S, 26, 3.0, th, seed=seed + 10 + k)
    v = v + 0.016 * strokes
    blotch = smooth(0.7, 1.7, gnoise(S, 40, seed=seed + 4))
    v = v - 0.04 * blotch
    pits = smooth(2.2, 3.0, gnoise(S, 1.3, seed=seed + 6))
    pits = blur(pits, 0.9)
    v = v - 0.18 * pits
    return stack(v * (1 + 0.018 * warm), v * (1 + 0.003 * warm), v * (1 - 0.024 * warm))


# ------------------------------------------------------------------ brick: each brick its own painted warm colour
def brick(seed=3):
    rows, n = 12, 5
    c = courses(S, rows, n, seed, shift=0.5, wob=0.003, wob_sigma=30)
    u, v, w, h = c["u"], c["v"], c["w"], c["h"]
    du, dv, dm = edge_masks(u, v, w, h, S, 0)
    gap = S / 170.0                        # mortar half width (px)
    inb = smooth(gap - 1.2, gap + 1.2, dm)
    a = hsh(c["rid"], c["cid"], seed=seed) * 2 - 1
    b = hsh(c["rid"], c["cid"], seed=seed + 1) * 2 - 1
    r = 1 + 0.07 * a + 0.05 * b
    g = 1 + 0.15 * a - 0.04 * b
    bl = 1 + 0.17 * a - 0.04 * b
    shade = 1 + 0.10 * (0.5 - v)
    shade = shade + 0.03 * gnoise(S, S / 30.0, 2.0, 0.0, seed=seed + 2) + 0.03 * gnoise(S, 9, seed=seed + 3)
    top = smooth(S / 90.0, 0.0, v * h * S - gap)
    left = smooth(S / 110.0, 0.0, u * w * S - gap)
    bot = smooth(S / 60.0, 0.0, (1 - v) * h * S - gap)
    rim = smooth(S / 70.0, 0.0, dm - gap)
    shade = shade + 0.14 * top + 0.06 * left - 0.14 * bot - 0.12 * rim
    chip = blur(smooth(2.0, 2.8, gnoise(S, 3.0, seed=seed + 5)), 1.0)
    shade = shade - 0.12 * chip
    mortar = 1.18 + 0.06 * gnoise(S, 4, seed=seed + 6)
    col = stack(r * shade, g * shade, bl * shade)
    mort = stack(mortar * 1.0, mortar * 0.96, mortar * 0.88)
    return col * inb[..., None] + mort * (1 - inb[..., None])


# ------------------------------------------------------------------ ashlar: coursed blocks, painted soft bevel + dark hand-drawn joints
def ashlar(seed=5, rows=5, per_row=(4, 3, 4, 3, 4), gap_px=None, contrast=1.0, jitter=0.35):
    c = courses(S, rows, list(per_row), seed, shift=0.0, wob=0.0026, wob_sigma=48, width_jitter=jitter, row_jitter=0.14)
    u, v, w, h = c["u"], c["v"], c["w"], c["h"]
    du, dv, dm = edge_masks(u, v, w, h, S, 0)
    gap = (gap_px or S / 150.0)
    inb = smooth(gap - 1.5, gap + 1.5, dm)
    a = hsh(c["rid"], c["cid"], seed=seed) * 2 - 1
    t = hsh(c["rid"], c["cid"], seed=seed + 1) * 2 - 1
    val = 1 + 0.07 * a * contrast
    r = val * (1 + 0.028 * t)
    g = val * (1 + 0.003 * t)
    b = val * (1 - 0.045 * t)
    shade = 1 + 0.10 * (0.5 - v) + 0.04 * gnoise(S, S / 26.0, 2.2, 0.0, seed=seed + 2) + 0.035 * gnoise(S, 11, seed=seed + 3)
    top = smooth(S / 50.0, 0.0, v * h * S - gap)
    left = smooth(S / 70.0, 0.0, u * w * S - gap)
    bot = smooth(S / 40.0, 0.0, (1 - v) * h * S - gap)
    right = smooth(S / 80.0, 0.0, (1 - u) * w * S - gap)
    shade = shade + 0.12 * top + 0.05 * left - 0.13 * bot - 0.06 * right
    # painted cracks (sparse) + a few stained patches
    ridge = np.abs(gnoise(S, 7, seed=seed + 7))
    crack = smooth(0.06, 0.0, ridge) * smooth(1.0, 1.8, gnoise(S, 70, seed=seed + 8))
    stain = smooth(0.6, 1.6, gnoise(S, 55, seed=seed + 9))
    shade = shade - 0.28 * crack - 0.05 * stain
    col = stack(r * shade, g * shade, b * shade)
    col = col * (1 + 0.0 * stain[..., None])
    jointcol = np.array([0.50, 0.47, 0.44], F32) * (1 + 0.15 * gnoise(S, 3, seed=seed + 10))[..., None]
    return col * inb[..., None] + jointcol * (1 - inb[..., None])


# ------------------------------------------------------------------ rubble / cobble wall: round painted stones
def rubble(seed=7, n=7):
    sid, d1, d2, dx, dy = voronoi(S, n, seed, 0.7)
    e = (d2 - d1) * S                                # px distance to the shared border (x2)
    gap = S / 120.0
    inb = smooth(gap - 1.5, gap + 1.5, e * 0.5)
    a = hsh(sid, seed=seed) * 2 - 1
    t = hsh(sid, seed=seed + 1) * 2 - 1
    val = 1 + 0.10 * a
    r, g, b = val * (1 + 0.03 * t), val * (1 + 0.0 * t), val * (1 - 0.05 * t)
    light = np.clip(-dy * n * 1.4, -1, 1)           # lit from above
    shade = 1 + 0.12 * light + 0.04 * gnoise(S, 12, seed=seed + 2)
    rim = smooth(S / 22.0, 0.0, e * 0.5 - gap)
    shade = shade - 0.20 * rim
    col = stack(r * shade, g * shade, b * shade)
    joint = np.array([0.48, 0.45, 0.42], F32)
    return col * inb[..., None] + joint * (1 - inb[..., None])


# ------------------------------------------------------------------ overlapping shingle roofs (clay tile / slate / verdigris copper)
def shingle(rows, n, seed, color_fn, scallop=0.22, overlap=0.30, shadow=0.42, edge_light=0.16, wob=0.003, streak=0.022):
    x, y = coords(S)
    wx, wy = wobble(S, wob, 35, seed * 5 + 1)
    X, Y = np.mod(x + wx, 1.0), np.mod(y + wy, 1.0)
    Yr = Y * rows
    row = np.floor(Yr).astype(int) % rows
    v = Yr - np.floor(Yr)
    Xr = X * n + (row % 2) * 0.5
    col = np.floor(Xr).astype(int)
    u = Xr - col
    col = col % n
    row_a = (row - 1) % rows
    Xa = X * n + (row_a % 2) * 0.5
    col_a = np.floor(Xa).astype(int)
    ua = Xa - col_a
    col_a = col_a % n
    edge_a = overlap * (1 - scallop * (2 * ua - 1) ** 2)
    cov = v < edge_a
    rid = np.where(cov, row_a, row)
    cid = np.where(cov, col_a, col)
    uu = np.where(cov, ua, u)
    vv = np.where(cov, 1 + v, v)
    a = hsh(rid, cid, seed=seed) * 2 - 1
    b = hsh(rid, cid, seed=seed + 1) * 2 - 1
    c = hsh(rid, cid, seed=seed + 2) * 2 - 1
    rgb = color_fn(a, b, c)
    t = np.clip((vv - overlap) / 1.0, 0, 1)
    shade = 0.90 + 0.17 * t
    dist_low = np.where(cov, edge_a - v, 9.0)
    shade = shade + edge_light * smooth(0.075, 0.0, dist_low) - 0.34 * smooth(0.03, 0.0, dist_low)
    d_below = np.where(cov, 9.0, v - edge_a)
    shade = shade - shadow * smooth(0.24, 0.0, d_below)
    side = np.minimum(uu, 1 - uu) * S / n
    shade = shade - 0.26 * smooth(S / 160.0, 0.5, side)
    shade = shade + streak * gnoise(S, 3.0, S / 20.0, 0.0, seed=seed + 3) + 0.045 * gnoise(S, S / (n * 3.5), seed=seed + 4)
    return rgb * shade[..., None]


def roof_tile(seed=11):
    def cf(a, b, c):
        r = 1 + 0.07 * a + 0.04 * b
        g = 1 + 0.30 * a + 0.12 * b
        bl = 1 + 0.22 * a - 0.10 * b
        fresh = (c > 0.88).astype(F32)               # the odd replaced tile: brighter, more orange
        return stack(r * (1 + 0.08 * fresh), g * (1 + 0.20 * fresh), bl * (1 + 0.05 * fresh))
    return shingle(7, 6, seed, cf, scallop=0.14, overlap=0.28, shadow=0.20, edge_light=0.10, streak=0.012)     # 洛奇M：大片平涂瓦，缝线浅


def roof_slate(seed=13):
    def cf(a, b, c):
        val = 1 + 0.11 * a
        r = val * (1 + 0.05 * b - 0.02)
        g = val * (1 + 0.025 * b)
        bl = val * (1 - 0.06 * b + 0.015)
        moss = (c > 0.9).astype(F32)
        return stack(r * (1 - 0.05 * moss), g * (1 + 0.10 * moss), bl * (1 - 0.08 * moss))
    return shingle(8, 6, seed, cf, scallop=0.22, overlap=0.32, shadow=0.20, edge_light=0.10, streak=0.012)


def copper(seed=17):
    def cf(a, b, c):
        val = 1 + 0.10 * a
        r = val * (1 - 0.09 * b)
        g = val * (1 + 0.04 * b)
        bl = val * (1 - 0.12 * b + 0.06)
        rust = (c > 0.9).astype(F32)               # oxidising tiles, warm brown
        return stack(r * (1 + 0.38 * rust), g * (1 - 0.06 * rust), bl * (1 - 0.34 * rust))
    return shingle(8, 6, seed, cf, scallop=0.30, overlap=0.30, shadow=0.36, edge_light=0.14)


# ------------------------------------------------------------------ wood: vertical planks, painted grain, dark joints
def wood(seed=19, n=9):
    r = np.random.default_rng(seed)
    x, y = coords(S)
    wx, wy = wobble(S, 0.003, 40, seed * 3 + 1)
    X, Y = np.mod(x + wx, 1.0), np.mod(y + wy, 1.0)
    ws = 1 + (r.random(n) - 0.5) * 0.4
    b = np.concatenate([[0], np.cumsum(ws / ws.sum())])
    pid = np.clip(np.searchsorted(b, X, side="right") - 1, 0, n - 1)
    wid = b[pid + 1] - b[pid]
    u = (X - b[pid]) / wid
    seg = np.zeros((S, S), np.int64)
    off = r.random(n)
    for k in range(n):
        m = pid == k
        brk = np.sort(r.random(2) * 0.6 + np.array([0.0, 0.5]))   # two end joints per plank
        yy = np.mod(Y[m] - off[k] * 0.0, 1.0)
        seg[m] = (yy > brk[0]).astype(int) + (yy > brk[1]).astype(int)
        seg[m] += k * 3
    a = hsh(seg, seed=seed) * 2 - 1
    t = hsh(seg, seed=seed + 1) * 2 - 1
    val = 1 + 0.10 * a
    rr, gg, bb = val * (1 + 0.05 * t), val * (1 + 0.0 * t), val * (1 - 0.09 * t)
    grain = 0.10 * gnoise(S, 1.8, 150.0, 0.0, seed=seed + 2) + 0.05 * gnoise(S, 0.9, 45.0, 0.0, seed=seed + 3)
    rings = 0.045 * np.sin(2 * np.pi * (u * 3.0 + 1.3 * gnoise(S, 70, 160, 0.0, seed=seed + 4)))
    shade = 1 + grain + rings
    edge_px = np.minimum(u, 1 - u) * wid * S
    gap = S / 190.0
    dark = smooth(gap + 1.5, gap - 1.0, edge_px)
    hl = smooth(S / 90.0, 0.0, u * wid * S - gap)
    shade = shade + 0.10 * hl - 0.45 * dark
    # end joints (horizontal dark hairlines) + knots
    jy = np.zeros((S, S), F32)
    for k in range(n):
        for j in range(2):
            pass
    segline = np.abs(np.diff(seg, axis=0, prepend=seg[:1]))
    segline = blur((segline > 0).astype(F32), 1.2) * 4.0
    shade = shade - 0.5 * np.clip(segline, 0, 1)
    kn = np.zeros((S, S), F32)
    for _ in range(3):
        cx, cy = r.random(), r.random()
        dx = (X - cx + 0.5) % 1.0 - 0.5
        dy = (Y - cy + 0.5) % 1.0 - 0.5
        d = np.sqrt((dx * S / 10.0) ** 2 + (dy * S / 26.0) ** 2)
        kn += np.exp(-d * d) * 0.45 + 0.08 * np.sin(d * 6.0) * np.exp(-d * d * 0.12)
    shade = shade - kn
    return stack(rr * shade, gg * shade, bb * shade)


# ------------------------------------------------------------------ painted metal (iron / bronze / gold take their colour from base_color)
def metal(seed=23):
    v = 1 + 0.05 * gnoise(S, 1.8, 90.0, 0.0, seed=seed) + 0.035 * gnoise(S, 40, seed=seed + 1)
    scuff = smooth(1.5, 2.6, gnoise(S, 1.6, 14.0, 0.7, seed=seed + 2))
    v = v + 0.10 * scuff
    rust = smooth(1.3, 2.4, gnoise(S, 14, seed=seed + 3)) * 0.55
    return stack(v * (1 + 0.16 * rust), v * (1 - 0.06 * rust), v * (1 - 0.30 * rust))


# ------------------------------------------------------------------ foliage clumps (vines / hedges / dense plants): overlapping painted leaf dabs
def foliage(seed=29):
    d = leaf_dabs(S, int(S * 0.9), seed, (0.045, 0.10))
    cover = (d > 0).astype(F32)
    core = blur(cover, 2.4)
    rim = cover * (1 - smooth(0.55, 0.9, core))
    val = (d - 0.15) / 0.85
    sh = 0.80 + 0.34 * val - 0.20 * rim
    sh = np.where(cover > 0, sh, 0.66)
    sh = sh + 0.03 * gnoise(S, 6, seed=seed + 1)
    t = (val - 0.5) * 2
    return stack(sh * (1 + 0.10 * t), sh * (1 + 0.02 * t), sh * (1 - 0.20 * t))


# ------------------------------------------------------------------ limestone: big pale sand-coloured blocks, soft joints, rain streaks
def limestone(seed=31):
    c = courses(S, 6, [3, 3, 3, 3, 3, 3], seed, shift=0.37, wob=0.0024, wob_sigma=48, width_jitter=0.22, row_jitter=0.08)
    u, v, w, h = c["u"], c["v"], c["w"], c["h"]
    du, dv, dm = edge_masks(u, v, w, h, S, 0)
    gap = S / 210.0
    inb = smooth(gap - 1.3, gap + 1.3, dm)
    a = hsh(c["rid"], c["cid"], seed=seed) * 2 - 1
    t = hsh(c["rid"], c["cid"], seed=seed + 1) * 2 - 1
    val = 1 + 0.05 * a
    r, g, b = val * (1 + 0.035 * t), val * (1 + 0.0 * t), val * (1 - 0.055 * t)
    shade = 1 + 0.06 * (0.5 - v) + 0.03 * gnoise(S, 40, seed=seed + 2) + 0.025 * gnoise(S, 10, seed=seed + 3)
    shade += -0.045 * smooth(0.5, 1.8, gnoise(S, 2.5, 170.0, 0.0, seed=seed + 4))      # rain streaks
    top = smooth(S / 80.0, 0.0, v * h * S - gap)
    bot = smooth(S / 55.0, 0.0, (1 - v) * h * S - gap)
    left = smooth(S / 100.0, 0.0, u * w * S - gap)
    shade = shade + 0.08 * top - 0.09 * bot + 0.04 * left
    speck = smooth(2.3, 3.1, gnoise(S, 1.2, seed=seed + 5))
    shade = shade - 0.10 * blur(speck, 0.8)
    col = stack(r * shade, g * shade, b * shade)
    jointcol = np.array([0.62, 0.59, 0.55], F32)
    return col * inb[..., None] + jointcol * (1 - inb[..., None])


# ------------------------------------------------------------------ 遮阳篷：竖条纹帆布（底色 = 点缀槽颜色，条纹交替变亮），带布纹与褶皱
def awning(seed=37):
    x, y = coords(S)
    wx, wy = wobble(S, 0.002, 60, seed)
    stripe = np.mod((x + wx) * 8.0, 1.0)
    band = (stripe < 0.5).astype(F32)
    edge = smooth(0.0, 0.03, stripe) * smooth(0.0, 0.03, 0.5 - stripe) + smooth(0.5, 0.53, stripe) * smooth(0.0, 0.03, 1.0 - stripe)
    v = 0.62 + 0.55 * band                       # 暗条 / 亮条（乘数，均值归一化后 ≈ 0.85 / 1.5）
    v = v * (0.96 + 0.08 * edge)
    weave = 0.035 * gnoise(S, 0.9, 0.9, seed=seed + 1) + 0.035 * gnoise(S, 40, 3.0, 0.0, seed=seed + 2)
    fold = 0.06 * np.sin(2 * np.pi * (x * 8.0 + 3.0 * wx)) * 0 + 0.05 * gnoise(S, 30, 90, 0.0, seed=seed + 3)
    v = v + weave + fold
    return stack(v, v * (1 + 0.02 * band), v * (1 - 0.0 * band))


# ------------------------------------------------------------------ 木瓦（铁匠铺屋面）：方头木片叠铺，深浅不一的棕色，竖向木纹
def shake(seed=41):
    def cf(a, b, c):
        val = 1 + 0.15 * a
        worn = (c > 0.86).astype(F32)                          # 偶尔一片新换的、更亮更黄的木瓦
        return stack(val * (1 + 0.07 * b + 0.10 * worn), val * (1 + 0.01 * b + 0.07 * worn), val * (1 - 0.10 * b - 0.04 * worn))
    return shingle(8, 5, seed, cf, scallop=0.04, overlap=0.30, shadow=0.26, edge_light=0.12, streak=0.03)


# ------------------------------------------------------------------ 树皮：竖向粗裂纹 + 一条条皮脊（树桩 / 原木侧面；树桩顶面的年轮是手建几何）
def bark(seed=53):
    x, y = coords(S)
    wx, wy = wobble(S, 0.004, 60, seed)
    X = np.mod(x + wx, 1.0)
    n = 11
    ridge = np.abs(np.sin(np.pi * X * n + 0.55 * gnoise(S, 30, 260.0, 0.0, seed=seed + 1)))     # 一条条纵向树皮脊
    furrow = smooth(0.35, 0.0, ridge)                                                             # 脊间深沟
    val = 1 + 0.13 * gnoise(S, 2.2, 150.0, 0.0, seed=seed + 2) + 0.05 * gnoise(S, 30, seed=seed + 3)
    val = val - 0.42 * furrow + 0.10 * smooth(0.6, 1.0, ridge)
    split = smooth(1.9, 2.8, gnoise(S, 1.4, 70.0, 0.0, seed=seed + 4))                           # 横向断裂
    val = val - 0.22 * split
    moss = smooth(1.2, 2.2, gnoise(S, 40, seed=seed + 5)) * 0.5
    return stack(val * (1 - 0.05 * moss), val * (1 + 0.02 * moss), val * (1 - 0.14 * moss))

# ------------------------------------------------------------------ 钢板：刷纹 + 板缝 + 铆钉（盔甲 / 铁砧 / 铁箍），底色由 base_color 决定
def steel(seed=43):
    x, y = coords(S)
    N = 3
    u, v = np.mod(x * N, 1.0), np.mod(y * N, 1.0)
    val = 1 + 0.05 * gnoise(S, 70, 1.6, 0.0, seed=seed) + 0.035 * gnoise(S, 30, seed=seed + 1)
    plate = hsh(np.floor(x * N).astype(int), np.floor(y * N).astype(int), seed=seed) * 2 - 1
    val = val * (1 + 0.05 * plate)
    edge = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) * S / N
    seam = smooth(S / 120.0, 0.0, edge)
    bevel = smooth(S / 45.0, S / 120.0, edge) * (0.12 * (0.5 - v) + 0.06 * (0.5 - u))   # 板缘受光
    val = val - 0.42 * seam + bevel
    # 铆钉：每块板四角内缩一点
    for cu in (0.13, 0.87):
        for cv in (0.13, 0.87):
            d = np.sqrt(((u - cu) * S / N) ** 2 + ((v - cv) * S / N) ** 2)
            r = S / 70.0
            dot = smooth(r, r * 0.55, d)
            hl = smooth(r * 0.9, 0.0, np.sqrt(((u - cu) * S / N + r * 0.28) ** 2 + ((v - cv) * S / N + r * 0.28) ** 2))
            val = val + 0.22 * dot * (0.4 + hl) - 0.25 * smooth(r * 1.9, r, d) * (1 - dot)
    scratch = smooth(1.8, 2.8, gnoise(S, 1.2, 40.0, 0.5, seed=seed + 2))
    val = val + 0.08 * scratch
    return stack(val * 1.01, val * 1.0, val * 1.04)


# ------------------------------------------------------------------ 皮革：小块卵石纹 + 一圈缝线（皮甲 / 皮围裙 / 风箱）
def leather(seed=47):
    x, y = coords(S)
    sid, d1, d2, dx, dy = voronoi(S, 26, seed, 0.9)
    e = (d2 - d1) * S
    pebble = smooth(0.0, S / 90.0, e * 0.5)
    val = 1 + 0.05 * gnoise(S, 50, seed=seed) + 0.035 * gnoise(S, 9, seed=seed + 1)
    val = val - 0.10 * (1 - pebble)
    N = 2
    u, v = np.mod(x * N, 1.0), np.mod(y * N, 1.0)
    edge = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) * S / N
    seam = smooth(S / 90.0, 0.0, edge)
    ste = smooth(S / 115.0, S / 190.0, np.abs(edge - S / (N * 11.0)))                  # 缝线带
    dash = (np.mod(np.where(np.minimum(u, 1 - u) < np.minimum(v, 1 - v), v, u) * N * 26.0, 1.0) < 0.55).astype(F32)
    stitch = ste * dash
    val = val - 0.38 * seam + 0.20 * stitch + 0.08 * smooth(S / 18.0, 0.0, edge)
    return stack(val * (1 + 0.04), val, val * (1 - 0.05))


ALL = {
    "pt_bark": bark, "pt_shake": shake, "pt_steel": steel, "pt_leather": leather,
    "pt_awning": awning,
    "pt_plaster": plaster, "pt_brick": brick, "pt_ashlar": ashlar, "pt_rubble": rubble, "pt_roof_tile": roof_tile, "pt_roof_slate": roof_slate,
    "pt_copper": copper, "pt_wood": wood, "pt_metal": metal, "pt_foliage": foliage, "pt_limestone": limestone,
}
SIZE = {"pt_metal": 512}

if __name__ == "__main__":
    for name, fn in ALL.items():
        if ONLY and name not in ONLY:
            continue
        rgb = fn()
        finish(rgb, os.path.join(OUT, name + ".png"), SIZE.get(name))
        print("painted", name, rgb.shape)
