"""New station design and Tripo reference modules; does not replace the game.
All images come from the same measured assembly. Blank joining faces and open
vault ends are intentional. Rendered references are NOT Tripo-generated models.
"""
import sys,math,json,argparse
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
import landmarks as L
OUT=ROOT/'docs/city_v5/station_redesign';SRC=OUT/'source';MOD=OUT/'modules';VIEWS=OUT/'views'
L.PAL.update({'brick':'K|0|b58472||0','water':'K|9|6c9ea0||0'})
S={
 'M01_entrance_pavilion':dict(label='中央到达大厅',dimensions=[32,27,14],reuseCount=1,interfaces=['左右侧面 x=±16 为翼楼拼接面','后侧 z=7 接候车厅；14m门洞保持贯通'],notes='保留大拱门、上方采光窗和门廊；时钟冠饰另件，不把钟楼和大厅熔为一体。'),
 'M02_wing_bay':dict(label='服务翼楼标准开间',dimensions=[10,20,20],reuseCount=4,interfaces=['左右 x=±5 是无外挑装饰的拼接面','正面 z=-10；每个10m开间包含完整门窗节奏'],notes='票务、行李与旅客服务用同一标准开间复用；窗框随墙体整体生成。'),
 'M03_corner_pavilion':dict(label='翼端转角亭楼',dimensions=[16,28,22],reuseCount=2,interfaces=['朝中央大厅的一侧与翼楼接合','正面 z=-11；右侧版本通过旋转/适当镜像组装'],notes='带转角壁柱、陡屋面和小型采光冠；它是横向站房的收尾，不是独立高塔。'),
 'M04_vault_segment':dict(label='候车厅拱顶标准段',dimensions=[32,9,10],reuseCount=4,interfaces=['前后 z=±5 都保持开口','拱脚 x=±16,y=0；按10m节距连续拼接'],notes='包含完整钢拱、檩条和青色玻璃壳；禁止把端面封成实体墙。'),
 'M05_vault_end':dict(label='候车厅后端拱窗',dimensions=[32,17,1.2],reuseCount=1,interfaces=['顶部半椭圆拱与M04同宽32m','下部保留28m宽双股轨道通口，不得封堵','后端底面放在二层站台标高13.4m'],notes='端墙与拱顶分件；玻璃区清晰分格，不要生成一整块不透明石墙。'),
 'M06_platform_canopy':dict(label='站台雨棚标准段',dimensions=[14,6.5,10],reuseCount=6,interfaces=['前后 z=±5 开放，可按10m重复','柱脚以模块底面y=0为基准'],notes='整段生成柱、梁和折线屋盖，保持柱间可通行；不要自动加地面和列车。'),
 'M07_stair_gallery':dict(label='通往高架站台的双跑楼梯',dimensions=[12,15,20],reuseCount=2,interfaces=['下层入口楼面y=0，二层楼面y=13.4','上下出入口在前侧，两个楼梯方向相反'],notes='以图保留双跑、平台和栏杆。Tripo外观件回收后须重新制作精确台阶/平滑碰撞。'),
 'M08_clock_crest':dict(label='中央时钟与翼饰冠',dimensions=[12,11,3],reuseCount=1,interfaces=['下方平直底座，居中装在M01屋顶前缘','正面朝-Z，背面不添加支架以外的建筑'],notes='重点精修模块：深浮雕表盘、金属指针、双翼与海港纹章；不要生成文字。'),
 'M09_entry_steps':dict(label='正门台阶与中间缓坡',dimensions=[24,.6,5],reuseCount=1,interfaces=['前缘y=-0.6；后缘y=0接大厅','中央4m净宽缓坡，两侧三级台阶'],notes='精确土木件建议最终Blender重建，Tripo可用于石材表面参考；切勿把台阶熔成乱石。'),
 'M10_plaza_lamp':dict(label='站前成组双臂灯',dimensions=[3.6,6.2,1.4],reuseCount=8,interfaces=['底面中心为安装点','保留两灯的对称朝向与实体底座'],notes='两盏灯与灯柱作为完整单件；生成时不带地面、不带其他建筑。'),
 'M11_relief_roundel':dict(label='海港铁路徽章浮雕',dimensions=[3.2,3.2,.5],reuseCount=4,interfaces=['背面为平面，正面朝-Z','安装在门楣/翼端空白徽章位'],notes='海翼与轮轨意象的浅浮雕，避免文字；与时钟冠分开，方便复用。'),
}

