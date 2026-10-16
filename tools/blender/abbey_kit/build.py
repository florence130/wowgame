"""Run in a fresh background Blender. Build, validate, export and render the kit.

blender -b --factory-startup --python build.py -- --out ABS_NEW_DIRECTORY
Optional --preset preset.json --only wall_plain_4 window_arch_frame --no-render
"""
import argparse, sys, json, math, hashlib, datetime
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import geometry as G
import components as C

TECH={
'wall_plain_4':['profile_extrude','vertices'],'wall_plain_2':['profile_extrude'],
'wall_door_4':['CSG','profile_extrude'],'wall_window_4':['CSG','profile_extrude'],
'window_arch_frame':['profile_extrude'],'window_arch_glass':['profile_extrude','curve_bevel'],
'door_arch_frame':['profile_extrude'],'door_wood_double':['CSG','profile_extrude'],
'door_wood_plain':['profile_extrude'],'door_stone':['profile_extrude'],
'rose_frame':['curve_bevel'],'rose_glass':['profile_extrude','curve_bevel'],
'column_3':['spin','profile_extrude'],'railing_wood_4':['vertices'],'railing_stone_4':['spin','array'],
'fence_post':['profile_extrude'],'arcade_4':['CSG','profile_extrude'],
'roof_gable_8x4':['mirror','solidify','vertices'],'roof_gable_4x4':['mirror','solidify','vertices'],
'roof_ridge_4':['profile_extrude'],'gable_rose_8':['CSG','profile_extrude'],'gable_plain_4':['profile_extrude'],
'floor_stone_4':['array','vertices'],'floor_wood_4':['array'],'plinth_4':['profile_extrude'],
'stairs_4':['profile_extrude','array'],'chimney':['CSG','profile_extrude'],
'dome_frame_4':['spin','curve_bevel'],'dome_glass_4':['loft','solidify'],
'bridge_segment_4':['vertices','array','curve_deform'],'balcony_4':['vertices'],
'sagging_beam_4':['simple_deform'],'bell':['loft','spin'],'buttress':['profile_extrude'],
'sdf_stone':['SDF','vertices'],'sdf_plinth':['SDF','vertices'],'sdf_rock':['SDF','vertices']}
LABELS=['纯墙4米','纯墙2米','拱门洞墙','拱窗洞墙','拱窗框','拱窗玻璃','拱门框','木双开门','素木门','石门','圆花窗框','圆花窗玻璃','3米柱','木栏杆','石栏杆','栏杆柱','回廊拱跨','8米坡屋顶','4米坡屋顶','屋脊','花窗山墙','普通山墙','石地板','木地板','地台','4级台阶','烟囱','穹顶框','穹顶玻璃','石桥段','阳台','弯木梁','钟','扶壁','SDF石块','SDF石基','SDF山石','长椅','花盆','货箱','木桶','墓碑','训练假人','武器架','祭台','灯柱','喷泉','柏树','旗帜']
ASSETS={};MAN=[];PLACES=[]

def make_scene(name):
    s=bpy.data.scenes.new(name);bpy.context.window.scene=s
    s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    s.world=bpy.data.worlds.new(name+'_world');s.world.use_nodes=True
    wn=s.world.node_tree.nodes;wn.clear();bg=wn.new('ShaderNodeBackground');wo=wn.new('ShaderNodeOutputWorld');bg.inputs[0].default_value=(.86,.84,.78,1);s.world.node_tree.links.new(bg.outputs[0],wo.inputs[0])
    s.render.engine='CYCLES';s.cycles.samples=8
    s.view_settings.view_transform='Standard';s.view_settings.look='None'
    s.view_settings.exposure=0;s.view_settings.gamma=1
    s.render.image_settings.file_format='PNG';s.render.film_transparent=False
    return s

def empty(name,col):
    o=bpy.data.objects.new(name,None);col.objects.link(o);o.empty_display_size=.2;return o

def recursive(root):
    return [o for o in root.children_recursive if o.type in ('MESH','CURVE','SURFACE','FONT')]

