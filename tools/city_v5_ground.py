"""Compile the finite urban land partition before generating the formal scene.

The city is a polygon coverage, never a collection of terrain paint patches.
All emitted coordinates are city-local metres (X,Y,Z); polygon coordinates X,Z.
"""
from __future__ import annotations
import json, math, sys, hashlib, shutil, heapq
from pathlib import Path
from collections import defaultdict, deque
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.local/city_v5/audit_deps'))
import shapely
from shapely.geometry import Polygon, LineString, Point, MultiPoint, box
from shapely.ops import unary_union
from shapely.affinity import rotate, translate
import numpy as np

OUT=ROOT/'docs/city_v5/ground_plan.json'
AUDIT=ROOT/'docs/city_v5/ground_coverage_audit.json'

def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def polygons(g):
    if g.is_empty:return []
    if g.geom_type=='Polygon':return [g]
    if not hasattr(g,'geoms'):return []
    return [p for part in g.geoms for p in polygons(part)]
def lines(g):
    if g.is_empty:return []
    if g.geom_type in ('LineString','LinearRing'):return [g]
    if hasattr(g,'geoms'):return [p for part in g.geoms for p in lines(part)]
    return []
def clean(g):return shapely.set_precision(shapely.make_valid(g),.000001)
def xy(ring):return [[round(x,6),round(z,6)] for x,z in list(ring.coords)[:-1]]
def footprint(b,pad=0):
    w,_,d=b['size'];x,z=b['c']
    return translate(rotate(box(-w/2-pad,-d/2-pad,w/2+pad,d/2+pad),-b['yaw'],origin=(0,0)),x,z)
def backup():
    dst=ROOT/'.local/city_v5/gen11d_ground_backup'
    for rel in ['tools/gen_solenne.gd','tools/city_v5_layout.py','docs/city_v5/layout.json','scenes/zones/tidewind_highlands.tscn','data/terrain/tidewind.res']:
        target=dst/rel
        if not target.exists():target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,target)
    return str(dst)

