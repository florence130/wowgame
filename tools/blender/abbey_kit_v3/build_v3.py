"""Reproducible modular abbey interior and physically supported exterior.
Blender -b --factory-startup --python build_v3.py -- --out ABS --res 1200
"""
import bpy, sys, json, math, argparse, importlib.util
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('abbey_exterior_v2',HERE.parent/'abbey_kit_v2/build.py')
V=importlib.util.module_from_spec(spec);spec.loader.exec_module(V)
G=V.G;B=V.B;M=V.M;D=V.D
sys.path.insert(0,str(HERE))
import structure as S, furniture as F, doors, pipeline, openings as O, glass
NEW=[]
DEFAULT={'door_angle':105,'pew_rows':5,'pew_pitch':1.65,'pew_first_y':5.1,'aisle_clear_width':2.1,'floor_z':.9,'column_height':5.4,'beam_bottom':6.3,'chandelier_energy':48,'floor_lamp_energy':35}
_RENDER_DEVICE=None

def render_scene(scene,path):
    global _RENDER_DEVICE
    if _RENDER_DEVICE is None:
        _RENDER_DEVICE='CPU'
        prefs=bpy.context.preferences.addons['cycles'].preferences
        for backend in ('CUDA','OPTIX'):
            try:
                prefs.compute_device_type=backend;prefs.get_devices()
                if any(d.type==backend for d in prefs.devices):
                    for d in prefs.devices:d.use=d.type==backend
                    _RENDER_DEVICE='GPU';break
            except (RuntimeError,TypeError):continue
    scene.cycles.device=_RENDER_DEVICE
    try:B.render(scene,path)
    except RuntimeError:
        if _RENDER_DEVICE!='GPU':raise
        _RENDER_DEVICE='CPU';scene.cycles.device='CPU';B.render(scene,path)

def sockets(axis,pitch,kind,z=0):
    rows=[]
    for sign in (-1,1):
        p=[0,0,z];p[axis]=sign*pitch/2;n=[0,0,0];n[axis]=sign
        rows.append(dict(name='start' if sign<0 else 'end',position_blender=p,normal_blender=n,kind=kind))
    return rows

def register(key,label,fn,methods,ports=None):
    V.asset(key,label,fn,methods,ports);NEW.append(key)

def capital():
    verts,faces=pipeline.refined_capital_mesh()
    o=G.mesh('SDF refined carved stone capital',verts,faces,'stone_light')
    o['modeling_route']='analytic SDF > finer volume sampling > planar interface correction'
    return o

def interior_column():
    objects=S.interior_column()
    for ob in objects:
        if 'SquareCapital' in ob.name:bpy.data.objects.remove(ob,do_unlink=True)
    ob=capital();ob.location.z=5.16

def foundation_strip():
    S.foundation_strip_4m()
    G.box('Foundation continuous bearing below coping',(4,1.325,.08),(0,0,.758),'stone_dark')

_original_asset=V.asset
def asset_with_bedding(key,label,fn,methods,sockets=None):
    if key=='floor_stone_4':
        original=fn
        def fn():
            original();G.box('Continuous mortar bedding',(4,4,.098),(0,0,.049),'grout')
    if key=='plinth_4':
        def fn():
            G.box('Dressed platform',(4,4,.62),(0,0,.31),'stone_dark',.012)
            # A bearing edge must remain planar under a spanning buttress foot.
            G.box('Platform upper rim',(4,4,.18),(0,0,.71),'sandstone')
    result=_original_asset(key,label,fn,methods,sockets)
    entry=V.MAN[-1];r=V.ASSETS[key]
    for ob in r.children_recursive:
        if ob.get('socket_kind')=='light_point':
            entry['sockets'].append(dict(name=ob.name,position_blender=list(ob.location),normal_blender=[0,0,-1],kind='light_point',suggested_energy_watts=ob['suggested_energy_watts']))
    return result
V.asset=asset_with_bedding

def rear_portal():
    outline=[(-4,0),(4,0),(4,6.2),(0,9.4),(-4,6.2)]
    V.facade_material_wall('Rear sanctuary portal',outline,.46,[G.arch_outline(5.2,2.75,-.1)],8,9.4)
    D.stone_arch(5.2,2.75,0,.52,.24)

