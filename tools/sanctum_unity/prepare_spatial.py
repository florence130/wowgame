"""Author the approved monastery footprint, including optional single-entry rooms.

The output is mesh input for Unity, not a pretend Unity export. Unity saves real
Mesh assets and a scene, then the separate exporter reads those actual meshes.
"""
import json, math, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.local/sanctum_unity_workshop'
sys.path.insert(0, str(WORK / 'python_libs'))
from shapely.geometry import Polygon, Point, box
from shapely.ops import triangulate, unary_union
from shapely.geometry.polygon import orient
import numpy as np
import shapely

plan = json.loads((ROOT/'tools/sanctum_unity/spatial_proposal.json').read_text('utf-8'))
plan.update(version='sanctum-mmo-clearance-dressing-20261011', status='mmo-camera-theme-review', bounds=[0,8,220,248])
floors = plan['floors']
# Idempotent: retain the approved main architecture; replace only this addition.
floors[:] = [f for f in floors if not f['id'].startswith('side_')]
by = {f['id']: f for f in floors}
by['court']['polygon'] = [[76,204],[124,204],[132,196],[132,173],[124,164],[84,164],[76,172],[76,179],[84,179],[84,187],[76,187]]
by['garden_ramp'].update(polygon=[[74,179],[84,179],[84,187],[74,187]], slope={'axis':'x','a':74,'b':84,'low':18,'high':20})
by['mortuary'].update(polygon=[[58,124],[66,124],[66,109],[76,102],[92,102],[100,110],[100,114],[80,114],[80,138],[58,138]], slope={'axis':'descent','low':8,'high':18}, level=8)
by['cellar'].update(level=8,polygon=[[96,108],[118,108],[126,117],[126,139],[115,145],[93,145],[86,130],[100,118]])
by['loading_ramp'].update(polygon=[[126,122],[138,122],[150,132],[150,147],[143,150],[130,141],[126,134]], slope={'axis':'x','a':126,'b':150,'low':8,'high':20})
by['loading_landing']['polygon'] = [[150,132],[156,132],[156,147],[150,147]]
by['east_stair']['slope'] = {'axis':'z','a':100,'b':112,'low':24,'high':20}
by['bell_stair'].update(polygon=[[56,94],[70,94],[70,88],[80,88],[80,80],[70,80],[70,58],[56,58]], slope={'axis':'z','a':66,'b':80,'low':32,'high':24})
for gate in plan['gates']:
    if gate['flag']=='sanctum_final_open':gate['point']=[72,84]
    if gate['flag']=='sanctum_ember_lake':gate['point']=[173,105]
    if gate['flag']=='sanctum_ember_root':gate.update(point=[64,131],width=14)
plan['route'][2]['points'] = [[38,134],[64,130],[72,130],[72,115],[72,112],[88,112],[106,112],[106,126],[124,126],[126,126],[145,138],[151,142],[172,134]]
for pull in plan['pulls']:
    if pull['id']=='P7':
        pull.update(point=[154,140],note='坡顶平整装卸前平台；坡面与洞口留空，清理这组后再进入莱克服务院。')
rooms = [
 ('gate_rest','门房休息间',0,20,[80,214,90,226],[90,218,93,222],'empty',[[104,219],[94,220],[85,220]]),
 ('tools','园丁工具间',1,18,[40,202,52,214],[44,198,48,202],'tools',[[46,192],[46,200],[46,208]]),
 ('hermit','隐修士小室',1,18,[0,132,12,144],[12,136,20,140],'chest',[[30,138],[16,138],[6,138]]),
 ('crypt','墓廊壁室',2,8,[74,81,98,101],[80,101,88,107],'chest',[[84,112],[84,103],[86,91]]),
 ('brew','旧酿酒间',2,8,[92,142,118,162],[101,139,109,144],'empty',[[105,132],[105,140],[105,150]]),
 ('ledger','装卸账房',2,20,[202,126,216,140],[198,130,202,136],'ledger',[[184,134],[200,133],[209,133]]),
 ('dorm','修士寝室',3,24,[188,82,202,94],[184,86,188,90],'dorm',[[172,88],[186,88],[195,88]]),
 ('chapel','西侧小礼拜室',3,24,[74,98,84,112],[84,104,88,108],'chapel',[[104,118],[104,106],[86,106],[79,105]]),
]
plan['side_rooms'] = []
for id,name,phase,y,r,link,use,route in rooms:
    polygon=lambda q:[[q[0],q[1]],[q[2],q[1]],[q[2],q[3]],[q[0],q[3]]]
    f={'id':'side_'+id,'name':name,'phase':phase,'level':y,'polygon':polygon(r),'kind':'optional','use':use,'label':[(r[0]+r[2])/2,(r[1]+r[3])/2]}
    floors.extend([f,{'id':'side_'+id+'_link','name':name+'门廊','phase':phase,'level':y,'polygon':polygon(link),'kind':'connector'}])
    plan['side_rooms'].append({'id':f['id'],'name':name,'phase':phase,'level':y,'use':use,'points':route,'center':f['label']})
