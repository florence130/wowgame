# 海神旧圣堂 v2 —— 玩法数据（小怪组 / 首领 / 门 / 灯 / 宝箱），全部由 layout + fields 推出，导出给 Godot。
import math
import numpy as np
import layout as L
import fields as F

FLAG_ROOT, FLAG_LAKE, FLAG_NAVE = "sanctum_ember_root", "sanctum_ember_lake", "sanctum_ember_nave"
FLAG_FINAL = "sanctum_final_open"

# 每段的小怪组（每组 3 只）。藤蔓魔物 = 植物，鼠人 = 蛮族；两者在下层混居。
R_ = ["d_bandit", "d_bandit_gunner", "d_bandit_mage"]
PULL_MOBS = {
    "s0": [["d_bandit", "d_bandit", "d_bandit_mage"]],
    "s1": [R_, ["d_bandit", "d_bandit", "d_bandit_gunner"]],
    "s2": [["d_vine", "d_vine", "d_treant"]],
    "s3": [["d_treant", "d_vine", "d_sapling"]],
    "s5": [R_, ["d_bandit", "d_bandit", "d_bandit_gunner"]],
    "s6": [["d_bandit_mage", "d_gargoyle", "d_gargoyle"], ["d_bandit", "d_bandit_gunner", "d_vine"]],
    "s7": [R_, ["d_bandit", "d_bandit", "d_bandit_mage"]],
    "s9": [["d_treant", "d_treant", "d_vine"]],
    "s10": [["d_gargoyle", "d_gargoyle", "d_vine"]],
    "s11": [["d_gargoyle", "d_vine", "d_vine"], ["d_treant", "d_gargoyle", "d_gargoyle"]],
    "s12": [["d_gargoyle", "d_gargoyle", "d_treant"]],
}
# 段 → 需要的旗标（打完前一个首领才开）
SEG_FLAGS = {}
for sid in ("s4", "s5", "s6", "b2"):
    SEG_FLAGS[sid] = [FLAG_ROOT]
for sid in ("s7", "s8", "s9", "s10", "b3"):
    SEG_FLAGS[sid] = [FLAG_ROOT, FLAG_LAKE]
for sid in ("s11", "s12", "b4"):
    SEG_FLAGS[sid] = [FLAG_ROOT, FLAG_LAKE, FLAG_NAVE]

BOSS_MOB = {1: "boss_rootguard", 2: "boss_lake", 3: "boss_sanctum_lantern", 4: "boss_victor"}
BOSS_FLAG = {1: FLAG_ROOT, 2: FLAG_LAKE, 3: FLAG_NAVE, 4: ""}
# 首领打完后开哪扇门：旗标 → 门位于「下一段」起点后的距离
GATES = [(1, "s4", FLAG_ROOT, "旧下行石阶"), (2, "s7", FLAG_LAKE, "码头洞闸门"), (3, "s11", FLAG_FINAL, "崖壁栈道封门")]


def _seg(sid):
    return next(s for s in L.MAIN if s["id"] == sid)


def _room_for_boss(n):
    return next(r for r in L.ROOMS if r.get("boss") == n)


def _along(sid, dist):
    """沿某段从起点走 dist 米：返回 (x, y, h, yaw)"""
    e = next(e for e in F.ELEMS if e["id"] == sid)
    return F.path_point(sid, min(dist / e["total"], 1.0))


