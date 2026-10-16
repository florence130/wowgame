"""Build a labelled contact sheet and six clean crops from one 3 x 2 sheet.

No network or image-generation calls. Keep the original API image unchanged.
Run with ordinary Python plus Pillow. Output must be a new directory.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

PARTS = [
    ('TR01', '方形承托柱头', '柱身 / 梁分离', '1.00 × 0.80 × 0.55 m',
     'A single square limestone pilaster capital only. Stepped upper bearing plate, flared transition and short lower neck. Flat top and bottom. No column shaft or beam.'),
    ('TR02', '檐下曲面牛腿', '背面贴墙 · 顶部承托', '0.45 × 0.60 × 0.80 m',
     'A single thick limestone eaves corbel only. Flat vertical back, flat horizontal bearing top, compact S-curved front and short lower heel. No wall or long cornice.'),
    ('TR03', '老虎窗山花冠', '仅上冠 · 不含窗与屋顶', '1.60 × 0.35 × 0.80 m',
     'A single wide low limestone dormer pediment crown only. Restrained curved upper moulding, central apex and curled shoulders. Flat lower mounting edge. No window, sill, wall, roof or vertical jambs.'),
    ('TR04', '中央山花单侧肩石', '一侧源件 · 另一侧镜像', '0.80 × 0.35 × 1.40 m',
     'A single left limestone gable shoulder only. Concave rising contour from low left to high right, compact scroll at lower end, flat back and vertical inner mounting edge. No mirrored partner or complete pediment.'),
    ('TR05', '钟楼拱龛弧形头石', '仅上拱 · 不含立柱与塔身', '1.30 × 0.40 × 0.65 m',
     'A single limestone semicircular niche arch head only. Thick stepped moulding and integral keystone, open inner arch, flat springing faces. No vertical jambs, columns, bell, wall or tower.'),
    ('TR06', '主窗宽缓尖拱顶框', '仅上拱 · 不含直框与玻璃', '1.50 × 0.28 × 0.90 m',
     'A single broad gently pointed limestone window arch head only, matching a Renaissance town-hall facade. Open inner arch, restrained moulding and flat springing faces. No narrow tall Gothic arch, jambs, wall, glass or sill.'),
]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--regions', help='Optional JSON with six non-overlapping source crop regions, in TR01 to TR06 order.')
    args = parser.parse_args()
    source, out = Path(args.source).resolve(), Path(args.out).resolve()
    if out.exists():
        raise SystemExit('Refusing an existing output directory; choose a new version.')
    im = Image.open(source).convert('RGB')
    w, h = im.size
    if w % 3 or h % 2:
        raise SystemExit('Input must divide into a 3 x 2 grid without fractional pixels.')
    if abs((w/3)/(h/2)-1) > .03:
        raise SystemExit('Expected approximately square cells in a 3 x 2 contact sheet.')
    out.mkdir(parents=True)
    (out/'parts').mkdir()
    shutil.copy2(source, out/'api_source.png')
    cw, ch = w//3, h//2
    regions = json.loads(Path(args.regions).read_text(encoding='utf-8-sig')) if args.regions else [
        [(i%3)*cw, (i//3)*ch, (i%3+1)*cw, (i//3+1)*ch] for i in range(6)]
    if len(regions) != 6:
        raise ValueError('Expected exactly six source crop regions.')
    for j, r in enumerate(regions):
        if len(r)!=4 or not all(isinstance(v,int) for v in r) or not (0<=r[0]<r[2]<=w and 0<=r[1]<r[3]<=h):
            raise ValueError('Invalid crop region.')
        for s in regions[:j]:
            if min(r[2],s[2])>max(r[0],s[0]) and min(r[3],s[3])>max(r[1],s[1]):
                raise ValueError('Crop regions overlap.')
    clean = Image.new('RGB', (3072, 2048), 'white')
    board = Image.new('RGB', (3072, 2656), '#F1F3F2')
    d = ImageDraw.Draw(board)
    font_base = Path('C:/Windows/Fonts/msyh.ttc')
    font_bold = Path('C:/Windows/Fonts/msyhbd.ttc')
    font = lambda size, bold=False: ImageFont.truetype(str(font_bold if bold else font_base), size)
    d.rectangle((0, 0, 3072, 286), fill='#193B49')
    d.text((100, 48), '修道院 · 可复用建筑石构件', font=font(74, True), fill='white')
    d.text((102, 156), '市政厅形制参考  /  TRIPO 造型探索  /  6 个独立小构件', font=font(33), fill='#D7E8E8')
    d.text((102, 214), '已去除树木、旗帜、徽章、十字与庭院装饰', font=font(28), fill='#BBCCCC')
    rows, prompts = [], []
    common = (' Match the provided single-component reference image. Stylized cream limestone, broad clean forms, restrained bevels and matte surfaces. '
              'One connected object with real thickness and planar mounting surfaces. Complete the unseen back conservatively; '
              'the back is a design proposal. No text, plinth, ground, scenery, flags, trees, emblems or crosses. '
              'Preserve open holes; do not fill the arch with a backing wall. Output one component, not a building.')
    for i, (aid, label, sub, dims, prompt) in enumerate(PARTS):
        col, row = i%3, i//3
        box = regions[i]
        region = im.crop(box)
        # Derive a conservative visible-object box, then retain 40 px for soft shadows.
        mask = region.convert('L').point(lambda p: 255 if p < 228 else 0)
        bounds = mask.getbbox()
        if bounds is None:
            raise ValueError(f'No visible object in {aid}.')
        bx = [max(0,bounds[0]-40),max(0,bounds[1]-40),min(region.width,bounds[2]+40),min(region.height,bounds[3]+40)]
        tile = region.crop(bx)
        tile.thumbnail((864,864), Image.Resampling.LANCZOS)
        crop = Image.new('RGB',(1024,1024),'white')
        crop.paste(tile,((1024-tile.width)//2,(1024-tile.height)//2))
        clean.paste(crop,(col*1024,row*1024))
        dest = out/'parts'/f'{aid}.png'
        crop.save(dest)
        x, y = 68+col*1002, 332+row*1070
        d.rounded_rectangle((x, y, x+936, y+1020), radius=22, fill='white')
        thumb = crop.copy()
        thumb.thumbnail((874, 790), Image.Resampling.LANCZOS)
        board.paste(thumb, (x+(936-thumb.width)//2, y+24+(790-thumb.height)//2))
        d.text((x+40, y+824), aid, font=font(35, True), fill='#236E83')
        d.text((x+183, y+819), label, font=font(38, True), fill='#22373F')
        d.text((x+40, y+883), sub, font=font(29), fill='#5B6C72')
        d.text((x+40, y+938), '建议宽 × 深 × 高：' + dims, font=font(27), fill='#5B6C72')
        full_prompt = prompt + common
        (out/'parts'/f'{aid}_prompt.txt').write_text(full_prompt+'\n', encoding='utf-8')
        prompts.append(f'## {aid} {label}\n\n{full_prompt}\n')
        rows.append({'id': aid, 'label_zh': label, 'file': f'parts/{aid}.png', 'crop_xyxy': box,
                     'local_content_crop_xyxy':bx, 'normalization':'fit within 864px, centre on a white 1024px square; no shape edits',
                     'sha256': digest(dest), 'prompt': f'parts/{aid}_prompt.txt', 'route': 'optional_tripo_shape_exploration'})
    d.text((100, 2510), '总图用于集中查看；单件生成使用 parts/TR01–TR06.png，六件不是同一物体的多视角。', font=font(30), fill='#334E58')
    d.text((100, 2568), '尺寸为设计建议。AI 参考图不证明背面、拓扑和接口；接收后仍需 Blender 校正。', font=font(29), fill='#66767C')
    board.save(out/'tripo_parts_board.png')
    clean.save(out/'tripo_parts_clean.png')
    (out/'TRIPO_PROMPTS.md').write_text('# 六部件 Tripo 提示\n\n每个提示仅配对应单图，按 ID 保存结果。\n\n'+'\n'.join(prompts), encoding='utf-8')
    manifest = {'schema': 1, 'stage': 'image_reference_only', 'source_image': str(source),
                'source_sha256': digest(source), 'source_size': [w,h], 'layout': {'columns':3,'rows':2},
                'images': rows, 'notes': ['No Tripo service was called.', 'Images are AI concept reconstructions, not measured 3D assets.',
                                        'A contact sheet is not a guarantee of six separate models from one image-to-3D request.']}
    (out/'image_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'output':str(out),'source_size':[w,h],'parts':len(rows)},ensure_ascii=False))


if __name__ == '__main__':
    main()
