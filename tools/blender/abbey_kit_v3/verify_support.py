"""Read-only geometric support audit of the saved v3 courtyard.

Run in factory-startup background Blender. A size/mtime-stable snapshot avoids
reading the producer's blend during a save. No source blend or scene is saved.
"""
import argparse,hashlib,json,math,shutil,sys,time
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

DEFAULT=Path('E:/wowgame/assets/models/abbey_kit_v3/build001/abbey_kit.blend')
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
parser=argparse.ArgumentParser()
parser.add_argument('--blend',default=str(DEFAULT))
parser.add_argument('--wait',type=float,default=1200)
cfg=parser.parse_args(args)
source=Path(cfg.blend)
destination=source.parent/'support_validation.json'
snapshot=Path('E:/wowgame/.local')/(source.parent.name+'_support_snapshot.blend')
snapshot.parent.mkdir(parents=True,exist_ok=True)
deadline=time.monotonic()+cfg.wait
stable_since=None
last=None
last_notice=0
while True:
    now=time.monotonic()
    if now>deadline:raise RuntimeError('Timed out waiting for a complete saved blend: '+str(source))
    if source.exists():
        st=source.stat()
        current=(st.st_size,st.st_mtime_ns)
        if current==last and current[0]>128:
            if stable_since is None:stable_since=now
            if now-stable_since>=8:
                shutil.copyfile(source,snapshot)
                after=source.stat()
                if current==(after.st_size,after.st_mtime_ns) and snapshot.stat().st_size==current[0]:break
                stable_since=None
        else:
            last=current
            stable_since=now
    if now-last_notice>25:
        print('SUPPORT_AUDIT_WAITING_FOR_STABLE_BLEND',str(source),flush=True)
        last_notice=now
    time.sleep(2)

digest=hashlib.sha256(snapshot.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(snapshot))
scene=bpy.data.scenes.get('ABY3_Courtyard')
if scene is None:raise RuntimeError('Saved blend has no ABY3_Courtyard scene')
bpy.context.window.scene=scene
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
TOL=.003

def owner(ob):
    current=ob
    while current:
        if current.get('asset_id'):
            return current
        current=current.parent
    return None

def category(key,name):
    value=(key+' '+name).lower()
    if any(w in value for w in ('foundation','plinth','pad','dais','landing','paving','floor','platform','threshold',
                               'mortar','grout','bearing','substrate','joint fill')):
        return 'foundation_or_floor'
    if 'ground' in value:return 'ground'
    if any(w in value for w in ('truss','beam','ceiling','column')):return 'structure'
    return 'other_geometry'

assets=[ob for ob in scene.objects if ob.get('asset_id') and ob.type=='EMPTY']
geometry=[]
by_owner={}
for ob in scene.objects:
    if ob.type not in ('MESH','CURVE','SURFACE','FONT'):continue
    evaluated=ob.evaluated_get(deps)
    mesh=evaluated.to_mesh()
    if mesh is None:continue
    if not mesh.polygons:
        evaluated.to_mesh_clear();continue
    mesh.calc_loop_triangles()
    matrix=evaluated.matrix_world.copy()
    verts=[matrix@v.co for v in mesh.vertices]
    polygons=[tuple(p.vertices) for p in mesh.polygons]
    tris=[tuple(t.vertices) for t in mesh.loop_triangles]
    lower=Vector(tuple(min(v[i] for v in verts) for i in range(3)))
    upper=Vector(tuple(max(v[i] for v in verts) for i in range(3)))
    asset=owner(ob)
    key=asset.get('asset_id','') if asset else ''
    record=dict(object=ob,name=ob.name,owner=asset,asset_id=key,verts=verts,tris=tris,
                min=lower,max=upper,bvh=BVHTree.FromPolygons(verts,polygons,all_triangles=False),
                category=category(key,ob.name))
    geometry.append(record)
    if asset:by_owner.setdefault(asset,[]).append(record)
    evaluated.to_mesh_clear()

def bounds(root):
    parts=by_owner.get(root,[])
    return (Vector(tuple(min(p['min'][i] for p in parts) for i in range(3))),
            Vector(tuple(max(p['max'][i] for p in parts) for i in range(3))))

