"""Qinglan / Solenne v5 native-metre architecture library.

Run: blender -b --python architecture.py -- --hero
     blender -b --python architecture.py -- --all

Axes: Blender +Z up, +Y street-facing; glTF/Godot +Y up, -Z front.
Ground-floor datum is zero. Exterior grade is -0.60 m. Do not scale assets.
Appearance is merged by material. Low-complexity collision meshes are named
*-colonly for Godot's scene importer; walkable shop doorways remain open.
"""
from pathlib import Path
import argparse
import json
import math
import sys
import time

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/city_v5/architecture"
DOC = ROOT / "docs/city_v5/architecture"
OUT.mkdir(parents=True, exist_ok=True)
DOC.mkdir(parents=True, exist_ok=True)

PALETTES = {
    "limestone": dict(wall="d5c6ad", stone="a99c84", trim="ede3cb", roof="344557", accent="476a6e"),
    "rose": dict(wall="ac7169", stone="aaa08b", trim="eee2cd", roof="485563", accent="753e39"),
    "sage": dict(wall="9ea99c", stone="a49e8d", trim="e4dec8", roof="466d65", accent="365d54"),
    "ochre": dict(wall="c5a078", stone="a59880", trim="eee0c2", roof="735044", accent="816342"),
    "academy": dict(wall="a9aaba", stone="a09fa4", trim="eae8db", roof="374d62", accent="484f78"),
    "brick": dict(wall="8e5142", stone="9a8b73", trim="d2c4a7", roof="46505a", accent="665447"),
    "white": dict(wall="d9d7c9", stone="aaa796", trim="f0e9d8", roof="52786e", accent="486959"),
}

# All dimensions describe finished, authored geometry, never a target scale.
SPECS = [
    dict(id="corner_merchants_3", label="商人街角公馆", w=32, d=26, floors=3, shape="L", palette="limestone", enter=True, roof="mansard", use="commercial_corner"),
    dict(id="corner_copper_4", label="铜绿街角住宅", w=34, d=26, floors=4, shape="L", palette="sage", enter=False, roof="hip", use="residential_corner"),
    dict(id="courtyard_college_3", label="学院三面庭院", w=36, d=26, floors=3, shape="U", palette="academy", enter=True, roof="hip", use="academy_courtyard"),
    dict(id="courtyard_residence_3", label="白石庭院住宅", w=36, d=26, floors=3, shape="U", palette="white", enter=False, roof="mansard", use="residential_courtyard"),
    dict(id="shop_arcade_3", label="石廊商铺街屋", w=24, d=20, floors=3, shape="rect", palette="limestone", enter=True, roof="mansard", use="commercial"),
    dict(id="shop_rose_4", label="玫石商铺街屋", w=28, d=22, floors=4, shape="rect", palette="rose", enter=False, roof="mansard", use="commercial"),
    dict(id="residence_slate_3", label="蓝灰屋顶住宅", w=22, d=20, floors=3, shape="rect", palette="limestone", enter=False, roof="hip", use="residential"),
    dict(id="residence_ochre_4", label="赭石屋顶住宅", w=26, d=22, floors=4, shape="rect", palette="ochre", enter=False, roof="hip", use="residential"),
    dict(id="academy_library_3", label="学术街书屋", w=26, d=22, floors=3, shape="rect", palette="academy", enter=False, roof="mansard", use="academy"),
    dict(id="academy_lodgings_4", label="学者宿舍", w=28, d=22, floors=4, shape="rect", palette="white", enter=False, roof="hip", use="academy"),
    dict(id="inn_seafarer_3", label="海风旅人客栈", w=28, d=24, floors=3, shape="rect", palette="rose", enter=True, roof="mansard", use="inn"),
    dict(id="mansion_garden_3", label="花园大宅", w=26, d=22, floors=3, shape="rect", palette="white", enter=False, roof="hip", use="mansion"),
    dict(id="warehouse_brick_2", label="港区红砖仓库", w=30, d=24, floors=2, shape="rect", palette="brick", enter=False, roof="gable", use="warehouse"),
    dict(id="warehouse_stone_1", label="港区低层货栈", w=32, d=24, floors=1, shape="rect", palette="ochre", enter=False, roof="gable", use="warehouse"),
]


