"""Native metre-scale civic architecture for Solenne v5.

Run Blender -b --python tools/blender/city_v5/landmarks.py -- --only station civic_hall
Geometry is authored in Godot XYZ (Y up, front -Z), converted once to Blender.
Rendered surfaces are merged by K| material, never used as collision.
Separate low-detail watertight pieces form one concave *-colonly collision shell.
"""
import argparse, json, math, sys, time
from pathlib import Path
from collections import defaultdict
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/models/city_v5/landmarks'
DOC=ROOT/'docs/city_v5/landmarks'
PLAN=json.loads((DOC/'manifest.plan.json').read_text(encoding='utf-8'))
PAL={
 'stone':'K|2|d8c8a8|st_masonry|4.0', 'limestone':'K|0|eee1c7|st_plaster|3.0',
 'trim':'K|9|f3e8d3||0', 'rustic':'K|2|b4a58c|st_masonry|3.5',
 'slate':'K|3|41546f|st_roof_scale|2.4', 'copper':'K|7|508d89||0',
 'gold':'K|7|bca35e||0', 'bronze':'K|7|574b39||0',
 'glass':'K|glass|739da8||0', 'shadow':'K|9|465766||0',
 'floor':'K|2|c9bda4|st_masonry|5.0', 'wood':'K|6|694a34|st_boards|2.0',
 'red':'K|0|bc8372|st_plaster|3.0'}

def bp(p): return (p[0],-p[2],p[1])
def gp(p): return (p[0],p[2],-p[1])

def material(key):
 name=PAL[key]; m=bpy.data.materials.get(name)
 if m:return m
 m=bpy.data.materials.new(name);m.use_nodes=True
 c=tuple(int(name.split('|')[2][i:i+2],16)/255 for i in (0,2,4))
 m.diffuse_color=(*c,1)
 nt=m.node_tree;nt.nodes.clear();p=nt.nodes.new('ShaderNodeBsdfPrincipled');o=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(p.outputs['BSDF'],o.inputs['Surface']);p.inputs['Base Color'].default_value=(*[v**2.2 for v in c],1)
 p.inputs['Roughness'].default_value=.68
 if key in ('gold','bronze','copper'):p.inputs['Metallic'].default_value=.35;p.inputs['Roughness'].default_value=.42
 if key=='glass':p.inputs['Metallic'].default_value=.18;p.inputs['Roughness'].default_value=.2
 return m

