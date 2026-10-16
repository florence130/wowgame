"""Native metre civic engineering for Solenne v5; no stretched legacy assets.

Blender +Y is Godot -Z. Gate and bridge longitudinal axis is Godot Z.
Gate/wall datum = grade; bridge datum = finished deck; ship datum = waterline.
Usage: blender -b --python civil.py -- --structure --render
       blender -b --python civil.py -- --all
"""
from pathlib import Path
import importlib.util
import argparse
import math
import json
import sys
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('city_architecture',HERE/'architecture.py')
A=importlib.util.module_from_spec(spec);spec.loader.exec_module(A)
ROOT=HERE.parents[2]
OUT=ROOT/'assets/models/city_v5/civil'
DOC=ROOT/'docs/city_v5/civil'
OUT.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
STONE='2:b4ad9c';DARKSTONE='2:898980';TRIM='9:e5ddc7';WALL='0:ccc6b5'
ROOF='3:3d5366';COPPER='5:547b70';IRON='7:343d42';GOLD='7:b5995e';GLASS='7:354c54'
WOOD='6:72513a';DECK='6:a28b64';NAVY='0:283e53';RED='0:823f35';CREAM='0:e1dbcd'


def tube(m,a,b,r,mat,sides=8):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized()
    u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u).normalized()
    verts=[tuple(p+r*(u*math.cos(k*math.tau/sides)+v*math.sin(k*math.tau/sides))) for p in (a,b) for k in range(sides)]
    faces=[tuple(range(sides-1,-1,-1)),tuple(range(sides,sides*2))]
    faces += [(k,(k+1)%sides,(k+1)%sides+sides,k+sides) for k in range(sides)]
    m.mesh(verts,faces,mat)


def structural_box(m,c,s,mat=STONE):
    m.box(c,s,mat);m.box(c,s,mat,collision=True)


def arch(m,center,span,rise,spring,thick,depth,axis='X',segments=18,fill_top=None):
    # Real elliptical voussoirs: open void below, load-bearing ring above.
    cx,cy=center
    for k in range(segments):
        a=k*math.pi/segments;b=(k+1)*math.pi/segments
        vv=[]
        for ext in (-depth/2,depth/2):
            for radius,height,t in [(span/2,rise,a),(span/2,rise,b),(span/2+thick,rise+thick,b),(span/2+thick,rise+thick,a)]:
                h=radius*math.cos(t);z=spring+height*math.sin(t)
                vv.append((cx+h,cy+ext,z) if axis=='X' else (cx+ext,cy+h,z))
        faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        m.mesh(vv,faces,TRIM if k%3 else STONE)
        m.cols.append((vv,faces))
        if fill_top is not None:
            # Solid spandrels transmit the wall/deck load into the arch ring.
            # Their outer profile follows the ring instead of leaving daylight
            # between a detached curved ribbon and a floating horizontal slab.
            aa=k*math.pi/segments;bb=(k+1)*math.pi/segments
            ha=(span/2+thick)*math.cos(aa);hb=(span/2+thick)*math.cos(bb)
            za=spring+(rise+thick)*math.sin(aa);zb=spring+(rise+thick)*math.sin(bb)
            fill=[]
            for ext in (-depth/2+.025,depth/2-.025):
                for h,z in [(ha,za),(hb,zb),(hb,fill_top),(ha,fill_top)]:
                    fill.append((cx+h,cy+ext,z) if axis=='X' else (cx+ext,cy+h,z))
            m.mesh(fill,faces,WALL if axis=='X' else STONE)
            m.cols.append((fill,faces))


def stone_courses(m,cx,cy,w,d,height,spacing=.85):
    for z in [i*spacing for i in range(1,int(height/spacing))]:
        m.box((cx,cy+d/2+.035,z),(w,.07,.055),DARKSTONE)
        m.box((cx,cy-d/2-.035,z),(w,.07,.055),DARKSTONE)
    for sx in (-1,1):
        for sy in (-1,1):
            for k in range(int(height/.9)):
                m.box((cx+sx*(w/2-.4),cy+sy*(d/2+.035),k*.9+.43),(1.05 if k%2 else .75,.20,.82),TRIM)


