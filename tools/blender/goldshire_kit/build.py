"""Goldenear village: metric, reusable, hollow architecture. Blender background entry.
blender -b --factory-startup -t 8 --python build.py -- --out <new directory>
Z up / +Y front in Blender; Y up / -Z front in GLB. Palette is the project JSON.
"""
import argparse, json, math, sys, struct, zlib, random
from pathlib import Path
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix

HERE=Path(__file__).resolve().parent
PROJECT=HERE.parents[2]
sys.path[:0]=[str(HERE.parent/'abbey_kit'),str(HERE.parent/'abbey_kit_v2')]
import geometry as G
import build as BASE
import roofs as R
import sdf as SDF

ASSETS={}; MAN=[]; PRESETS={}; PLACES=[]; CACHE={}; OUT=None; SDF_STONE=None
PAL={c[0]:c[2].lstrip('#') for g in json.loads((PROJECT/'docs/palette/palette.json').read_text(encoding='utf8'))['groups'] for c in g['colors']}
ALIASES={'sandstone':'stone','tile_dark':'terracotta_dark','tile_light':'terracotta_light','cloth':'linen'}
PAIRS={'plaster':['plaster','plaster_white'],'plaster_ochre':['plaster_ochre','plaster'],
 'plaster_rose':['plaster_rose','plaster'],'stone':['stone','stone_light','stone_dark'],
 'stone_dark':['stone_dark','stone'],'foundation':['foundation','stone_dark'],
 'wood':['wood','wood_honey'],'timber':['timber','wood_dark'],'wood_pale':['wood_pale','wood_honey'],
 'terracotta':['terracotta','terracotta_light'],'terracotta_dark':['terracotta_dark','terracotta'],
 'slate':['slate','slate_light'],'slate_dark':['slate_dark','slate'],
 'thatch':['thatch','thatch_dark'],'linen':['linen','burlap'],'wood_green':['wood_green','forest_cloth']}

def png(path,a):
    h,w,c=a.shape
    def ch(n,d):return struct.pack('>I',len(d))+n+d+struct.pack('>I',zlib.crc32(n+d)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(b''.join(b'\0'+a[y].tobytes() for y in range(h)),8))+ch(b'IEND',b''))

def material(key):
    key=ALIASES.get(key,key)
    if key in CACHE:return CACHE[key]
    h=PAL[key]; rgb=tuple(G.linear(int(h[i:i+2],16)) for i in (0,2,4))
    m=bpy.data.materials.new('GS_'+key);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    m['palette_key']=key;m['base_srgb']='#'+h;m['palette_source']='docs/palette/palette.json'
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1)
    bs.inputs['Roughness'].default_value=.88;bs.inputs['Specular IOR Level'].default_value=.22
    if key=='glass':
        bs.inputs['Alpha'].default_value=.24;bs.inputs['Roughness'].default_value=.21
        bs.inputs['Transmission Weight'].default_value=.25
        m.surface_render_method='DITHERED';m.use_transparent_shadow=True
    elif key in ('iron','bronze'):
        bs.inputs['Metallic'].default_value=.5;bs.inputs['Roughness'].default_value=.65
    elif key in PAIRS:
        n=512;y,x=np.mgrid[0:n,0:n]/n
        # Quantized pigment only. Every stored texel is an actual palette swatch.
        pat=(np.sin(math.tau*(x+.21*np.sin(math.tau*y)))+.42*np.cos(math.tau*(2*y+x)))/1.42
        if key.startswith(('wood','timber')):pat=np.sin(math.tau*(13*x+.15*np.sin(math.tau*y)))
        idx=(pat>.72).astype(int)
        if key in ('stone','stone_dark','foundation'):idx=np.zeros_like(idx)
        colors=np.array([[int(PAL[k][i:i+2],16) for i in (0,2,4)] for k in PAIRS[key]],dtype=np.uint8)
        path=OUT/'textures'/f'{key}_basecolor.png';png(path,colors[idx])
        im=bpy.data.images.load(str(path));im.pack();tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest'
        mapping=m.node_tree.nodes.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=(.18,.18,.18)
        uv=m.node_tree.nodes.new('ShaderNodeTexCoord');m.node_tree.links.new(uv.outputs['UV'],mapping.inputs['Vector']);m.node_tree.links.new(mapping.outputs['Vector'],tex.inputs['Vector'])
        m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    CACHE[key]=m;return m

def scene(name):
    s=bpy.data.scenes.new(name);bpy.context.window.scene=s;s.unit_settings.system='METRIC';return s

def empty(name):
    o=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(o);return o

def shift(fn,loc=(0,0,0),angle=0):
    before=set(G.COL.objects);fn();mat=Matrix.Translation(loc)@Matrix.Rotation(math.radians(angle),4,'Z')
    for o in set(G.COL.objects)-before:o.matrix_basis=mat@o.matrix_basis

def asset(key,label,fn,methods,sockets=None):
    bpy.context.window.scene=LIB
    c=bpy.data.collections.new('GS_'+key);LIB.collection.children.link(c)
    r=bpy.data.objects.new(key,None);c.objects.link(r);G.COL=c;G.ROOT=r
    fn();r['asset_id']=key;r['methods']=','.join(methods)
    # Retain modifier sources, generate exact collision from evaluated solids later.
    ASSETS[key]=r
    stat=BASE.evaluated_stats(r)
    entry={'id':key,'label_zh':label,'methods':methods,'sockets':sockets or [],**stat}
    MAN.append(entry);print('ASSET',key,stat['triangles'],flush=True)

