"""Author camera clearance revisions for the Blender sea-temple source.
Original Unity files remain reference-only. Meshes are imported into Blender
and exported there; this preparer does not produce a fake DCC export.
Geometry helpers derive from tools/sanctum_unity/prepare_spatial.py.
"""
import json, math, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / '.local/sanctum_unity_workshop'
sys.path.insert(0, str(WORK / 'python_libs'))
from shapely.geometry import Polygon, Point, box
from shapely.ops import triangulate, unary_union
from shapely.geometry.polygon import orient
import numpy as np
import shapely
OUT=ROOT/'assets/models/sanctum_blender_ruin'
plan=json.loads((ROOT/'assets/models/sanctum_unity_v2/layout.json').read_text('utf-8'))
plan.update(version='sanctum-blender-camera-clearance-20261012',status='whitebox-camera-revision')
floors=plan['floors']
by={f['id']:f for f in floors}
buried_ids={f['id'] for f in floors if f.get('buried')}
# Design points are in Godot metres. Main encounter order and heights remain.
by['approach']['polygon']=[[92,264],[116,264],[116,228],[92,228]]
by['gatehouse']['polygon']=[[90,228],[118,228],[118,204],[90,204]]
by['cloister']['polygon']=[[16,202],[82,202],[82,170],[62,170],[62,180],[42,180],[42,162],[46,162],[46,152],[16,152]]
by['cloister']['roof_level']=32.8
by['mortuary'].update(polygon=[[58,124],[58,102],[100,102],[100,114],[88,114],[88,138],[58,138]],slope={'axis':'descent','low':8,'high':18,'flat_landing_z':114,'blend_end_z':124})
by['cellar']['polygon']=[[100,94],[118,94],[126,106],[126,139],[115,145],[93,145],[86,130],[100,118]]
by['sacristy']['polygon']=[[154,100],[190,100],[190,78],[178,64],[160,64],[154,78],[146,78],[146,90],[154,90]]
by['bell_stair'].update(polygon=[[50,94],[70,94],[70,88],[80,88],[80,80],[70,80],[70,52],[50,52]],slope={'axis':'z','a':56,'b':80,'low':32,'high':24})
by['bell_bridge']['polygon']=[[50,56],[70,52],[52,38],[43,47]]
plan['route'][4]['points']=[[104,50],[104,84],[78,84],[64,84],[64,54],[48,46],[36,32]]
# Side rooms keep their purpose and a single portal, with enough orbit room.
revisions={
 'side_gate_rest':([62,208,86,232],[86,214,90,226],[[104,219],[88,220],[74,220]]),
 'side_tools':([34,210,58,234],[40,202,52,210],[[46,192],[46,206],[46,222]]),
 'side_hermit':([-16,124,12,152],[12,132,20,144],[[30,138],[16,138],[-2,138]]),
 'side_ledger':([202,118,230,148],[198,127,202,139],[[184,134],[200,133],[216,133]]),
 'side_dorm':([196,74,224,102],[190,82,196,94],[[172,88],[193,88],[210,88]]),
 'side_chapel':([60,100,84,126],[84,106,88,118],[[104,118],[104,112],[86,112],[72,113]]),
 'votive':([140,170,168,198],[132,178,140,190],[[120,184],[136,184],[154,184]])}
def rect(q):return [[q[0],q[1]],[q[2],q[1]],[q[2],q[3]],[q[0],q[3]]]
for id,(area,link,route) in revisions.items():
 center=[(area[0]+area[2])/2,(area[1]+area[3])/2]
 by[id].update(polygon=rect(area),label=center)
 by[id+'_link'].update(polygon=rect(link))
 for room in plan['side_rooms']:
  if room['id']==id:room.update(center=center,points=route)
for f in floors:
 if not f.get('buried') and (f['kind'] in ['interior','optional'] or '_link' in f['id']):f['ceiling']=14.8