def gate():
    m=A.Meshes()
    for x in (-17,17):
        structural_box(m,(x,0,3.2),(16,16,6.4),DARKSTONE)
        structural_box(m,(x,0,15.35),(15.5,15.5,17.9),WALL)
        stone_courses(m,x,0,15.5,15.5,24.3,1.2)
        for z in (6.4,15.8,23.8):m.box((x,0,z),(16.4,16.4,.45),TRIM)
        # Broad battlement terraces beneath restrained copper roofs.
        m.box((x,0,24.65),(17,17,.7),TRIM)
        A.roof_piece(m,x,0,15.8,15.8,25.0,'hip',ROOF,IRON)
        m.box((x,0,28.65),(8.6,.32,.22),COPPER)
        for dx in (-4.0,0,4.0):
            for sy in (-1,1):
                origin=(x-7.75,sy*7.75);t=(1,0);n=(0,sy)
                A.window(m,origin,t,n,dx+7.75,9.0,1.65,4.6,TRIM,GLASS,IRON,False,True)
                A.window(m,origin,t,n,dx+7.75,18.2,1.5,3.9,TRIM,GLASS,IRON)
        # Stone seam band and squared corner buttresses fix the mass to grade.
        for dx in (-6.8,6.8):
            m.box((x+dx,8.18,3.8),(1.4,1.0,7.6),STONE)
        for yy in (-5.5,5.5):
            m.box((x+8.1,yy,3.8),(1.0,1.4,7.6),STONE)
        tube(m,(x,0,28.6),(x,0,30),.15,GOLD,8)
    # Eighteen-metre clear opening; towers begin at X=+-9.
    arch(m,(0,0),18,3.0,11.0,1.6,7.0,'X',20,16.0)
    structural_box(m,(0,0,17.0),(20,7,2.2),WALL)
    m.box((0,0,18.2),(21.2,8.2,.45),TRIM)
    # Very low-complexity collision leaves the entire gate opening clear.
    for y in (-3.65,3.65):
        structural_box(m,(0,y,18.95),(20,.65,1.2),STONE)
        m.box((0,y,19.6),(20.5,.92,.18),TRIM)
    for x in range(-8,9,4):
        for y in (-3.65,3.65):m.box((x,y,19.95),(1.1,.9,.6),STONE)
    # Relief shield, vertical banners and lanterns have human-scale detailing.
    tube(m,(0,4.12,16.7),(0,4.42,16.7),1.35,GOLD,16)
    m.mesh([(-.8,4.48,17.3),(.8,4.48,17.3),(.65,4.48,16.0),(0,4.48,15.55),(-.65,4.48,16.0)],[(0,1,2,3,4)],NAVY)
    for x in (-11,11):
        m.box((x,8.1,14.2),(1.75,.09,6.5),NAVY)
        m.box((x,8.2,17.5),(2.0,.2,.14),GOLD)
        m.box((x,8.6,3.9),(.6,.55,1.0),IRON)
        m.box((x,8.65,3.9),(.45,.48,.75),'0:d5bb7c')
    return m,dict(id='city_gate_grand',label='晴岚港大城门',footprint=[50,18],datum='finished street grade y=0',visible_height=30,gate_clear_width=18,gate_clear_height=14,arch_spring_height=11,central_wall_thickness=7,opening_axis='Z',doorway=[0,0,0],collision_policy='solid towers, continuous arch ring/spandrels and high crossbeam; fully open street passage')