def entry(b):
 b.box(0,-.65,0,32,1.1,14,'rustic',True);b.box(0,-.12,0,32,.24,14,'floor',True)
 for z in (-7,7):b.opening_wall(0,z,0,32,20,14,0,15,True,False,1.4,'stone')
 for x in (-15.4,15.4):b.box(x,10,0,1.2,20,12.58,'stone',True)
 b.pediment(0,-7.8,32,20,6,'stone');b.rose(0,22.5,-8.35,2.1)
 for x in (-12,-8,8,12):b.column(x,-8,0,14,.65)
 b.box(0,14.5,-8,28,.8,3,'trim');b.gable(0,0,33,15,20.4,6,'slate')
 for x in (-12,12):b.box(x,17.2,-7.9,5,2.6,.2,'brick')
 # Clerestory is a visible glazing insert, not an empty upper blank wall.
 b.opening_wall(0,-7.78,15.5,12,4.2,10,.3,3.3,False,True,.18,'stone',False)
 b.box(0,17.45,-7.96,10,3.3,.10,'glass')
 for x in (-2.5,0,2.5):b.box(x,17.45,-8.04,.1,3.3,.12,'bronze')
 b.box(0,17.45,-8.04,10,.12,.12,'bronze')
def wing(b):
 # Flat joint faces let successive bays form one wing, not four little houses.
 b.box(0,-.65,0,10,1.1,20,'rustic',True);b.box(0,-.12,0,10,.24,20,'floor',True)
 for z,angle in [(-10,0),(10,math.pi)]:b.pose=(0,0,0,angle);b.facade(10,14,-10,2,False,False,'limestone',2)
 b.pose=(0,0,0,0)
 profile=[(-10.45,14.5),(-7.2,19.1),(7.2,19.1),(10.45,14.5)]
 vs=[(x,y,z) for x in (-5,5) for z,y in profile]
 b.mesh(vs,[(i,i+1,i+5,i+4) for i in range(3)],'slate')
 b.box(0,14.5,0,10,.25,20,'stone',True)
 for z in (-7.2,7.2):b.box(0,19.1,z,10,.18,.18,'gold')
 # No independent side facade: interior joint is a straight thin wall only above floor.
 for x in (-5,5):b.box(x,7,0,.15,14,20,'limestone')
 # Trim to the measured joint planes; ornamental cornices must not overrun neighbors.
 for mat,(vs,fs) in b.parts.items():
  b.parts[mat][0]=[(max(-5,min(5,x)),y,z) for x,y,z in vs]
def corner(b):
 b.shell(0,0,16,22,17,True,False,3,'stone',3,False,False,5)
 b.mansard(0,0,16,22,17.6,7,'slate');b.dome(0,0,24,2.2,2.4,'copper',1)
 b.pediment(0,-11.8,13,17.4,3.5,'stone')
 for x in (-6,6):b.column(x,-11.5,0,11,.5)
def vault(b):
 b.barrel(0,0,32,10,0,8,'glass')
 for a in (math.pi/6,math.pi/3,math.pi/2,2*math.pi/3,5*math.pi/6):
  b.box(16*math.cos(a),8*math.sin(a)+.04,0,.12,.14,10,'bronze')
 for z in (-5,5):
  for i in range(16):
   a=i*math.pi/16;c=(i+1)*math.pi/16
   b.beam((16*math.cos(a),8*math.sin(a),z),(16*math.cos(c),8*math.sin(c),z),.38,.45,'bronze')
 for x in (-16,16):b.box(x,-.3,0,.8,.6,10,'stone')
def end(b):
 b.opening_wall(0,0,0,32,8.6,28,0,8.3,True,False,1.2,'stone')
 b.extrude([(-16,8.6),(16,8.6)]+[(16*math.cos(i*math.pi/32),8.6+8*math.sin(i*math.pi/32)) for i in range(1,33)],0,.16,'glass')
 for z in (-.2,.2):
  for x in (-12,-8,-4,0,4,8,12):b.box(x,8.6+4*math.sqrt(1-x*x/256),z,.2,8*math.sqrt(1-x*x/256),.16,'bronze')
  b.box(0,11.2,z,30,.18,.16,'bronze')
def canopy(b):
 for x in (-5.5,5.5):
  for z in (-4,4):
   b.column(x,z,0,4.8,.28,'bronze');b.beam((x,3.1,z),(x*.3,5.1,z),.22,.25,'bronze')
 b.gable(0,0,14,10,4.9,1.4,'copper')
 for x in (-7,7):b.box(x,4.9,0,.2,.3,10,'gold')
