"""Source-faithful rural kit. blender -b --python build.py -- <new-output-dir>.
Snapshot kernel/field from abbey_kit, avoiding concurrent shared-source mutation.
All dimensions in metres, front +Y, Z up. Export converts to glTF Y up.
"""
import bpy, bmesh, sys, os, math, json, pathlib, random, hashlib
from mathutils import Vector
sys.path.insert(0,str(pathlib.Path(__file__).parent))
import kernel as G
import thatch as T
from field import polygonize
ROOT=pathlib.Path('E:/wowgame')
argv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
OUT=pathlib.Path(argv[0]) if argv else ROOT/'assets/models/vale_kit_v1/build_001'
if (OUT/'vale_kit.blend').exists():raise RuntimeError('Choose a new build directory; existing builds are immutable.')
OUT.mkdir(parents=True,exist_ok=True)
for folder in ['modules','assemblies','stages','renders']:(OUT/folder).mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
SC=bpy.context.scene
G.PALETTE.update({'plaster':'F0E4C8','plaster_patch':'E6D7B7','timber':'6A4A30','wood':'805937',
 'terracotta':'B8553A','tile_dark':'AA4D34','tile_light':'C36749','barn':'B04030','barn_light':'B64837','barn_dark':'A6382B',
 'ivory':'F0E8D8','thatch':'C8A868','thatch_light':'D2B273','thatch_dark':'B7995E','mill_roof':'8A4A3A',
 'mill_light':'965442','sandstone':'B9B1A1','stone_dark':'A39A87','stone_light':'C8BEAA','iron':'3A3A44',
 'glass':'6A8AB0','cloth':'F2EDE0','leaf':'4F8F3A','flower':'FF7090','flower_y':'FFD040','flower_w':'F2EDE0'})
PALETTE_SOURCE=json.loads((ROOT/'docs/palette/palette.json').read_text(encoding='utf-8'))
PALETTE_SWATCHES={c[0]:c[2].lstrip('#').upper() for group in PALETTE_SOURCE['groups'] for c in group['colors']}
PALETTE_MAP=json.loads((pathlib.Path(__file__).parent/'palette_map.json').read_text())
G.PALETTE={key:PALETTE_SWATCHES[source] for key,source in PALETTE_MAP.items()}
LIB={};RECORDS=[];ASSEMBLIES={};SEAMS=[]

def context(name):
    col=bpy.data.collections.new(name);SC.collection.children.link(col)
    root=bpy.data.objects.new(name,None);col.objects.link(root)
    G.COL=col;G.ROOT=root
    return root,col

def evaluated_points(objects):
    dg=bpy.context.evaluated_depsgraph_get();pts=[]
    for ob in objects:
        if ob.type not in {'MESH','CURVE'}:continue
        ev=ob.evaluated_get(dg);me=ev.to_mesh()
        if me and len(me.polygons):pts.extend(ev.matrix_world@v.co for v in me.vertices)
        ev.to_mesh_clear()
    return pts

def bounds(objects):
    bpy.context.view_layer.update();pts=evaluated_points(objects)
    return [[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]] if pts else [[0]*3,[0]*3]

def export(root,col,folder):
    # Export cleaned evaluated snapshots; editable source and modifiers stay intact.
    bpy.ops.object.select_all(action='DESELECT')
    temp=bpy.data.collections.new('EXPORT_SNAPSHOT');SC.collection.children.link(temp);copies={};dg=bpy.context.evaluated_depsgraph_get()
    for o in col.objects:
        if o.type=='EMPTY':n=o.copy()
        elif o.type in {'MESH','CURVE'}:
            ev=o.evaluated_get(dg);me=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg)
            if not me.polygons:bpy.data.meshes.remove(me);continue
            bm=bmesh.new();bm.from_mesh(me)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
            bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
            bmesh.ops.triangulate(bm,faces=list(bm.faces))
            bad=[f for f in bm.faces if f.calc_area()<1e-10]
            if bad:bmesh.ops.delete(bm,geom=bad,context='FACES_ONLY')
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
            if not me.uv_layers:
                uv=me.uv_layers.new(name='UVMap')
                for p in me.polygons:
                    axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
                    for li in p.loop_indices:
                        v=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(v[axes[0]],v[axes[1]])
            n=bpy.data.objects.new(o.name+'__export',me)
        else:continue
        temp.objects.link(n);copies[o]=n
    for o,n in copies.items():
        n.parent=copies.get(o.parent);n.matrix_world=o.matrix_world.copy();n.select_set(True)
    bpy.context.view_layer.objects.active=copies[root]
    bpy.ops.export_scene.gltf(filepath=str(OUT/folder/(root.name+'.glb')),export_format='GLB',use_selection=True,export_apply=False,export_cameras=False,export_lights=False,export_extras=True)
    for n in list(temp.objects):
        data=n.data;bpy.data.objects.remove(n,do_unlink=True)
        if isinstance(data,bpy.types.Mesh) and data.users==0:bpy.data.meshes.remove(data)
    bpy.data.collections.remove(temp)

def module(name,fn,methods,sockets=None):
    root,col=context(name);fn();bpy.context.view_layer.update()
    root['methods']=','.join(methods);root['sockets_json']=json.dumps(sockets or {})
    rec={'id':name,'methods':methods,'sockets':sockets or {},'bounds_blender':bounds(col.objects),'file':'modules/'+name+'.glb'}
    LIB[name]=(root,col);RECORDS.append(rec);export(root,col,'modules');col.hide_render=True
    return root

def inst(name,loc=(0,0,0),rot=0,scale=(1,1,1),label=None):
    src,col=LIB[name];dest=G.COL;parent=G.ROOT;copies={}
    for o in col.objects:
        n=o.copy();dest.objects.link(n);n.name=(label or name)+'__'+o.name;copies[o]=n
    for o,n in copies.items():n.parent=copies.get(o.parent,parent)
    rt=copies[src];rt.location=loc;rt.rotation_euler.z=rot;rt.scale=scale
    return rt

