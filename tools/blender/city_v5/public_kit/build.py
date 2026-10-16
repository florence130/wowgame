"""Purpose-designed civic kit; metric modular sources and evaluated game exports.

Uses the established ten-method vocabulary by suitability, retaining real
Mirror/Array/Solidify/Screw/SimpleDeform/Curve modifiers in the source .blend.
Godot XYZ authored, translated once into Blender Z-up. No legacy tower reuse.
"""
from pathlib import Path
from collections import defaultdict
import sys, math, json, argparse, time
import bpy, bmesh
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent))
import landmarks as L
OUT=ROOT/'assets/models/city_v5/landmarks'
DOC=ROOT/'docs/city_v5/public_kit'
L.PAL.update({'brick':'K|0|b7836c|st_masonry|3.0','water':'K|9|63a9ac||0',
              'ivory':'K|0|dfdbc5|st_plaster|3.0','indigo':'K|0|65769e|st_plaster|3.0'})

SPECS={
 'portal_hall':dict(label='星门传送大厅',footprint=[32,28],body_height=16,max_height=29,entry_width=8,entries=[[0,0,-14]],concept='Broad vaulted terminal, three portal bays, luminous oculus; no tower'),
 'mage_guild':dict(label='群星法师院',footprint=[44,32],body_height=16,max_height=30,entry_width=10,entries=[[0,0,-16]],concept='Open scholarly court, two low study wings and rear observatory hall'),
 'roman_baths':dict(label='晴岚帝国浴场',footprint=[64,44],body_height=17,max_height=27,entry_width=10,entries=[[0,0,-22]],concept='Roman thermae: basilical hall, paired vaulted bathing rooms, open natatio courts and colonnades'),
 'tax_hall':dict(label='税务计量厅',footprint=[28,24],body_height=14,max_height=21,entry_width=6,entries=[[0,0,-12]],concept='Rusticated loggia, steep treasury roof, counting-window rhythm and relief balance'),
 'welfare_court':dict(label='市民保障院',footprint=[32,28],body_height=9,max_height=16,entry_width=8,entries=[[0,0,-14]],concept='Welcoming low courtyard institution with sheltered benches and community fountain'),
 'court_hall':dict(label='海港裁定厅',footprint=[44,28],body_height=18,max_height=26,entry_width=8,entries=[[0,0,-14]],concept='Severe giant-order portico, stepped pediment and solid judicial chamber'),
 'exchange_hall':dict(label='商贸交易所',footprint=[44,28],body_height=13,max_height=23,entry_width=8,entries=[[0,0,-14]],concept='Glass-vault trading gallery between lower merchant wings'),
 'hospital_hall':dict(label='圣堂医院',footprint=[44,28],body_height=12,max_height=22,entry_width=8,entries=[[0,0,-14]],concept='Two ward wings and a sheltered healing garden, small central chapel roof'),
 'customs_hall':dict(label='港务海关',footprint=[44,28],body_height=14,max_height=22,entry_width=8,entries=[[0,0,-14]],concept='Brick inspection loggia, deep cargo arches and a weighbridge canopy'),
 'passenger_hall':dict(label='海运客运厅',footprint=[44,28],body_height=12,max_height=23,entry_width=10,entries=[[0,0,-14]],concept='Long glazed concourse, broad arched entrances and projecting quay canopy'),
}