class Compiler:
    def __init__(self,plan):
        self.p=plan;self.faces=[];self.geometry={};self.height_functions={};self.edges=[];self.links=[]
        self.blocks=[];self.parcels=[];self.pedestrian_paths=[];self.path_geometries=[];self.navigation_issues=[]
        self.roads=[]
        for r in plan['roads']:
            for a,b,ya,yb in zip(r['pts'],r['pts'][1:],r['heights'],r['heights'][1:]):
                self.roads.append((a,b,ya,yb,r['id']))
        self.land=Polygon(plan['wall']+[[230,1009.54545],[80,1030],[-180,930],[-180,735],[-270,650],[-550,650],[-620,735],[-640,930],[-720,970],[-880,940],[-940,800],[-960,630],[-965,430],[-980,250],[-963.33333,220]])
        self.boundary=clean(self.land)
        self.water=clean(LineString(plan['river']).buffer(26,quad_segs=8))
        self.land=clean(self.land.difference(self.water))
        self.remaining=self.land
        self.buildings=unary_union([footprint(b) for b in plan['buildings']])
        self.districts=[
            ('governor',60,box(-1100,150,-674,450)),
            ('academy',44,box(-674,150,-360,450)),
            ('civic',26,box(-360,150,400,502)),
            ('market_lower',20,box(-180,502,400,600)),
            ('civic_service',26,box(-360,502,-180,548)),
            ('west_upper',52,box(-1100,450,-790,500)),
            ('upper_market',44,box(-790,450,-580,500)),
            ('academy_lower',38,box(-580,450,-360,535)),
            ('west_middle',44,box(-1100,500,-790,565)),
            ('west_trade',44,box(-790,500,-674,540)),
            ('west_old',38,box(-1100,565,-740,885)),
            ('terrace_lower',32,box(-790,500,-360,600)),
            ('cathedral',38,box(-740,600,-700,855)),
            ('harbor_transition',22,box(-740,600,-630,700)),
            ('harbor',13,box(-1100,548,-180,1100)),
            ('south_city',18,box(-180,580,400,1100)),
        ]
        self.building_districts={b['id']:self.district(*b['c']) for b in plan['buildings']}
        self.compounds=[];self.compound_geo={};self.forecourt_geo={}
        fronts={'civic':box(-224,343,-136,382),'market':box(45,341,115,382),'palace':box(-840,328,-740,409),'academy':box(-570,309,-450,398),'cathedral':box(-825,660,-745,704),'station':box(10,751,110,777)}
        for b in plan['buildings']:
            if b['id'] not in fronts:continue
            fc=fronts[b['id']];outer=box(*footprint(b,4).union(fc).bounds)
            others=unary_union([footprint(q) for q in plan['buildings'] if q['id']!=b['id']])
            if outer.intersection(others).area>.001:outer=clean(outer.difference(others.buffer(.5)))
            self.compound_geo[b['id']]=outer;self.forecourt_geo[b['id']]=fc
            self.compounds.append(dict(id='compound_'+b['id'],buildingId=b['id'],kind='landmark_compound',level=self.building_districts[b['id']][1],polygon=xy(max(polygons(outer),key=lambda p:p.area).exterior),frontCourt=xy(fc.exterior),area=round(outer.area,3)))
        self.compound_union=unary_union(list(self.compound_geo.values()))
        self.forecourt_union=unary_union(list(self.forecourt_geo.values()))
    def district(self,x,z):
        p=Point(x,z)
        for ident,y,poly in self.districts:
            if poly.covers(p):return ident,y
        return ('civic',26) if z<580 else ('south_city',18)
    def road_h(self,x,z):
        weight=0.;value=0.
        for a,b,ya,yb,_ in self.roads:
            dx=b[0]-a[0];dz=b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz)))
            dist=(x-a[0]-t*dx)**2+(z-a[1]-t*dz)**2
            # A continuous field of the shared graph constraints: no nearest-road
            # ownership switch and therefore no vertical discontinuity at junctions.
            w=1.0/(dist+2.0)**2
            value+=(ya+(yb-ya)*t)*w;weight+=w
        return value/weight
    def make_neighborhoods(self,corridor,parks):
        """Allocate occupied plots, then route an obstacle-aware small street grid."""
        buildings={b['id']:b for b in self.p['buildings']}
        actual={k:footprint(b) for k,b in buildings.items()}
        reserved=unary_union([p.buffer(.2,join_style=2) for p in actual.values()])
        park_geo=unary_union([Polygon(p['polygon'],p.get('holes',[])) for p in parks])
        block_land=clean(self.land.difference(corridor).difference(park_geo).union(reserved.intersection(self.land)))
        raw=sorted(polygons(block_land),key=lambda p:(round(p.centroid.y),round(p.centroid.x)))
        block_geo={};assigned={}
        for n,poly in enumerate(raw):
            members=[bid for bid,p in actual.items() if poly.covers(p.centroid)]
            if not members and poly.area<50:continue
            bid=f'block_{n:03d}';block_geo[bid]=poly
            levs=sorted({self.building_districts[i][1] for i in members})
            district,level=self.district(poly.representative_point().x,poly.representative_point().y)
            self.blocks.append(dict(id=bid,district=district,level=levs[0] if len(levs)==1 else level,levels=levs or [level],polygon=xy(poly.exterior),holes=[xy(r) for r in poly.interiors],buildingIds=members,pathIds=[],area=round(poly.area,3)))
            for i in members:assigned[i]=bid
        for bid,p in actual.items():
            if bid not in assigned:
                key=max(block_geo,key=lambda k:block_geo[k].intersection(p).area)
                assigned[bid]=key;next(b for b in self.blocks if b['id']==key)['buildingIds'].append(bid)
        # 2m orthogonal routing lattice, with a full-width building exclusion.
        step=2.;minx,minz,maxx,maxz=self.land.bounds;ox=math.floor(minx/step)*step;oz=math.floor(minz/step)*step
        nx=int(math.ceil((maxx-ox)/step))+1;nz=int(math.ceil((maxz-oz)/step))+1
        gx,gz=np.meshgrid(ox+np.arange(nx)*step,oz+np.arange(nz)*step)
        nav=self.land.buffer(-1.6).difference(self.buildings.buffer(1.85,join_style=2)).difference(park_geo.buffer(.25))
        free=shapely.contains_xy(nav,gx,gz).ravel()
        source=free & shapely.contains_xy(corridor.buffer(.5),gx,gz).ravel()
        parent=np.full(nx*nz,-2,dtype=np.int32);queue=deque(np.flatnonzero(source).tolist())
        for i in queue:parent[i]=-1
        def near_indices(i):
            x=i%nx;z=i//nx
            if x:yield i-1
            if x+1<nx:yield i+1
            if z:yield i-nx
            if z+1<nz:yield i+nx
        while queue:
            i=queue.popleft()
            for j in near_indices(i):
                if free[j] and parent[j]==-2:parent[j]=i;queue.append(j)
        def coord(i):return [ox+(i%nx)*step,oz+(i//nx)*step]
        def snap(pt):
            x=int(round((pt[0]-ox)/step));z=int(round((pt[1]-oz)/step));options=[]
            for dz in range(-4,5):
                for dx in range(-4,5):
                    xx=x+dx;zz=z+dz
                    if 0<=xx<nx and 0<=zz<nz:
                        j=zz*nx+xx
                        if free[j] and parent[j]!=-2 and LineString([pt,coord(j)]).buffer(1.2).intersection(self.buildings).area<.001:options.append(((coord(j)[0]-pt[0])**2+(coord(j)[1]-pt[1])**2,j))
            return min(options)[1] if options else None
        def simplify(points):
            result=[]
            for p in points:
                if result and p==result[-1]:continue
                while len(result)>1 and abs((result[-1][0]-result[-2][0])*(p[1]-result[-1][1])-(result[-1][1]-result[-2][1])*(p[0]-result[-1][0]))<1e-8:result.pop()
                result.append(p)
            return result
        def route(a,b,block):
            start=snap(a);end=snap(b)
            if start is None or end is None:return None
            allowed=block.buffer(4).difference(self.forecourt_union.buffer(1))
            limit=allowed.bounds;visited={start:0};prev={};todo=[(0,start)];target=coord(end)
            while todo:
                _,i=heapq.heappop(todo)
                if i==end:
                    nodes=[end]
                    while nodes[-1]!=start:nodes.append(prev[nodes[-1]])
                    return simplify([a]+[coord(j) for j in reversed(nodes)]+[b])
                if len(visited)>35000:break
                for j in near_indices(i):
                    if not free[j]:continue
                    x,z=coord(j)
                    if not(limit[0]<=x<=limit[2] and limit[1]<=z<=limit[3]) or not allowed.covers(Point(x,z)):continue
                    score=visited[i]+1
                    if score>=visited.get(j,1e20):continue
                    visited[j]=score;prev[j]=i;heapq.heappush(todo,(score+(abs(x-target[0])+abs(z-target[1]))/step,j))
            return None
        def add_path(bid,points,kind,connects):
            if not points or len(points)<2:return None
            line=LineString(points)
            if line.length<.1:return None
            width=3.;full=line.buffer(width/2,cap_style=1,join_style=1,quad_segs=4)
            # Clip only at the public corridor/land edge, never tunnel through a house.
            conflict=full.intersection(self.buildings.buffer(.05)).area
            if conflict>.005:
                narrow=line.buffer(1.2,cap_style=1,join_style=1,quad_segs=4)
                if narrow.intersection(self.buildings.buffer(.05)).area<.005:width=2.4;full=narrow;conflict=0
            if conflict>.005:
                self.navigation_issues.append(dict(kind='path_building_conflict',blockId=bid,connects=connects,area=round(conflict,4)));return None
            poly=clean(full.intersection(self.land).difference(park_geo));components=polygons(poly)
            if len(components)!=1:return None
            poly=components[0];ident=f'walk_{len(self.pedestrian_paths):03d}'
            levels=[self.district(x,z)[1] for x,z in points]
            rec=dict(id=ident,blockId=bid,kind=kind,width=width,level=levels[0] if max(levels)==min(levels) else None,points=points,centerline=[[p[0],y,p[1]] for p,y in zip(points,levels)],polygon=xy(poly.exterior),holes=[xy(r) for r in poly.interiors],connects=connects,length=round(line.length,3),status='horizontal_route_reserved')
            self.pedestrian_paths.append(rec);self.path_geometries.append(poly);next(b for b in self.blocks if b['id']==bid)['pathIds'].append(ident);return ident
        entries={};backs={};entry_paths=defaultdict(list)
        for b in self.p['buildings']:
            x,z=b['c'];a=math.radians(b['yaw']);front=(-math.sin(a),-math.cos(a));d=b['size'][2]/2
            def landing(sign,preferred):
                for off in [preferred,2.5,2.,1.5]:
                    q=[x+sign*front[0]*(d+off),z+sign*front[1]*(d+off)]
                    if Point(q).buffer(1.25).intersection(self.buildings).area<.001:return q
                return [x+sign*front[0]*(d+preferred),z+sign*front[1]*(d+preferred)]
            entries[b['id']]=landing(1,2.8)
            backs[b['id']]=landing(-1,3.3)
            i=snap(entries[b['id']]);nodes=[]
            if i is not None:
                while i>=0:nodes.append(coord(i));i=int(parent[i])
            pid=add_path(assigned[b['id']],simplify([entries[b['id']]]+nodes),'front_access',[b['id'],'public_sidewalk'])
            if pid:entry_paths[b['id']].append(pid)
            else:self.navigation_issues.append(dict(kind='front_access_unresolved',buildingId=b['id']))
        # Shared internal lanes join neighbours and their rear courts. Two nearest
        # links per building make small loops, not one radial spoke per house.
        for block in self.blocks:
            members=[k for k in block['buildingIds'] if k not in self.compound_geo];pairs=set()
            for bid in members:
                nearest=sorted((other for other in members if other!=bid),key=lambda other:Point(backs[bid]).distance(Point(backs[other])))[:2]
                for other in nearest:pairs.add(tuple(sorted((bid,other))))
            for a,b in sorted(pairs):
                pts=route(backs[a],backs[b],block_geo[block['id']])
                pid=add_path(block['id'],pts,'shared_rear_lane',[a,b])
                if pid:entry_paths[a].append(pid);entry_paths[b].append(pid)
            for bid in members:
                pts=route(entries[bid],backs[bid],block_geo[block['id']])
                pid=add_path(block['id'],pts,'side_access',[bid])
                if pid:entry_paths[bid].append(pid)
        lanes=unary_union(self.path_geometries).difference(self.compound_union)
        def orthogonal_cells(members,domain):
            """Guillotine cadastral cuts align with streets and house rows."""
            if len(members)<2:return {members[0]:domain} if members else {}
            candidates=[]
            for axis in [0,1]:
                ordered=sorted(members,key=lambda k:buildings[k]['c'][axis])
                for cut in range(1,len(ordered)):
                    aa=ordered[:cut];bb=ordered[cut:]
                    left=max(actual[k].bounds[axis+2] for k in aa);right=min(actual[k].bounds[axis] for k in bb)
                    split=(left+right)/2 if right>=left else (buildings[ordered[cut-1]]['c'][axis]+buildings[ordered[cut]]['c'][axis])/2
                    penalty=max(0,left-right)*100+abs(len(aa)-len(bb))
                    candidates.append((penalty,axis,split,aa,bb))
            _,axis,split,aa,bb=min(candidates,key=lambda r:r[0]);x0,z0,x1,z1=domain.bounds
            low=box(x0-1,z0-1,split,z1+1) if axis==0 else box(x0-1,z0-1,x1+1,split)
            high=box(split,z0-1,x1+1,z1+1) if axis==0 else box(x0-1,split,x1+1,z1+1)
            result=orthogonal_cells(aa,domain.intersection(low));result.update(orthogonal_cells(bb,domain.intersection(high)));return result
        for block in self.blocks:
            members=block['buildingIds'];pg=block_geo[block['id']]
            if not members:continue
            ordinary=[k for k in members if k not in self.compound_geo]
            cells=orthogonal_cells(ordinary,pg.difference(self.compound_union))
            cells.update({k:self.compound_geo[k] for k in members if k in self.compound_geo})
            other_reserved=unary_union([actual[k] for k in members])
            for bid in members:
                cell=cells[bid]
                b=buildings[bid];shape=clean(cell.intersection(pg).difference(other_reserved).union(actual[bid]).difference(lanes))
                if bid in self.compound_geo:shape=clean(self.compound_geo[bid])
                pieces=polygons(shape);site=next((q for q in pieces if q.covers(actual[bid].centroid)),max(pieces,key=lambda p:p.area))
                level=self.building_districts[bid][1];a=math.radians(b['yaw']);front=(-math.sin(a),-math.cos(a));w=b['size'][0];d=b['size'][2]
                court_site=clean(cell.intersection(pg).difference(other_reserved))
                def court(center):
                    q=translate(rotate(box(-min(w,14)/2,-3,min(w,14)/2,3),-b['yaw'],origin=(0,0)),*center).intersection(court_site)
                    ps=polygons(q);return xy(max(ps,key=lambda x:x.area).exterior) if ps else []
                entry=[b['c'][0]+front[0]*d/2,b['c'][1]+front[1]*d/2]
                tangent=(math.cos(a),-math.sin(a));frontage=[[entry[0]-tangent[0]*w/2,entry[1]-tangent[1]*w/2],[entry[0]+tangent[0]*w/2,entry[1]+tangent[1]*w/2]]
                self.parcels.append(dict(id='parcel_'+bid,buildingId=bid,blockId=block['id'],polygon=xy(site.exterior),holes=[xy(r) for r in site.interiors],level=level,entry=entry,entrance=[entry[0],level+.6,entry[1]],buildingFootprint=xy(actual[bid].exterior),frontCourt=xy(self.forecourt_geo[bid].exterior) if bid in self.forecourt_geo else court(entries[bid]),backCourt=court(backs[bid]),frontage=frontage,pathIds=entry_paths[bid],footprintArea=round(actual[bid].area,3)))
        # The network is a real carved paving class, with unioned junctions.
        self.pedestrian_union=clean(lanes.difference(corridor))
        for ident,y,poly in self.districts:
            self.take('internal_walk_'+ident,'pedestrian',self.pedestrian_union.intersection(poly),y,'cap',ident)
    def add_connections(self):
        # Connections are kept explicit and pending until their landing heights
        # are verified against the final parcel and pedestrian surfaces.
        self.links=[]
    def rebuild_faces(self):
        pass
    def emit(self,ident,kind,g,h,material='paving',district=None):
        result=[]
        for k,p in enumerate(polygons(clean(g))):
            if p.area<.00001:continue
            fid=ident if k==0 else f'{ident}_{k}'
            hp=h if callable(h) else lambda x,z,y=h:y
            # Dense shared borders limit faceting of curved road profiles.
            p=shapely.segmentize(p,4.0)
            verts=[];tris=[];lookup={}
            for tri in polygons(shapely.constrained_delaunay_triangles(p)):
                coords=list(tri.exterior.coords)[:3];indices=[]
                for x,z in coords:
                    key=(round(x,6),round(z,6))
                    if key not in lookup:lookup[key]=len(verts);verts.append([key[0],round(hp(*key),5),key[1]])
                    indices.append(lookup[key])
                a,b,c=[verts[i] for i in indices]
                # Positive Y normal in X/Y/Z coordinates.
                if (b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2])<0:indices.reverse()
                tris.append(indices)
            face=dict(id=fid,sceneId='ground_'+fid,kind=kind,district=district or ident,material=material,polygon=xy(p.exterior),holes=[xy(r) for r in p.interiors],vertices=verts,triangles=tris,collide=True,area=round(p.area,5))
            if not callable(h):face['level']=h
            self.faces.append(face);self.geometry[fid]=p;self.height_functions[fid]=hp;result.append(face)
        return result
    def take(self,ident,kind,g,h,material='paving',district=None):
        g=clean(g.intersection(self.remaining));result=self.emit(ident,kind,g,h,material,district)
        self.remaining=clean(self.remaining.difference(g));return result
    def compile(self):
        street_roads=[r for r in self.p['roads'] if r['width']>=8]
        carriage=clean(unary_union([LineString(r['pts']).buffer(r['width']/2,cap_style=1,join_style=1,quad_segs=6) for r in street_roads]).buffer(1.5,quad_segs=6).buffer(-1.5,quad_segs=6))
        corridor=clean(unary_union([LineString(r['pts']).buffer(r['width']/2+r['walk'],cap_style=1,join_style=1,quad_segs=6) for r in street_roads]).union(carriage.buffer(3,quad_segs=6)))
        carriage=clean(carriage.difference(self.forecourt_union));corridor=clean(corridor.difference(self.forecourt_union))
        self.take('carriageways','carriageway',carriage,lambda x,z:self.road_h(x,z),'road','streets')
        curb=clean(carriage.buffer(.4,join_style=2).difference(carriage).intersection(corridor))
        self.take('curbs','curb',curb,lambda x,z:self.road_h(x,z)+min(.15,Point(x,z).distance(carriage)*.375),'cap','streets')
        self.take('sidewalks','sidewalk',corridor.difference(carriage).difference(curb),lambda x,z:self.road_h(x,z)+.15,'paving','streets')
        # Quay-side public walk is six metres clear, distinct from its edge wall.
        coast=LineString([[-963.33333,220],[-980,250],[-965,430],[-960,630],[-940,800],[-880,940],[-720,970],[-640,930],[-620,735],[-550,650],[-270,650],[-180,735],[-180,930],[80,1030],[230,1009.54545]])
        self.coast=coast
        walk=clean(coast.buffer(7,cap_style=2,join_style=2).intersection(self.land).difference(self.buildings.buffer(1)))
        for ident,y,poly in self.districts:
            self.take('coastal_'+ident,'promenade',walk.intersection(poly),y,'paving','waterfront')
        riverwalk=clean(self.water.buffer(6.5).difference(self.water).intersection(self.land).difference(self.buildings.buffer(1)))
        # A thin remainder against a house is edge paving, never advertised as a
        # navigable promenade. Its through route uses the reserved interior grid.
        riverwalk=clean(riverwalk.buffer(-2.5).buffer(2.5).intersection(riverwalk))
        self.take('river_north','promenade',riverwalk.intersection(box(-180,0,500,580)),20,'paving','riverfront')
        self.take('river_south','promenade',riverwalk.intersection(box(-180,580,500,1200)),18,'paving','riverfront')
        self.take('river_harbor','promenade',riverwalk,13,'paving','riverfront')
        parks=[]
        for ident,candidate,y in [('city_park',box(-850,806,-735,865),38),('harbor_pocket_park',box(64,905,162,953),18)]:
            possible=clean(candidate.intersection(self.remaining).difference(self.buildings.buffer(3)).difference(corridor.buffer(2)))
            poly=max(polygons(possible),key=lambda p:p.area)
            # One connected green per named park; other fragments remain paving.
            fs=self.take(ident,'park',poly,y,'park',ident)
            parks.extend(dict(id=f['id'],polygon=f['polygon'],holes=f['holes'],area=f['area'],level=y) for f in fs)
        for c in self.compounds:self.take(c['id'],'forecourt',self.compound_geo[c['buildingId']],c['level'],'paving',self.building_districts[c['buildingId']][0])
        self.make_neighborhoods(corridor,parks)
        # Whole-block grades own floors. No per-building islands of old grades.
        by_district=defaultdict(list)
        for b in self.p['buildings']:
            by_district[self.building_districts[b['id']][0]].append(footprint(b,1))
        all_pads=unary_union([g for gs in by_district.values() for g in gs])
        for ident,y,poly in self.districts:
            reserved=unary_union(by_district[ident])
            self.take('district_'+ident,'terrace',poly.difference(all_pads).union(reserved),y,'paving',ident)
        self.take('urban_closure','terrace',self.land,26,'paving','civic')
        self.add_connections()
        self.rebuild_faces()
        # Adjacent physical steps are explicit design records, never smooth dirt.
        for i,f in enumerate(self.faces):
            pg=self.geometry[f['id']]
            for g in self.faces[i+1:]:
                q=self.geometry[g['id']]
                if not pg.intersects(q):continue
                for line in lines(pg.boundary.intersection(q.boundary)):
                    if line.length<.05:continue
                    mid=line.interpolate(.5,normalized=True);a=self.height_functions[f['id']](mid.x,mid.y);b=self.height_functions[g['id']](mid.x,mid.y)
                    if abs(a-b)<.025:continue
                    self.edges.append(dict(id=f'edge_{len(self.edges)}',kind='curb' if abs(a-b)<.25 else 'retaining',faces=[f['id'],g['id']],points=[[round(x,4),round(z,4)] for x,z in line.coords],low=round(min(a,b),4),high=round(max(a,b),4),status='design_edge'))
        coverage=unary_union(list(self.geometry.values()));missing=self.land.difference(coverage);overlap=sum(g.area for g in self.geometry.values())-coverage.area
        audit=dict(urbanLandArea=round(self.land.area,5),coveredArea=round(coverage.area,5),missingArea=round(missing.area,8),overlapArea=round(overlap,8),waterIntrusionArea=round(coverage.intersection(self.water).area,8),parkCount=len(parks),parkArea=sum(p['area'] for p in parks),faceCount=len(self.faces),vertices=sum(len(f['vertices']) for f in self.faces),triangles=sum(len(f['triangles']) for f in self.faces),coveragePassed=missing.area<.01 and abs(overlap)<.05 and coverage.intersection(self.water).area<.01,blocks=len(self.blocks),parcels=len(self.parcels),pedestrianPaths=len(self.pedestrian_paths),navigationIssues=self.navigation_issues,implementationReady=False,pending=['Resolve stair candidates and floor/frontage transitions','Generate explicit boundary/connection meshes','Validate seam heights and pedestrian connectivity'])
        out=dict(schemaVersion=1,version='ground12-plan-c',status='parcel_and_pedestrian_plan',coordinateSystem='city-local X/Y/Z metres; polygon X/Z',roadHeightModel='continuous weighted shared-network segment field',sourceLayoutHash=hashlib.sha256(json.dumps(self.p,sort_keys=True).encode()).hexdigest(),urbanBoundary=xy(self.boundary.exterior),waterExclusions=[dict(polygon=xy(p.exterior),holes=[]) for p in polygons(self.water)],parks=parks,compounds=self.compounds,blocks=self.blocks,parcels=self.parcels,pedestrianPaths=self.pedestrian_paths,faces=self.faces,edges=self.edges,links=self.links,meta=audit)
        return out,audit

def main():
    backup();plan=read(ROOT/'docs/city_v5/layout.json');c=Compiler(plan);out,audit=c.compile()
    OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(json.dumps(out,ensure_ascii=False,separators=(',',':')),encoding='utf8');AUDIT.write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(audit,ensure_ascii=False));print(OUT)
if __name__=='__main__':main()