def apse_floor():
    n=48;r=3.30;v=[]
    xy=[(r*math.cos(i*math.pi/n),-r*math.sin(i*math.pi/n)) for i in range(n+1)]
    for z in (0,.1):v.extend((x,y,z) for x,y in xy)
    m=len(xy);f=[tuple(range(m-1,-1,-1)),tuple(range(m,2*m))]
    for i in range(m):j=(i+1)%m;f.append((i,j,j+m,i+m))
    G.mesh('Sanctuary semicircular floor',v,f,'sandstone')

def ceiling():
    # Two editable solidified boards below the stone slate roof.
    o=G.mesh('Wood roof inner lining',[(0,-2,3.07),(3.82,-2,0),(3.82,2,0),(0,2,3.07)],[(0,1,2,3)],'wood_dark')
    m=o.modifiers.new('Mirror two roof pitches','MIRROR');m.use_axis=(True,False,False)
    m=o.modifiers.new('Solidify timber roof sheathing','SOLIDIFY');m.thickness=.045;m.offset=1
    for sign in (-1,1):
        for i in range(1,10):
            x=sign*i*.375;z=3.07*(1-abs(x)/3.82)
            G.box('Roof lining board seam',(.016,4,.018),(x,0,z-.018),'timber')

def entry_stairs():
    for i in range(6):G.box('Stone entry tread',(3.4,.415,.15*(6-i)),(0,.2+i*.4,.075*(6-i)),'sandstone',.017)

def landing():
    G.box('Entry landing closed core',(3.4,.95,.8),(0,0,.4),'stone_dark',.012)
    G.box('Entry threshold stone',(3.4,.95,.1),(0,0,.85),'sandstone',.01)

def wainscot():
    G.box('Wall lower wood panel',(4,.09,.92),(0,0,.46),'wood',.008)
    for x in (-1.94,-.97,0,.97,1.94):G.box('Panel upright',(.065,.035,.82),(x,.058,.46),'timber',.006)
    for z in (.065,.9):G.box('Panel horizontal rail',(4,.045,.1),(0,.07,z),'timber',.006)

def register_all():
    V.register()
    items=[
      ('foundation_strip_4m','4米条形承重地基',foundation_strip,['profile_extrude','array'],sockets(0,4,'foundation_strip')),
      ('support_pad','扶壁独立柱墩',S.support_pad,['profile_extrude'],[]),
      ('cloister_pad','回廊柱墩',lambda:S.support_pad(1.18,1.18,.3),['profile_extrude'],[]),
      ('corner_pad','角部宽地基',lambda:S.support_pad(2.0,2.0,.8),['profile_extrude'],[]),
      ('tower_foundation','钟楼整体承重基础',lambda:S.support_pad(4.9,4.9,.8),['profile_extrude'],[]),
      ('interior_column','5.4米室内立柱',interior_column,['spin','profile_extrude','SDF'],[dict(name='foot',position_blender=[0,0,0],normal_blender=[0,0,-1],kind='column_stack'),dict(name='capital',position_blender=[0,0,5.4],normal_blender=[0,0,1],kind='column_stack')]),
      ('stone_capital_sdf','SDF精修石柱头',capital,['SDF','vertices'],[dict(name='bottom',position_blender=[0,0,0],normal_blender=[0,0,-1],kind='capital'),dict(name='top',position_blender=[0,0,.24],normal_blender=[0,0,1],kind='capital')]),
      ('beam_4m','4米可接房梁',S.beam_4m,['mirror','profile_extrude'],sockets(0,4,'beam_4m')),
      ('roof_truss_8m','教堂三角木屋架',S.roof_truss_8m,['mirror','profile_extrude'],[]),
      ('chandelier','六灯吊灯',S.chandelier,['spin','curve_bevel','mirror'],[]),
      ('floor_lamp','独立落地灯',S.floor_lamp,['spin','profile_extrude'],[]),
      ('pew_2m','2米教堂长椅',F.pew_2m,['mirror','array','profile_extrude'],[]),
      ('pew_end','长椅端板',F.pew_end,['profile_extrude'],[]),
      ('pew_seat_1m','1米可接椅身',F.pew_seat_1m,['array','solidify'],sockets(0,1,'pew_seat')),
      ('lectern','斜面讲台',F.lectern,['mirror','profile_extrude'],[]),
      ('altar_table','木制讲桌',F.altar_table,['mirror','profile_extrude'],[]),
      ('wood_dais_2m','2米木制地台',F.wood_dais_2m,['array','mirror','solidify'],sockets(0,2,'dais_grid')+[dict(p,name='back' if i==0 else 'front') for i,p in enumerate(sockets(1,2,'dais_grid'))]),
      ('wood_stairs','3级木制台阶',F.wood_stairs,['profile_extrude','array'],[dict(name='upper',position_blender=[0,0,.48],normal_blender=[0,-1,0],kind='dais_stair')]),
      ('altar_back_panel','木制圣坛背板',F.altar_back_panel,['mirror','profile_extrude'],[]),
      ('door_hinged','可开启双扇橡木大门',doors.hinged_door,['CSG','profile_extrude'],[]),
      ('rear_portal','后殿贯通拱墙',rear_portal,['CSG','profile_extrude'],[]),
      ('apse_floor','后殿半圆地板',apse_floor,['vertices','profile_extrude'],[]),
      ('ceiling_4m','4米双坡木顶内衬',ceiling,['mirror','solidify'],sockets(1,4,'ceiling_4m')),
      ('entry_stairs','6级入口石阶',entry_stairs,['profile_extrude'],[]),
      ('entry_landing','入口石平台',landing,['profile_extrude'],[]),
      ('wainscot_4m','4米木制护墙板',wainscot,['array','profile_extrude'],sockets(0,4,'wainscot_4m')),
      ('window_reveal','高窗连续石返口',O.window_reveal,['profile_extrude','vertices'],[]),
      ('portal_reveal','后殿拱门连续石返口',O.portal_reveal,['profile_extrude','vertices'],[]),
      ('entry_reveal','入口拱门连续石返口',O.entry_reveal,['profile_extrude','vertices'],[]),
    ]
    for row in items:register(*row)