def sock(axis,half,kind):
    return [{'name':n,'position_blender':[s*half if i==axis else 0 for i in range(3)],'normal_blender':[s if i==axis else 0 for i in range(3)],'kind':kind} for n,s in [('start',-1),('end',1)]]

def inst(key,loc=(0,0,0),angle=0,parent=None):
    src=ASSETS[key];r=empty(key+'_instance');r.parent=parent;r.location=loc;r.rotation_euler.z=math.radians(angle)
    mapping={src:r}
    for o in src.children_recursive:
        cp=o.copy();cp.data=o.data;bpy.context.scene.collection.objects.link(cp);mapping[o]=cp
    for o,cp in list(mapping.items())[1:]:cp.parent=mapping[o.parent];cp.matrix_basis=o.matrix_basis.copy();cp.matrix_parent_inverse=o.matrix_parent_inverse.copy()
    PLACES.append({'assembly':parent.name if parent else bpy.context.scene.name,'asset':key,'position_blender':list(loc),'rotation_z_deg':angle})
    return r

def box(n,size,loc,mat='wood',b=.02):return G.box(n,size,loc,mat,b)

def wall(w=2,kind='plain',mat='plaster'):
    h=3.4;th=.30
    if kind=='door':
        for side in (-1,1):box('Wall jamb',((w-2)/2,th,h),(side*(w+2)/4,0,h/2),mat)
        box('Door lintel wall',(2,th,.6),(0,0,3.1),mat)
        for side in (-1,1):box('Deep timber door frame',(.16,.48,2.8),(side*1.07,0,1.4),'timber')
        box('Door head beam',(2.3,.48,.18),(0,0,2.87),'timber')
    elif kind=='window':
        for side in (-1,1):box('Pier',((w-1.2)/2,th,h),(side*(w+1.2)/4,0,h/2),mat)
        box('Sill wall',(1.2,th,1.05),(0,0,.525),mat)
        box('Window head wall',(1.2,th,.95),(0,0,2.925),mat)
    else:box('Wall panel',(w,th,h),(0,0,h/2),mat)
    for x in (-w/2+.09,w/2-.09):box('Boundary post',(.18,.4,h),(x,0,h/2),'timber')
    for z in ((3.25,) if kind=='door' else (.16,3.25)):box('Ledger',(w,.42,.18),(0,0,z),'timber')
    if kind=='plain' and w>=1.9:
        G.beam('Half timber diagonal',(-w/2+.18,.18,.32),(w/2-.18,.18,2.95),.14)

def window(w=1.2,h=1.4,shutters=True):
    for x in (-w/2-.055,w/2+.055):box('Window jamb',(.11,.19,h+.22),(x,.05,1.05+h/2),'wood')
    for z in (1.0,1.1+h):box('Window header',(w+.22,.19,.12),(0,.05,z),'wood')
    box('Transparent glass',(w-.035,.024,h-.03),(0,.02,1.05+h/2),'glass',0)
    box('Window mullion',(.055,.10,h),(0,.08,1.05+h/2),'wood')
    box('Window crossbar',(w,.10,.055),(0,.08,1.05+h*.55),'wood')
    box('Projecting stone sill',(w+.4,.46,.13),(0,.12,1.0),'stone_light')
    if shutters:
        for side in (-1,1):
            for i in range(3):box('Shutter board',(.17,.09,h*.94),(side*(w/2+.2+i*.18),.08,1.05+h/2),'wood_green',.008)
            for z in (1.22,1.05+h-.16):box('Shutter brace',(.58,.13,.095),(side*(w/2+.38),.105,z),'timber',.008)

def door():
    # Origin at left hinge; the preset rotates leaf outwards by 105 degrees.
    for i in range(8):box('Door plank',(.242,.095,2.7),(.125+i*.249,0,1.35),'wood',.008)
    for z in (.45,2.22):box('Iron strap',(1.84,.13,.1),(1,0,z),'iron',.007)
    G.ring('Iron handle',.085,1.35,.022,'iron',10,y=.085).location.x=1.73

def foundation(w=2):
    box('Foundation core',(w,.48,.40),(0,0,-.20),'foundation')
    for row in range(2):
        for i in range(int(w*2)):
            box('Dressed base stone',(.485,.53,.185),(-w/2+.25+i*.5,0,-.30+row*.20),'stone' if (i+row)%3 else 'stone_dark',.027)

def floor(w=2,d=2):
    box('Floor structural slab',(w,d,.18),(0,0,-.10),'timber')
    o=box('Plank floor',(.244,d,.04),(-w/2+.125,0,-.02),'wood_pale',.006);G.array(o,int(w/.25),(.25,0,0))

