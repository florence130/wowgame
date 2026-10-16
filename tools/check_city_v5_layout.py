"""Read-only native-metre city geometry audit. Does not execute the generator.

Requires Shapely (normal environment or .local/city_v5/audit_deps).
Reports 2D conflicts and authored terrain-write conflicts, not runtime acceptance.
"""
from pathlib import Path
import argparse, copy, hashlib, json, math, re, sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.local/city_v5/audit_deps'))
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union, nearest_points
from shapely import affinity

EPS = .05

def read(path): return json.loads((ROOT / path).read_text(encoding='utf-8'))
def sha(path): return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
def xy(p): return [round(p.x,3),round(p.y,3)]
def rect(c, size, yaw=0):
    w,d=size
    return affinity.translate(affinity.rotate(box(-w/2,-d/2,w/2,d/2),-yaw,origin=(0,0)),*c)
def turn(p,yaw):
    a=math.radians(yaw);x,z=p
    return (math.cos(a)*x+math.sin(a)*z,-math.sin(a)*x+math.cos(a)*z)
def move(poly,c,yaw): return affinity.translate(affinity.rotate(poly,-yaw,origin=(0,0)),*c)
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def lerp(a,b,t): return a+(b-a)*t

def scene_nodes(path):
    raw=(ROOT/path).read_text(encoding='utf-8');out={}
    for head,body in re.findall(r'\[node ([^\n]+)\]\n(.*?)(?=\n\[|\Z)',raw,re.S):
        if 'parent="Buildings"' not in head:continue
        name=re.search(r'name="([^"]+)"',head).group(1)
        match=re.search(r'transform = Transform3D\(([^)]+)\)',body)
        if not match:continue
        v=list(map(float,match.group(1).split(',')))
        asset=re.search(r'asset_scene = "([^"]+)"',body)
        # TSCN Transform3D text serializes the basis row by row. Godot yaw
        # therefore has sin(yaw) at element 2, not element 6.
        out[name]=dict(c=[v[9],v[11]],y=v[10],yaw=math.degrees(math.atan2(v[2],v[0])),asset=asset.group(1) if asset else '',basis=v[:9])
    return out