def wall():
    m=A.Meshes()
    structural_box(m,(0,0,7.9),(32,7,15.8),WALL)
    stone_courses(m,0,0,32,7,15.8,1.25)
    structural_box(m,(0,0,16.0),(32,7.4,.4),TRIM)
    for y in (-3.1,3.1):
        structural_box(m,(0,y,16.5),(32,.8,.6),STONE)
        m.box((0,y,16.83),(32,1.0,.18),TRIM)
        for x in range(-15,16,3):
            structural_box(m,(x,y,17.4),(1.5,.9,1.2),STONE)
            m.box((x,y,18.0),(1.65,1.05,.12),TRIM)
    for x in (-12,-4,4,12):
        m.box((x,3.65,6.3),(1.15,1.0,12.6),STONE)
        m.box((x,3.8,13.15),(1.4,1.3,.7),TRIM)
    return m,dict(id='city_wall_32',label='三十二米石城墙',footprint=[32,8.5],structural_footprint=[32,7],datum='finished grade y=0',visible_height=18.06,wall_walk_y=16.2,repeat_axis='X',collision_policy='solid wall and separate parapets; authored wall-walk')


def tower():
    m=A.Meshes();r=11
    m.cylinder(0,0,-.5,r+.7,5.0,DARKSTONE,20)
    m.cylinder(0,0,4.5,r,20.0,WALL,20)
    for z in (4.5,13.0,23.8):m.cylinder(0,0,z,r+.45,.45,TRIM,20)
    m.cylinder(0,0,24.5,r+1.0,.65,TRIM,20)
    m.cylinder(0,0,25.15,r+.5,1.1,STONE,20)
    for k in range(16):
        a=k*math.tau/16;u=(math.cos(a),math.sin(a));v=(-u[1],u[0])
        m.box((u[0]*r,u[1]*r,27.05),(1.55,1.3,1.6),STONE,(v,u))
        m.box((u[0]*r,u[1]*r,27.9),(1.72,1.45,.16),TRIM,(v,u))
        for z in (8,17):
            A.window(m,(u[0]*r,u[1]*r),v,u,0,z,1.2,3.6,TRIM,GLASS,IRON)
    # A low-sided polygon collision describes the actual cylindrical body.
    poly=[(r*math.cos(k*math.tau/16),r*math.sin(k*math.tau/16)) for k in range(16)]
    m.prism(poly,-.5,26.3,STONE,True)
    return m,dict(id='city_corner_tower',label='晴岚港转角重塔',footprint=[24,24],body_diameter=22,datum='finished grade y=0',visible_height=27.98,collision_policy='one low-sided solid tower shell')


def bridge():
    m=A.Meshes()
    for y,width in [(-35.5,3),(-12,4),(12,4),(35.5,3)]:
        structural_box(m,(0,y,-4.25),(21.6,width,7.5),STONE)
        # Streamlined cutwaters, not square blocks in the water.
        if abs(y)<20:
            for side in (-1,1):
                poly=[(side*10.8,y-width/2),(side*14,y),(side*10.8,y+width/2)]
                m.prism(poly,-8,-4.2,DARKSTONE)
                m.prism(poly,-8,-4.2,DARKSTONE,True)
    for y in (-24,0,24):arch(m,(0,y),20,4.3,-5.8,1.3,22.16,'Y',20,-.2)
    structural_box(m,(0,0,-.25),(22,74,.5),STONE)
    m.box((0,0,.025),(17.0,74,.05),'2:9e9d96')
    for x in (-9.5,9.5):structural_box(m,(x,0,.10),(2.0,74,.20),TRIM)
    for x in (-10.65,10.65):
        structural_box(m,(x,0,.75),(.7,74,1.5),STONE)
        m.box((x,0,1.56),(1.0,74.3,.22),TRIM)
        for y in range(-36,37,6):
            m.box((x,y,1.0),(1.15,1.15,2.0),TRIM)
            m.box((x,y,2.08),(1.4,1.4,.18),STONE)
    for x in (-10.65,10.65):
        for y in (-24,0,24):
            tube(m,(x,y,2.15),(x,y,5.8),.10,IRON)
            m.box((x,y,5.55),(.60,.6,.88),IRON)
            m.box((x,y,5.55),(.46,.46,.68),'0:dac492')
            m.box((x,y,6.06),(.83,.83,.16),ROOF)
    return m,dict(id='city_bridge_74',label='晴岚三拱大桥',footprint=[22,74],datum='finished bridge deck y=0',visible_height=6.14,foundation_bottom_y=-8,axis='Z',clear_spans=[20,20,20],span_centers_z=[-24,0,24],walkable_width=20.0,collision_policy='flat deck, piers, cutwaters, continuous arch rings/spandrels and parapets; no detail collision')