def gable(w=6,rise=2.7):
    run=w/2+.45;sag=min(.10,run*.024)
    def roof_underside(x):return rise*(1-abs(x)/run)-sag*math.sin(math.pi*abs(x)/run)-.17
    points=[(-w/2,0),(w/2,0)]+[(w/2-w*i/20,roof_underside(w/2-w*i/20)) for i in range(21)]
    o=G.profile('Gable plaster',points,.3,'plaster_ochre')
    for side in (-1,1):
        pts=[(side*w/2*(1-i/6),.16,roof_underside(side*w/2*(1-i/6))-.105) for i in range(7)]
        G.line('Gable rake timber',pts,.085,'timber')
    G.beam('King post',(0,.18,0),(0,.18,rise-.25),.20)
    box('Gable tie',(w,.43,.18),(0,0,.09),'timber')
    for x in (-w*.23,w*.23):G.beam('Gable short stud',(x,.16,.1),(x,.16,rise*.48),.15)

def roof(w,mat='terracotta'):
    if mat=='thatch':return thatch_roof(w)
    before=set(G.COL.objects);R.pitched_roof(w,2,w*.45,seed=w)
    if mat!='terracotta':
        mp={'terracotta':mat,'terracotta_dark':mat+'_dark','terracotta_light':mat+'_light' if mat=='slate' else 'thatch'}
        for o in set(G.COL.objects)-before:
            for slot in o.material_slots:
                k=slot.material['palette_key'];slot.material=material(mp.get(k,k))

def thatch_roof(w):
    run=w/2+.60;rise=w*.45
    def z(r):return rise*(1-(r/run)**1.30)
    verts=[];faces=[]
    for i in range(17):
        x=run*i/16
        for y in (-1,1):verts.append((x,y,z(x)))
    for i in range(16):faces.append((2*i,2*i+1,2*i+3,2*i+2))
    o=G.mesh('Curved bundled straw roof',verts,faces,'thatch');m=o.modifiers.new('01 Mirrored roof halves','MIRROR');m.use_axis[0]=True;m.use_clip=True
    m=o.modifiers.new('04 Thick thatch edge','SOLIDIFY');m.thickness=.30
    # Broad layered thatch hems, no clay-shaped tiles coloured yellow.
    for side in (-1,1):
        for row in range(6):
            r=run*(row+1)/6
            for j in range(8):
                y=-.875+j*.25;end=min(run,r+.1)
                G.line('Sparse straw binding',[(side*(r-.26),y,z(r-.26)+.018),(side*end,y+.02,z(end)+.03)],.016,'thatch_dark' if j%3==0 else 'thatch')
        G.line('Rounded hanging thatch eave',[(side*run,-1,-.12),(side*(run+.025),0,-.13),(side*run,1,-.12)],.15,'thatch')
    G.line('Bound straw ridge',[(0,-1,rise+.04),(0,1,rise+.04)],.15,'thatch_dark')

def thatch_end(w,wall=False):
    run=w/2+.60;rise=w*.45
    def z(x):return rise*(1-(abs(x)/run)**1.30)
    if wall:
        points=[(-w/2,0),(w/2,0)]+[(w/2-w*i/20,z(w/2-w*i/20)-.17) for i in range(21)]
        G.profile('Curved upper gable infill',points,.3,'plaster_ochre')
        box('Gable tie',(w,.4,.20),(0,0,.10),'timber');G.beam('Gable king post',(0,.17,0),(0,.17,rise-.20),.2)
    else:
        G.line('Rounded straw end',[(x,0,z(x)-.12) for x in np.linspace(-run,run,33)],.16,'thatch')

def stone_sdf():
    global SDF_STONE
    if SDF_STONE is None:SDF_STONE=SDF.polygonize('stone',.15,True)
    v,f=SDF_STONE;o=G.mesh('Refined analytic SDF dressed stone',[(x*.48,y*.7,z*.35) for x,y,z in v],f,'stone')
    m=o.modifiers.new('SDF low-poly correction','DECIMATE');m.ratio=.36
    o['source_route']='analytic signed-distance field -> marching tetrahedra -> decimate; metric core is separate'

def column():
    G.lathe('Turned porch post',[(.22,0),(.22,.18),(.16,.25),(.14,2.62),(.22,2.76),(.24,2.82)],'timber',8)
    box('Post stone shoe',(.5,.5,.2),(0,0,.1),'stone')
    for side in (-1,1):G.beam('Knee brace',(0,0,2.25),(side*.68,0,2.80),.15)

def rail():
    for x in (-.91,.91):box('Rail end post',(.18,.18,1.05),(x,0,.525),'timber')
    for z in (.20,.98):box('Rail horizontal',(2,.16,.13),(0,0,z),'wood')
    G.beam('Rail cross A',(-.83,0,.26),(.83,0,.92),.08,'wood')
    G.beam('Rail cross B',(-.83,.045,.92),(.83,.045,.26),.08,'wood')

def stairs():
    # Ascend -Y. Top at y=-2.7,z=3.4. Smooth dedicated collision ramp in metadata.
    for i in range(17):box('Stair tread',(1.5,.34,.13),(0,2.7-(i+.5)*5.4/17,(i+1)*.2-.065),'wood_pale',.015)
    for side in (-1,1):
        G.beam('Stair stringer',(side*.65,2.7,-.10),(side*.65,-2.7,3.25),.18)
        G.beam('Stair handrail',(side*.78,2.7,1),(side*.78,-2.7,4.4),.085,'wood')
        for i in (0,4,8,12,16):
            y=2.7-(i+.5)*5.4/17;z=(i+1)*.2
            box('Baluster',(.065,.065,1),(side*.78,y,z+.5),'timber',.006)

