"""Additional stills chosen after reviewing the two contact sheets."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json

from extract_video_frames import VIDEOS, ROOT, extract

DETAILS = {"video_1": [92.0, 115.0, 171.0, 275.0],
           "video_2": [27.0, 42.0, 150.0, 205.0]}


def main():
    rows, jobs = [], []
    target = ROOT / "details"
    target.mkdir(exist_ok=True)
    for name, source, _ in VIDEOS:
        for seconds in DETAILS[name]:
            out = target / f"{name}_{seconds:07.3f}s.jpg"
            jobs.append((source, seconds, out))
            rows.append({"video": name, "source": str(source), "seconds": seconds,
                         "resolution": [1280, 720], "file": str(out.relative_to(ROOT))})
    with ThreadPoolExecutor(max_workers=4) as pool:
        for out in pool.map(extract, jobs):
            print(out, flush=True)
    (ROOT / "video_detail_manifest.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
