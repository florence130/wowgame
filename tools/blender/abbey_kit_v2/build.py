"""Editable abbey modules and lit assemblies. Blender 5.2 background entrypoint.

blender -b --factory-startup --python build.py -- --out ABS_PATH --style concept
blender -b --factory-startup --python build.py -- --out ABS_PATH --style game
Each build has its own packed .blend, GLBs, manifest, textures and actual renders.
"""
import sys, argparse, json, math, random
from pathlib import Path
import bpy, bmesh
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'abbey_kit'))
import geometry as G
import build as B
sys.path.insert(0,str(HERE))
import materials as M
import details as D
import roofs as R
import apse_base

ASSETS={}; MAN=[]; PLACEMENTS=[]; STYLE='concept'

def repair_degenerate_evaluations(r):
    """Clean numerical slivers at Boolean/Bevel tangencies on affected meshes only."""
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    for o in r.children_recursive:
        if o.type!='MESH':continue
        ev=o.evaluated_get(dg);probe=ev.to_mesh();probe.calc_loop_triangles()
        bad=any((probe.vertices[t.vertices[1]].co-probe.vertices[t.vertices[0]].co).cross(probe.vertices[t.vertices[2]].co-probe.vertices[t.vertices[0]].co).length<1e-10 for t in probe.loop_triangles)
        ev.to_mesh_clear()
        if not bad:continue
        me=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg)
        bm=bmesh.new();bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-5)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        zero=[f for f in bm.faces if f.calc_area()<5e-11]
        if zero:bmesh.ops.delete(bm,geom=zero,context='FACES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
        o.modifiers.clear();o.data=me;o['numerical_slivers_repaired']=True

def scene(name):
    s=bpy.data.scenes.new(name);bpy.context.window.scene=s
    s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    return s

def root(name,collection=None):
    return B.empty(name,collection or bpy.context.scene.collection)

def asset(key,label,fn,methods,sockets=None):
    bpy.context.window.scene=LIB
    c=bpy.data.collections.new('ABY_'+key);LIB.collection.children.link(c)
    r=root(key,c);G.COL=c;G.ROOT=r;fn();bpy.context.view_layer.update();repair_degenerate_evaluations(r)
    r['asset_id']=key;r['style']=STYLE;r['unit']='metres'
    ASSETS[key]=r
    stat=B.evaluated_stats(r)
    MAN.append(dict(id=key,label_zh=label,methods=methods,sockets=sockets or [],**stat))
    print('ASSET',key,stat['triangles'],flush=True)

def inst(key,xyz=(0,0,0),angle=0,parent=None,scale=None):
    src=ASSETS[key];c=bpy.context.scene.collection
    r=root(key+'_instance',c);r.location=xyz;r.rotation_euler.z=math.radians(angle)
    if parent:r.parent=parent
    if scale:r.scale=scale
    mapping={src:r}
    for o in src.children_recursive:
        cp=o.copy();cp.data=o.data;c.objects.link(cp);mapping[o]=cp
    for o,cp in list(mapping.items())[1:]:
        cp.parent=mapping[o.parent];cp.matrix_parent_inverse=o.matrix_parent_inverse.copy();cp.matrix_basis=o.matrix_basis.copy()
    PLACEMENTS.append(dict(asset=key,position=list(xyz),rotation_z_deg=angle,assembly=parent.name if parent else bpy.context.scene.name))
    return r

def shifted(fn,xyz=(0,0,0),angle=0):
    before=set(G.COL.objects);fn()
    from mathutils import Matrix
    m=Matrix.Translation(xyz)@Matrix.Rotation(math.radians(angle),4,'Z')
    for o in set(G.COL.objects)-before:o.matrix_basis=m@o.matrix_basis

def circular_outline(radius,z,segments=48):
    return [(radius*math.cos(i*math.tau/segments),z+radius*math.sin(i*math.tau/segments)) for i in range(segments)]

def facade_material_wall(name,outline,depth,holes=(),width=8,height=9.4):
    o=G.profile(name,outline,depth,'plaster')
    for i,h in enumerate(holes):G.subtract(o,G.profile('Opening tool',h,depth+2,None))
    G.bevel(o,.035)
    if STYLE=='game':
        # A thin masonry skin is cut by the same opening silhouettes as the wall.
        parts=[];rng=random.Random(11)
        course=.43
        for row in range(math.ceil(height/course)):
            z=(row+.5)*course
            for col in range(math.ceil(width/1.03)+2):
                x=-width/2+(col-.5+.5*(row%2))*1.03
                if x< -width/2-.45 or x>width/2+.45:continue
                parts.append(G.box('Ashlar face',(1.018,.055,course-.016),(x,depth/2+.007,z),rng.choice(['plaster']*6+['sandstone','stone_mid']),.014))
        # Intersect skin with full facade including its roof line, then openings.
        skin=D._merge(parts,'Masonry courses')[0]
        tool=G.profile('Masonry clipping envelope',outline,depth+1,None)
        mod=skin.modifiers.new('Clip stonework to gable','BOOLEAN');mod.operation='INTERSECT';mod.solver='EXACT';mod.object=tool;G.apply_modifier(skin,mod);bpy.data.objects.remove(tool,do_unlink=True)
        for h in holes:G.subtract(skin,G.profile('Stone opening',h,depth+2,None))
    return o

def front_wall():
    h=7.1 if STYLE=='concept' else 6
    outline=[(-4,0),(4,0),(4,h+.20),(0,h+3.4),(-4,h+.20)]
    facade_material_wall('Nave front gable',outline,.46,[G.arch_outline(2.5,2.55,bottom=-.15),circular_outline(1.25*.83,6.65)])
    for z in (.22,.48):
        for x in (-2.7,2.7):G.box('Foundation course',(2.6,.63,.22),(x,.02,z),'stone_dark',.025)
    # Entry stays open through the skirting.
    for x in (-2.7,2.7):G.box('Front base trim',(2.3,.68,.26),(x,.025,.58),'sandstone',.025)

def wall_bay(height=6,sill=3.1,window=True):
    wh=2.3
    if STYLE=='concept':height=7.1;sill=5.05;wh=1.65
    height+=.20
    holes=[D.pointed_outline(1.1,wh,sill)] if window else []
    facade_material_wall('Nave repeat wall',[(-2,0),(2,0),(2,height),(-2,height)],.46,holes,4,height)
    G.box('Stone base',(4,.61,.42),(0,0,.21),'stone_dark',.025)
    G.box('Stone base rim',(4,.66,.13),(0,0,.49),'sandstone',.017)
    G.box('Eave timber ledger',(4,.55,.18),(0,0,height-.12),'timber',.02)

def plinth():
    G.box('Dressed platform',(4,4,.62),(0,0,.31),'stone_dark',.045)
    G.box('Platform upper rim',(4,4,.18),(0,0,.71),'sandstone',.025)

def floor():
    parts=[]
    for x in range(4):
        for y in range(4):parts.append(G.box('Paving slab',(.987,.987,.10),(-1.5+x,-1.5+y,.05),'sandstone' if (x+y)%4 else 'stone_light',.016))
    D._merge(parts,'Paving 4m')

def stair():
    for i in range(5):G.box('Stone tread',(4.2,.46,.16*(5-i)),(0,.23+i*.44,.08*(5-i)),'sandstone',.025)

def buttress():
    # .76 avoids a coplanar side face with the foundation course at Y=.335.
    o=G.profile('Outward stepped stone buttress',[(-.16,0),(.96,0),(.90,1.2),(.72,1.6),(.72,3.35),(.51,3.75),(.51,5.35),(.15,5.8),(-.16,5.8)],.76,'sandstone')
    o.rotation_euler.z=math.pi/2;G.bevel(o,.023)
    G.box('Buttress plinth',(.89,1.26,.36),(0,.41,.18),'stone_dark',.035)
    for z,depth,y in [(1.25,1.1,.4),(3.40,.86,.28),(5.35,.67,.18)]:G.box('Buttress sloped step cap',(.86,depth,.14),(0,y,z),'stone_light',.018)

def column():
    G.lathe('Stone column',[(.43,0),(.43,.18),(.31,.23),(.28,.38),(.23,1.85),(.30,2.04),(.38,2.08),(.38,2.18)],'sandstone',12)
    G.box('Square capital',(.86,.84,.20),(0,0,2.2),'stone_light',.026)

def arcade():
    # The column ends at2.3; round arch rises from2.3 to3.85 with wall to4.15.
    facade_material_wall('Arcade spandrel',[(-2,2.25),(2,2.25),(2,4.15),(-2,4.15)],.42,[G.arch_outline(3.1,2.3,bottom=-.1)],4,4.15)
    D.stone_arch(width=3.1,spring=2.3,bottom=2.3,depth=.56,thickness=.25)
    G.box('Arcade timber eave',(4,.64,.19),(0,0,4.16),'timber',.02)

def tower_wall():
    facade_material_wall('Tower lower wall',[(-2,0),(2,0),(2,6),(-2,6)],.5,[D.pointed_outline(.7,1.65,3.3)],4,6)
    G.box('Tower base',(4.1,.7,.5),(0,0,.25),'stone_dark',.026)

def belfry_wall():
    facade_material_wall('Belfry arched wall',[(-2,0),(2,0),(2,3.1),(-2,3.1)],.5,[G.arch_outline(2.35,1.6,bottom=-.1)],4,3.1)
    D.stone_arch(2.35,1.6,0,.68,.25)

def boundary():
    facade_material_wall('Boundary wall',[(-2,0),(2,0),(2,1.65),(-2,1.65)],.5,(),4,1.65)
    G.box('Boundary stone foot',(4,.65,.29),(0,0,.145),'stone_dark',.025)
    shifted(lambda:R.pitched_roof(.7,4,rise=.21),(0,0,1.68),90)

def gate_wall():
    facade_material_wall('Roofed courtyard gate',[(-1.5,0),(1.5,0),(1.5,3.1),(0,3.75),(-1.5,3.1)],.6,[G.arch_outline(1.45,1.6,bottom=-.05)],3,3.75)
    D.stone_arch(1.45,1.6,0,.76,.24)
    shifted(lambda:D.oak_double_door(1.41,1.58),(0,.07,0))
    shifted(lambda:R.pitched_roof(3,.95,rise=.7),(0,0,3.1))
    shifted(lambda:R.gable_fascia(3,rise=.7),(0,.48,3.1))

def apse():
    # Half-circle rear sanctuary, modular footprint joins nave at y=0.
    radius=3.5;h=5.35;n=12;parts=[]
    for i in range(n):
        a=i*math.pi/n;b=(i+1)*math.pi/n
        rr=(radius-.2,radius+.2)
        v=[(r*math.cos(t),-r*math.sin(t),z) for z in (0,h) for r,t in [(rr[0],a),(rr[1],a),(rr[1],b),(rr[0],b)]]
        parts.append(G.mesh('Apse stone wall',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'plaster'))
    wall=D._merge(parts,'Apse curved stone wall')[0]
    for side in (-1,1):
        G.box('Apse end joint pier',(.44,.60,h),(side*3.50,.08,h/2),'sandstone',.02)
    # Radial overlapping tile rows rather than a smooth cone.
    verts=[];faces=[];mi=[]
    for row in range(8):
        r1=3.85*(1-row/9);r2=3.85*(1-(row+1)/9)
        z1=h+.1+row*.27;z2=z1+.29
        for i in range(24):
            a=i*math.pi/24+.004;b=(i+1)*math.pi/24-.004
            v=[(r*math.cos(t),-r*math.sin(t),z+d) for d in (0,.07) for r,t,z in [(r1,a,z1),(r1,b,z1),(r2,b,z2),(r2,a,z2)]]
            base=len(verts);verts+=v
            for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:faces.append(tuple(base+j for j in f));mi.append((i+row)%3)
    o=G.mesh('Apse radial slate tiles',verts,faces,None)
    for k in ['terracotta','tile_dark','tile_light']:o.data.materials.append(G.material(k))
    for p,i in zip(o.data.polygons,mi):p.material_index=i
    count=24
    v=[(.45*math.cos(i*math.pi/count),-.45*math.sin(i*math.pi/count),h+2.03) for i in range(count+1)]
    v.extend([(0,0,h+2.03),(0,0,h+2.37)])
    f=[(i,i+1,count+2) for i in range(count)]+[(count+1,i+1,i) for i in range(count)]+[(0,count+2,count)]
    G.mesh('Apse closing half-cone',v,f,'terracotta')
    for deg in (30,90,150):
        a=math.radians(deg);xyz=(radius*math.cos(a),-radius*math.sin(a),0);angle=-90-deg
        from mathutils import Matrix
        cutter=G.profile('Apse matching window hole',D.pointed_outline(.8,2.1,1.7),1.5,None)
        cutter.matrix_basis=Matrix.Translation(xyz)@Matrix.Rotation(math.radians(angle),4,'Z')
        G.subtract(wall,cutter)
        outer=((radius+.20)*math.cos(a),-(radius+.20)*math.sin(a),0)
        shifted(lambda:D.pointed_window(.8,2.1,1.7),outer,angle)

def register():
    defs=[
      ('plinth_4','4米石地台',plinth,['profile_extrude']),('floor_stone_4','4米石地板',floor,['array']),
      ('facade_8','礼拜堂开洞山墙',front_wall,['CSG','profile_extrude']),
      ('wall_clerestory_4','4米高窗侧墙',wall_bay,['CSG','profile_extrude']),
      ('window_clerestory','尖拱彩窗',lambda:D.pointed_window(1.1,1.65,5.05) if STYLE=='concept' else D.pointed_window(1.1,2.3,3.1),['profile_extrude','curve_bevel']),
      ('door_arch','分块拱石门框',lambda:D.stone_arch(2.5,2.55,0,.62,.34),['profile_extrude']),
      ('door_oak','分板木双门与铁件',lambda:D.oak_double_door(2.46,2.53),['CSG','profile_extrude']),
      ('rose_window','花瓣圆花窗',lambda:D.rose_window(1.25,8 if STYLE=='game' else 6),['profile_extrude','curve_bevel']),
      ('quoin_6','6米转角石',lambda:D.quoin_column(6,.58),['array']),
      ('buttress','阶梯石扶壁',buttress,['profile_extrude']),('corbel','屋檐木托架',D.corbel,['vertices']),
      ('roof_nave_4','主屋顶4米叠瓦段',lambda:R.pitched_roof(8,4,3.4),['mirror','solidify','array']),
      ('roof_end','主屋顶短檐',lambda:R.pitched_roof(8,.3,3.4),['mirror','array']),
      ('roof_fascia','主山墙封檐',lambda:R.gable_fascia(8,3.4),['mirror','profile_extrude']),
      ('roof_shed_4','4米侧廊披屋',lambda:R.shed_roof(2.8,4,1.4),['solidify','array']),
      ('roof_cloister_4','4米回廊屋顶',lambda:R.pitched_roof(3.4,4,1.25),['mirror','array']),
      ('roof_tower','钟楼塔顶',lambda:(R.spire_roof(4.9,4.2) if STYLE=='game' else R.hip_roof(4.9,2.2)),['loft','array']),
      ('dormer','三角老虎窗',R.dormer,['profile_extrude']),('chimney','分层烟囱',R.roof_chimney,['CSG','profile_extrude']),
      ('ridge_cross','屋脊石十字',R.ridge_cross,['profile_extrude']),('stairs','5级石阶',stair,['array']),
      ('column','回廊石柱',column,['spin']),('arcade','回廊分块拱跨',arcade,['CSG','profile_extrude']),
      ('tower_wall','钟楼开窗墙',tower_wall,['CSG']),('tower_window','钟楼窄窗',lambda:D.pointed_window(.7,1.65,3.3),['profile_extrude']),
      ('belfry','开放钟室拱墙',belfry_wall,['CSG','profile_extrude']),
      ('boundary_4','4米带瓦帽院墙',boundary,['profile_extrude','array']),('gate','院墙门楼',gate_wall,['CSG','profile_extrude']),
    ]
    if STYLE=='game':
        defs.append(('apse','半圆后殿',apse,['loft','array']))
        defs.append(('apse_plinth','半圆后殿地台',apse_base.build,['profile_extrude','array']))
    for key,label,fn,meth in defs:
        sock=[]
        if key.endswith('_4'):
            axis=1 if key.startswith('roof') else 0
            for sign in (-1,1):
                pos=[0,0,0];pos[axis]=sign*2;n=pos.copy();n[axis]=sign
                sock.append(dict(name='start' if sign<0 else 'end',position_blender=pos,normal_blender=n,kind=key))
        asset(key,label,fn,meth,sock)

def chapel():
    r=root('Chapel');r.location=(4,0,0)
    roof_z=7.9 if STYLE=='concept' else 6.8
    for x in (-2,2):
        for y in (-6,-2,2,6):inst('plinth_4',(x,y,0),parent=r);inst('floor_stone_4',(x,y,.8),parent=r)
    inst('facade_8',(0,8,.8),parent=r);inst('facade_8',(0,-8,.8),180,r)
    for k in ('door_arch','door_oak'):inst(k,(0,8.15,.8),parent=r)
    inst('rose_window',(0,8.26,7.45),parent=r);inst('stairs',(0,8.38,0),parent=r)
    if STYLE=='game':
        for x in (-3.65,3.65):inst('buttress',(x,8,.8),parent=r)
    for sx in (-1,1):
        angle=-90 if sx==1 else 90
        for y in (-6,-2,2,6):
            inst('wall_clerestory_4',(sx*4,y,.8),angle,r)
            inst('window_clerestory',(sx*4.22,y,.8),angle,r)
            for dy in (-1.75,1.75):inst('corbel',(sx*4,y+dy,roof_z),angle,r)
        for y in (-8,-4,0,4,8):inst('buttress',(sx*4,y,.8),angle,r)
        for y in (-8,8):inst('quoin_6',(sx*3.91,y,.8),parent=r)
    for y in (-6,-2,2,6):inst('roof_nave_4',(0,y,roof_z),parent=r)
    for sy in (-1,1):
        inst('roof_end',(0,sy*8.15,roof_z),parent=r);inst('roof_fascia',(0,sy*8.18,roof_z),0 if sy==1 else 180,r)
        inst('ridge_cross',(0,sy*8,roof_z+3.44),parent=r)
    for sx in (-1,1):
        for y in (-4,3.8):inst('dormer',(sx*2.75,y,roof_z+.95),90 if sx==1 else -90,r)
    # Roof chimneys are integral architecture, not courtyard props.
    for y in (-6.5,4.8):inst('chimney',(.8,y,roof_z+2.49),parent=r)
    if STYLE=='concept':
        for sx in (-1,1):
            for y in (-6,-2,2,6):
                inst('roof_shed_4',(sx*4,y,4.37),0 if sx==1 else 180,r)
                inst('arcade',(sx*6.40,y,.05),-90 if sx==1 else 90,r)
            for y in (-8,-4,0,4,8):inst('column',(sx*6.40,y,.05),parent=r)
    else:
        inst('apse',(0,-8,.8),parent=r);inst('apse_plinth',(0,-8,0),parent=r)
    return r

def tower():
    r=root('BellTower');r.location=(-9,-4,0)
    for key in ('plinth_4',):inst(key,parent=r)
    for x,y,a in [(0,2,0),(0,-2,180),(2,0,-90),(-2,0,90)]:
        inst('tower_wall',(x,y,.8),a,r)
        inst('tower_window',(x*1.12,y*1.12,.8),a,r)
        inst('belfry',(x,y,6.85),a,r)
    for x in (-1.9,1.9):
        for y in (-1.9,1.9):inst('quoin_6',(x,y,.8),parent=r)
    G.COL=bpy.context.scene.collection;G.ROOT=r
    for z in (.8,3.65,6.75,9.85):G.box('Tower belt stone',(4.45,4.45,.23),(0,0,z),'sandstone',.035)
    G.box('Tower eave soffit',(4.66,4.66,.20),(0,0,9.96),'timber',.025)
    inst('roof_tower',(0,0,9.98),parent=r)
    inst('ridge_cross',(0,0,14.25 if STYLE=='game' else 12.23),parent=r)
    # Structural belfry beam is retained. Independent bell/props excluded by scope.
    G.box('Bell chamber beam',(3.7,.25,.3),(0,0,9.15),'timber',.02)
    return r

def courtyard():
    r=root('CourtyardArchitecture')
    for y in (0,4,8):
        inst('roof_cloister_4',(-9,y,4.21),parent=r)
        for x in (-10.65,-7.35):inst('arcade',(x,y,.05),90 if x< -9 else -90,r)
    for y in (-2,2,6,10):
        for x in (-10.65,-7.35):inst('column',(x,y,.05),parent=r)
    # Low enclosing wall: continuous spans either side of a real gate.
    for x in (-9.5,-1.5):inst('boundary_4',(x,11.0,0),parent=r)
    inst('gate',(-5.5,11,0),parent=r)
    # Fill the half-metre end intervals at the gate with stone piers.
    G.COL=bpy.context.scene.collection;G.ROOT=r
    for x in (-11.5,-7.25,-3.75,.5):
        G.box('Boundary pier',(.62,.8,1.98),(x,11,.99),'sandstone',.025)
        G.box('Pier cap',(.78,.95,.17),(x,11,2),'stone_light',.025)
    for y in (-4,0,4,8):inst('boundary_4',(-11.5,y,0),90,r)
    for x in (-9.5,-5.5,-1.5):inst('boundary_4',(x,-6,0),parent=r)
    for x in (-9.5,-5.5,-1.5):
        for y in (-3,1,5,9):inst('floor_stone_4',(x,y,-.08),parent=r)
    return r

def main():
    global LIB,STYLE
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--style',choices=['concept','game'],default='concept');p.add_argument('--no-export',action='store_true');p.add_argument('--res',type=int,default=1500)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);STYLE=args.style;out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    for folder in ('glb','assemblies','renders'): (out/folder).mkdir(exist_ok=True)
    if STYLE=='game':
        palette=M.use_game_palette();(out/'palette_mapping.json').write_text(json.dumps(palette,ensure_ascii=False,indent=2),encoding='utf8')
    M.install(out)
    LIB=scene('ABY2_'+STYLE+'_Library');register()
    if not args.no_export:
        for key,r in ASSETS.items():B.export_root(r,out/'glb'/f'{key}.glb')
    demo=scene('ABY2_'+STYLE+'_Courtyard');M.light_scene(demo)
    roots=[chapel(),tower(),courtyard()]
    if not args.no_export:
        for r in roots:B.export_root(r,out/'assemblies'/f'{r.name}.glb')
    G.COL=demo.collection;G.ROOT=None
    G.box('Presentation ground',(200,200,.18),(0,0,-.24),'ground',.05)
    B.camera(demo,(-.7,1,5.2),(29,39,25),36,args.res)
    demo.render.resolution_y=int(args.res*.79)
    bpy.context.window.scene=demo
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
    manifest=dict(version='abbey-v2',style=STYLE,scope='architecture only; no vegetation, ivy or standalone props',assets=MAN,palette=M.COLORS,placements=PLACEMENTS,source_reference='docs/abbey_kit_v1/concept_v1.png' if STYLE=='concept' else 'docs/buildings_v2/vale_abbey_chapel/hero.png + tools/gen_vale.gd::_abbey',assemblies=[dict(id=r.name,**B.evaluated_stats(r)) for r in roots])
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    B.render(demo,out/'renders'/'courtyard.png')
    # Front three-quarter detail exposes entry, masonry, tile edges and real shadows.
    demo.camera.location=(-12,26,15);demo.camera.rotation_euler=(Vector((3.3,5.5,5))-demo.camera.location).to_track_quat('-Z','Y').to_euler();demo.camera.data.ortho_scale=20
    B.render(demo,out/'renders'/'chapel_detail.png')
    print('BUILD COMPLETE',out,flush=True)

if __name__=='__main__':main()