def build():
    d = {"extent": list(L.EXTENT), "level_y": L.LEVEL_Y, "segments": [], "pulls": [], "bosses": [], "gates": [],
         "side": [], "lamps": [], "rooms": [], "pois": []}
    for r in L.ROOMS:
        d["rooms"].append(dict(id=r["id"], name=r["name"], c=r["c"], style=r["style"], boss=r["boss"],
                               **({"r": r["r"]} if "r" in r else {"size": r["size"]}), y=L.LEVEL_Y[r["level"]]))
    n = 0
    for s in L.MAIN:
        e = next(e for e in F.ELEMS if e["id"] == s["id"])
        d["segments"].append(dict(id=s["id"], name=s["name"], style=e["style"], length=round(e["total"], 1), flags=SEG_FLAGS.get(s["id"], [])))
        groups = PULL_MOBS.get(s["id"], [])
        for i, mobs in enumerate(groups):
            t = (i + 0.5) / len(groups)
            x, y, h, yaw = F.path_point(s["id"], t)
            n += 1
            d["pulls"].append(dict(id="pull_%02d" % n, seg=s["id"], x=round(x, 2), z=round(y, 2), y=round(h, 2), yaw=round(yaw, 3),
                                   mobs=mobs, flags=SEG_FLAGS.get(s["id"], [])))
        # 路灯：每 ~16 米一盏（给 Godot 挂灯具 / 光源）
        for k in range(int(e["total"] // 16)):
            x, y, h, yaw = F.path_point(s["id"], (k + 0.5) / max(int(e["total"] // 16), 1))
            d["lamps"].append(dict(seg=s["id"], x=round(x, 2), z=round(y, 2), y=round(h, 2), yaw=round(yaw, 3), style=e["style"]))
        d["pois"].append(dict(id=("poi_sanctum_in" if s["id"] == "s0" else "poi_sanctum_" + s["id"]), name=s["name"], x=round(F.path_point(s["id"], 0.5)[0], 1),
                              z=round(F.path_point(s["id"], 0.5)[1], 1), r=max(e["total"] / 2 + 8, 18)))
    for b in (1, 2, 3, 4):
        r = _room_for_boss(b)
        y = L.LEVEL_Y[r["level"]]
        d["bosses"].append(dict(number=b, mob=BOSS_MOB[b], flag=BOSS_FLAG[b], x=r["c"][0], z=r["c"][1], y=y, r=r.get("r", 22),
                                name=r["name"], flags=SEG_FLAGS.get("b%d" % b, [])))
    for b, nxt, flag, title in GATES:
        r = _room_for_boss(b)
        R = r["r"] if "r" in r else 24
        # 门在下一段里、离首领场地边缘约 4 米的位置
        e = next(e for e in F.ELEMS if e["id"] == nxt)
        for k in range(1, 120):
            x, y, h, yaw = F.path_point(nxt, k / 120.0)
            if np.hypot(x - r["c"][0], y - r["c"][1]) >= R + 4:
                break
        d["gates"].append(dict(flag=flag, title=title, x=round(x, 2), z=round(y, 2), y=round(h, 2), yaw=round(yaw, 3), width=L.CORR - 0.4, boss=b))
    for s in L.SIDE:
        d["side"].append(dict(id=s["id"], name=s["name"], use=s["use"], x=s["c"][0], z=s["c"][1], y=L.LEVEL_Y[s["level"]], size=list(s["size"])))
    sx, sy, sh, syaw = F.path_point("s0", 0.0)
    d["start"] = dict(x=round(sx, 2), z=round(sy, 2), y=round(sh, 2), yaw=round(syaw, 3))
    return d


def stats(d):
    return "pulls %d, mobs %d, bosses %d, gates %d, lamps %d" % (len(d["pulls"]), sum(len(p["mobs"]) for p in d["pulls"]), len(d["bosses"]), len(d["gates"]), len(d["lamps"]))


def scatter_trees(T, meta, seed=11):
    """在岛屿高处（空间外 4m 以上、距岸线 ≥3m）泊松取样放柏树 / 岩石 / 灌木。返回 {kind: [[x, z], ...]}"""
    rng = np.random.RandomState(seed)
    org, cs, res = meta["origin"], meta["cell_size"], meta["resolution"]

    def th(x, z):
        i = int(round((x - org[0]) / cs)); j = int(round((z - org[1]) / cs))
        return float(T[min(max(j, 0), res), min(max(i, 0), res)])

    out = {"pine": [], "rock": [], "bush": []}
    spec = {"pine": (3.3, 7.0), "rock": (4.0, 3.2), "bush": (2.0, 3.5)}
    for kind, (count_scale, mind) in spec.items():
        pts = []
        tries = 0
        target = {"pine": 150, "rock": 120, "bush": 200}[kind]
        while len(pts) < target and tries < 30000:
            tries += 1
            x = rng.uniform(org[0] + 8, org[0] + res * cs - 8)
            z = rng.uniform(org[1] + 8, org[1] + res * cs - 8)
            h = th(x, z)
            if h < 3.0:
                continue
            sd = float(min_sdf1(x, z))
            if sd < L.WALL_T + 4.5:
                continue
            if any((x - p[0]) ** 2 + (z - p[1]) ** 2 < mind * mind for p in pts):
                continue
            pts.append((round(x, 1), round(z, 1)))
        out[kind] = pts
    return out


def min_sdf1(x, z):
    return F.min_sdf(np.array([[x]], dtype=float), np.array([[z]], dtype=float))[0, 0]