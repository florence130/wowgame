"""Closed semicircular abbey foundation, in metres; no scene side effects.

Place this module at world Z=0, under an apse whose wall datum is Z=.8.
The curved side occupies negative Y; the straight edge overlaps Y=+.12.
Callers provide geometry.COL, geometry.ROOT and the active material factory.
"""
import math
import geometry as G


def _outline(radius,segments=32):
    return [(radius*math.cos(math.pi*i/segments),
             -radius*math.sin(math.pi*i/segments)) for i in range(segments+1)] + [(-radius,.12),(radius,.12)]


def _solid_body():
    # The whole interior is closed and filled. Recessed bands behind the face
    # stones remain continuous, so mortar joints cannot expose the underside.
    profile=[(3.82,0),(3.87,.035),(3.87,.065),(3.81,.065),
             (3.81,.575),(3.91,.610),(3.91,.780),(3.63,.800)]
    vertices=[]
    faces=[]
    n=len(_outline(1))
    for radius,z in profile:
        vertices.extend((x,y,z) for x,y in _outline(radius))
    for row in range(len(profile)-1):
        a,b=row*n,(row+1)*n
        for i in range(n):
            j=(i+1)%n
            faces.append((a+i,a+j,b+j,b+i))
    faces.extend([tuple(range(n-1,-1,-1)),
                  tuple(range((len(profile)-1)*n,len(profile)*n))])
    return G.mesh('ABY_ApseBase_ClosedSteppedMass',vertices,faces,'stone_dark')


def _wedge(vertices,faces,indices,a,b,inner,outer,bottom,top,mat):
    # Two arc segments per stone preserve the round facade without tiny tris.
    angles=[a,(a+b)/2,b]
    outline=[(outer*math.cos(t),-outer*math.sin(t)) for t in angles]
    outline += [(inner*math.cos(t),-inner*math.sin(t)) for t in reversed(angles)]
    offset=len(vertices)
    n=len(outline)
    vertices.extend((x,y,z) for z in (bottom,top) for x,y in outline)
    local=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    local.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    faces.extend(tuple(offset+j for j in face) for face in local)
    indices.extend([mat]*len(local))


def build():
    """Build a solid 0.8 m apse base with staggered ashlar and dressed coping.

    Nominal facade radius 3.86 m; upper coping outer radius 3.97 m. All original
    vertices stay within Z=[0,.8]. Returns two mesh objects, parented by G.
    """
    body=_solid_body()
    vertices,faces,indices=[],[],[]
    count=18
    step=math.pi/count
    joint=.010/3.86
    for row,(bottom,top) in enumerate(((.078,.314),(.326,.565))):
        shift=step*.5*(row%2)
        for stone in range(-1,count+1):
            a=max(0,stone*step+shift+joint/2)
            b=min(math.pi,(stone+1)*step+shift-joint/2)
            if b-a<.001:continue
            key=0 if (stone+row)%7==0 else 2 if (stone+2*row)%5==0 else 1
            _wedge(vertices,faces,indices,a,b,3.76,3.86,bottom,top,key)
    # Wide coping slabs carry the full .4 m apse wall (radius 3.3 .. 3.7),
    # leave a readable ledge, and meet the solid centre at exactly Z=.8.
    for stone in range(count):
        a=stone*step+(.006/3.97 if stone else 0)
        b=(stone+1)*step-(.006/3.97 if stone<count-1 else 0)
        _wedge(vertices,faces,indices,a,b,3.59,3.97,.612,.800,2 if stone%6==0 else 1)
    stones=G.mesh('ABY_ApseBase_BondedAshlarAndCoping',vertices,faces,None)
    for key in ('stone_dark','sandstone','stone_mid'):
        stones.data.materials.append(G.material(key))
    for face,index in zip(stones.data.polygons,indices):
        face.material_index=index
    # Bevel stays inside the nominal slab envelope and makes the mortar joints
    # legible in the same lit material setup as the rest of the abbey kit.
    G.bevel(stones,.006)
    for ob in (body,stones):
        ob['asset_family']='Abbey semicircular apse foundation'
        ob['datum_bottom']=0.0
        ob['datum_wall_seat']=.8
        ob['straight_edge_overlap']=.12
    return [body,stones]