class Kit:
 def __init__(self,key):
  self.key=key;self.coll=[[],[]];self.objects=[];self.modules=[]
  self.root=bpy.data.objects.new(key,None);bpy.context.scene.collection.objects.link(self.root)
  self.root['units']='metres';self.root['front']='Godot -Z';self.root['source_recipe']=str(Path(__file__).relative_to(ROOT))
 def part(self,name,fn,methods=('profile extrusion','geometric vertices')):
  b=L.Builder(name);fn(b);objs=[]
  parent=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(parent);parent.parent=self.root
  for mat,(v,f) in b.parts.items():
   ob=L.create_mesh(name+'_'+mat,v,f,mat);ob.parent=parent;ob['module']=name;ob['methods']=','.join(methods);objs.append(ob)
  v,f=self.coll;o=len(v);v.extend(b.coll[0]);f.extend(tuple(i+o for i in q) for q in b.coll[1])
  self.objects+=objs;self.modules.append(dict(name=name,methods=list(methods),objects=[o.name for o in objs]))
  return objs
 def add(self,ob,method):
  ob.parent=self.root;ob['methods']=method;self.objects.append(ob);self.modules.append(dict(name=ob.name,methods=[method],objects=[ob.name]));return ob
 def box(self,name,x,y,z,w,h,d,mat='stone',coll=False):return self.part(name,lambda b:b.box(x,y,z,w,h,d,mat,coll))
 def floor(self,w,d):
  self.part('01 Continuous ground and cut-stone footing',lambda b:(b.box(0,-.85,0,w,1.5,d,'rustic',True),b.box(0,-.12,0,w,.24,d,'floor',True)))
 def shell(self,name,x,z,w,d,h,mat='limestone',floors=2,roof=True,entry=True):
  return self.part(name,lambda b:b.shell(x,z,w,d,h,entry,False,max(3,int(w/5)),mat,floors,False,roof,6 if entry else 0))
 def stairs(self,d,w):return self.part('Entry terrace, steps and accessible ramp',lambda b:b.stairs(-d/2-.15,w,-d/2+.4))
 def columns(self,name,x,z,count,pitch,h=8,r=.55):
  # A spun radial source plus a real fixed-pitch array. The source remains editable.
  profile=[(0,0),(r*1.6,0),(r*1.6,.3),(r*1.2,.5),(r,.75),(r*.86,h-.9),(r*1.4,h-.65),(r*1.7,h-.4),(r*1.7,h),(0,h)]
  me=bpy.data.meshes.new(name);me.from_pydata([(rr,0,yy) for rr,yy in profile],[(i,i+1) for i in range(len(profile)-1)],[]);me.update()
  ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob);ob.data.materials.append(L.material('trim'));ob.location=L.bp((x,0,z))
  screw=ob.modifiers.new('06 Turned column profile','SCREW');screw.axis='Z';screw.angle=math.tau;screw.steps=16;screw.render_steps=16;screw.use_merge_vertices=True
  a=ob.modifiers.new('02 Measured colonnade repetition','ARRAY');a.count=count;a.use_relative_offset=False;a.use_constant_offset=True;a.constant_offset_displace=(pitch,0,0)
  self.add(ob,'screw; array')
  self.part(name+' lintel',lambda b:b.box(x+(count-1)*pitch/2,h+.25,z,(count-1)*pitch+2,.5,2.0,'stone',True))
 def curve(self,name,points,r=.12,mat='gold',closed=False):
  cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=1;cu.resolution_u=2;cu.use_fill_caps=True
  sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
  for p,v in zip(sp.points,points):p.co=(*L.bp(v),1)
  sp.use_cyclic_u=closed;ob=bpy.data.objects.new(name,cu);bpy.context.scene.collection.objects.link(ob);ob.data.materials.append(L.material(mat));return self.add(ob,'curve bevel')
 def dome(self,name,x,z,y,r,h,mat='copper'):
  profile=[(r*math.cos(a),y+h*math.sin(a)) for a in [i*math.pi/2/16 for i in range(17)]]
  me=bpy.data.meshes.new(name);me.from_pydata([(rr,0,hh) for rr,hh in profile],[(i,i+1) for i in range(16)],[]);me.update()
  ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob);ob.data.materials.append(L.material(mat));ob.location=L.bp((x,0,z))
  m=ob.modifiers.new('06 Revolved dome section','SCREW');m.axis='Z';m.angle=math.tau;m.steps=40;m.render_steps=40;m.use_merge_vertices=True
  m=ob.modifiers.new('04 Architectural shell thickness','SOLIDIFY');m.thickness=.18
  self.add(ob,'screw; solidify')
  self.part(name+' base ring',lambda b:b.ring(x,y-.3,z,r+.25,.55,.5,'trim'))
 def vault(self,name,x,z,w,d,y,h,mat='copper'):
  objs=self.part(name,lambda b:b.barrel(x,z,w,d,y,h,mat),('loft','profile extrusion'))
  for ob in objs:
   if ob.data.materials[0].name==L.PAL[mat]:m=ob.modifiers.new('04 Vault shell thickness','SOLIDIFY');m.thickness=.16;ob['methods']='loft; solidify'
 def banner(self,x,z,y,mat='indigo'):
  verts=[(x+xx,y+yy,z) for yy in (0,3.5) for xx in (-.6,0,.6)]
  ob=L.create_mesh('09 Soft hanging institutional banner',verts,[(0,1,4,3),(1,2,5,4)],mat)
  m=ob.modifiers.new('09 Modest cloth bend','SIMPLE_DEFORM');m.deform_method='BEND';m.deform_axis='Z';m.angle=.22
  m=ob.modifiers.new('04 Banner thickness','SOLIDIFY');m.thickness=.04;self.add(ob,'simple deform; solidify')
 def mirror_detail(self,w,d,h):
  obs=self.part('01 Mirrored corner buttresses',lambda b:(b.box(w/2-.5,h/2,-d/2-.4,.9,h,1.3,'rustic'),b.box(w/2-.5,h-.4,-d/2-.5,1.3,.5,1.7,'trim')),('mirror','geometric vertices'))
  for ob in obs:ob.modifiers.new('01 Matching opposite pier','MIRROR')
 def basin(self,name,x,z,w,d):
  self.part(name,lambda b:(b.box(x,-.06,z,w,.09,d,'water'),b.box(x,-.3,z,w,.35,d,'stone',True),
   b.box(x-w/2-.35,.18,z,.7,.5,d+1.4,'trim',True),b.box(x+w/2+.35,.18,z,.7,.5,d+1.4,'trim',True),
   b.box(x,.18,z-d/2-.35,w,.5,.7,'trim',True),b.box(x,.18,z+d/2+.35,w,.5,.7,'trim',True)))
 def emblem(self,x,y,z,kind='star',r=2):
  n=8 if kind=='star' else 12
  points=[(x+math.sin(i*math.pi/n)*(r if i%2==0 else r*.48),y+math.cos(i*math.pi/n)*(r if i%2==0 else r*.48)) for i in range(n*2)]
  self.part('Institutional sculpted emblem',lambda b:b.extrude(points,z,.3,'gold'))
 def bench(self,x,z,w=5):
  self.part('Stone public bench',lambda b:(b.box(x,.55,z,w,.22,.75,'stone',True),b.box(x-w*.35,.25,z,.5,.5,.8,'rustic'),b.box(x+w*.35,.25,z,.5,.5,.8,'rustic')))