def awning():
    # Genuine editable Solidify, low polygon curved canvas profile.
    verts=[]
    for i in range(9):
        y=i*.25;z=3.0-.46*y+.055*y*y
        verts.extend([(-2,y,z),(2,y,z)])
    o=G.mesh('Canvas canopy',verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(8)],'linen')
    mod=o.modifiers.new('04 Canvas thickness','SOLIDIFY');mod.thickness=.028
    for x in (-1.88,1.88):box('Awning support',(.12,.12,2.29),(x,1.9,1.145),'timber')
    box('Canopy front rail',(4.1,.10,.12),(0,2,2.30),'timber')
    for i in range(8):box('Striped valance',(.5,.045,.27),(-1.75+i*.5,2,2.17),'forest_cloth' if i%2 else 'linen',.012)

def chimney():
    # Hollow flue, four separate solid walls, neither roof cube nor plugged chimney.
    for side in (-1,1):
        box('Chimney long wall',(1.05,.19,3.1),(0,side*.43,1.55),'stone')
        box('Chimney short wall',(.19,.67,3.1),(side*.43,0,1.55),'stone')
    for z in (.25,1.45,2.95):
        for side in (-1,1):
            box('Flue cap long',(1.22,.24,.17),(0,side*.48,z),'stone_light')
            box('Flue cap short',(.24,.73,.17),(side*.49,0,z),'stone_light')

def counter():
    box('Counter body',(2,.70,.96),(0,0,.48),'wood')
    box('Counter top',(2.12,.84,.12),(0,0,1.02),'wood_pale')
    for x in (-.86,0,.86):box('Counter raised frame',(.11,.06,.78),(x,.37,.50),'timber')

def shelf():
    for x in (-.9,.9):box('Shelf side',(.12,.48,2.3),(x,0,1.15),'timber')
    for z in (.18,.85,1.52,2.24):box('Shelf plank',(1.92,.48,.1),(0,0,z),'wood_pale')
    box('Shelf back',(1.8,.05,2.1),(0,-.22,1.2),'wood')

def forge():
    for x in (-.84,.84):box('Forge cheek',(.32,1.35,1.25),(x,0,.625),'stone_dark')
    box('Forge hearth',(2,1.5,.32),(0,0,.16),'stone_dark')
    box('Forge rear',(2,.32,2.4),(0,-.62,1.2),'stone')
    o=G.profile('Tapered forge hood',[(-1.1,1.5),(1.1,1.5),(.5,2.8),(-.5,2.8)],1.45,'iron');G.bevel(o,.03)
    box('Forge opening dark back',(1.25,.04,.9),(0,-.43,.81),'iron',0)

def worktable():
    box('Cutting table top',(2.8,1.35,.12),(0,0,1.03),'wood_pale')
    for x in (-1.1,1.1):
        for y in (-.45,.45):box('Table leg',(.14,.14,1),(x,y,.5),'timber')
    box('Cloth on cutting table',(1.9,1.1,.026),(0,0,1.106),'linen',0)

def sign(icon):
    G.beam('Sign mounting arm',(0,-.1,3.05),(0,1.28,3.05),.10,'iron')
    for x in (-.45,.45):G.line('Sign suspension',[(x,.93,3.02),(x,.93,2.55)],.024,'iron')
    o=G.profile('Carved signboard',[(-.7,1.82),(.7,1.82),(.8,2.18),(.63,2.60),(-.63,2.60),(-.8,2.18)],.14,'wood_dark',y=.93)
    if icon=='smithy':
        G.profile('Anvil emblem',[(-.47,2.32),(.50,2.32),(.32,2.16),(.1,2.16),(.15,1.97),(-.24,1.97),(-.18,2.15),(-.37,2.15)],.04,'stone_light',y=1.02)
    elif icon=='tailor':
        for side in (-1,1):G.ring('Scissors handle',.11,2.11,.026,'linen',12,y=1.03).location.x=side*.23
        for side in (-1,1):G.beam('Scissors blade',(side*.21,1.03,2.14),(-side*.22,1.03,2.47),.06,'linen')
    elif icon=='tavern':
        box('Tankard emblem',(.42,.035,.42),(0,1.03,2.19),'linen');G.ring('Tankard handle',.13,2.21,.035,'linen',10,1.03).location.x=.26
    elif icon=='general':
        G.profile('Wheat sack emblem',[(-.3,1.95),(.3,1.95),(.34,2.26),(.19,2.43),(-.19,2.43),(-.34,2.26)],.035,'burlap',y=1.03)
    else:G.profile('Shield emblem',[(-.28,2.44),(.28,2.44),(.24,2.1),(0,1.94),(-.24,2.1)],.04,'slate',y=1.03)

