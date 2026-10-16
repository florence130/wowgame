"""Deterministic metre-based Blender construction primitives (no external packages)."""
import bpy, bmesh, math
from mathutils import Vector

PALETTE = {'plaster':'E8C9A8','plaster_patch':'DBB998','timber':'4E3A2C','wood':'765B42',
 'terracotta':'C4694A','tile_dark':'A9553C','tile_light':'D8835B','sandstone':'C8B79B',
 'stone_dark':'AE9C80','stone_light':'DDD0B7','iron':'424746','glass':'70B9BB',
 'glass_amber':'D9B36C','moss':'6E8A4A','leaf':'668555','leaf_light':'829A62',
 'cloth':'AF5D48','flower':'E8B4A6'}
MATS={}
COL=None
ROOT=None

def linear(v):
    v=v/255
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4

def material(key):
    if key in MATS: return MATS[key]
    h=PALETTE[key]; c=tuple(linear(int(h[i:i+2],16)) for i in (0,2,4))+(1,)
    m=bpy.data.materials.new('ABY_'+key); m.diffuse_color=c; m.use_nodes=True
    n=m.node_tree.nodes; n.clear(); out=n.new('ShaderNodeOutputMaterial')
    # Direct RGB -> Surface is the glTF exporter's supported shadeless pattern.
    rgb=n.new('ShaderNodeRGB'); rgb.outputs[0].default_value=c
    m.node_tree.links.new(rgb.outputs[0],out.inputs['Surface']); MATS[key]=m
    return m

def attach(o,name,mat=None):
    o.name=name
    for c in list(o.users_collection): c.objects.unlink(o)
    COL.objects.link(o)
    if ROOT: o.parent=ROOT
    if mat: o.data.materials.append(material(mat))
    return o

def mesh(name,verts,faces,mat='sandstone',edges=None):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,edges or [],faces); me.update()
    if faces:
        bm=bmesh.new(); bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); COL.objects.link(o)
    if ROOT: o.parent=ROOT
    if mat: o.data.materials.append(material(mat))
    if faces:
        uv=me.uv_layers.new(name='UVMap')
        for p in me.polygons:
            axis=max(range(3),key=lambda k:abs(p.normal[k])); axes=[k for k in range(3) if k!=axis]
            for li in p.loop_indices:
                co=me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]],co[axes[1]])
    return o

def bevel(o,width=.025):
    m=o.modifiers.new('Soft low-poly corners','BEVEL'); m.width=width; m.segments=1
    return o

def box(name,size,loc=(0,0,0),mat='sandstone',bevel_width=0):
    x,y,z=[s/2 for s in size]; px,py,pz=loc
    verts=[(px+a*x,py+b*y,pz+c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    o=mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    if bevel_width: bevel(o,bevel_width)
    return o

def profile(name,points,depth,mat='sandstone',y=0):
    """Extrude a closed X/Z outline through Y. points ordered around its perimeter."""
    n=len(points); v=[(x,y+d,z) for d in (-depth/2,depth/2) for x,z in points]
    f=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,f,mat)

def arch_outline(width,spring,bottom=0,segments=12):
    r=width/2
    return [(-r,bottom),(r,bottom)]+[(r*math.cos(math.pi*i/segments),spring+r*math.sin(math.pi*i/segments)) for i in range(segments+1)]

def apply_modifier(o,m):
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=m.name)

def subtract(o,cutter,keep=False):
    m=o.modifiers.new('CSG exact opening','BOOLEAN'); m.operation='DIFFERENCE'; m.solver='EXACT'; m.object=cutter
    apply_modifier(o,m)
    if not keep: bpy.data.objects.remove(cutter,do_unlink=True)
    return o

def arch_frame(name,w=2,spring=1.7,bottom=0,thick=.22,depth=.5,y=0):
    parts=[]
    if spring-bottom>1e-6:
        for side in (-1,1):
            parts.append(box(name+'_jamb',(thick,depth,spring-bottom),(side*(w/2+thick/2),y,(spring+bottom)/2),'sandstone',.018))
    for i in range(12):
        a=math.pi*i/12; b=math.pi*(i+1)/12; r=w/2; R=r+thick
        pts=[(r*math.cos(a),spring+r*math.sin(a)),(R*math.cos(a),spring+R*math.sin(a)),(R*math.cos(b),spring+R*math.sin(b)),(r*math.cos(b),spring+r*math.sin(b))]
        parts.append(profile(name+'_voussoir',pts,depth,'stone_light' if i%4==0 else 'sandstone',y))
    return parts

def line(name,points,r=.04,mat='timber',cyclic=False):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.resolution_u=1; cu.bevel_depth=r; cu.resolution_u=1; cu.bevel_resolution=0; cu.use_fill_caps=True
    sp=cu.splines.new('POLY'); sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points): p.co=(*co,1)
    sp.use_cyclic_u=cyclic; o=bpy.data.objects.new(name,cu); COL.objects.link(o)
    if ROOT:o.parent=ROOT
    o.data.materials.append(material(mat)); return o

def ring(name,r,z,depth=.14,mat='sandstone',segments=16,y=0):
    pts=[(r*math.cos(i*2*math.pi/segments),y,z+r*math.sin(i*2*math.pi/segments)) for i in range(segments)]
    return line(name,pts,depth,mat,True)

def lathe(name,profile_points,mat='sandstone',segments=12):
    """Editable Screw modifier on radial profile in X/Z."""
    o=mesh(name,[(r,0,z) for r,z in profile_points],[],mat,[(i,i+1) for i in range(len(profile_points)-1)])
    m=o.modifiers.new('06 Spin profile','SCREW'); m.axis='Z'; m.angle=math.tau; m.steps=segments; m.render_steps=segments; m.use_merge_vertices=True; m.use_smooth_shade=False
    return o

def loft(name,rings,mat='sandstone',segments=12,cap=True):
    verts=[(r*math.cos(i*math.tau/segments),r*math.sin(i*math.tau/segments),z) for r,z in rings for i in range(segments)]
    faces=[]
    for j in range(len(rings)-1):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
    if cap:faces += [tuple(range(segments-1,-1,-1)),tuple(range((len(rings)-1)*segments,len(rings)*segments))]
    return mesh(name,verts,faces,mat)

def array(o,count,offset,merge=False):
    m=o.modifiers.new('02 Repeat measured pitch','ARRAY');m.count=count;m.use_relative_offset=False;m.use_constant_offset=True;m.constant_offset_displace=offset;m.use_merge_vertices=merge;return m

def patches(o,keys,seed=3):
    import random
    rng=random.Random(seed)
    for key in keys:o.data.materials.append(material(key))
    for p in o.data.polygons:
        p.material_index=rng.randrange(len(o.data.materials)) if rng.random()<.28 else 0

def beam(name,a,b,width=.12,mat='timber'):
    a,b=Vector(a),Vector(b);v=b-a
    o=box(name,(width,width,v.length),(0,0,0),mat,.012)
    o.location=(a+b)/2; o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return o
