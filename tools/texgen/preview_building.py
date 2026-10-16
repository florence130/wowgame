# Contact sheet: base colour x painted multiplier x 2 (what the building shader outputs, un-lit).  py preview_building.py <tex_dir> <out.png> [tile px]
import sys
import numpy as np
from PIL import Image, ImageDraw

D, OUT = sys.argv[1], sys.argv[2]
T = int(sys.argv[3]) if len(sys.argv) > 3 else 360
items = [("pt_brick", "b25a40"), ("pt_ashlar", "d6ccb8"), ("pt_plaster", "efe5cf"), ("pt_roof_tile", "a5463a"),
         ("pt_roof_slate", "4a5f86"), ("pt_copper", "5f9f8f"), ("pt_wood", "6e4a30"), ("pt_limestone", "efe7d6"),
         ("pt_rubble", "a59d8f"), ("pt_foliage", "4f8a3c"), ("pt_metal", "6a6258"), ("pt_roof_tile", "c8604a")]
cols = 4
rows = (len(items) + cols - 1) // cols
sheet = Image.new("RGB", (cols * T, rows * T), (40, 40, 40))
for i, (n, hexc) in enumerate(items):
    im = np.asarray(Image.open(f"{D}/{n}.png").convert("RGB")).astype(np.float32) / 255.0
    base = np.array([int(hexc[k:k + 2], 16) for k in (0, 2, 4)], np.float32) / 255.0
    # 1.5 repeats so seams show
    big = np.tile(im, (2, 2, 1))
    out = np.clip(base * np.clip(big * 2.0, 0.3, 1.9), 0, 1)
    pil = Image.fromarray((out * 255).astype(np.uint8)).crop((0, 0, int(im.shape[1] * 1.5), int(im.shape[0] * 1.5))).resize((T, T), Image.LANCZOS)
    sheet.paste(pil, ((i % cols) * T, (i // cols) * T))
    ImageDraw.Draw(sheet).text(((i % cols) * T + 6, (i // cols) * T + 4), f"{n} {hexc}", fill=(255, 255, 255))
sheet.save(OUT)
print("saved", OUT)
