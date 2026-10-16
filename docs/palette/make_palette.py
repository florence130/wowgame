# Render docs/palette/palette.json into palette.png (swatch board for GPT colour picking) and palette.md.
# Usage: python docs/palette/make_palette.py
import json, os
from PIL import Image, ImageDraw, ImageFont

D = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(D, "palette.json"), encoding="utf-8"))


def font(sz):
    for f in ["msyh.ttc", "C:/Windows/Fonts/msyh.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
              "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", "NotoSansCJK-Regular.ttc"]:
        try:
            return ImageFont.truetype(f, sz)
        except Exception:
            pass
    return ImageFont.load_default()


def lum(h):
    r, g, b = (int(h[i:i + 2], 16) for i in (1, 3, 5))
    return 0.299 * r + 0.587 * g + 0.114 * b


SW, SH, COLS, PAD = 190, 120, 8, 14
f_title, f_grp, f_name, f_hex = font(40), font(28), font(19), font(17)
rows = 0
for g in P["groups"]:
    rows += (len(g["colors"]) + COLS - 1) // COLS
H = 110 + len(P["groups"]) * 52 + rows * (SH + PAD) + 20
W = COLS * (SW + PAD) + PAD * 3
img = Image.new("RGB", (W, H), "#f7f4ec")
dr = ImageDraw.Draw(img)
dr.text((PAD * 2, 24), P["name"], fill="#2a1d12", font=f_title)
y = 100
for g in P["groups"]:
    dr.text((PAD * 2, y), g["cn"] + "  " + g["id"], fill="#3a2412", font=f_grp)
    y += 46
    for i, (key, cn, hx) in enumerate(g["colors"]):
        x = PAD * 2 + (i % COLS) * (SW + PAD)
        if i and i % COLS == 0:
            y += SH + PAD
        dr.rounded_rectangle((x, y, x + SW, y + SH), 10, fill=hx, outline="#d8d0c0")
        tc = "#1e1a14" if lum(hx) > 140 else "#f7f4ec"
        dr.text((x + 10, y + SH - 56), cn, fill=tc, font=f_name)
        dr.text((x + 10, y + SH - 30), hx.upper() + "  " + key, fill=tc, font=f_hex)
    y += SH + PAD + 6
img.save(os.path.join(D, "palette.png"))

md = ["# " + P["name"], "", P["basis"], "", "## 使用规则", ""] + ["- " + r for r in P["rules"]] + [""]
for g in P["groups"]:
    md += ["## " + g["cn"] + " (" + g["id"] + ")", "", "| 键 | 名称 | HEX |", "|---|---|---|"]
    md += ["| %s | %s | `%s` |" % (k, c, h) for k, c, h in g["colors"]]
    md.append("")
open(os.path.join(D, "palette.md"), "w", encoding="utf-8").write("\n".join(md))
print("palette.png", img.size)
