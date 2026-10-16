"""Reproducible visual reference sampling; no game files are changed."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import subprocess

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
VIDEOS = [
    ("video_1", Path("E:/DOWNLOADS/41403485769-1-192.mp4"), 509.42),
    ("video_2", Path("E:/DOWNLOADS/41418490820-1-192.mp4"), 258.82),
]
FONT = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)


def extract(job):
    path, seconds, out = job
    if out.is_file():
        return out
    subprocess.run([
        FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{seconds:.3f}", "-i", str(path),
        "-frames:v", "1", "-q:v", "2", str(out)
    ], check=True, capture_output=True)
    return out


def main():
    manifest = []
    jobs = []
    for name, path, duration in VIDEOS:
        target = ROOT / name
        target.mkdir(parents=True, exist_ok=True)
        frames = []
        for index in range(24):
            seconds = round((duration - 1.0) * index / 23.0, 3)
            out = target / f"frame_{index + 1:02d}_{seconds:07.3f}s.jpg"
            frames.append({"index": index + 1, "seconds": seconds, "file": str(out.relative_to(ROOT))})
            jobs.append((path, seconds, out))
        manifest.append({"name": name, "source": str(path), "duration_seconds": duration,
                         "resolution": [1280, 720], "method": "24 equally spaced still frames; not continuous playback", "frames": frames})
    with ThreadPoolExecutor(max_workers=4) as pool:
        for out in pool.map(extract, jobs):
            print(out, flush=True)
    for video in manifest:
        sheet = Image.new("RGB", (1280, 6 * 208 + 36), "#17212c")
        draw = ImageDraw.Draw(sheet)
        draw.text((12, 8), f"{video['name']} | 24 equally spaced samples | {video['duration_seconds']:.2f} s", font=FONT, fill="white")
        for frame in video["frames"]:
            index = frame["index"] - 1
            x, y = (index % 4) * 320, 36 + (index // 4) * 208
            with Image.open(ROOT / frame["file"]) as source:
                thumb = source.resize((320, 180), Image.Resampling.LANCZOS)
                sheet.paste(thumb, (x, y))
            seconds = frame["seconds"]
            centiseconds = round(seconds * 100)
            minutes, remaining = divmod(centiseconds, 6000)
            draw.text((x + 6, y + 184), f"#{index+1:02d} {minutes:02d}:{remaining/100:05.2f} ({seconds:.2f}s)", font=FONT, fill="white")
        out = ROOT / f"{video['name']}_contact_sheet.jpg"
        sheet.save(out, quality=94)
        video["contact_sheet"] = str(out.relative_to(ROOT))
        print(f"CONTACT_SHEET {out}", flush=True)
    (ROOT / "video_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