def rgb(h):
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))


def material(kind, color):
    # Numeric K types follow src/core/util.gd; dark glass stays opaque, allowing
    # stable depth/shadowing while the deliberately open door provides access.
    key = "K|%s|%s||0" % (kind, color)
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.new(key)
    m.diffuse_color = (*rgb(color), 1)
    m.use_nodes = True
    bs = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bs is None:
        bs=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
        output=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
        m.node_tree.links.new(bs.outputs['BSDF'],output.inputs['Surface'])
    bs.inputs["Base Color"].default_value = (*rgb(color), 1)
    bs.inputs["Roughness"].default_value = .28 if kind == "7" else .72
    bs.inputs["Metallic"].default_value = .72 if kind == "7" else 0
    return m


class Meshes:
    def __init__(self):
        self.groups = {}
        self.cols = []
        self.entries = []

    def mesh(self, verts, faces, mat):
        g = self.groups.setdefault(mat, [[], []])
        n = len(g[0])
        g[0].extend(verts)
        g[1].extend(tuple(n+i for i in f) for f in faces)

    def box(self, center, size, mat, axes=None, collision=False):
        x, y, z = center
        a, b, c = (v/2 for v in size)
        points = [(sx*a, sy*b, sz*c) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        if axes:
            u, v = axes
            points = [(x+p*u[0]+q*v[0], y+p*u[1]+q*v[1], z+r) for p,q,r in points]
        else:
            points = [(x+p,y+q,z+r) for p,q,r in points]
        faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        if collision:
            self.cols.append((points,faces))
        else:
            self.mesh(points,faces,mat)

    def prism(self, poly, lo, hi, mat, collision=False):
        n=len(poly)
        verts=[(x,y,z) for z in (lo,hi) for x,y in poly]
        faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        if collision:
            self.cols.append((verts,faces))
        else:
            self.mesh(verts,faces,mat)

    def cylinder(self, x,y,z, radius,height,mat,sides=8):
        pts=[(x+radius*math.cos(i*math.tau/sides),y+radius*math.sin(i*math.tau/sides),zz) for zz in (z,z+height) for i in range(sides)]
        faces=[tuple(range(sides-1,-1,-1)),tuple(range(sides,sides*2))]
        faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
        self.mesh(pts,faces,mat)

    def build(self, prefix):
        out=[]
        for mat,(verts,faces) in self.groups.items():
            me=bpy.data.meshes.new(prefix+"_"+mat)
            me.from_pydata(verts,[],faces)
            me.update()
            bm=bmesh.new();bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            bm.to_mesh(me);bm.free()
            ob=bpy.data.objects.new(prefix+"_"+mat+"-nocol",me)
            bpy.context.collection.objects.link(ob)
            k,h=mat.split(":")
            me.materials.append(material(k,h))
            out.append(ob)
        # A single low-complexity collision mesh per asset. Individual boxes
        # form only foundations, walls, floor and stairs, never decoration.
        vv=[];ff=[]
        for verts,faces in self.cols:
            n=len(vv);vv.extend(verts);ff.extend(tuple(n+i for i in f) for f in faces)
        me=bpy.data.meshes.new(prefix+"_collision")
        me.from_pydata(vv,[],ff);me.update()
        bm=bmesh.new();bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(me);bm.free()
        co=bpy.data.objects.new(prefix+"-colonly",me)
        bpy.context.collection.objects.link(co)
        co.hide_render=True
        co.display_type="WIRE"
        out.append(co)
        return out


def polygon(spec):
    w,d=spec['w'],spec['d']
    if spec['shape']=="L":
        return [(-w/2,d/2),(w/2,d/2),(w/2,d/2-12),(-w/2+12,d/2-12),(-w/2+12,-d/2),(-w/2,-d/2)]
    if spec['shape']=="U":
        return [(-w/2,d/2),(w/2,d/2),(w/2,-d/2),(w/2-9,-d/2),(w/2-9,d/2-10),(-w/2+9,d/2-10),(-w/2+9,-d/2),(-w/2,-d/2)]
    return [(-w/2,d/2),(w/2,d/2),(w/2,-d/2),(-w/2,-d/2)]


def face_box(m, origin, tangent, normal, s, depth, z, width, thickness, height, mat, collision=False):
    x=origin[0]+tangent[0]*s+normal[0]*depth
    y=origin[1]+tangent[1]*s+normal[1]*depth
    m.box((x,y,z+height/2),(width,thickness,height),mat,(tangent,normal),collision)


def window(m,origin,t,n,s,z,w,h,trim,glass,iron,balcony=False,arched=False):
    # 26 cm deep reveal with an inset glazing plane and projecting sill.
    face_box(m,origin,t,n,s,.02,z,w,.055,h,glass)
    for dx in (-w/2-.09,w/2+.09):
        face_box(m,origin,t,n,s+dx,.15,z-.12,.18,.28,h+.24,trim)
    face_box(m,origin,t,n,s,.19,z-.16,w+.58,.48,.16,trim)
    face_box(m,origin,t,n,s,.15,z+h,w+.38,.29,.16,trim)
    face_box(m,origin,t,n,s,.08,z,.055,.08,h,iron)
    face_box(m,origin,t,n,s,.08,z+h*.68,w,.08,.055,iron)
    if arched:
        # A small genuine raised segmental stone arch over the rectangular
        # window, not a disc or a flat painted arch.
        r=w*.56
        for k in range(9):
            a=(k+.5)*math.pi/9
            ss=s+math.cos(a)*r
            zz=z+h+.05+math.sin(a)*.35
            face_box(m,origin,t,n,ss,.15,zz,.20,.28,.14,trim)
    if balcony:
        bw=w+.9
        face_box(m,origin,t,n,s,.51,z-.25,bw,1.1,.18,trim)
        face_box(m,origin,t,n,s,1.03,z-.05,bw,.08,.06,iron)
        face_box(m,origin,t,n,s,1.03,z+.90,bw,.09,.075,iron)
        for k in range(int(bw/.20)+1):
            a=s-bw/2+k*bw/max(1,int(bw/.20))
            face_box(m,origin,t,n,a,1.03,z,.035,.035,.92,iron)
        for a in (-bw/2,bw/2):
            face_box(m,origin,t,n,s+a,.54,z+.90,.06,1.0,.075,iron)
            for b in (.25,.5,.75):
                face_box(m,origin,t,n,s+a,b,z,.035,.035,.92,iron)


def roof_piece(m,cx,cy,w,d,z,style,roof,trim):
    # Authored volumetric roof. All dimensions stay in metres.
    w+=.9;d+=.9
    if style=="gable":
        verts=[(cx-w/2,cy-d/2,z),(cx+w/2,cy-d/2,z),(cx+w/2,cy+d/2,z),(cx-w/2,cy+d/2,z),(cx,cy-d/2,z+4.4),(cx,cy+d/2,z+4.4)]
        m.mesh(verts,[(0,1,4),(3,5,2),(0,4,5,3),(1,2,5,4),(0,3,2,1)],roof)
        m.box((cx,cy,z+4.43),(.22,d+.15,.16),trim)
        return 4.6
    rise=min(3.5,min(w,d)*.35) if style=="hip" else 4.6
    if style=="mansard":
        iw=max(3,w-4.0);id_=max(3,d-4.0)
        verts=[(cx+sx*w/2,cy+sy*d/2,z) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        verts += [(cx+sx*iw/2,cy+sy*id_/2,z+3.0) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        m.mesh(verts,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],roof)
        w,d,z=iw,id_,z+3.0
        rr=1.6
    else:
        rr=rise
    ridge=max(1,w-d*.45)
    verts=[(cx-w/2,cy-d/2,z),(cx+w/2,cy-d/2,z),(cx+w/2,cy+d/2,z),(cx-w/2,cy+d/2,z),(cx-ridge/2,cy,z+rr),(cx+ridge/2,cy,z+rr)]
    m.mesh(verts,[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4)],roof)
    m.box((cx,cy,z+rr+.035),(ridge+.15,.16,.14),trim)
    return rise


def build_asset(spec):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    p=PALETTES[spec['palette']]
    wall="0:"+p['wall'];stone="2:"+p['stone'];trim="9:"+p['trim'];roof="3:"+p['roof']
    dark="7:263139";glass="7:34464b";wood="6:594736";accent="0:"+p['accent'];brick="1:815546"
    m=Meshes();poly=polygon(spec);w,d=spec['w'],spec['d'];floors=spec['floors']
    first=5.8 if spec['use']=="warehouse" and floors==1 else 4.8
    height=first+max(0,floors-1)*3.8
    commercial=spec['use'] in ('commercial','commercial_corner','inn')
    # Stone structural plinth and subgrade footings are continuous.
    m.prism(poly,-1.2,-.18,stone)
    m.prism(poly,-.18,0,"6:8c7758" if spec['enter'] else "2:bcb6a6")
    m.prism(poly,-.3,0,stone,True)
    # Upper storeys have actual repeated levels, floor plates and roof lines.
    if floors>1:
        m.prism(poly,first,height,wall)
    if spec['enter']:
        m.prism(poly,first-.32,first,stone,True)
    else:
        m.prism(poly,0,first,wall)
        m.prism(poly,0,height,wall,True)
    edges=[]
    for i,a in enumerate(poly):
        b=poly[(i+1)%len(poly)]
        le=math.dist(a,b);t=((b[0]-a[0])/le,(b[1]-a[1])/le);n=(-t[1],t[0])
        edges.append((a,t,n,le))
    for ei,(a,t,n,le) in enumerate(edges):
        front=ei==0
        courtyard=spec['shape']=='U' and ei==4
        door=front or (spec['enter'] and courtyard)
        dw=3.4 if spec['enter'] else 2.4
        if spec['use']=="warehouse":dw=5.8
        dc=le/2
        # Enterable shells have a real hole; all visible façade infill is
        # generated around that hole rather than masking a closed wall.
        if spec['enter']:
            if door:
                for lo,hi in [(0,dc-dw/2),(dc+dw/2,le)]:
                    if hi>lo:
                        face_box(m,a,t,n,(lo+hi)/2,-.27,0,hi-lo,.54,first,stone,True)
                        face_box(m,a,t,n,(lo+hi)/2,-.27,0,hi-lo,.54,first,stone)
                face_box(m,a,t,n,dc,-.27,3.65,dw,.54,first-3.65,stone,True)
                face_box(m,a,t,n,dc,-.27,3.65,dw,.54,first-3.65,stone)
            else:
                face_box(m,a,t,n,le/2,-.27,0,le,.54,first,stone,True)
                face_box(m,a,t,n,le/2,-.27,0,le,.54,first,stone)
        bays=max(2,round(le/(4.2 if commercial else 3.8)))
        pitch=le/bays
        # Lower rustication, heavy vertical piers, and deep shop openings.
        for j in range(bays):
            s=(j+.5)*pitch
            in_door=door and abs(s-dc)<dw/2+pitch*.35
            shopw=min(pitch-.8,3.2 if commercial else 2.3)
            if spec['enter']:
                if not in_door:
                    # The structural shell already supplies the spandrel and
                    # sill wall. Adding another coplanar box here caused a
                    # solid black self-shadow band in Cycles / Godot.
                    for ds in (-pitch/2+.23,pitch/2-.23):
                        face_box(m,a,t,n,s+ds,-.18,.5,.46,.46,3.55,stone)
            if not in_door:
                gh=3.1 if commercial else 2.3
                gz=.65 if commercial else 1.05
                window(m,a,t,n,s,gz,shopw,gh,trim,glass,dark,arched=not commercial)
                if commercial:
                    # Timber storefront fascia, supported shallow metal canopy.
                    face_box(m,a,t,n,s,.16,3.88,shopw+.35,.35,.35,accent)
                    if front:
                        face_box(m,a,t,n,s,.62,3.75,shopw+.5,1.3,.12,accent)
                        for ds in (-shopw/2,shopw/2):
                            face_box(m,a,t,n,s+ds,.58,3.38,.065,.8,.065,dark)
            # Stone piers with real recessed mortar courses, no texture needed.
            for zz in range(8):
                if not in_door:
                    face_box(m,a,t,n,j*pitch+.25,.055,zz*.57,.45,.20,.52,stone)
        if door:
            # Dark/open entry flanked by dimensioned dressed stone jambs.
            for ds in (-dw/2-.16,dw/2+.16):
                face_box(m,a,t,n,dc+ds,.17,0,.32,.48,3.65,trim)
            face_box(m,a,t,n,dc,.28,3.65,dw+.64,.56,.30,trim)
            face_box(m,a,t,n,dc,.30,4.02,dw+.95,.75,.18,trim)
            if not spec['enter']:
                face_box(m,a,t,n,dc,.035,0,dw,.10,3.65,wood)
                for j in (-1,1):
                    face_box(m,a,t,n,dc+j*dw*.25,.10,.4,dw*.40,.045,2.5,accent)
                    face_box(m,a,t,n,dc+j*.15,.16,1.3,.055,.12,.25,"7:a68a50")
            else:
                # Real folded wooden leaf, alongside the hole, not across it.
                face_box(m,a,t,n,dc-dw/2+.08,-.78,.05,.10,1.30,3.35,wood)
            for k in range(3):
                dep=(3-k)*.42
                zz=-.6+k*.2
                face_box(m,a,t,n,dc,dep/2+.02,zz,dw+.95,dep,.2,stone)
            # A capsule cannot climb these hard 0.20m risers: edge contacts
            # present a roughly 60-degree normal to the real Player. Keep
            # the visible stair nosings, but use one continuous 25.46-degree
            # collision ramp touching all three nosings and the indoor floor.
            profile=[(0,-.8),(1.70,-.8),(1.70,-.6),(.44,0),(0,0)]
            ramp=[]
            for side in (-1,1):
                for outside,zr in profile:
                    ss=dc+side*(dw+.95)/2
                    ramp.append((a[0]+t[0]*ss+n[0]*outside,a[1]+t[1]*ss+n[1]*outside,zr))
            rf=[(4,3,2,1,0),(5,6,7,8,9)]+[(j,(j+1)%5,(j+1)%5+5,j+5) for j in range(5)]
            m.cols.append((ramp,rf))
            px=a[0]+t[0]*dc;py=a[1]+t[1]*dc
            m.entries.append(dict(position=[round(px,3),0,round(-py,3)],outward=[round(n[0],3),0,round(-n[1],3)],clear_width=dw,clear_height=3.65,open=spec['enter'],approach_depth=1.70,approach_ramp_degrees=round(math.degrees(math.atan(.6/1.26)),3)))
        # Real height rhythm, continuous floor string-courses and cornices.
        for floor in range(1,floors):
            z=first+(floor-1)*3.8
            face_box(m,a,t,n,le/2,.08,z-.10,le,.23,.22,trim)
            for j in range(bays):
                s=(j+.5)*pitch
                balcony=floor==1 and (front or (ei in (1,2) and spec['shape']=='L')) and j%2==0 and spec['use']!='warehouse'
                window(m,a,t,n,s,z+.68,min(1.75,pitch-.85),2.35,trim,glass,dark,balcony,arched=spec['use'] in ('academy','academy_courtyard','mansion'))
                if floor==1 and j%2==0 and spec['use']!='warehouse':
                    face_box(m,a,t,n,s,.26,z+3.28,2.05,.5,.14,trim)
        # Proper dressed corners, alternating quoins, not corner towers.
        for end in (.28,le-.28):
            for k in range(int(height/.6)):
                face_box(m,a,t,n,end,.10,k*.6,.56 if k%2 else .85,.26,.54,trim)
        for zz,th,dep in [(height-.33,.22,.34),(height-.06,.19,.65),(height+.17,.12,.84)]:
            face_box(m,a,t,n,le/2,dep/2-.10,zz,le+.28,dep,th,trim)
    # Fitted roof wings: valleys at L/U joins, substantial silhouettes.
    if spec['shape']=='L':
        pieces=[(0,d/2-6,w,12),(-w/2+6,-6,12,d-12)]
    elif spec['shape']=='U':
        pieces=[(0,d/2-5,w,10),(-w/2+4.5,-5,9,d-10),(w/2-4.5,-5,9,d-10)]
    else:
        pieces=[(0,0,w,d)]
    roofrise=0
    for cx,cy,rw,rd in pieces:
        roofrise=max(roofrise,roof_piece(m,cx,cy,rw,rd,height+.28,spec['roof'],roof,dark))
    # Dormers belong to the main street roof, not to every random parcel.
    if spec['roof']=='mansard':
        for j in range(max(2,int(w/6))):
            x=-w/2+(j+.5)*w/max(2,int(w/6))
            y=d/2-1.15
            m.box((x,y,height+1.65),(1.95,2.1,2.40),wall)
            window(m,(x-.975,y+1.05),(1,0),(0,1),.975,height+.63,1.26,1.72,trim,glass,dark)
            roof_piece(m,x,y,2.16,2.35,height+2.88,"hip",roof,trim)
    # Chimney caps, stacked brick courses, and paired clay pots.
    for x in (-w*.28,w*.28):
        cy=d*.08 if spec['shape']=='rect' else d/2-5.7
        z=height+roofrise*.72
        m.box((x,cy,z+1.12),(1.16,.96,2.24),brick)
        m.box((x,cy,z+2.28),(1.42,1.22,.22),trim)
        for dx in (-.3,.3):m.cylinder(x+dx,cy,z+2.4,.17,.56,brick,8)
    # Simple useful interiors, deliberately restricted to four shop/inn assets.
    if spec['enter']:
        # The structural slab already supplies the interior surface at y=0;
        # an overlapping floor prism would create another black plinth seam.
        for x in (-w*.25,w*.25):
            m.box((x,d*.10,2.4),(.42,.42,4.8),wood)
            m.box((x,d*.10,.2),(.65,.65,.40),stone)
            m.box((x,d*.10,2.4),(.65,.65,4.8),wood,collision=True)
        # Counter against a side wall, clear 4m route behind the entrance.
        m.box((-w/2+1.7,d/2-4.8,.58),(2.1,5.0,1.16),wood)
        m.box((-w/2+1.7,d/2-4.8,1.2),(2.35,5.2,.16),stone)
        m.box((-w/2+1.7,d/2-4.8,.6),(2.35,5.2,1.3),wood,collision=True)
        for x in (-w*.25,w*.25):
            m.box((x,d/2-5.5,first-.58),(3.1,.10,.12),"7:b09b67")
        # Pendant lights stay warm but do not add per-instance real lights.
        for x in (-w*.22,w*.22):
            m.box((x,d/2-5.0,first-.25),(.045,.045,.5),dark)
            m.box((x,d/2-5.0,first-.65),(.45,.45,.35),"0:e1c48c")
    objects=m.build(spec['id'])
    collision_ob=next(ob for ob in objects if ob.name.endswith('-colonly'))
    collision_bvh=BVHTree.FromPolygons([v.co.copy() for v in collision_ob.data.vertices],[list(p.vertices) for p in collision_ob.data.polygons],all_triangles=False)
    checks=[]
    for e in m.entries:
        center=Vector((e['position'][0],-e['position'][2],1.25))
        normal=Vector((e['outward'][0],-e['outward'][2],0))
        hit=collision_bvh.ray_cast(center+normal*2.2,-normal,4.8)[0]
        open_actual=hit is None
        if open_actual != e['open']:
            raise RuntimeError('Door collision contract failed: '+spec['id']+' '+str(e))
        floorhit=collision_bvh.ray_cast(center-normal*1.0,Vector((0,0,-1)),3.0)[0]
        checks.append(dict(entry=e['position'],clear_at_player_height=open_actual,floor_y=round(floorhit.z,4) if floorhit is not None else None))
    root=bpy.data.objects.new(spec['id'],None)
    bpy.context.collection.objects.link(root)
    root['units']='metres';root['allow_nonuniform_scale']=False
    for ob in objects:ob.parent=root
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=root
    path=OUT/(spec['id']+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(spec['id']+'.blend')))
    visible=[ob for ob in objects if not ob.name.endswith('-colonly')]
    vs=[ob.matrix_world@Vector(v) for ob in visible for v in ob.bound_box]
    low=[min(v[i] for v in vs) for i in range(3)];high=[max(v[i] for v in vs) for i in range(3)]
    triangles=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in visible)
    ct=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects if ob.name.endswith('-colonly'))
    item=dict(id=spec['id'],label=spec['label'],path='res://assets/models/city_v5/architecture/'+spec['id']+'.glb',source_blend='assets/models/city_v5/architecture/'+spec['id']+'.blend',footprint=[w,d],footprint_polygon=[[x,-y] for x,y in poly],visible_height=round(high[2],3),wall_height=round(height,3),floors=floors,first_floor_height=first,upper_floor_height=3.8,ground_floor_y=0,street_y=-.6,placement_lift=.6,foundation_bottom_y=-1.2,entry=m.entries,shape=spec['shape'],street_side='-Z',corner_wing='-X wing extends toward +Z' if spec['shape']=='L' else '',courtyard_open_side='+Z' if spec['shape']=='U' else '',use=spec['use'],enterable=spec['enter'],scale=[1,1,1],collision='Godot importer: one low-complexity -colonly mesh, open doorway shell' if spec['enter'] else 'Godot importer: one low-complexity -colonly mesh, solid residential body',collision_checks=checks,appearance_meshes=len(visible),triangles=triangles,collision_triangles=ct,bounds_godot={'min':[round(low[0],3),round(low[2],3),round(-high[1],3)],'max':[round(high[0],3),round(high[2],3),round(-low[1],3)]})
    print('ARCHITECTURE_ASSET '+json.dumps(item,ensure_ascii=False),flush=True)
    return item


