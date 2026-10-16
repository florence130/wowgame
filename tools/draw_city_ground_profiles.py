"""Draw real, coordinate-bound sections from the emitted ground triangles."""
import json,math,sys,hashlib
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.local/city_v5/audit_deps'))
from shapely.geometry import Polygon,Point
from shapely import STRtree
src=ROOT/'docs/city_v5/ground_plan.json'
p=json.loads(src.read_text(encoding='utf8'))
geo=[];tri=[];kinds=[]
for face in p['faces']:
    vs=face['vertices']
    for inds in face['triangles']:
        t=[vs[i] for i in inds];a=Polygon([(v[0],v[2]) for v in t])
        if a.area<1e-8:continue
        geo.append(a);tri.append(t);kinds.append(face['kind'])
tree=STRtree(geo)
def sample(x,z):
    pt=Point(x,z);hits=[]
    for i in tree.query(pt):
        if not geo[i].buffer(.000001).covers(pt):continue
        a,b,c=tri[i];den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
        if abs(den)<1e-9:continue
        u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
        v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den
        hits.append((u*a[1]+v*b[1]+(1-u-v)*c[1],kinds[i]))
    return max(hits) if hits else None
cuts=[dict(id='A-A',label='市政厅—前庭—内部步道—主街',a=[-180,295],b=[-180,410])]
links=[l for l in p.get('links',[]) if l.get('axis') and len(l['axis'])>=2 and abs(l['axis'][0][1]-l['axis'][-1][1])>1]
if links:
    l=max(links,key=lambda l:abs(l['axis'][0][1]-l['axis'][-1][1]));a,b=l['axis'][0],l['axis'][-1];dx,dz=b[0]-a[0],b[2]-a[2];n=math.hypot(dx,dz)
    cuts.append(dict(id='B-B',label=l['id']+' 上下台地与连接',a=[a[0]-dx/n*5,a[2]-dz/n*5],b=[b[0]+dx/n*5,b[2]+dz/n*5]))
else:cuts.append(dict(id='B-B',label='学院南侧原失配点复查（尚无定稿阶梯）',a=[-560,395],b=[-560,470]))
rows=[]
for cut in cuts:
    a,b=cut['a'],cut['b'];length=math.dist(a,b);samples=[]
    for k in range(501):
        t=k/500;x=a[0]+(b[0]-a[0])*t;z=a[1]+(b[1]-a[1])*t;r=sample(x,z)
        samples.append(dict(distance=length*t,x=x,z=z,y=r[0] if r else None,kind=r[1] if r else 'gap'))
    rows.append(dict(**cut,length=length,samples=samples))
W,H=1800,1150;im=Image.new('RGB',(W,H),'#f5f2ea');d=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n)
d.text((50,30),'晴岚港｜实际地面剖切',font=font(34),fill='#263f43')
d.text((50,84),f"{p['version']} · 按已生成三角面逐点插值 · SHA256 {hashlib.sha256(src.read_bytes()).hexdigest()[:12]}",font=font(20),fill='#6c7c7b')
colors={'carriageway':'#596f79','sidewalk':'#a58645','curb':'#8d7852','pedestrian':'#557f75','terrace':'#957c67','promenade':'#b18843','park':'#6f9270','stairs':'#ab624a','ramp':'#986952'}
for n,row in enumerate(rows):
    top=170+n*455; a,b=row['a'],row['b']; ss=row['samples'];ys=[s['y'] for s in ss if s['y'] is not None];lo=math.floor(min(ys)-1);hi=math.ceil(max(ys)+1);span=max(2,hi-lo)
    d.text((50,top),row['id']+'  '+row['label'],font=font(25),fill='#263f43')
    d.text((50,top+39),f"起点 X {a[0]:.1f} / Z {a[1]:.1f} → 终点 X {b[0]:.1f} / Z {b[1]:.1f}，总长 {row['length']:.1f} m",font=font(18),fill='#687e7a')
    left,right=110,1720;yt,yb=top+100,top+340
    X=lambda v:left+v/row['length']*(right-left)
    Y=lambda v:yb-(v-lo)/span*(yb-yt)
    for j in range(5):
        y=lo+span*j/4; yy=Y(y);d.line((left,yy,right,yy),fill='#d6d9cf',width=1);d.text((25,yy-12),f'{y:.2f}',font=font(15),fill='#687e7a')
    for s,t in zip(ss,ss[1:]):
        if s['y'] is None or t['y'] is None:continue
        x1,x2=X(s['distance']),X(t['distance']);y1,y2=Y(s['y']),Y(t['y']);d.polygon([(x1,y1),(x2,y2),(x2,yb),(x1,yb)],fill='#ded0b7');d.line((x1,y1,x2,y2),fill=colors.get(s['kind'],'#856b56'),width=4)
    for j in range(6):
        v=row['length']*j/5;xx=X(v);d.text((xx-16,yb+13),f'{v:.1f}',font=font(16),fill='#687e7a')
    gaps=sum(s['y'] is None for s in ss)
    d.text((110,yb+43),f"水平距离 / m；高程 / m（纵横比例不一致） · 501 个采样点 · 无地面点 {gaps}",font=font(18),fill='#687e7a')
d.text((50,1090),'本图反映当前候选真实顶面；不包含建筑外壳、挡墙立面和游戏角色。阶梯最终落点仍须按完整连接实走。',font=font(20),fill='#687e7a')
out=ROOT/'docs/city_v5/ground_replan'
im.save(out/'actual_sections.png')
(out/'actual_sections.json').write_text(json.dumps(dict(version=p['version'],sourceHash=hashlib.sha256(src.read_bytes()).hexdigest(),cuts=rows),ensure_ascii=False,indent=2),encoding='utf8')
print(out/'actual_sections.png')