class Audit:
    def __init__(self,plan):
        self.p=plan
        self.generator=(ROOT/'tools/gen_solenne.gd').read_text(encoding='utf8')
        self.man={a['id']:a for family in ('architecture','landmarks') for a in read(f'assets/models/city_v5/{family}/manifest.json')['assets']}
        self.scene=scene_nodes('scenes/zones/tidewind_highlands.tscn')
        self.local={};self.envelope={}
        for aid,a in self.man.items():
            self.local[aid]=Polygon(a['footprint_polygon']) if 'footprint_polygon' in a else rect((0,0),a['footprint'])
            bounds=a.get('bounds_godot')
            lo=bounds['min'] if bounds else a['aabb_min'];hi=bounds['max'] if bounds else a['aabb_max']
            self.envelope[aid]=box(lo[0],lo[2],hi[0],hi[2])
        self.buildings={b['id']:b for b in plan['buildings']}
        self.polys={i:self.body(b) for i,b in self.buildings.items()}
        self.lines={r['id']:LineString(r['pts']) for r in plan['roads']}
        west=plan['coast_west'];south=plan['coast_south']
        self.water=unary_union([
            Polygon([(-3000,-2000),(west[0][0],-2000)]+[tuple(q) for q in west]+[(west[-1][0],3000),(-3000,3000)]),
            Polygon([(-3000,south[0][1])]+[tuple(q) for q in south]+[(3000,south[-1][1]),(3000,3000),(-3000,3000)]),
            LineString(plan['river']).buffer(26,quad_segs=48)])
        self.roads=self.make_roads()
        self.car=unary_union([r['car'] for r in self.roads.values()])
        self.walk=unary_union([r['walk'] for r in self.roads.values()])
        self.road_space=self.car.union(self.walk)
        self.landscape={g['id']:rect(g['c'],g['size']) for g in plan['gardens']+plan['squares']}
        self.terrain=self.terrain_features()

    def body(self,b):return move(self.local[b['asset']],b['c'],b['yaw'])
    def exterior(self,b):return move(self.envelope[b['asset']],b['c'],b['yaw'])
    def entries(self,b):
        a=self.man[b['asset']]
        if 'entry' in a:return a['entry']
        return [dict(position=e,outward=[0,0,-1 if e[2]<0 else 1],clear_width=a.get('entry_width',6),approach_depth=4) for e in a.get('entries',[])]
    def entry_aprons(self,b):
        pieces=[]
        for e in self.entries(b):
            x,_,z=e['position'];nx,_,nz=e['outward'];depth=e.get('approach_depth',4)+.25;w=e.get('clear_width',4)+1.2
            t=(-nz,nx)
            pieces.append(move(Polygon([(x+t[0]*s*w/2+nx*d,z+t[1]*s*w/2+nz*d) for s,d in [(-1,0),(1,0),(1,depth),(-1,depth)]]),b['c'],b['yaw']))
        return unary_union(pieces)
    def grade(self,x,z):
        h=20+40*(1-smooth(-880,-280,x))*(1-smooth(380,650,z))
        h+=18*(1-smooth(-800,-610,x))*smooth(570,690,z)*(1-smooth(840,940,z))
        for t in self.p['terraces']:
            dist=Point(x,z).distance(rect(t['c'],t['size']));h=lerp(h,t['y'],1-smooth(0,32,dist))
        coast=self.interp(self.p['coast_south'],x,0)
        if -690<x<210:h=lerp(13,h,smooth(12,55,coast-z))
        dr=Point(x,z).distance(LineString(self.p['river']))
        return lerp(14,h,smooth(30,80,dr))
    @staticmethod
    def interp(values,t,axis):
        other=1-axis
        if t<=values[0][axis]:return values[0][other]
        for a,b in zip(values,values[1:]):
            if t<=b[axis]:return lerp(a[other],b[other],(t-a[axis])/max(b[axis]-a[axis],.001))
        return values[-1][other]
    def road_h(self,p):
        x,z=p
        for xx,zz,h in self.p['road_levels']:
            if math.hypot(x-xx,z-zz)<1:return h
        if x>-180 and 535<=z<=650:return 20
        if x>230 and z<500:return 26
        if x>=-150 and 650<=z<=890:return 18
        if -900<=x<=-680 and 600<=z<=885:return 38
        if -665<=x<=-330 and z>=600:return 13
        return self.grade(x,z)
    def road_height_at(self,p,r):
        best=None
        for a,b in zip(r['pts'],r['pts'][1:]):
            line=LineString([a,b]);dist=line.distance(p);f=line.project(p)/line.length
            if best is None or dist<best[0]:best=(dist,lerp(self.road_h(a),self.road_h(b),f))
        return best[1]
    def make_roads(self):
        result={}
        for r in self.p['roads']:
            cars=[];walks=[]
            for a,b in zip(r['pts'],r['pts'][1:]):
                line=LineString([a,b]);length=line.length;n=max(1,math.ceil(length/4));dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
                for k in range(n):
                    p0=line.interpolate(k/n,normalized=True);p1=line.interpolate((k+1)/n,normalized=True);mid=line.interpolate((k+.5)/n,normalized=True)
                    if self.water.contains(mid):continue
                    cars.append(LineString([p0,p1]).buffer(r['width']/2,cap_style=2))
                    for sign in (-1,1):
                        off=sign*(r['width']/2+r['walk']/2);ox=-dz*off;oz=dx*off;mp=Point(mid.x+ox,mid.y+oz)
                        if any(rr['id']!=r['id'] and self.lines[rr['id']].distance(mp)<rr['width']/2+rr['walk']+2 for rr in self.p['roads']):continue
                        walks.append(LineString([(p0.x+ox,p0.y+oz),(p1.x+ox,p1.y+oz)]).buffer(r['walk']/2,cap_style=2))
            result[r['id']]={'car':unary_union(cars),'walk':unary_union(walks),'spec':r}
        return result
    def terrain_for_building(self,b):
        w,d=self.man[b['asset']]['footprint'];x,z=b['c'];yaw=b['yaw'];fx,fz=turn((0,-1),yaw)
        y=b.get('y',self.scene.get(b['id'],{}).get('y',self.grade(x,z))-.6)
        return [dict(id=b['id']+':body_pad',kind='building_pad',owner=b['id'],poly=rect((x,z),(w+4,d+5),yaw),falloff=4,y=y),dict(id=b['id']+':entry_pad',kind='building_entry_pad',owner=b['id'],poly=rect((x+fx*(d/2+3),z+fz*(d/2+3)),(10,16),yaw),falloff=8,y=y)]
    def terrain_features(self):
        features=[]
        special=re.search(r'([\d.]+) if s\.id=="([^"]+)" else ([\d.]+)',self.generator)
        for kind,fall in [('squares',7),('gardens',5)]:
            for g in self.p[kind]:
                active_fall=fall
                if kind=='squares' and special:active_fall=float(special[1] if g['id']==special[2] else special[3])
                features.append(dict(id=g['id'],kind=kind,owner=g['id'],poly=rect(g['c'],g['size']),falloff=g.get('falloff',active_fall),y=g['y']))
        for b in self.p['buildings']:features.extend(self.terrain_for_building(b))
        return features
    def terrain_conflicts(self,features=None):
        out=[]
        for f in self.terrain if features is None else features:
            outer=f['poly'].buffer(f['falloff'])
            for rid,r in self.roads.items():
                hit=outer.intersection(r['car'])
                if hit.area<EPS:continue
                core=f['poly'].intersection(r['car']);region=core if core.area>EPS else hit
                samples=[region.representative_point()]
                for part in getattr(region,'geoms',[region]):
                    if hasattr(part,'exterior'):samples.extend(Point(p) for p in part.exterior.coords)
                q=max(samples,key=lambda pt:abs(f['y']-self.road_height_at(pt,r['spec'])))
                expected=self.road_height_at(q,r['spec']);diff=f['y']-expected
                if abs(diff)<2:continue
                perturb=max(abs(f['y']-self.road_height_at(pt,r['spec']))*(1-smooth(0,f['falloff'],pt.distance(f['poly']))) for pt in samples)
                out.append(dict(feature=f['id'],owner=f['owner'],kind=f['kind'],road=rid,at=xy(q),target_grade=round(f['y'],3),road_authored_grade=round(expected,3),delta_m=round(diff,3),sampled_max_single_write_displacement_m=round(perturb,3),core_overlap_m2=round(core.area,3),blend_overlap_m2=round(hit.area-core.area,3),severity='terrain_write_conflict' if core.area>EPS else 'terrain_blend_risk'))
        return out
    def building_issues(self):
        definite=[];risk=[]
        for bid,b in self.buildings.items():
            body=self.polys[bid];outer=self.exterior(b).difference(self.entry_aprons(b));waterhit=body.intersection(self.water)
            if waterhit.area>EPS:definite.append(dict(kind='building_water',building=bid,c=b['c'],area_m2=round(waterhit.area,3),at=xy(waterhit.centroid)))
            elif body.distance(self.water)<3:risk.append(dict(kind='water_setback_under_3m',building=bid,gap_m=round(body.distance(self.water),3)))
            for rid,r in self.roads.items():
                for kind in ('car','walk'):
                    hit=body.intersection(r[kind])
                    if hit.area>EPS:definite.append(dict(kind='building_'+kind,building=bid,c=b['c'],road=rid,area_m2=round(hit.area,3),at=xy(hit.centroid)))
                    elif (h:=outer.intersection(r[kind])).area>EPS:risk.append(dict(kind='overhang_or_trim_'+kind,building=bid,road=rid,area_m2=round(h.area,3),at=xy(h.centroid),note='AABB envelope only; could be overhead eaves. Normal entry apron excluded.'))
        ids=list(self.buildings)
        for i,bid in enumerate(ids):
            for oid in ids[i+1:]:
                hit=self.polys[bid].intersection(self.polys[oid])
                if hit.area>EPS:definite.append(dict(kind='building_building',building=bid,other=oid,area_m2=round(hit.area,3),at=xy(hit.centroid)))
                elif self.polys[bid].distance(self.polys[oid])<1:risk.append(dict(kind='building_gap_under_1m',building=bid,other=oid,gap_m=round(self.polys[bid].distance(self.polys[oid]),3)))
        return definite,risk
    def gate_report(self):
        walls={i:rect(n['c'],(32,7),n['yaw']) for i,n in self.scene.items() if n['asset'].endswith('/city_wall_32.glb')}
        out=[]
        for gid,n in self.scene.items():
            if not n['asset'].endswith('/city_gate_grand.glb'):continue
            for sign in (-1,1):
                dx,dz=turn((17*sign,0),n['yaw']);c=[n['c'][0]+dx,n['c'][1]+dz];tower=rect(c,(16,16),n['yaw'])
                nearest=min(walls,key=lambda wid:tower.distance(walls[wid]));gap=tower.distance(walls[nearest]);p,q=nearest_points(tower,walls[nearest])
                out.append(dict(gate=gid,tower_side=sign,tower_c=[round(v,3) for v in c],nearest_wall=nearest,gap_m=round(gap,4),connected_in_plan=gap<=.15,gap_endpoints=[xy(p),xy(q)],vertical_base_delta=round(n['y']-self.scene[nearest]['y'],3)))
        return out
    def station_report(self):
        ids=[i for i in self.buildings if i.startswith('station_court_')];obstacles=unary_union(list(self.polys.values())).buffer(.75)
        center=Point(-60,810);members=[]
        for bid in ids:
            b=self.buildings[bid];d=self.man[b['asset']]['footprint'][1];dx,dz=turn((0,d/2+.9),b['yaw']);rear=Point(b['c'][0]+dx,b['c'][1]+dz)
            corridor=LineString([rear,center]);block=corridor.intersection(obstacles.difference(self.polys[bid].buffer(.75)))
            members.append(dict(building=bid,rear_access_point=xy(rear),rear_faces_shared_court=block.is_empty,rear_door_claimed=False,note='Back-of-plot connection only; closed residences have no playable rear door.'))
        routes=[('west',[(-60,810),(-118,810),(-130,810)]),('east',[(-60,810),(0,810),(0,765),(0,735)])]
        exits=[]
        for side,points in routes:
            path=LineString(points);hits=[bid for bid,g in self.polys.items() if path.buffer(.75,cap_style=2).intersection(g).area>EPS]
            end=Point(points[-1]);exits.append(dict(side=side,path=points,clear_width_m=1.5,blocking_buildings=hits,water_overlap_m2=round(path.buffer(.75).intersection(self.water).area,4),reaches_public_road=end.distance(self.road_space)<1.5,pass_plan=not hits and path.buffer(.75).intersection(self.water).area<EPS and end.distance(self.road_space)<1.5))
        return dict(member_count=len(ids),members=members,exits=exits,two_plan_exits=len(exits)==2 and all(e['pass_plan'] for e in exits),limitation='2D plot/road test. Garden props, actual grade and real-player traversal require runtime verification.')
    def candidate(self,b,moved):
        # Other buildings stay at current coordinates, except earlier jointly
        # accepted moves. No candidate is approved in isolation from its peers.
        others=unary_union([self.body(moved.get(i,o)) for i,o in self.buildings.items() if i!=b['id']])
        reserves=unary_union(list(self.landscape.values()))
        walls=unary_union([rect(n['c'],(32,7),n['yaw']) for n in self.scene.values() if n['asset'].endswith('/city_wall_32.glb')])
        base_y=b.get('y',self.scene.get(b['id'],{}).get('y',self.grade(*b['c'])+.6)-.6)
        offsets=sorted([(dx,dz) for dx in range(-140,141,2) for dz in range(-140,141,2) if dx or dz],key=lambda q:q[0]**2+q[1]**2)
        for dx,dz in offsets:
            trial=copy.deepcopy(b);trial['c']=[round(b['c'][0]+dx,3),round(b['c'][1]+dz,3)];body=self.body(trial);outer=self.exterior(trial)
            if body.intersection(self.road_space).area>EPS or body.distance(self.road_space)<1:continue
            if outer.difference(self.entry_aprons(trial)).distance(self.road_space)<.25:continue
            if outer.distance(others)<2 or body.distance(self.water)<3 or outer.distance(walls)<1:continue
            if outer.intersection(reserves).area>EPS:continue
            if not (-940<trial['c'][0]<275 and 210<trial['c'][1]<980):continue
            conflicts=self.terrain_conflicts(self.terrain_for_building(trial))
            if not conflicts:
                return trial,dict(c=trial['c'],yaw=trial['yaw'],grade=base_y,offset_m=round(math.hypot(dx,dz),3),body_road_clearance_m=round(body.distance(self.road_space),3),water_clearance_m=round(body.distance(self.water),3),neighbor_clearance_m=round(outer.distance(others),3),terrain_conflicts=[],candidate_scope='same grade/yaw, complete manifest body and visual envelope, current buildings plus earlier proposals, rendered road+walk cells, water, squares/gardens, wall, and authored road-grade/flatten halo conflicts; not terrain-runtime validated')
        return None,dict(c=None,reason='No same-grade candidate within 140m square meets all checks. Requires coordinated grade/road/parcel redesign.')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--cathedral-width',type=float);ap.add_argument('--no-candidates',action='store_true');args=ap.parse_args()
    plan=read('docs/city_v5/layout.json');scenario=[]
    if args.cathedral_width:
        for s in plan['squares']:
            if s['id']=='cathedral_square':s['size'][0]=args.cathedral_width;scenario.append({'cathedral_square_width':args.cathedral_width})
    audit=Audit(plan);definite,risks=audit.building_issues();terrain=audit.terrain_conflicts();gates=audit.gate_report();station=audit.station_report()
    mismatches=[]
    for bid,b in audit.buildings.items():
        n=audit.scene.get(bid)
        if n is None or math.dist(b['c'],n['c'])>.02 or abs(((b['yaw']-n['yaw']+180)%360)-180)>.01:mismatches.append(bid)
    slopes=[]
    for r in plan['roads']:
        for a,b in zip(r['pts'],r['pts'][1:]):
            y0,y1=audit.road_h(a),audit.road_h(b);pct=100*abs(y1-y0)/math.dist(a,b)
            if pct>12:slopes.append(dict(road=r['id'],a=a,b=b,y0=round(y0,2),y1=round(y1,2),authored_grade_percent=round(pct,2),severity='planned_slope_risk',note='Endpoint design grades only; post-road flatten writes can produce a different actual slope.'))
    proposals={};moved={}
    if not args.no_candidates:
        for bid in sorted({v['building'] for v in definite}):
            trial,detail=audit.candidate(audit.buildings[bid],moved);proposals[bid]=detail
            if trial:moved[bid]=trial
    projected=copy.deepcopy(plan)
    for i,b in enumerate(projected['buildings']):
        if b['id'] in moved:projected['buildings'][i]=moved[b['id']]
    joint=[]
    if moved:
        projected_audit=Audit(projected);joint=[v for v in projected_audit.building_issues()[0] if v['building'] in moved or v.get('other') in moved]
    report=dict(scope='Static 2D geometry and authored terrain-write audit; no full-city runtime pass claimed.',sources={f:sha(f) for f in ['docs/city_v5/layout.json','tools/gen_solenne.gd','scenes/zones/tidewind_highlands.tscn','assets/models/city_v5/architecture/manifest.json','assets/models/city_v5/landmarks/manifest.json']},scenario_overrides=scenario,counts={'buildings':len(plan['buildings']),'roads':len(plan['roads']),'definite_overlap_records':len(definite),'setback_visual_risks':len(risks),'terrain_write_or_blend_records':len(terrain)},scene_layout_transform_mismatches=mismatches,confirmed_plan_conflicts=definite,setback_and_visual_risks=risks,terrain_write_conflicts=terrain,authored_slope_risks=slopes,gate_wall_connections=gates,station_court=station,relocation_candidates=proposals,joint_candidate_conflicts=joint,limitations=['Native architectural L/U polygons used; landmark manifest body rectangles reserve their structural footprint.','Visual AABB eaves/trim treated as risk, not certain ground obstruction. Ordinary external entry aprons excluded from that risk.','Road cells reproduce 4m water skip and junction sidewalk suppression; curb-only overhangs are not a separate test.','Terrain records inspect writes made after road grading. They do not measure final terrain samples or wall-clock Player traversal.','Candidate elevations are retained, not certified against actual terrain, utility access or views.','Station paths test the shared rear court and two street routes, not rear doors for sealed residences.'])
    report['final_road_protection_present']='The narrow final pass protects' in audit.generator
    if report['final_road_protection_present']:
        report['limitations'].append('Generator now reapplies the full road corridor after parcel earthworks. Terrain records show pre-protection grade mismatches, not final-road failures; measure the final saved TerrainData with check_city_v5_terrain.tscn.')
    out=ROOT/'docs/city_v5/layout_audit.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'counts':report['counts'],'confirmed':definite,'terrain_core':[v for v in terrain if v['severity']=='terrain_write_conflict'],'candidates':proposals,'joint_candidate_conflicts':joint,'gates':gates,'station':station},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
