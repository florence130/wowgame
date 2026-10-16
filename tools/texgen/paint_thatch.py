# 手绘茅草贴图（RGB 乘数图，均值 0.5，无缝）：参考图（洛奇M 式厚茅草屋顶）——顺坡向下的长草束笔触 + 每隔一段的「一把草」横向层叠阴影 + 大尺度明暗斑。
# v 轴 = 顺坡向下（建筑着色器的屋顶映射：u 沿屋檐、v 沿坡面向下），所以笔触沿 v 拉长。
#   py tools/texgen/paint_thatch.py    → assets/textures/building/pt_thatch.png（再运行 pbr_maps.py pt_thatch 生成法线 / 粗糙度）
import os
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
N = 1024
rng = np.random.default_rng(7)
F = np.float32


def blur_wrap(a, sx, sy):
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * np.pi ** 2 * ((sx * fx) ** 2 + (sy * fy) ** 2)).astype(F)
    return np.fft.ifft2(np.fft.fft2(a) * g).real.astype(F)


# 长草笔触：白噪声在 u 方向轻糊、v 方向重糊 → 竖向细长纹
s1 = blur_wrap(rng.standard_normal((N, N)).astype(F), 1.3, 22.0)
s2 = blur_wrap(rng.standard_normal((N, N)).astype(F), 3.0, 60.0)
s1 /= s1.std(); s2 /= s2.std()
# 草束层叠：每 ~170px 一排，排内向下渐亮、排下缘一条暗缝（一把草压着一把草）
v = np.arange(N, dtype=F)[:, None] / N
row = 6.0
ph = (v * row + 0.12 * blur_wrap(rng.standard_normal((N, N)).astype(F), 40, 2)[:, :1]) % 1.0
band = np.broadcast_to((0.35 * (1.0 - ph) - 0.55 * np.exp(-((ph - 0.97) / 0.035) ** 2)), (N, N))
big = blur_wrap(rng.standard_normal((N, N)).astype(F), 55, 55)
big /= big.std()
lum = 1.0 + 0.16 * s1 + 0.09 * s2 + 0.35 * band + 0.07 * big
lum = np.clip(lum, 0.45, 1.65)
# 偏暖偏冷的草色变化（橙黄 ↔ 青黄）
t = blur_wrap(rng.standard_normal((N, N)).astype(F), 8, 40)
t /= t.std()
rgb = np.stack([lum * (1.0 + 0.05 * t), lum * (1.0 + 0.01 * t), lum * (1.0 - 0.07 * t)], -1)
rgb /= rgb.reshape(-1, 3).mean(0)
out = np.clip(rgb * 0.5, 0, 1)
Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(ROOT, "assets", "textures", "building", "pt_thatch.png"), optimize=True)
print("pt_thatch.png saved")