plan['ground']['entry_cut']=[[55,123],[58,123],[58,118],[89,118],[89,139],[55,139]]
plan['ground']['loading_tunnel_roof_level']=24.8
plan['camera_design']={'distance':16,'pitch_range':[-.4,-.65],'main_and_branch_min_target':8,'side_center_min_target':10,'physical_collisions_retained':True,'note':'Thresholds are sampled regression criteria, not human acceptance. No global camera change.'}
polys = {f['id']:orient(Polygon(f['polygon']),1) for f in floors}
assert all(p.is_valid for p in polys.values())
def height(f,x,z):
    s=f.get('slope')
    if not s:return f['level']
    if s['axis']=='descent':
        original=18-4*max(0,min(1,(x-64)/8))-6*max(0,min(1,(130-z)/16))
        blend=max(0,min(1,(z-s['flat_landing_z'])/(s['blend_end_z']-s['flat_landing_z'])))
        return 8+(original-8)*blend
    t=max(0,min(1,((x if s['axis']=='x' else z)-s['a'])/(s['b']-s['a'])))
    rise=(s['high']-s['low'])*t
    if 'flatten_after_x' in s:rise*=max(0,min(1,(s['flatten_after_x']-x)/(s['flatten_after_x']-s['blend_from_x'])))
    return s['low']+rise
def floor_at(x,z,phase):
    fs=[f for f in floors if f['kind']!='blocked' and polys[f['id']].buffer(.02).covers(Point(x,z))]
    match=[f for f in fs if f['phase']==phase]
    assert fs,(x,z,phase)
    return height((match or fs)[0],x,z)
for r in plan['route']+plan['side_rooms']:
    r['points3']=[[x,round(floor_at(x,z,r['phase']),4),z] for x,z in r['points']]
for p in plan['pulls']:
    x,z=p['point'];p['level']=floor_at(x,z,p['phase'])
for g in plan['gates']:
    x,z=g['point'];g['level']=floor_at(x,z,2 if g['flag'].endswith('root') else 3 if g['flag'].endswith('lake') else 4)

meshes=[]
STONE=[.62,.60,.53,1];TRIM=[.74,.71,.61,1];FLOOR=[.52,.52,.48,1];WOOD=[.37,.28,.20,1];ROOF=[.24,.29,.34,1];GREEN=[.36,.43,.28,1]
def mesh(name,group,color):
    m=dict(name=name,group=group,color=color,positions=[],triangles=[]);meshes.append(m);return m
def tri(m,a,b,c):
    i=len(m['positions'])//3;m['positions'].extend(a+b+c);m['triangles'].extend([i,i+1,i+2])
def quad(m,a,b,c,d):tri(m,a,b,c);tri(m,a,c,d)
def cuboid(name,group,c,size,color,yaw=0):
    m=mesh(name,group,color);x,y,z=c;w,h,d=[v/2 for v in size];co,si=math.cos(yaw),math.sin(yaw)
    vs=[]
    for yy in [-h,h]:
        for xx,zz in [(-w,-d),(w,-d),(w,d),(-w,d)]:vs.append([x+xx*co-zz*si,y+yy,z+xx*si+zz*co])
    for ids in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:quad(m,*[vs[i] for i in reversed(ids)])

def portal_arch(name,x,y,z,width,yaw,spring=3.4,rise=1.2):
    co,si=math.cos(yaw),math.sin(yaw)
    def world(p):return [x+p[0]*co-p[2]*si,y+p[1],z+p[0]*si+p[2]*co]
    for side in [-1,1]:cuboid(name+'_Pier','walls',world([side*(width/2+.4),spring/2,0]),[.8,spring,1.3],TRIM,yaw)
    m=mesh(name+'_Voussoirs','walls',TRIM)
    for i in range(13):
        a=i*math.pi/13+.004;b=(i+1)*math.pi/13-.004
        ring=[[math.cos(a)*width/2,spring+math.sin(a)*rise], [math.cos(b)*width/2,spring+math.sin(b)*rise],
              [math.cos(b)*(width/2+.7),spring+math.sin(b)*(rise+.6)], [math.cos(a)*(width/2+.7),spring+math.sin(a)*(rise+.6)]]
        front=[world([p[0],p[1],-.65]) for p in ring];back=[world([p[0],p[1],.65]) for p in ring]
        quad(m,*front);quad(m,*reversed(back))
        for j in range(4):k=(j+1)%4;quad(m,front[k],front[j],back[j],back[k])
