# 环境素材改编（用户授权的洛奇M参考素材；不原样使用，全部按本作绘本画风重做）
# 输出 assets/textures/env/：
#   moon.png        月亮：去饱和 → 4 级色阶（平涂感）→ 本作月光色（奶白偏蓝）→ 柔边圆盘
#   stars.png       星空：去掉紫色星云，只保留星点；按亮度分三档重新上色（冷白 / 淡金 / 淡蓝），再加一层很淡的本作夜空色雾带
#   water_normal.png 水面细节法线：模糊 1.5px、法线强度压到 55%、四方连续
#   fx_butterfly.png 蝴蝶图集 4 列（花色）× 2 行（展翅 / 收翅）：取原剪影，内部重画翅纹与本作色板，外描深棕边
#   fx_bird.png      飞鸟图集 2 帧（展翅 / 下扑）：原剪影 → 下扑帧由翅膀压扁变形得到，统一深石板色
# py tools/reftexture/adapt_env.py
import os
import numpy as np
from PIL import Image, ImageFilter, ImageOps

SRC = r"E:\codexwork\洛奇mobile\assets"
OUT = r"E:\wowgame\assets\textures\env"
os.makedirs(OUT, exist_ok=True)

def load(rel):
    return Image.open(os.path.join(SRC, rel)).convert("RGBA")