def render_asset(spec, suffix='front'):
    scene=bpy.context.scene
    try:scene.render.engine='CYCLES'
    except Exception:pass
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1400;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
    scene.world.color=(.24,.27,.31)
    scene.world.use_nodes=True
    bg=next((n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND'),None)
    if bg is None:
        bg=scene.world.node_tree.nodes.new('ShaderNodeBackground')
        wo=scene.world.node_tree.nodes.new('ShaderNodeOutputWorld')
        scene.world.node_tree.links.new(bg.outputs['Background'],wo.inputs['Surface'])
    bg.inputs['Color'].default_value=(.33,.40,.52,1)
    bg.inputs['Strength'].default_value=.45
    bpy.ops.mesh.primitive_plane_add(size=220,location=(0,0,-.63))
    ground=bpy.context.object;ground.name='preview_ground'
    ground.data.materials.append(material('2','a5aaa7'))
    bpy.ops.object.light_add(type='SUN',location=(30,35,55))
    sun=bpy.context.object;sun.rotation_euler=(math.radians(28),math.radians(-24),math.radians(-32));sun.data.energy=3.0;sun.data.angle=math.radians(8)
    bpy.ops.object.light_add(type='AREA',location=(-25,20,35))
    area=bpy.context.object;area.data.energy=1700;area.data.shape='DISK';area.data.size=30
    target=Vector((0,0,8));area.rotation_euler=(target-area.location).to_track_quat('-Z','Y').to_euler()
    loc=(49,62,37) if suffix=='front' else (45,-55,42)
    if suffix=='entry':loc=(5,spec['d']/2+9,2.0)
    bpy.ops.object.camera_add(location=loc)
    cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,9))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=59 if spec['w']>=32 else 52
    if suffix=='entry':
        cam.data.type='PERSP';cam.data.lens=27
        cam.rotation_euler=(Vector((0,spec['d']/2-3,1.8))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.lens=48;scene.camera=cam
    try:scene.view_settings.view_transform='AgX'
    except Exception:pass
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(DOC/(spec['id']+'_'+suffix+'.png'))
    bpy.ops.render.render(write_still=True)


def main():
    bpy.context.preferences.filepaths.save_version=0
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser();parser.add_argument('--hero',action='store_true');parser.add_argument('--all',action='store_true');parser.add_argument('--asset');parser.add_argument('--render',action='store_true');parser.add_argument('--gallery',action='store_true');parser.add_argument('--preview-only',action='store_true');parser.add_argument('--view',default='front',choices=['front','back','entry'])
    opt=parser.parse_args(args)
    if opt.gallery:
        for spec in SPECS:
            bpy.ops.wm.open_mainfile(filepath=str(OUT/(spec['id']+'.blend')))
            render_asset(spec,'front')
        print('ARCHITECTURE_GALLERY_DONE',flush=True)
        return
    selected=SPECS if opt.all else [s for s in SPECS if s['id']==opt.asset] if opt.asset else [SPECS[0]]
    if opt.preview_only:
        for spec in selected:
            bpy.ops.wm.open_mainfile(filepath=str(OUT/(spec['id']+'.blend')))
            render_asset(spec,opt.view)
        return
    manifest_path=OUT/'manifest.json'
    old=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    records={a['id']:a for a in old.get('assets',[])}
    for spec in selected:
        item=build_asset(spec);records[item['id']]=item
        doc=dict(version='5.0',authoring_units='metres',godot_axes=dict(up='+Y',front='-Z'),placement='Place root at finished street grade + 0.6m. Rotation and translation only; preserve unit scale.',source='tools/blender/city_v5/architecture.py',assets=list(records.values()))
        manifest_path.write_text(json.dumps(doc,ensure_ascii=False,indent=2),encoding='utf-8')
        (DOC/'manifest.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2),encoding='utf-8')
        if opt.hero or opt.render:
            render_asset(spec,opt.view)
    (DOC/'README.md').write_text('''# 晴岚港 v5 住宅建筑库\n\n原生米制建筑，Godot 正面 -Z，室内地坪 y=0，街面 y=-0.6m。节点放在整平街面 +0.6m，保持 scale=(1,1,1)。各楼层、窗门、台阶均为固定真实尺寸。\n\n外观按材质合并。`-colonly` 子网格由 Godot 导入为静态低复杂碰撞；商铺、客栈和学院庭院的首层入口留有真实门洞与室内地坪。住宅可以封闭。图形细节不参与碰撞。\n\n详细尺寸、入口、轮廓、实际高度和碰撞三角形数量见 manifest.json。每个GLB同目录保留对应.blend。\n\n构建：Blender 后台运行 tools/blender/city_v5/architecture.py -- --all。单体预览：--asset corner_merchants_3 --render。\n''',encoding='utf-8')
    print('ARCHITECTURE_DONE '+str(len(selected)),flush=True)


if __name__=='__main__':main()
