"""Dawnbell roofs: thick, individually shaped clay tiles in batched meshes.

All dimensions are metres. Public builders return their newly created objects.
The caller supplies geometry.COL / geometry.ROOT and installs its materials.
Pitched sections run along Y and end exactly at +/- length/2, for repetition.
The roof eave datum is Z=0; a roof's rise measures from that datum to its ridge.
"""
import math
import random
import bpy
import bmesh
from mathutils import Vector
import geometry as G


class _Batch:
    def __init__(self, name, mats=('terracotta', 'tile_dark', 'tile_light')):
        self.name = name
        self.mats = mats
        self.verts, self.faces, self.indices = [], [], []

    def part(self, verts, faces, mat=0):
        offset = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(offset + i for i in f) for f in faces)
        self.indices.extend([mat] * len(faces))

    def build(self):
        if not self.faces:
            return None
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.verts, [], self.faces)
        me.update()
        for key in self.mats:
            me.materials.append(G.material(key))
        for face, index in zip(me.polygons, self.indices):
            face.material_index = index
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(me)
        bm.free()
        me.update()
        uv = me.uv_layers.new(name='UVMap')
        for face in me.polygons:
            axis = max(range(3), key=lambda k: abs(face.normal[k]))
            axes = [k for k in range(3) if k != axis]
            for loop in face.loop_indices:
                co = me.vertices[me.loops[loop].vertex_index].co
                uv.data[loop].uv = (co[axes[0]], co[axes[1]])
        ob = bpy.data.objects.new(self.name, me)
        G.COL.objects.link(ob)
        if G.ROOT:
            ob.parent = G.ROOT
        ob['construction'] = 'Batched solid clay tiles; staggered overlapping courses'
        return ob


def _start():
    return set(G.COL.objects)


def _finish(before):
    return [ob for ob in G.COL.objects if ob not in before]


def _clip(poly, distance):
    """Clip a convex polygon against signed half-space distance >= 0."""
    result = []
    for a, b in zip(poly, poly[1:] + poly[:1]):
        da, db = distance(a), distance(b)
        if da >= -1e-9:
            result.append(a)
        if (da > 0) != (db > 0):
            t = da / (da - db)
            result.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
    clean = []
    for p in result:
        if not clean or math.dist(p, clean[-1]) > 1e-7:
            clean.append(p)
    if len(clean) > 1 and math.dist(clean[0], clean[-1]) < 1e-7:
        clean.pop()
    return clean


