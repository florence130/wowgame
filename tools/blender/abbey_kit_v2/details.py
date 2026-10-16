"""Concept-derived abbey details, in metres, outward normal +Y.

Caller supplies geometry.COL, geometry.ROOT and lit geometry.material(). All
builders return a list of ordinary mesh objects, generally one mesh per module.
The window glass never extends beyond y=.032. No lights or scene are changed.
"""
import math
import random
import bpy
from mathutils import Vector
import geometry as G


def _merge(objects, name):
    """Bake independent primitives, bevels and curves to one multi-material mesh."""
    objects = [o for o in objects if o is not None]
    if not objects:
        return []
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    vertices, faces, face_mats, mats = [], [], [], []
    for o in objects:
        evaluated = o.evaluated_get(deps)
        data = evaluated.to_mesh()
        if not data:
            continue
        offset = len(vertices)
        matrix = o.matrix_basis
        vertices.extend(tuple(matrix @ v.co) for v in data.vertices)
        indices = []
        # Use original datablocks: evaluated materials become dangling pointers
        # after a later dependency-graph update in Blender 5.2.
        for mat in o.data.materials:
            if mat not in mats:
                mats.append(mat)
            indices.append(mats.index(mat))
        for poly in data.polygons:
            faces.append(tuple(offset + i for i in poly.vertices))
            face_mats.append(indices[poly.material_index] if indices else 0)
        evaluated.to_mesh_clear()
    result = G.mesh(name, vertices, faces, None)
    for mat in mats:
        result.data.materials.append(mat)
    # G.mesh runs a normal-only bmesh pass: polygon ordering is preserved.
    for poly, idx in zip(result.data.polygons, face_mats):
        poly.material_index = idx
    for o in objects:
        bpy.data.objects.remove(o, do_unlink=True)
    result['asset_family'] = 'Abbey concept details v2'
    return [result]


def _strip(name, a, b, y, depth, mat='sandstone', bevel=.015):
    o = G.profile(name, [a[0], a[1], b[1], b[0]], depth, mat, y)
    if bevel:
        G.bevel(o, bevel)
    return o


