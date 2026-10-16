# -*- coding: utf-8 -*-
"""把参考游戏（洛奇 M）的手绘贴图改编成本项目的地表 / 建筑细节贴图。

用户授权使用 E:\\codexwork\\洛奇mobile 的素材，但要求**不能直接照搬**——这里的做法是
「取参考贴图的笔触与图案，保留本项目的配色」：

  地表贴图（彩色，均值保持与原文件一致）：out = 原贴图平均色 × (1 + 细节 × 强度)
    细节层 = 参考图的亮度 − 其平均值（因此只带入笔触，不带入颜色）
  建筑贴图（灰度，均值 0.5，符合 U.BTEX / prep_tex.py 的约定）：out = 0.5 + 细节 × 强度
  图集裁块用「镜像 2×2」法保证无缝；参考图里本来就是无缝的（草/土/岩）直接重采样。

输出会覆盖 assets/textures/{terrain,building}/ 下的同名文件，原文件先备份到
.local/backup_tex_ref_20261008/；同时生成 output/ref_tex_adapted.png 供人工核对。

用法：py -3 tools/reftexture/adapt_textures.py
"""
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF = r"E:\codexwork\洛奇mobile\assets"
BACKUP = os.path.join(ROOT, ".local", "backup_tex_ref_20261008")
SHEET = os.path.join(ROOT, "output", "ref_tex_adapted.png")

# 参考图图集（玛奇：堤尔克那建筑图集）里裁出来的可平铺区域。
# 坐标是用 tools/reftexture/grid_atlas.py 画网格后人工核对出来的（图集内每块料是均匀图案）。
BANK = os.path.join(REF, "textures", "TirChonaill_Bank_00.png")
INN = os.path.join(REF, "textures", "TirChonaill_Inn_00.png")
ATLAS = {
    "wood_h": (BANK, (16, 16, 240, 160)),        # 横木板墙（浅棕）
    "wood_v": (BANK, (272, 132, 496, 246)),      # 竖木板墙（浅桃）
    "wood_dark": (BANK, (16, 396, 496, 500)),    # 深色木板带
    "cobble": (BANK, (16, 524, 240, 756)),       # 灰石砌墙
    "shingle": (BANK, (272, 904, 504, 1016)),    # 绿色瓦片（只取图案）
    "inn_wood": (INN, (16, 200, 240, 440)),      # 旅店浅棕木地板
    "inn_cobble": (INN, (24, 486, 232, 688)),    # 旅店鹅卵石地（带小石子）
    "inn_slate": (INN, (640, 776, 1016, 1016)),  # 灰蓝石板
}

# 参考图里本来就无缝的手绘贴图
REF_GRASS = os.path.join(REF, "terrain", "TirChonaill_Grass_00.png")
REF_SOIL = os.path.join(REF, "terrain", "TirChonaill_Soil_00.png")
REF_CLIFF = os.path.join(REF, "terrain", "TirChonaill_Cliff_00.png")
REF_DWALL = os.path.join(REF, "dungeons", "alby_Dungeon_Alby_Wall_00.png")
REF_DFLOOR = os.path.join(REF, "dungeons", "alby_Dungeon_Alby_Floor_00.png")

# 目标 → (来源, 是否图集裁块, 强度)
TERRAIN = {
    "t0_grass": (REF_GRASS, False, 0.85),
    "t1_grass_dark": (REF_GRASS, False, 1.0),    # 深草：同笔触、拉大对比
    "t2_dirt": (REF_SOIL, False, 0.5),
    "t3_rock": (REF_CLIFF, False, 0.5),          # 崖面裂缝对比降下来
    "t5_cobble": (REF_DWALL, False, 0.55),       # 铺装/石地：柔和的层理
    "t8_moss": (REF_GRASS, False, 0.95),         # 苔藓：同笔触、更大对比
}
BUILDING = {
    "plaster": (REF_DFLOOR, False, 0.5),
    "stone": (REF_DWALL, False, 0.4),
    "roof_slate": ("inn_slate", True, 0.45),
    "roof_terracotta": ("shingle", True, 0.6),
    "wood": ("inn_wood", True, 0.42),
    "pt_ashlar": (REF_DWALL, False, 0.42),
    "pt_rubble": ("inn_cobble", True, 0.5),
    "st_stone": (REF_DWALL, False, 0.4),
    "st_plaster": (REF_DFLOOR, False, 0.5),
    "st_wood": ("inn_wood", True, 0.42),
    "st_planks": ("wood_v", True, 0.5),
    "st_boards": ("wood_dark", True, 0.5),
    "brick": ("wood_h", True, 0.5),   # 只取参考图的砌块图案，颜色仍由 building.gdshader 的红砖底色给
}


