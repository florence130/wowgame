# 把 audit_views.py 渲出的 6 个视角图拼成每件一张 docs/village_kit/parts/audit/<id>.png
import os, glob
from PIL import Image, ImageDraw
OUT = r"E:\wowgame\docs\village_kit\parts\audit"
ids = sorted(set(os.path.basename(f).split("__")[0] for f in glob.glob(OUT + r"\*__*.png")))
for pid in ids:
    names = ["front", "back", "left", "right", "top", "under"]
    sh = Image.new("RGB", (560 * 3, 560 * 2), (200, 200, 200))
    d = ImageDraw.Draw(sh)
    for i, n in enumerate(names):
        p = os.path.join(OUT, "%s__%s.png" % (pid, n))
        if os.path.exists(p):
            sh.paste(Image.open(p).convert("RGB"), ((i % 3) * 560, (i // 3) * 560))
            d.text(((i % 3) * 560 + 6, (i // 3) * 560 + 4), pid + " " + n, fill=(0, 0, 0))
            os.remove(p)
    sh.save(os.path.join(OUT, pid + ".png"))
print(ids)