_old_inst=V.inst
def inst(key,xyz=(0,0,0),angle=0,parent=None,scale=None):
    r=_old_inst(key,xyz,angle,parent,scale);r['asset_id']=key;r['reusable_instance']=True
    return r
V.inst=inst

def delete_root(r):
    for ob in list(r.children_recursive)[::-1]:bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.objects.remove(r,do_unlink=True)

def trim_foundation_overlaps(parent):
    """Keep source modules intact; trim earlier assembly copies at later pad footprints.

    Shared top surfaces at Z=.8 caused black coplanar patches. Cropping the earlier
    slab with the new pad's footprint leaves a butt joint instead of stacked skins.
    """
    ids={'plinth_4','apse_plinth','foundation_strip_4m','corner_pad','support_pad','tower_foundation'}
    prior=[];scene=bpy.context.scene
    priority={'plinth_4':0,'apse_plinth':0,'foundation_strip_4m':1,'corner_pad':2,'support_pad':3,'tower_foundation':4}
    ordered=sorted([r for r in parent.children if r.get('asset_id') in ids],key=lambda r:(priority[r['asset_id']],r.name))
    for current in ordered:
        key=current.get('asset_id')
        if key not in ids:continue
        if key in ('corner_pad','support_pad','tower_foundation'):
            width,depth={'corner_pad':(2,2),'support_pad':(1.6,1.8),'tower_foundation':(4.9,4.9)}[key]
            center=current.matrix_world.translation
            xmin,xmax=center.x-width/2,center.x+width/2;ymin,ymax=center.y-depth/2,center.y+depth/2
            for earlier in prior:
                for ob in list(earlier.children_recursive):
                    if ob.type!='MESH':continue
                    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=ob.evaluated_get(dg)
                    points=[ob.matrix_world@Vector(p) for p in ev.bound_box]
                    if max(p.x for p in points)<=xmin+.0001 or min(p.x for p in points)>=xmax-.0001 or max(p.y for p in points)<=ymin+.0001 or min(p.y for p in points)>=ymax-.0001:continue
                    mesh=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg)
                    ob.data=mesh;ob.modifiers.clear()
                    G.COL=scene.collection;G.ROOT=None
                    tool=G.box('Foundation joint crop',(width,depth,2),(center.x,center.y,.4),None)
                    G.subtract(ob,tool);ob['assembly_joint_trim']=True
                    if not ob.data.polygons:bpy.data.objects.remove(ob,do_unlink=True)
        prior.append(current)
    V.repair_degenerate_evaluations(parent)

