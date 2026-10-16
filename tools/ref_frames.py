# Extract reference frames from the style videos into .shots/ref/ (contact sheets for review)
import os, subprocess, sys, glob
import imageio_ffmpeg
from PIL import Image

FF = imageio_ffmpeg.get_ffmpeg_exe()
SRC = r"E:\DOWNLOADS\新建文件夹"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".shots", "ref")
os.makedirs(OUT, exist_ok=True)
open(os.path.join(OUT, ".gdignore"), "a").close()
N = int(sys.argv[1]) if len(sys.argv) > 1 else 16


def duration(p):
    r = subprocess.run([FF, "-i", p], capture_output=True, text=True, encoding="utf-8", errors="ignore")
    for line in r.stderr.splitlines():
        if "Duration:" in line:
            t = line.split("Duration:")[1].split(",")[0].strip().split(":")
            return float(t[0]) * 3600 + float(t[1]) * 60 + float(t[2])
    return 60.0


for v in sorted(glob.glob(os.path.join(SRC, "*.mp4"))):
    name = os.path.splitext(os.path.basename(v))[0]
    d = duration(v)
    frames = []
    for i in range(N):
        t = d * (i + 0.5) / N
        fp = os.path.join(OUT, "%s_%02d.jpg" % (name, i))
        if not os.path.exists(fp):
            subprocess.run([FF, "-y", "-ss", "%.2f" % t, "-i", v, "-frames:v", "1", "-vf", "scale=960:-2", "-q:v", "3", fp], capture_output=True)
        if os.path.exists(fp):
            frames.append(fp)
    # contact sheet 4x4
    if frames:
        ims = [Image.open(f).convert("RGB") for f in frames]
        w, h = 480, int(480 * ims[0].height / ims[0].width)
        cols = 4
        rows = (len(ims) + cols - 1) // cols
        sheet = Image.new("RGB", (w * cols, h * rows))
        for k, im in enumerate(ims):
            sheet.paste(im.resize((w, h)), ((k % cols) * w, (k // cols) * h))
        sheet.save(os.path.join(OUT, "sheet_%s.jpg" % name), quality=85)
    print("VIDEO", name, round(d, 1), len(frames))
print("REF_DONE")