def opening_cut(core,opening,height,offset):
    if opening=='door':cut=G.profile('CSG_door_cutter',G.arch_outline(1.88,2.22,.3),1)
    else:cut=G.box('CSG_window_cutter',(1.35,1,1.3),(offset,0,height*.44+1.3/2))
    G.subtract(core,cut)

def wall(w=4,h=3,kind='farm',opening=None,offset=0):
    mat='plaster' if kind=='farm' else 'barn'
    o=G.box('wall_core',(w,.34,h),(0,0,h/2),mat)
    if opening:opening_cut(o,opening,h,offset)
    if kind=='barn':
        # Real broad brick courses, clipped around the same openings.
        for row in range(int(h/.38)):
            for k in range(int(w/.85)+1):
                x=-w/2+.42+k*.84-(row%2)*.42;bw=min(.80,w/2-x+.4)
                if x-bw/2< -w/2 or bw<.3:continue
                z=.21+row*.38
                if opening=='door' and abs(x)<1.35 and z<3.3:continue
                if opening=='window' and abs(x-offset)<1.1 and h*.44-.25<z<h*.44+1.55:continue
                G.box('brick_course',(bw,.025,.34),(x,.18,z),['barn','barn_light','barn_dark'][(row+k)%7%3],.025)
    else:
        for x,z in [(-w*.35,.6),(w*.31,h*.86)]:
            if opening=='door' and abs(x)<1.2:continue
            G.profile('quiet_plaster_patch',[(x-.25,z),(x+.19,z-.04),(x+.28,z+.20),(x-.22,z+.25)],.01,'plaster_patch',.178)

def window_frame(mat='timber'):
    for x in [-.765,.765]:G.box('window_jamb',(.18,.25,1.5),(x,.09,.75),mat,.025)
    for z in [-.02,1.52]:G.box('window_lintel',(1.82,.30,.18),(0,.09,z),mat,.025)
    G.box('window_sill',(1.95,.52,.17),(0,.2,-.13),'sandstone',.035)

def window_insert():
    G.box('glass',(1.30,.045,1.26),(0,-.075,.75),'glass')
    G.box('mullion',(.065,.12,1.31),(0,.01,.75),'timber',.009)
    G.box('crossbar',(1.34,.12,.065),(0,.01,.75),'timber',.009)

def doorframe(mat='timber'):
    # Closed arch outline with open centre.
    old=G.PALETTE['sandstone'];G.arch_frame('door',1.88,1.92,0,.20,.35,y=.13)
    for o in G.COL.objects:
        if o.type=='MESH':o.data.materials.clear();o.data.materials.append(G.material(mat))

def door():
    G.profile('plank_door',G.arch_outline(1.83,1.90,.035),.17,'wood')
    for x in [-.72,-.48,-.24,0,.24,.48,.72]:
        top=1.9+math.sqrt(max(0,.915**2-x*x))-.035
        G.box('plank_seam',(.025,.012,top-.055),(x,.094,(top+.055)/2),'timber')
    for z in [.52,1.77]:
        G.box('iron_hinge',(1.47,.055,.13),(0,.135,z),'iron',.015)
        for x in [-.62,.62]:G.box('iron_stud',(.07,.08,.07),(x,.16,z),'stone_dark',.012)
    ring=G.ring('ring_handle',.12,1.09,.027,'iron',12,y=.18);ring.location.x=.48

def flowerbox():
    for y in [-.18,.18]:G.box('wood_flowerbox',(1.8,.10,.32),(0,y,.16),'wood',.02)
    for x in [-.85,.85]:G.box('box_end',(.1,.4,.32),(x,0,.16),'timber',.02)
    G.box('soil',(1.6,.32,.06),(0,0,.20),'timber')
    for i in range(5):
        x=-.62+i*.31
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.24,location=(x,0,.34));o=G.attach(bpy.context.object,'leaf','leaf');o.scale=(1,.75,.6)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.16,location=(x,.02,.52));G.attach(bpy.context.object,'flower',['flower_w','flower_y','flower'][i%3])

def foundation(w=4):
    for i in range(4):G.box('foundation_block',(w/4-.025,.55,.38),(-w/2+(i+.5)*w/4,0,.19),['sandstone','stone_light','sandstone','stone_dark'][i],.065)

def timber_beam(w=4,mat='timber'):
    G.box('storey_band',(w,.36,.27),(0,0,0),mat,.035)
    # Quiet shallow bevelled grain sliver is geometry and exports reliably.
    G.box('grain',(w*.68,.007,.024),(0,.184,.052),'wood' if mat=='timber' else 'stone_light',.006)