def slab(f,poly,roof=False):
    m=mesh(f['id']+('_roof' if roof else '_floor'),'buried_roofs' if roof and f.get('buried') else 'roofs' if roof else 'floor',ROOF if roof else [.43,.43,.39,1] if f.get('buried') else GREEN if f['id']=='root_garden' else FLOOR)
    # Subdivide slopes at 1m so height-function clamp transitions remain exact.
    pieces=[]
    if 'slope' in f:
        minx,minz,maxx,maxz=poly.bounds
        for x in range(math.floor(minx),math.ceil(maxx)):
            for z in range(math.floor(minz),math.ceil(maxz)):
                part=poly.intersection(box(x,z,x+1,z+1))
                if part.area>1e-5:pieces.extend([part] if part.geom_type=='Polygon' else [p for p in part.geoms if p.geom_type=='Polygon'])
    else:pieces=[poly]
    ceiling=f.get('ceiling',16 if f['id'] in ['nave','apse'] else 14.8)
    def vertex(x,z):return [x, f.get('roof_level',height(f,x,z)+ceiling) if roof else height(f,x,z),z]
    for part in pieces:
        for t in triangulate(part):
            if not part.covers(t.representative_point()):continue
            pts=list(t.exterior.coords)[:3];v=[vertex(*p) for p in pts]
            # Unity normals are recalculated from outward winding.
            tri(m,v[2],v[1],v[0])
            if roof:tri(m,[v[0][0],v[0][1]-.3,v[0][2]],[v[1][0],v[1][1]-.3,v[1][2]],[v[2][0],v[2][1]-.3,v[2][2]])
            else:tri(m,*[[p[0],p[1]-.35,p[2]] for p in v])
    # Real thickness on visible exterior edges.
    pts=list(poly.exterior.coords)
    for a,b in zip(pts,pts[1:]):
        va,vb=vertex(*a),vertex(*b);da=[va[0],va[1]-.35,va[2]];db=[vb[0],vb[1]-.35,vb[2]]
        quad(m,va,vb,db,da)