def portal(k):
 k.floor(32,28)
 for x in (-12,12):k.shell('Side portal registry wing',x,1,8,26,10,'indigo',2,True,False)
 # Open great hall: body width reads horizontally, doors are not a tower at grade.
 k.part('Great-hall arches',lambda b:(b.opening_wall(0,-14,0,16,16,8,0,11,True,False,1.2,'stone'),b.opening_wall(0,14,0,16,16,8,0,11,True,False,1.2,'stone'),b.box(-8,8,0,1,16,28,'stone',True),b.box(8,8,0,1,16,28,'stone',True)))
 k.vault('Glazed nave over the three gates',0,0,16,28,16,7,'glass')
 k.part('Main tympanum and ring',lambda b:(b.pediment(0,-14.4,19,16,7,'indigo'),b.rose(0,18.5,-15,2.5)))
 for x in (-5,5):
  k.curve('Portal gateway ring',[(x+2.15*math.sin(i*math.tau/32),3.2+2.9*math.cos(i*math.tau/32),8) for i in range(32)],.25,'copper',True)
  k.box('Gate dais',x,.18,8,5,.36,4,'stone',True)
  k.emblem(x,6.7,7.8,r=.8)
 k.columns('Entrance pillars',-6,-15,2,12,11,.65);k.stairs(28,12);k.mirror_detail(32,28,10)
 for x in (-5,0,5):k.emblem(x,13.7,-14.75,r=1.05)
 k.curve('Continuous rune frieze',[(-7,12.2,-14.8),(7,12.2,-14.8)],.09,'gold')

def mage(k):
 k.floor(44,32)
 for x in (-17,17):k.shell('Low research cloister wing',x,1,10,30,12,'indigo',2,True,False)
 k.shell('Rear lecture hall',0,9,24,14,16,'stone',2,False,True)
 k.dome('Observatory cupola',0,9,16.6,7.8,7.5)
 # An armillary, not a tower: the scientific instrument is the skyline feature.
 for tilt in (-.65,.65):
  k.curve('Astronomical brass meridian',[(math.cos(a)*3,24+math.sin(a)*3*math.cos(tilt),9+math.sin(a)*3*math.sin(tilt)) for a in [i*math.tau/48 for i in range(48)]],.16,'gold',True)
 k.columns('Cloister entry colonnade',-18,-14,3,5,8);k.columns('Cloister entry colonnade',8,-14,3,5,8)
 k.part('Open ceremonial gateway',lambda b:b.arch(0,0,-15.4,10,8,3,.65,1.2,'trim'))
 k.emblem(0,12,-15.8,r=1.35);k.bench(-8,-5);k.bench(8,-5);k.banner(-13,-15,8);k.banner(13,-15,8);k.stairs(32,12)

