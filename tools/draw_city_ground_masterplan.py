"""Render the actual ground partition (including holes) for design review."""
import json, math, hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'docs/city_v5/ground_plan.json'
plan = json.loads(SRC.read_text(encoding='utf8'))
layout = json.loads((ROOT / 'docs/city_v5/layout.json').read_text(encoding='utf8'))
OUT = ROOT / 'docs/city_v5/ground_replan'
OUT.mkdir(exist_ok=True)
W,H = 2140,1920
im = Image.new('RGB', (W,H), '#f4f1e9')
d = ImageDraw.Draw(im)
font = lambda s: ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', s)
q = lambda p: (round(70+(p[0]+1010)*1.5), round(190+(p[1]-175)*1.5))
sea = '#b6d0d8'
d.rectangle((35,145,2105,1490), fill=sea)
levels = [(13,'#e2d8c4'),(18,'#dfc9a7'),(26,'#d1bb99'),(32,'#c3a888'),(38,'#b99a7e'),(44,'#aa8874'),(52,'#947268'),(60,'#80615d')]
def tone(y):
    return min(levels, key=lambda t:abs(t[0]-y))[1]
def polygon(face, color):
    mask = Image.new('1',(W,H),0)
    md=ImageDraw.Draw(mask)
    md.polygon([q(p) for p in face['polygon']],fill=1)
    for hole in face.get('holes',[]): md.polygon([q(p) for p in hole],fill=0)
    im.paste(color,(0,0),mask)
for f in plan['faces']:
    y=sum(v[1] for v in f['vertices'])/max(1,len(f['vertices']))
    color={'carriageway':'#6e797e','sidewalk':'#f5e9c9','promenade':'#e6be6c','park':'#6f9471'}.get(f['kind'],tone(y))
    polygon(f,color)
d=ImageDraw.Draw(im)
for b in layout['buildings']:
    x,z=b['c']; w,_,h=b['size']; a=math.radians(b['yaw'])
    poly=[q([x+math.cos(a)*dx+math.sin(a)*dz,z-math.sin(a)*dx+math.cos(a)*dz]) for dx,dz in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]]
    d.polygon(poly,fill='#5e5c61',outline='#373d42',width=1)
for p in plan['parks']:
    pts=p['polygon']; cx=sum(v[0] for v in pts)/len(pts); cz=sum(v[1] for v in pts)/len(pts)
    label='城市公园' if p['id']=='city_park' else '码头小公园'
    px,pz=q([cx,cz]); d.text((px-42,pz-10),label,font=font(19),fill='white',stroke_width=2,stroke_fill='#47624c')
for n,l in enumerate(plan['links'],1):
    a,b=l['axis']; pa,pb=q([a[0],a[2]]),q([b[0],b[2]])
    c='#c13e34' if l.get('buildingConflictArea',0)>0.01 else '#244e75'
    d.line([pa,pb],fill=c,width=7)
    x,y=pa;d.ellipse((x-13,y-13,x+13,y+13),fill=c)
    d.text((x-7,y-11),str(n),font=font(17),fill='white')
    x,y=pb;d.ellipse((x-4,y-4,x+4,y+4),fill=c)
for x,z,label in [(-810,265,'官邸台地 60 m'),(-575,285,'学院台地 44 m'),(-75,355,'市政商贸 26 m'),(-805,715,'圣堂台地 38 m'),(-465,608,'码头 13 m'),(95,860,'南城台地 18 m')]:
    px,pz=q([x,z]);d.rounded_rectangle((px-8,pz-5,px+len(label)*20,pz+31),radius=4,fill='#f4f1e9')
    d.text((px,pz),label,font=font(22),fill='#26373e')
d.text((45,30),'晴岚港｜全城地面分区与高差连接',font=font(37),fill='#24383d')
d.text((45,85),f"设计候选 {plan['version']} · 真实地面多边形及建筑占地 · 非游戏实景 · SHA256 {hashlib.sha256(SRC.read_bytes()).hexdigest()[:12]}",font=font(21),fill='#62747a')
box=(35,1530,2105,1855)
d.rounded_rectangle(box,radius=10,fill='#f5f2ea',outline='#8fa8ae',width=2)
d.text((65,1550),'图例与待处理项',font=font(25),fill='#26373e')
items=[('车道','#6e797e'),('人行道','#f5e9c9'),('滨海步道','#e6be6c'),('仅两处公园','#6f9471'),('建筑占地','#5e5c61')]
for i,(label,c) in enumerate(items):
    x=65+i*375;d.rectangle((x,1594,x+28,1620),fill=c,outline='#7b817d');d.text((x+38,1591),label,font=font(21),fill='#344b53')
d.text((65,1637),'台地标高：',font=font(20),fill='#344b53')
for i,(y,c) in enumerate(levels):
    x=230+i*200;d.rectangle((x,1640,x+27,1666),fill=c);d.text((x+33,1637),f'{y} m',font=font(19),fill='#344b53')
conflicts=[str(i) for i,l in enumerate(plan['links'],1) if l.get('buildingConflictArea',0)>0.01]
d.text((65,1687),'蓝色编号：连接候选；红色编号：与建筑冲突，必须调整。',font=font(21),fill='#344b53')
d.text((65,1724),'当前冲突编号：'+('、'.join(conflicts) or '无')+'。楼根与整街坊台面高程仍需统一，逐楼碎台不得保留。',font=font(21),fill='#9b4438')
d.text((65,1761),'覆盖图只证明用地归属；接缝高度、阶梯落点、护岸、入口与真实行走另行验收。',font=font(20),fill='#344b53')
d.text((65,1800),'公园以外全部为铺装陆域；保留河港水面。滨海步道沿岸连续，不跨港封水。',font=font(20),fill='#344b53')
d.text((45,1875),'方向：上北下南。深浅表示台地标高，建筑暂沿用现有占地；本阶段停止建筑和车站重做。',font=font(22),fill='#344b53')
im.save(OUT/'masterplan.png')
print(OUT/'masterplan.png')