def wrap_blend(im, band=40):
    """把裁剪块做成无缝：整体滚动半幅，再在边缘带与原图线性混合。
    （比镜像 2×2 更保形：木板/瓦片的条纹方向不会被打乱。）"""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    rolled = np.roll(a, (h // 2, w // 2), axis=(0, 1))
    yy = np.minimum(np.arange(h), h - 1 - np.arange(h))[:, None]
    xx = np.minimum(np.arange(w), w - 1 - np.arange(w))[None, :]
    t = np.clip(np.minimum(yy, xx).astype(np.float32) / float(band), 0.0, 1.0)[..., None]
    return Image.fromarray((a * t + rolled * (1 - t)).astype(np.uint8))


def detail_layer(im, size, seamless, zoom=1.0):
    """返回均值 0 的亮度细节层（float，约 ±0.25）。"""
    im = im.convert("RGB")
    if zoom > 1.0:
        w, h = im.size
        im = im.crop((int(w * (1 - 1 / zoom) / 2), int(h * (1 - 1 / zoom) / 2),
                      int(w * (1 + 1 / zoom) / 2), int(h * (1 + 1 / zoom) / 2)))
    if seamless:
        im = wrap_blend(im)
    im = im.resize((size, size), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    return lum - lum.mean()


def atlas_crop(name):
    src_path, rect = ATLAS[name]
    x0, y0, x1, y1 = rect
    return Image.open(src_path).convert("RGB").crop((x0, y0, x1, y1))


def mean_color(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    return a.reshape(-1, 3).mean(axis=0)


def backup(path):
    os.makedirs(BACKUP, exist_ok=True)
    dst = os.path.join(BACKUP, os.path.relpath(path, ROOT).replace("\\", "/").replace("/", "_"))
    if not os.path.exists(dst):
        shutil.copyfile(path, dst)


def write_terrain(target, src, is_atlas, strength):
    path = os.path.join(ROOT, "assets", "textures", "terrain", target + ".png")
    if not os.path.exists(path):
        print("  skip (no target)", target)
        return None
    backup(path)
    src_img = atlas_crop(src) if is_atlas else Image.open(src)
    d = detail_layer(src_img, 512, is_atlas, 1.0 if target != "t1_grass_dark" and target != "t8_moss" else 1.6)
    base = mean_color(path)  # 保留本项目原贴图的平均色
    out = base[None, None, :] * (1.0 + (d * strength * 2.0)[..., None])
    img = Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0).astype(np.uint8))
    img.save(path)
    print("  terrain %-14s <- %-28s strength %.2f" % (target, os.path.basename(src) if not is_atlas else src, strength))
    return img


def write_building(target, src, is_atlas, strength):
    path = os.path.join(ROOT, "assets", "textures", "building", target + ".png")
    if not os.path.exists(path):
        print("  skip (no target)", target)
        return None
    backup(path)
    src_img = atlas_crop(src) if is_atlas else Image.open(src)
    d = detail_layer(src_img, 512, is_atlas)
    out = 0.5 + d * strength * 2.0
    img = Image.fromarray((np.clip(out, 0.02, 0.98) * 255.0).astype(np.uint8)).convert("RGB")
    img.save(path)
    print("  building %-14s <- %-28s strength %.2f" % (target, os.path.basename(src) if not is_atlas else src, strength))
    return img


def contact_sheet(images):
    cols = 6
    size = 160
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * size, rows * size), (24, 26, 32))
    for i, im in enumerate(images):
        sheet.paste(im.resize((size, size), Image.LANCZOS), ((i % cols) * size, (i // cols) * size))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    sheet.save(SHEET)
    print("sheet ->", os.path.relpath(SHEET, ROOT))


def main():
    out = []
    print("terrain:")
    for target, (src, is_atlas, strength) in TERRAIN.items():
        im = write_terrain(target, src, is_atlas, strength)
        if im is not None:
            out.append(im)
    print("building:")
    for target, (src, is_atlas, strength) in BUILDING.items():
        im = write_building(target, src, is_atlas, strength)
        if im is not None:
            out.append(im)
    contact_sheet(out)


if __name__ == "__main__":
    main()