def evaluated_stats(root):
    dg=bpy.context.evaluated_depsgraph_get();bpy.context.view_layer.update()
    verts=[];tris=0;uv=True;bad=0
    for o in recursive(root):
        ev=o.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles)
        m=root.matrix_world.inverted()@o.matrix_world
        verts += [m@v.co for v in me.vertices]
        bad+=sum(1 for t in me.loop_triangles if (me.vertices[t.vertices[1]].co-me.vertices[t.vertices[0]].co).cross(me.vertices[t.vertices[2]].co-me.vertices[t.vertices[0]].co).length_squared<1e-18)
        # Curves/screw need UV generated on the export copy.
        ev.to_mesh_clear()
    lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)]
    return {'bounds_min':lo,'bounds_max':hi,'triangles':tris,'degenerate_triangles':bad}

def add_uv(me):
    if me.uv_layers:return
    uv=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        axis=max(range(3),key=lambda k:abs(p.normal[k])); axes=[k for k in range(3) if k!=axis]
        for li in p.loop_indices:
            co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]],co[axes[1]])

def export_root(root,path):
    # Export evaluated mesh copies; source modifiers stay editable in the .blend.
    scene=bpy.context.scene;tmp=bpy.data.collections.new('_EXPORT_TEMP');scene.collection.children.link(tmp)
    dg=bpy.context.evaluated_depsgraph_get();copies=[]
    for o in recursive(root):
        me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
        if not me.polygons:bpy.data.meshes.remove(me);continue
        add_uv(me)
        obj=bpy.data.objects.new(o.name,me);tmp.objects.link(obj);obj.matrix_world=root.matrix_world.inverted()@o.matrix_world;copies.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for o in copies:o.select_set(True)
    if copies:bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=False,export_yup=True,export_extras=True,export_materials='EXPORT')
    for o in copies:
        me=o.data;bpy.data.objects.remove(o,do_unlink=True);bpy.data.meshes.remove(me)
    bpy.data.collections.remove(tmp)

def sockets(key):
    out=[]
    def s(name,p,normal,kind):out.append({'name':name,'position_blender':p,'normal_blender':normal,'kind':kind})
    if key.startswith('wall_') or key in ('arcade_4','railing_wood_4','railing_stone_4','bridge_segment_4'):
        length=2 if key=='wall_plain_2' else 4
        s('left',[-length/2,0,0],[-1,0,0],'linear_4m');s('right',[length/2,0,0],[1,0,0],'linear_4m')
    if key.startswith(('wall_','column')):s('top',[0,0,3],[0,0,1],'stack_3m')
    if key.startswith('roof_gable') or key=='roof_ridge_4':
        s('front',[0,2,0],[0,1,0],'roof_pitch_4m');s('back',[0,-2,0],[0,-1,0],'roof_pitch_4m')
    if key in ('window_arch_frame','window_arch_glass','wall_window_4'):s('window',[0,0,0],[0,1,0],'window_1p4_s2p05')
    if key in ('door_arch_frame','wall_door_4','door_wood_double','door_wood_plain','door_stone'):s('door',[0,0,0],[0,1,0],'door_2_s1p7')
    if key in ('rose_frame','rose_glass'):s('rose',[0,0,0],[0,1,0],'rose_r1')
    s('origin',[0,0,0],[0,0,-1],'insertion')
    return out

def instance(key,xyz=(0,0,0),angle=0,parent=None):
    src=ASSETS[key];scene=bpy.context.scene
    root=empty(key+'_instance',scene.collection);root.location=xyz;root.rotation_euler.z=math.radians(angle)
    if parent:root.parent=parent
    for o in src.children:
        cp=o.copy();cp.data=o.data;scene.collection.objects.link(cp);cp.parent=root;cp.matrix_parent_inverse.identity();cp.matrix_basis=o.matrix_basis.copy()
    PLACES.append({'assembly':parent.name if parent else scene.name,'asset':key,'position_blender':list(xyz),'rotation_z_deg':angle})
    return root

