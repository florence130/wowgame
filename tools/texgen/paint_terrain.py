# Procedural hand-painted terrain textures (tileable), stylised after Mabinogi Eternity ground art.
# python tools/texgen/paint_terrain.py <out_dir> [size]
# Everything is drawn on a torus (wrap-around), so every texture tiles seamlessly.
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/terrain"
S = int(sys.argv[2]) if len(sys.argv) > 2 else 512
SS = S * 2  # supersampled canvas
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(20261005)


# ------------------------------------------------------------------ helpers
def tnoise(scale, octaves=4, seed=0, size=SS):
    """Tileable value noise (sum of octaves of bicubic-upsampled random grids)."""
    r = np.random.default_rng(seed)
    acc = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = max(2, int(scale * (2 ** o)))
        g = r.random((n, n)).astype(np.float32)
        # tile 3x3, upsample, crop centre -> seamless
        big = np.tile(g, (3, 3))
        im = Image.fromarray((big * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
        a = np.asarray(im).astype(np.float32)[size:size * 2, size:size * 2] / 255.0
        acc += a * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def relaxed_points(n_pts, seed, iters=4, res=128):
    """Random points evened out by Lloyd relaxation on the torus (irregular but similar-sized cells)."""
    r = np.random.default_rng(seed)
    pts = r.random((n_pts, 2))
    yy, xx = np.mgrid[0:res, 0:res].astype(np.float32) / res
    for _ in range(iters):
        best = np.full((res, res), 9.0, np.float32)
        cid = np.zeros((res, res), np.int32)
        for k, (px, py) in enumerate(pts):
            dx = xx - px; dx -= np.round(dx)
            dy = yy - py; dy -= np.round(dy)
            d = dx * dx + dy * dy
            m = d < best
            best = np.where(m, d, best); cid = np.where(m, k, cid)
        for k in range(n_pts):
            sel = cid == k
            if not sel.any():
                continue
            # 环面上的质心：以当前点为参照展开
            dx = xx[sel] - pts[k, 0]; dx -= np.round(dx)
            dy = yy[sel] - pts[k, 1]; dy -= np.round(dy)
            pts[k] = ((pts[k, 0] + dx.mean()) % 1.0, (pts[k, 1] + dy.mean()) % 1.0)
    return pts


def voronoi(n_pts, seed, size=SS, jitter=1.0, grid=None, pts=None):
    """Tileable Voronoi: returns (F1, F2, cell id) arrays. Points on a jittered grid (gx x gy) or random."""
    r = np.random.default_rng(seed)
    if pts is not None:
        pts = np.asarray(pts)
    elif grid:
        gx, gy = grid
        pts = []
        for j in range(gy):
            for i in range(gx):
                off = 0.5 if j % 2 else 0.0
                pts.append(((i + off + 0.5 + (r.random() - 0.5) * jitter) / gx, (j + 0.5 + (r.random() - 0.5) * jitter) / gy))
        pts = np.array(pts) % 1.0
    else:
        pts = r.random((n_pts, 2))
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    f1 = np.full((size, size), 9.0, np.float32)
    f2 = np.full((size, size), 9.0, np.float32)
    cid = np.zeros((size, size), np.int32)
    for k, (px, py) in enumerate(pts):
        dx = np.abs(xx - px); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(yy - py); dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, k, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid, len(pts)


def col(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def to_img(a):
    a = np.clip(a, 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8), "RGB")


def wrap_draw(img, draw_fn):
    """Call draw_fn(draw, ox, oy) for the 9 torus offsets so strokes wrap around edges."""
    d = ImageDraw.Draw(img, "RGBA")
    for oy in (-SS, 0, SS):
        for ox in (-SS, 0, SS):
            draw_fn(d, ox, oy)


def strokes(img, n, colors, length, width, angle=None, seed=1, curve=0.35, alpha=(140, 230)):
    """Painterly blade / brush strokes: tapered curved polylines."""
    r = np.random.default_rng(seed)
    items = []
    for _ in range(n):
        x, y = r.random() * SS, r.random() * SS
        a = (angle if angle is not None else r.random() * math.tau) + (r.random() - 0.5) * 0.9
        L = length * (0.6 + r.random() * 0.8)
        w = width * (0.6 + r.random() * 0.8)
        c = colors[r.integers(len(colors))]
        al = int(r.integers(alpha[0], alpha[1]))
        bend = (r.random() - 0.5) * curve
        items.append((x, y, a, L, w, c, al, bend))

    def fn(d, ox, oy):
        for (x, y, a, L, w, c, al, bend) in items:
            if not (-L <= x + ox <= SS + L and -L <= y + oy <= SS + L):
                continue
            pts_l, pts_r = [], []
            segs = 5
            for s in range(segs + 1):
                f = s / segs
                aa = a + bend * f
                px = x + ox + math.cos(aa) * L * f
                py = y + oy + math.sin(aa) * L * f
                ww = w * (1 - f) ** 0.8 + 0.4
                nx, ny = -math.sin(aa), math.cos(aa)
                pts_l.append((px + nx * ww, py + ny * ww))
                pts_r.append((px - nx * ww, py - ny * ww))
            rgb = tuple(int(v * 255) for v in c)
            d.polygon(pts_l + pts_r[::-1], fill=rgb + (al,))
    wrap_draw(img, fn)


def dots(img, n, colors, rmin, rmax, seed=2, alpha=(200, 255), highlight=False):
    r = np.random.default_rng(seed)
    items = [(r.random() * SS, r.random() * SS, rmin + r.random() * (rmax - rmin), colors[r.integers(len(colors))], int(r.integers(*alpha))) for _ in range(n)]

    def fn(d, ox, oy):
        for (x, y, rr, c, al) in items:
            X, Y = x + ox, y + oy
            if not (-rr <= X <= SS + rr and -rr <= Y <= SS + rr):
                continue
            rgb = tuple(int(v * 255) for v in c)
            if highlight:
                sh = tuple(int(v * 255 * 0.6) for v in c)
                d.ellipse((X - rr + rr * 0.25, Y - rr * 0.8 + rr * 0.3, X + rr + rr * 0.25, Y + rr * 0.8 + rr * 0.3), fill=sh + (int(al * 0.6),))
            d.ellipse((X - rr, Y - rr * 0.8, X + rr, Y + rr * 0.8), fill=rgb + (al,))
            if highlight:
                hl = tuple(min(255, int(v * 255 * 1.25 + 30)) for v in c)
                d.ellipse((X - rr * 0.55, Y - rr * 0.6, X + rr * 0.1, Y - rr * 0.05), fill=hl + (int(al * 0.7),))
    wrap_draw(img, fn)


def save(img, name):
    img = img.filter(ImageFilter.GaussianBlur(0.6)).resize((S, S), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))
    print("PAINTED", name)


# ------------------------------------------------------------------ grass family
def grass_base(c_dark, c_mid, c_light, seed):
    n1 = tnoise(3, 3, seed)
    n2 = tnoise(10, 3, seed + 1)
    t = ss(0.3, 0.75, n1 * 0.7 + n2 * 0.3)
    a = lerp(lerp(c_dark, c_mid, ss(0.2, 0.55, n1)), c_light, t * 0.6)
    return to_img(a)


def grass(name, c_dark, c_mid, c_light, seed, extra=None):
    # 洛奇M 地面：低频大色块为主，笔触稀疏且低对比（草的细节由 3D 草丛提供，贴图不能“满屏噪点”）
    img = grass_base(c_dark, c_mid, c_light, seed)
    blades = [c_dark * 0.92, c_mid * 0.95, c_mid, c_mid * 1.05, c_light, c_light * 1.03]
    blades = [np.clip(b, 0, 1) for b in blades]
    strokes(img, 700, blades[:3], 40, 3.6, angle=-math.pi / 2, seed=seed + 2, curve=0.6, alpha=(50, 110))
    strokes(img, 900, blades[2:], 30, 2.8, angle=-math.pi / 2, seed=seed + 3, curve=0.7, alpha=(60, 120))
    if extra:
        extra(img)
    save(img, name)


# 色值按洛奇M 实机取色：色相约 100–110°，饱和 0.4–0.5（旧版 3f7f2a/62a537/a2cf55 偏黄、过艳）
G_DARK, G_MID, G_LIGHT = col("3b6534"), col("55844a"), col("82a85e")
grass("t0_grass", G_DARK, G_MID, G_LIGHT, 10)
grass("t1_grass_dark", col("2a4e2a"), col("3d6838"), col("5a8248"), 20,
      extra=lambda im: dots(im, 200, [col("46703c"), col("527c44"), col("38602f")], 6, 12, seed=21, alpha=(110, 180)))
grass("t7_flowers", G_DARK, G_MID, G_LIGHT, 30,
      extra=lambda im: dots(im, 900, [col("ffffff"), col("fff1a8"), col("ffd84a"), col("d9c4ff"), col("ffb3c8"), col("b9a3ff")], 2.5, 6, seed=31, highlight=True))

# ------------------------------------------------------------------ moss
m1 = tnoise(5, 4, 40)
m2 = tnoise(14, 3, 41)
moss = lerp(col("3a3524"), col("4f7a2c"), ss(0.35, 0.6, m1))
moss = lerp(moss, col("78a640"), ss(0.55, 0.75, m1 * 0.6 + m2 * 0.4) * 0.8)
img = to_img(moss)
dots(img, 1600, [col("6a9a38"), col("86b44a"), col("4c7a2a")], 4, 11, seed=42, alpha=(120, 210))
dots(img, 140, [col("9a948a"), col("8a8478")], 6, 14, seed=43, highlight=True)
strokes(img, 900, [col("5c8e30"), col("7aaa40")], 18, 2.2, seed=44, alpha=(100, 180))
save(img, "t8_moss")

# ------------------------------------------------------------------ dirt path
d1 = tnoise(4, 4, 50)
d2 = tnoise(18, 3, 51)
dirt = lerp(col("a67c52"), col("c9a271"), ss(0.3, 0.7, d1))
dirt = lerp(dirt, col("d8b888"), ss(0.6, 0.85, d2) * 0.5)
dirt = lerp(dirt, col("8a6440"), ss(0.65, 0.9, 1 - d2) * 0.35)
img = to_img(dirt)
strokes(img, 1400, [col("b8915f"), col("d6b585"), col("9a7048")], 40, 4, angle=0.0, seed=52, curve=0.2, alpha=(50, 110))
dots(img, 520, [col("b8ac98"), col("cfc4b0"), col("9c8f7c"), col("a88a68")], 3, 9, seed=53, highlight=True)
save(img, "t2_dirt")

# ------------------------------------------------------------------ sand
s1 = tnoise(4, 4, 60)
s2 = tnoise(40, 2, 61)
yy = np.mgrid[0:SS, 0:SS][0].astype(np.float32) / SS
rip = 0.5 + 0.5 * np.sin((yy * 16 + tnoise(3, 2, 62) * 3.0) * math.tau)
sand = lerp(col("e3c992"), col("f3e2b6"), ss(0.3, 0.7, s1))
sand = lerp(sand, col("d4b67e"), (ss(0.75, 1.0, rip) * 0.35)[..., None][..., 0])
sand = sand * (0.95 + 0.1 * s2[..., None])
img = to_img(sand)
dots(img, 120, [col("fff4e0"), col("f0d0c0"), col("e8e0d0")], 3, 7, seed=63, highlight=True)
save(img, "t4_sand")

# ------------------------------------------------------------------ farm furrows
f1 = tnoise(4, 3, 70)
xx = np.mgrid[0:SS, 0:SS][1].astype(np.float32) / SS
fur = 0.5 + 0.5 * np.cos((xx * 12 + tnoise(2, 2, 71) * 0.4) * math.tau)
farm = lerp(col("5a3a22"), col("8a5e38"), fur)
farm = lerp(farm, col("a07448"), ss(0.85, 1.0, fur) * 0.6)
farm = farm * (0.9 + 0.2 * f1[..., None])
img = to_img(farm)
strokes(img, 900, [col("6a462a"), col("9a6c42")], 30, 3, angle=-math.pi / 2, seed=72, curve=0.1, alpha=(60, 130))
# sprouts along ridges
r = np.random.default_rng(73)
items = []
for row in range(12):
    for k in range(18):
        items.append(((row + 0.5) / 12 * SS + (r.random() - 0.5) * 10, (k + r.random()) / 18 * SS))


def sprout(d, ox, oy):
    for (x, y) in items:
        X, Y = x + ox, y + oy
        if -20 <= X <= SS + 20 and -20 <= Y <= SS + 20:
            d.ellipse((X - 9, Y - 4, X, Y + 3), fill=(110, 170, 60, 230))
            d.ellipse((X, Y - 4, X + 9, Y + 3), fill=(130, 190, 70, 230))
wrap_draw(img, sprout)
save(img, "t6_farm")

# ------------------------------------------------------------------ rock (big chunky facets)
# 洛奇M 式岩壁：横向层理的大块岩板（宽而矮），每块上缘受光、下缘压暗，板间是深色裂隙；冷灰为主、少量暖灰，零星苔点。
# 贴图竖直方向 = 世界竖直方向（三向投影的侧面），所以层理是水平的
r = np.random.default_rng(81)
yy, xx = np.mgrid[0:SS, 0:SS].astype(np.float32) / SS
pts = r.random((46, 2))
ASP = 2.6   # 横向拉长：层状岩板
f1 = np.full((SS, SS), 9.0, np.float32)
f2 = np.full((SS, SS), 9.0, np.float32)
cid = np.zeros((SS, SS), np.int32)
for k, (px, py) in enumerate(pts):
    dx = xx - px; dx -= np.round(dx)
    dy = yy - py; dy -= np.round(dy)
    d = np.sqrt((dx / ASP) ** 2 + dy * dy)
    closer = d < f1
    f2 = np.where(closer, f1, np.minimum(f2, d)); cid = np.where(closer, k, cid); f1 = np.where(closer, d, f1)
n = len(pts)
tone = r.random(n).astype(np.float32)
warm = (r.random(n) > 0.75).astype(np.float32)
cy = pts[:, 1]
# 板内纵向位置：上缘亮、下缘暗（以板中心为参照）
rel = yy - cy[cid]; rel -= np.round(rel)
shade = ss(0.06, -0.08, rel)          # 越往下越暗
base = lerp(col("8b9196"), col("b4b8b8"), tone[cid] * 0.7 + 0.3 * tnoise(6, 3, 82))
base = lerp(base, col("aea596"), warm[cid] * 0.5)
base = base * (0.8 + 0.28 * shade[..., None])
gap = f2 - f1
crack = ss(0.0, 0.01, gap)
base = base * (0.45 + 0.55 * crack[..., None])
lip = ss(0.01, 0.022, gap) * (1 - ss(0.022, 0.04, gap)) * ss(0.0, 0.05, -rel)   # 岩板上缘一道亮边
base = lerp(base, col("d4d6d2"), lip * 0.45)
img = to_img(base)
strokes(img, 260, [col("7a8086"), col("a3a8aa")], 50, 1.6, angle=0.0, seed=83, curve=0.15, alpha=(60, 120))
dots(img, 90, [col("6f8a4a"), col("5f7c40")], 5, 11, seed=84, alpha=(110, 170))
save(img, "t3_rock")

# ------------------------------------------------------------------ cobblestone (rounded flagstones)
# 洛奇M 提尔克那式石板：大小不一的不规则石块（随机点 + 少量大块），粗而深的灰缝，缝里长草；
# 石面是平涂的暖米灰 + 上缘提亮的圆角，不要规则蜂窝
r = np.random.default_rng(91)
F1, F2, cid, n = voronoi(0, 90, pts=relaxed_points(42, 90, iters=1))
tone = r.random(n).astype(np.float32)
warm = r.random(n).astype(np.float32)
gap = F2 - F1
gw = 0.008 + 0.005 * tnoise(6, 2, 95)          # 灰缝宽度随位置变化
inside = ss(gw, gw + 0.012, gap)
bevel = ss(gw, gw + 0.06, gap)
st = lerp(lerp(col("b3ab9b"), col("d6cfbf"), tone[cid]), col("cdbb9c"), warm[cid] * 0.35)
st = st * (0.88 + 0.14 * bevel[..., None]) * (0.97 + 0.06 * tnoise(5, 2, 92)[..., None])
yy, xx = np.mgrid[0:SS, 0:SS].astype(np.float32) / SS
grout = lerp(col("6f695d"), col("566f3c"), ss(0.45, 0.75, tnoise(7, 3, 93)) * 0.75)
cob = lerp(grout + np.zeros_like(st), st, inside)
img = to_img(cob)
strokes(img, 160, [col("5f7f3a"), col("6f9444")], 14, 2.4, seed=94, alpha=(110, 180))
dots(img, 60, [col("c9c1b0"), col("a9a192")], 3, 6, seed=96, alpha=(90, 150))
save(img, "t5_cobble")
print("ALL_PAINTED")