def register():
    for w in (1,2):
        asset(f'wall_plain_{w}',f'{w}米木筋墙',lambda w=w:wall(w),['profile_extrude','vertices'],sock(0,w/2,'wall_3p4'))
        asset(f'foundation_{w}',f'{w}米石基',lambda w=w:foundation(w),['array','CSG'],sock(0,w/2,'foundation'))
    for mat in ('plaster','plaster_rose','plaster_ochre','stone'):
        asset('wall_window_'+mat,mat+'开窗墙',lambda mat=mat:wall(2,'window',mat),['CSG','profile_extrude'],sock(0,1,'wall_3p4'))
        asset('wall_door_'+mat,mat+'开门墙',lambda mat=mat:wall(4,'door',mat),['CSG','profile_extrude'],sock(0,2,'wall_3p4'))
    for w in (4,6,8):
        asset(f'gable_{w}',f'{w}米木筋山墙',lambda w=w:gable(w,w*.45),['profile_extrude','mirror'])
        asset(f'fascia_{w}',f'{w}米封檐',lambda w=w:R.gable_fascia(w,w*.45),['profile_extrude','mirror'])
        asset(f'thatch_gable_{w}',f'{w}米茅草顶曲山墙',lambda w=w:thatch_end(w,True),['profile_extrude','vertices'])
        asset(f'thatch_end_{w}',f'{w}米茅草封边',lambda w=w:thatch_end(w),['curve_bevel'])
        for m in ('terracotta','slate','thatch'):
            asset(f'roof_{w}_{m}',f'{w}米{m}屋面2米段',lambda w=w,m=m:roof(w,m),['array','solidify','vertices'],sock(1,1,f'roof_{w}'))
    defs=[('window','透明玻璃百叶窗',window,['profile_extrude','array']),('door_leaf','铰链木门',door,['array','curve_bevel']),
      ('floor_2','2米木地板',floor,['array']),('column','门廊承重柱',column,['spin','profile_extrude']),
      ('rail_2','2米木栏杆',rail,['array','vertices']),('stairs_34','3.4米楼梯',stairs,['array','vertices']),
      ('awning_4','4米货廊布篷',awning,['solidify','vertices']),('chimney','中空石烟囱',chimney,['CSG','profile_extrude']),
      ('counter_2','2米柜台',counter,['profile_extrude']),('shelf_2','2米货架',shelf,['array']),
      ('forge','炉膛和排烟罩',forge,['profile_extrude','CSG']),('worktable','裁剪工作台',worktable,['array']),
      ('shed_2','2米侧棚屋面',lambda:R.shed_roof(3,2,1.2),['array','solidify']),
      ('tower_cap','治安塔亭顶',lambda:R.hip_roof(9,3.5),['loft','array']),
      ('hip_roof_8','8米住宅四坡顶',lambda:R.hip_roof(9,2.8),['loft','array']),
      ('stone_sdf','解析SDF石面块',stone_sdf,['SDF','vertices'])]
    for k,l,f,m in defs:asset(k,l,f,m,sock(0,1,'rail') if k=='rail_2' else [])
    asset('roof_low_8','铁匠铺低坡屋面',lambda:R.pitched_roof(8,2,2.2),['array','solidify'],sock(1,1,'roof_low_8'))
    asset('gable_low_8','铁匠铺低山墙',lambda:gable(8,2.2),['profile_extrude'])
    asset('fascia_low_8','铁匠铺低山墙封檐',lambda:R.gable_fascia(8,2.2),['profile_extrude'])
    for k in ('smithy','tailor','general','tavern','guard'):asset('sign_'+k,k+'店招',lambda k=k:sign(k),['profile_extrude','curve_bevel'])

def floor_area(r,w,d,z,hole_side=0):
    # 2m full modules away from stair slot; explicit narrow fill pieces at slot boundary.
    for x in np.arange(-w/2+1,w/2,2):
        for y in np.arange(-d/2+1,d/2,2):
            if hole_side and x*hole_side>w/2-2.1:continue
            inst('floor_2',(float(x),float(y),z),parent=r)
    if hole_side:
        # The omitted outer 2m band is 6m long; keep its .35m inner rim.
        direct(r,lambda:floor(.35,d),(hole_side*(w/2-1.825),0,z))
        for sign in (-1,1):direct(r,lambda:floor(1.65,(d-5.8)/2),(hole_side*(w/2-.825),sign*(d+5.8)/4,z))

def direct(r,fn,loc=(0,0,0),angle=0):
    G.COL=bpy.context.scene.collection;G.ROOT=r;shift(fn,loc,angle)

