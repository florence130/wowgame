"""Create a labeled visual comparison without cropping or retouching frames."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,hashlib
ROOT=Path('E:/wowgame');OUT=ROOT/'output/sanctum_blender_20261012';OUT.mkdir(parents=True,exist_ok=True)
SHOTS=ROOT/'.shots/sanctum_blender_repaired'
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',24)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
def panel(board,path,rect,title,caption):
    x,y,w,h=rect;draw=ImageDraw.Draw(board)
    draw.text((x+14,y+10),title,font=font,fill='#eee8d8')
    im=Image.open(path).convert('RGB');im.thumbnail((w-28,h-90),Image.Resampling.LANCZOS)
    board.paste(im,(x+(w-im.width)//2,y+52+(h-90-im.height)//2))
    draw.text((x+14,y+h-30),caption,font=small,fill='#b6b9b4')
comparison=Image.new('RGB',(1600,1130),'#222b30')
panel(comparison,ROOT/'output/imagegen/sanctum_ocean_ruin_20261012/07_sea_nave_flat.png',(0,0,800,565),'目标参考图','概念画：作为造型与气氛目标')
panel(comparison,ROOT/'.shots/sanctum_blender_v1/reference_nave.png',(800,0,800,565),'你指出的问题：旧版矮拱顶','旧游戏截图，净高约15m')
panel(comparison,SHOTS/'reference_nave.png',(0,565,800,565),'Blender重建后：旧机位、60°视场','约29m净高；角色原生尺寸。保存场景截图，无修图。')
panel(comparison,SHOTS/'nave_altar.png',(800,565,800,565),'Blender重建后：后殿','实体结构、高窗开口及阴影；整体美术仍待完善。')
comparison.save(OUT/'comparison.png')
details=Image.new('RGB',(1600,1130),'#222b30')
for i,(name,title,caption) in enumerate([
    ('nave_altar','后殿与祭坛','同套石材、高窗、尖拱、藤蔓与实体窗光'),
    ('apse_spring_16m','首领区：16m远镜头','原生SpringArm固定位置探测；不是战斗截图'),
    ('rat_stores','地下旧供物库','覆土与实体屋顶保留；地下尚需继续细化'),
    ('departure_bell','出航钟台','补破损边角与侵藤；整体建筑造型尚待完善')]):
    panel(details,SHOTS/(name+'.png'),((i%2)*800,(i//2)*565,800,565),title,caption)
details.save(OUT/'details.png')
paths=[ROOT/'assets/models/sanctum_blender_ruin/sea_temple_ruin.blend',ROOT/'assets/models/sanctum_blender_ruin/sea_temple_structure.glb',ROOT/'assets/models/sanctum_blender_ruin/sea_temple_ruin.glb',SHOTS/'report.json',SHOTS/'reference_nave.png',ROOT/'.shots/sanctum_blender_repaired_combat/combat_report.json',ROOT/'.local/sanctum_blender_repaired_route.log',ROOT/'.local/sanctum_blender_repaired_scripts.log',OUT/'comparison.png',OUT/'details.png']
manifest={str(p.relative_to(ROOT)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('REVIEW_CREATED',str(OUT))