for f in floors:
    poly=polys[f['id']]
    slab(f,poly)
    indoor=f['kind'] in ['interior','underground','nave','optional','colonnade'] or f['id']=='apse' or f['id'].startswith('side_') or f['id']=='votive_link'
    if indoor:slab(f,poly.intersection(box(0,0,200,118)) if f['id']=='mortuary' else poly,True)
    wh=16 if f['id'] in ['nave','apse'] else 6 if f['kind']=='underground' else 7 if indoor else 1.4 if f['kind'] in ['bridge','final'] else 5
    if f['kind']=='blocked':wh=2.5 if f['id']=='broken_stair' else .8
    boundary=mesh(f['id']+'_boundary','walls',[.43,.45,.41,1] if f.get('buried') else STONE)
    infill=mesh(f['id']+'_HighInfill','walls',STONE) if f['id'] in ['nave','apse'] else None
    # Test outside every boundary sample against compatible adjacent surfaces.
    # Collinear continuous spans are merged, but ramp wall bases follow height.
    pts=list(poly.exterior.coords)
    for a,b in zip(pts,pts[1:]):
        dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz);n=max(1,math.ceil(length/.4));nx,nz=dz/length,-dx/length
        spans=[];start=None
        for k in range(n):
            t=(k+.5)/n;x,z=a[0]+dx*t,a[1]+dz*t;fy=height(f,x,z)
            open_edge=False
            if f['kind']!='blocked':
                q=Point(x+nx*.55,z+nz*.55)
                for other in floors:
                    if other is f or other['kind']=='blocked':continue
                    if polys[other['id']].buffer(.03).covers(q) and abs(height(other,x,z)-fy)<.22:
                        open_edge=True
                        if infill is not None:
                            own_top=fy+16
                            other_indoor=other['kind'] in ['interior','underground','nave','optional'] or other['id']=='apse' or other['id'].startswith('side_')
                            other_top=other.get('roof_level',height(other,x,z)+(16 if other['id'] in ['nave','apse'] else 7)) if other_indoor else fy+8.5
                            if other_top<own_top-.1:
                                xa,za=a[0]+dx*k/n,a[1]+dz*k/n;xb,zb=a[0]+dx*(k+1)/n,a[1]+dz*(k+1)/n
                                va=[xa,other_top,za];vb=[xb,other_top,zb];ua=[xa,own_top,za];ub=[xb,own_top,zb]
                                quad(infill,vb,ub,ua,va)
                                quad(infill,[xa+nx*.65,other_top,za+nz*.65],[xa+nx*.65,own_top,za+nz*.65],[xb+nx*.65,own_top,zb+nz*.65],[xb+nx*.65,other_top,zb+nz*.65])
                        break
            if not open_edge and start is None:start=k/n
            if open_edge and start is not None:spans.append((start,k/n));start=None
        if start is not None:spans.append((start,1))
        if 'slope' in f:
            # Clamp and blended ramp heights are nonlinear. Keep wall feet and
            # ceilings on the same subdivided floor instead of spanning a gap.
            refined=[]
            for ta,tb in spans:
                count=max(1,math.ceil((tb-ta)*length/.5))
                refined.extend([(ta+(tb-ta)*i/count,ta+(tb-ta)*(i+1)/count) for i in range(count)])
            spans=refined
        for ta,tb in spans:
            aa=(a[0]+dx*ta,a[1]+dz*ta);bb=(a[0]+dx*tb,a[1]+dz*tb)
            # Place walls entirely outside walkable footprint.
            va=[aa[0],height(f,*aa),aa[1]];vb=[bb[0],height(f,*bb),bb[1]]
            wh=16 if f['id'] in ['nave','apse'] else f.get('ceiling',14.8) if indoor else 1.4 if f['kind'] in ['bridge','final','ramp'] else 5
            if f['id']=='cloister':wh=5
            if f.get('buried'):wh=f['roof_level']-min(height(f,*aa),height(f,*bb))
            if f['kind']=='blocked':wh=2.5 if f['id']=='broken_stair' else .8
            # The arcade faces the herb courtyard through low parapets and
            # piers. Its outer retaining wall stays closed against the hillside.
            if f['id']=='cloister' and ((a[1]==180 and b[1]==180) or (a[0]==42 and b[0]==42) or (a[0]==62 and b[0]==62)):
                wh=1.1
            if f['id']=='loading_ramp' and max(aa[0],bb[0])<=132.01:wh=24.8-min(va[1],vb[1])
            voa=[va[0]+nx*.65,va[1],va[2]+nz*.65];vob=[vb[0]+nx*.65,vb[1],vb[2]+nz*.65]
            up=lambda v:[v[0],f['roof_level'] if f.get('buried') else v[1]+wh,v[2]]
            quad(boundary,vb,up(vb),up(va),va);quad(boundary,voa,up(voa),up(vob),vob)
            quad(boundary,up(vb),up(vob),up(voa),up(va));quad(boundary,va,up(va),up(voa),voa);quad(boundary,vob,up(vob),up(vb),vb)
            # Retaining masonry supports outdoor terraces; upper nave walls sit
            # on the cellar roof band, leaving the lower walkable storey intact.
            if f['kind'] not in ['bridge','stair','ramp','blocked']:
                base=22 if f['phase']==3 else 12
                if f['phase']==4:base=12
                quad(boundary,[voa[0],base,voa[2]],voa,vob,[vob[0],base,vob[2]])
                # Close the foundation volume at corners, including the inner
                # face; an exterior sheet leaves the masonry hollow at ground.
                quad(boundary,[va[0],base,va[2]],[vb[0],base,vb[2]],vb,va)
                quad(boundary,[va[0],base,va[2]],va,voa,[voa[0],base,voa[2]])
                quad(boundary,[vob[0],base,vob[2]],vob,vb,[vb[0],base,vb[2]])

# Coherent architectural vocabulary: courtyard arcade, nave piers, tower silhouette.
for room in plan['side_rooms']:
    link=next((f for f in floors if f['id']==room['id']+'_link'),None)
    if not link:continue
    minx,minz,maxx,maxz=polys[link['id']].bounds
    cx,cz=(minx+maxx)/2,(minz+maxz)/2
    horizontal=room['id'] not in ['side_tools','side_crypt','side_brew']
    top=12.8 if room['id'] in buried_ids else 14.8
    door_height=11.8 if room['id'] in buried_ids else 13.2
    header=top-door_height
    cuboid(room['id']+'_DoorHeader','walls',[cx,room['level']+door_height+header/2,cz],[1,header,maxz-minz] if horizontal else [maxx-minx,header,1],TRIM)
