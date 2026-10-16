"""体检候选音频：时长 / 峰值 / RMS / 声道 / 首尾是否可循环。用于筛音效与循环环境音。

用法：
    python tools/audio/inspect_audio.py <文件或目录> [...]
"""
import sys
import os
import numpy as np
import soundfile as sf


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-9))


def loop_gap(d: np.ndarray, sr: int, win: float = 0.20) -> float:
    """首尾窗的波形差异（dB）。越小越像能无缝循环的素材。"""
    n = int(win * sr)
    if d.shape[0] < n * 3:
        return 99.0
    a = d[:n]
    b = d[-n:]
    if a.ndim > 1:
        a = a.mean(axis=1)
        b = b.mean(axis=1)
    diff = float(np.sqrt(np.mean((a - b) ** 2)))
    ref = float(np.sqrt(np.mean(a ** 2))) + 1e-9
    return db(diff / ref)


def report(path: str) -> None:
    d, sr = sf.read(path, dtype="float32", always_2d=True)
    dur = d.shape[0] / sr
    peak = float(np.max(np.abs(d)))
    rms = float(np.sqrt(np.mean(d ** 2)))
    ch = d.shape[1]
    gap = loop_gap(d, sr)
    print("%-52s %6.2fs %s peak %6.1f dBFS  rms %6.1f dBFS  循环残差 %6.1f dB" % (
        os.path.basename(path), dur, "st" if ch > 1 else "mo", db(peak), db(rms), gap))


def main() -> None:
    targets: list[str] = []
    for a in sys.argv[1:]:
        if os.path.isdir(a):
            targets += [os.path.join(a, f) for f in sorted(os.listdir(a))
                        if f.lower().endswith((".ogg", ".wav", ".flac"))]
        else:
            targets.append(a)
    if not targets:
        print(__doc__)
        return
    for t in targets:
        try:
            report(t)
        except Exception as e:  # 单个文件失败不影响其余
            print("%-52s 读取失败: %s" % (os.path.basename(t), e))


if __name__ == "__main__":
    main()