def chapel(bays=4,origin=(0,0,0),name='chapel'):
    root=empty(name,bpy.context.scene.collection);root.location=origin
    L=bays*4;zbase=.6
    for x in (-2,2):
        for i in range(bays):
            y=-L/2+2+i*4;instance('plinth_4',(x,y,0),parent=root);instance('floor_stone_4',(x,y,.6),parent=root)
    for sy in (-1,1):
        y=sy*L/2;rot=0 if sy==1 else 180
        instance('wall_door_4',(0,y,zbase),rot,root);instance('door_arch_frame',(0,y+sy*.02,zbase),rot,root)
        if sy==-1:instance('door_wood_double',(0,y,zbase),rot,root)
        for x in (-3,3):instance('wall_plain_2',(x,y,zbase),rot,root)
        # Upper front wall 3m floor, a lower roof creates readable village proportions.
        instance('gable_rose_8',(0,y,zbase+3),rot,root)
        instance('rose_frame',(0,y+sy*.25,zbase+4.19),rot,root)
        instance('rose_glass',(0,y+sy*.26,zbase+4.19),rot,root)
    for sx in (-1,1):
        for i in range(bays):
            y=-L/2+2+i*4;rot=-90 if sx==1 else 90
            for key in ('wall_window_4','window_arch_frame','window_arch_glass'):instance(key,(sx*4,y,zbase),rot,root)
        for i in range(bays+1):instance('buttress',(sx*4.25,-L/2+i*4,zbase),90,root)
    for i in range(bays):
        y=-L/2+2+i*4;instance('roof_gable_8x4',(0,y,zbase+3),parent=root);instance('roof_ridge_4',(0,y,zbase+5.72),parent=root)
    instance('stairs_4',(0,L/2+.6,0),parent=root)
    instance('prop_altar',(0,-L/2+2,zbase+.225),parent=root)
    for y in [-L/2+5+i*2 for i in range(max(1,bays*2-3))]:
        for x in (-2.2,2.2):instance('prop_bench',(x,y,zbase+.225),parent=root)
    return root

def tower(origin=(-9,-3,0)):
    root=empty('bell_tower',bpy.context.scene.collection);root.location=origin
    instance('plinth_4',(0,0,0),parent=root)
    for level in range(2):
        for x,y,a in [(0,2,0),(0,-2,180),(2,0,-90),(-2,0,90)]:
            key='wall_door_4' if level==0 and y==2 else 'wall_window_4'
            instance(key,(x,y,.6+level*3),a,root)
            if key=='wall_window_4':instance('window_arch_frame',(x,y,.6+level*3),a,root);instance('window_arch_glass',(x,y,.6+level*3),a,root)
            else:instance('door_arch_frame',(x,y,.6),a,root)
    for x in (-2,2):
        for y in (-2,2):instance('column_3',(x,y,6.6),parent=root)
    for x,y,a in [(0,2,0),(0,-2,180),(2,0,-90),(-2,0,90)]:instance('arcade_4',(x,y,6.6),a,root)
    instance('roof_gable_4x4',(0,0,9.6),parent=root)
    for y,a in [(-2,180),(2,0)]:instance('gable_plain_4',(0,y,9.6),a,root)
    instance('roof_ridge_4',(0,0,10.96),parent=root);instance('bell',(0,0,7.7),parent=root)
    return root

def cloister(bays=3,origin=(-10,7,0)):
    root=empty('cloister',bpy.context.scene.collection);root.location=origin
    for i in range(bays):
        x=i*4
        instance('floor_stone_4',(x,0,0),parent=root)
        for sy in (-1,1):instance('arcade_4',(x,sy*2,0),parent=root)
        instance('roof_gable_4x4',(x,0,3),90,root);instance('roof_ridge_4',(x,0,4.36),90,root)
    for i in range(bays+1):
        for sy in (-1,1):instance('column_3',(-2+i*4,sy*2,0),parent=root)
    for x,a in [(-2,90),(bays*4-2,-90)]:instance('gable_plain_4',(x,0,3),a,root)
    return root