# Supports sit on the outside edge; turn pads and lateral camera space stay clear.
for x in [20,30,62,78]:cuboid('SouthCloisterPier','walls',[x,25.3,201.5],[.85,14.6,.85],TRIM)
for z in [158,170,182,194]:cuboid('WestCloisterPier','walls',[16.5,25.3,z],[.85,14.6,.85],TRIM)
for z in [102,116,130]:
    for x in [91,117]:
        cuboid('NavePier','walls',[x,31,z],[1.4,14,1.4],TRIM)
# Apothecary beds, explicitly outside the route.
for x in [43,51]:
    for z in [170,178]:cuboid('HerbBed','props',[x,18.7,z],[5,1.4,5],WOOD)
for x in [24,48]:cuboid('BellTowerPier','walls',[x,42,18],[2.2,20,2.2],STONE)
cuboid('BellTowerLintel','walls',[36,50,18],[28,1.5,3],TRIM)
cuboid('BellTowerCap','roofs',[36,53,18],[31,1.5,8],ROOF)
# Simple pitched silhouette over the long nave (ceiling below remains real).
ridge=mesh('NavePitchedRoof','roofs',ROOF)
quad(ridge,[86,40,142],[104,45,142],[104,45,96],[86,40,96])
quad(ridge,[104,45,142],[122,40,142],[122,40,96],[104,45,96])

# A real surface with localized excavations. BrushTerrain retains the identical
# heights for scene tools and vegetation, while this saved Unity mesh has portal
# cutouts that a single unbroken heightfield cannot represent.
spec=plan['ground'];res=spec['resolution'];cell=spec['cell_size'];ox,oz=spec['origin']
xx,zz=np.meshgrid(np.arange(res+1)*cell+ox,np.arange(res+1)*cell+oz)
px,pz=xx.ravel(),zz.ravel();sample_points=shapely.points(px,pz)
def heights(f):
    if 'slope' not in f:return np.full(px.shape,f['level'],dtype=float)
    s=f['slope']
    if s['axis']=='descent':
        original=18-4*np.clip((px-64)/8,0,1)-6*np.clip((130-pz)/16,0,1)
        blend=np.clip((pz-s['flat_landing_z'])/(s['blend_end_z']-s['flat_landing_z']),0,1)
        return 8+(original-8)*blend
    t=np.clip(((px if s['axis']=='x' else pz)-s['a'])/(s['b']-s['a']),0,1)
    rise=(s['high']-s['low'])*t
    if 'flatten_after_x' in s:rise*=np.clip((s['flatten_after_x']-px)/(s['flatten_after_x']-s['blend_from_x']),0,1)
    return s['low']+rise
grades=[f for f in floors if not f.get('buried') and f['id']!='loading_ramp' and f['kind']!='bridge']
distance=np.array([shapely.distance(polys[f['id']],sample_points) for f in grades])
grade_heights=np.array([heights(f)-spec['floor_offset'] for f in grades])
weights=1/np.maximum(distance,1.0)**4
land=np.sum(weights*grade_heights,axis=0)/np.sum(weights,axis=0)
nearest=np.min(distance,axis=0)
land+=(np.sin(px*.051)*np.cos(pz*.047)*1.1+np.sin((px+pz)*.023)*.6)*np.clip((nearest-3)/20,0,1)
land+=np.maximum(0,px-235)*.18+np.maximum(0,10-pz)*.22
# Exact architectural pads remove air beneath terraces and keep earth below
# floors. Underground ceilings get a minimum layer of soil, never an exposed box.
for f in floors:
    if not f.get('buried'):continue
    d=shapely.distance(polys[f['id']],sample_points)
    blend=np.clip(1-d/10,0,1);blend=blend*blend*(3-2*blend)
    target=f['roof_level']+spec['min_cover']
    land=np.maximum(land,land+(target-land)*blend)