def ray_hits(point,excluded,up=False):
    direction=Vector((0,0,1 if up else -1))
    # Small penetration is reported with a negative gap rather than mistaken
    # for empty air. Larger interpenetration is outside this support audit.
    origin=Vector(point)+Vector((0,0,-.035 if up else .055))
    hits=[]
    for part in geometry:
        if part['owner'] in excluded:continue
        low,high=part['min'],part['max']
        if origin.x<low.x-1e-6 or origin.x>high.x+1e-6 or origin.y<low.y-1e-6 or origin.y>high.y+1e-6:
            continue
        if up and high.z<origin.z or not up and low.z>origin.z:continue
        pos,normal,face,distance=part['bvh'].ray_cast(origin,direction,50)
        if pos is None:continue
        # A supporting upper face is hit from above; hanging mounts touch a
        # lower face from below. Exiting an enclosing wall is not support.
        if normal.z>(-.35) if up else normal.z<.35:continue
        gap=pos.z-point[2] if up else point[2]-pos.z
        hits.append(dict(object=part['name'],asset_id=part['asset_id'],category=part['category'],
                         surface_z=pos.z,gap=gap,distance=distance,normal=list(normal)))
    return sorted(hits,key=lambda hit:hit['distance'])

def inside_triangle_xy(point,triangle):
    x,y=point
    values=[]
    for a,b in zip(triangle,triangle[1:]+triangle[:1]):
        values.append((b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x))
    return min(values)>=-1e-8 or max(values)<=1e-8

def bottom_samples(root):
    lower,upper=bounds(root)
    z=lower.z
    triangles=[]
    points=[]
    mode='closed_bottom_faces'
    for part in by_owner[root]:
        if part['min'].z>z+.002:continue
        for indices in part['tris']:
            triangle=[part['verts'][i] for i in indices]
            if max(abs(v.z-z) for v in triangle)<.002:
                # Screw-generated caps can use either winding. A nonzero XY
                # triangle at the actual minimum Z is a bottom contact face
                # independently of its shading-normal orientation.
                if abs((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).z)>.00000001:
                    triangles.append(triangle)
                    points.extend(triangle)
    if not triangles:
        # Legacy v2 turned columns end in an uncapped perimeter ring. Report
        # that topology explicitly, and test the footprint of the *actual*
        # minimum-height rim rather than crashing or inventing a lower foot.
        xy=sorted(set((v.x,v.y) for part in by_owner[root] for v in part['verts'] if abs(v.z-z)<.002))
        if len(xy)<3:raise RuntimeError('Insufficient bottom rim in '+root.name)
        def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
        lo=[]
        for p in xy:
            while len(lo)>=2 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
            lo.append(p)
        hi=[]
        for p in reversed(xy):
            while len(hi)>=2 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
            hi.append(p)
        points=[Vector((x,y,z)) for x,y in lo[:-1]+hi[:-1]]
        center=sum(points,Vector())/len(points)
        triangles=[[center,a,b] for a,b in zip(points,points[1:]+points[:1])]
        mode='open_bottom_rim_footprint'
    xmin,xmax=min(p.x for p in points),max(p.x for p in points)
    ymin,ymax=min(p.y for p in points),max(p.y for p in points)
    targets=[((xmin+xmax)/2,(ymin+ymax)/2)]
    targets += [(xmin+(xmax-xmin)*a,ymin+(ymax-ymin)*b) for a,b in ((.15,.15),(.85,.15),(.85,.85),(.15,.85))]
    centers=[sum(triangle,Vector())/3 for triangle in triangles]
    samples=[]
    for x,y in targets:
        if any(inside_triangle_xy((x,y),tri) for tri in triangles):p=Vector((x,y,z))
        else:
            p=min(centers,key=lambda c:(c.x-x)**2+(c.y-y)**2).copy();p.z=z
        if not any((p-old).length<.00001 for old in samples):samples.append(p)
    # Disconnected bench feet can map two AABB targets to one foot. Add true
    # inset points from other foot triangles until at least five are checked.
    for tri,center in zip(triangles,centers):
        for p in [center]+[center*.6+v*.4 for v in tri]:
            if len(samples)>=5:break
            p=p.copy();p.z=z
            if not any((p-old).length<.00001 for old in samples):samples.append(p)
        if len(samples)>=5:break
    return z,samples,mode

def sample_support(root,point,up=False,strict_floor=False):
    hits=ray_hits(point,{root},up)
    hit=hits[0] if hits else None
    valid=hit is not None and -.056<=hit['gap']<=TOL
    reason=None
    if hit is None:reason='no supporting face'
    elif hit['gap']>TOL:reason='air gap exceeds 3 mm'
    elif hit['gap']<-.056:reason='penetration too deep for this support check'
    elif hit['category']=='ground' and point[2]>.03:
        valid=False;reason='presentation ground is not support for a raised base'
    elif strict_floor and hit['category']!='foundation_or_floor':
        valid=False;reason='base does not land on a foundation or floor module'
    return dict(point=list(point),pass_check=valid,reason=reason,hit=hit)

