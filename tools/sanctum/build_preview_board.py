# -*- coding: utf-8 -*-
"""Assemble the sanctum room previews into a review board, an HTML page and a manifest.

Usage: py tools/sanctum/build_preview_board.py
Input : output/imagegen/sanctum_preview_20261012/<id>_<slug>.png (+ _prompt.txt)
Output: review_board.png, review.html, manifest.json in the same folder.
"""
import hashlib, html, json, os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "output" / "imagegen" / "sanctum_preview_20261012"
FONT = "C:/Windows/Fonts/msyh.ttc"

ITEMS = [
    ("01_overall", "01 整体总览", "山门→回廊庭院→正殿→地下储藏→转运院→钟台，一条主线的整体关系；山坡地形，无海崖"),
    ("02_gate_forecourt", "02 山门与前庭", "入口与第一个轻遭遇；波纹铺装、破拱、藤蔓魔物贴墙"),
    ("03_cloister_court", "03 回廊与祈航庭院", "第一个首领场地；柱廊退到外缘，中央 28m 战斗面保持空"),
    ("04_rat_cellar", "04 地下供物储藏层", "真正埋在地下、顶上有土；旧祈愿货物被鼠人改作窝铺"),
    ("05_nave", "05 海洋女神正殿", "最大室内；高拱、侧墙封闭、高位小窗；贝壳女神浮雕，非十字／非哥特"),
    ("06_nave_apse", "06 正殿后殿与祭坛", "正殿尽端的祭坛与女神浮雕近景；柱式与拱肋语言"),
    ("07_rat_delivery_court", "07 鼠人转运院", "原祭品转运院被鼠人粗棚覆盖；窝棚只贴外缘墙"),
    ("08_bell_tower", "08 旧出航钟台", "最终战；八角平台、旧钟、破柱廊，环形战斗面"),
    ("09_passage_down", "09 地下过道（下坡）", "8m 宽 12m 高坡道；洞口上方切出真实土层断面，看得出是往地下走"),
    ("10_passage_up", "10 上行过道与装卸坡道", "东侧服务坡道；车辙、弃货、排水沟，走行面留空"),
    ("11_side_rooms", "11 侧室一组", "空室／宝箱室／旧酿酒间／小礼拜室，四种侧室用途"),
    ("12_scale_check", "12 尺度与镜头参照", "左：正殿远镜头队伍‑建筑比例；右：8m 过道内的净空"),
]


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except Exception:
        return ImageFont.load_default()


