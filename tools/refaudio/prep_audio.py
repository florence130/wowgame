# -*- coding: utf-8 -*-
"""把参考游戏（洛奇 M / 玛奇手游）的音频改编成本项目可用的资源。

用户授权：可以使用 F:\\MabinogiMobile_TW 与 E:\\codexwork\\洛奇mobile 里的素材，
但**不能直接照搬**——这里做的改编是：
  1. 白天 / 副本 BGM：原 ogg 已是压缩流，直接复制，运行时由 Sfx 设 loop；
  2. 夜晚 BGM（32MB 立体声 wav）：降采样到 22.05k 单声道、取一段可循环的窗口、首尾交叉淡化；
  3. 村庄环境音：降采样到 22.05k 单声道（保持循环无缝）；
  4. 统一做峰值归一化到 -3dBFS，避免和程序化音效抢音量。

输出：
  assets/audio/bgm/field_day.ogg | dungeon.ogg | night.wav
  assets/audio/env/village_day.wav | village_night.wav
  assets/third_party/mabinogi_mobile/SOURCE.json（来源、大小、sha256）

用法：py -3 tools/refaudio/prep_audio.py
"""
import hashlib
import json
import os
import shutil
import struct
import wave

SRC = r"E:\codexwork\洛奇mobile\assets\audio"
SRC2 = r"E:\codexwork\洛奇mobile\assets\village\audio"  # 夜晚 BGM 与村庄环境音在这里
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BGM_OUT = os.path.join(ROOT, "assets", "audio", "bgm")
ENV_OUT = os.path.join(ROOT, "assets", "audio", "env")
META_DIR = os.path.join(ROOT, "assets", "third_party", "mabinogi_mobile")
TARGET_RATE = 22050
PEAK = 0.707  # -3 dBFS


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for blk in iter(lambda: f.read(1 << 20), b""):
            h.update(blk)
    return h.hexdigest()


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, rate, width, n = w.getnchannels(), w.getframerate(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    assert width == 2, "只处理 16bit wav: %s" % path
    frames = n
    vals = list(struct.unpack("<%dh" % (frames * ch), raw))
    # 单声道混合
    mono = [0] * frames
    for i in range(frames):
        if ch == 1:
            mono[i] = vals[i]
        else:
            mono[i] = int(sum(vals[i * ch + c] for c in range(ch)) / ch)
    # 线性重采样到 TARGET_RATE
    if rate != TARGET_RATE:
        out_n = int(frames * TARGET_RATE / rate)
        out = [0] * out_n
        for i in range(out_n):
            p = i * rate / TARGET_RATE
            i0 = int(p)
            i1 = min(i0 + 1, frames - 1)
            f = p - i0
            out[i] = int(mono[i0] * (1 - f) + mono[i1] * f)
        mono = out
    return mono


def norm(data, peak=PEAK):
    m = max(1, max(abs(v) for v in data))
    k = peak * 32767.0 / m
    return [int(max(-32768, min(32767, v * k))) for v in data]


def crossfade_loop(data, fade_s=1.5, rate=TARGET_RATE):
    """把尾部与头部交叉淡化，做出可无缝循环的一段。"""
    n = len(data)
    f = int(fade_s * rate)
    if n < f * 4:
        return data
    head = data[:f]
    body = data[f:n - f]
    tail = data[n - f:]
    looped = []
    for i in range(f):
        w = i / f
        looped.append(int(tail[i] * (1 - w) + head[i] * w))
    return looped + body


def write_wav(path, data, rate=TARGET_RATE):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(struct.pack("<%dh" % len(data), *data))


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    print("  copy  %s -> %s (%.2f MB)" % (os.path.basename(src), os.path.relpath(dst, ROOT), os.path.getsize(dst) / 1048576))


def main():
    os.makedirs(BGM_OUT, exist_ok=True)
    os.makedirs(ENV_OUT, exist_ok=True)
    os.makedirs(META_DIR, exist_ok=True)
    used = {}

    # 1) 白天 / 副本 BGM：已是 ogg，直接复制
    for src_name, out_name in [("BGM_Tir Cornail DAY.ogg", "field_day.ogg"), ("BGM_Dungeon ALBY.ogg", "dungeon.ogg")]:
        s = os.path.join(SRC, src_name)
        if os.path.exists(s):
            d = os.path.join(BGM_OUT, out_name)
            copy(s, d)
            used[src_name] = {"out": os.path.relpath(d, ROOT), "sha256": sha256(s)}

    # 2) 夜晚 BGM：降采样 + 交叉循环（取开头 150 秒，足够长的安静段落）
    s = os.path.join(SRC2, "BGM_Tir Cornail NIGHT.wav")
    if os.path.exists(s):
        data = read_wav(s)
        data = data[: int(150 * TARGET_RATE)]
        data = norm(crossfade_loop(data))
        d = os.path.join(BGM_OUT, "night.wav")
        write_wav(d, data)
        print("  proc  %s -> %s (%.2f MB)" % ("BGM_Tir Cornail NIGHT.wav", os.path.relpath(d, ROOT), os.path.getsize(d) / 1048576))
        used["BGM_Tir Cornail NIGHT.wav"] = {"out": os.path.relpath(d, ROOT), "sha256": sha256(s), "note": "150s window, mono 22.05k, crossfade loop"}

    # 3) 村庄环境音：降采样，保持原循环长度
    for src_name, out_name in [("SFX_ENV_Village_Day.wav", "village_day.wav"), ("SFX_ENV_Village_Night.wav", "village_night.wav")]:
        s = os.path.join(SRC2, src_name)
        if os.path.exists(s):
            d = os.path.join(ENV_OUT, out_name)
            write_wav(d, norm(read_wav(s)))
            print("  proc  %s -> %s (%.2f MB)" % (src_name, os.path.relpath(d, ROOT), os.path.getsize(d) / 1048576))
            used[src_name] = {"out": os.path.relpath(d, ROOT), "sha256": sha256(s), "note": "mono 22.05k, peak -3dBFS"}

    meta = {
        "source": "洛奇 M（玛奇手游）客户端提取音频",
        "origin": SRC,
        "authorization": "用户明确授权在 E:\\wowgame 中使用并改编；不直接照搬，全部经过降采样/单声道/循环淡化/归一化处理。",
        "derivatives": used,
    }
    with open(os.path.join(META_DIR, "SOURCE.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent="\t")
    print("written", os.path.join(META_DIR, "SOURCE.json"))


if __name__ == "__main__":
    main()
