"""Measured design sections, not screenshots of implemented city geometry."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
R=Path(__file__).resolve().parents[1]
O=R/'docs/city_v5/ground_replan';O.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(1900,1420),'#f5f2eb');d=ImageDraw.Draw(im)
def font(n):return ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n)
def text(p,s,n=23,c='#26383d'):d.text(p,s,font=font(n),fill=c)
def box(x,y,w,h,c):d.rectangle((x,y,x+w,y+h),fill=c)
def line(points,c='#39494e',w=3):d.line(points,fill=c,width=w)
def arrow(a,b,label):
 line([a,b]);x,y=a;xx,yy=b
 line([(x+8,y-5),a,(x+8,y+5)]);line([(xx-8,yy-5),b,(xx-8,yy+5)])
 text(((x+xx)/2-d.textlength(label,font=font(21))/2,y-33),label,21)
text((65,36),'晴岚港 · 城市地面断面设计',40)
text((65,96),'实施前的设计示意｜连续实体地面，不把自然草坡染灰｜尺寸为本城游戏设计参数',23,'#65747a')

text((65,158),'01  主街：建筑—人行道—车道—人行道—建筑',28)
box(80,227,150,174,'#b9b0a2');box(1580,227,150,174,'#b9b0a2')
box(230,394,300,30,'#dfd5bd');box(1280,394,300,30,'#dfd5bd')
box(230,424,1350,79,'#c5b8a5');box(530,408,750,30,'#92989a')
line([(230,394),(530,394),(530,408),(1280,408),(1280,394),(1580,394)],'#5b5f5e',4)
for x in range(255,520,32):line([(x,395),(x,404)],'#b4a78d',2)
for x in range(1305,1570,32):line([(x,395),(x,404)],'#b4a78d',2)
arrow((250,294),(510,294),'人行道约 4 m');arrow((550,294),(1260,294),'主车道 14–18 m');arrow((1300,294),(1560,294),'人行道约 4 m')
text((287,336),'浅色大石板',22);text((823,356),'深灰整石铺装',22);text((1322,336),'浅色大石板',22)
text((590,452),'连续基础与匹配碰撞；下方地形不得穿出',23)
text((80,529),'路缘约 0.13–0.15 m；路口铺装连续收口，灯具放在通行净区以外。图中路缘高差放大表达。',22)

text((65,597),'02  台地：上层铺地—休息平台—台阶—下层铺地',28)
box(100,693,510,172,'#c2b6a1');box(100,686,510,14,'#e0d4bb')
stepx,stepy=31,8;xx,yy=610,686
poly=[(610,686)]
for i in range(20):
 if i==10:poly.extend([(xx+75,yy)]);xx+=75
 poly.extend([(xx,yy+stepy),(xx+stepx,yy+stepy)]);xx+=stepx;yy+=stepy
poly.extend([(1690,yy),(1690,890),(610,890)]);d.polygon(poly,fill='#d5c6aa')
line(poly[:-3], '#716b5f',3)
line([(595,676),(940,764),(1015,764),(1325,844)],'#966e50',4)
text((160,634),'上层：明确水平台面',22);text((1410,782),'下层台面',22)
text((1360,691),'踏面约 0.35 m',22);text((1360,731),'踢面约 0.15 m',22)
text((100,915),'每跑设休息平台；上下端都接实地。挡墙在台阶开口处断开，侧边收口，不横穿通道。',22)

text((65,982),'03  滨水：城市台地—连续步道—护岸—水面',28)
box(100,1090,545,148,'#c5b7a0');box(100,1080,545,18,'#dfd4bc')
box(645,1090,505,148,'#c5b7a0');box(645,1080,505,18,'#e3d9c5')
box(1150,1092,92,230,'#a7a197');box(1242,1196,476,126,'#91b5c0')
line([(1150,1090),(1242,1090)],'#e9e0cd',10)
line([(1148,1039),(1148,1083)],'#576267',4);line([(1124,1039),(1172,1039)],'#576267',4)
arrow((663,1036),(1128,1036),'滨海步道目标净宽 6–8 m')
text((180,1130),'同级铺装／明确下行台阶',24);text((734,1140),'连续石板步道',24);text((1340,1153),'保留真实水域',24)
text((80,1350),'绿地仅两处：城市公园、码头小公园。其余城内陆地均分配铺装与地基；不新增零散绿岛。',24)
im.save(O/'sections.png')
print(O/'sections.png')