class Builder:
 def __init__(self,key):self.key=key;self.parts=defaultdict(lambda:[[],[]]);self.coll=[[],[]];self.pose=(0,0,0,0);self.anchors=[]
 def trans(self,p):
  x,y,z,a=self.pose;c=math.cos(a);s=math.sin(a)
  return (x+p[0]*c+p[2]*s,y+p[1],z-p[0]*s+p[2]*c)
 def mesh(self,verts,faces,mat='stone',collision=False,visual=True):
  vv=[self.trans(v) for v in verts]
  if visual:
   v,f=self.parts[mat];o=len(v);v.extend(vv);f.extend(tuple(i+o for i in q) for q in faces)
  if collision:
   v,f=self.coll;o=len(v);v.extend(vv);f.extend(tuple(i+o for i in q) for q in faces)
 def box(self,x,y,z,w,h,d,mat='stone',collision=False,visual=True):
  if min(w,h,d)<=.001:return
  v=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
  self.mesh(v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat,collision,visual)
 def extrude(self,poly,z,d,mat='stone',collision=False,visual=True):
  n=len(poly);v=[(x,y,z+side*d/2) for side in (-1,1) for x,y in poly]
  f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
  self.mesh(v,f,mat,collision,visual)
 def cylinder(self,x,y,z,r,h,mat='stone',n=20,rt=None,collision=False):
  rt=r if rt is None else rt
  v=[(x+math.sin(a)*rr,y+yy,z+math.cos(a)*rr) for yy,rr in [(0,r),(h,rt)] for a in [i*math.tau/n for i in range(n)]]
  self.mesh(v,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat,collision)
 def ring(self,x,y,z,r,thick,h,mat='trim',n=32,collision=False):
  v=[(x+math.sin(i*math.tau/n)*rr,y+yy,z+math.cos(i*math.tau/n)*rr) for yy,rr in [(0,r),(h,r),(0,r-thick),(h,r-thick)] for i in range(n)]
  f=[]
  for i in range(n):
   j=(i+1)%n;f.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(n+i,n+j,3*n+j,3*n+i),(j,i,2*n+i,2*n+j)])
  self.mesh(v,f,mat,collision)
 def arch(self,x,y,z,w,spring,rise,thick=.35,depth=.45,mat='trim',n=16):
  self.box(x-w/2-thick/2,y+spring/2,z,thick,spring,depth,mat)
  self.box(x+w/2+thick/2,y+spring/2,z,thick,spring,depth,mat)
  v=[]
  for side in (-1,1):
   for outer in (0,1):
    for i in range(n+1):
     a=i*math.pi/n;v.append((x+math.cos(a)*(w/2+outer*thick),y+spring+math.sin(a)*(rise+outer*thick),z+side*depth/2))
  N=n+1;f=[]
  for i in range(n):
   f.extend([(i,i+1,N+i+1,N+i),(2*N+i,3*N+i,3*N+i+1,2*N+i+1),(i,2*N+i,2*N+i+1,i+1),(N+i+1,3*N+i+1,3*N+i,N+i)])
  f.extend([(0,N,3*N,2*N),(n,2*N+n,3*N+n,N+n)])
  self.mesh(v,f,mat)
 def opening_wall(self,x,z,bottom,bay,story,ow,sill,oh,arch=True,glass=True,depth=1.0,mat='limestone',coll=True,details=True):
  # Side piers, sill and arch spandrel leave a real void in the wall mesh.
  if coll:
   if glass or bottom>0:self.box(x,bottom+story/2,z,bay,story,depth,mat,True,False)
   else:
    for side in (-1,1):self.box(x+side*(bay+ow)/4,bottom+story/2,z,(bay-ow)/2,story,depth,mat,True,False)
    self.box(x,bottom+oh+(story-oh)/2,z,ow,story-oh,depth,mat,True,False)
  self.box(x-bay/2+(bay-ow)/4,bottom+story/2,z,(bay-ow)/2,story,depth,mat)
  self.box(x+bay/2-(bay-ow)/4,bottom+story/2,z,(bay-ow)/2,story,depth,mat)
  if sill:self.box(x,bottom+sill/2,z,ow,sill,depth,mat)
  rise=min(ow/2,oh*.33) if arch else 0.0; spring=oh-rise
  if arch:
   N=12
   for i in range(N):
    a=math.pi-i*math.pi/N;b=math.pi-(i+1)*math.pi/N
    px=x+math.cos(a)*ow/2;qx=x+math.cos(b)*ow/2
    py=bottom+sill+spring+math.sin(a)*rise;qy=bottom+sill+spring+math.sin(b)*rise
    self.extrude([(px,py),(qx,qy),(qx,bottom+story),(px,bottom+story)],z,depth,mat)
  else:self.box(x,bottom+sill+oh+(story-sill-oh)/2,z,ow,story-sill-oh,depth,mat)
  fy=bottom+sill;front=z-depth/2-.17
  if details:
   self.arch(x,fy,front,ow,spring,rise,.25,.5,'trim') if arch else self.frame(x,fy,front,ow,oh)
   self.box(x,fy-.12,front-.12,ow+.8,.24,1,'trim')
   if sill>0:self.box(x,fy+oh+.42,front-.08,ow+.9,.2,.72,'trim')
  if glass:
   poly=[(x-ow/2,fy),(x+ow/2,fy),(x+ow/2,fy+spring)]
   if arch:poly.extend((x+math.cos(i*math.pi/16)*ow/2,fy+spring+math.sin(i*math.pi/16)*rise) for i in range(1,17))
   else:poly.extend([(x+ow/2,fy+oh),(x-ow/2,fy+oh)])
   self.extrude(poly,z+.22,.10,'glass',False)
   self.box(x,fy+spring/2,z+.10,.09,spring,.12,'bronze')
   for dy in (.45,.78):self.box(x,fy+spring*dy,z+.08,ow,.075,.13,'bronze')
 def frame(self,x,y,z,w,h):
  for sx in (-1,1):self.box(x+sx*(w/2+.14),y+h/2,z,.28,h+.3,.48,'trim')
  for yy in (y-.12,y+h+.12):self.box(x,yy,z,w+.55,.25,.48,'trim')
 def facade(self,w,h,z,n,ground_open=False,entry=False,mat='limestone',floors=3,entry_width=0):
  bh=h/floors;bay=w/n
  # Upper windows do not need collision holes; one continuous wall replaces all detail bays.
  if floors>1:self.box(0,(h+bh)/2,z,w,h-bh,1.0,mat,True,False)
  for row in range(floors):
   if row==0 and entry_width:
    center=entry_width+3.2;side=(w-center)/2;sn=max(1,int(side/5));sb=side/sn
    self.opening_wall(0,z,0,center,bh,entry_width,0,bh*.84,True,False,mat=mat)
    for sign in (-1,1):
     for i in range(sn):
      xx=sign*(center/2+(i+.5)*sb)
      self.opening_wall(xx,z,0,sb,bh,min(sb*.54,3),1.1,bh*.57,True,True,mat=mat)
    self.box(0,bh-.15,z-.30,w+.5,.3,1.45,'trim')
    continue
   for i in range(n):
    x=-w/2+(i+.5)*bay
    door=row==0 and (ground_open or (entry and i==n//2))
    ow=bay*.70 if door else min(bay*.50,3.0)
    self.opening_wall(x,z,row*bh,bay,bh,ow,0 if door else 1.1,bh*.79 if door else bh*.57,arch=(row==0 or row==floors-1),glass=not door,mat=mat,coll=(row==0))
   self.box(0,(row+1)*bh-.15,z-.30,w+.5,.3,1.45,'trim')
  # rusticated corners and giant-order pilasters give depth at street distance.
  for x in (-w/2+.35,w/2-.35):
   self.box(x,h/2,z-.68,.65,h,.42,'stone')
   for yy in [i*.72+.36 for i in range(int(h/.72))]:self.box(x,yy,z-.93,.88,.52,.22,'trim')
  for i in range(max(1,int(w/1.35))):
   self.box(-w/2+(i+.5)*w/max(1,int(w/1.35)),h-.55,z-.70,.38,.40,.58,'trim')
 def cornice(self,w,d,y,x=0,z=0):
  for yy,ww,hh in [(y-.45,.4,.35),(y,.8,.3),(y+.42,1.15,.32)]:
   self.box(x,yy,z,w+ww,hh,d+ww,'trim')
 def shell(self,x,z,w,d,h,front_entry=True,back_entry=False,n=5,mat='limestone',floors=3,arcade=False,roof=True,entry_width=0):
  old=self.pose;self.pose=(x,0,z,0)
  self.box(0,-.65,0,w,1.1,d,'rustic',True)
  self.box(0,-.12,0,w,.24,d,'floor',True)
  self.facade(w,h,-d/2,n,arcade,front_entry,mat,floors,entry_width)
  self.pose=(x,0,z,math.pi);self.facade(w,h,-d/2,n,False,back_entry,mat,floors)
  self.pose=(x,0,z,math.pi/2);self.facade(d,h,-w/2,max(3,int(d/6)),False,False,mat,floors)
  self.pose=(x,0,z,-math.pi/2);self.facade(d,h,-w/2,max(3,int(d/6)),False,False,mat,floors)
  self.pose=(x,0,z,0);self.cornice(w,d,h)
  if roof:self.mansard(0,0,w,d,h+.6,5,'slate')
  self.pose=old
 def mansard(self,x,z,w,d,y,h,mat='slate'):
  inset=min(w,d)*.13
  levels=[(w+.9,d+.9,y),(w-inset*2,d-inset*2,y+h*.77),(w-inset*2-.6,d-inset*2-.6,y+h)]
  v=[(x+sx*ww/2,yy,z+sz*dd/2) for ww,dd,yy in levels for sx,sz in [(-1,-1),(1,-1),(1,1),(-1,1)]]
  f=[(8,9,10,11)]
  for j in (0,4):
   for i in range(4):f.append((j+i,j+(i+1)%4,j+4+(i+1)%4,j+4+i))
  self.mesh(v,f,mat,False)
  self.box(x,y+.18,z,w,.35,d,'stone',True)
  for sx in (-1,1):self.box(x+sx*(w/2-inset),y+h,z,.18,.22,d-inset*2,'gold')
  # Raised dormers break the uninterrupted roof plane and add inhabited attic scale.
  if w>16 and h>=4:
   count=max(2,int(w/9))
   for i in range(count):
    xx=x-w*.38+(i+.5)*w*.76/count;zz=z-d/2+inset*.32
    self.opening_wall(xx,zz,y+.4,2.8,3.0,1.45,.35,1.9,True,True,.55,'stone',False)
    self.gable(xx,zz+.5,3.15,1.8,y+3.4,.75,mat)
 def gable(self,x,z,w,d,y,h,mat='slate'):
  v=[(x-w/2,y,z-d/2),(x+w/2,y,z-d/2),(x,y+h,z-d/2),(x-w/2,y,z+d/2),(x+w/2,y,z+d/2),(x,y+h,z+d/2)]
  self.mesh(v,[(0,1,2),(3,5,4),(0,2,5,3),(2,1,4,5)],mat)
  self.box(x,y,z,w,.3,d,'stone',True)
  self.box(x,y+h,z,.4,.4,d+.6,'gold')
 def pediment(self,x,z,w,y,h,mat='stone'):
  self.extrude([(x-w/2,y),(x+w/2,y),(x,y+h)],z,.9,mat)
  self.box(x,y,z,w+1,.45,1.3,'trim')
  # upper sloped trim rails, via beam.
  self.beam((x-w/2,y+.2,z-.53),(x,y+h+.2,z-.53),.27,.35,'trim')
  self.beam((x,y+h+.2,z-.53),(x+w/2,y+.2,z-.53),.27,.35,'trim')
 def beam(self,a,b,w,d,mat='trim'):
  va=Vector(a);vb=Vector(b);axis=(vb-va).normalized();u=axis.cross(Vector((0,0,1)))
  if u.length<.001:u=axis.cross(Vector((0,1,0)))
  u.normalize();v=axis.cross(u).normalized();vs=[]
  for p in (va,vb):
   for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]:vs.append(tuple(p+u*s*w/2+v*t*d/2))
  self.mesh(vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
 def column(self,x,z,y,h,r=.55,mat='trim'):
  self.box(x,y+.18,z,r*3,.36,r*3,'stone')
  self.cylinder(x,y+.36,z,r*1.25,.22,mat,n=16)
  self.cylinder(x,y+.58,z,r,h-1.1,mat,n=16,rt=r*.82)
  self.cylinder(x,y+h-.52,z,r*1.3,.25,mat,n=16)
  self.box(x,y+h-.16,z,r*3.1,.32,r*3.1,mat)
 def dome(self,x,z,y,r,h,mat='copper',lantern=0):
  N=32;M=12;v=[]
  for j in range(M+1):
   a=j*math.pi/2/M;rr=r*math.cos(a)
   for i in range(N):v.append((x+math.sin(i*math.tau/N)*rr,y+math.sin(a)*h,z+math.cos(i*math.tau/N)*rr))
  f=[]
  for j in range(M):
   for i in range(N):f.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
  self.mesh(v,f,mat)
  self.ring(x,y-.2,z,r+.2,.45,.5,'trim')
  for i in range(0,N,4):
   a=i*math.tau/N
   for j in range(M):
    aa=j*math.pi/2/M;bb=(j+1)*math.pi/2/M
    self.beam((x+math.sin(a)*r*math.cos(aa),y+h*math.sin(aa)+.08,z+math.cos(a)*r*math.cos(aa)),(x+math.sin(a)*r*math.cos(bb),y+h*math.sin(bb)+.08,z+math.cos(a)*r*math.cos(bb)),.12,.12,'gold')
  if lantern:
   self.cylinder(x,y+h,z,r*.12,lantern*.55,'trim',12)
   self.cylinder(x,y+h+lantern*.55,z,r*.22,lantern*.45,mat,12,rt=0)
 def barrel(self,x,z,w,d,y,h,mat='copper'):
  N=24;v=[]
  for zz in (z-d/2,z+d/2):
   for i in range(N+1):
    a=math.pi-i*math.pi/N;v.append((x+math.cos(a)*w/2,y+math.sin(a)*h,zz))
  self.mesh(v,[(i,i+1,N+i+2,N+i+1) for i in range(N)],mat)
  for k in range(int(d/6)+1):
   zz=z-d/2+k*d/int(d/6)
   for i in range(N):self.beam(v[i][:2]+(zz,),v[i+1][:2]+(zz,),.19,.28,'bronze')
  for xx in [x-w/2,x+w/2]:self.box(xx,y-.2,z,.35,.5,d+.4,'trim')
 def stairs(self,z,w,landing_to=None):
  # 0.6m rise; broad steps each side, unobstructed central 3m ramp.
  for i in range(3):
   length=3-i*.8;top=-.4+i*.2
   for side in (-1,1):self.box(side*(w/4+.75),(top-.6)/2,z-length/2,(w-3)/2,top+.6,length,'stone')
  # Closed wedges keep collision normals outward after export (an open ramp quad can face down).
  faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]
  def wedge(width):
   return [(-width/2,-.75,z-3),(width/2,-.75,z-3),(width/2,-.6,z-3),(-width/2,-.6,z-3),(-width/2,-.75,z),(width/2,-.75,z),(width/2,0,z),(-width/2,0,z)]
  self.mesh(wedge(w),faces,'floor',True,False)
  self.mesh(wedge(3),faces,'floor')
  # A flush landing reaches the actual building floor; decorative porticos can project farther out.
  end=z+.25 if landing_to is None else landing_to
  self.box(0,-.3,(z+end)/2,w,.6,max(.25,end-z),'floor',True)
 def round_tower(self,x,z,r,h,peak,entry=False,mat='limestone'):
  self.cylinder(x,-1.2,z,r,1.2,'rustic',n=24,collision=True)
  N=24;bay=math.tau*r/N
  for i in range(N):
   a=i*math.tau/N;old=self.pose
   self.pose=(x+math.sin(a)*r,0,z-math.cos(a)*r,-a)
   front=i in (0,1,N-1)
   if entry and front:
    self.box(0,(8+h)/2,0,bay+.08,h-8,1.2,mat,True,False)
    if i==0:
     levels=max(2,int(h/9));story=h/levels
     for row in range(1,levels):self.opening_wall(0,0,row*story,bay+.08,story,min(bay*.62,1.6),1.5,story*.62,True,True,1.2,mat,False)
     self.box(0,(8+story)/2,0,bay+.08,story-8,1.2,mat)
    else:self.box(0,(8+h)/2,0,bay+.08,h-8,1.2,mat)
   else:
    self.box(0,h/2,0,bay+.08,h,1.2,mat,True,False)
    if i%3==0:
     levels=max(2,int(h/9));story=h/levels
     for row in range(levels):self.opening_wall(0,0,row*story,bay+.08,story,min(bay*.62,1.6),1.5,story*.62,True,True,1.2,mat,False)
    else:self.box(0,h/2,0,bay+.08,h,1.2,mat)
   self.pose=old
  for y in [9,h*.52,h-.3]:
   self.ring(x,y,z,r+1.0,1.55,.65,'trim')
   self.ring(x,y-.35,z,r+.72,1.25,.28,'stone')
  self.dome(x,z,h,r+.3,peak-h-2,'copper',2)
  if entry:
   self.opening_wall(x,z-r-.1,0,bay*3+.3,8,4.4,0,7.8,True,False,1.0,mat,True)
   self.arch(x,0,z-r-.65,4.4,5.8,2.2,.6,1.2,'stone')
   self.stairs(z-r-1,6,z-r+.6)
 def clock(self,x,y,z,r):
  old=self.pose
  # Face disk in XY with relief ring and visible hands.
  N=32;poly=[(x+math.sin(i*math.tau/N)*r,y+math.cos(i*math.tau/N)*r) for i in range(N)]
  self.extrude(poly,z,.2,'floor')
  for i in range(12):
   a=i*math.tau/12;self.beam((x+math.sin(a)*r*.78,y+math.cos(a)*r*.78,z-.18),(x+math.sin(a)*r*.94,y+math.cos(a)*r*.94,z-.18),.10,.12,'bronze')
  self.beam((x,y,z-.25),(x+r*.48,y+r*.30,z-.25),.16,.12,'bronze')
  self.beam((x,y,z-.24),(x-r*.17,y+r*.66,z-.24),.12,.12,'bronze')
 def rose(self,x,y,z,r):
  N=48;v=[]
  for zz,rr in [(z,r),(z,r-.5),(z+.35,r),(z+.35,r-.5)]:
   v.extend((x+math.sin(i*math.tau/N)*rr,y+math.cos(i*math.tau/N)*rr,zz) for i in range(N))
  f=[]
  for i in range(N):
   j=(i+1)%N;f.extend([(i,j,N+j,N+i),(2*N+i,3*N+i,3*N+j,2*N+j),(i,2*N+i,2*N+j,j)])
  self.mesh(v,f,'trim')
  self.extrude([(x+math.sin(i*math.tau/N)*(r-.5),y+math.cos(i*math.tau/N)*(r-.5)) for i in range(N)],z+.18,.1,'glass')
  for i in range(12):
   a=i*math.tau/12;self.beam((x,y,z-.08),(x+math.sin(a)*(r-.48),y+math.cos(a)*(r-.48),z-.08),.14,.16,'gold')
  self.extrude([(x+math.sin(i*math.tau/12)*.8,y+math.cos(i*math.tau/12)*.8) for i in range(12)],z-.20,.18,'gold')

def station(b):
 # Side offices set back from a genuinely open 32m central arrival hall.
 for x in (-33,33):b.shell(x,0,34,56,18,True,True,5,'stone',3,True)
 b.box(0,-.65,0,32,1.1,56,'rustic',True);b.box(0,-.12,0,32,.24,56,'floor',True)
 for x in (-16,16):b.box(x,9,0,1,18,56,'limestone',True)
 for z in (-28,28):
  b.opening_wall(0,z,0,32,18,14,0,12,True,False,1.3,'stone')
  b.arch(0,0,z-.75 if z<0 else z+.75,14,8,4,.8,1.6,'trim')
  b.clock(0,17.5,z-1.15,2.4)
  for x in (-12,12):b.column(x,z-.8,0,17,.62)
 b.barrel(0,0,32,56,18,10,'copper')
 # Transparent upper lunette over a solid lower entry wall.
 for z in (-27.9,27.9):
  b.extrude([(-16,18),(16,18)]+[(16*math.cos(i*math.pi/24),18+10*math.sin(i*math.pi/24)) for i in range(1,25)],z,.12,'glass')
 for x in (-36,36):
  b.shell(x,-17,12,16,34,True,False,3,'stone',4,False,False)
  b.dome(x,-17,34,6.3,9,'copper',3)
  b.clock(x,28,-25.75,2.4)
 for x in (-16.2,16.2):
  for z in (-19,-7,5,17):b.column(x,z,0,16,.6)
 b.stairs(-28,18)
 old=b.pose;b.pose=(0,0,0,math.pi);b.stairs(-28,18);b.pose=old
 # Passenger benches/ticket counters are kept in side wings, outside the central 30m hall.
 for x in (-24,24):
  for z in (-7,7,18):b.box(x,.65,z,2,1.3,3.6,'wood')

def civic(b):
 for x in (-31,31):b.shell(x,0,26,36,22,True,False,5,'limestone',3,True)
 b.shell(0,0,36,40,24,True,False,5,'stone',3,False,False,10)
 # Replace central front bay with broad arch in a separate front portal; shell entry still open.
 # Rebuild the central mass explicitly so no narrower original bay blocks the entrance.
 b.pediment(0,-21,26,24.5,5,'stone')
 for x in (-13,-9,9,13):b.column(x,-21.4,0,16,.62)
 b.cylinder(0,24.4,1,8.6,4.3,'stone',24)
 b.dome(0,1,28.7,8.9,11.3,'copper',4)
 b.stairs(-20.8,14,-19.8)

def governor(b):
 for x in (-40,40):b.shell(x,0,20,70,24,True,False,3,'limestone',3,False)
 b.shell(0,24,60,22,24,True,False,9,'stone',3,True,True,10)
 b.pediment(0,12.1,24,24.5,5)
 for x in (-12,-8,8,12):b.column(x,10.5,0,14,.6)
 b.dome(0,25,28.5,7.5,7.5,'slate',2)
 b.stairs(12,14,13.2)
 for x in (-40,40):old=b.pose;b.pose=(x,0,0,0);b.stairs(-35,7);b.pose=old

def cathedral(b):
 # Nave/side aisles are separate open structural shells.
 b.box(0,-.65,0,48,1.1,94,'rustic',True);b.box(0,-.12,0,48,.24,94,'floor',True)
 for x in (-19,19):b.shell(x,4,10,80,15,False,False,3,'limestone',2,False,False);b.gable(x,4,11,81,15.5,5,'slate')
 for x in (-12,12):b.box(x,19,0,1.2,14,90,'stone',True)
 b.opening_wall(0,-47,0,24,26,8,0,13,True,False,1.6,'stone')
 b.box(0,13,46.5,24,26,1,'stone',True)
 b.gable(0,0,25,94,26,10,'slate')
 b.pediment(0,-47.6,24,26,10,'stone')
 # Rose window: layered wheel with twelve radial mullions.
 b.rose(0,22,-48.15,4.0)
 for x in (-18,18):
  b.shell(x,-38,12,18,49,False,False,3,'stone',6,False,False)
  b.cylinder(x,49,-38,6.4,3,'trim',8)
  b.cylinder(x,52,-38,6.5,10,'slate',8,rt=0)
  for sx in (-1,1):b.cylinder(x+sx*4.8,48.5,-43,1,7,'slate',8,rt=0)
 for x in (-11,11):
  for z in range(-32,37,11):b.column(x,z,0,13,.85)
 for x in (-23,23):
  for z in range(-21,42,11):
   b.box(x,5,z,2,10,2,'stone',True)
   b.beam((x,8,z),(x*.54,22,z),1.0,1.3,'trim')
 b.box(0,.35,32,12,.7,8,'floor',True)
 b.box(0,1.0,32,6,1.3,2,'stone')
 b.stairs(-47.9,12,-46.8)

def trade(b):
 for x in (-25.5,25.5):b.shell(x,0,19,38,12,True,True,3,'stone',2,True,False);b.mansard(x,0,19,38,12.5,5.5,'copper')
 b.box(0,-.65,0,32,1.1,38,'rustic',True);b.box(0,-.12,0,32,.24,38,'floor',True)
 for z in (-19,19):
  b.opening_wall(0,z,0,32,14,12,0,10,True,False,1.1,'stone')
  b.extrude([(-16,14),(16,14)]+[(16*math.cos(i*math.pi/24),14+10*math.sin(i*math.pi/24)) for i in range(1,25)],z,.10,'glass')
 b.barrel(0,0,32,38,14,10,'glass')
 for x in (-15.85,15.85):
  for z in (-14,-5,5,14):b.column(x,z,0,14,.5)
 b.stairs(-19,16)
 old=b.pose;b.pose=(0,0,0,math.pi);b.stairs(-19,16);b.pose=old

def academy(b):
 b.shell(0,0,60,40,22,True,False,9,'limestone',3,True,True,8)
 b.pediment(-3,-20.8,24,22.8,5,'stone')
 for x in (-13,-8,2,7):b.column(x,-21,0,14,.55)
 b.round_tower(22,7,7,35,48,False,'stone')
 # Armillary above the observatory dome.
 b.stairs(-20.6,12,-19.8)

def opera(b):
 b.shell(0,0,64,40,20,True,False,9,'limestone',3,True,False,10)
 b.mansard(0,0,64,40,20.6,5,'slate')
 b.pediment(0,-21,28,21,7,'stone')
 for x in (-24,-18,-12,12,18,24):b.column(x,-21.2,0,12,.6)
 b.box(0,12.5,-21,55,.7,4,'trim')
 for x in (-27,27):b.dome(x,-14,21,4.2,5,'copper',1)
 b.stairs(-21.8,16,-19.8)

def public(b):
 b.shell(0,0,44,28,18,True,False,7,'limestone',3,True,False,8)
 b.mansard(0,0,44,28,18.6,5,'slate')
 b.dome(0,3,22,6,5,'copper',1)
 b.pediment(0,-15.1,20,18.7,4.3,'stone')
 for x in (-9,-5,5,9):b.column(x,-15.2,0,10,.48)
 b.stairs(-15.8,12,-13.8)

def magic(b):
 b.round_tower(0,0,9.4,54,66,True,'stone')
 # Flying-finial buttresses visibly distinguish it from the academy observatory.
 for i in range(6):
  a=i*math.tau/6;x=math.sin(a)*9.7;z=math.cos(a)*9.7
  b.cylinder(x,43,z,.85,12,'slate',8,rt=0)
 b.ring(0,38,0,10.35,1.05,.5,'gold')

def guild(b):
 b.shell(0,0,44,30,18,True,False,7,'stone',3,True,False,8)
 b.gable(0,0,45,31,18.5,8.5,'slate')
 b.pediment(0,-15.9,25,18.5,9.5,'stone')
 b.clock(0,22.2,-16.55,2.0)
 for x in (-18,18):b.box(x,9,-15.8,1.3,18,1,'trim')
 for x in (-8,-4,4,8):b.column(x,-17.0,0,10,.48)
 b.stairs(-17.6,12,-14.8)

MAKERS={'station':station,'civic_hall':civic,'governor_palace':governor,'cathedral':cathedral,'trade_hall':trade,'academy':academy,'opera':opera,'public_house':public,'magic_tower':magic,'guild_hall':guild}

def create_mesh(name,verts,faces,mat=None):
 me=bpy.data.meshes.new(name);me.from_pydata([bp(p) for p in verts],[],faces);me.update()
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 if mat:me.materials.append(material(mat))
 obj=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(obj)
 return obj

def validate(b,info):
 # Collision is tested in native Godot coordinates; horizontal approach ray at chest height.
 tree=BVHTree.FromPolygons([Vector(v) for v in b.coll[0]],b.coll[1],all_triangles=False)
 checks=[]
 for p in info['entries']:
  x,y,z=p;sign=-1 if z>=info['footprint'][1]/2-.01 else 1
  start=Vector((x,1.0,z-sign*2));direction=Vector((0,0,sign))
  hit=tree.ray_cast(start,direction,4)
  floor=tree.ray_cast(Vector((x,2,z+sign*2)),Vector((0,-1,0)),4)
  checks.append({'entry':p,'approach_ray_clear':hit[0] is None,'floor_hit_y':round(floor[0].y,4) if floor[0] else None})
 return checks

def render(scene,info,key):
 scene.render.engine='CYCLES';scene.cycles.samples=24
 scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
 world=bpy.data.worlds.new(key+'_world');world.use_nodes=True
 nt=world.node_tree;nt.nodes.clear();bg=nt.nodes.new('ShaderNodeBackground');wo=nt.nodes.new('ShaderNodeOutputWorld');nt.links.new(bg.outputs[0],wo.inputs[0]);bg.inputs[0].default_value=(.62,.72,.85,1);bg.inputs[1].default_value=.55;scene.world=world
 # Presentation ground is not exported or included in the source asset collection.
 bpy.ops.mesh.primitive_plane_add(size=400,location=bp((0,-.62,0)))
 ground=bpy.context.object;ground.name='PreviewGround';ground.data.materials.append(material('floor'))
 sun_data=bpy.data.lights.new('Sun','SUN');sun_data.energy=3;sun_data.angle=math.radians(12)
 sun=bpy.data.objects.new('Sun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(math.radians(28),math.radians(-30),math.radians(-30))
 cam_data=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cam_data);scene.collection.objects.link(cam)
 w,d=info['footprint'];h=info['max_height'];cam.location=bp((w*.84,max(h*.85,w*.52),-d*1.15-w*.65))
 target=Vector(bp((0,h*.32,0)));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam_data.type='ORTHO';cam_data.ortho_scale=max(w*1.45,d*1.34,h*1.6);scene.camera=cam
 # A 1.8m witness person at the main entry makes metre scale inspectable.
 p=info['entries'][0];bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=.22,location=bp((p[0]-5,1.58,p[2]-3)))
 person_head=bpy.context.object;person_head.data.materials.append(material('red'))
 bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=.24,depth=1.25,location=bp((p[0]-5,.78,p[2]-3)))
 person_body=bpy.context.object;person_body.data.materials.append(material('red'))
 scene.render.filepath=str(DOC/(key+'_preview.png'));bpy.ops.render.render(write_still=True)
 for o in (ground,sun,cam,person_head,person_body):bpy.data.objects.remove(o,do_unlink=True)