def hull(m,length,width,top,mat=NAVY):
    stations=[(-.5,.28),(-.43,.78),(-.30,.97),(0,1),(.30,.93),(.43,.58),(.5,.03)]
    verts=[]
    for yy,f in stations:
        y=length*yy;w=width*f
        verts.extend([(0,y,-3.2),(-w*.34,y,-2.2),(-w*.5,y,0),(-w*.5,y,top),(w*.5,y,top),(w*.5,y,0),(w*.34,y,-2.2)])
    n=7;faces=[]
    for i in range(len(stations)-1):
        for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    faces += [tuple(range(n-1,-1,-1)),tuple(range((len(stations)-1)*n,len(stations)*n))]
    m.mesh(verts,faces,mat);m.cols.append((verts,faces))
    deckpoly=[(-width*f*.5,length*y) for y,f in stations]+[(width*f*.5,length*y) for y,f in reversed(stations)]
    m.prism(deckpoly,top,top+.16,DECK)
    m.prism(deckpoly,top,top+.16,DECK,True)
    for side in (-1,1):
        for i in range(len(stations)-1):
            y0,f0=stations[i];y1,f1=stations[i+1]
            p0=(side*width*f0*.5,length*y0,top+.3);p1=(side*width*f1*.5,length*y1,top+.3)
            tube(m,p0,p1,.045,CREAM)
            tube(m,(p0[0],p0[1],top+1.25),(p1[0],p1[1],top+1.25),.055,CREAM)
            count=max(1,int(math.dist(p0,p1)/1.7))
            for k in range(count):
                t=k/count;x=p0[0]+(p1[0]-p0[0])*t;y=p0[1]+(p1[1]-p0[1])*t
                tube(m,(x,y,top+.18),(x,y,top+1.27),.038,CREAM,6)
            # Continuous painted waterline band follows the hull profile.
            m.mesh([(p0[0]*1.001,p0[1],.65),(p1[0]*1.001,p1[1],.65),(p1[0]*1.001,p1[1],1.10),(p0[0]*1.001,p0[1],1.10)],[(0,1,2,3)],TRIM)
    return stations


def passenger():
    m=A.Meshes();hull(m,65,13,2.6,NAVY)
    structural_box(m,(0,-3,4.22),(10.3,38,2.9),CREAM)
    structural_box(m,(0,-1,6.93),(8.3,27,2.5),CREAM)
    structural_box(m,(0,10,9.44),(8.5,8.0,2.45),CREAM)
    for z,w,d,y in [(5.75,11.0,39,-3),(8.30,9.0,28,-1),(10.73,9.2,8.8,10)]:m.box((0,y,z),(w,d,.18),DECK)
    for side in (-1,1):
        for y in range(-19,15,3):
            m.box((side*5.2,y,4.35),(.075,1.65,1.25),GLASS)
            m.box((side*5.24,y,3.66),(.13,1.85,.11),TRIM)
        for y in range(-12,12,3):m.box((side*4.2,y,7.10),(.075,1.7,1.2),GLASS)
    for x in (-3,-1,1,3):m.box((x,14.04,9.52),(1.6,.075,1.2),GLASS)
    for y in (-7,2):
        m.cylinder(0,y,8.40,1.10,6.2,'0:b99a5d',16)
        m.cylinder(0,y,14.05,1.22,.65,NAVY,16)
        m.cylinder(0,y,8.30,1.45,.28,IRON,16)
    for y in (-24,23):
        tube(m,(0,y,2.8),(0,y,16.0),.13,WOOD)
        tube(m,(-2,y,12.5),(2,y,12.5),.08,WOOD)
        for x in (-4.5,4.5):tube(m,(x,y-3,2.8),(0,y,14),.026,IRON,6)
    for x in (-4.4,4.4):
        for y in (-13,-2):
            m.box((x,y,6.15),(1.2,5.8,.65),TRIM)
            tube(m,(x,y-3,6.5),(x,y-3,7.5),.09,IRON)
            tube(m,(x,y+3,6.5),(x,y+3,7.5),.09,IRON)
    return m,dict(id='harbor_passenger_65',label='海岚号客轮',footprint=[13,65],datum='waterline y=0',main_deck_y=2.76,visible_height=16,keel_y=-3.2,bow='-Z',collision_policy='coarse shaped hull, finished deck and three solid superstructure blocks; decoration excluded')