def gate(origin=(1,17,0)):
    root=empty('courtyard_gate',bpy.context.scene.collection);root.location=origin
    instance('wall_door_4',parent=root);instance('door_arch_frame',parent=root)
    for x in (-6,-2,2,6):instance('column_3',(x,0,0),parent=root)
    for x in (-4,4):instance('railing_stone_4',(x,0,0),parent=root)
    instance('roof_gable_4x4',(0,0,3),parent=root)
    for y,a in [(-2,180),(2,0)]:instance('gable_plain_4',(0,y,3),a,root)
    instance('roof_ridge_4',(0,0,4.36),parent=root)
    return root

def curved_bridge(count=4,bend=2.5):
    root=empty('bridge_array_curve',bpy.context.scene.collection)
    # Mesh segments combined first, ensuring one consistent deformation space.
    inst=instance('bridge_segment_4',parent=root);dg=bpy.context.evaluated_depsgraph_get();bpy.context.view_layer.update()
    verts=[];faces=[];material_indices=[];mats=[]
    for o in recursive(inst):
        me=bpy.data.meshes.new_from_object(o.evaluated_get(dg));offset=len(verts)
        verts += [tuple(o.matrix_local@v.co+Vector((2,0,0))) for v in me.vertices]
        for p in me.polygons:
            faces.append(tuple(i+offset for i in p.vertices));mat=me.materials[p.material_index]
            if mat not in mats:mats.append(mat)
            material_indices.append(mats.index(mat))
        bpy.data.meshes.remove(me)
    for o in list(inst.children):bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.objects.remove(inst,do_unlink=True)
    G.COL=bpy.context.scene.collection;G.ROOT=root
    o=G.mesh('bridge_array_then_curve',verts,faces,None)
    for m in mats:o.data.materials.append(m)
    for p,idx in zip(o.data.polygons,material_indices):p.material_index=idx
    G.array(o,count,(4,0,0),True)
    cu=bpy.data.curves.new('bridge_path','CURVE');cu.dimensions='3D';cu.resolution_u=24
    s=cu.splines.new('BEZIER');s.bezier_points.add(4)
    for i,p in enumerate(s.bezier_points):
        p.co=(count*4*i/4,bend*math.sin(math.pi*i/4),0);p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    path=bpy.data.objects.new('CONTROL_bridge_path',cu);bpy.context.scene.collection.objects.link(path);path.parent=root
    m=o.modifiers.new('07 Curve after Array','CURVE');m.object=path;m.deform_axis='POS_X'
    return root

def camera(scene,target,position,scale,res=1400):
    data=bpy.data.cameras.new(scene.name+'_camera');o=bpy.data.objects.new(data.name,data);scene.collection.objects.link(o)
    o.location=position;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=scale;scene.camera=o
    scene.render.resolution_x=res;scene.render.resolution_y=int(res*.75);scene.render.resolution_percentage=100

def render(scene,path):
    bpy.context.window.scene=scene;scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)

def validate_geometry():
    results=[]
    def check(name,ok,**e):results.append({'check':name,'passed':bool(ok),**e})
    bpy.context.window.scene=LIB;bpy.context.view_layer.update()
    for key,root in ASSETS.items():
        stats=evaluated_stats(root);check(key+'_finite',all(math.isfinite(v) for k in ('bounds_min','bounds_max') for v in stats[k]),**stats)
        check(key+'_nonempty',stats['triangles']>0)
        check(key+'_no_degenerate_triangles',stats['degenerate_triangles']==0)
        if key in ('wall_plain_4','wall_window_4','wall_door_4','arcade_4'):
            check(key+'_pitch',abs(stats['bounds_max'][0]-stats['bounds_min'][0]-4)<1e-5)
    # Real ray casts through evaluated wall cores in front-to-back direction.
    for key,z in [('wall_door_4',1.3),('wall_window_4',1.5)]:
        if key not in ASSETS:continue
        root=ASSETS[key];core=next(o for o in root.children if o.name.startswith('plaster_core'))
        ev=core.evaluated_get(bpy.context.evaluated_depsgraph_get())
        hit,*_=ev.ray_cast(Vector((0,2,z)),Vector((0,-1,0)))
        side,*_=ev.ray_cast(Vector((1.8,2,z)),Vector((0,-1,0)))
        check(key+'_opening_penetrates',not hit and side,center_hit=hit,solid_side_hit=side)
    # Structural fit is measured independently from exported GLB in verify_exports.py.
    return results

