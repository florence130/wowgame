"""Create review boards from the station package's actual manifest and renders.

The boards are for reading/review, not image-to-3D input. Images are contained
without cropping. No model, manifest, map, HTML or source render is modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

PROJECT = Path(__file__).resolve().parents[2]
DEFAULT_PACKAGE = PROJECT / "docs/city_v5/station_redesign"
BG = "#eeeae1"
CARD = "#fbfaf6"
INK = "#263a42"
MUTED = "#677379"
RULE = "#d1d1c8"
TEAL = "#366f73"
GOLD = "#a67b37"
PRIORITY = {"M01", "M02", "M03", "M04", "M08"}
PRECISE = {"M07", "M09"}
FONT_PATHS = [Path("C:/Windows/Fonts/msyh.ttc"), Path("C:/Windows/Fonts/simhei.ttf")]
BOLD_PATHS = [Path("C:/Windows/Fonts/msyhbd.ttc"), *FONT_PATHS]


def font(size: int, bold: bool = False):
    for path in BOLD_PATHS if bold else FONT_PATHS:
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    raise RuntimeError("需要中文字体：微软雅黑或黑体。请在 FONT_PATHS 中配置可用字体。")


def text(draw, xy, value, size=28, color=INK, bold=False):
    draw.text(xy, str(value), font=font(size, bold), fill=color, anchor="lt")


def wrapped(draw, value, width, size):
    lines, current = [], ""
    face = font(size)
    for char in str(value):
        if char == "\n":
            lines.append(current)
            current = ""
        elif current and draw.textlength(current + char, font=face) > width:
            lines.append(current)
            current = char
        else:
            current += char
    if current:
        lines.append(current)
    return lines


def paragraph(draw, xy, value, width, size=28, color=MUTED, leading=1.55):
    x, y = xy
    for line in wrapped(draw, value, width, size):
        text(draw, (x, y), line, size, color)
        y += round(size * leading)
    return y


def dims(value):
    if not isinstance(value, list) or len(value) != 3:
        raise ValueError(f"Expected width / height / depth dimensions, got {value!r}")
    return " × ".join(f"{float(v):.3f}".rstrip("0").rstrip(".") for v in value) + " m"


def actual_dims(module):
    if module.get("actualDimensions") is not None:
        return module["actualDimensions"]
    bounds = module["actualBounds"]
    return [float(b) - float(a) for a, b in zip(bounds["min"], bounds["max"])]


def inside(package, relative):
    path = (package / relative).resolve()
    if not path.is_relative_to(package):
        raise ValueError(f"Image path leaves the station package: {relative}")
    return path


def contained(canvas, source, box):
    x, y, w, h = map(int, box)
    photo = source.convert("RGBA")
    photo = ImageOps.contain(photo, (w, h), Image.Resampling.LANCZOS)
    canvas.paste(photo, (x + (w - photo.width) // 2, y + (h - photo.height) // 2), photo)


def heading(draw, title, subtitle, width):
    text(draw, (80, 57), title, 64, bold=True)
    text(draw, (84, 148), subtitle, 29, MUTED)
    draw.line((80, 202, width - 80, 202), fill=RULE, width=2)


def module_board(manifest, photos):
    modules = sorted(manifest["modules"], key=lambda m: m["id"])
    width, margin, gap, columns = 3840, 80, 28, 4
    card_w = (width - 2 * margin - gap * (columns - 1)) // columns
    image_h, card_h = card_w - 36, card_w + 222
    rows = math.ceil((len(modules) + 1) / columns)
    height = 244 + rows * card_h + (rows - 1) * gap + 120
    board = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(board)
    heading(draw, "晴岚中央车站 · 11类构件总览", "同一套设计模型的单件视图  /  编号与尺寸读取自设计清单  /  仅供查看与选件", width)

    for i, module in enumerate(modules):
        col, row = i % columns, i // columns
        x, y = margin + col * (card_w + gap), 244 + row * (card_h + gap)
        ident, label = module["id"], module["label"]
        short = ident.split("_", 1)[0]
        draw.rounded_rectangle((x, y, x + card_w, y + card_h), radius=13, fill=CARD, outline=RULE, width=2)
        draw.rounded_rectangle((x + 22, y + 24, x + 138, y + 80), radius=8, fill=TEAL)
        text(draw, (x + 40, y + 36), short, 31, "#ffffff", True)
        label_lines = wrapped(draw, label, card_w - 182, 31)
        if len(label_lines) > 2:
            raise ValueError(f"Module label is too long for the card: {label}")
        for line_no, line in enumerate(label_lines):
            text(draw, (x + 160, y + 27 + line_no * 39), line, 31, bold=True)
        photo_y = y + 112
        contained(board, photos[module["views"]["hero"]], (x + 18, photo_y, card_w - 36, image_h))
        meta_y = photo_y + image_h + 18
        text(draw, (x + 26, meta_y), "设计尺寸  " + dims(module["dimensions"]), 26)
        text(draw, (x + 26, meta_y + 40), "含外挑包围盒  " + dims(actual_dims(module)), 25, MUTED)
        tag = "优先生成" if short in PRIORITY else "建议原生精确重建" if short in PRECISE else "后续生成"
        text(draw, (x + 26, meta_y + 84), f"{tag}  ·  组装复用 ×{int(module['reuseCount'])}", 25, GOLD if short in PRECISE else TEAL)

    i = len(modules)
    x = margin + (i % columns) * (card_w + gap)
    y = 244 + (i // columns) * (card_h + gap)
    draw.rounded_rectangle((x, y, x + card_w, y + card_h), radius=13, fill="#e0e8e2", outline="#c3d0c8", width=2)
    text(draw, (x + 40, y + 47), "从这5件开始", 43, bold=True)
    text(draw, (x + 42, y + 121), "M01  ·  M02  ·  M03  ·  M04  ·  M08", 31, TEAL, True)
    note_y = paragraph(draw, (x + 42, y + 219), "先确定大厅、翼楼、端亭、拱顶和时钟冠饰的共同风格，再完成其余构件。", card_w - 84, 34, INK)
    draw.line((x + 42, note_y + 48, x + card_w - 42, note_y + 48), fill="#bacbc2", width=2)
    note_y = paragraph(draw, (x + 42, note_y + 98), "尺寸顺序：宽 × 高 × 深，单位为米。\n设计尺寸用于体量与拼装；实测包围盒包含檐口、门廊、底座等外挑。", card_w - 84, 30)
    note_y = paragraph(draw, (x + 42, note_y + 54), "M07楼梯与M09门前台阶优先用Blender精确重建；外观生成不能代替标高、通行和碰撞。", card_w - 84, 30)
    paragraph(draw, (x + 42, note_y + 54), "上传Tripo时使用单个模块的hero原图。\n这张带编号的总览图不作为生成输入。", card_w - 84, 30, TEAL)
    text(draw, (80, height - 65), f"{manifest['version']}  ·  图像分别取景，并非统一画面比例尺  ·  正式游戏车站尚未替换", 27, MUTED)
    return board


def views_board(manifest, photos):
    width, margin, gap = 4320, 80, 32
    cell_w = (width - 2 * margin - gap) // 2
    image_h = round(cell_w / 1.6)
    cell_h = image_h + 144
    height = 244 + 2 * cell_h + gap + 120
    board = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(board)
    heading(draw, "晴岚中央车站 · 整体设计视图", "同一座组装模型的4个相机视角  /  用于整体确认、比例与结构核对  /  非Tripo单件输入", width)
    panels = [
        ("hero", "01  整体透视", "横向站房、中央到达大厅与后方候车拱顶"),
        ("front", "02  正面", "主入口轴线、两翼开间与端亭比例"),
        ("right", "03  右侧", "站房进深、候车厅与站台的空间关系"),
        ("top", "04  俯视", "模块排布、通道与后部场地关系"),
    ]
    for i, (view, label, description) in enumerate(panels):
        x = margin + (i % 2) * (cell_w + gap)
        y = 244 + (i // 2) * (cell_h + gap)
        draw.rounded_rectangle((x, y, x + cell_w, y + cell_h), radius=13, fill=CARD, outline=RULE, width=2)
        text(draw, (x + 28, y + 27), label, 38, bold=True)
        text(draw, (x + 28, y + 87), description, 27, MUTED)
        contained(board, photos[manifest["overallViews"][view]], (x + 16, y + 132, cell_w - 32, image_h - 6))
    text(draw, (80, height - 65), f"{manifest['version']}  ·  各视图独立取景；数值尺寸和拼接关系以manifest / assembly清单为准  ·  设计候选", 27, MUTED)
    return board


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=DEFAULT_PACKAGE)
    parser.add_argument("--out", type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--modules-only", action="store_true")
    group.add_argument("--views-only", action="store_true")
    args = parser.parse_args()
    package = args.package.resolve()
    manifest_path = package / "manifest.json"
    raw = manifest_path.read_bytes()
    manifest = json.loads(raw.decode("utf-8"))
    modules = manifest["modules"]
    expected = {f"M{i:02}" for i in range(1, 12)}
    if len(modules) != 11 or {m["id"].split("_", 1)[0] for m in modules} != expected:
        raise ValueError("本总览要求M01至M11共11类模块；请先核对manifest。")
    paths = set()
    if not args.views_only:
        for module in modules:
            dims(module["dimensions"])
            dims(actual_dims(module))
            paths.add(module["views"]["hero"])
    if not args.modules_only:
        paths.update(manifest["overallViews"][v] for v in ("hero", "front", "right", "top"))
    missing = [p for p in sorted(paths) if not inside(package, p).is_file()]
    if missing:
        raise FileNotFoundError("视图尚未全部就绪；没有覆盖已有总览：\n" + "\n".join(missing))
    fingerprints = {p: (inside(package, p).stat().st_size, inside(package, p).stat().st_mtime_ns) for p in paths}
    photos = {}
    for relative in sorted(paths):
        with Image.open(inside(package, relative)) as source:
            source.load()
            photos[relative] = source.copy()
    boards = {}
    if not args.views_only:
        boards["modules_overview.png"] = module_board(manifest, photos)
    if not args.modules_only:
        boards["station_views.png"] = views_board(manifest, photos)
    changed = [p for p in paths if fingerprints[p] != (inside(package, p).stat().st_size, inside(package, p).stat().st_mtime_ns)]
    if manifest_path.read_bytes() != raw or changed:
        raise RuntimeError("源视图/manifest在排版期间改变；没有覆盖已有总览，请待渲染完成后重跑。")
    out = (args.out or package / "boards").resolve()
    out.mkdir(parents=True, exist_ok=True)
    results = []
    for name, board in boards.items():
        target = out / name
        board.save(target, optimize=True)
        results.append({"path": str(target), "size": list(board.size), "bytes": target.stat().st_size})
    print(json.dumps({"version": manifest["version"], "manifestSha256": hashlib.sha256(raw).hexdigest(), "outputs": results}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