report=dict(source_blend=str(source),source_sha256=digest,source_size=last[0],
            scene=scene.name,tolerance_metres=TOL,evaluated_geometry_objects=len(geometry),
            method='evaluated world meshes; five true bottom-surface samples; own asset excluded from vertical BVH rays',
            bases=[],truss_column_contacts=[],beam_connections=[],hanging_mounts=[],door_hinges=[],failures=[])
mandatory={'buttress','column','interior_column'}
optional={'pew_2m','lectern','altar_table','floor_lamp','altar_back_panel','wood_dais_2m'}
for root in assets:
    key=root['asset_id']
    if key not in mandatory|optional:continue
    z,samples,mode=bottom_samples(root)
    tested=[sample_support(root,p,strict_floor=key in mandatory) for p in samples]
    entry=dict(asset=root.name,asset_id=key,bottom_z=z,contact_surface_mode=mode,sample_count=len(tested),
               pass_check=all(p['pass_check'] for p in tested),samples=tested)
    report['bases'].append(entry)
    if not entry['pass_check']:report['failures'].append(dict(check='base_support',asset=root.name,asset_id=key,
        failed_points=[p for p in tested if not p['pass_check']]))

columns=[r for r in assets if r['asset_id']=='interior_column']
beams=[r for r in assets if r['asset_id']=='beam_4m']
for root in assets:
    key=root['asset_id']
    if key=='roof_truss_8m':
        parts=[p for p in by_owner[root] if 'TieBeam' in p['name']]
        tie=parts[0]
        for column in columns:
            low,high=bounds(column)
            center=(low+high)/2
            if tie['min'].x-TOL<=center.x<=tie['max'].x+TOL and tie['min'].y-TOL<=center.y<=tie['max'].y+TOL:
                gap=tie['min'].z-high.z
                check=dict(truss=root.name,column=column.name,tie_bottom=tie['min'].z,column_top=high.z,
                           gap=gap,pass_check=abs(gap)<=TOL)
                report['truss_column_contacts'].append(check)
                if not check['pass_check']:report['failures'].append(dict(check='column_truss_contact',**check))
    elif key=='chandelier':
        low,high=bounds(root)
        mount=root.matrix_world@Vector((0,0,0))
        test=sample_support(root,mount,up=True)
        entry=dict(asset=root.name,actual_top=high.z,mount=list(mount),**test)
        report['hanging_mounts'].append(entry)
        if not test['pass_check']:report['failures'].append(dict(check='chandelier_mount',**entry))
    elif key=='door_hinged':
        angles=[]
        for hinge in root.children_recursive:
            if 'open_sign' in hinge:
                actual=math.degrees(hinge.rotation_euler.z)
                target=root['door_angle_degrees']*hinge['open_sign']
                angles.append(dict(hinge=hinge.name,actual_degrees=actual,expected_degrees=target,pass_check=abs(actual-target)<.001))
        entry=dict(asset=root.name,hinges=angles,pass_check=len(angles)==2 and all(a['pass_check'] for a in angles))
        report['door_hinges'].append(entry)
        if not entry['pass_check']:report['failures'].append(dict(check='door_hinge_angle',**entry))

endpoints=[]
for root in beams:
    timber=next(p for p in by_owner[root] if 'MainTimber' in p['name'])
    for sign in (-1,1):
        point=root.matrix_world@Vector((sign*2,0,0))
        endpoints.append((root,sign,point,timber['min'].z))
for root,sign,point,z in endpoints:
    others=[(r,s,p) for r,s,p,_ in endpoints if r!=root]
    near=min(others,key=lambda t:(t[2]-point).length) if others else None
    if near and (near[2]-point).length<=TOL:
        entry=dict(beam=root.name,end=sign,point=list(point),other_beam=near[0].name,
                   distance=(near[2]-point).length,pass_check=True)
    else:
        support=sample_support(root,Vector((point.x,point.y,z)))
        entry=dict(beam=root.name,end=sign,point=list(point),terminal_support=support,pass_check=support['pass_check'])
    report['beam_connections'].append(entry)
    if not entry['pass_check']:report['failures'].append(dict(check='beam_connection',**entry))

report['summary']=dict(base_assets=len(report['bases']),base_points=sum(b['sample_count'] for b in report['bases']),
                       truss_column_contacts=len(report['truss_column_contacts']),beam_ends=len(report['beam_connections']),
                       hanging_mounts=len(report['hanging_mounts']),door_sets=len(report['door_hinges']),failures=len(report['failures']))
report['pass_check']=not report['failures']
destination.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print('SUPPORT_VALIDATION',json.dumps(report['summary']),str(destination),flush=True)
for failure in report['failures']:
    print('SUPPORT_FAILURE',json.dumps(failure,ensure_ascii=False),flush=True)