def baths(k):
 # Continuous stone foundations, with authored openings for two visible basins.
 k.part('Bath footing and pool courts',lambda b:(b.box(0,-.95,0,64,1,44,'rustic',True),b.box(0,-.12,0,12,.24,44,'floor',True),b.box(0,-.12,16,64,.24,12,'floor',True),b.box(0,-.12,-20,64,.24,4,'floor',True),b.box(-30,-.12,-5,4,.24,30,'floor',True),b.box(30,-.12,-5,4,.24,30,'floor',True)))
 for x in (-19,19):k.basin('Open natatio basin',x,-6,18,18)
 k.part('Central frigidarium basilica',lambda b:(b.opening_wall(0,-5,0,14,17,9,0,12,True,False,1.1,'stone'),b.box(0,8.5,21,14,17,1,'brick',True)))
 def clerestory(b,x,angle):
  b.pose=(x,0,8,angle);b.facade(26,17,0,3,False,False,'brick',2)
 for x,angle in [(-7,math.pi/2),(7,-math.pi/2)]:k.part('Daylit thermal hall clerestory',lambda b,x=x,a=angle:clerestory(b,x,a))
 k.vault('High barrel-vaulted frigidarium',0,8,16,26,17,8,'slate')
 for z in (-5.1,21.1):
  k.part('Thermal lunette window',lambda b,z=z:b.extrude([(-8,17),(8,17)]+[(8*math.cos(i*math.pi/24),17+8*math.sin(i*math.pi/24)) for i in range(1,25)],z,.18,'glass'))
  for x in (-4,0,4):k.part('Lunette bronze mullion',lambda b,x=x,z=z:b.box(x,17+math.sqrt(64-x*x)/2,z-.12,.16,math.sqrt(64-x*x),.22,'bronze'))
 for x in (-23,23):
  k.shell('Warm bathing chamber',x,14,16,14,9,'brick',1,False,True)
  k.dome('Caldarium hemispherical roof',x,14,9.6,8.25,6,'copper')
  k.columns('Pool-side colonnade',x-7,-17,3,7,7,.58)
 for x in (-30,30):
  k.part('Perimeter arcade',lambda b,x=x:(b.box(x,4,0,1,8,37,'brick',True),b.box(x,8.6,0,3,.8,37,'trim')))
  for z in (-12,-4,4,12):k.part('Pool side niche',lambda b,x=x,z=z:b.arch(x,1,z,3,3,1.5,.3,.55,'trim'))
 k.columns('Monumental entrance left',-29,-21,4,6,8,.65);k.columns('Monumental entrance right',11,-21,4,6,8,.65)
 k.part('Bath portal',lambda b:(b.arch(0,0,-21.5,10,8,3,.8,1.4,'stone'),b.pediment(0,-21.7,14,11,4,'brick')))
 k.emblem(0,12.5,-22.3,kind='sun',r=1.4);k.stairs(44,14)
 for x in (-27,27):k.bench(x,1,4)

def tax(k):
 k.floor(28,24);k.shell('Counting hall',0,1,28,22,14,'stone',2,False,True)
 k.part('Treasury hipped roof',lambda b:b.mansard(0,1,28,22,14.5,5.5,'slate'))
 k.columns('Public counting loggia left',-11,-12,2,4,8,.5);k.columns('Public counting loggia right',7,-12,2,4,8,.5)
 k.part('Weighing scales relief',lambda b:(b.beam((0,12,-13),(0,18,-13),.24,.24,'gold'),b.beam((-4,16,-13),(4,16,-13),.24,.24,'gold'),b.beam((-4,16,-13),(-4,13.5,-13),.1,.1,'bronze'),b.beam((4,16,-13),(4,13.5,-13),.1,.1,'bronze'),b.extrude([(-5,13.5),(-3,13.5),(-4,12.5)],-13,.18,'gold'),b.extrude([(3,13.5),(5,13.5),(4,12.5)],-13,.18,'gold')))
 k.mirror_detail(28,24,14);k.stairs(24,9)