def room(r,w,d,levels=1,mat='plaster',roofmat='terracotta',origin=(0,0,0),backdoor=False,hip=False,side_links=(),low=False):
    # Named local subassembly keeps attachments editable and declarations metric.
    q=empty('Room');q.parent=r;q.location=origin
    for lev in range(levels):
        z=.36+3.4*lev
        floor_area(q,w,d,z,1 if lev else 0)
        for side in (-1,1):
            a=0 if side==1 else 180;y=side*d/2
            if lev==0 and (side==1 or backdoor):
                inst('wall_door_'+mat,(0,y,z),a,q)
                if w>4:
                    for x in (-1,1):inst(f'wall_plain_{int((w-4)/2)}',(x*(w+4)/4,y,z),a,q)
            else:
                for x in np.arange(-w/2+1,w/2,2):
                    inst('wall_window_'+mat,(float(x),y,z),a,q);inst('window',(float(x),y+side*.19,z),a,q)
            if lev==0:
                if side==1 or backdoor:
                    for sign in (-1,1):inst('foundation_1',(sign*1.5,y,.36),a,q)
                    if w>4:
                        for sign in (-1,1):inst(f'foundation_{int((w-4)/2)}',(sign*(w+4)/4,y,.36),a,q)
                else:
                    for x in np.arange(-w/2+1,w/2,2):inst('foundation_2',(float(x),y,.36),a,q)
        for side in (-1,1):
            a=-90 if side==1 else 90
            for y in np.arange(-d/2+1,d/2,2):
                if side in side_links and lev==0 and abs(y)<2:continue
                inst('wall_window_'+mat,(side*w/2,float(y),z),a,q)
                inst('window',(side*(w/2+.19),float(y),z),a,q)
                if lev==0:inst('foundation_2',(side*w/2,float(y),.36),a,q)
            if side in side_links and lev==0:inst('wall_door_'+mat,(side*w/2,0,z),a,q)
        if lev==0:
            inst('door_leaf',(-1.0,d/2+.22,z),-105,q)
            direct(q,lambda:entry_ramp(),(0,d/2,0))
        if lev<levels-1:
            inst('stairs_34',(w/2-.95,0,z),parent=q)
            add_ramp(q,(w/2-.95,0,z),0,1.5,5.4,3.4,'stairs')
            for y in (-2,0,2):inst('rail_2',(w/2-1.75,y,z+3.4),90,q)
    rz=.36+3.4*levels
    if hip:inst('hip_roof_8',(0,0,rz),parent=q)
    else:
        for side in (-1,1):
            inst('gable_low_8' if low else f'thatch_gable_{w}' if roofmat=='thatch' else f'gable_{w}',(0,side*d/2,rz),0 if side==1 else 180,q)
            inst('fascia_low_8' if low else f'thatch_end_{w}' if roofmat=='thatch' else f'fascia_{w}',(0,side*(d/2+1),rz),parent=q)
        for y in np.arange(-d/2-1,d/2+1,2):inst('roof_low_8' if low else f'roof_{w}_{roofmat}',(0,float(y+1),rz),parent=q)
    for side in (-1,1):
        for z in (.15,.35):inst('stone_sdf',(side*(w/2-.22),d/2+.22,z),parent=q)
    # Roof overhang runs exactly d+2; no intersecting false dormer volumes.
    return q

def entry_ramp():
    # Smooth stone apron, walkable by the actual .4m radius player capsule.
    box('Entry level landing',(2.6,1,.36),(0,0,.18),'stone',0)
    v=[(-1.3,.5,0),(1.3,.5,0),(1.3,2.4,0),(-1.3,2.4,0),(-1.3,.5,.36),(1.3,.5,.36),(1.3,2.4,.02),(-1.3,2.4,.02)]
    G.mesh('Entry stone apron',v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'stone')

def add_ramp(r,loc,angle,w,d,h,kind):
    q=empty('COLLISION_RAMP');q.parent=r;q.location=loc;q.rotation_euler.z=math.radians(angle)
    q['ramp_width']=w;q['ramp_depth']=d;q['ramp_height']=h;q['collision_only']=True

def porch(r,width,y,z=.36):
    for x in np.arange(-width/2+1,width/2,2):inst('floor_2',(float(x),y+1,z),parent=r)
    for x in (-width/2+.25,width/2-.25):inst('column',(x,y+1.65,z),parent=r)
    # Rotate shed: rise starts at wall, falls towards street +Y.
    for x in np.arange(-width/2+1,width/2,2):inst('shed_2',(float(x),y,2.28+z),90,r)
    for x in (-width/2+1,width/2-1):inst('rail_2',(x,y+1.9,z),parent=r)
    direct(r,entry_ramp,(0,y+2,0))

def preset(key,label,w,d,levels=1,mat='plaster',roofmat='terracotta',feature=None):
    sc=scene('GS_'+key);r=empty(key)
    q=room(r,w,d,levels,mat,roofmat,hip=feature=='hip',side_links=(-1,) if feature in ('tavern','tailor','general') else (),low=feature=='smithy')
    if feature in ('porch','tavern'):porch(r,w,d/2)
    if feature=='general':inst('awning_4',(0,d/2+.2,.36),parent=r)
    if feature=='smithy':
        for y in (-2,0,2):inst('shed_2',(w/2,y,2.56),parent=r)
        for y in (-2.6,2.6):inst('column',(w/2+2.7,y,.0),parent=r)
        inst('forge',(w/2+1.6,-1.8,.05),parent=r)
        inst('chimney',(w/2+1.6,-2,2.6),parent=r)
    elif feature=='tailor':
        # Lower glazed cutting room attached through a real 2m side opening.
        wing=room(r,4,6,1,'plaster_rose','slate',origin=(-w/2-2,0,0),side_links=(1,))
        inst('worktable',(-w/2-2,-1.6,.36),parent=r)
        inst('shelf_2',(-w/2+.55,-2,.36),90,r)
        # Exaggerated split-level workroom with hanging cloth panels as fixed fittings.
        direct(r,lambda:box('Fabric sample rail',(.12,3,.12),(0,0,2.55),'wood'),(-w/2-2,-2.65,.36),90)
        for i in range(3):direct(r,lambda i=i:box('Fabric hanging sample',(.03,.60,1.4),(0,-.9+i*.9,1.8),['linen','lavender','forest_cloth'][i],.004),(-w/2-2,-2.65,.36),90)
    elif feature=='tavern':
        wing=room(r,4,8,1,'plaster','terracotta',origin=(-w/2-2,0,0),side_links=(1,))
        inst('worktable',(-w/2-2,2,.36),parent=r)
        for x in (-2,0):inst('counter_2',(x,-d/2+2,.36),parent=r)
        for x in (-2,0):inst('shelf_2',(x,-d/2+.5,.36),parent=r)
        inst('worktable',(-w/2+1.8,2,.36),parent=r)
        # Separate rear lodging wing, joined by its own open porch circulation.
    elif feature=='general':
        wing=room(r,4,6,1,'stone','terracotta',origin=(-w/2-2,-0,0),side_links=(1,))
        inst('awning_4',(-w/2-2,3.2,.36),parent=r)
        inst('counter_2',(-1.3,-1,.36),parent=r)
        for x in (-2,0,2):inst('shelf_2',(x,-d/2+.5,.36),parent=r)
    if feature in ('smithy','general','tailor','tavern'):
        inst('sign_'+feature,(-w/2+.65,d/2+.3,.36),parent=r)
    if feature!='smithy':inst('chimney',(-w/2+1.1,-d/2+1.2,.36+3.4*levels+.40),parent=r)
    if feature=='wing':
        # Independent open-ended covered side wing: alternative real footprint.
        for y in (-2,0,2):inst('shed_2',(w/2,y,2.3),parent=r)
        for y in (-2.7,2.7):inst('column',(w/2+2.7,y,0),parent=r)
        for y in (-2,0,2):inst('rail_2',(w/2+2.7,y,0),90,r)
    PRESETS[key]={'root':r,'scene':sc,'label':label,'width':w,'depth':d,'levels':levels,'entry':[0,.36,-d/2],
        'route':[[0,.4,-d/2-3],[0,.4,-d/2+.8],[0,.4,0]],'feature':feature or 'home'}
    return r

