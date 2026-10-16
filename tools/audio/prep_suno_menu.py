"""Prepare Suno candidate A, now used for daytime city music."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.local/menu_music_20261011'
sys.path.insert(0, str(WORK / 'deps'))
import imageio_ffmpeg
import numpy as np
import soundfile as sf

ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out = ROOT / 'assets/audio/bgm'
out.mkdir(parents=True, exist_ok=True)
rows = []
for task in ['145334040', '145334042']:
    src = WORK / f'candidate_{task}.m4a'
    pcm = WORK / f'candidate_{task}.wav'
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-i', str(src),
                    '-ar', '44100', '-ac', '2', str(pcm)], check=True)
    data, sr = sf.read(pcm, dtype='float32', always_2d=True)
    preview = WORK / f'candidate_{task}.mp3'
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-i', str(src),
                    '-codec:a', 'libmp3lame', '-q:a', '2', str(preview)], check=True)
    row = {'task_id': task, 'source_duration': len(data) / sr,
           'source_peak_dbfs': float(20*np.log10(max(float(np.abs(data).max()), 1e-9))),
           'sha256': hashlib.sha256(src.read_bytes()).hexdigest()}
    if task == '145334040':
        # Trim only exterior silence; preserve the arrangement and stereo image.
        blocks = np.array([np.sqrt(np.mean(data[i:i+4410]**2))
                           for i in range(0, len(data), 4410)])
        active = np.flatnonzero(blocks > 10**(-48/20))
        first = max(0, int(active[0])*4410-2205)
        last = min(len(data), (int(active[-1])+1)*4410+2205)
        data = data[first:last]
        n = 3 * sr
        mix = np.linspace(0, 1, n, dtype='float32')[:, None]
        # Tail-to-head overlap, then a cyclic rotation: the boundary continues
        # from the mixed opening at t=3s to the unmodified body at t=3s.
        join = data[-n:]*(1-mix) + data[:n]*mix
        data = np.concatenate([data[n:-n], join])
        rms = float(np.sqrt(np.mean(data**2)))
        gain = min(10**(-22/20)/max(rms, 1e-9),
                   10**(-3/20)/max(float(np.abs(data).max()), 1e-9))
        data *= gain
        dst = out / 'city_day_suno.ogg'
        processed = WORK / 'main_menu_loop.wav'
        sf.write(processed, data, sr, subtype='PCM_16')
        subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-i', str(processed),
                        '-codec:a', 'libvorbis', '-q:a', '5', str(dst)], check=True)
        row.update({'game_file': str(dst.relative_to(ROOT)), 'loop_overlap_seconds': 3,
                    'duration': len(data)/sr, 'gain_db': float(20*np.log10(gain)),
                    'rms_dbfs': float(20*np.log10(np.sqrt(np.mean(data**2)))),
                    'peak_dbfs': float(20*np.log10(np.abs(data).max())),
                    'game_sha256': hashlib.sha256(dst.read_bytes()).hexdigest()})
    rows.append(row)
(WORK / 'processing_report.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
print(json.dumps(rows, indent=2))