def interior(parent,cfg):
    r=V.root('InteriorLayout_A');r.parent=parent;r['layout_preset']='nave_5_rows'
    floor=cfg['floor_z']
    for x in (-3.3,3.3):
        for y in (-6,-2,2,6):inst('interior_column',(x,y,floor),parent=r)
        for y in (-4,0,4):inst('beam_4m',(x,y,6.46),90,r)
    for y in (-6,-2,2,6):inst('roof_truss_8m',(0,y,cfg['beam_bottom']),parent=r);inst('ceiling_4m',(0,y,cfg['beam_bottom']),parent=r)
    for x in (-3.70,3.70):
        for y in (-6,-2,2,6):inst('wainscot_4m',(x,y,floor),90 if x<0 else -90,r)
    for row in range(cfg['pew_rows']):
        y=cfg['pew_first_y']-row*cfg['pew_pitch']
        for sign in (-1,1):inst('pew_2m',(sign*(cfg['aisle_clear_width']/2+1),y,floor),180,r)
    for x in (-1,1):
        for y in (-7,-5):inst('wood_dais_2m',(x,y,floor),parent=r)
    inst('wood_stairs',(0,-4,floor),parent=r)
    inst('altar_table',(0,-7.1,floor+.48),parent=r)
    inst('lectern',(1.15,-5.6,floor+.48),parent=r)
    inst('altar_back_panel',(0,-9.8,floor),parent=r)
    for y in (-2,2):inst('chandelier',(0,y,6.3),parent=r)
    for x in (-2.7,2.7):
        for y in (-4.4,7):inst('floor_lamp',(x,y,floor),parent=r)
    return r

def chapel(cfg):
    r=V.chapel();r.name='Chapel_Open_Interior'
    for ob in list(r.children):
        key=ob.get('asset_id','')
        if key=='door_oak' or key=='stairs' or key=='facade_8' and ob.location.y<0:delete_root(ob)
    inst('rear_portal',(0,-8,.8),180,r);inst('apse_floor',(0,-8,.8),parent=r)
    inst('portal_reveal',(0,-8,.8),180,r);inst('entry_reveal',(0,8,.8),parent=r)
    for sx in (-1,1):
        for y in (-6,-2,2,6):inst('window_reveal',(sx*4.22,y,.8),-90 if sx==1 else 90,r)
    dr=inst('door_hinged',(0,8.82,.91),parent=r);doors.set_angle(dr,cfg['door_angle'])
    inst('entry_landing',(0,8.65,0),parent=r);inst('entry_stairs',(0,9.125,0),parent=r)
    for x in (-4.675,4.675):
        for y in (-6,-2,2,6):inst('foundation_strip_4m',(x,y,0),90,r)
    for x in (-4.2,4.2):
        for y in (-8,8):inst('corner_pad',(x,y,0),parent=r)
    for x in (-3.65,3.65):inst('support_pad',(x,8.54,0),parent=r)
    bpy.context.view_layer.update();trim_foundation_overlaps(r)
    inside=interior(r,cfg)
    return r,inside,dr

def exterior_fixes():
    tower=V.tower();inst('tower_foundation',(0,0,0),parent=tower)
    bpy.context.view_layer.update();trim_foundation_overlaps(tower)
    court=V.courtyard()
    for ob in list(court.children):
        if ob.get('asset_id') in ('column','arcade','roof_cloister_4'):ob.location.z+=.25
    for x in (-10.65,-7.35):
        for y in (-2,2,6,10):inst('cloister_pad',(x,y,0),parent=court)
    return tower,court

