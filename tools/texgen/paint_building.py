# Hand-painted building detail maps (greyscale, mean ~0.5, tileable) in the Mabinogi Mobile manner:
# big irregular stones drawn as flat fills with soft rounded edges and quiet joints - no photo noise, no brick grid.
# Output goes to assets/textures/building/pt_*.png and is used through U.TEX_ALIAS (kit materials keep their names).
# py tools/texgen/paint_building.py [out_dir] [size]
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/building"
S = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
SS = S * 2
os.makedirs(OUT, exist_ok=True)


def tnoise(scale, octaves, seed, size=SS):
    r = np.random.default_rng(seed)
    acc = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = max(2, int(scale * (2 ** o)))
        g = r.random((n, n)).astype(np.float32)
        im = Image.fromarray((np.tile(g, (3, 3)) * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
        acc += np.asarray(im).astype(np.float32)[size:size * 2, size:size * 2] / 255.0 * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def rounded_blocks(rows, seed, len_range, row_jitter=0.18, gap=0.0045, radius=0.012):
    """Coursed stones: rows of random height, blocks of random length. Returns (fill id map, edge distance)."""
    r = np.random.default_rng(seed)
    # row boundaries (wrap): heights vary +-row_jitter
    hs = np.array([1.0 + (r.random() - 0.5) * 2 * row_jitter for _ in range(rows)])
    ys = np.concatenate([[0], np.cumsum(hs / hs.sum())])
    img_id = Image.new("I", (SS, SS), 0)
    img_m = Image.new("L", (SS, SS), 0)
    di = ImageDraw.Draw(img_id)
    dm = ImageDraw.Draw(img_m)
    bid = 1
    blocks = []
    for k in range(rows):
        y0, y1 = ys[k], ys[k + 1]
        x = r.random()
        start = x
        while x < start + 1.0 - 1e-6:
            L = len_range[0] + r.random() * (len_range[1] - len_range[0])
            if start + 1.0 - (x + L) < len_range[0] * 0.6:
                L = start + 1.0 - x
            # slight per-stone wobble of the vertical joint and row edge
            blocks.append((x, y0, x + L, y1, bid, r.random()))
            bid += 1
            x += L
    g = gap * SS
    wob = radius * SS
    for (x0, y0, x1, y1, i, _) in blocks:
        # 不规则多边形：四角内收 + 每边中点轻微外鼓/内凹，之后模糊再阈值得到圆润边
        a0, b0, a1, b1 = x0 * SS + g, y0 * SS + g, x1 * SS - g, y1 * SS - g
        j = lambda: (r.random() - 0.5) * 2 * wob
        poly = [(a0 + abs(j()), b0 + abs(j())), ((a0 + a1) / 2 + j(), b0 + j() * 0.6), (a1 - abs(j()), b0 + abs(j())),
                (a1 + j() * 0.6, (b0 + b1) / 2 + j()), (a1 - abs(j()), b1 - abs(j())), ((a0 + a1) / 2 + j(), b1 + j() * 0.6),
                (a0 + abs(j()), b1 - abs(j())), (a0 + j() * 0.6, (b0 + b1) / 2 + j())]
        for ox in (-SS, 0, SS):
            for oy in (-SS, 0, SS):
                if a1 + ox < -10 or a0 + ox > SS + 10 or b1 + oy < -10 or b0 + oy > SS + 10:
                    continue
                pp = [(px + ox, py + oy) for (px, py) in poly]
                di.polygon(pp, fill=i)
                dm.polygon(pp, fill=255)
    ids = np.asarray(img_id).astype(np.int32)
    m0 = np.asarray(img_m.filter(ImageFilter.GaussianBlur(SS * 0.006))).astype(np.float32) / 255.0
    mask = np.clip((m0 - 0.5) * 6.0 + 0.5, 0, 1)   # 圆角：模糊后重新收紧边缘
    tone = np.zeros(bid + 1, np.float32)
    for (_, _, _, _, i, t) in blocks:
        tone[i] = t
    return ids, mask, tone


def save_grey(a, name):
    a = (a - a.mean()) + 0.5
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").resize((S, S), Image.LANCZOS)
    im.convert("RGB").save(os.path.join(OUT, name + ".png"))
    print("PAINTED", name, round(float(a.mean()), 3))


def stone_wall(name, rows, len_range, seed, joint=0.62, tone_amp=0.10):
    ids, mask, tone = rounded_blocks(rows, seed, len_range)
    yy = np.mgrid[0:SS, 0:SS][0].astype(np.float32)
    # 每块石头：平涂明度 + 很轻的低频笔触 + 上缘一道柔和提亮（手绘的"受光边"）
    face = 0.5 + (tone[ids] - 0.5) * tone_amp * 2.0
    face += (tnoise(5, 3, seed + 1) - 0.5) * 0.06
    edge_in = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(SS * 0.006))).astype(np.float32) / 255.0
    rim = np.clip(mask - edge_in, 0, 1)
    up = np.roll(mask, int(SS * 0.006), axis=0)       # 掩码下移 → 上缘为正
    top_hl = np.clip(mask - up, 0, 1)
    face += top_hl * 0.10 - rim * 0.06
    a = face * mask + joint * 0.5 * (1 - mask) + (tnoise(9, 2, seed + 2) - 0.5) * 0.04 * (1 - mask)
    save_grey(a, name)


# 修道院 / 城墙的方整石：6 层，每块 0.12–0.3 个贴图宽（4m 贴图 → 约 0.5–1.2m 长、0.67m 高）
stone_wall("pt_ashlar", 6, (0.13, 0.3), 301, tone_amp=0.06)
# 勒脚 / 毛石：更多层、更短更不规则
stone_wall("pt_rubble", 8, (0.08, 0.2), 302, joint=0.5, tone_amp=0.09)
print("ALL_PAINTED")