def tower():
    sc=scene('GS_guard_tower');r=empty('guard_tower')
    # Two occupied rooms plus a walkable open watch gallery. Dedicated stair voids.
    w=d=8
    for lev in range(2):
        z=.36+lev*3.4;floor_area(r,8,8,z,1 if lev else 0)
        for side in (-1,1):
            for y in (-3,-1,1,3):
                inst('wall_window_stone' if lev==0 else 'wall_window_plaster_ochre',(side*4,y,z),-90 if side==1 else 90,r)
                inst('window',(side*4.19,y,z),-90 if side==1 else 90,r)
            for x in (-3,-1,1,3):
                if side==1 and lev==0 and abs(x)==1:continue
                inst('wall_window_stone' if lev==0 else 'wall_window_plaster_ochre',(x,side*4,z),0 if side==1 else 180,r)
                inst('window',(x,side*4.19,z),0 if side==1 else 180,r)
        if lev==0:inst('wall_door_stone',(0,4,z),parent=r)
        sx=1 if lev==0 else -1;a=0 if lev==0 else 180
        inst('stairs_34',(sx*3.05,0,z),a,r);add_ramp(r,(sx*3.05,0,z),a,1.5,5.4,3.4,'stairs')
    floor_area(r,8,8,7.16,-1)
    for side in (-1,1):
        for k in (-3,-1,1,3):
            if side==-1 or abs(k)>1:inst('foundation_2',(k,side*4,.36),parent=r)
            inst('foundation_2',(side*4,k,.36),90,r)
            inst('rail_2',(k,side*4,7.16),parent=r);inst('rail_2',(side*4,k,7.16),90,r)
        for y in (-3.8,3.8):inst('column',(side*3.8,y,7.16),parent=r)
    inst('tower_cap',(0,0,9.98),parent=r)
    for side in (-1,1):inst('foundation_1',(side*1.5,4,.36),parent=r)
    inst('door_leaf',(-1,4.22,.36),-105,r);direct(r,entry_ramp,(0,4,0));inst('sign_guard',(-2.8,4.3,.36),parent=r)
    inst('counter_2',(-1.4,-2,.36),parent=r)
    PRESETS['guard_tower']={'root':r,'scene':sc,'label':'金穗治安塔','width':8,'depth':8,'levels':3,'entry':[0,.36,-4],'route':[[0,.4,-7],[0,.4,-3],[0,.4,0]],'feature':'guard'}

def export(r,path):
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();tmp=bpy.data.collections.new('_export');bpy.context.scene.collection.children.link(tmp)
    copies=[];mapping={};rootmat=r.matrix_world.inverted()
    for o in [r]+list(r.children_recursive):
        if o.type in ('MESH','CURVE'):
            me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg);BASE.add_uv(me)
            cp=bpy.data.objects.new(o.name,me)
            # Simple batched collision is generated in Godot, excluding visible stair treads.
            cp['gs_solid']=not any(s.material and s.material.get('palette_key')=='glass' for s in o.material_slots) and not any(t in o.name for t in ('Stair tread','Stair stringer','Baluster','Stair handrail','Iron handle'))
        else:cp=bpy.data.objects.new(o.name,None)
        tmp.objects.link(cp);mapping[o]=cp;copies.append(cp)
        for k in o.keys():cp[k]=o[k]
        if o==r:cp.matrix_world=Matrix.Identity(4)
        elif o.parent in mapping:cp.parent=mapping[o.parent];cp.matrix_local=o.matrix_local
        else:cp.matrix_world=rootmat@o.matrix_world
    bpy.ops.object.select_all(action='DESELECT')
    for o in copies:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_extras=True,export_yup=True)
    for o in reversed(copies):
        me=o.data if o.type=='MESH' else None;bpy.data.objects.remove(o,do_unlink=True)
        if me:bpy.data.meshes.remove(me)
    bpy.data.collections.remove(tmp)