loading_cover=polys['loading_ramp'].intersection(box(120,110,132,150))
d=shapely.distance(loading_cover,sample_points)
blend=np.clip(1-d/5,0,1);blend=blend*blend*(3-2*blend)
target=24.8+spec['min_cover']
land=np.maximum(land,land+(target-land)*blend)
for d,h in zip(distance,grade_heights):land=np.where(d<1e-5,h,land)
land=land.reshape((res+1,res+1))
entry_cut=Polygon(spec['entry_cut'])
exit_cut=polys['loading_ramp'].intersection(box(131.8,115,154,153)).buffer(.35,join_style=2)
cuts=unary_union([entry_cut,exit_cut])
plan['ground']['exit_cut']=list(exit_cut.exterior.coords)[:-1]
def ground_y(x,z):
    gx=(x-ox)/cell;gz=(z-oz)/cell;ix=max(0,min(res-1,int(gx)));iz=max(0,min(res-1,int(gz)));fx=gx-ix;fz=gz-iz
    return float((land[iz,ix]*(1-fx)+land[iz,ix+1]*fx)*(1-fz)+(land[iz+1,ix]*(1-fx)+land[iz+1,ix+1]*fx)*fz)
terrain=mesh('MonasteryHillside','terrain',[.47,.60,.36,1])
for iz in range(res):
    for ix in range(res):
        x,z=ox+ix*cell,oz+iz*cell
        square=box(x,z,x+cell,z+cell)
        if square.intersects(cuts):
            part=square.difference(cuts)
            pieces=[part] if part.geom_type=='Polygon' else [p for p in getattr(part,'geoms',[]) if p.geom_type=='Polygon']
            for p in pieces:
                for t in triangulate(p):
                    if p.covers(t.representative_point()):
                        v=[[a,ground_y(a,b),b] for a,b in list(t.exterior.coords)[:3]];tri(terrain,v[2],v[1],v[0])
        else:
            a=[x,float(land[iz,ix]),z];b=[x+cell,float(land[iz,ix+1]),z];c=[x+cell,float(land[iz+1,ix+1]),z+cell];d=[x,float(land[iz+1,ix]),z+cell]
            quad(terrain,a,d,c,b)
# Close the exposed cut edges above the vault or down to the outside paving.
# A heightfield alone is a sheet; these faces make the portal rim a soil volume.
def cut_bottom(x,z):
    p=Point(x,z)
    for f in floors:
        if f.get('buried') and polys[f['id']].buffer(.01).covers(p):
            if f['id']=='mortuary' and z>118.01:return height(f,x,z)-.4
            return f['roof_level']-.32
    if x<=132.01 and polys['loading_ramp'].buffer(.01).covers(p):
        return 24.48
    candidates=[f for f in floors if polys[f['id']].buffer(.5).covers(p)]
    return min([height(f,x,z)-.4 for f in candidates] or [ground_y(x,z)-.5])
for excavation in [entry_cut,exit_cut]:
    rim=list(orient(excavation,1).exterior.coords)
    for a,b in zip(rim,rim[1:]):
        count=max(1,math.ceil(math.dist(a,b)/.5))
        for i in range(count):
            aa=[a[j]+(b[j]-a[j])*i/count for j in range(2)]
            bb=[a[j]+(b[j]-a[j])*(i+1)/count for j in range(2)]
            ha,hb=ground_y(*aa),ground_y(*bb)
            ba,bbh=min(ha,cut_bottom(*aa)),min(hb,cut_bottom(*bb))
            if max(ha-ba,hb-bbh)<.001:continue
            quad(terrain,[bb[0],bbh,bb[1]],[bb[0],hb,bb[1]],[aa[0],ha,aa[1]],[aa[0],ba,aa[1]])
# Loading tunnel roof stops before its open excavation; the exit arch frames
# the first view of the occupied service court.
loading=by['loading_ramp'].copy();loading.update(id='loading_tunnel',buried=True,ceiling=16.8,roof_level=24.8)
slab(loading,polys['loading_ramp'].intersection(box(120,110,132,150)),True)
portal_arch('MortuaryPortal',73,8.75,118,28,0,8.6,2.0)
portal_arch('LoadingPortal',132,11,131,18,math.pi/2,11.0,1.5)
ground_export={'spec':spec,'heights':[round(float(v),5) for v in land.ravel()]}


meshes=[m for m in meshes if m['triangles']]
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),'utf-8')
(OUT/'ground.json').write_text(json.dumps(ground_export,separators=(',',':')),'utf-8')
(OUT/'whitebox_mesh_input.json').write_text(json.dumps({'version':plan['version'],'meshes':meshes},separators=(',',':')),'utf-8')
print(json.dumps({'floors':len(floors),'side_rooms':len(plan['side_rooms']),'meshes':len(meshes)},indent=2))
