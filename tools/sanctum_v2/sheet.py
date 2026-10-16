# 把一个目录里的截图拼成带标签的总览图；并读取 report.json 报告异常。
#   py -I tools/sanctum_v2/sheet.py <截图目录> <输出png> [列数] [名称前缀过滤]
import os, sys, json
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
pre = sys.argv[4] if len(sys.argv) > 4 else ""
names = sorted(f for f in os.listdir(src) if f.endswith(".png") and f.startswith(pre))
W, H = 480, 270
rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGB", (cols * W, rows * (H + 22)), (30, 30, 34))
d = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)
for i, n in enumerate(names):
    im = Image.open(os.path.join(src, n)).convert("RGB").resize((W, H))
    x, y = (i % cols) * W, (i // cols) * (H + 22)
    sheet.paste(im, (x, y + 22))
    d.text((x + 6, y + 3), n[:-4], font=font, fill=(240, 230, 200))
sheet.save(out, quality=88)
print(out, len(names), "images")

rp = os.path.join(src, "report.json")
if os.path.exists(rp):
    rep = json.load(open(rp, encoding="utf-8"))
    bad = []
    for r in rep:
        issues = []
        if r["floor_y"] is None:
            issues.append("无地面碰撞")
        elif abs(r["floor_y"] - r["player_y"]) > 0.6:
            issues.append("站位与地面差 %.2f" % (r["player_y"] - r["floor_y"]))
        if r["cam"] is not None and r["cam"] < 6 and not r["view"].startswith(("look_up", "nave_low", "side_")):
            issues.append("镜头被压到 %.1fm" % r["cam"])
        if issues:
            bad.append((r["view"], issues))
    print("views", len(rep), "problems", len(bad))
    for v, i in bad:
        print("  ", v, i)