def stone_arch(width=2.4, spring=2.35, bottom=0, depth=.55, thickness=.30):
    """Round arch opening width, spring height and bottom; blockwork outside it."""
    parts = []
    r = width / 2
    rng = random.Random(903)
    rows = max(2, round((spring-bottom)/.42))
    pitch = (spring-bottom)/rows
    for side in (-1, 1):
        for i in range(rows):
            extra = .035 if i % 3 == 0 else 0
            parts.append(G.box('Arch jamb ashlar', (thickness+extra, depth+rng.uniform(-.024,.024), pitch-.014),
                               (side*(r+(thickness+extra)/2), .012 if i % 3 == 0 else 0,
                                bottom+(i+.5)*pitch),
                               ['sandstone','stone_light','sandstone','stone_dark'][i % 4], .020))
        parts.append(G.box('Arch square plinth', (thickness+.13,depth+.14,.19),
                           (side*(r+thickness/2),.025,bottom+.095),'sandstone',.019))
        parts.append(G.box('Arch impost ledge', (thickness+.16,depth+.11,.13),
                           (side*(r+thickness/2),.027,spring-.012),'stone_light',.018))
        parts.append(G.box('Arch impost lower', (thickness+.065,depth+.055,.095),
                           (side*(r+thickness/2),.014,spring-.106),'sandstone',.012))
    n = 13
    gap = .009 / max(r,.2)
    for i in range(n):
        a = math.pi*i/n + gap/2
        b = math.pi*(i+1)/n - gap/2
        outer = r+thickness+(.045 if i == n//2 else rng.uniform(-.007,.009))
        pts = [(r*math.cos(a),spring+r*math.sin(a)),
               (outer*math.cos(a),spring+outer*math.sin(a)),
               (outer*math.cos(b),spring+outer*math.sin(b)),
               (r*math.cos(b),spring+r*math.sin(b))]
        o = G.profile('Arch separate wedge',pts,depth+(.05 if i==n//2 else 0),
                      ['sandstone','stone_light','sandstone','stone_dark','sandstone'][i%5],
                      .02 if i==n//2 else 0)
        G.bevel(o,.012)
        parts.append(o)
    return _merge(parts,'ABY_Detail_StoneArch')


def pointed_outline(width, height, sill=0, segments=9):
    """CCW X/Z opening. Two radius=width arcs meet at sill+height.

    Vertical spring is sill+height-sqrt(3)*width/2. Keep height >= .87*width.
    Use this exact profile for a wall boolean, with >=.02 clearance if desired.
    """
    r = width/2
    spring = sill+height-math.sqrt(3)*r
    pts = [(-r,sill),(r,sill),(r,spring)]
    pts += [(-r+width*math.cos(math.pi*i/(3*segments)),
             spring+width*math.sin(math.pi*i/(3*segments))) for i in range(1,segments+1)]
    pts += [(r+width*math.cos(2*math.pi/3+math.pi*i/(3*segments)),
             spring+width*math.sin(2*math.pi/3+math.pi*i/(3*segments))) for i in range(1,segments+1)]
    return pts


def pointed_window(width=1.05,height=2.3,sill=.8):
    """Deep ashlar frame outside the opening, inset colored glass and leadwork."""
    parts=[]
    t=.14
    r=width/2
    spring=sill+height-math.sqrt(3)*r
    inner=pointed_outline(width,height,sill)
    # A genuinely thin glass panel, fully contained in the requested opening.
    parts.append(G.profile('Pointed turquoise glazing',inner,.028,'glass',.018))
    # Honey lower lights, independently thick and with dark leading in front.
    for side in (-1,1):
        parts.append(G.box('Pointed honey lower pane',(width*.41,.018,(spring-sill)*.69),
                           (side*width*.24,.027,sill+(spring-sill)*.345+.025),'glass_amber'))
    # Straight side stone courses.
    rows=max(2,round((spring-sill)/.39))
    for side in (-1,1):
        for k in range(rows):
            parts.append(G.box('Window ashlar jamb',(t,.29,(spring-sill)/rows-.012),
                               (side*(r+t/2),.075,sill+(k+.5)*(spring-sill)/rows),
                               'stone_light' if k%3==0 else 'sandstone',.010))
    # Stone voussoirs follow the same two arcs as the wall cutter.
    for side in (-1,1):
        for i in range(5):
            a=math.pi*i/15+.004
            b=math.pi*(i+1)/15-.004
            # Right curve center=-r, mirrored for the left half.
            def p(angle,rad):
                return (side*(-r-(rad-width)/2+rad*math.cos(angle)),spring+rad*math.sin(angle))
            pts=[p(a,width),p(a,width+2*t),p(b,width+2*t),p(b,width)]
            o=G.profile('Pointed wedge stone',pts,.30,'stone_light' if i%3==0 else 'sandstone',.078)
            parts.append(G.bevel(o,.008))
    parts.append(G.box('Projecting stone windowsill',(width+2*t+.14,.43,.14),(0,.105,sill-.052),'stone_light',.018))
    # Bronze/dark wood rebate and central/cross leadwork provide legible depth.
    parts.append(G.line('Pointed inside rebate',[(x,.057,z) for x,z in inner],.025,'timber',True))
    parts.append(G.line('Window central leading',[(0,.063,sill+.025),(0,.063,sill+height-.025)],.022,'timber'))
    for z in [sill+(spring-sill)*.36,sill+(spring-sill)*.72,spring]:
        parts.append(G.line('Window cross leading',[(-r+.015,.063,z),(r-.015,.063,z)],.020,'timber'))
    # Two curved upper tracery ribs create a pointed three-light crown.
    for side in (-1,1):
        pts=[(side*r*(1-u),.063,spring+(height-(spring-sill))*(u**.8)*.60)
             for u in [0,.2,.4,.6,.8,1]]
        parts.append(G.line('Window crown tracery',pts,.023,'timber'))
    return _merge(parts,'ABY_Detail_PointedWindow')


def rose_window(radius=1.1,petals=6):
    """Six/eight almond petals, honey/teal, segmented stone circular frame."""
    parts=[]
    r=radius
    inner=r*.81
    n=18
    for i in range(n):
        a=math.tau*i/n+.006
        b=math.tau*(i+1)/n-.006
        pts=[(inner*math.cos(a),inner*math.sin(a)),(r*math.cos(a),r*math.sin(a)),
             (r*math.cos(b),r*math.sin(b)),(inner*math.cos(b),inner*math.sin(b))]
        parts.append(G.bevel(G.profile('Rose separate ashlar',pts,.32,
                                        ['sandstone','stone_light','sandstone'][i%3],.06),.012))
    circle=[(inner*math.cos(i*math.tau/48),inner*math.sin(i*math.tau/48)) for i in range(48)]
    parts.append(G.profile('Rose turquoise backing glass',circle,.026,'glass',.015))
    parts.append(G.ring('Rose deep inner rebate',inner,0,.034,'timber',48,.053))
    for i in range(petals):
        angle=math.pi/2+math.tau*i/petals
        outline=[]
        for side in (-1,1):
            samples=range(13) if side==-1 else range(12,-1,-1)
            for j in samples:
                u=j/12
                along=inner*(.12+.82*u)
                across=side*inner*(.29*6/petals)*math.sin(math.pi*u)**.82
                outline.append((along*math.cos(angle)-across*math.sin(angle),
                                along*math.sin(angle)+across*math.cos(angle)))
        parts.append(G.profile('Rose almond petal glass',outline,.014,
                               'glass_amber' if i%2==0 else 'glass',.028))
        parts.append(G.line('Rose raised petal lead',[(x,.065,z) for x,z in outline],.022,'timber',True))
    # Central round boss and small cross, as in the concept.
    rr=inner*.17
    pts=[(rr*math.cos(i*math.tau/16),rr*math.sin(i*math.tau/16)) for i in range(16)]
    parts.append(G.profile('Rose central honey glass',pts,.02,'glass_amber',.05))
    parts.append(G.ring('Rose central lead',rr,0,.022,'timber',20,.079))
    parts.append(G.box('Rose center vertical',(r*.027,.030,rr*1.40),(0,.083,0),'timber',.002))
    parts.append(G.box('Rose center horizontal',(rr*1.22,.030,r*.027),(0,.085,0),'timber',.002))
    return _merge(parts,'ABY_Detail_RoseWindow')


def oak_double_door(width=2.35,spring=2.32):
    """Closed round-headed wood gate; board gaps, front iron straps and rings."""
    parts=[]
    r=width/2
    outline=G.arch_outline(width,spring,0,24)
    parts.append(G.profile('Door recessed dark backing',outline,.16,'timber',-.034))
    count=max(8,round(width/.20))
    if count%2: count+=1
    pitch=width/count
    rng=random.Random(92)
    for i in range(count):
        left=-r+i*pitch+.009
        right=-r+(i+1)*pitch-.009
        # More gap at the two-leaf center seam.
        if i==count//2-1: right-=.009
        if i==count//2: left+=.009
        top=[]
        for j in range(4):
            x=right+(left-right)*j/3
            top.append((x,spring+math.sqrt(max(0,r*r-x*x))-.025))
        pts=[(left,.045),(right,.045)]+top
        o=G.profile('Gate individual oak plank',pts,.11,'wood' if i%4 else 'timber',.087+rng.uniform(-.009,.009))
        parts.append(G.bevel(o,.006))
        # Shallow raised grain runs are deliberately broad, readable at game scale.
        x=(left+right)/2+rng.uniform(-.025,.025)
        h=spring+math.sqrt(max(0,r*r-x*x))-.10
        grain=[(x,.148,.16),(x+.015,.15,h*.38),(x-.010,.149,h*.68),(x+.006,.149,h)]
        parts.append(G.line('Oak stylized dark grain',grain,.006,'timber'))
    for side in (-1,1):
        for z in (.29,spring*.82):
            parts.append(G.box('Wrought iron broad hinge strap',(width*.42,.050,.108),
                               (side*width*.255,.186,z),'iron',.012))
            for x in [side*width*.075,side*width*.26,side*width*.425]:
                # Square pyramidal wrought nail head, not shiny spheres.
                verts=[(x-.018,.214,z-.018),(x+.018,.214,z-.018),(x+.018,.214,z+.018),
                       (x-.018,.214,z+.018),(x,.241,z)]
                parts.append(G.mesh('Iron strap forged rivet',verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],'stone_dark'))
        x=side*width*.105
        z=spring*.48
        parts.append(G.box('Door ring escutcheon',(.108,.043,.18),(x,.181,z+.05),'iron',.018))
        ringpts=[(x+.089*math.cos(i*math.tau/16),.234,z-.020+.116*math.sin(i*math.tau/16)) for i in range(16)]
        parts.append(G.line('Heavy hanging door ring',ringpts,.025,'iron',True))
        parts.append(G.box('Door ring pivot',(.040,.055,.047),(x,.226,z+.091),'iron',.008))
    return _merge(parts,'ABY_Detail_OakDoubleDoor')


def quoin_column(height=5,block=.55):
    """Alternating long/short corner ashlars; center on the exterior corner."""
    # A solid corner backing closes the L-shaped void between two butt-jointed
    # wall panels. Alternating decorative quoins alone leave the joint hollow.
    parts=[G.box('Corner masonry backing',(block*1.08,block*1.08,height),(0,0,height/2),'plaster',.008)]
    n=max(2,round(height/(block*.69)))
    h=height/n
    for i in range(n):
        long=block*(1.18 if i%2 else 1.48)
        short=block*(.87 if i%2 else .73)
        dims=(long,short,h-.016) if i%2 else (short,long,h-.016)
        parts.append(G.box('Corner alternating ashlar',dims,(0,0,(i+.5)*h),
                           ['sandstone','stone_light','sandstone','sandstone'][i%4],.025))
    parts.append(G.box('Corner broad base',(block*1.5,block*1.5,.20),(0,0,.10),'stone_dark',.026))
    return _merge(parts,'ABY_Detail_QuoinColumn')


def corbel():
    """Timber corbel: fixing at origin, eave extends +Y, body below origin."""
    parts=[G.box('Corbel wall upright',(.17,.15,.78),(0,.025,-.34),'timber',.012),
           G.box('Corbel eave bracket',(.21,.81,.16),(0,.32,-.045),'timber',.013),
           G.beam('Corbel diagonal brace',(0,.05,-.62),(0,.65,-.12),.145,'wood')]
    for y,z in [(.125,-.57),(.56,-.13)]:
        parts.append(G.box('Corbel wooden pegging',(.025,.050,.052),(.089,y,z),'wood',.006))
    return _merge(parts,'ABY_Detail_TimberCorbel')


def ivy_patch(width=1,height=2,seed=0):
    """Coarse grouped ivy leaves on XZ wall plane; geometry extends toward +Y."""
    rng=random.Random(seed)
    parts=[]
    paths=[]
    for branch in range(4):
        x0=(branch-1.5)*width*.20
        path=[]
        for j in range(9):
            u=j/8
            path.append((x0+math.sin(u*5+branch)*width*.12,.054+u*.01,height*u))
        paths.append(path)
        parts.append(G.line('Ivy climbing woody stem',path,.014 if branch<2 else .010,'timber'))
    verts,faces,idx=[],[],[]
    palette=['leaf','leaf_light','moss']
    # Broad leaves with five pointed lobes and a folded center ridge.
    shape=[(0,-.78),(-.29,-.25),(-.81,-.22),(-.45,.20),(-.49,.64),(-.18,.48),
           (0,1),(.18,.48),(.49,.64),(.45,.20),(.81,-.22),(.29,-.25)]
    count=max(26,round(width*height*47))
    for i in range(count):
        branch=i%4
        u=rng.random()
        # Leaves form overlapping groups along stems with an irregular silhouette.
        cx=(branch-1.5)*width*.20+math.sin(u*5+branch)*width*.12+rng.uniform(-.16,.16)*width
        cz=u*height
        cy=rng.uniform(.072,.14)
        scale=rng.uniform(.105,.175)*min(1.35,max(.72,width**.2))
        rot=rng.uniform(-1.6,1.6)
        base=len(verts)
        verts.append((cx,cy+.033,cz))
        for sx,sz in shape:
            px=(sx*math.cos(rot)-sz*math.sin(rot))*scale
            pz=(sx*math.sin(rot)+sz*math.cos(rot))*scale
            verts.append((cx+px,cy+rng.uniform(-.012,.012),cz+pz))
        mat=i%3 if rng.random()<.60 else 0
        for k in range(len(shape)):
            faces.append((base,base+1+k,base+1+(k+1)%len(shape)))
            idx.append(mat)
    leaves=G.mesh('Ivy grouped folded leaf geometry',verts,faces,None)
    for key in palette: leaves.data.materials.append(G.material(key))
    for poly,m in zip(leaves.data.polygons,idx): poly.material_index=m
    parts.append(leaves)
    return _merge(parts,'ABY_Detail_IvyPatch')


def wall_banner(height=1.8,width=.65):
    """Matte terracotta swallow-point banner with ochre wheat emblem."""
    parts=[]
    top=height
    # Wood wall fixings and a horizontal rod, no specular metal ornament.
    parts.append(G.box('Banner wall bracket',(.10,.12,.30),(0,.075,top+.09),'timber',.012))
    parts.append(G.beam('Banner bracket extension',(0,.08,top+.15),(0,.39,top+.15),.075,'timber'))
    parts.append(G.beam('Banner cross rod',(-width*.65,.39,top),(width*.65,.39,top),.069,'wood'))
    for side in (-1,1):
        parts.append(G.box('Banner wooden rod finial',(.095,.092,.096),(side*width*.65,.39,top),'timber',.015))
    outline=[(-width/2,top-.045),(width/2,top-.045),(width/2,.20),(0,0),(-width/2,.20)]
    parts.append(G.profile('Hanging terracotta cloth',outline,.024,'cloth',.39))
    for x in (-width*.41,width*.41):
        parts.append(G.box('Banner ochre side embroidery',(.018,.012,height*.78),(x,.409,height*.54),'glass_amber'))
    parts.append(G.line('Banner golden wheat stem',[(0,.411,height*.34),(0,.411,height*.77)],.011,'glass_amber'))
    for i in range(3):
        z=height*(.44+i*.083)
        for side in (-1,1):
            x=side*width*.13
            pts=[(0,z-.04),(x,z),(side*width*.19,z+.10),(side*width*.025,z+.047)]
            parts.append(G.profile('Banner wheat grain embroidery',pts,.008,'glass_amber',.414))
    pts=[(0,height*.80),(-width*.07,height*.725),(0,height*.66),(width*.07,height*.725)]
    parts.append(G.profile('Banner wheat crown diamond',pts,.008,'glass_amber',.414))
    return _merge(parts,'ABY_Detail_WallBanner')


def _foliage_crown(name,center,scale,seed=0):
    """An irregular faceted canopy with a scalloped outline, not a UV sphere."""
    rng=random.Random(seed)
    cx,cy,cz=center
    sx,sy,sz=scale
    levels=[(-.68,.36),(-.38,.86),(-.04,1),(.31,.88),(.58,.57),(.80,.14)]
    segments=9
    verts=[]
    for j,(z,r) in enumerate(levels):
        for i in range(segments):
            angle=math.tau*i/segments+(j%2)*.09
            radial=r*(1+rng.uniform(-.17,.17))
            verts.append((cx+sx*radial*math.cos(angle),cy+sy*radial*math.sin(angle),
                          cz+sz*(z+rng.uniform(-.12,.12))))
    faces=[tuple(range(segments-1,-1,-1))]
    for j in range(len(levels)-1):
        for i in range(segments):
            a=j*segments+i
            b=j*segments+(i+1)%segments
            faces.extend([(a,b,b+segments),(a,b+segments,a+segments)])
    faces.append(tuple(range((len(levels)-1)*segments,len(levels)*segments)))
    o=G.mesh(name,verts,faces,None)
    for mat in ('leaf','leaf_light','moss'):o.data.materials.append(G.material(mat))
    for p in o.data.polygons:
        p.material_index=1 if p.center.z>cz+sz*.2 and rng.random()<.60 else (2 if rng.random()<.15 else 0)
    return o


def _broad_leaf_spray(name,centers,scale,seed=0):
    rng=random.Random(seed)
    verts,faces,indices=[],[],[]
    for cx,cy,cz in centers:
        angle=rng.random()*math.tau
        size=scale*rng.uniform(.65,1.25)
        # Folded, broad six-sided leaves: a few visible tips soften canopy edges.
        shape=[(0,-.62),(-.52,-.17),(-.53,.35),(0,1),(.53,.35),(.52,-.17)]
        base=len(verts)
        verts.append((cx,cy,cz+.032))
        for u,v in shape:
            verts.append((cx+size*(u*math.cos(angle)-v*math.sin(angle)),
                          cy+size*(u*math.sin(angle)+v*math.cos(angle)),
                          cz+size*v*.48))
        for i in range(6):
            faces.append((base,base+1+i,base+1+(i+1)%6))
            indices.append(1 if rng.random()<.35 else 0)
    o=G.mesh(name,verts,faces,None)
    for key in ('leaf','leaf_light'):o.data.materials.append(G.material(key))
    for p,idx in zip(o.data.polygons,indices):p.material_index=idx
    return o


def vegetation_shrub(width=1.5,height=1.2,seed=0):
    """Ground-rooted evergreen shrub, 3 broad canopy masses and coarse leaves."""
    rng=random.Random(seed)
    parts=[]
    crown_positions=[(-width*.22,0,height*.50),(width*.23,width*.02,height*.51),
                     (0,width*.055,height*.70)]
    parts.append(G.beam('Shrub main woody trunk',(0,0,0),(0,0,height*.64),width*.06,'timber'))
    for i,p in enumerate(crown_positions):
        parts.append(G.beam('Shrub woody fork',(0,0,height*.18),p,width*.035,'timber'))
        parts.append(_foliage_crown('Shrub broad leaf mass',p,(width*.31,width*.28,height*.38),seed*31+i))
    centers=[]
    for i in range(25):
        a=rng.random()*math.tau
        radial=rng.uniform(.30,.46)*width
        centers.append((radial*math.cos(a),radial*.73*math.sin(a),height*rng.uniform(.45,.81)))
    parts.append(_broad_leaf_spray('Shrub coarse leaf edge',centers,width*.105,seed+56))
    return _merge(parts,'ABY_Vegetation_Shrub')


def cypress(height=4,seed=0):
    """Slender courtyard cypress, tapered scalloped crown and exposed trunk."""
    rng=random.Random(seed)
    parts=[]
    parts.append(G.loft('Cypress tapered woody trunk',[(height*.048,0),(height*.040,height*.26),
                                                      (height*.024,height*.55),(height*.008,height*.84)],
                        'timber',7))
    # One uninterrupted irregular crown with broad tier silhouettes.
    levels=[(.13,.065),(.20,.14),(.30,.12),(.35,.16),(.44,.125),(.49,.145),
            (.58,.11),(.64,.125),(.72,.09),(.79,.083),(.86,.059),(.93,.037),(1.0,.002)]
    segments=9
    verts=[]
    for j,(z,r) in enumerate(levels):
        bend=math.sin(z*3+seed)*height*.025
        for i in range(segments):
            a=math.tau*i/segments+(j%2)*.12
            rr=height*r*(1+rng.uniform(-.12,.12))
            verts.append((bend+rr*math.cos(a),rr*math.sin(a),height*(z+rng.uniform(-.012,.012))))
    faces=[tuple(range(segments-1,-1,-1))]
    for j in range(len(levels)-1):
        for i in range(segments):
            a=j*segments+i
            b=j*segments+(i+1)%segments
            faces.extend([(a,b,b+segments),(a,b+segments,a+segments)])
    faces.append(tuple(range((len(levels)-1)*segments,len(levels)*segments)))
    crown=G.mesh('Cypress broad tapered crown',verts,faces,None)
    for key in ('leaf','leaf_light','moss'):crown.data.materials.append(G.material(key))
    for p in crown.data.polygons:
        # Broad directional bands rather than noisy per-leaf speckles.
        p.material_index=1 if p.normal.x<-.3 and p.normal.z>.1 else (2 if p.normal.y<-.4 else 0)
    parts.append(crown)
    centers=[]
    for i in range(18):
        z=rng.uniform(.28,.87)
        a=rng.random()*math.tau
        rr=height*(.17-.12*z)
        centers.append((rr*math.cos(a),rr*math.sin(a),height*z))
    parts.append(_broad_leaf_spray('Cypress coarse foliage edge',centers,height*.045,seed+70))
    return _merge(parts,'ABY_Vegetation_Cypress')
