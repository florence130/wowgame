# 直接取用洛奇M（Mabinogi Mobile）解包资源里的建筑平涂贴图（个人项目、可做衍生 / MOD）：
#   E:\MabinogiMobile_TW_extract\Textures\Bangor_WorkShop_OutSide_00.png   1024×2048 图集（8 块 512 方砖：深木 ×2 / 浅木 ×2 / 方石 / 乱石 / 灰泥 / 红砖）
#   E:\MabinogiMobile_TW_extract\Textures\Dunbarton_Roof_02.png / _03.png    256 无缝屋面（鼠尾草绿 / 长春花蓝 的方瓦）
# 做法：裁出方砖 → 十字交叉淡入淡出做成无缝 → 除以整体均值变成「RGB 乘数贴图」（建筑着色器 ×2 后底色保持，逐块色相 / 明度变化来自它）；
#   整体均值色另存到 docs/mabi_ref/tile_means.json，作为各材质的底色（房屋风格色板就从这里取）。
#   py tools/texgen/mabi_tiles.py
import os, json
import numpy as np
from PIL import Image

R = r"E:\MabinogiMobile_TW_extract\Textures"
OUT = r"E:\wowgame\assets\textures\building"
DOC = r"E:\wowgame\docs\mabi_ref"
F = np.float32


def seamless(a, edge=0.22, axes="xy"):
    """把方块做成无缝：和自己平移半幅的拷贝按「离边越近越用拷贝」的权重混合（经典 offset-blend）。"""
    h, w = a.shape[:2]
    sh = a
    if "y" in axes:
        sh = np.roll(sh, h // 2, axis=0)
    if "x" in axes:
        sh = np.roll(sh, w // 2, axis=1)
    y = np.abs(np.linspace(-1, 1, h, dtype=F))[:, None]
    x = np.abs(np.linspace(-1, 1, w, dtype=F))[None, :]
    wy = np.clip((y - (1 - edge * 2)) / (edge * 2), 0, 1)
    wx = np.clip((x - (1 - edge * 2)) / (edge * 2), 0, 1)
    m = np.maximum(wx if "x" in axes else wy * 0, wy if "y" in axes else wx * 0)[..., None]
    m = m * m * (3 - 2 * m)
    return a * (1 - m) + sh * m


def to_multiplier(a):
    """albedo(0..255) → 乘数贴图（每通道均值 0.5，和 paintlib.finish 的约定一致）；返回 (PNG 数组, 均值色 hex)。"""
    mean = a.reshape(-1, 3).mean(0)
    mul = a / np.maximum(mean, 1e-3)
    out = np.clip(mul * 0.5, 0, 1)
    return (out * 255 + 0.5).astype(np.uint8), "#%02x%02x%02x" % tuple(int(v) for v in mean)


def save(name, a, size=1024, make_seamless=True, axes="xy"):
    if make_seamless:
        a = seamless(a, axes=axes)
    img, mean = to_multiplier(a)
    im = Image.fromarray(img, "RGB")
    if im.size[0] != size:
        im = im.resize((size, size), Image.LANCZOS)
    im.save(os.path.join(OUT, name + ".png"), optimize=True)
    return mean


if __name__ == "__main__":
    os.makedirs(DOC, exist_ok=True)
    atlas = np.asarray(Image.open(os.path.join(R, "Bangor_WorkShop_OutSide_00.png")).convert("RGB"), F)
    tw, th = atlas.shape[1] // 2, atlas.shape[0] // 4
    def tile(r, c):
        return atlas[r * th:(r + 1) * th, c * tw:(c + 1) * tw]
    means = {}
    means["pt_wood"] = save("pt_wood", tile(0, 1), axes="y")                         # 深木（含橙 / 灰褐几块不同木板）
    means["pt_wood_light"] = save("pt_wood_light", tile(1, 0), axes="y")              # 浅木板（地板 / 板墙 / 货架）
    means["pt_ashlar"] = save("pt_ashlar", tile(2, 0))
    means["pt_rubble"] = save("pt_rubble", tile(2, 1))
    means["pt_limestone"] = save("pt_limestone", tile(2, 0)[::-1, ::-1])      # 石饰：同一块方石翻转，错开纹路
    means["pt_plaster"] = save("pt_plaster", tile(3, 0))
    means["pt_brick"] = save("pt_brick", tile(3, 1))
    r2 = np.asarray(Image.open(os.path.join(R, "Dunbarton_Roof_02.png")).convert("RGB"), F)
    r3 = np.asarray(Image.open(os.path.join(R, "Dunbarton_Roof_03.png")).convert("RGB"), F)
    means["pt_roof_tile"] = save("pt_roof_tile", r2, make_seamless=False)    # 陶瓦：用鼠尾草绿方瓦的瓦片结构，底色换成陶土色
    means["pt_roof_slate"] = save("pt_roof_slate", r3, make_seamless=False)
    means["pt_shake"] = save("pt_shake", r2[::-1, :], make_seamless=False)   # 木瓦：同样的方瓦结构，底色换成木色
    means["pt_roof_sage"] = means["pt_roof_tile"]
    json.dump(means, open(os.path.join(DOC, "tile_means.json"), "w", encoding="utf-8"), indent=1)
    for k, v in means.items():
        print("tile", k, v)
