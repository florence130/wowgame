"""Shared, explicit street elevations; geometric intersections are real graph nodes.

This runs after parcel authoring so road subdivision never changes which parcels
are admitted. No dependency on raster terrain or the previous generated scene.
"""
import math
from collections import defaultdict


def solve_network(plan):
    roads = plan['roads']
    by_id = {r['id']: r for r in roads}
    # A high terrace cul-de-sac must stop before the lower harbour corridor.
    by_id['cathedral_front']['pts'][-1] = [-760, 650]
    # The western cross street meets the actual high street centreline.
    by_id['west_residential_lane']['pts'][0] = [-900 + 5 * 90 / 130, 540]
    profiles = {
        'east_crown': [26,26,26,26,26,42,50,55.875],
        'north_ring': [60,60,60,26,26,26,26],
        'civic_west': [26,26,26,26],
        'civic_cross': [26,26,26,26,26],
        'civic_south': [26,26,26,20,20,26],
        'market_axis': [26,26,26,20],
        'market_east': [26,26,26,20],
        'bridge_station': [26,20,20,20,18,18],
        'east_embankment': [26,22,20,20,20,20,18,18,18],
        'station_front': [18]*5,
        'station_south': [18]*3,
        'station_west': [18]*2,
        'west_highstreet': [60,52,38,38,38,38],
        'palace_approach': [60,60,55.875,44.875,43.5,38,38,38],
        'academy_approach': [44,44,42],
        'academy_lower': [42,34],
        'west_cross': [38,38,30,34,34,26],
        'cathedral_front': [38,38,38],
        'harbor_ramp': [30,28,24,20,16,13],
        'western_quay': [13]*4,
        'north_quay': [13]*5,
        'east_quay': [18]*5,
        'station_to_quay': [18]*4,
        'cathedral_garden': [38]*2,
        'terrace_lane': [60,50,50-20*90/(90+math.hypot(20,40)),30],
        'west_residential_lane': [52-14*90/130,43.5,50-20*90/(90+math.hypot(20,40)),34,26],
        'tavern_walk': [22,20,13],
        'academy_lower_court': [44]*5,
        'station_court_w': [18]*3,
        'station_court_e': [18]*4,
    }
    for r in roads:
        if r['id'].startswith('river_'):
            profiles[r['id']] = [18] * len(r['pts'])
        assert len(profiles[r['id']]) == len(r['pts']), r['id']

    def key(p): return (round(p[0], 5), round(p[1], 5))
    def dot(a,b): return a[0]*b[0]+a[1]*b[1]
    def sub(a,b): return a[0]-b[0],a[1]-b[1]
    def cross(a,b): return a[0]*b[1]-a[1]*b[0]
    segments=[]
    for r in roads:
        levels=profiles[r['id']]
        for i,(a,b) in enumerate(zip(r['pts'],r['pts'][1:])):
            segments.append(dict(road=r,index=i,a=a,b=b,h0=levels[i],h1=levels[i+1],cuts={0.,1.}))
    for i,s in enumerate(segments):
        u=sub(s['b'],s['a'])
        for t in segments[i+1:]:
            v=sub(t['b'],t['a']);delta=sub(t['a'],s['a']);det=cross(u,v)
            if abs(det)>1e-8:
                f=cross(delta,v)/det;g=cross(delta,u)/det
                if -1e-7<=f<=1+1e-7 and -1e-7<=g<=1+1e-7:
                    s['cuts'].add(max(0.,min(1.,f)));t['cuts'].add(max(0.,min(1.,g)))
            elif abs(cross(delta,u))<1e-6:
                for p in (t['a'],t['b']):
                    f=dot(sub(p,s['a']),u)/dot(u,u)
                    if 0<f<1:s['cuts'].add(f)
                for p in (s['a'],s['b']):
                    f=dot(sub(p,t['a']),v)/dot(v,v)
                    if 0<f<1:t['cuts'].add(f)
    values=defaultdict(list);splits=defaultdict(list);owners=defaultdict(set)
    flat_ids={r['id'] for r in roads if max(profiles[r['id']])-min(profiles[r['id']])<.001}
    fixed={}
    for s in segments:
        for f in sorted(s['cuts']):
            q=key((s['a'][0]+(s['b'][0]-s['a'][0])*f,s['a'][1]+(s['b'][1]-s['a'][1])*f))
            h=s['h0']+(s['h1']-s['h0'])*f
            values[q].append(h);owners[q].add(s['road']['id'])
            if not splits[s['road']['id']] or splits[s['road']['id']][-1]!=q:splits[s['road']['id']].append(q)
            if s['road']['id'] in flat_ids:fixed[q]=h
    # Protect the level approaches to the palace / academy and bridge decks.
    fixed.update({(-790.,355.):60,(-790.,420.):60,(-510.,330.):44,(-510.,405.):44,
                  (20.,535.):20,(20.,580.):20,(20.,650.):20,(219.,536.):20,(200.,580.):20,(180.,628.):20})
    heights={q:sum(v)/len(v) for q,v in values.items()}
    heights.update({q:h for q,h in fixed.items() if q in heights})
    edges={tuple(sorted((a,b))) for pts in splits.values() for a,b in zip(pts,pts[1:]) if a!=b}
    # Projection onto shared edge grade constraints removes inconsistent legacy
    # overrides while retaining flat public grounds. Real junctions have one Y.
    for iteration in range(3000):
        maximum=0.
        for a,b in sorted(edges):
            limit=.15*math.dist(a,b);delta=heights[b]-heights[a]
            excess=abs(delta)-limit
            if excess<=1e-8:continue
            maximum=max(maximum,excess);sign=1 if delta>0 else -1
            if a in fixed and b in fixed:
                raise ValueError(f'Incompatible fixed street grades: {a} {b}')
            if a in fixed:heights[b]-=sign*excess
            elif b in fixed:heights[a]+=sign*excess
            else:
                heights[a]+=sign*excess*.5;heights[b]-=sign*excess*.5
        if maximum<1e-7:break
    else:raise ValueError('Street elevation solve did not converge')
    for r in roads:
        r['pts']=[list(q) for q in splits[r['id']]]
        r['heights']=[round(heights[q],6) for q in splits[r['id']]]
    plan['road_levels']=[[q[0],q[1],round(h,6)] for q,h in sorted(heights.items())]
    plan['road_network']={
        'version':1,'nodes':len(heights),'edges':len(edges),
        'junctions':[{'c':list(q),'y':round(heights[q],6),'roads':sorted(ids)} for q,ids in owners.items() if len(ids)>1],
        'max_authored_grade_percent':round(max(abs(heights[a]-heights[b])/math.dist(a,b)*100 for a,b in edges),5),
        'method':'All geometric crossings and collinear overlaps share explicit elevation nodes; grade-constrained graph.'}
