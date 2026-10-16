"""把《洛奇 Mobile》提取出来的音频适配成《以太纪元》的听感，输出到 assets/audio/。

设计原则（对应「不要完全直接拿来使用，需要根据当前游戏风格进行修改」）：
  1. 统一响度：原始素材 RMS 从 -8.5 到 -49.8 dBFS 不等、峰值最高 +2 dBFS（已削波）。
     这里按用途归一（BGM -20 / 环境音 -30 / 音效 -17 dBFS），并用 tanh 软限幅处理过冲，
     既消除削波又不产生硬切。
  2. 软低通 + 32 kHz 重采样：手游时代的混音高频偏亮偏硬，与本作绘本柔光风格冲突。
     统一做 11 kHz 一阶低通（前后向各一次，零相位），再降到 32 kHz——频带正好覆盖，
     体积也小一截。
  3. 立体声收窄：M/S 处理把 side 收到 0.85，让音乐/环境音退到音效后面，不抢戏。
  4. 循环处理：环境音与 BGM 先裁掉首尾静音，再做 0.5 s 交叉淡化，消除接缝的「咔哒」。
     环境音实测首尾残差 2.6–4.6 dB，BGM 里有 13.7 dB 的，不处理必然爆音。
  5. 长素材裁短音效：洛奇的武器音是 1.6–3.8 s 的 Boss 连段，不能直接当打击音用。
     这里用短时能量包络找「最强起音点」，从该点切固定长度并加淡出——切割位置写进日志可复核。

用法：
    python tools/audio/prep_lom_audio.py            # 全部生成
    python tools/audio/prep_lom_audio.py --list     # 只打印映射表
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import numpy as np
import soundfile as sf

SRC = "E:/MabinogiMobile_TW_extract"
MUSIC = SRC + "/Map/Audio/Music"
SFXDIR = SRC + "/Map/Audio"
ROOT = "E:/wowgame/assets/audio"

# 输出采样率与 Vorbis 质量（0.0–1.0）。32 kHz 配合 11 kHz 低通足够，且显著省体积。
RATE_BGM = 32000
RATE_SFX = 44100
Q_BGM = 0.22
Q_SFX = 0.30
LP_CUTOFF = 11000.0
SIDE_KEEP = 0.85

# ---------------------------------------------------------------- 映射表
# (源文件, 目标相对路径, 类型, 目标 RMS dBFS, 裁短到多少秒或 None, 循环交叉淡化秒数)
BGM = [
    ("BGM_Tir Cornail DAY.ogg", "bgm/town_day.ogg", "town", -20.0),
    ("BGM_Tir Cornail NIGHT.ogg", "bgm/town_night.ogg", "town_night", -21.0),
    ("BGM_Colhen DAY Short.ogg", "bgm/city_day.ogg", "city", -20.0),
    ("BGM_Colhen NIGHT Short.ogg", "bgm/city_night.ogg", "city_night", -21.0),
    ("BGM_Dugald Aisle.ogg", "bgm/field_day.ogg", "field", -20.0),
    ("BGM_WolvesWood Dangerous Zone.ogg", "bgm/field_night.ogg", "field_night", -21.0),
    ("BGM_Morrighan_Church.ogg", "bgm/sanctum.ogg", "sanctum", -21.0),
    ("BGM_Dungeon ALBY.ogg", "bgm/dungeon.ogg", "dungeon", -20.0),
    ("BGM_Town Battle.ogg", "bgm/combat.ogg", "combat", -19.0),
]

AMB = [
    ("SFX_ENV_Village_Day.ogg", "amb/village_day.ogg", -30.0),
    ("SFX_ENV_Village_Night.ogg", "amb/village_night.ogg", -32.0),
    ("SFX_ENV_Town_Day.ogg", "amb/town_day.ogg", -30.0),
    ("SFX_ENV_Town_Night.ogg", "amb/town_night.ogg", -32.0),
    ("SFX_ENV_Forest_Day.ogg", "amb/forest_day.ogg", -30.0),
    ("SFX_ENV_Forest_Night.ogg", "amb/forest_night.ogg", -32.0),
    # 魔法场持续音：圣所/遗迹用，本来就是循环素材（首尾残差 0.3 dB）
    ("SFX_IceMage_Freezing_Field_Tier1A_Field_Idle.ogg", "amb/arcane_field.ogg", -31.0),
]

# (源文件, 相对 SFXDIR 还是 Audio/, 目标, 目标 RMS, 裁短秒数或 None)
SFX = [
    # —— 武器与命中：从 1.6–3.8 s 的 Boss 连段里取最强起音，切 0.3–0.6 s ——
    ("Boss_Pearon_GhostArmor_Black_TwoHandedSword_SFX_03.ogg", "audio", "sfx/hit.ogg", -17.0, 0.42),
    ("Boss_Alby_DivineSoldier_GreatSwordWarrior_SFX_01.ogg", "audio", "sfx/hit_crit.ogg", -16.0, 0.60),
    ("Boss_Peaca_Ghost_Scythe_Black_SFX_01.ogg", "music", "sfx/swing.ogg", -20.0, 0.34),
    ("Boss_Rabbie_GhostArmor_Defualt_Mace_SFX_02.ogg", "music", "sfx/block.ogg", -17.0, 0.45),
    # —— 施法 ——
    ("SFX_Dryad_Magician_ForestGale_Casting.ogg", "sfx", "sfx/cast.ogg", -17.0, 1.60),
    ("SFX_IceMage_Freezing_Field_Tier2C_Field_Casting.ogg", "sfx", "sfx/frost.ogg", -17.0, None),
    ("SFX_DungeonTransition.ogg", "sfx", "sfx/arcane.ogg", -19.0, None),
    ("SFX_UseMysticDungeonKey_PortalSpawn.ogg", "sfx", "sfx/portal.ogg", -18.0, None),
    # —— 拾取 / 交互 / 系统 ——
    ("SFX_CombatField_Drop_Do_Small.ogg", "sfx", "sfx/loot.ogg", -18.0, None),
    ("SFX_CombatField_Drop_Open_Small.ogg", "sfx", "sfx/open.ogg", -19.0, 1.10),
    ("SFX_DungeonDoor_Math_Abyss_Close.ogg", "sfx", "sfx/close.ogg", -19.0, 1.40),
    ("SFX_Eventgame_Collabo_MapleStory_SlimeDungeon_CoinCount.ogg", "sfx", "sfx/coin.ogg", -19.0, None),
    ("SFX_MysticDungeon_Spawn.ogg", "sfx", "sfx/aggro.ogg", -18.0, 1.60),
    ("ItemBox_Random_Upgrade.ogg", "audio", "sfx/learn.ogg", -18.0, None),
    ("ItemBox_Epic_SFX_Result.ogg", "audio", "sfx/levelup.ogg", -17.0, None),
    ("SFX_UseMysticDungeonKey.ogg", "sfx", "sfx/quest_accept.ogg", -18.0, None),
    ("SFX_Clear_Dungeon.ogg", "sfx", "sfx/quest_done.ogg", -17.0, 3.20),
]


# ---------------------------------------------------------------- DSP
def db(x: float) -> float:
    return 20.0 * np.log10(max(float(x), 1e-9))


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(x ** 2))) if x.size else 0.0


def narrow(d: np.ndarray, keep: float) -> np.ndarray:
    if d.shape[1] < 2:
        return d
    m = d.mean(axis=1, keepdims=True)
    s = (d[:, :1] - d[:, 1:2]) * 0.5
    return np.concatenate([m + s * keep, m - s * keep], axis=1)


def lowpass(d: np.ndarray, sr: int, fc: float) -> np.ndarray:
    """一阶低通，前后向各一次（零相位）。"""
    a = 1.0 - np.exp(-2.0 * np.pi * fc / sr)
    out = d.copy()
    for _ in range(2):
        out = np.apply_along_axis(lambda c: _onepole(c, a), 0, out)
        out = out[::-1]
    return out


def _onepole(c: np.ndarray, a: float) -> np.ndarray:
    y = np.empty_like(c)
    acc = c[0]
    for i in range(c.size):
        acc += a * (c[i] - acc)
        y[i] = acc
    return y


def lowpass_fast(d: np.ndarray, sr: int, fc: float) -> np.ndarray:
    """低通的频域实现：等波纹更小的零相位衰减，且比逐样本循环快得多。"""
    n = d.shape[0]
    if n < 64:
        return d
    freq = np.fft.rfftfreq(n, 1.0 / sr)
    # 一阶幅度响应｜H｜= 1/sqrt(1+(f/fc)^2)，前后向各一次即平方
    h = 1.0 / (1.0 + (freq / fc) ** 2)
    spec = np.fft.rfft(d, axis=0)
    return np.fft.irfft(spec * h[:, None], n=n, axis=0).astype(np.float32)


def resample(d: np.ndarray, sr: int, out_sr: int) -> np.ndarray:
    if out_sr == sr:
        return d
    n_out = int(round(d.shape[0] * out_sr / sr))
    t_in = np.arange(d.shape[0], dtype=np.float64)
    t_out = np.linspace(0.0, d.shape[0] - 1.0, n_out)
    ch = [np.interp(t_out, t_in, d[:, c].astype(np.float64)) for c in range(d.shape[1])]
    return np.stack(ch, axis=1).astype(np.float32)


def trim_silence(d: np.ndarray, sr: int, thresh_db: float = -55.0, pad: float = 0.05) -> np.ndarray:
    mono = d.mean(axis=1)
    win = max(int(0.02 * sr), 1)
    n = mono.size // win * win
    if n == 0:
        return d
    env = np.sqrt((mono[:n].reshape(-1, win) ** 2).mean(axis=1))
    idx = np.nonzero(env > 10 ** (thresh_db / 20.0))[0]
    if idx.size == 0:
        return d
    a = max(int(idx[0] * win - pad * sr), 0)
    b = min(int((idx[-1] + 1) * win + pad * sr), d.shape[0])
    return d[a:b]


def loop_crossfade(d: np.ndarray, sr: int, sec: float) -> np.ndarray:
    """把尾部与开头交叉淡化，使首尾相接时无跳变。返回裁掉尾巴的循环体。"""
    n = int(sec * sr)
    if n <= 0 or d.shape[0] <= n * 3:
        return d
    head = d[:n].copy()
    tail = d[-n:]
    fade = np.linspace(0.0, 1.0, n)[:, None].astype(np.float32)
    blended = head * fade + tail * (1.0 - fade)
    out = np.concatenate([blended, d[n:-n]], axis=0)
    return out.astype(np.float32)


def onset_cut(d: np.ndarray, sr: int, length: float, hop: float = 0.005) -> tuple[np.ndarray, float]:
    """在短时能量包络里找最强起音点，切出 length 秒。返回 (片段, 起点秒)。"""
    mono = np.abs(d).mean(axis=1)
    h = max(int(hop * sr), 1)
    n = mono.size // h * h
    env = mono[:n].reshape(-1, h).max(axis=1)
    rise = np.maximum(np.diff(env, prepend=env[0]), 0.0)
    # 只在前 70% 找，避免落到尾音的衰减段上
    limit = max(int(len(rise) * 0.7), 1)
    onset = int(np.argmax(rise[:limit])) * h
    start = max(onset - int(0.03 * sr), 0)
    end = min(start + int(length * sr), d.shape[0])
    return d[start:end].copy(), start / sr


def soft_limit(d: np.ndarray, ceiling_db: float = -1.0) -> np.ndarray:
    """tanh 软限幅：过冲时平滑压缩而不是硬削。"""
    ceil = 10 ** (ceiling_db / 20.0)
    peak = float(np.max(np.abs(d))) if d.size else 0.0
    if peak <= ceil:
        return d
    k = ceil / peak
    return (np.tanh(d * k * 1.4) / 1.4).astype(np.float32)


def normalize(d: np.ndarray, target_db: float) -> np.ndarray:
    cur = rms(d)
    if cur <= 0.0:
        return d
    d = d * (10 ** (target_db / 20.0) / cur)
    return soft_limit(d)


def fade(d: np.ndarray, sr: int, fin: float, fout: float) -> np.ndarray:
    out = d.copy()
    n = min(int(fin * sr), out.shape[0] // 2)
    if n > 0:
        out[:n] *= np.linspace(0.0, 1.0, n)[:, None]
    n = min(int(fout * sr), out.shape[0] // 2)
    if n > 0:
        out[-n:] *= np.linspace(1.0, 0.0, n)[:, None]
    return out


# ---------------------------------------------------------------- 处理流程
def process(src: str, dst: str, kind: str, target_db: float, cut: float | None) -> dict:
    d, sr = sf.read(src, dtype="float32", always_2d=True)
    src_rms, src_peak = db(rms(d)), db(np.max(np.abs(d)))
    info: dict = {"source": src, "target": dst, "kind": kind,
                  "src_seconds": round(d.shape[0] / sr, 2),
                  "src_rms_db": round(src_rms, 1), "src_peak_db": round(src_peak, 1)}

    if kind == "bgm":
        d = trim_silence(d, sr)
        d = narrow(d, SIDE_KEEP)
        d = lowpass_fast(d, sr, LP_CUTOFF)
        d = resample(d, sr, RATE_BGM)
        d = loop_crossfade(d, RATE_BGM, 0.5)
        d = normalize(d, target_db)
    elif kind == "amb":
        d = trim_silence(d, sr, thresh_db=-70.0, pad=0.0)
        d = narrow(d, SIDE_KEEP)
        d = lowpass_fast(d, sr, LP_CUTOFF)
        d = resample(d, sr, RATE_BGM)
        d = loop_crossfade(d, RATE_BGM, 1.2)
        d = normalize(d, target_db)
    else:  # sfx
        if cut is not None:
            d, start = onset_cut(d, sr, cut)
            info["cut_from_seconds"] = round(start, 3)
        d = lowpass_fast(d, sr, LP_CUTOFF)
        d = resample(d, sr, RATE_SFX)
        d = fade(d, RATE_SFX, 0.003, 0.030)
        d = normalize(d, target_db)

    out_sr = RATE_BGM if kind in ("bgm", "amb") else RATE_SFX
    out_q = Q_BGM if kind in ("bgm", "amb") else Q_SFX
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    sf.write(dst, d, out_sr, format="OGG", subtype="VORBIS", compression_level=out_q)

    info.update({"out_seconds": round(d.shape[0] / out_sr, 2), "out_rate": out_sr,
                 "out_rms_db": round(db(rms(d)), 1), "out_peak_db": round(db(np.max(np.abs(d))), 1),
                 "bytes": os.path.getsize(dst),
                 "src_sha256": hashlib.sha256(open(src, "rb").read()).hexdigest()})
    return info


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="只打印映射表")
    args = ap.parse_args()

    jobs: list[tuple[str, str, str, float, float | None]] = []
    for name, rel, mode, tgt in BGM:
        jobs.append((os.path.join(MUSIC, name), rel, "bgm", tgt, None))
    for name, rel, tgt in AMB:
        jobs.append((os.path.join(SFXDIR, name), rel, "amb", tgt, None))
    for name, where, rel, tgt, cut in SFX:
        base = SFXDIR if where == "sfx" else os.path.join(SRC, "Audio")
        jobs.append((os.path.join(base, name), rel, "sfx", tgt, cut))

    if args.list:
        for s, r, k, t, c in jobs:
            print("%-6s %-26s <- %s%s" % (k, r, os.path.basename(s),
                                          "  裁 %.2fs" % c if c else ""))
        print("合计 %d 项" % len(jobs))
        return

    rows: list[dict] = []
    total = 0
    for s, r, k, t, c in jobs:
        if not os.path.exists(s):
            print("!! 缺源文件 %s" % s)
            continue
        info = process(s, os.path.join(ROOT, r), k, t, c)
        rows.append(info)
        total += info["bytes"]
        print("%-24s %6.2fs -> %6.2fs  rms %6.1f -> %6.1f dB  峰 %5.1f dB  %6.0f KB%s" % (
            r, info["src_seconds"], info["out_seconds"], info["src_rms_db"], info["out_rms_db"],
            info["out_peak_db"], info["bytes"] / 1024.0,
            "  切自 %.2fs" % info["cut_from_seconds"] if "cut_from_seconds" in info else ""))

    manifest = {
        "source_client": "F:/MabinogiMobile_TW（玛奇 Mobile 台服客户端）",
        "extraction": "E:/MabinogiMobile_TW_extract",
        "pipeline": "tools/audio/prep_lom_audio.py",
        "recipe": {
            "loudness": "按用途归一到 BGM -20 / 环境音 -30 / 音效 -17 dBFS，tanh 软限幅 ceiling -1 dBFS",
            "lpf": "%d Hz 一阶幅度响应平方（零相位）" % LP_CUTOFF,
            "side_keep": SIDE_KEEP,
            "loop": "裁首尾静音 + 交叉淡化（BGM 0.5s / 环境音 1.2s）",
            "sfx_cut": "短时能量包络最强起音点起切 + 3ms 淡入 / 30ms 淡出",
            "encode": "OGG Vorbis，BGM 与环境音 %d Hz q%.2f，音效 %d Hz q%.2f" % (
                RATE_BGM, Q_BGM, RATE_SFX, Q_SFX),
        },
        "items": rows,
    }
    with open(ROOT + "/SOURCE.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print("\n合计 %.2f MB，清单写入 assets/audio/SOURCE.json" % (total / 1048576.0))


if __name__ == "__main__":
    main()