# ---------------------------------------------------------------- 月亮
m = load(r"village\environment\moon_00.png").resize((256, 256), Image.LANCZOS)
a = np.asarray(m).astype(np.float32) / 255.0
lum = a[..., :3] @ np.array([0.3, 0.59, 0.11])
lum = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
q = np.round(np.clip((lum - 0.35) / 0.6, 0, 1) * 3) / 3          # 4 级色阶
dark, light = np.array([0.70, 0.76, 0.90]), np.array([1.0, 0.97, 0.88])
rgb = dark[None, None] * (1 - q[..., None]) + light[None, None] * q[..., None]
yy, xx = np.mgrid[0:256, 0:256]
r = np.hypot(xx - 127.5, yy - 127.5) / 120.0
alpha = np.clip((1.0 - r) * 18, 0, 1)
rgb *= (1.0 - 0.18 * np.clip(r, 0, 1) ** 3)[..., None]            # 边缘略暗，像球体
Image.fromarray((np.dstack([rgb, alpha]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "moon.png"))

# ---------------------------------------------------------------- 星空
s = load(r"village\environment\skystar5.png").convert("RGB").resize((1024, 512), Image.LANCZOS)
sa = np.asarray(s).astype(np.float32) / 255.0
lum = sa @ np.array([0.3, 0.59, 0.11])
bg = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
pts = np.clip((lum - bg - 0.05) * 3.0, 0, 1)                      # 只留比周围亮的点：星
rnd = np.random.default_rng(7).random(lum.shape)
tint = np.where(rnd[..., None] < 0.2, [1.0, 0.9, 0.7], np.where(rnd[..., None] < 0.5, [0.75, 0.85, 1.0], [0.95, 0.97, 1.0]))
band = np.exp(-((np.mgrid[0:512, 0:1024][0] - 256 - 60 * np.sin(np.mgrid[0:512, 0:1024][1] / 1024 * 6.283)) / 70.0) ** 2) * 0.10
stars = pts[..., None] * tint + band[..., None] * np.array([0.45, 0.55, 0.9])
Image.fromarray((np.clip(stars, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "stars.png"))

# ---------------------------------------------------------------- 水面法线
w = Image.open(os.path.join(SRC, r"village\water\Water_Normal_00.png")).convert("RGB").filter(ImageFilter.GaussianBlur(1.5))
wa = np.asarray(w).astype(np.float32) / 255.0 * 2 - 1
wa[..., :2] *= 0.55
wa /= np.linalg.norm(wa, axis=-1, keepdims=True) + 1e-6
sh = np.roll(np.roll(wa, 128, 0), 128, 1)
t = np.linspace(0, 1, 256); e = np.clip(np.minimum(t, 1 - t) * 2 / 0.25, 0, 1); mk = np.outer(e, e)[..., None]
wa = wa * mk + sh * (1 - mk); wa /= np.linalg.norm(wa, axis=-1, keepdims=True) + 1e-6
Image.fromarray(((wa * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "water_normal.png"))

# ---------------------------------------------------------------- 蝴蝶图集
bf = load(r"village\wildlife\FX_Butterfly_01.png")
f_open = bf.crop((0, 0, 64, 64))
f_fold = Image.new("RGBA", (64, 64)); f_fold.paste(f_open.resize((26, 64), Image.LANCZOS), (19, 0))
frames = [f_open, f_fold]                                          # 展翅 / 收翅（横向压缩成侧立的翅膀）
PAL = [((0.98, 0.86, 0.42), (0.92, 0.55, 0.25)), ((0.97, 0.72, 0.80), (0.80, 0.42, 0.62)),
       ((0.62, 0.80, 0.98), (0.30, 0.50, 0.86)), ((0.98, 0.98, 0.94), (0.70, 0.78, 0.55))]
atlas = Image.new("RGBA", (64 * 4, 64 * 2))
for fi, fr in enumerate(frames):
    al = np.asarray(fr).astype(np.float32)[..., 3] / 255.0
    al = (al > 0.5).astype(np.float32)
    inner = np.asarray(Image.fromarray((al * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))).astype(np.float32) / 255
    yy, xx = np.mgrid[0:64, 0:64]
    for ci, (c1, c2) in enumerate(PAL):
        g = np.clip(np.hypot(xx - 32, yy - 32) / 30.0, 0, 1)            # 翅根→翅尖渐变
        spots = ((np.hypot((np.abs(xx - 32) - 17), yy - 26) < 4.5) & (inner > 0)).astype(np.float32)
        rgb = np.array(c1)[None, None] * (1 - g[..., None]) + np.array(c2)[None, None] * g[..., None]
        rgb = rgb * (1 - spots[..., None] * 0.55)
        edge = (al - inner)[..., None]
        rgb = rgb * (1 - edge) + np.array([0.28, 0.18, 0.12]) * edge     # 深棕描边
        body = ((np.abs(xx - 32) < 2) & (yy > 18) & (yy < 50)).astype(np.float32)[..., None]
        rgb = rgb * (1 - body) + np.array([0.25, 0.17, 0.12]) * body
        a2 = np.maximum(al, body[..., 0])
        atlas.paste(Image.fromarray((np.dstack([rgb, a2]) * 255).astype(np.uint8), "RGBA"), (ci * 64, fi * 64))
atlas.save(os.path.join(OUT, "fx_butterfly.png"))

# ---------------------------------------------------------------- 飞鸟图集
bd = load(r"village\wildlife\Fx_Bird_00.png")
al = (np.asarray(bd).astype(np.float32)[..., 3] / 255.0 > 0.5).astype(np.float32)
up = Image.fromarray((al * 255).astype(np.uint8))
down = Image.new("L", (64, 64))
wings = up.resize((64, 30), Image.LANCZOS)                         # 下扑帧：整体压扁 + 翼尖下移
down.paste(wings, (0, 26))
down = ImageOps.flip(down) if False else down
cols = np.array([0.24, 0.27, 0.33])
bird = Image.new("RGBA", (128, 64))
for i, f in enumerate([up, down]):
    a2 = np.asarray(f).astype(np.float32) / 255.0
    bird.paste(Image.fromarray((np.dstack([np.broadcast_to(cols, (64, 64, 3)), a2]) * 255).astype(np.uint8), "RGBA"), (i * 64, 0))
bird.save(os.path.join(OUT, "fx_bird.png"))
print("ENV_ADAPTED", sorted(os.listdir(OUT)))
