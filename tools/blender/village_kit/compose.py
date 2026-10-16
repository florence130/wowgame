# 一栋房子的总装：outline → 墙 → 地板 / 天花 → 屋顶 → 门廊 / 老虎窗 / 烟囱 → 藤蔓灌木 → 内饰。
import math, random
from mathutils import Vector
from geo import Geo, T, Rz, Rx, Ry, S3, M_XZ, I
import house as hs
import stamp
from house import TW, FL, TN, OV, K, mats, footprint
import furn


def surface_z(parts, H, x, y):
    """屋面上某点的高度（各部件取最高）。"""
    best = -1.0
    for p in parts:
        x0, x1, y0, y1 = p["rect"]
        if not (x0 - 0.01 <= x <= x1 + 0.01 and y0 - 0.01 <= y <= y1 + 0.01):
            continue
        c = (y - (y0 + y1) / 2) if p["axis"] == "x" else (x - (x0 + x1) / 2)
        span = (y1 - y0) if p["axis"] == "x" else (x1 - x0)
        best = max(best, H + (span / 2 - abs(c)) * TN)
    return best


def build_house(sp, seed=1):
    rnd = random.Random(seed)
    st = mats(sp)
    G = Geo()
    out, parts, W, D = footprint(sp)
    H = sp["H"]
    rows = [(0.0, H)] if sp.get("rows", 1) == 1 else [(0.0, sp.get("row0", 3.3)), (sp.get("row0", 3.3), H)]
    Hc = sp.get("Hc", (H - 0.32) if sp.get("rows", 1) == 1 else rows[0][1])
    info = hs.build_walls(G, st, sp, out, rows, H, rnd)
    # 地板 / 天花
    for p in parts:
        x0, x1, y0, y1 = p["rect"]
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        G.box("S", hs.FLOORM, x1 - x0, y1 - y0, FL + 1.8, T(cx, cy, -1.8))
        G.box("S", K(0, "e9ddc4", "pt_plaster", 4.0), x1 - x0, y1 - y0, 0.14, T(cx, cy, Hc - 0.14))
    # 屋顶
    if sp.get("roof") == "pyramid":
        x0, x1, y0, y1 = parts[0]["rect"]
        hw = (x1 - x0) / 2 + OV
        zb = H - OV * TN
        pcx, pcy = (x0 + x1) / 2, (y0 + y1) / 2
        # 塔楼锥顶：构件库 T07（七层叠瓦的四坡锥）按塔身尺寸非等比放大 + T07 塔尖 / 旗
        k, kz = hw * stamp.SC / 2.758, hw * TN * stamp.SC / 4.2
        stamp.place(G, st, "tower", T(pcx, pcy, zb) @ S3(k / stamp.SC, k / stamp.SC, kz / stamp.SC), None, finial=False)
        stamp.place(G, st, "finial", T(pcx, pcy, zb + hw * TN - 0.08) @ S3(1.3 / stamp.SC, 1.3 / stamp.SC, 1.3 / stamp.SC), None, force="N")
        rinfo = [dict(zr=zb + hw * TN, span=x1 - x0, M0=T((x0 + x1) / 2, (y0 + y1) / 2, 0), ax="x", ye=0, cc=0, ac=0, Lr=x1 - x0)]
        # 石垛口：墙顶一圈小方墩
        for sx in (-1, 1):
            for sy in (-1, 1):
                G.box("S", st["STONE"], 0.8, 0.8, 0.6, T((x0 + x1) / 2 + sx * (x1 - x0) / 2, (y0 + y1) / 2 + sy * (y1 - y0) / 2, H - 0.1))
    else:
        rinfo = [hs.gable_roof(G, st, p, H, rnd, sp) for p in parts]
    zr_max = max(r["zr"] for r in rinfo)
    if getattr(G, "TF", None) is not None:
        G.TF.emit(G, st["TIMBER"])              # 木筋构架：布尔求并 + 倒角，一次写入（timber.py）
    # 门廊或门阶
    e0 = info[0]
    if sp.get("door_bay") is not None or True:
        dx = e0["door_x"]
        hs.door_unit(G, st, e0["Me"], dx, *((3.4, 3.2) if sp.get("barn_door") else (1.5, 2.4)))
        if sp.get("porch", False):
            hs.porch(G, st, e0["Me"], dx, rnd)
        else:
            hs.doorstep(G, st, e0["Me"], dx)
    # 老虎窗（第 0 个部件前坡）
    bar = parts[0]
    for xl in sp.get("dormers", []):
        r0 = rinfo[0]
        span = r0["span"]
        yl = -span * 0.2
        zs = H + (yl + span / 2) * TN
        if bar["axis"] == "x":
            hs.dormer(G, st, r0["M0"] @ T(xl, yl, zs))
    # 烟囱
    for c in sp.get("chim", []):
        x, y = c[0], c[1]
        zs = surface_z(parts, H, x, y)
        hs.chimney(G, st, x, y, H - 1.0, zs + 1.2)
    # 外立面修饰
    hs.build_exterior_dressing(G, st, sp, info, out, H, rnd, rinfo, W, D)
    ext_x = None
    if sp.get("smith"):
        import smith
        ext_x = smith.exterior(G, st, sp, info, parts, H, zr_max)
    ctx = dict(parts=parts, FL=FL, Hc=Hc, H=H, TW=TW, out=out, info=info, st=st, door_x=e0["door_x"], W=W, D=D, rnd=rnd, zr=zr_max)
    furn.furnish(G, sp, ctx)
    xs = [p[0] for p in out]
    ys = [p[1] for p in out]
    meta = dict(id=sp["id"], w=round(max(xs) - min(xs), 2), d=round(max(ys) - min(ys), 2), h=round(zr_max + 1.2, 2),
                # 门点记录在真正门洞前沿；门廊是装饰 / 可通行平台，不应把测试与 NPC 站位推到平台外缘。
                # 旧值把有门廊的门点向外推 2.2m，home_wing 的 L 形门廊因此会挡住实际入口。
                door=[round(e0["door_x"] + e0["a"].x, 2), round(-(e0["a"].y - TW / 2 - (0.25 if sp.get("porch") else 0.9)), 2)],
                bbox=[round(min(xs), 2), round(min(ys), 2), round(max(xs), 2), round(max(ys), 2)])
    ix0, ix1, iy0, iy1 = furn.inner(parts[0], 0.5)
    meta["inner"] = [round(ix0, 2), round(ix1, 2), round(-iy1, 2), round(-iy0, 2)]       # 主室内部范围（glTF x / z），NPC 站位用
    meta["porch"] = bool(sp.get("porch", False))
    if ext_x:
        meta["ext"] = [round(ext_x[0], 2), round(ext_x[1], 2)]                  # 敞棚 / 烟囱使占地向两侧外扩（相对主体中心的 x 范围），gen_vale 压平地面用
    meta["fp"] = [round(min(p[0] for p in out), 2), round(min(p[1] for p in out), 2), round(max(p[0] for p in out), 2), round(max(p[1] for p in out), 2)]       # 主体占地（不含敞棚 / 烟囱）
    meta["lights"] = [[round(x, 2), round(z, 2), round(-y, 2), round(rg, 1), round(en, 2)] for (x, y, z, rg, en) in G.lights]
    meta["smoke"] = [[round(x, 2), round(z, 2), round(-y, 2)] for (x, y, z) in G.smoke]
    if "npcs" in G.marks:
        meta["npcs"] = {k: [round(v[0], 2), round(-v[1], 2)] for k, v in G.marks["npcs"].items()}
    return G, meta