def build_pipeline(out):
    s=make_scene('ABY_Pipeline');root=empty('pipeline_samples',s.collection);G.COL=s.collection;G.ROOT=root
    # S01 primitive CSG blockout with genuine boolean opening.
    o=G.box('S01_CSG_block',(3,.5,3),(0,0,1.5),'plaster');G.subtract(o,G.profile('CSG_cut',G.arch_outline(1.6,1.6,-.1),1))
    a=empty('S02_SDF_raw',s.collection);G.ROOT=a;C.sdf_asset('stone',False);a.location=(4,0,0)
    b=empty('S07_SDF_refined',s.collection);G.ROOT=b;C.sdf_asset('stone',True);b.location=(6,0,0)
    c=instance('wall_door_4',(10,0,0));d=instance('door_arch_frame',(10,0,0))
    camera(s,(5,0,1.4),(13,18,12),16,1200)
    return s

def main():
    global LIB
    if not bpy.app.background:raise RuntimeError('Run this builder in a fresh background Blender; it does not operate on your live scene.')
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--preset',default=str(HERE/'preset.json'));ap.add_argument('--only',nargs='+');ap.add_argument('--no-render',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=Path(args.out).resolve()
    if out.exists():raise FileExistsError(f'Refusing to overwrite existing build: {out}; choose a new build directory.')
    config=json.loads(Path(args.preset).read_text(encoding='utf-8'))
    for k,lo,hi in [('chapel_bays',2,8),('cloister_bays',1,8),('bridge_segments',1,10)]:
        v=config[k]
        if isinstance(v,bool) or not isinstance(v,int) or not lo<=v<=hi:raise ValueError(f'{k} must be integer {lo}..{hi}')
    if not 0<=config['bridge_bend_m']<=4:raise ValueError('bridge_bend_m 0..4')
    G.PALETTE.update(config.get('palette',{}))
    names=args.only or list(C.RECIPES)
    if set(names)-C.RECIPES.keys():raise ValueError('Unknown asset IDs: '+str(set(names)-C.RECIPES.keys()))
    (out/'glb').mkdir(parents=True);(out/'renders').mkdir();(out/'assemblies').mkdir()
    LIB=make_scene('ABY_Library')
    for idx,key in enumerate(names):
        col=bpy.data.collections.new('ABY_'+key);LIB.collection.children.link(col);G.COL=col;G.ROOT=None
        root=empty('ABY_'+key,col);G.ROOT=root;C.RECIPES[key]();root['asset_id']=key;root['kit_version']='1.0';ASSETS[key]=root
        bpy.context.view_layer.update();st=evaluated_stats(root)
        MAN.append({'id':key,'label_zh':LABELS[list(C.RECIPES).index(key)],'route':'SDF' if key.startswith('sdf_') else 'CSG/mesh','techniques':TECH.get(key,['profile_extrude','vertices']),'sockets':sockets(key),'file':'glb/'+key+'.glb',**st})
        export_root(root,out/'glb'/f'{key}.glb')
        print('ASSET',key,st['triangles'],flush=True)
    checks=validate_geometry()
    assemblies=[];scenes=[]
    if not args.only:
        demo=make_scene('ABY_Demo');scenes.append(demo)
        clo=cloister(config['cloister_bays'],(-10,2,0));clo.rotation_euler.z=math.pi/2
        for root in [chapel(config['chapel_bays']),tower((-10,-4,0)),clo,gate((1,17,0))]:
            export_root(root,out/'assemblies'/f'{root.name}.glb');assemblies.append(root.name)
        for key,xyz in [('prop_fountain',(-4,13,.225)),('prop_planter',(-3,9,0)),('prop_planter',(3,9,0)),('prop_cypress',(7,6,0)),('prop_cypress',(7,-5,0)),('prop_bench',(-9,15,0)),('prop_lamp',(-4,18,0)),('prop_lamp',(6,18,0))]:instance(key,xyz)
        for x in (-6,-2,2):
            for y in (10,14):instance('floor_stone_4',(x,y,0))
        camera(demo,(-2,4,3),(33,46,32),45,config['render_resolution'])
        bridge=make_scene('ABY_Bridge');scenes.append(bridge)
        curve=curved_bridge(config['bridge_segments'],config['bridge_bend_m']);export_root(curve,out/'assemblies'/'bridge_curved.glb')
        straight=curved_bridge(2,0);straight.location=(0,-6,0)
        camera(bridge,(6,-1,0),(18,22,20),26,config['render_resolution'])
        detail=make_scene('ABY_Bridge_Detail');scenes.append(detail)
        curved_bridge(config['bridge_segments'],config['bridge_bend_m'])
        camera(detail,(7,1.6,.5),(11,10,8),12,1400)
        stair_scene=make_scene('ABY_Stair_Side');scenes.append(stair_scene)
        instance('stairs_4',(0,2.6,0));instance('plinth_4');instance('floor_stone_4',(0,0,.6))
        camera(stair_scene,(0,.8,.4),(15,.8,.4),7,1200)
        pipeline=build_pipeline(out);scenes.append(pipeline)
        # Gallery is a separate scene, libraries keep origin at zero for editing and export.
        gallery=make_scene('ABY_Catalog');scenes.append(gallery)
        for idx,key in enumerate(names):
            root=instance(key,((idx%7)*6,(idx//7)*6,0))
            # labels are camera-readable on the ground, unaffected by lighting.
            G.COL=gallery.collection;G.ROOT=None
            cu=bpy.data.curves.new('label','FONT');cu.body=f'{idx+1:02d} {key}';cu.size=.28;cu.align_x='CENTER';o=bpy.data.objects.new('label',cu);gallery.collection.objects.link(o);o.location=(root.location.x,root.location.y-2.6,.03);cu.materials.append(G.material('timber'))
        camera(gallery,(18,18,0),(46,66,55),58,2400)
        for o in gallery.objects:
            if o.type=='FONT':o.rotation_euler=gallery.camera.rotation_euler
        # Assembly variation proves same components can build shorter chapel.
        alt=make_scene('ABY_Variation');scenes.append(alt);small=chapel(2,name='chapel_small');export_root(small,out/'assemblies'/'chapel_small.glb')
        camera(alt,(0,0,2),(16,22,15),24,config['render_resolution'])
    manifest={'version':'1.0','generated_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},'units':'metres','blender_axes':{'up':'+Z','front':'+Y'},'godot_axes':{'up':'+Y','front':'-Z'},'basis_conversion':'(x,y,z)->(x,z,-y)','uv':'Box projection in metres; broad color-block materials. Not a baked atlas.','material_mode':'KHR_materials_unlit, opaque color glass stylization','config':config,'assets':MAN,'assemblies':assemblies,'placements':PLACES,'production_status':'source and model prototype; not installed into live map'}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'validation.json').write_text(json.dumps({'checks':checks,'passed':all(c['passed'] for c in checks),'scope':'evaluated component geometry, structural pitch and opening rays; game integration separate'},indent=2),encoding='utf-8')
    if scenes:bpy.context.window.scene=scenes[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
    if not args.no_render:
        for s in scenes:render(s,out/'renders'/f'{s.name}.png')
    if not all(c['passed'] for c in checks):raise RuntimeError('Geometry validation failed; see validation.json')
    print('ABBEY_BUILD_OK',str(out),flush=True)

if __name__=='__main__':main()