def sailcloth(m,y,z,w,h):
    verts=[];nx=6;nz=4
    for j in range(nz+1):
        t=j/nz
        for i in range(nx+1):
            u=i/nx;xx=(u-.5)*w*(1-.18*t)
            belly=math.sin(u*math.pi)*math.sin(t*math.pi)*.85
            verts.append((xx,y+belly,z+t*h))
    faces=[]
    for j in range(nz):
        for i in range(nx):
            k=j*(nx+1)+i;faces.append((k,k+1,k+nx+2,k+nx+1))
    m.mesh(verts,faces,'0:ded8bd')
    tube(m,(-w/2,y,z),(w/2,y,z),.08,WOOD)
    tube(m,(-w*.41,y,z+h),(w*.41,y,z+h),.065,WOOD)


def sailing():
    m=A.Meshes();hull(m,52,12,3.0,WOOD)
    stern=[(-2.6,-24.5),(-4.3,-22),(-5.4,-15),(-5.4,-10.5),(5.4,-10.5),(5.4,-15),(4.3,-22),(2.6,-24.5)]
    fore=[(-5.25,14),(-4.1,20),(-1.6,24.8),(1.6,24.8),(4.1,20),(5.25,14)]
    for poly,top,mat in [(stern,5.70,NAVY),(fore,4.4,WOOD)]:
        m.prism(poly,3.16,top,mat);m.prism(poly,3.16,top,mat,True)
        cap=[(x*1.025,y) for x,y in poly]
        m.prism(cap,top,top+.16,DECK)
        m.prism(cap,top,top+.16,DECK,True)
        for i,(x,y) in enumerate(cap):
            xx,yy=cap[(i+1)%len(cap)]
            tube(m,(x,y,top+1.15),(xx,yy,top+1.15),.045,CREAM)
            count=max(1,int(math.dist((x,y),(xx,yy))/1.7))
            for k in range(count):
                t=k/count;px=x+(xx-x)*t;py=y+(yy-y)*t
                tube(m,(px,py,top+.16),(px,py,top+1.17),.035,CREAM,6)
    for x in (-1.6,0,1.6):m.box((x,-24.54,4.55),(1.15,.08,1.12),GLASS)
    for x in (-2.7,2.7):m.box((x,-10.46,4.5),(1.5,.08,1.2),GLASS)
    m.box((0,-10.44,4.28),(1.4,.1,2.12),WOOD)
    for side in (-1,1):
        for y in (-14.6,-12.1):
            m.box((side*5.44,y,4.58),(.08,1.35,1.2),GLASS)
    for i in (1,5):
        a=stern[i];b=stern[i+1];le=math.dist(a,b)
        t=((b[0]-a[0])/le,(b[1]-a[1])/le);n=(-t[1],t[0])
        for s in (le*.3,le*.7):A.window(m,a,t,n,s,3.85,1.35,1.2,TRIM,GLASS,IRON)
    for k in range(9):
        rise=(k+1)*.3
        structural_box(m,(3.9,-6.7-k*.45,3.16+rise/2),(1.75,.45,rise),DECK)
    for y,height,width in [(-13,22,10.0),(0,29,11.7),(13,24,9.5)]:
        tube(m,(0,y,3.1),(0,y,height),.17,WOOD,12)
        for i in range(3):
            sz=7.3+i*5.2;sh=4.55 if i<2 else 3.8;sw=width-i*1.65
            if sz+sh>height-.8:continue
            sailcloth(m,y+.25,sz,sw,sh)
        for side in (-1,1):
            for off in (-2.0,2.0):tube(m,(side*5.2,y+off,3.3),(0,y,height-2),.026,IRON,6)
    for y in (-13,0):tube(m,(0,y,21),(0,y+13,24),.028,IRON,6)
    tube(m,(0,19,4.0),(0,29.0,6.8),.14,WOOD,8)
    m.mesh([(0,13.2,21.5),(0,28.8,7.1),(0,18,7.5)],[(0,1,2)],'0:ded8bd')
    for side in (-1,1):
        for y in range(-19,20,5):
            tube(m,(side*5.9,y,1.8),(side*6.03,y,1.8),.28,IRON,12)
    return m,dict(id='harbor_sailing_52',label='远航三桅帆船',footprint=[12,55.2],hull_length=52,datum='waterline y=0',main_deck_y=3.16,visible_height=29,keel_y=-3.2,bow='-Z',collision_policy='coarse shaped hull/finished decks, tapered fore/aftcastle and stern deck stairs; rigging and cloth excluded')


