# 海神旧圣堂 v2 —— 2D 几何核心（纯 numpy，不依赖 Blender）。
# 走廊 / 房间 → 有向距离场(SDF) → 行进方格取等值线(轮廓) → RDP 简化。
import math
import numpy as np


def seg_dist(px, py, a, b):
    abx, aby = b[0] - a[0], b[1] - a[1]
    t = ((px - a[0]) * abx + (py - a[1]) * aby) / max(abx * abx + aby * aby, 1e-9)
    t = np.clip(t, 0.0, 1.0)
    return np.hypot(px - (a[0] + t * abx), py - (a[1] + t * aby))


def polyline_sdf(px, py, pts, half):
    d = None
    for a, b in zip(pts, pts[1:]):
        di = seg_dist(px, py, a, b) - half
        d = di if d is None else np.minimum(d, di)
    return d


def rect_sdf(px, py, c, size, rr=3.0):
    hx, hy = size[0] / 2 - rr, size[1] / 2 - rr
    qx, qy = np.abs(px - c[0]) - hx, np.abs(py - c[1]) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rr


def circle_sdf(px, py, c, r):
    return np.hypot(px - c[0], py - c[1]) - r


def make_grid(x0, y0, x1, y1, cs):
    xs = np.arange(x0, x1 + cs, cs)
    ys = np.arange(y0, y1 + cs, cs)
    px, py = np.meshgrid(xs, ys)
    return xs, ys, px, py


def march(f, xs, ys):
    """f[j,i] < 0 为内部。返回闭合轮廓列表，每个 (N,2) 数组，内部在轮廓左侧（逆时针外轮廓）。"""
    ny, nx = f.shape
    ins = f < 0
    edges = {}  # edge-id -> position

    def ep(kind, i, j):
        k = (kind, i, j)
        if k not in edges:
            if kind == 0:  # 水平边 (i,j)-(i+1,j)
                a, b = f[j, i], f[j, i + 1]
                t = a / (a - b)
                edges[k] = (xs[i] + t * (xs[i + 1] - xs[i]), ys[j])
            else:          # 竖直边 (i,j)-(i,j+1)
                a, b = f[j, i], f[j + 1, i]
                t = a / (a - b)
                edges[k] = (xs[i], ys[j] + t * (ys[j + 1] - ys[j]))
        return k

    nxt = {}
    for j in range(ny - 1):
        for i in range(nx - 1):
            a, b, c, d = ins[j, i], ins[j, i + 1], ins[j + 1, i + 1], ins[j + 1, i]
            code = a | (b << 1) | (c << 2) | (d << 3)
            if code in (0, 15):
                continue
            B, R, T, L = (0, i, j), (1, i + 1, j), (0, i, j + 1), (1, i, j)
            # 每条线段 (from, to)：内部在行进方向左侧
            segs = {
                1: [(L, B)], 2: [(B, R)], 3: [(L, R)], 4: [(R, T)], 6: [(B, T)], 7: [(L, T)],
                8: [(T, L)], 9: [(T, B)], 11: [(T, R)], 12: [(R, L)], 13: [(R, B)], 14: [(B, L)],
            }.get(code)
            if code == 5 or code == 10:
                center = (f[j, i] + f[j, i + 1] + f[j + 1, i + 1] + f[j + 1, i]) / 4.0
                if code == 5:   # a,c 内部
                    segs = [(L, T), (R, B)] if center < 0 else [(L, B), (R, T)]
                else:           # b,d 内部
                    segs = [(B, L), (T, R)] if center < 0 else [(B, R), (T, L)]
            for p, q in segs:
                nxt[ep(*p)] = ep(*q)
    loops, seen = [], set()
    for start in list(nxt):
        if start in seen:
            continue
        loop, cur = [], start
        while cur not in seen and cur in nxt:
            seen.add(cur)
            loop.append(edges[cur])
            cur = nxt[cur]
        if len(loop) >= 4:
            # 行进时内部落在右侧；翻转后内部在左侧（外轮廓逆时针，面积 > 0）
            loops.append(np.array(loop)[::-1].copy())
    return loops


def area(poly):
    x, y = poly[:, 0], poly[:, 1]
    return 0.5 * float(np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y))


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    d = seg_dist(pts[:, 0], pts[:, 1], a, b)
    k = int(np.argmax(d))
    if d[k] > eps:
        l, r = rdp(pts[:k + 1], eps), rdp(pts[k:], eps)
        return np.vstack([l[:-1], r])
    return np.array([a, b])


def simplify_loop(poly, eps):
    n = len(poly)
    if n < 8:
        return poly
    k = int(np.argmax(np.hypot(poly[:, 0] - poly[0, 0], poly[:, 1] - poly[0, 1])))
    a = rdp(np.vstack([poly[:k + 1]]), eps)
    b = rdp(np.vstack([poly[k:], poly[:1]]), eps)
    return np.vstack([a[:-1], b[:-1]])


def point_in_poly(p, poly):
    x, y, c = p[0], p[1], False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi, xj, yj = poly[i][0], poly[i][1], poly[j][0], poly[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c


def classify(loops):
    """外轮廓(逆时针, 面积>0)与洞(顺时针)；返回 [(outer, [holes])]"""
    outers = [l for l in loops if area(l) > 0]
    holes = [l for l in loops if area(l) <= 0]
    res = [(o, []) for o in outers]
    for h in holes:
        for o, hs in res:
            if point_in_poly(h[0], o):
                hs.append(h)
                break
    return res