def lighting(sc):
    sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True
    sc.world=bpy.data.worlds.new(sc.name+'_sky');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.67,.8,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    sc.view_settings.view_transform='AgX';sc.view_settings.look='AgX - Medium High Contrast'
    sun=bpy.data.lights.new('Sun','SUN');sun.energy=2.1;sun.angle=.18
    o=bpy.data.objects.new('Sun',sun);sc.collection.objects.link(o);o.rotation_euler=(.45,-.6,-.5)
    data=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',data);sc.collection.objects.link(cam);sc.camera=cam
    sc.render.image_settings.file_format='PNG';sc.render.resolution_percentage=100
    return cam

def render(sc,path,target=(0,0,3),pos=(16,23,16),scale=20,res=1100):
    bpy.context.window.scene=sc;cam=sc.camera or lighting(sc);cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    sc.render.resolution_x=res;sc.render.resolution_y=int(res*.83);sc.render.filepath=str(path);bpy.ops.render.render(write_still=True)

def build(out,res,skip_renders=False):
    global OUT,LIB
    OUT=out;out.mkdir(parents=True,exist_ok=False)
    for f in ('modules','assemblies','textures','renders'): (out/f).mkdir()
    bpy.ops.wm.read_factory_settings(use_empty=True);G.material=material
    LIB=scene('GS_Module_Library');register()
    preset('smithy','炉石铁匠铺',8,8,1,'stone','terracotta',feature='smithy')
    preset('general_store','麦袋杂货店',6,8,1,'plaster_ochre','thatch',feature='general')
    preset('tailor','针线裁缝铺',6,8,2,'plaster_rose','slate',feature='tailor')
    preset('tavern','金穗酒馆与旅店',8,10,2,'plaster','terracotta',feature='tavern')
    tower()
    preset('home_cottage','单层农户小屋',6,6,1,'plaster_ochre','thatch')
    preset('home_long','长屋',6,10,1,'plaster','terracotta')
    preset('home_loft','阁楼住宅',6,8,2,'plaster','terracotta')
    preset('home_porch','带门廊住宅',8,6,1,'plaster_rose','slate',feature='porch')
    preset('home_wing','带侧院工棚住宅',6,6,1,'plaster_ochre','terracotta',feature='wing')
    preset('home_broad','四坡石基住宅',8,8,1,'stone','slate',feature='hip')
    bpy.context.window.scene=LIB
    for item in MAN:export(ASSETS[item['id']],out/'modules'/f"{item['id']}.glb")
    entries=[]
    for k,p in PRESETS.items():
        bpy.context.window.scene=p['scene'];export(p['root'],out/'assemblies'/f'{k}.glb')
        entries.append({'id':k,**{a:b for a,b in p.items() if a not in ('root','scene')},**BASE.evaluated_stats(p['root'])})
        lighting(p['scene']);G.COL=p['scene'].collection;G.ROOT=None
        box('Presentation ground',(36,36,.12),(0,0,-.14),'stone_light')
        if not skip_renders:render(p['scene'],out/'renders'/f'{k}.png',target=(0,0,4 if p['levels']>1 else 2.5),scale=25 if p['feature'] in ('tavern','tailor','general') else 23 if p['levels']>1 else 19,res=res)
    catalog=scene('GS_Village_Collection');lighting(catalog)
    for i,(k,p) in enumerate(PRESETS.items()):
        offset=Vector(((i%4)*19,(i//4)*22,0))
        # Linked objects in overview; original assembly remains the source.
        mapping={}
        for o in [p['root']]+list(p['root'].children_recursive):
            cp=o.copy();cp.data=o.data;catalog.collection.objects.link(cp);mapping[o]=cp
        for o,cp in mapping.items():
            if o==p['root']:cp.location=offset
            else:cp.parent=mapping[o.parent];cp.matrix_basis=o.matrix_basis.copy()
    G.COL=catalog.collection;G.ROOT=None;box('Overview ground',(90,80,.2),(27,23,-.17),'stone_light')
    if not skip_renders:render(catalog,out/'renders'/'village_overview.png',(27,23,2),(96,122,95),92,max(1500,res))
    hierarchy=[]
    for k,p in PRESETS.items():
        bpy.context.window.scene=p['scene'];bpy.context.view_layer.update();root=p['root']
        for node in root.children_recursive:
            asset_id=node.name.split('_instance')[0]
            if asset_id not in ASSETS:continue
            transform=root.matrix_world.inverted()@node.matrix_world
            hierarchy.append({'assembly':k,'asset':asset_id,'matrix_blender':[list(row) for row in transform]})
    manifest={'version':'goldshire_v1','unit':'metres','front':'Blender +Y / Godot -Z','wall_module':2,'floor_height':3.4,'floor_datum':.36,'door_clear_width':2,'door_clear_height':2.8,'palette':'docs/palette/palette.json','modules':MAN,'assemblies':entries,'placements':hierarchy}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    (out/'palette_mapping.json').write_text(json.dumps({k:PAL[k] for k in CACHE},indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'goldshire_kit.blend'))
    print('GOLDSHIRE_BUILD_COMPLETE',out,flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--res',type=int,default=1100);ap.add_argument('--skip-renders',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);build(Path(args.out),args.res,args.skip_renders)