def main():
    present = [(s, t, d) for s, t, d in ITEMS if (SRC / (s + ".png")).exists()]
    missing = [s for s, _, _ in ITEMS if not (SRC / (s + ".png")).exists()]
    if not present:
        raise SystemExit("no previews found in %s" % SRC)

    margin, gap, cols = 22, 22, 2
    cw, ih, label_h, header = 820, 547, 86, 118
    rows = (len(present) + cols - 1) // cols
    board = Image.new("RGB", (cols * cw + 2 * margin + gap, header + rows * (ih + label_h + gap) + margin), "#ece7de")
    d = ImageDraw.Draw(board)
    d.text((margin, 16), "荒废的海洋女神圣堂 · 房间与过道预览", font=font(34), fill="#22343f")
    d.text((margin, 68), "统一洛奇M 式低多边形平涂大色块｜概念预览，不是游戏截图｜实际几何仍以现有白盒为准",
           font=font(21), fill="#4e5b5c")

    for i, (stem, title, sub) in enumerate(present):
        with Image.open(SRC / (stem + ".png")) as im:
            im.load()
            thumb = im.convert("RGB").resize((cw, ih), Image.Resampling.LANCZOS)
        x = margin + (i % cols) * (cw + gap)
        y = header + (i // cols) * (ih + label_h + gap)
        board.paste(thumb, (x, y))
        d.rectangle((x, y + ih, x + cw, y + ih + label_h), fill="#faf8f3")
        d.text((x + 16, y + ih + 9), title, font=font(26), fill="#22343f")
        d.text((x + 16, y + ih + 50), sub, font=font(17), fill="#54605c")
    board.save(SRC / "review_board.png")

    cards = []
    for stem, title, sub in present:
        cards.append(
            '<article><h2>%s</h2><p>%s</p>'
            '<a href="%s.png" target="_blank"><img src="%s.png" alt="%s" loading="lazy"></a>'
            '<a class="pl" href="%s_prompt.txt" target="_blank">查看提示词</a></article>'
            % (html.escape(title), html.escape(sub), stem, stem, html.escape(title), stem))
    page = """<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>荒废的海洋女神圣堂 · 房间预览</title><style>
body{margin:0;background:#e9e5dc;color:#243a45;font-family:Microsoft YaHei,sans-serif}
header,main{max-width:1720px;margin:auto;padding:26px}
h1{font-size:30px;margin:0 0 10px}p{line-height:1.85}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:26px}
article{background:#faf8f3;padding:16px;border-radius:10px;box-shadow:0 1px 3px rgba(0,0,0,.12)}
h2{font-size:22px;margin:4px 0 6px}article p{color:#54605c;font-size:15px;min-height:3.4em}
img{display:block;width:100%;border-radius:6px;margin:12px 0}
a{color:#2f6478}.pl{font-size:14px}
@media(max-width:600px){main{display:block}article{margin-bottom:22px}}
</style><header><h1>荒废的海洋女神圣堂 · 房间与过道预览</h1>
<p>古王国水手与商船出海前祈航的海洋女神神殿，信仰被新魔法科技取代后荒废一百余年，
如今由藤蔓魔物与附近鼠人蛮族占据。共用灰米石、灰蓝旧幡、苔绿藤蔓、波纹与贝壳符号。</p>
<p><b>请确认画法是否合适</b>：低多边形、大色块平涂、仅 2–3 级明暗、无细碎纹理与写实光照。
几何与尺寸按现有白盒（正殿 74×80m、地下储藏层约 40×37m、过道 8m 宽）；图只用于确认风格与氛围，
不是游戏截图，也不代表通行、镜头或战斗空间已经验收。</p></header><main>""" + "".join(cards) + "</main></html>"
    (SRC / "review.html").write_text(page, encoding="utf-8")

    files = []
    for p in sorted(SRC.iterdir()):
        if p.suffix in {".png", ".txt", ".html", ".json"}:
            files.append({"file": p.name, "bytes": p.stat().st_size,
                          "sha256": hashlib.sha256(p.read_bytes()).hexdigest()})
    manifest = {
        "status": "visual_previews_awaiting_user_feedback",
        "theme": "荒废百年、被藤蔓魔物与鼠人蛮族占据的海洋女神祈航圣堂",
        "style": "洛奇M / 巴别塔圣歌式低多边形平涂大色块手绘卡通",
        "whitebox_modified_in_this_stage": False,
        "engine_geometry_unchanged": True,
        "provider_tutorial": "https://www.krill-code.com/app/tutorial?channel=绘图&client=api-code",
        "requested_base_url": "https://api.krill-code.net/v1",
        "requested_model": "gpt-image-2.5",
        "requested_size": "1536x1024",
        "provider_underlying_model_independently_verified": False,
        "room_source_sizes": {
            "nave": "74x80 m, level 24", "cellar": "40x37 m, level 8, buried",
            "mortuary": "42x36 m, level 8, buried", "cloister": "50x46 m, level 18",
            "root_garden": "44x41 m, level 18", "supply_court": "48x44 m, level 20",
            "bell_tower": "40x40 m, level 32",
        },
        "generated": [s for s, _, _ in present],
        "missing": missing,
        "limitations": [
            "图片是风格与氛围概念预览，不是游戏截图、不是白盒平面图",
            "图中的相机、净高、战斗空间与碰撞没有经过三维验证",
            "侧室与钟台等图后续还要按实际白盒边界补做",
            "保存成功不等于用户已批准风格",
        ],
        "credentials_saved": False,
        "files": files,
    }
    (SRC / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"present": len(present), "missing": missing,
                      "board": str(SRC / "review_board.png")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