def roof_section(length=4,depth=10.24,rise=5.24,kind='tile',caps=(False,False)):
    if kind=='thatch':return T.roof(length,depth,rise,caps=caps)
    half=depth/2;mat='terracotta' if kind=='tile' else 'thatch'
    # Profile swept along X: mirror half Y, then solidify.
    verts=[]
    for x in [-length/2,length/2]:
        for j in range(9):
            t=j/8;verts.append((x,half*t,rise*(1-t)-.10*math.sin(math.pi*t)))
    faces=[(j,j+1,j+10,j+9) for j in range(8)]
    o=G.mesh('roof_half',verts,faces,mat)
    m=o.modifiers.new('01 Mirror roof across Y','MIRROR');m.use_axis=(False,True,False);m.use_clip=True
    m=o.modifiers.new('04 Roof shell thickness','SOLIDIFY');m.thickness=.20 if kind=='tile' else .32;m.offset=-1
    # Separate broad overlapping tiles/sheaves: longitudinal array stays editable.
    rows=7;columns=max(1,round(length/.8));pitch=length/columns
    for side in [-1,1]:
        for j in range(rows):
            t0=j/rows;t1=min(1.022,(j+1.12)/rows)
            z0=rise*(1-t0)+.055;z1=rise*(1-t1)+.055
            w=pitch-.023
            if kind=='tile':
                verts=[(-w/2,side*half*t0,z0),(w/2,side*half*t0,z0),(w/2,side*half*t1,z1),(-w/2,side*half*t1,z1)]
            else:
                # Multiple irregular straw tips prevent the surface reading as golden roof tiles.
                verts=[(-w/2,side*half*t0,z0),(w/2,side*half*t0,z0)]
                for p in range(7):
                    x=w/2-p*w/6;tip=[0,.09,.035,.13,.065,.11,0][p]
                    verts.append((x,side*(half*t1+tip),z1-tip*.6))
            key=(['terracotta','tile_light','terracotta','tile_dark'][j%4] if kind=='tile' else ['thatch','thatch_light','thatch','thatch_dark'][j%4])
            o=G.mesh('tile_row' if kind=='tile' else 'straw_sheaf_row',verts,[tuple(range(len(verts)))],key);o.location.x=-length/2+pitch/2
            m=o.modifiers.new('04 tile thickness','SOLIDIFY');m.thickness=.095 if kind=='tile' else .20;m.offset=-1
            G.bevel(o,.032);G.array(o,columns,(pitch,0,0))
            if kind=='thatch':
                # Thin raised grooves run with the straw, kept tonal and sparse.
                for q in range(4):
                    xx=-length/2+pitch*(q+1)/5
                    a=half*(t0+.028);b=half*(t1-.03)
                    zA=rise*(1-(t0+.028))+.065;zB=rise*(1-(t1-.03))+.065
                    line=G.line('straw_fibre',[(xx,side*a,zA),(xx+.035,side*(a+b)/2,(zA+zB)/2+.02),(xx+.018,side*b,zB)],.012,'thatch_dark')
                    G.array(line,columns,(pitch,0,0))
    for y in [-half,half]:G.box('eave_fascia',(length,.24,.27),(0,y,-.06),'timber',.04)

def ridge(length=4,kind='tile'):
    if kind=='thatch':return T.ridge(length)
    if kind=='tile':
        pts=[(-.31,0),(-.31,.10),(0,.35),(.31,.10),(.31,0),(0,.20)]
        o=G.profile('ridge_cap',pts,.78,'terracotta');o.rotation_euler.z=math.pi/2;o.location.x=-length/2+.4
        # Profile along X after object rotation: array local Y -> global X.
        G.array(o,round(length/.8),(0,-.8,0))
    else:
        o=G.lathe('bound_straw_ridge',[(0,0),(.30,0),(.36,length*.5),(.30,length),(0,length)],'thatch_light',10);o.rotation_euler.y=math.pi/2;o.location.x=-length/2
        for x in [-length/2+.18,0,length/2-.18]:
            pts=[(x,.37*math.cos(k*math.tau/12),.37*math.sin(k*math.tau/12)) for k in range(12)];G.line('rope_binding',pts,.035,'wood',True)

def chimney():
    o=G.box('chimney_core',(.86,.92,4.4),(0,0,2.2),'stone_dark',.04)
    G.subtract(o,G.box('real_flue',(.50,.55,1.2),(0,0,4.2)))
    for j in range(9):
        for side in [-1,1]:
            G.box('stone_course',(.86,.08,.43),(0,side*.47,.25+j*.47),['sandstone','stone_light','stone_dark'][j%3],.04)
            G.box('stone_course',(.08,.90,.43),(side*.44,0,.25+j*.47),['stone_light','sandstone'][j%2],.04)
    for y in [-.51,.51]:G.box('flue_cap',(1.16,.23,.27),(0,y,4.45),'sandstone',.04)
    for x in [-.465,.465]:G.box('flue_cap',(.23,.8,.27),(x,0,4.45),'sandstone',.04)

def bracket():
    G.profile('timber_bracket',[(-.17,0),(.17,0),(.17,-.42),(-.02,-.42),(-.17,-.18)],.65,'timber')

def stone(refined=True):
    v,f=polygonize('stone',.11,refined);o=G.mesh('analytic_SDF_stone',v,f,'sandstone');o.location.z=.28
    dec=o.modifiers.new('SDF production reduction','DECIMATE');dec.ratio=.32
    G.patches(o,['stone_light','stone_dark'],11)

def fence(post=True):
    for z in [.42,1.05]:G.box('rail',(4,.14,.16),(0,0,z),'wood',.025)
    for x in [-1.2,0,1.2]:G.beam('picket',(x,0,.13),(x,0,1.28),.12,'timber')
    if post:
        G.box('post',(.21,.21,1.4),(-2,0,.70),'timber',.03)

def bent_fence():
    # Local positive-X module -> array -> live Curve, no fake labels.
    verts=[];faces=[]
    for z in [.42,1.05]:
        start=len(verts)
        for i in range(17):
            x=i*.25
            verts.extend([(x,-.07,z-.08),(x,.07,z-.08),(x,.07,z+.08),(x,-.07,z+.08)])
        for i in range(16):
            a=start+i*4
            for q in range(4):faces.append((a+q,a+(q+1)%4,a+(q+1)%4+4,a+q+4))
        faces.extend([(start+3,start+2,start+1,start),tuple(start+64+q for q in range(4))])
    o=G.mesh('continuous_rail',verts,faces,'wood');G.array(o,3,(4,0,0),True)
    cu=bpy.data.curves.new('fence_path','CURVE');cu.dimensions='3D';cu.resolution_u=24;sp=cu.splines.new('BEZIER');sp.bezier_points.add(2)
    for p,co in zip(sp.bezier_points,[(0,0,0),(6,1.5,0),(11,4,0)]):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    path=bpy.data.objects.new('editable_path',cu);G.COL.objects.link(path);path.parent=G.ROOT;path.hide_render=True
    m=o.modifiers.new('07 Follow editable path','CURVE');m.object=path;m.deform_axis='POS_X'