def build(key,no_render=False):
 start=time.time();bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 b=Builder(key);MAKERS[key](b);info=next(dict(e) for e in PLAN['assets'] if e['id']==key)
 objs=[]
 for mat,(verts,faces) in b.parts.items():objs.append(create_mesh(f'{key}_{mat}-nocol',verts,faces,mat))
 collider=create_mesh(f'{key}_shell-colonly',*b.coll);collider.hide_render=True;objs.append(collider)
 # Ground-floor layers remain authorable as separate material batches plus collision shell.
 allv=[v for verts,_ in b.parts.values() for v in verts]
 lo=[min(v[i] for v in allv) for i in range(3)];hi=[max(v[i] for v in allv) for i in range(3)]
 info.update({'glb':f'res://assets/models/city_v5/landmarks/{key}.glb','blend':f'assets/models/city_v5/landmarks/{key}.blend',
  'aabb_min':lo,'aabb_max':hi,'aabb_size':[hi[i]-lo[i] for i in range(3)],'floor_y':0,'street_y':-.6,'foundation_y':-1.2,'placement_lift':.6,
  'materials':[PAL[k] for k in b.parts], 'visual_meshes':len(b.parts),'visual_vertices':len(allv),'visual_triangles':sum(max(1,len(f)-2) for v,ff in b.parts.values() for f in ff),
  'collision_meshes':1,'collision_vertices':len(b.coll[0]),'collision_triangles':sum(len(f)-2 for f in b.coll[1]),'entry_checks':validate(b,info),
  'front':'-Z','scale':[1,1,1],'notes':'Facade and roof meshes are new procedural native geometry; K materials are merged. Collision shell is independent of detail.'})
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(key+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_extras=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(key+'.blend')))
 (DOC/(key+'.json')).write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
 if not no_render:render(scene,info,key)
 print('LANDMARK_DONE',key,round(time.time()-start,1),json.dumps({'aabb':info['aabb_size'],'collision_triangles':info['collision_triangles'],'entries':info['entry_checks']}),flush=True)
 return info

def main():
 p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=MAKERS);p.add_argument('--no-render',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 OUT.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 for key in (a.only or MAKERS):build(key,a.no_render)
 assets=[json.loads(p.read_text(encoding='utf-8')) for p in DOC.glob('*.json') if p.stem in MAKERS]
 (OUT/'manifest.json').write_text(json.dumps({'coordinate_system':'Godot native XYZ; front -Z','placement_lift':.6,'scale':[1,1,1],'assets':assets},ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__':main()