def _tile(batch, polygon, mapping, r0, r1, color=0, relief=.06):
    if len(polygon) < 3:
        return
    area = abs(sum(a[0]*b[1] - a[1]*b[0] for a,b in zip(polygon,polygon[1:]+polygon[:1])))
    if area < .00005:
        return
    n = len(polygon)
    cx = sum(p[0] for p in polygon) / n
    cy = sum(p[1] for p in polygon) / n
    verts = []
    # Each clay tile has a closed underside, an actual exposed lip, bevel and crown.
    for level in (0, 1, 2):
        for r, y in polygon:
            if level == 2:
                delta = Vector((cx-r, cy-y))
                if delta.length > .012:
                    delta.normalize()
                    r, y = r+delta.x*.009, y+delta.y*.009
            co = Vector(mapping(r, y))
            weight = min(1.0, max(0.0, (r-r0)/max(r1-r0,.001)))
            co.z += .008 if level == 0 else .032 + relief*weight + (0.009 if level == 2 else 0)
            verts.append(tuple(co))
    center = Vector(mapping(cx, cy))
    center.z += .049 + relief*min(1.0,max(0.0,(cx-r0)/max(r1-r0,.001)))
    verts.append(tuple(center))
    faces = [tuple(range(n-1,-1,-1))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    faces += [(i+n,(i+1)%n+n,(i+1)%n+2*n,i+2*n) for i in range(n)]
    faces += [(i+2*n,(i+1)%n+2*n,3*n) for i in range(n)]
    batch.part(verts, faces, color)


def _tiles(batch, run, length, mapping, seed, triangular=False, pitch=.43, tilewidth=.50):
    rng = random.Random(seed)
    count = max(1, math.ceil(run/pitch))
    spacing = run/count
    # A globally regular half-bond survives repeating 4 m modules at their seams.
    width = tilewidth
    for row in range(count):
        high = max(0, run-(row+1)*spacing)
        low = run-row*spacing
        r0, r1 = high, min(run, low+.10)
        shift = (row % 2)*width*.5
        cmin = math.floor((-length/2-shift)/width)-1
        cmax = math.ceil((length/2-shift)/width)+1
        for col in range(cmin,cmax):
            left, right = col*width+shift+.010, (col+1)*width+shift-.010
            # Eave irregularity is in X only: section end planes remain exact.
            end = r1 + (rng.uniform(-.015,.025) if row == 0 else rng.uniform(-.006,.006))
            c = min(.030, (right-left)*.09, (end-r0)*.08)
            poly = [(r0,left),(end-c,left),(end,left+c),(end,right-c),(end-c,right),(r0,right)]
            poly = _clip(poly,lambda p:p[1]+length/2)
            poly = _clip(poly,lambda p:length/2-p[1])
            if triangular:
                poly = _clip(poly,lambda p:p[0]-p[1])
                poly = _clip(poly,lambda p:p[0]+p[1])
            choice = rng.random()
            color = 1 if choice < .16 else 2 if choice > .76 else 0
            _tile(batch,poly,mapping,r0,end,color,relief=rng.uniform(.035,.057))


def _deck(name, run, length, mapping, triangular=False):
    verts, faces = [], []
    divisions = max(3, math.ceil(run/.40))
    for i in range(divisions+1):
        r = max(.0005,run*i/divisions) if triangular else run*i/divisions
        half = r if triangular else length/2
        for dz in (-.13,-.003):
            for y in (-half,half):
                x,yy,z = mapping(r,y)
                verts.append((x,yy,z+dz))
    for i in range(divisions):
        a,b = 4*i,4*(i+1)
        faces.extend([(a,a+1,b+1,b),(a+2,b+2,b+3,a+3),(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)])
    faces.extend([(0,2,3,1),(4*divisions,4*divisions+1,4*divisions+3,4*divisions+2)])
    return G.mesh(name,verts,faces,'tile_dark')


def _cap(batch,a,b,radius=.185,material=0):
    a,b=Vector(a),Vector(b)
    axis=b-a
    length=axis.length
    if length<.008:return
    axis.normalize()
    u=Vector((axis.y,-axis.x,0))
    if u.length<.001:u=Vector((1,0,0))
    u.normalize()
    v=u.cross(axis).normalized()
    if v.z<0:v=-v
    seg=7
    verts=[]
    for end in (a,b):
        for rad in (radius,radius-.045):
            for j in range(seg+1):
                angle=math.pi*j/seg
                verts.append(tuple(end+u*(math.cos(angle)*rad)+v*(math.sin(angle)*rad)))
    n=seg+1
    faces=[]
    for j in range(seg):
        faces += [(j,j+1,j+1+2*n,j+2*n),(j+n,j+3*n,j+1+3*n,j+1+n),
                  (j,j+n,j+1+n,j+1),(j+2*n,j+1+2*n,j+1+3*n,j+3*n)]
    faces += [(0,2*n,3*n,n),(n-1,2*n-1,4*n-1,3*n-1)]
    batch.part(verts,faces,material)


def _caps(batch,a,b,seed=0,radius=.185):
    a,b=Vector(a),Vector(b)
    count=max(1,math.ceil((b-a).length/.54))
    rng=random.Random(seed)
    gap=min(.007,.1*(b-a).length/count)
    vector=(b-a).normalized()
    for i in range(count):
        start=a+(b-a)*i/count+vector*(gap if i else 0)
        end=a+(b-a)*(i+1)/count-vector*(gap if i<count-1 else 0)
        _cap(batch,start,end,radius,2 if rng.random()>.7 else 0)


def _pitched(width,length,rise,seed,overhang=.45,eave=0,name='ABY_Roof'):
    run=width/2+overhang
    sag=min(.10,run*.024)
    batch=_Batch(name+'_SolidClayTiles')
    for side in (-1,1):
        mapping=lambda r,y,s=side:(s*r,y,eave+rise*(1-r/run)-sag*math.sin(math.pi*r/run))
        _deck(name+'_TimberSheathing',run,length,mapping)
        _tiles(batch,run,length,mapping,seed+(13 if side<0 else 71),pitch=.40 if width<2 else .43,tilewidth=.28 if width<2 else .50)
        G.box(name+'_ThickEave',(.20,length,.24),(side*run,0,eave-.09),'timber',.026)
        # Sparse carved strokes are visible on the vertical face of the timber.
        if length>.7:
            for k in range(2):
                y0=-length*.41+k*.10
                y1=length*.32+k*.11
                G.line(name+'_WoodCarvedStroke',[(side*(run+.101),y0,eave-.09+k*.065),
                       (side*(run+.103),(y0+y1)/2,eave-.08+k*.065),(side*(run+.101),y1,eave-.095+k*.065)],.008,'wood')
    batch.build()
    caps=_Batch(name+'_SegmentedRoundRidge')
    _caps(caps,(0,-length/2,eave+rise+.033),(0,length/2,eave+rise+.033),seed,radius=.13 if width<2 else .19)
    caps.build()


def pitched_roof(width=8,length=4,rise=None,seed=0):
    """Repeatable gable roof; width excludes .45 m eaves, ridge lies along Y.

    No end fascia is baked into repeatable sections. Add gable_fascia() only
    to the exposed front/back of the fully assembled roof.
    """
    if width<=0 or length<=0:raise ValueError('Roof dimensions must be positive')
    before=_start()
    rise=width*.425 if rise is None else rise
    _pitched(width,length,rise,seed)
    return _finish(before)


def gable_fascia(width=8,rise=None,depth=.24):
    """Exposed gable edge centred on Y=0; place once at each building end."""
    before=_start()
    rise=width*.425 if rise is None else rise
    run=width/2+.45
    for side in (-1,1):
        pts=[(side*run,-.08),(side*run,-.31),(0,rise-.25),(0,rise-.02)]
        G.profile('ABY_Gable_DeepCarvedFascia',pts,depth,'timber')
        G.line('ABY_Gable_WoodScore',[(side*(run-.10),-depth/2-.006,-.12),
               (side*run*.52,-depth/2-.008,rise*.46-.14),(side*.17,-depth/2-.006,rise-.23)],.009,'wood')
    return _finish(before)


def shed_roof(run=2.8,length=4,rise=1.4,seed=0):
    """Repeatable lean-to: high point X=0,Z=rise; low point X=run,Z=0."""
    if min(run,length)<=0:raise ValueError('Roof dimensions must be positive')
    before=_start()
    mapping=lambda r,y:(r,y,rise*(1-r/run)-.045*math.sin(math.pi*r/run))
    _deck('ABY_Shed_Sheathing',run,length,mapping)
    tiles=_Batch('ABY_Shed_SolidClayTiles')
    _tiles(tiles,run,length,mapping,seed)
    tiles.build()
    G.box('ABY_Shed_LowThickEave',(.20,length,.22),(run,0,-.075),'timber',.024)
    G.box('ABY_Shed_HighWallBeam',(.16,length,.18),(0,0,rise-.11),'timber',.018)
    return _finish(before)


def hip_roof(width=4.8,rise=2.2,seed=0):
    """Square bell-tower pavilion roof, including eaves, hip caps and finial.

    Width includes the full tiled footprint. Place on a narrower tower wall.
    """
    if width<=0:raise ValueError('Roof width must be positive')
    before=_start()
    run=width/2
    tiles=_Batch('ABY_Hip_SolidClayTiles')
    caps=_Batch('ABY_Hip_SegmentedHipCaps')
    for side in range(4):
        angle=side*math.pi/2
        c,s=math.cos(angle),math.sin(angle)
        mapping=lambda r,y,c=c,s=s:(c*r-s*y,s*r+c*y,rise*(1-r/run)-.06*math.sin(math.pi*r/run))
        _deck('ABY_Hip_TimberSheathing',run,width,mapping,triangular=True)
        _tiles(tiles,run,width,mapping,seed+side*101,triangular=True)
        if side%2:
            G.box('ABY_Hip_ThickEave',(width,.23,.22),(0,run*(1 if side==1 else -1),-.085),'timber',.025)
        else:
            G.box('ABY_Hip_ThickEave',(.23,width,.22),(run*(1 if side==0 else -1),0,-.085),'timber',.025)
        corner=(c*run-s*run,s*run+c*run,.06)
        _caps(caps,(0,0,rise+.06),corner,seed+side,radius=.14)
    tiles.build()
    caps.build()
    G.lathe('ABY_Hip_PeakFinial',[(0,rise+.08),(.17,rise+.08),(.17,rise+.16),(.095,rise+.22),(.06,rise+.44),(0,rise+.57)],'timber',8)
    return _finish(before)


def spire_roof(width=4.8,rise=4.5,seed=0):
    """Tall square spire with concave tiled faces and a slightly turned eave.

    Width is the full footprint including eaves (there is no added .45 m
    overhang). Datum Z=0 is below the wooden eave; the pointed deck reaches
    Z=rise. Individual clay/slate lips and ridge caps extend slightly above
    the deck. No finial or cross is included. Palette keys intentionally match
    the other roof builders so the game slate palette can replace warm clay.
    """
    if width <= 0 or rise <= .35:
        raise ValueError('Spire width must be positive and rise greater than .35 m')
    before=_start()
    run=width/2
    tiles=_Batch('ABY_Spire_SolidOverlappingTiles')
    caps=_Batch('ABY_Spire_CurvedCornerRidges')
    # Steeper near the peak, softer near the eaves: the silhouette follows the
    # approved tall spire rather than scaling the previous straight pavilion.
    def height(r,y=0):
        t=min(1.0,max(0.0,r/run))
        f=min(1.0,max(0.0,(t-.80)/.20))
        upturn=.025*f*f*(3-2*f)
        corner=.045*(min(1.0,abs(y)/run)**6)*(t**6)
        return .27+(rise-.27)*((1-t)**1.40)+upturn+corner
    # Keep projected course pitch small enough to produce ~14 rows, not six
    # oversized tiles stretched vertically up a steep 4.5 m tower roof.
    rows=max(9,math.ceil(math.hypot(run,rise)/.39))
    pitch=run/rows
    for side in range(4):
        angle=side*math.pi/2
        c,s=math.cos(angle),math.sin(angle)
        mapping=lambda r,y,c=c,s=s:(c*r-s*y,s*r+c*y,height(r,y))
        _deck('ABY_Spire_CurvedSheathing',run,width,mapping,triangular=True)
        _tiles(tiles,run,width,mapping,seed+side*103,triangular=True,
               pitch=pitch,tilewidth=.36 if width<6 else .43)
        # Thick wooden edge follows the shallow lift at both outer corners.
        verts,faces=[],[]
        subdivisions=10
        for j in range(subdivisions+1):
            y=-run+width*j/subdivisions
            top=height(run,y)-.045
            for rr,z in [(run-.20,top-.22),(run-.012,top-.22),
                         (run-.012,top),(run-.20,top)]:
                verts.append((c*rr-s*y,s*rr+c*y,z))
        for j in range(subdivisions):
            a,b=4*j,4*(j+1)
            faces.extend([(a,a+1,b+1,b),(a+1,a+2,b+2,b+1),
                          (a+2,a+3,b+3,b+2),(a+3,a,b,b+3)])
        faces.extend([(3,2,1,0),(4*subdivisions,4*subdivisions+1,
                     4*subdivisions+2,4*subdivisions+3)])
        G.bevel(G.mesh('ABY_Spire_TurnedThickEave',verts,faces,'timber'),.015)
        # Caps follow the same non-linear hip profile, not a straight line
        # that would otherwise float above the middle of the concave roof.
        capsteps=max(rows,12)
        for j in range(capsteps):
            ra,rb=run*j/capsteps,run*(j+1)/capsteps
            pa=Vector((c*ra-s*ra,s*ra+c*ra,height(ra,ra)+.035))
            pb=Vector((c*rb-s*rb,s*rb+c*rb,height(rb,rb)+.035))
            direction=(pb-pa).normalized()
            if j:pa+=direction*.004
            if j<capsteps-1:pb-=direction*.004
            radius=.080+.038*(j+.5)/capsteps
            _cap(caps,pa,pb,radius,2 if (j+side)%5==0 else 0)
    tile_object=tiles.build()
    caps.build()
    if tile_object:
        tile_object['roof_profile']='Concave tall square spire; slight eave turn-up'
        tile_object['course_count']=rows
        tile_object['nominal_width']=width
        tile_object['nominal_rise']=rise
    return _finish(before)


def dormer(width=1.05,depth=.7,height=.85):
    """Upright triangular dormer. Front faces -Y; local sill is at Z=0.

    Place upright on a slope (do not tilt with the tiles); rotate around Z to
    face outward. Its rear triangle is intended to intersect the host roof.
    """
    before=_start()
    G.profile('ABY_Dormer_RecessShadow',[(-width/2,0),(width/2,0),(0,height)],depth,'timber')
    front=-depth/2-.018
    for i in range(4):
        z=.12+i*height*.155
        half=width*.5*(1-z/height)-.055
        if half>0:
            G.box('ABY_Dormer_RecessedLouver',(half*2,.055,.045),(0,front-.014,z),'wood',.005)
    for a,b in [((-width/2,front-.048,.005),(0,front-.048,height)),
                ((0,front-.048,height),(width/2,front-.048,.005)),
                ((-width/2,front-.048,.005),(width/2,front-.048,.005))]:
        G.beam('ABY_Dormer_HeavyTriangleFrame',a,b,.09,'wood')
    G.beam('ABY_Dormer_CentreMullion',(0,front-.05,.05),(0,front-.05,height-.095),.055,'timber')
    _pitched(width,depth+.10,height,11,overhang=.075,eave=.025,name='ABY_DormerCap')
    return _finish(before)


def ridge_cross(size=1):
    before=_start()
    G.box('ABY_RidgeCross_Upright',(.105*size,.115*size,size),(0,0,size*.5),'timber',.014*size)
    G.box('ABY_RidgeCross_Arms',(.55*size,.12*size,.105*size),(0,0,size*.70),'wood',.014*size)
    G.box('ABY_RidgeCross_CentrePeg',(.16*size,.145*size,.15*size),(0,-.012*size,size*.70),'timber',.015*size)
    return _finish(before)


def roof_chimney():
    """Short plaster chimney with shadowed vent, corner supports and tile cap."""
    before=_start()
    G.box('ABY_Chimney_PlasterShaft',(.48,.52,.92),(0,0,.46),'plaster',.022)
    G.box('ABY_Chimney_BaseCollar',(.59,.62,.14),(0,0,.09),'sandstone',.024)
    G.box('ABY_Chimney_VentShadow',(.44,.48,.20),(0,0,1.01),'timber')
    for x in (-.205,.205):
        for y in (-.225,.225):
            G.box('ABY_Chimney_VentCorner',(.08,.08,.23),(x,y,1.02),'sandstone',.008)
    _pitched(.50,.65,.15,5,overhang=.065,eave=1.145,name='ABY_ChimneyCap')
    return _finish(before)