def mill_section(index=0):
    z=index*3.5;r0=3-.225*index;r1=r0-.225
    o=G.loft('octagonal_tower_course',[(r0,0),(r1,3.5)],'plaster',8);o.rotation_euler.z=math.pi/8
    # bake orientation before CSG for reliable cutter positions
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);o.select_set(False)
    if index==0:
        cut=G.profile('tower_door_cutter',G.arch_outline(1.40,1.8,-.05),1.5,y=2.8);G.subtract(o,cut)
    for k in [0,1]:
        level=5+k*3.5
        if z<level<z+3.5:
            h=level-z;front=(3-.9*(level/14))*math.cos(math.pi/8)
            G.subtract(o,G.box('tower_window_cutter',(.9,1.1,1.15),(0,front,h+.575)))

def mill_roof():
    G.loft('octagonal_roof',[(3.30,0),(.015,4.2)],'mill_roof',8)
    for j in range(6):
        t0=j/6;t1=(j+1)/6;r0=3.3*(1-t0)+.075;r1=3.3*(1-t1)+.075
        for k in range(16):
            a=k*math.tau/16;b=(k+1)*math.tau/16
            # points projected onto octagon envelope; constant facets preserved
            def rr(a,r):return r*math.cos(math.pi/8)/math.cos(a%(math.pi/4)-math.pi/8)
            verts=[(rr(a,r0)*math.cos(a),rr(a,r0)*math.sin(a),4.2*t0),(rr(b,r0)*math.cos(b),rr(b,r0)*math.sin(b),4.2*t0),(rr(b,r1)*math.cos(b),rr(b,r1)*math.sin(b),4.2*t1+.09),(rr(a,r1)*math.cos(a),rr(a,r1)*math.sin(a),4.2*t1+.09)]
            o=G.mesh('cap_shingle',verts,[(0,1,2,3)],'mill_light' if (j+k)%5==0 else 'mill_roof');m=o.modifiers.new('04 Shingle shell','SOLIDIFY');m.thickness=.07
    o=G.lathe('eave_collar',[(3.16,-.22),(3.3,-.22),(3.3,0),(3.16,0)],'timber',8)

def sail():
    G.box('sail_spine',(.18,.18,7.5),(0,0,3.75),'timber',.025)
    G.box('outer_frame',(.12,.15,5.8),(.0+1.48,0,4.28),'wood',.02)
    for z in [1.4,3.33,5.26,7.16]:G.box('cross_spar',(1.60,.16,.12),(.74,.14,z),'wood',.018)
    verts=[(x,.02+.07*math.sin(math.pi*j/8),1.48+j*5.6/8) for j in range(9) for x in [.1,1.39]]
    faces=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(8)]
    o=G.mesh('canvas',verts,faces,'cloth');m=o.modifiers.new('09 Gentle sail twist','SIMPLE_DEFORM');m.deform_method='TWIST';m.deform_axis='Z';m.angle=.022
    m=o.modifiers.new('04 Canvas thickness','SOLIDIFY');m.thickness=.035
    for z in [1.4,3.33,5.26,7.16]:
        for x in [0,1.48]:G.line('rope_lashing',[(x-.10,-.10,z-.1),(x+.10,.13,z),(x-.10,-.10,z+.1)],.025,'thatch_dark')

def hub():
    G.box('main_hub',(.7,.8,.7),(0,0,0),'timber',.08)
    o=G.lathe('spindle',[(0,0),(.20,0),(.20,1.4),(0,1.4)],'wood',12);o.rotation_euler.x=math.pi/2
    for x in [-.23,.23]:G.box('hub_pin',(.075,.075,.075),(x,.42,.22),'iron',.01)