def welfare(k):
 k.floor(32,28)
 for x in (-12,12):k.shell('Sheltered community wing',x,0,8,28,8,'ivory',1,True,False)
 k.shell('Public assistance room',0,9,16,10,9,'ivory',1,True,True)
 k.columns('Friendly open porch left',-13,-13,2,5,5.5,.35);k.columns('Friendly open porch right',8,-13,2,5,5.5,.35)
 k.part('Welcome canopy',lambda b:b.gable(0,-12,12,4,6,3,'copper'))
 for x in (-7,7):k.bench(x,-3,4)
 # Low fountain within the court, leaving the approach and service point free.
 k.part('Community fountain',lambda b:(b.ring(0,.12,4,2.5,.4,.5,'stone'),b.cylinder(0,.12,4,2.1,.08,'water',24),b.column(0,4,0,2.0,.25)))
 k.stairs(28,10);k.banner(-10,-14,5,'red');k.banner(10,-14,5,'red')

def court(k):
 k.floor(44,28);k.shell('Judicial chamber',0,2,44,24,18,'stone',2,False,True)
 k.part('Stepped pediment',lambda b:(b.gable(0,2,45,25,18.5,5,'slate'),b.pediment(0,-15,34,16,8,'stone')))
 k.columns('Giant order left',-18,-14,3,5,14,.8);k.columns('Giant order right',8,-14,3,5,14,.8)
 k.emblem(0,20,-15.7,kind='sun',r=2);k.stairs(28,20)

def exchange(k):
 k.floor(44,28)
 for x in (-17,17):k.shell('Merchant counting wing',x,0,10,28,12,'red',2,True,False)
 k.part('Exchange hall arcades',lambda b:(b.opening_wall(0,-14,0,24,13,10,0,10,True,False,1,'stone'),b.opening_wall(0,14,0,24,13,10,0,10,True,False,1,'stone')))
 k.vault('Trading-floor glass vault',0,0,24,28,13,9,'glass')
 k.columns('Trading-floor columns',-11,-9,2,22,12,.45);k.stairs(28,14);k.emblem(0,12,-14.6,r=1.4)

def hospital(k):
 k.floor(44,28)
 for x in (-17,17):k.shell('Daylit patient ward',x,0,10,28,10,'ivory',2,True,False)
 k.shell('Infirmary reception and chapel',0,9,24,10,12,'ivory',2,False,True)
 k.part('Chapel gable',lambda b:b.gable(0,9,25,11,12.5,7,'slate'))
 k.columns('Sheltered healing walk left',-18,-13,3,5,6,.45);k.columns('Sheltered healing walk right',8,-13,3,5,6,.45)
 k.part('Healer emblem',lambda b:(b.box(0,17,-.9,.65,4,.3,'copper'),b.box(0,17,-.9,3,.65,.3,'copper')))
 for x in (-8,8):k.bench(x,-4,4)
 k.stairs(28,12)

def customs(k):
 k.floor(44,28);k.shell('Brick customs registry',0,5,44,18,14,'brick',2,False,True)
 k.part('Bonded goods roof',lambda b:b.gable(0,5,45,19,14.5,6,'slate'))
 k.columns('Cargo inspection loggia left',-19,-12,3,6,8,.6);k.columns('Cargo inspection loggia right',7,-12,3,6,8,.6)
 k.part('Inspection porch and deep arches',lambda b:(b.box(0,8.4,-10,44,.8,8,'stone'),b.arch(0,0,-14,8,6,2,.6,1,'stone')))
 k.emblem(0,10.3,-14.4,kind='sun',r=1.4);k.stairs(28,16)

def passenger(k):
 k.floor(44,28);k.shell('Passenger concourse',0,3,44,22,12,'ivory',2,False,True)
 k.vault('Long copper quay roof',0,3,44,22,12.5,9,'copper')
 k.columns('Quay entrance canopy left',-19,-13,3,6,7,.45);k.columns('Quay entrance canopy right',7,-13,3,6,7,.45)
 k.part('Harbor-front canopy',lambda b:(b.box(0,7.5,-12,44,.5,5,'trim'),b.arch(0,0,-14,10,7,3,.6,.8,'trim'),b.clock(0,11,-14.5,1.7)))
 for x in (-15,15):k.bench(x,-8,5)
 k.stairs(28,16)