def stair(b):
 rise=6.7;steps=34;run=14
 b.box(0,-.18,0,12,.36,20,'floor',True)
 for i in range(steps):
  h=(i+1)*rise/steps;z=-9+(i+.5)*run/steps
  b.box(-3,h/2,z,4.8,h,run/steps,'stone',True)
  z=5-(i+.5)*run/steps;b.box(3,(rise+h)/2,z,4.8,rise+h,run/steps,'stone',True)
 b.box(0,rise-.2,7,12,.4,4,'floor',True);b.box(3,13.2,-9.5,4.8,.4,1,'floor',True)
 for x in (-5.6,-.4):b.beam((x,1,-9),(x,7.7,5),.13,.13,'bronze')
 for x in (.4,5.6):b.beam((x,7.7,5),(x,14.4,-9),.13,.13,'bronze')
 for i in range(8):
  z=-9+2*i;h=(z+9)/14*rise
  for x in (-5.6,-.4):b.cylinder(x,h,z,.055,1,'bronze',8)
  for x in (.4,5.6):b.cylinder(x,13.4-h,z,.055,1,'bronze',8)
def clock(b):
 b.box(0,.4,0,12,.8,3,'stone');b.pediment(0,0,10,.8,8.8,'stone');b.clock(0,4.4,-.65,3.2)
 for sx in (-1,1):
  for i in range(4):b.extrude([(sx*2,5.1+i*.38),(sx*(5.2-i*.35),5.4+i*.6),(sx*(5.8-i*.35),5.9+i*.6),(sx*2,5.42+i*.38)],-.78-i*.12,.18,'gold')
 b.cylinder(0,9,0,.18,1.2,'gold',12);b.cylinder(0,10.2,0,.6,.7,'copper',12,rt=0)
def steps(b):
 for i in range(3):
  length=5-i*1.4;top=-.4+i*.2
  for side in (-1,1):b.box(side*7,(top-.6)/2,-length/2,10,top+.6,length,'stone',True)
 b.mesh([(-2,-.6,-5),(2,-.6,-5),(2,0,0),(-2,0,0)],[(0,1,2,3)],'floor')
def lamp(b):
 b.cylinder(0,0,0,.45,.5,'stone',12);b.cylinder(0,.5,0,.16,4.7,'bronze',12,rt=.11)
 for sx in (-1,1):
  b.beam((0,4.2,0),(sx*1.4,5.2,0),.14,.14,'bronze')
  b.box(sx*1.4,5.25,0,.65,.8,.65,'glass');b.cylinder(sx*1.4,5.65,0,.53,.35,'bronze',8,rt=0)
  for zz in (-.34,.34):
   for xx in (-.34,.34):b.box(sx*1.4+xx,5.25,zz,.06,.8,.06,'bronze')
 b.cylinder(0,5.2,0,.2,1,'gold',12,rt=0)
def relief(b):
 b.extrude([(1.6*math.sin(i*math.tau/32),1.6+1.6*math.cos(i*math.tau/32)) for i in range(32)],0,.22,'stone')
 b.clock(0,1.6,-.22,1.05)
 for sx in (-1,1):
  for i in range(3):b.extrude([(sx*.45,1.4+i*.3),(sx*1.42,1.6+i*.34),(sx*1.25,1.85+i*.34),(sx*.45,1.63+i*.3)],-.42-i*.12,.1,'gold')
MAKERS=dict(zip(S,[entry,wing,corner,vault,end,canopy,stair,clock,steps,lamp,relief]))

def make_module(key):
 b=L.Builder(key);MAKERS[key](b);obs=[]
 for mat,(v,f) in b.parts.items():obs.append(L.create_mesh(key+'_'+mat,v,f,mat))
 return obs
