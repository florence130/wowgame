# 画晴岚港 v4 布局草案（docs/world_v4/city_plan.json → docs/world_v4/city_plan.png），供用户审核。
# py tools/draw_city_plan.py
import json, math
from PIL import Image, ImageDraw, ImageFont

P = json.load(open("docs/world_v4/city_plan.json", encoding="utf-8"))
x0, z0, x1, z1 = P["bounds"]
S = 1.15         # 像素 / 米
M = 30
LEG = 430        # 右侧图例宽
TOP = 56
W, H = int((x1 - x0) * S) + 2 * M + LEG, int((z1 - z0) * S) + 2 * M + TOP
im = Image.new("RGB", (W, H), (240, 236, 224))
d = ImageDraw.Draw(im, "RGBA")
F = ImageFont.truetype("msyh.ttc", 14)
FS = ImageFont.truetype("msyh.ttc", 13)
FB = ImageFont.truetype("msyhbd.ttc", 19)
FA = ImageFont.truetype("msyhbd.ttc", 15)
FT = ImageFont.truetype("msyhbd.ttc", 24)


def pt(p):
    return (M + (p[0] - x0) * S, M + TOP + (p[1] - z0) * S)


def poly(pts, **kw):
    d.polygon([pt(p) for p in pts], **kw)


def line(pts, w, col):
    d.line([pt(p) for p in pts], fill=col, width=int(w), joint="curve")


def circle(c, r, **kw):
    a, b = pt((c[0] - r, c[1] - r)), pt((c[0] + r, c[1] + r))
    d.ellipse([a, b], **kw)


SEA = (92, 150, 196)
d.rectangle([pt((x0, z0)), pt((x1, z1))], fill=(176, 198, 134))
poly([(x0, z0)] + P["coast"] + [(P["coast"][-1][0], z1), (x0, z1)], fill=SEA)
east = P["coast_east"]
poly([(east[0][0], z1)] + east + [(x1, z1)], fill=SEA)
poly([(-560, 1060), (-120, 1050), (-120, z1), (-560, z1)], fill=SEA)
circle(P["bay"]["c"], P["bay"]["r"], fill=SEA)

# 分区色块（城内不透明度高一些）
for dist in P["districts"]:
    c = tuple(dist["color"]) + ((150,) if dist.get("outside") else (200,))
    poly(dist["poly"], fill=c, outline=(90, 80, 70, 160))
# 水面压在分区上
circle(P["harbor"]["c"], P["harbor"]["r"], fill=SEA)
line([P["harbor"]["c"]] + P["harbor"]["channel"] + [[-440, 900]], 34 * S, SEA)
line(P["river"], 18 * S, SEA)
# 旧城轮廓
line(P["old_city"] + [P["old_city"][0]], 2, (200, 50, 50, 220))
# 主干道（金色描边 + 白芯）
for av in P["avenues"]:
    line(av["pts"], av["w"] * S + 4, (150, 110, 40))
    line(av["pts"], av["w"] * S, (252, 244, 220))
# 广场
for sq in P["squares"]:
    circle(sq["c"], sq["r"], fill=(250, 244, 226), outline=(150, 110, 40), width=2)
# 城墙 + 塔
line(P["wall"], 8, (246, 242, 234))
line(P["wall"], 2, (100, 90, 80))
for i in range(len(P["wall"]) - 1):
    a, b = P["wall"][i], P["wall"][i + 1]
    n = max(1, int(math.dist(a, b) / 70))
    for k in range(n + 1):
        t = k / n
        circle((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), 7, fill=(246, 242, 234), outline=(100, 90, 80), width=2)
for name, g in P["gates"].items():
    circle(g, 13, fill=(214, 168, 70), outline=(90, 70, 40), width=2)
    x, y = pt(g)
    d.text((x + 14, y - 22), name, fill=(80, 50, 10), font=FA, stroke_width=3, stroke_fill=(250, 248, 240))
line([(-700, 1095), (-570, 1120)], 9, (224, 218, 204))

# 设施：编号圆点（新增 = 红，保留 = 深蓝），图例在右侧
num = {}
for i, f in enumerate(P["facilities"]):
    x, y = pt(f["p"])
    col = (200, 40, 40) if f.get("new") else (40, 60, 120)
    d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=col, outline=(255, 255, 255), width=2)
    t = str(i + 1)
    tw = d.textlength(t, font=FS)
    d.text((x - tw / 2, y - 9), t, fill=(255, 255, 255), font=FS)
# 主干道名称（沿线中点）
for av in P["avenues"]:
    pts = av["pts"]
    mid = pts[av.get("label_i", max(1, len(pts) // 3))]
    x, y = pt(mid)
    d.text((x + 8, y - 10), av["cn"], fill=(120, 70, 10), font=FA, stroke_width=3, stroke_fill=(255, 250, 235))
# 分区名
for dist in P["districts"]:
    xs = [p[0] for p in dist["poly"]]; zs = [p[1] for p in dist["poly"]]
    c = (sum(xs) / len(xs), sum(zs) / len(zs))
    x, y = pt(c)
    d.text((x - 40, y - 34), dist["cn"], fill=(25, 30, 60), font=FB, stroke_width=3, stroke_fill=(250, 248, 240))
d.text(pt((-300, 1130)), "大海湾", fill=(255, 255, 255), font=FT)
d.text(pt((-995, 650)), "外海", fill=(255, 255, 255), font=FT)
sx, sy = pt((x1 - 260, z1 - 25))
d.line([sx, sy, sx + 200 * S, sy], fill=(0, 0, 0), width=3)
d.text((sx, sy + 4), "200 m", fill=(0, 0, 0), font=F)
d.text((M, 14), "晴岚港 v4 布局草案 · 第二版（约 1.2 × 1.0 km，北在上）  红线 = 现城区   金线 = 主干道   红点 = 新增设施   蓝点 = 保留设施", fill=(20, 20, 20), font=FB)

# 右侧图例：按分区列设施
lx = W - LEG + 10
ly = TOP + M
for dist in P["districts"]:
    items = [(i, f) for i, f in enumerate(P["facilities"]) if f["d"] == dist["id"]]
    if not items:
        continue
    d.rectangle([lx, ly + 3, lx + 14, ly + 17], fill=tuple(dist["color"]), outline=(80, 80, 80))
    d.text((lx + 20, ly), dist["cn"] + "  " + dist["sub"], fill=(20, 20, 40), font=FA)
    ly += 22
    for i, f in items:
        col = (200, 40, 40) if f.get("new") else (40, 60, 120)
        d.text((lx + 10, ly), "%2d  %s%s" % (i + 1, f["cn"], "  [新]" if f.get("new") else ""), fill=col, font=FS)
        ly += 17
    ly += 6
ly += 4
d.text((lx, ly), "主干道", fill=(20, 20, 40), font=FA)
ly += 22
for av in P["avenues"]:
    d.text((lx + 10, ly), "%s：%s" % (av["cn"], av["note"]), fill=(110, 70, 10), font=FS)
    ly += 17
im.save("docs/world_v4/city_plan.png")
print("PLAN", W, H, "facilities", len(P["facilities"]))