def crane():
    m=A.Meshes()
    structural_box(m,(0,0,.6),(8,8,1.2),DARKSTONE)
    structural_box(m,(0,0,2.1),(5,5,3.0),STONE)
    for x in (-2.0,2.0):
        for y in (-2.0,2.0):tube(m,(x,y,3.4),(x*.7,y*.7,16.7),.28,IRON)
    for z in (5,8,11,14):
        low=2-.6*(z-3.4)/13.3;high=2-.6*(z+2.7-3.4)/13.3
        for side in (-1,1):
            tube(m,(side*low,-low,z),(side*high,high,z+2.7),.13,IRON)
            tube(m,(-low,side*low,z),(high,side*high,z+2.7),.13,IRON)
    for z in (5,8,11,14,16.7):
        q=2-.6*(z-3.4)/13.3
        for side in (-1,1):
            tube(m,(side*q,-q,z),(side*q,q,z),.12,IRON)
            tube(m,(-q,side*q,z),(q,side*q,z),.12,IRON)
    m.box((0,0,16.8),(5,5,.7),IRON)
    # Nineteenth-century fixed lattice crane with a proper counterweight.
    for x in (-1.5,1.5):
        tube(m,(x,-7,17.5),(x,16,21.0),.23,IRON)
        tube(m,(x,-7,19.3),(x,16,22.8),.23,IRON)
        for k in range(10):
            y=-7+k*2.3;z=17.5+(y+7)*3.5/23
            tube(m,(x,y,z),(x,y+2.3,z+2.15),.13,IRON)
    for k in range(11):
        y=-7+k*2.3;z=17.5+(y+7)*3.5/23
        for zz in (z,z+1.8):tube(m,(-1.5,y,zz),(1.5,y,zz),.13,IRON)
    structural_box(m,(0,-5,17.8),(4,4,3.3),DARKSTONE)
    structural_box(m,(0,1.6,15.4),(3.8,3.4,3.0),NAVY)
    m.box((0,3.33,15.9),(2.8,.07,1.2),GLASS)
    for x in (-.5,.5):tube(m,(x,15,21.4),(x,15,5.0),.06,IRON)
    m.box((0,15,5.1),(1.5,.8,.6),IRON)
    tube(m,(0,15,5.0),(0,15,3.9),.14,IRON)
    tube(m,(0,15,3.9),(.65,15,3.65),.14,IRON)
    return m,dict(id='harbor_crane',label='港口桁架吊机',footprint=[8,24],datum='quayside y=0',visible_height=23.1,hook_position=[0,4.0,-15],collision_policy='base/cab/counterweight only; narrow lattice and cables excluded')


BUILDERS={'city_gate_grand':gate,'city_wall_32':wall,'city_corner_tower':tower,'city_bridge_74':bridge,'harbor_passenger_65':passenger,'harbor_sailing_52':sailing,'harbor_crane':crane}