def light_interiors(scene,inside,cfg):
    bpy.context.view_layer.update()
    for ob in inside.children_recursive:
        if ob.get('socket_kind')!='light_point':continue
        lamp=bpy.data.lights.new('Warm lamp / '+ob.name,'POINT')
        lamp.energy=cfg['chandelier_energy'] if 'Chandelier' in ob.name else cfg['floor_lamp_energy']
        lamp.color=M.light_rgb('window_glow',(1,.72,.38));lamp.shadow_soft_size=.14
        lo=bpy.data.objects.new('LIGHT / '+ob.name,lamp);scene.collection.objects.link(lo);lo.location=ob.matrix_world.translation
    # Broad physical window-area sources give readable bounced light in roofed room.
    for x in (.35,7.65):
        for y in (-4,4):
            d=bpy.data.lights.new('Clerestory daylight','AREA');d.energy=260;d.shape='RECTANGLE';d.size=1;d.size_y=1.6;d.color=M.light_rgb('ambient',(0.7,.8,1))
            ob=bpy.data.objects.new(d.name,d);scene.collection.objects.link(ob);ob.location=(x,y,4.6);ob.rotation_euler=(Vector((4,y,1.4))-ob.location).to_track_quat('-Z','Y').to_euler()
    for y in (-4,3):
        d=bpy.data.lights.new('Interior soft bounce','AREA');d.energy=450;d.shape='DISK';d.size=5;d.color=M.light_rgb('sun',(1,.9,.7))
        ob=bpy.data.objects.new(d.name,d);scene.collection.objects.link(ob);ob.location=(4,y,5.8)

def camera(scene,pos,target,path,scale=20,res=1100,perspective=False):
    B.camera(scene,target,pos,scale,res);scene.render.resolution_y=int(res*.75)
    scene.camera.name='ABY3_VIEW_'+Path(path).stem
    scene['camera_'+Path(path).stem]=scene.camera.name
    if perspective:scene.camera.data.type='PERSP';scene.camera.data.lens=22
    render_scene(scene,path)

