import json,math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1];p=json.loads((R/'docs/city_v5/layout.json').read_text(encoding='utf8'))
im=Image.new('RGB',(1800,1500),'#e8e4d4');d=ImageDraw.Draw(im);f=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
def q(v):return ((v[0]+1040)*1.22+35,(v[1]-145)*1.22+75)
def rect(c,s):
    return [q([c[0]-s[0]/2,c[1]-s[1]/2]),q([c[0]+s[0]/2,c[1]+s[1]/2])]
d.polygon([q(v) for v in [[-1040,160]]+p['coast_west']+[[-1040,1200]]],fill='#78a9bd')
d.polygon([q(v) for v in p['coast_south']+[[520,1200],[-1040,1200]]],fill='#78a9bd')
for i,t in enumerate(p['terraces']):
    d.rectangle(rect(t['c'],t['size']),fill=['#b8be9d','#c8c3a1','#dfd8c1','#bbc2aa','#ddd6c0','#cec6ad'][i%6]);d.text(q([t['c'][0]-t['size'][0]/2,t['c'][1]-t['size'][1]/2]),f"{t['id']} {t['y']}m",font=f,fill='#676651')
d.line([q(v) for v in p['river']],fill='#78a9bd',width=63)
for r in p['roads']:
    d.line([q(v) for v in r['pts']],fill='#fcf1cf',width=round((r['width']+2*r['walk'])*1.22));d.line([q(v) for v in r['pts']],fill='#a8a39b',width=round(r['width']*1.22))
for s in p['squares']:d.rectangle(rect(s['c'],s['size']),fill='#eadcba',outline='#c9b791',width=1)
for g in p['gardens']:d.rectangle(rect(g['c'],g['size']),fill='#9eb886',outline='#668955',width=2)
for b in p['buildings']:
    a=math.radians(b['yaw']);w,_,h=b['size'];x,z=b['c'];poly=[]
    for dx,dz in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]:poly.append(q([x+math.cos(a)*dx+math.sin(a)*dz,z-math.sin(a)*dx+math.cos(a)*dz]))
    d.polygon(poly,fill='#7e617a' if b['family']=='landmarks' else '#bc8c67',outline='#674c40')
    en=q([x-math.sin(a)*h/2,z-math.cos(a)*h/2]);d.ellipse([en[0]-3,en[1]-3,en[0]+3,en[1]+3],fill='white')
    if b['label']:d.text(q([x-w/2,z-h/2-17]),b['label'],font=f,fill='#302d29')
d.line([q(v) for v in p['wall']],fill='#635e58',width=8)
for _,x,z,y in p['gates']:d.ellipse([q([x-17,z-17]),q([x+17,z+17])],outline='#b3554c',width=4)
for s in p['spawns']:
    x,y=q(s['p']);d.ellipse([x-4,y-4,x+4,y+4],fill='#e12335')
d.text((30,14),'晴岚港 v5 · 地块 / 道路 / 前庭 / 台地 初稿（单位：米；白点为主入口）',font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',26),fill='#242929')
d.text((30,1428),f"原生建筑 {len(p['buildings'])} 栋；紫色=地标；棕色=住宅及街区设施；绿色=园地；红点=到达锚点",font=f,fill='#242929')
im.save(R/'docs/city_v5/layout.png')
print(R/'docs/city_v5/layout.png')