def setup_scene(name):
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.name=name;sc.unit_settings.system='METRIC'
 sc.render.engine='CYCLES';sc.cycles.samples=12;sc.cycles.use_denoising=True
 sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
 sc.view_settings.view_transform='AgX'
 w=bpy.data.worlds.new('Neutral studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.75,.78,.82,1);w.node_tree.nodes['Background'].inputs[1].default_value=.55;sc.world=w
 sun=bpy.data.lights.new('Soft daylight','SUN');sun.energy=2.8;sun.angle=.22
 ob=bpy.data.objects.new('Soft daylight',sun);sc.collection.objects.link(ob);ob.rotation_euler=(.45,-.5,-.45)
 ca=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',ca);sc.collection.objects.link(cam);ca.type='ORTHO';sc.camera=cam
 return sc,cam
def bounds(obs):
 vv=[L.gp(o.matrix_world@Vector(v)) for o in obs for v in o.bound_box]
 lo=[min(v[i] for v in vv) for i in range(3)];hi=[max(v[i] for v in vv) for i in range(3)];return lo,hi
def shot(sc,cam,obs,path,view='hero',wide=False):
 bpy.context.view_layer.update();lo,hi=bounds(obs);c=Vector([(lo[i]+hi[i])/2 for i in range(3)]);size=[hi[i]-lo[i] for i in range(3)];r=max(size)
 directions={'hero':(1.25,.85,-1.65),'front':(0,0,-2),'back':(0,0,2),'right':(2,0,0),'top':(0,2,0),'rear_hero':(-1,.85,1.6)}
 vec=Vector(directions[view]);cam.location=L.bp(c+vec*r);target=Vector(L.bp(c));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 aspect=1.6 if wide else 1;sc.render.resolution_x=1600 if wide else 1024;sc.render.resolution_y=1000 if wide else 1024
 cam.data.ortho_scale=(max(size[0],size[1]*aspect) if view in ('front','back') else max(size[2],size[1]*aspect) if view=='right' else max(size[0],size[2]*aspect) if view=='top' else r*1.4)*1.16
 sc.render.filepath=str(path);bpy.ops.render.render(write_still=True)
def duplicate_module(src,name,pos):
 out=[]
 for ob in src:
  n=ob.copy();n.data=ob.data; n.name=name+'_'+ob.name; bpy.context.scene.collection.objects.link(n);n.location=L.bp(pos);out.append(n)
 return out
def main():
 p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=list(S));p.add_argument('--skip-modules',action='store_true');p.add_argument('--skip-overall',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 for d in (OUT,SRC,MOD,VIEWS):d.mkdir(parents=True,exist_ok=True)
 previous=json.loads((OUT/'manifest.json').read_text(encoding='utf8')) if (OUT/'manifest.json').exists() else {}
 existing={m['id']:m for m in previous.get('modules',[])};modules=[]
 for key in a.only or S:
  row=dict(existing.get(key,{}),**S[key],id=key,views={v:f'modules/{key}/{v}.png' for v in ['hero','front','right','back','top']})
  if not a.skip_modules:
   sc,cam=setup_scene(key);obs=make_module(key);d=MOD/key;d.mkdir(exist_ok=True)
   bpy.context.view_layer.update();lo,hi=bounds(obs);row['actualBounds']={'min':lo,'max':hi};row['actualDimensions']=[round(hi[i]-lo[i],3) for i in range(3)]
   bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(key+'.blend')))
   for v in ['hero','front','right','back','top']:shot(sc,cam,obs,d/(v+'.png'),v)
  modules.append(row);print('STATION_MODULE_DONE',key,flush=True)
 if not a.skip_overall:
  sc,cam=setup_scene('New Qinglan Central Station design')
  source={key:make_module(key) for key in S};all_originals=[o for obs in source.values() for o in obs]
  for ob in all_originals:ob.hide_render=True
  placements=[];assembly=[];groups=[]
  def place(key,pos):
   obs=duplicate_module(source[key],key+' instance',pos)
   for ob in obs:ob.hide_render=False
   assembly.extend(obs);placements.append({'module':key,'position':pos,'yaw':0});groups.append((key,pos,obs))
  place('M01_entrance_pavilion',[0,0,-21])
  for x in (-31,-21,21,31):place('M02_wing_bay',[x,0,-18])
  for x in (-44,44):place('M03_corner_pavilion',[x,0,-17])
  for z in (-7,3,13,23):place('M04_vault_segment',[0,22,z])
  place('M05_vault_end',[0,13.4,28])
  for x in (-25,25):
   for z in (-2,8,18):place('M06_platform_canopy',[x,13.4,z])
   place('M07_stair_gallery',[x,0,6])
  place('M08_clock_crest',[0,26,-29]);place('M09_entry_steps',[0,0,-28])
  for x in (-46,-24,24,46):
   for z in (-39,-55):place('M10_plaza_lamp',[x,-.6,z])
  for x in (-44,-11,11,44):place('M11_relief_roundel',[x,17,-28.6])
  # Essential site geometry stays Blender-authored, outside Tripo decorative modules.
  b=L.Builder('Site and platform skeleton')
  b.box(0,-1.3,-9,114,1.3,110,'rustic')
  b.box(0,-.74,-47,108,.28,34,'stone')
  b.box(0,-.565,-47,18,.07,34,'floor')
  for x in (-50,-42,-34,-26,-18,18,26,34,42,50):
   b.box(x,-.593,-47,.07,.018,34,'rustic')
  for z in (-61,-53,-45,-37):b.box(0,-.593,z,108,.018,.07,'rustic')
  # Elevated rail deck; two running tracks terminate behind the entrance block.
  b.box(0,12.6,16,32,1.6,56,'rustic')
  for tx in (-8,8):
   b.box(tx,13.45,16,5,.1,56,'shadow')
   for z in range(-10,45,2):b.box(tx,13.6,z,4,.24,.38,'wood')
   for dx in (-1,1):b.box(tx+dx,13.83,16,.16,.22,56,'bronze')
   b.box(tx,14.4,-11,4,.45,.5,'red')
  # Each slab surrounds a real stair well, with 3m clear side walks.
  for x in (-25,25):
   for sx in (-7.5,7.5):b.box(x+sx,13.05,6,3,.7,44,'floor')
   for z,d in ((-10,12),(22,12)):b.box(x,13.05,z,12,.7,d,'floor')
   for z in (-12,10,25):
    for sx in (-7.5,7.5):b.column(x+sx,z,0,12.7,.75,'stone')
   # Railings on outer platform edge and around the well; leave upper landing open.
   for edge in (-6,6):
    b.box(x+edge,14.45,6,.10,.12,20,'bronze')
    for z in range(-3,17,2):b.cylinder(x+edge,13.4,z,.055,1.05,'bronze',8)
   b.box(x,14.45,16,12,.12,.1,'bronze')
   for z in range(-15,28,3):b.cylinder(x+(-9 if x<0 else 9),13.4,z,.06,1.15,'bronze',8)
   b.box(x+(-9 if x<0 else 9),14.55,6,.12,.12,44,'bronze')
  # Station side walls carry the high vault; open ground aisle remains 30m wide.
  for x in (-16,16):
   for z in (-7,3,13,23):
    b.box(x,10.8,z,1,21.6,1.4,'stone');b.box(x,21.6,z,1.4,.8,10,'trim')
  for x in (-36,36):
   b.box(x,-.4,-49,12,.4,10,'rustic');b.box(x,-.1,-49,11.2,.2,9.2,'copper')
  for mat,(v,f) in b.parts.items():assembly.append(L.create_mesh('Site_'+mat,v,f,mat))
  for ob in all_originals:bpy.data.objects.remove(ob,do_unlink=True)
  bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'Station_assembled_design.blend'))
  for v in ['hero','front','right','back','top','rear_hero']:shot(sc,cam,assembly,VIEWS/(v+'.png'),v,True)
  # Exploded assembly is explanatory only, never used as a Tripo image input.
  for key,pos,obs in groups:
   offset=(0,0,0)
   if key.startswith('M01'):offset=(0,0,-18)
   elif key.startswith('M02'):offset=(14 if pos[0]>0 else -14,0,-8)
   elif key.startswith('M03'):offset=(30 if pos[0]>0 else -30,0,0)
   elif key.startswith('M04'):offset=(0,18,0)
   elif key.startswith('M05'):offset=(0,5,22)
   elif key.startswith('M06'):offset=(12 if pos[0]>0 else -12,10,0)
   elif key.startswith('M07'):offset=(10 if pos[0]>0 else -10,0,4)
   elif key.startswith('M08'):offset=(0,18,-18)
   elif key.startswith('M09'):offset=(0,0,-20)
   elif key.startswith('M11'):offset=(0,0,-21)
   for ob in obs:ob.location+=Vector(L.bp(offset))
  shot(sc,cam,assembly,VIEWS/'exploded.png','hero',True)
  (OUT/'assembly.json').write_text(json.dumps({'units':'metres','stationNativeFootprint':[104,56],'groundFloor':0,'streetGrade':-.6,'raisedPlatformFloor':13.4,'placements':placements,'status':'Design candidate only; not installed in production game'},ensure_ascii=False,indent=2),encoding='utf8')
 updated={m['id']:m for m in modules};merged=[updated.get(key,existing.get(key)) for key in S];modules=[m for m in merged if m]
 manifest={'title':'晴岚中央车站 · 重设计与Tripo构件包','version':'station-concept-3','status':'设计视图，等待用户逐件Tripo生成；未替换游戏车站','units':'m','axes':'Godot X width / Y up / Z depth; front -Z. Blender Z up / +Y front.','overallViews':{v:f'views/{v}.png' for v in ['hero','front','right','back','top','rear_hero','exploded']},'modules':modules,'recommendedOrder':['M01_entrance_pavilion','M02_wing_bay','M03_corner_pavilion','M04_vault_segment','M08_clock_crest','M06_platform_canopy','M05_vault_end','M07_stair_gallery','M09_entry_steps','M10_plaza_lamp','M11_relief_roundel'],'pipelineNote':'All views are actual Blender renders of one new design. Tripo is performed by the user. Measured joints and collision geometry must be corrected after generation.'}
 (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
 print('STATION_DESIGN_DONE',flush=True)
if __name__=='__main__':main()