def export_asset(name):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    m,info=BUILDERS[name]()
    objects=m.build(name)
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
    root['units']='metres';root['allow_nonuniform_scale']=False
    for ob in objects:ob.parent=root
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')))
    vis=[o for o in objects if o.name.endswith('-nocol')]
    points=[o.matrix_world@Vector(v) for o in vis for v in o.bound_box]
    lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)]
    info.update(path='res://assets/models/city_v5/civil/'+name+'.glb',scale=[1,1,1],source_blend='assets/models/city_v5/civil/'+name+'.blend',actual_bounds_godot=dict(min=[round(lo[0],3),round(lo[2],3),round(-hi[1],3)],max=[round(hi[0],3),round(hi[2],3),round(-lo[1],3)]),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in vis),collision_triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects if o.name.endswith('-colonly')))
    print('CIVIL_ASSET '+json.dumps(info,ensure_ascii=False),flush=True)
    return info


def render(info):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=1500;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.world.use_nodes=True
    bg=next((n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND'),None)
    if bg is None:
        bg=scene.world.node_tree.nodes.new('ShaderNodeBackground');wo=scene.world.node_tree.nodes.new('ShaderNodeOutputWorld');scene.world.node_tree.links.new(bg.outputs['Background'],wo.inputs['Surface'])
    bg.inputs['Color'].default_value=(.38,.43,.50,1);bg.inputs['Strength'].default_value=.55
    bridge_=info['id']=='city_bridge_74';ship=info['id'].startswith('harbor_') and 'crane' not in info['id']
    bpy.ops.mesh.primitive_plane_add(size=240,location=(0,0,-8.15 if bridge_ else -.07))
    bpy.context.object.data.materials.append(A.material('0','709aab') if ship or bridge_ else A.material('2','acaea7'))
    bpy.ops.object.light_add(type='SUN',location=(35,40,60));sun=bpy.context.object;sun.rotation_euler=(math.radians(25),math.radians(-25),math.radians(-30));sun.data.energy=3;sun.data.angle=.10
    span=max(info['footprint']);height=info['visible_height']
    loc=(span*.9,span*1.0,height*1.7+10)
    if bridge_:loc=(70,74,30)
    bpy.ops.object.camera_add(location=loc);cam=bpy.context.object
    visible=[o for o in scene.objects if o.type=='MESH' and o.name.endswith('-nocol')]
    points=[o.matrix_world@Vector(p) for o in visible for p in o.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target=(low+high)/2
    cam.location=target+Vector(loc)
    direction=(target-cam.location).to_track_quat('-Z','Y')
    cam.rotation_euler=direction.to_euler();cam.data.type='ORTHO';scene.camera=cam
    right=direction@Vector((1,0,0));up=direction@Vector((0,1,0))
    projected=[((p-target).dot(right),(p-target).dot(up)) for p in points]
    width=max(p[0] for p in projected)-min(p[0] for p in projected)
    height=max(p[1] for p in projected)-min(p[1] for p in projected)
    cam.data.ortho_scale=max(width,height*scene.render.resolution_x/scene.render.resolution_y)*1.18
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(DOC/(info['id']+'.png'))
    try:scene.view_settings.view_transform='AgX'
    except Exception:pass
    bpy.ops.render.render(write_still=True)


def main():
    bpy.context.preferences.filepaths.save_version=0
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    p=argparse.ArgumentParser();p.add_argument('--all',action='store_true');p.add_argument('--structure',action='store_true');p.add_argument('--asset');p.add_argument('--render',action='store_true');p.add_argument('--preview-only',action='store_true');a=p.parse_args(args)
    names=list(BUILDERS) if a.all else list(BUILDERS)[:4] if a.structure else [a.asset or 'city_gate_grand']
    path=OUT/'manifest.json';old=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {};records={x['id']:x for x in old.get('assets',[])}
    for name in names:
        if a.preview_only:
            bpy.ops.wm.open_mainfile(filepath=str(OUT/(name+'.blend')));render(records[name]);continue
        info=export_asset(name);records[name]=info
        manifest=dict(version='5.0',units='metres',godot_axes=dict(up='+Y',front='-Z'),scaling='Preserve unit scale. Translate and rotate whole native assets.',source='tools/blender/city_v5/civil.py',assets=list(records.values()))
        path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
        (DOC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
        if a.render:render(info)
    print('CIVIL_DONE '+str(len(names)),flush=True)


if __name__=='__main__':main()