MAKERS=dict(portal_hall=portal,mage_guild=mage,roman_baths=baths,tax_hall=tax,welfare_court=welfare,court_hall=court,exchange_hall=exchange,hospital_hall=hospital,customs_hall=customs,passenger_hall=passenger)

def build(key,render=True):
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.name=key+' editable assembly';sc.unit_settings.system='METRIC'
 k=Kit(key);MAKERS[key](k);info=dict(SPECS[key]);info['id']=key
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();batches=defaultdict(lambda:[[],[]]);lo=[1e9]*3;hi=[-1e9]*3
 for ob in k.objects:
  ev=ob.evaluated_get(dg);me=ev.to_mesh()
  for poly in me.polygons:
   mat=me.materials[poly.material_index].name;vs,fs=batches[mat];offset=len(vs)
   for i in poly.vertices:
    p=L.gp(ob.matrix_world@me.vertices[i].co);vs.append(p)
    for j in range(3):lo[j]=min(lo[j],p[j]);hi[j]=max(hi[j],p[j])
   fs.append(tuple(range(offset,len(vs))))
  ev.to_mesh_clear()
 source_checks=L.validate(type('Collision',(),{'coll':k.coll})(),info)
 w,d=info['footprint'];info['footprint_polygon']=[[-w/2,-d/2],[w/2,-d/2],[w/2,d/2],[-w/2,d/2]]
 info['footprint_note']='Actual continuous rectangular foundation platform, including the open court; upper volumes are separate modules.'
 info['foundation_bottom_y']=round(lo[1],5)
 info.update(dict(aabb_min=lo,aabb_max=hi,aabb_size=[hi[i]-lo[i] for i in range(3)],floor_y=0,street_y=-.6,foundation_y=-1.6,placement_lift=.6,scale=[1,1,1],front='-Z',glb=f'res://assets/models/city_v5/landmarks/{key}.glb',blend=f'assets/models/city_v5/landmarks/{key}.blend',modules=k.modules,entry_checks=source_checks,usable_hall={'center':[0,0,-5],'size':[8,8]},service_positions=[[0,0,-5]],visual_triangles=sum(sum(len(f)-2 for f in ff) for vv,ff in batches.values()),collision_triangles=sum(len(f)-2 for f in k.coll[1])))
 # Save the genuinely editable modules before producing merged export batches.
 txt=bpy.data.texts.new('REBUILD_RECIPE.py');txt.write(Path(__file__).read_text(encoding='utf8'))
 root_text=bpy.data.texts.new('ASSEMBLY_MANIFEST.json');root_text.write(json.dumps(info,ensure_ascii=False,indent=2))
 for i,p in enumerate(info['entries']):
  anchor=bpy.data.objects.new('socket_entry_'+str(i),None);sc.collection.objects.link(anchor);anchor.parent=k.root;anchor.location=L.bp(p);anchor['socket_kind']='entry';anchor['clear_width']=info['entry_width']
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(key+'.blend')))
 for ob in list(bpy.data.objects):bpy.data.objects.remove(ob,do_unlink=True)
 objects=[]
 for mat,(v,f) in batches.items():
  alias=next(a for a,n in L.PAL.items() if n==mat);objects.append(L.create_mesh(key+'_'+alias+'-nocol',v,f,alias))
 col=L.create_mesh(key+'_shell-colonly',*k.coll);col.hide_render=True;objects.append(col)
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objects:ob.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_extras=True,export_cameras=False,export_lights=False)
 (DOC/(key+'.json')).write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf8')
 if render:
  L.DOC=DOC;L.render(sc,info,key)
 print('PUBLIC_KIT_DONE',key,json.dumps({'aabb':info['aabb_size'],'entry_checks':source_checks,'triangles':info['visual_triangles']}),flush=True)
 return info

def main():
 p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=list(MAKERS));p.add_argument('--no-render',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 OUT.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 for key in a.only or MAKERS:build(key,not a.no_render)
 rows=[json.loads((DOC/(key+'.json')).read_text(encoding='utf8')) for key in MAKERS if (DOC/(key+'.json')).exists()]
 (DOC/'manifest.public.json').write_text(json.dumps({'version':'5.1-public-kit','source':'component assembly with retained editing modifiers','assets':rows},ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':main()