plan['side_rooms'].append({'id':'votive','name':'祈愿侧堂','phase':0,'level':20,'use':'votive','points':[[120,184],[136,184],[148,184]],'center':[148,184]})
buried_ids={'mortuary','cellar','side_crypt','side_crypt_link','side_brew','side_brew_link'}
for f in floors:
    f['buried']=f['id'] in buried_ids
    if f['buried']:
        f['ceiling']=12.8
        f['roof_level']=20.8
plan['ground']={'origin':[-72,-64],'resolution':192,'cell_size':2,'floor_offset':.4,'min_cover':.8,
                'entry_cut':[[55,123],[66,123],[66,118],[81,118],[81,139],[55,139]],
                'note':'Surface follows the monastery terraces; enclosed stores have soil above their ceilings. Only the entrance and loading exit are excavated.'}
polys = {f['id']:orient(Polygon(f['polygon']),1) for f in floors}
assert all(p.is_valid for p in polys.values())
def height(f,x,z):
    s=f.get('slope')
    if not s:return f['level']
    if s['axis']=='descent':return 18-4*max(0,min(1,(x-64)/8))-6*max(0,min(1,(130-z)/16))
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
    ceiling=f.get('ceiling',16 if f['id'] in ['nave','apse'] else 7)
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
    indoor=f['kind'] in ['interior','underground','nave','optional'] or f['id']=='apse' or f['id'].startswith('side_')
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
            wh=16 if f['id'] in ['nave','apse'] else 6 if f['kind']=='underground' else 7 if indoor else 1.4 if f['kind'] in ['bridge','final'] else 5
            if f.get('buried'):wh=f['roof_level']-min(height(f,*aa),height(f,*bb))
            if f['kind']=='blocked':wh=2.5 if f['id']=='broken_stair' else .8
            # The arcade faces the herb courtyard through low parapets and
            # piers. Its outer retaining wall stays closed against the hillside.
            if f['id']=='cloister' and ((a[1]==186 and b[1]==186) or (a[0]==36 and b[0]==36) or (a[0]==62 and b[0]==62)):
                wh=1.1
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
    top=12.8 if room['id'] in buried_ids else 7
    door_height=8.5 if room['id'] in buried_ids else 3.5
    header=top-door_height
    cuboid(room['id']+'_DoorHeader','walls',[cx,room['level']+door_height+header/2,cz],[1,header,maxz-minz] if horizontal else [maxx-minx,header,1],TRIM)
for x in range(28,65,8):
    cuboid('SouthCloisterPier','walls',[x,21.1,186.5],[.85,6.2,.85],TRIM)
    cuboid('CloisterLintel','detail',[x+3,24.3,186.5],[7,.6,1],TRIM)
for z in range(156,185,8):cuboid('WestCloisterPier','walls',[35.5,21.1,z],[.85,6.2,.85],TRIM)
cuboid('SouthCloisterEave','roofs',[49,24.8,192],[50,.4,14],ROOF)
cuboid('WestCloisterEave','roofs',[30,24.8,171],[14,.4,42],ROOF)
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
    if s['axis']=='descent':return 18-4*np.clip((px-64)/8,0,1)-6*np.clip((130-pz)/16,0,1)
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
        return 20.48
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
loading=by['loading_ramp'].copy();loading.update(id='loading_tunnel',buried=True,ceiling=12.8,roof_level=20.8)
slab(loading,polys['loading_ramp'].intersection(box(120,110,132,150)),True)
portal_arch('MortuaryPortal',73,9.5,118,14,0,8.3,2.2)
portal_arch('LoadingPortal',132,11,131,18,math.pi/2,7.0,2.0)
ground_export={'spec':spec,'heights':[round(float(v),5) for v in land.ravel()]}

# GridDungeonBuilder receives this same authored footprint for independent marker output.
cells=[]
for z in range(8,248,4):
    for x in range(0,220,4):
        candidates=[f for f in floors if f['kind']!='blocked' and polys[f['id']].covers(Point(x+2,z+2))]
        if candidates:cells.append([x//4,0,z//4])
meshes=[m for m in meshes if m['triangles']]
out=ROOT/'assets/models/sanctum_unity_v2';out.mkdir(parents=True,exist_ok=True)
(ROOT/'tools/sanctum_unity/spatial_proposal.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),'utf-8')
(out/'layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),'utf-8')
(out/'ground.json').write_text(json.dumps(ground_export,separators=(',',':')),'utf-8')
asset=WORK/'UnityProject/Assets/SanctumWorkshop';asset.mkdir(parents=True,exist_ok=True)
(asset/'spatial_mesh_input.json').write_text(json.dumps({'version':plan['version'],'cells':cells,'meshes':meshes},separators=(',',':')),'utf-8')
print(json.dumps({'floors':len(floors),'side_rooms':len(plan['side_rooms']),'meshes':len(meshes),'painted_cells':len(cells)},indent=2))
