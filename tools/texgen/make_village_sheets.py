# 把 tools/blender/village_kit/sheets.py 渲出的单件图拼成编号总图（白底网格，只有数字编号）：
#   village_tripo_parts_sheet.png   —— 交给 Tripo 生成的「复杂构件」（造型细碎 / 有雕刻 / 曲面）
#   village_furniture_sheet.png     —— 交给 Tripo 生成的家具与室内小物
#   village_blender_parts_sheet.png —— 我在 Blender 里自己做的「简单构件」（外墙板、屋面板、山墙、墙基…），只作说明，不用拿去 Tripo
# 并把 Tripo 用的每件裁成 1024 白底方图放 single/（想一件一件喂 Tripo 时用）。
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
D = os.path.join(ROOT, "docs", "village_kit", "tripo")
ITEMS = os.path.join(D, "items")
SINGLE = os.path.join(D, "single")
os.makedirs(SINGLE, exist_ok=True)
BG = (246, 246, 243)
FONT = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 64)

# Tripo 复杂构件（新编号 T1..T13 ← 渲染件 c##）
TRIPO = [4, 5, 10, 11, 12, 14, 16, 17, 18, 19, 20, 21, 22]
# Blender 自做的简单构件
BLENDER = [1, 2, 3, 6, 7, 8, 9, 13, 15]


def crop(path):
    im = Image.open(path).convert("RGBA")
    bb = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(bb) if bb else im


def sheet(files, cols, out, single_prefix=None, cell=700):
    rows = (len(files) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell, rows * (cell + 40)), BG)
    d = ImageDraw.Draw(img)
    for i, f in enumerate(files):
        it = crop(os.path.join(ITEMS, f))
        s = min((cell * 0.82) / it.width, (cell * 0.72) / it.height)
        it2 = it.resize((max(1, int(it.width * s)), max(1, int(it.height * s))), Image.LANCZOS)
        cx, cy = (i % cols) * cell, (i // cols) * (cell + 40)
        img.paste(it2, (cx + (cell - it2.width) // 2, cy + 20 + (int(cell * 0.78) - it2.height) // 2), it2)
        t = str(i + 1)
        d.text((cx + (cell - d.textlength(t, font=FONT)) / 2, cy + int(cell * 0.78) + 36), t, fill=(20, 20, 20), font=FONT)
        if single_prefix:
            sq = Image.new("RGB", (1024, 1024), (255, 255, 255))
            k = min(880 / it.width, 880 / it.height)
            big = it.resize((max(1, int(it.width * k)), max(1, int(it.height * k))), Image.LANCZOS)
            sq.paste(big, ((1024 - big.width) // 2, (1024 - big.height) // 2), big)
            sq.save(os.path.join(SINGLE, "%s%02d.png" % (single_prefix, i + 1)))
    img.save(out)
    print("saved", out, img.size)


for f in os.listdir(SINGLE):
    os.remove(os.path.join(SINGLE, f))
for old in ("village_components_sheet.png",):
    p = os.path.join(D, old)
    if os.path.exists(p):
        os.remove(p)
sheet(["c%02d.png" % i for i in TRIPO], 5, os.path.join(D, "village_tripo_parts_sheet.png"), "T")
sheet(["f%02d.png" % i for i in range(1, 25)], 6, os.path.join(D, "village_furniture_sheet.png"), "F")
sheet(["c%02d.png" % i for i in BLENDER], 5, os.path.join(D, "village_blender_parts_sheet.png"))
