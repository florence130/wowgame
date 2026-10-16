# 自检：布局派生场是否合理（轮廓方向、简化后顶点数、地形范围、阶梯高度）
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import fields as F, geo2d as G, layout as L

t = time.time()
S = F.build(1.0)
print("field", S["f"].shape, "%.1fs" % (time.time() - t))
loops = G.march(S["f"], S["xs"], S["ys"])
res = G.classify(loops)
print("loops", len(loops), "outer", len(res), "holes", sum(len(h) for o, h in res))
bad = 0
for l in loops:
    k = len(l) // 3
    p, q = l[k], l[k + 1]
    d = q - p
    n = np.array([-d[1], d[0]])
    n /= max(np.hypot(*n), 1e-9)
    m = (p + q) / 2 + n * 0.3
    bad += F.sample(S, m[0], m[1])[0] > 0
print("left-not-inside loops", bad, "/", len(loops))
simp = [G.simplify_loop(l, 0.35) for l in loops]
print("verts raw", sum(len(l) for l in loops), "simplified", sum(len(l) for l in simp))
T, meta = F.terrain_heights()
print("terrain", T.shape, float(T.min()), float(T.max()), meta)
print("s0 start y", F.height_at(*L.MAIN[0]["pts"][0]), "end y", F.height_at(*L.MAIN[0]["pts"][-1]))
print("open area m2", int((S["f"] < 0).sum()))

# 不同高度的空间在平面上不得重叠（重叠处高度查询会取错层）
px, py = S["px"], S["py"]
sd, hh = [], []
for e in F.ELEMS:
    d, h = F.elem_sdf_h(e, px, py)
    sd.append(d)
    hh.append(h)
conflicts = {}
for i in range(len(F.ELEMS)):
    for j in range(i + 1, len(F.ELEMS)):
        both = (sd[i] < 0.5) & (sd[j] < 0.5)
        if both.any():
            dh = np.abs(hh[i] - hh[j])[both].max()
            if dh > 0.6:
                conflicts[(F.ELEMS[i]["id"], F.ELEMS[j]["id"])] = (int(both.sum()), round(float(dh), 1))
print("height conflicts:", conflicts if conflicts else "none")

# 垂直净空：地下空间天花以上不得与上层空间重叠
for e in F.ELEMS:
    if e["style"] in F.UNDERGROUND:
        d, h = F.elem_sdf_h(e, px, py)
        m = d < 0
        for o in F.ELEMS:
            if o is e or o["style"] in F.UNDERGROUND:
                continue
            d2, h2 = F.elem_sdf_h(o, px, py)
            ov = m & (d2 < L.WALL_T)
            if ov.any() and (h2[ov] - h[ov]).max() > 0.5 and o["y0"] > e["y0"]:
                print("underground-over-overlap", e["id"], "under", o["id"], int(ov.sum()))
