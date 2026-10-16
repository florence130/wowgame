# 建筑手绘贴图的 PBR 高清化（2026-10-10 用户：金穗镇遵循洛奇M 画面风格，做 PBR 高清化重置）。
# 输入：assets/textures/building/pt_*.png（洛奇M 图集方砖裁出的 RGB 乘数贴图，1024，均值 0.5）
# 输出（全部 2048、无缝，FFT 环绕运算保证平铺）：
#   pt_X.png    albedo 乘数图：2048 Lanczos 放大 + 反锐化 + 无缝微噪点 + 缝隙 / 凹处环境遮蔽，均值重新归一到 0.5（底色不变）
#   pt_X_n.png  切线空间法线图（OpenGL 约定：+X = 贴图 u 向右，+Y = 贴图 v 增大方向；building.gdshader 的切线系和它一致）
#   pt_X_r.png  R = 粗糙度乘数（0.5 = 不变；凹处 / 灰缝更糙，磨亮处更光滑），G = 环境遮蔽
# 原 1024 版备份到 .local/backup_tex_hd_20261010/。
#   py tools/texgen/pbr_maps.py [name1,name2]
import os, sys, shutil
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
D = os.path.join(ROOT, "assets", "textures", "building")
BK = os.path.join(ROOT, ".local", "backup_tex_hd_20261010")
F = np.float32
N = 2048
# 名称: (法线强度, 微噪点强度, 噪点基频(周期数/张), 遮蔽强度, 粗糙度对比)
MATS = {
    "pt_ashlar": (7.0, 0.05, 96, 0.55, 0.9), "pt_rubble": (8.5, 0.06, 80, 0.6, 1.0), "pt_limestone": (5.5, 0.04, 96, 0.4, 0.8),
    "pt_brick": (6.5, 0.05, 110, 0.5, 0.8), "pt_plaster": (2.2, 0.06, 140, 0.25, 0.6), "pt_wood": (5.0, 0.04, 120, 0.5, 0.9),
    "pt_wood_light": (4.5, 0.04, 120, 0.45, 0.8), "pt_roof_tile": (7.0, 0.04, 90, 0.55, 0.7), "pt_roof_slate": (6.0, 0.04, 90, 0.5, 0.8),
    "pt_shake": (7.0, 0.04, 90, 0.55, 0.8), "pt_thatch": (6.0, 0.03, 70, 0.6, 0.7),
}


def blur(a, sigma):
    """环绕（无缝）高斯模糊：频域乘高斯。a: HxW 或 HxWxC。"""
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi ** 2) * (sigma ** 2) * (fx ** 2 + fy ** 2)).astype(F)
    if a.ndim == 2:
        return np.fft.ifft2(np.fft.fft2(a) * g).real.astype(F)
    return np.stack([np.fft.ifft2(np.fft.fft2(a[..., c]) * g).real for c in range(a.shape[2])], -1).astype(F)


def tile_noise(rng, freq, n=N):
    """无缝噪点：白噪声在频域按 1/f 滤波（freq = 主频周期数）。返回均值 0、标准差 1。"""
    w = rng.standard_normal((n, n)).astype(F)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    r = np.sqrt(fx ** 2 + fy ** 2) + 1e-6
    filt = (1.0 / (1.0 + (r / freq) ** 2)) * (r / freq + 0.2)
    a = np.fft.ifft2(np.fft.fft2(w) * filt).real.astype(F)
    return (a - a.mean()) / (a.std() + 1e-6)


def process(name, strength, grain, gfreq, ao_s, rough_c):
    src = os.path.join(D, name + ".png")
    bk = os.path.join(BK, name + ".png")
    if not os.path.exists(bk):
        os.makedirs(BK, exist_ok=True)
        shutil.copy2(src, bk)
    im = Image.open(bk).convert("RGB")
    if im.size[0] != N:
        im = im.resize((N, N), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=2.2, percent=60, threshold=2))
    a = np.asarray(im, F) / 255.0                                   # 乘数图，均值≈0.5
    rng = np.random.default_rng(abs(hash(name)) % (2 ** 31))
    lum = a.mean(2)
    lum = lum / max(lum.mean(), 1e-4)                                # 均值 1
    # 高度：贴图自带的明暗（砖缝 / 灰缝 / 木板缝 = 暗 = 低）+ 低频起伏 + 微噪点
    h = blur(lum, 2.2) - 0.6 * blur(lum, 40.0)
    h = (h - h.min()) / (h.max() - h.min() + 1e-6)
    micro = tile_noise(rng, gfreq)
    h = h + 0.006 * micro
    # 遮蔽：高度低于周围的凹处变暗
    ao = np.clip(1.0 - ao_s * np.clip(blur(h, 14.0) - h, 0, None) * 3.0, 0.35, 1.0)
    # 法线（中心差分，环绕）
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    k = strength * N / 256.0 * 0.32
    nx, ny, nz = -dx * k, -dy * k, np.ones_like(h)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nmap = np.stack([nx * inv, ny * inv, nz * inv], -1) * 0.5 + 0.5
    # 粗糙度乘数：亮 / 凸处略光滑，暗 / 凹处更糙
    rr = np.clip(0.5 - rough_c * 0.35 * (lum - 1.0) - 0.15 * (ao - 1.0) * -1.0 * 0 + 0.03 * micro, 0.0, 1.0)
    rr = np.clip(rr + (1.0 - ao) * 0.4, 0.0, 1.0)
    # albedo：微噪点 + 遮蔽，均值回到 0.5
    out = a * (1.0 + grain * 0.3 * micro[..., None]) * (0.78 + 0.22 * ao)[..., None]
    out = out * (0.5 / out.reshape(-1, 3).mean(0))
    u8 = lambda x: (np.clip(x, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(u8(out), "RGB").save(os.path.join(D, name + ".png"), optimize=True)
    Image.fromarray(u8(nmap), "RGB").save(os.path.join(D, name + "_n.png"), optimize=True)
    Image.fromarray(u8(np.stack([rr, ao, np.zeros_like(rr)], -1)), "RGB").resize((1024, 1024), Image.LANCZOS).save(os.path.join(D, name + "_r.png"), optimize=True)
    print("PBR", name, [os.path.getsize(os.path.join(D, name + s)) // 1024 for s in (".png", "_n.png", "_r.png")], "KB", flush=True)


if __name__ == "__main__":
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
    for k, v in MATS.items():
        if not only or k in only:
            process(k, *v)