def porch():
    G.box('porch_deck',(4.4,2.05,.33),(0,1.08,.165),'sandstone',.065)
    for z,y,w in [(.15,2.35,3.2),(.32,1.95,3.5)]:G.box('porch_step',(w,.52,.28),(0,y,z),'sandstone',.05)
    for x in [-1.94,1.94]:
        G.box('post_plinth',(.6,.6,.64),(x,1.8,.32),'sandstone',.08)
        G.box('porch_post',(.32,.34,2.8),(x,1.8,1.95),'timber',.04)
        G.beam('post_brace',(x,1.8,2.76),(x*.63,1.8,3.42),.18,'timber')
    G.box('porch_front_beam',(4.45,.28,.28),(0,1.8,3.36),'timber',.04)
    # Continuous structural deck under the overlapping tiles, visible at both sides.
    deck=G.profile('porch_roof_deck',[(-.16,4.161),(2.35,3.207),(2.35,3.017),(-.16,3.971)],4.50,'timber')
    deck.rotation_euler.z=math.pi/2
    for row in range(3):
        y0=-.1+row*.75;y1=y0+.83;z0=4.2-y0*.38;z1=4.2-y1*.38
        for k in range(6):
            x=-2.25+k*.75
            o=G.mesh('porch_tile',[(x,y0,z0),(x+.73,y0,z0),(x+.73,y1,z1),(x,y1,z1)],[(0,1,2,3)],'terracotta' if k%3 else 'tile_light')
            m=o.modifiers.new('04 tile shell','SOLIDIFY');m.thickness=.11;G.bevel(o,.035)
    G.box('porch_rear_beam',(4.6,.25,.2),(0,-.10,4.12),'timber',.03)
    # Modest bench and firewood beneath it.
    G.box('bench_seat',(1.25,.55,.15),(1.13,.67,.92),'wood',.035)
    for x in [.7,1.6]:G.box('bench_leg',(.16,.36,.55),(x,.67,.62),'timber',.02)
    for i in range(4):
        o=G.lathe('firewood',[(0,0),(.15,0),(.15,.66),(0,.66)],'wood',8);o.rotation_euler.x=math.pi/2;o.location=(.72+(i%2)*.34,1.03,.5+(i//2)*.26)
    o=G.lathe('terracotta_pot',[(0,0),(.23,0),(.31,.35),(.25,.53),(.29,.56),(.29,.61),(.22,.61),(.22,.55)],'terracotta',12);o.location=(-1.32,.65,.33)
    for i in range(3):
        x=-1.42+.10*i;G.line('pot_stem',[(x,.65,.80),(x+.03,.65,1.15)],.02,'leaf')
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.10,location=(x+.03,.65,1.16));G.attach(bpy.context.object,'pot_flower','flower_w')

def cargo_door():
    for side in [-1,1]:
        G.box('cargo_leaf',(1.96,.19,3.47),(side*1.0,0,1.735),'wood',.02)
        for i in range(6):G.box('cargo_plank_seam',(.022,.016,3.45),(side*1.0-.80+i*.32,.105,1.73),'timber')
        for z in [.24,3.2]:G.box('cream_crossrail',(1.91,.13,.17),(side*1.0,.18,z),'ivory',.024)
        G.beam('cream_diagonal',(side*.08,.18,.30),(side*1.85,.18,3.1),.18,'ivory')
        for z in [.55,2.92]:
            G.box('cargo_hinge',(.67,.09,.16),(side*1.60,.27,z),'iron',.012)
            for x in [side*1.35,side*1.85]:G.box('hinge_rivet',(.06,.065,.06),(x,.32,z),'stone_dark',.007)
    for x in [-2.13,2.13]:G.box('cargo_jamb',(.24,.38,3.65),(x,.07,1.825),'ivory',.035)
    G.box('cargo_lintel',(4.5,.40,.26),(0,.07,3.64),'ivory',.04)

def hayloft():
    G.box('loft_dark_inside',(2.7,.05,2.05),(0,-.18,1.025),'timber')
    for x in [-1.49,1.49]:G.box('loft_jamb',(.21,.28,2.22),(x,.02,1.11),'ivory',.025)
    for z in [-.04,2.25]:G.box('loft_band',(3.20,.38,.20),(0,.09,z),'ivory',.025)
    for side in [-1,1]:
        G.box('open_shutter',(1.1,.17,2.12),(side*2.02,.09,1.08),'wood',.02)
        for z in [.35,1.85]:G.box('shutter_strap',(.85,.06,.09),(side*2.02,.22,z),'iron',.01)
        G.beam('shutter_diagonal',(side*1.6,.22,.24),(side*2.45,.22,1.95),.10,'timber')
    rng=random.Random(22)
    for i in range(30):
        x=rng.uniform(-1.2,1.2);y=rng.uniform(-.06,.23);z=rng.uniform(.07,.22)
        G.profile('loose_hay',[(x-.18,z),(x+.12,z),(x+.20,z+.15),(x+.02,z+.32)],.18,'thatch_light',y)
    G.box('hoist_beam',(.22,2.3,.24),(0,.9,2.70),'timber',.035)
    G.beam('hoist_brace',(0,.07,2.05),(0,1.7,2.65),.18,'timber')
    G.line('hanging_rope',[(0,1.95,2.80),(0,2.02,2.57),(0,2.02,.94)],.035,'thatch_dark')
    G.line('hook',[(0,2.02,.96),(.05,2.02,.70),(-.12,2.02,.56),(-.26,2.02,.69),(-.22,2.02,.80)],.06,'iron')

def barrel():
    G.lathe('barrel_body',[(0,0),(.50,0),(.56,.20),(.64,.8),(.58,1.4),(.51,1.55),(0,1.55)],'wood',14)
    for z,r in [(.2,.575),(1.30,.61)]:G.lathe('iron_hoop',[(r,z),(r+.035,z),(r+.035,z+.13),(r,z+.13)],'iron',14)
    for i in range(14):
        a=i*math.tau/14
        G.line('barrel_stave',[(.54*math.cos(a),.54*math.sin(a),.16),(.65*math.cos(a),.65*math.sin(a),.8),(.55*math.cos(a),.55*math.sin(a),1.48)],.014,'timber')

def haybale():
    G.box('bale',(1.45,.9,1.05),(0,0,.525),'thatch',.14)
    for x in [-.42,.42]:G.line('bale_rope',[(x,-.47,.13),(x,-.47,.96),(x,-.33,1.08),(x,.34,1.08),(x,.47,.93),(x,.47,.12)],.038,'wood')
    for i in range(20):
        x=-.65+(i%10)*.14;z=.12+(i//10)*.45
        G.profile('bale_straw',[(x-.10,z),(x+.08,z+.03),(x+.14,z+.20),(x,z+.35)],.025,'thatch_light',.459)

def make_library():
    for kind,h in [('farm',3),('barn',4)]:
        for opening in [None,'door','window']:
            module('V_'+kind+'_wall_'+(opening or 'solid'),lambda k=kind,h=h,o=opening:wall(4,h,k,o),['CSG','03 extrusion','10 vertices'],{'left':[-2,0,0],'right':[2,0,0],'top':[0,0,h]})
        module('V_'+kind+'_frame',lambda k=kind:window_frame('timber' if k=='farm' else 'ivory'),['03 extrusion'])
        module('V_'+kind+'_doorframe',lambda k=kind:doorframe('timber' if k=='farm' else 'ivory'),['03 extrusion','10 vertices'])
        module('V_'+kind+'_beam',lambda k=kind:timber_beam(4,'timber' if k=='farm' else 'ivory'),['03 extrusion'],{'left':[-2,0,0],'right':[2,0,0]})
    module('V_window_insert',window_insert,['03 extrusion'])
    module('V_door',door,['03 extrusion','05 curve bevel'])
    module('V_flowerbox',flowerbox,['03 extrusion','10 vertices'])
    module('V_foundation',foundation,['02 repeat','03 extrusion'],{'left':[-2,0,0],'right':[2,0,0]})
    module('V_stone_SDF',stone,['SDF analytical field','10 vertices'])
    module('V_roof_tile_4m',roof_section,['01 mirror','02 array','04 solidify','10 vertices'],{'left':[-2,0,0],'right':[2,0,0]})
    module('V_roof_thatch_4m',lambda:roof_section(4,13.2,7.42,'thatch'),['01 mirror','02 array','04 solidify','10 vertices'],{'left':[-2,0,0],'right':[2,0,0]})
    module('V_ridge_tile',ridge,['03 extrusion','02 array'])
    module('V_ridge_thatch',lambda:ridge(4,'thatch'),['06 spin','05 curve bevel'])
    module('V_chimney',chimney,['CSG','03 extrusion'])
    module('V_bracket',bracket,['03 extrusion'])
    module('V_fence_4m',fence,['03 extrusion','10 vertices'],{'left':[-2,0,0],'right':[2,0,0]})
    module('V_fence_curved_12m',bent_fence,['02 array','07 curve deformation'])
    for i in range(4):module('V_mill_course_'+str(i),lambda i=i:mill_section(i),['08 loft','CSG'],{'bottom':[0,0,0],'top':[0,0,3.5]})
    module('V_mill_roof',mill_roof,['08 loft','06 spin','04 solidify'])
    module('V_mill_sail',sail,['09 simple deform','04 solidify','05 curve bevel'],{'pivot':[0,0,0]})
    module('V_mill_hub',hub,['06 spin','03 extrusion'],{'pivot':[0,0,0]})
    module('V_porch',porch,['03 extrusion','04 solidify','06 spin','05 curve bevel'])
    module('V_cargo_door',cargo_door,['03 extrusion','10 vertices'])
    module('V_hayloft',hayloft,['03 extrusion','05 curve bevel','10 vertices'])
    module('V_barrel',barrel,['06 spin','05 curve bevel'])
    module('V_haybale',haybale,['03 extrusion','05 curve bevel','10 vertices'])

def add_window(kind,x,y,z,rot=0,fbox=False,scale=1):
    inst('V_'+kind+'_frame',(x,y,z),rot,(scale,1,scale))
    inst('V_window_insert',(x,y,z),rot,(scale,1,scale))
    if fbox:
        # positive local Y is outwards
        inst('V_flowerbox',(x-.34*math.sin(rot),y+.34*math.cos(rot),z-.15),rot,(scale,1,1))

def decoration_center(o):
    # Mesh coordinates are local to the rotated panel, including rear facades.
    local=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
    return o.location+o.rotation_euler.to_matrix()@local

def house(kind):
    barn=kind=='barn';w,d,h=(16,11,8) if barn else (12,9,6);layer=h/2;rise=7.42 if barn else 5.24
    roof_depth=13.2 if barn else 10.24
    eave_infill=rise*(1-d/roof_depth)
    root,col=context('VALE_'+kind);root['kind']=kind;root['nominal_wall_dimensions']=[w,d,h]
    # Four facades built from actual modules. Original window positions x=+-0.3 W.
    for sy in [-1,1]:
        rot=0 if sy==1 else math.pi
        # Use simple solid panels + exact cuts at original positions, preserving 4m seams.
        for level in [0,1]:
            for i in range(int(w/4)):
                x=-w/2+2+4*i
                start=set(col.objects);wall(4,layer,kind)
                created=set(col.objects)-start
                for o in created:
                    o.location.x+=x;o.location.y+=sy*d/2;o.location.z+=level*layer
                    if sy<0:o.rotation_euler.z=math.pi
                core=next(o for o in created if o.name.startswith('wall_core'))
                # Cut world-space precise openings using kernel; nearby brick decorations removed locally.
                doors=sy==1 and level==0
                for targetx in ([-w*.3,w*.3] if (level==0 or sy==1) and not (barn and sy==1 and level==0) else []):
                    if abs(targetx-x)<=2.05:
                        bottom=1.3 if level==0 else h*.62
                        cut=G.box('window_CSG',(1.35,1.3,1.3),(targetx,sy*d/2,bottom+.65));G.subtract(core,cut)
                        for o in list(created):
                            if o!=core and o.name.startswith('brick_course'):
                                center=decoration_center(o);cx,cz=center.x,center.z
                                if abs(cx-targetx)<1.1 and bottom-.25<cz<bottom+1.6:bpy.data.objects.remove(o,do_unlink=True)
                if doors and abs(x)<2.1:
                    cut=G.box('cargo_CSG',(4.02,1.3,3.68),(0,d/2,2.03)) if barn else G.profile('entrance_CSG',G.arch_outline(1.88,2.22,.29),1.3,y=d/2)
                    G.subtract(core,cut)
                    for o in list(created):
                        if o.name in bpy.data.objects and o.name.startswith('brick_course'):
                            center=decoration_center(o);cx,cz=center.x,center.z
                            if abs(cx)<(2.5 if barn else 1.4) and cz<4.0:bpy.data.objects.remove(o,do_unlink=True)
                if barn and sy==1 and level==1 and abs(x)<2.1:
                    G.subtract(core,G.box('loft_CSG',(2.85,1.3,2.18),(0,d/2,6.20)))
                    for o in list(created):
                        if o.name in bpy.data.objects and o.name.startswith('brick_course'):
                            center=decoration_center(o);cx,cz=center.x,center.z
                            if abs(cx)<1.85 and 4.8<cz<7.6:bpy.data.objects.remove(o,do_unlink=True)
                if level==0 and sy<0:inst('V_foundation',(x,sy*(d/2+.05),0),0)
                for zz in [(level+1)*layer-.12]:inst('V_'+kind+'_beam',(x,sy*(d/2+.045),zz),rot)
                SEAMS.append({'building':kind,'side':sy,'level':level,'x_interval':[x-2,x+2]})
        for sx in [-1,1]:
            for level,bottom in [(0,1.3),(1,h*.62)]:
                if (level==0 or sy==1) and not (barn and sy==1 and level==0):add_window(kind,sx*w*.3,sy*(d/2+.12),bottom,rot,level==0 and sy==1 and not barn)
            if not barn:
                # Complete knee braces connect corner posts to the top beam and
                # stay outside window bounds; no cut-off floating fragments.
                G.beam('connected_corner_brace',(sx*(w/2-.06),sy*(d/2+.16),h-1.28),(sx*(w/2-1.15),sy*(d/2+.16),h-.12),.24,'timber')
        G.box('roof_wall_infill',(w,.34,eave_infill-.16),(0,sy*d/2,h+(eave_infill-.16)/2),'barn' if barn else 'plaster')
    for sx in [-1,1]:
        # exact depth panels are parameterized residual modules, not whole-building scaling
        for level in [0,1]:
            core=G.box('side_wall',(.34,d-.34,layer),(sx*w/2,0,level*layer+layer/2),'barn' if barn else 'plaster')
            if level==0:
                G.subtract(core,G.box('side_window_cut',(1.2,1.35,1.3),(sx*w/2,0,1.95)))
        for zz in [layer-.12,h-.12]:G.box('side_band',(.39,d,.27),(sx*w/2,0,zz),'ivory' if barn else 'timber',.035)
        for j in range(math.ceil(d)):
            G.box('side_foundation',(.55,d/math.ceil(d)-.025,.38),(sx*w/2,-d/2+(j+.5)*d/math.ceil(d),.19),'sandstone',.055)
        add_window(kind,sx*(w/2+.12),0,1.3,-sx*math.pi/2)
        if barn:
            for row in range(20):
                z=.20+row*.38
                for k in range(12):
                    y=-d/2+.48+k*.9-(row%2)*.45
                    if abs(y)>.5*d-.3 or abs(y)<1.1 and 1.0<z<2.9:continue
                    G.box('side_brick',(.025,.85,.34),(sx*(w/2+.18),y,z),['barn','barn_light','barn','barn_dark'][k%4],.024)
        for sy in [-1,1]:G.box('corner_post',(.32,.34,h+eave_infill-.16),(sx*(w/2-.06),sy*(d/2-.03),(h+eave_infill-.16)/2),'ivory' if barn else 'timber',.03)
        gable=G.profile('gable_infill',[(-d/2,0),(d/2,0),(d/2,eave_infill-.16),(0,rise-.16),(-d/2,eave_infill-.16)],.32,'barn' if barn else 'plaster');gable.rotation_euler.z=math.pi/2;gable.location=(sx*w/2,0,h)
        for sy in [-1,1]:G.beam('gable_rake',(sx*(w/2+.22),sy*(roof_depth/2+.02),h-.16),(sx*(w/2+.22),0,h+rise-.16),.30,'timber')
    # Base strips either side of the door plus true entrance step.
    gap=2.25 if barn else 1.04
    for side in [-1,1]:
        nblocks=math.ceil((w/2-gap)/1.05);pitch=(w/2-gap)/nblocks
        for k in range(nblocks):G.box('threshold_side_stone',(pitch-.025,.55,.38),(side*(gap+(k+.5)*pitch),d/2+.05,.19),['sandstone','stone_light','stone_dark'][k%3],.055)
    if barn:
        inst('V_cargo_door',(0,d/2+.24,.25));inst('V_hayloft',(0,d/2+.22,5.08))
        inst('V_barrel',(3.36,d/2+.9,0));inst('V_haybale',(-3.45,d/2+.80,0))
    else:
        inst('V_'+kind+'_doorframe',(0,d/2+.18,.3));inst('V_door',(0,d/2+.2,.3));inst('V_porch',(0,d/2+.19,0))
    n=int(w/4)
    for i in range(n):
        x=-w/2+2+4*i;inst('V_roof_thatch_4m' if barn else 'V_roof_tile_4m',(x,0,h));inst('V_ridge_thatch' if barn else 'V_ridge_tile',(x,0,h+rise))
    # End overhangs built with scaled module pitch only at roof ends.
    ext=1.50 if barn else .78
    for sx in [-1,1]:
        start=set(col.objects);roof_section(ext,13.2 if barn else 10.24,rise,'thatch' if barn else 'tile',caps=(sx<0,sx>0));ridge(ext,'thatch' if barn else 'tile')
        for o in set(col.objects)-start:
            o.location.x+=sx*(w/2+ext/2);o.location.z+=h+(rise if o.name.startswith(('ridge_cap','bound_straw_ridge','rope_binding','organic_bound_ridge','ridge_rope')) else 0)
    for sy in [-1,1]:
        for i in range(n*2+1):inst('V_bracket',(-w/2+i*2,sy*(d/2+.1),h-.13),0 if sy==1 else math.pi)
    inst('V_chimney',(-w*.28,-d*.2,h+rise*.30))
    ASSEMBLIES[kind]=(root,col);export(root,col,'assemblies');col.hide_render=True

def windmill():
    root,col=context('VALE_windmill')
    for i in range(4):inst('V_mill_course_'+str(i),(0,0,3.5*i))
    inst('V_mill_roof',(0,0,14))
    G.arch_frame('mill_door',1.4,1.8,0,.18,.28,2.85)
    inst('V_door',(0,2.91,0),0,(.74,1,.87))
    for z in [5,8.5]:
        y=(3-.9*(z/14))*math.cos(math.pi/8)+.08;add_window('farm',0,y,z,0,False,.69)
    # Rock collar sectors stay below doorway; exact octagonal silhouette.
    for j in [0,1]:
        for k in range(24):
            a=k*math.tau/24+math.pi/8;r=2.94-.02*j
            x,y=r*math.cos(a),r*math.sin(a)
            if abs(x)<1 and y>2:continue
            inst('V_stone_SDF',(x,y,j*.32),a+math.pi/2,(.72,.50,.56))
    for z,a in [(2.9,math.pi*.65),(6.9,math.pi*.70),(10.3,math.pi*.63)]:
        r=(3-.9*z/14)*math.cos(math.pi/8)/math.cos((a-math.pi/8)%(math.pi/4)-math.pi/8)
        for j in range(2):
            o=G.box('plaster_exposed_stone',(.55,.06,.30),(0,0,0),'stone_light',.04);o.location=(r*math.cos(a),r*math.sin(a),z+j*.33);o.rotation_euler.z=a-math.pi/2
    inst('V_mill_hub',(0,3.65,11.9))
    rotor=bpy.data.objects.new('ROTOR_PIVOT',None);col.objects.link(rotor);rotor.parent=root;rotor.location=(0,3.65,11.9);rotor['godot_spin_axis']='Z';rotor['local_axis_blender']='Y'
    for i in range(4):
        rt=inst('V_mill_sail');rt.parent=rotor;rt.rotation_euler.y=i*math.pi/2
    ASSEMBLIES['windmill']=(root,col);export(root,col,'assemblies');col.hide_render=True
    # Separate rotor export with origin exactly at the spinning hub.
    rr,rc=context('VALE_rotor')
    inst('V_mill_hub')
    for i in range(4):r=inst('V_mill_sail');r.rotation_euler.y=i*math.pi/2
    ASSEMBLIES['rotor']=(rr,rc);export(rr,rc,'assemblies');rc.hide_render=True

def stages():
    r,c=context('STAGE_01_CSG')
    G.box('farm_mass',(12,9,6),(0,0,3),'plaster')
    g=G.profile('roof_mass',[(-5.12,6),(5.12,6),(0,11.24)],13.56,'terracotta');g.rotation_euler.z=math.pi/2
    export(r,c,'stages');c.hide_render=True
    for refined in [False,True]:
        r,c=context('STAGE_02_SDF_initial' if not refined else 'STAGE_07_SDF_refined_batch')
        for i,kind in enumerate(['stone','plinth','rock']):
            v,f=polygonize(kind,.12,refined);o=G.mesh('analytic_'+kind,v,f,'sandstone');o.location.x=i*2
        export(r,c,'stages');c.hide_render=True

def render(col,name,angle='hero'):
    col.hide_render=False
    bpy.context.view_layer.update();lo,hi=bounds(col.objects);lo=Vector(lo);hi=Vector(hi);ctr=(lo+hi)/2;span=max(hi-lo)
    cam=SC.camera
    direction={'hero':(.9,1.5,.70),'front':(0,1,0),'right':(1,0,0),'back':(0,-1,0)}[angle]
    cam.location=ctr+Vector(direction)*span*2;cam.rotation_euler=(ctr-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=span*1.35
    SC.render.filepath=str(OUT/'renders'/f'{name}_{angle}.png');bpy.ops.render.render(write_still=True);col.hide_render=True

def lighting():
    SC.render.engine='CYCLES';SC.cycles.samples=24;SC.cycles.use_denoising=True;SC.cycles.device='CPU'
    SC.render.resolution_x=1200;SC.render.resolution_y=1200;SC.render.resolution_percentage=100
    SC.world=bpy.data.worlds.new('Warm neutral world');SC.world.use_nodes=True;SC.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.69,.74,1);SC.world.node_tree.nodes['Background'].inputs[1].default_value=.7
    SC.view_settings.view_transform='Standard'
    env=bpy.data.collections.new('Presentation only');SC.collection.children.link(env)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02));p=bpy.context.object
    for c in list(p.users_collection):c.objects.unlink(p)
    env.objects.link(p);p.name='Presentation floor';p.data.materials.append(G.material('ivory'))
    for name,loc,energy,size in [('Key',(-10,12,25),1800,12),('Fill',(12,0,15),900,10)]:
        ld=bpy.data.lights.new(name,'AREA');ld.energy=energy;ld.shape='DISK';ld.size=size;o=bpy.data.objects.new(name,ld);env.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,5))-o.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('Asset camera');cam=bpy.data.objects.new('Asset camera',cd);env.objects.link(cam);cd.type='ORTHO';SC.camera=cam

