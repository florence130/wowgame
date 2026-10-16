# 画海神旧圣堂 v2 平面路线图 + 估算时长 → docs/sanctum_v2/plan_v2.png
#   py -I tools/sanctum_v2/draw_plan.py
import os, sys, math
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "docs", "sanctum_v2", "plan_v2.png")
K = 2.4            # 像素 / 米
PAD = 30
PANEL = 430
RUN = 7.0          # 玩家跑速 m/s (src/actors/player.gd RUN_SPEED)
# 战斗时长估算：熟练队 = 两组串拉一起打（2 组约 50s），首领 120s；首通 = 单组 45s，首领 240s
SK_PAIR_S, SK_BOSS_S = 50, 120
FC_PULL_S, FC_BOSS_S, FC_SLOW = 45, 240, 0.75   # 首通跑路按 75% 效率
LV = {"S": ((214, 202, 170), "地表"), "U": ((150, 170, 196), "地下"), "H": ((196, 214, 160), "高处")}
CORR = L.CORR

F = lambda s: ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", s)
W, H = int(L.EXTENT[0] * K) + PAD * 2, int(L.EXTENT[1] * K) + PAD * 2
img = Image.new("RGB", (W + PANEL, H), (236, 226, 196))
d = ImageDraw.Draw(img)
P = lambda p: (PAD + p[0] * K, PAD + p[1] * K)


def seglen(pts):
    return sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))


def walk(pts, t):
    """沿折线走到总长比例 t 的点"""
    tot, acc = seglen(pts), 0
    for a, b in zip(pts, pts[1:]):
        l = math.dist(a, b)
        if acc + l >= t * tot:
            u = (t * tot - acc) / l if l else 0
            return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)
        acc += l
    return pts[-1]


def poly(pts, col, w):
    pp = [P(p) for p in pts]
    d.line(pp, fill=col, width=int(w * K), joint="curve")
    for p in pp:
        r = w * K / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col)


def room(r, col, out=(120, 100, 70)):
    x, y = P(r["c"])
    if "r" in r:
        s = r["r"] * K
        d.ellipse([x - s, y - s, x + s, y + s], fill=col, outline=out, width=3)
    else:
        w, h = r["size"][0] * K / 2, r["size"][1] * K / 2
        d.rounded_rectangle([x - w, y - h, x + w, y + h], 8, fill=col, outline=out, width=3)


# 1 通道底色（深边）+ 房间
for s in L.SIDE:
    poly(s["pts"], (120, 100, 70), L.SIDE_CORR + 1.5)
for s in L.MAIN:
    poly(s["pts"], (120, 100, 70), CORR + 1.5)
for s in L.SIDE:
    poly(s["pts"], LV[s["level"]][0], L.SIDE_CORR)
    room(s, tuple(int(c * 0.93) for c in LV[s["level"]][0]))
for s in L.MAIN:
    poly(s["pts"], LV[s["level"]][0], CORR)
for r in L.ROOMS:
    room(r, LV[r["level"]][0])

# 2 小怪组 / 首领 / 门 / 名称
n_pull, t_walk = 0, 0.0
for s in L.MAIN:
    t_walk += seglen(s["pts"]) / RUN
    for i in range(s["pulls"]):
        x, y = P(walk(s["pts"], (i + 0.5) / s["pulls"]))
        n_pull += 1
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(196, 70, 50), outline=(90, 30, 20), width=2)
        d.text((x, y), str(n_pull), font=F(10), fill="white", anchor="mm")
for r in L.ROOMS:
    x, y = P(r["c"])
    if r.get("boss"):
        d.regular_polygon((x, y, 15), 6, fill=(150, 40, 40), outline=(60, 10, 10))
        d.text((x, y), "B%d" % r["boss"], font=F(13), fill="white", anchor="mm")
        d.text((x, y + 26), r["name"], font=F(15), fill=(60, 30, 20), anchor="mm")
    else:
        d.text((x, y), r["name"], font=F(15), fill=(60, 40, 20), anchor="mm")
for s in L.SIDE:
    x, y = P(s["c"])
    tag = {"empty": "空", "chest": "箱", "bed": "床", "shrine": "祭坛"}[s["use"]]
    d.text((x, y), s["name"] + "\n[" + tag + "]", font=F(12), fill=(60, 40, 20), anchor="mm", align="center")
# 首领打完开门：标在每个首领场地出口
for i, s in enumerate(L.MAIN):
    if s.get("boss") and i + 1 < len(L.MAIN):
        x, y = P(L.MAIN[i + 1]["pts"][0])
        d.rectangle([x - 6, y - 6, x + 6, y + 6], fill=(230, 180, 40), outline=(90, 60, 0), width=2)
# 入口
x, y = P(L.MAIN[0]["pts"][0])
d.text((x, y + 18), "入口", font=F(16), fill=(30, 90, 40), anchor="mm")
d.text((W / 2, H - 14), "海（南）", font=F(14), fill=(60, 110, 150), anchor="mm")

# 3 统计
main_len = sum(seglen(s["pts"]) for s in L.MAIN)
side_len = sum(seglen(s["pts"]) * 2 for s in L.SIDE)
n_boss = sum(1 for s in L.MAIN if s.get("boss"))
t_sk = t_walk + math.ceil(n_pull / 2) * SK_PAIR_S + n_boss * SK_BOSS_S
t_fc = t_walk / FC_SLOW + n_pull * FC_PULL_S + n_boss * FC_BOSS_S + side_len / RUN
lines = [
    "海神旧圣堂 v2  平面路线（定稿候选）",
    "",
    "主路线长度  %.0f m" % main_len,
    "侧室往返    %.0f m（%d 间，均为单入口）" % (side_len, len(L.SIDE)),
    "小怪组      %d 组（红点编号，3 只/组）" % n_pull,
    "首领        %d 个" % n_boss,
    "",
    "估算时长",
    "  纯跑路          %.1f 分" % (t_walk / 60),
    "  熟练队（双拉）  %.0f 分" % (t_sk / 60),
    "    = 跑路 + %d 次双拉×%ds + 首领×%ds" % (math.ceil(n_pull / 2), SK_PAIR_S, SK_BOSS_S),
    "  首通（单拉+侧室）%.0f 分" % (t_fc / 60),
    "","颜色：米黄=地表  灰蓝=地下  绿=高处",
    "红六边形=首领  黄方块=首领后开的门",
    "通道宽 %gm（侧室 %gm），首领场地直径 %gm" % (L.CORR, L.SIDE_CORR, L.BOSS_R * 2),
    "",
    "流程：",
]
for s in L.MAIN:
    lines.append(("  【首领】" if s.get("boss") else "    ") + s["name"] + ("" if not s["pulls"] else "  ×%d" % s["pulls"]))
d.rectangle([W, 0, W + PANEL, H], fill=(246, 240, 222))
d.multiline_text((W + 18, 18), "\n".join(lines), font=F(15), fill=(50, 40, 30), spacing=5)
img.save(OUT)
print(OUT, "main %.0fm side %.0fm pulls %d boss %d walk %.1fmin skilled %.1fmin first %.1fmin" % (
    main_len, side_len, n_pull, n_boss, t_walk / 60, t_sk / 60, t_fc / 60))
