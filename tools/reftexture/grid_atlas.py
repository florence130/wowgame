# -*- coding: utf-8 -*-
"""给参考图集画上坐标网格，方便人工挑选可平铺区域（输出到 output/ref_atlas_grid.png）。

用法：py -3 tools/reftexture/grid_atlas.py [图集路径...]
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT = [r"E:\codexwork\洛奇mobile\assets\textures\TirChonaill_Bank_00.png",
           r"E:\codexwork\洛奇mobile\assets\textures\TirChonaill_Inn_00.png",
           r"E:\codexwork\洛奇mobile\assets\textures\TirChonaill_Blacksmith_00.png",
           r"E:\codexwork\洛奇mobile\assets\textures\TirChonaill_HealerHouse_00.png"]


def grid(path, step=64):
    im = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(im)
    w, h = im.size
    for x in range(0, w + 1, step):
        d.line([(x, 0), (x, h)], fill=(255, 0, 0) if x % 256 == 0 else (255, 160, 0), width=1)
    for y in range(0, h + 1, step):
        d.line([(0, y), (w, y)], fill=(255, 0, 0) if y % 256 == 0 else (255, 160, 0), width=1)
    for x in range(0, w + 1, 128):
        for y in range(0, h + 1, 128):
            d.text((x + 3, y + 2), "%d,%d" % (x, y), fill=(255, 0, 0))
    return im


def main():
    out_dir = os.path.join(ROOT, "output")
    os.makedirs(out_dir, exist_ok=True)
    for p in (sys.argv[1:] or DEFAULT):
        if not os.path.exists(p):
            print("missing", p)
            continue
        im = grid(p)
        name = os.path.basename(p).replace(".png", "_grid.png")
        dst = os.path.join(out_dir, name)
        im.save(dst)
        print("->", os.path.relpath(dst, ROOT), im.size)


if __name__ == "__main__":
    main()