def reuse_demo(out,res):
    scene=V.scene('ABY3_Reuse_Examples');M.light_scene(scene)
    root=V.root('InteriorLayout_B_Reusable')
    # Four metre bench assembled from 1m center modules and separate end panels.
    for x in (-1.5,-.5,.5,1.5):inst('pew_seat_1m',(x,0,0),parent=root)
    for x in (-2,2):inst('pew_end',(x,0,0),parent=root)
    for x in (-2,0,2):
        for y in (3,5):inst('wood_dais_2m',(x,y,0),parent=root)
    inst('wood_stairs',(0,6,0),parent=root)
    for x in (-4,-.0,4):inst('beam_4m',(x,-3,5.56),parent=root)
    for x in (-6,-2,2,6):inst('interior_column',(x,-3,0),parent=root)
    G.COL=scene.collection;G.ROOT=None;G.box('Reuse display ground',(40,40,.1),(0,0,-.05),'ground')
    camera(scene,(13,17,13),(0,.7,2.5),out/'renders/reuse_examples.png',21,res)
    return scene,root

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--res',type=int,default=1200);ap.add_argument('--preset');ap.add_argument('--no-export',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    for p in ('glb','assemblies','renders'): (out/p).mkdir(exist_ok=True)
    cfg=dict(DEFAULT)
    if args.preset:cfg.update(json.loads(Path(args.preset).read_text(encoding='utf8')))
    if not 0<=cfg['door_angle']<=105:raise ValueError('Door opening must be 0..105 degrees.')
    if cfg['floor_z']!=.9 or cfg['column_height']!=5.4 or cfg['beam_bottom']!=6.3:raise ValueError('This nave uses fixed floor/column/beam datums .9 / 5.4 / 6.3m. Change the architectural recipes together to change these.')
    if not isinstance(cfg['pew_rows'],int) or not 1<=cfg['pew_rows']<=6:raise ValueError('Pew rows must be an integer 1..6.')
    if cfg['pew_pitch']<1.45 or cfg['pew_first_y']>6.1 or cfg['pew_first_y']-(cfg['pew_rows']-1)*cfg['pew_pitch']< -2.1:raise ValueError('Pew layout blocks the entry, sanctuary stair or row access.')
    if not 1.4<=cfg['aisle_clear_width']<=2.1:raise ValueError('Aisle width must be 1.4..2.1m for this fixed nave.')
    (out/'assembly_preset.json').write_text(json.dumps(cfg,indent=2),encoding='utf8')
    palette=M.use_game_palette()
    for key in ('wood_dark','bronze','window_glow'):
        M.COLORS[key]=palette['colors'][key];M.COLOR_KEYS[key]=key
    palette['material_mapping']=M.COLOR_KEYS
    (out/'palette_mapping.json').write_text(json.dumps(palette,ensure_ascii=False,indent=2),encoding='utf8')
    M.install(out);V.STYLE='game';V.LIB=V.scene('ABY3_Library');register_all()
    # Lamp glass can emit while its lit Principled base remains the palette value.
    for mat in bpy.data.materials:
        if mat.get('recipe_key')=='window_glow':
            p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            p.inputs['Emission Color'].default_value=p.inputs['Base Color'].default_value;p.inputs['Emission Strength'].default_value=1.3
            p.inputs['Alpha'].default_value=.58;mat.surface_render_method='DITHERED'
        if mat.get('recipe_key')=='bronze':
            p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Metallic'].default_value=.5;p.inputs['Roughness'].default_value=.65
    glass.configure()
    if not args.no_export:
        for key,r in V.ASSETS.items():
            (doors.export_hierarchy if key in ('door_hinged','chandelier','floor_lamp') else B.export_root)(r,out/'glb'/f'{key}.glb')
    demo=V.scene('ABY3_Courtyard');M.light_scene(demo)
    chapel_root,inside,dr=chapel(cfg);tower,court=exterior_fixes();light_interiors(demo,inside,cfg)
    G.COL=demo.collection;G.ROOT=None;G.box('Presentation ground Z=0',(200,200,.2),(0,0,-.1),'ground')
    assemblies=[chapel_root,inside,tower,court]
    if not args.no_export:
        for root in assemblies:B.export_root(root,out/'assemblies'/f'{root.name}.glb')
        doors.export_hierarchy(dr,out/'assemblies/Door_Open_105deg.glb')
    manifest=dict(version='abbey-v3',scope='architecture and explicitly requested reusable interiors; no vegetation',assets=V.MAN,new_asset_ids=NEW,placements=V.PLACEMENTS,assemblies=[dict(id=r.name,**B.evaluated_stats(r)) for r in assemblies],palette=M.COLORS,preset=cfg)
    manifest['sdf_capital_source']=pipeline.CAPITAL_LAST_EVIDENCE
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
    camera(demo,(29,39,25),(-.7,1,5.2),out/'renders/exterior_open.png',36,args.res)
    camera(demo,(4,7.35,2.4),(4,-5.8,2.7),out/'renders/interior_eye.png',20,args.res,True)
    camera(demo,(13,16,5.8),(7.7,4,1.5),out/'renders/foundation_close.png',12,args.res)
    # Cutaway retains original shared mesh data and hides only the near facade/roof in a separate scene.
    cut=V.scene('ABY3_Interior_Cutaway');M.light_scene(cut)
    hidden={'facade_8','rose_window','roof_nave_4','roof_end','roof_fascia','ridge_cross','dormer','chimney','ceiling_4m','wall_clerestory_4','window_clerestory','window_reveal','buttress','quoin_6','corbel'}
    removed=set()
    for r in chapel_root.children_recursive:
        if r.get('asset_id') in hidden and (r.get('asset_id') not in ('wall_clerestory_4','window_clerestory','window_reveal','buttress','quoin_6','corbel') or r.location.x>0 or r.location.y>7.9):removed.add(r);removed.update(r.children_recursive)
    for ob in [chapel_root]+list(chapel_root.children_recursive):
        if ob not in removed:cut.collection.objects.link(ob)
    G.COL=cut.collection;G.ROOT=None;G.box('Cutaway ground',(80,80,.1),(0,0,-.05),'ground')
    camera(cut,(24,24,20),(4,-.5,3),out/'renders/interior_cutaway.png',23,args.res)
    reuse,rr=reuse_demo(out,args.res)
    if not args.no_export:B.export_root(rr,out/'assemblies/InteriorLayout_B.glb')
    bpy.context.window.scene=demo
    B.camera(demo,(-.7,1,5.2),(29,39,25),36,args.res)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
    print('ABBEY V3 BUILD COMPLETE',out,flush=True)

if __name__=='__main__':main()