def main():
    stages();make_library();house('farm');house('barn');windmill()
# Actual complete reusable fence assembly uses source segments and one post per boundary.
    r,c=context('VALE_fence_demo')
    for x in [-4,0,4]:inst('V_fence_4m',(x,0,0))
    G.box('terminal_post',(.21,.21,1.4),(6,0,.70),'timber',.03)
    ASSEMBLIES['fence_demo']=(r,c);export(r,c,'assemblies');c.hide_render=True
    manifest={'version':'1.0','front':'Blender +Y = Godot -Z','units':'metres','palette_srgb':G.PALETTE,'palette_source':'docs/palette/palette.json + user supplied palette image','palette_map':PALETTE_MAP,'modules':RECORDS,'assemblies':{k:{'file':'assemblies/'+v[0].name+'.glb','bounds_blender':bounds(v[1].objects)} for k,v in ASSEMBLIES.items()},'facade_seams':SEAMS,'source_files':['tools/gen_vale.gd','tools/blender/build_models.py','tools/blender/build_props.py'],'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(__file__).parent.glob('*.py')}}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    lighting()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'vale_kit.blend'))
    for key in ['farm','barn','windmill']:
        for angle in ['hero','front','right','back']:render(ASSEMBLIES[key][1],key,angle)
# Make the first building immediately visible on opening the editable source.
    ASSEMBLIES['farm'][1].hide_render=False
    for c in SC.collection.children:
        if c.name!='Presentation only':c.hide_viewport=c!=ASSEMBLIES['farm'][1]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'vale_kit.blend'))
    print('VALE_BUILD_COMPLETE',str(OUT),len(LIB),len(ASSEMBLIES))

if __name__=='__main__':main()
