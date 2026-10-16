"""Inspectable analytic CSG/SDF routing project for new abbey v3 constituents.

Blender API: run(out, specs=None). Each spec has id and bounds=[min,max] (or
bounds_min/bounds_max), optional recipe and kwargs. Only supported explicit
recipes are accepted. All SDF samples come from analytic boxes/cylinders/tori;
no source mesh, remesher, voxel-remesh modifier or triangle-distance query is used.

Thick stone gets coarse/fine SDF candidates plus a socket-plane correction.
The selected stone_capital_sdf is a real refined analytic-SDF final module.
Thin wood/joinery/metal routes to the separately generated dimension-controlled
modifier recipe. Output: pipeline_stages.blend and pipeline_routes.json.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import time
import bpy
import bmesh
import numpy as np
from mathutils import Matrix,Vector

HERE=Path(__file__).resolve().parent
sys.path[:0]=[str(HERE),str(HERE.parent/'abbey_kit_v2'),str(HERE.parent/'abbey_kit')]
import geometry as G
import sdf as SDF
import furniture as F
import structure as S


DEFAULT_SPECS=[
    {'id':'foundation_strip_4m','bounds':[[-2,-.675,0],[2,.675,.8]]},
    {'id':'support_pad','bounds':[[-.8,-.9,0],[.8,.9,.8]]},
    {'id':'interior_column','bounds':[[-.37,-.37,0],[.37,.37,5.4]]},
    {'id':'stone_capital_sdf','bounds':[[-.39,-.39,0],[.39,.39,.24]]},
    {'id':'beam_4m','bounds':[[-2,-.15,-.17],[2,.15,.17]]},
    {'id':'roof_truss_8m','bounds':[[-3.7,-.2,0],[3.7,.2,3.1]]},
    {'id':'chandelier','bounds':[[-.75,-.75,-1],[.75,.75,0]]},
    {'id':'floor_lamp','bounds':[[-.28,-.28,0],[.28,.28,1.8]]},
    {'id':'pew_2m','bounds':[[-1,-.425,0],[1,.425,1.15]]},
    {'id':'pew_end','bounds':[[-.065,-.425,0],[.065,.32,1.15]]},
    {'id':'pew_seat_1m','bounds':[[-.5,-.403,0],[.5,.425,1.1375]]},
    {'id':'lectern','bounds':[[-.4,-.3,0],[.4,.313,1.25]]},
    {'id':'altar_table','bounds':[[-1.1,-.45,0],[1.1,.45,1.05]]},
    {'id':'wood_dais_2m','bounds':[[-1,-1,0],[1,1,.48]]},
    {'id':'wood_stairs','bounds':[[-1,0,0],[1,1.05,.48]]},
    {'id':'altar_back_panel','bounds':[[-1.2,-.21,0],[1.2,.21,2.8]]},
]
THICK={'foundation_strip_4m','support_pad','interior_column','stone_capital_sdf'}
CAPITAL_LAST_EVIDENCE={}
ALIASES={'foundation_4':'foundation_strip_4m','foundation_strip':'foundation_strip_4m',
         'column_interior':'interior_column','interior_column_54':'interior_column',
         'wood_beam_4m':'beam_4m','truss_8m':'roof_truss_8m','floor_lantern':'floor_lamp',
         'pew':'pew_2m','wood_dais':'wood_dais_2m'}


def _box(name,size,center=(0,0,0),mat='wood',rotation=None):
    d={'kind':'box','name':name,'size':list(size),'center':list(center),'material':mat}
    if rotation is not None:d['rotation']=np.asarray(rotation).tolist()
    return d


def _cylinder(name,radius,height,center=(0,0,0),mat='sandstone',rotation=None):
    d={'kind':'cylinder','name':name,'radius':radius,'height':height,'center':list(center),'material':mat}
    if rotation is not None:d['rotation']=np.asarray(rotation).tolist()
    return d


def _beam(name,a,b,width,depth=None,mat='timber'):
    a,b=np.asarray(a,dtype=float),np.asarray(b,dtype=float)
    direction=b-a;length=float(np.linalg.norm(direction));z=direction/length
    reference=np.array([0.,1.,0.]) if abs(z[1])<.9 else np.array([1.,0.,0.])
    x=np.cross(reference,z);x/=np.linalg.norm(x);y=np.cross(z,x)
    return _box(name,(width,depth or width,length),(a+b)/2,mat,np.column_stack([x,y,z]))


def _torus(name,major,minor,z,mat='iron'):
    return {'kind':'torus','name':name,'major':major,'minor':minor,'center':[0,0,z],'material':mat}


def _capital_primitives(width,height):
    return [_box('capital lower seat',(width*.83,width*.83,height*.25),(0,0,height*.125),'stone_dark'),
            _box('capital rounded body',(width*.92,width*.92,height*.58),(0,0,height*.45),'sandstone'),
            _box('capital upper bearing crown',(width,width,height*.35),(0,0,height*.825),'sandstone')]


def _capital_field(points,width,height):
    p=np.asarray(points,dtype=float);result=np.full(p.shape[:-1],np.inf)
    for primitive in _capital_primitives(width,height):
        radius=min(width*.045,primitive['size'][2]*.30)
        d=SDF.rounded_box(p-np.asarray(primitive['center']),np.asarray(primitive['size'])/2,radius)
        result=np.minimum(result,d) if not np.isfinite(result).all() else SDF.smooth_union(result,d,min(.016,height*.065))
    # Low-amplitude, broad chisel undulation; exact support planes are not carved.
    z=np.clip(p[...,2]/height,0,1)
    envelope=np.sin(math.pi*z)**2
    chisel=(np.sin(p[...,0]*18+.4)*np.cos(p[...,1]*15-.7)+.3*np.sin((p[...,0]+p[...,1])*23))
    result+=min(.0028,height*.012)*np.maximum(chisel,0)*envelope
    # Analytic intersection preserves the declared metric envelope before meshing.
    return np.maximum.reduce([result,-p[...,2],p[...,2]-height,
                              np.abs(p[...,0])-width/2,np.abs(p[...,1])-width/2])


def refined_capital_mesh(width=.78,height=.24,step=.035):
    """Actual SDF final: rounded layered stone, exact Z=0/height interfaces.

    Returns (vertices, triangular_faces), no scene objects. Finite analytic scalar
    samples are polygonized first; subsequent coplanar cleanup is not remeshing.
    Width is the actual XY envelope, origin is bottom-center. Evidence from the
    latest call is in CAPITAL_LAST_EVIDENCE for a caller's manifest.
    """
    global CAPITAL_LAST_EVIDENCE
    if min(width,height,step)<=0:raise ValueError('Capital dimensions/step must be positive')
    bounds=[[-width/2,-width/2,0],[width/2,width/2,height]]
    primitives=_capital_primitives(width,height)
    vertices,faces,sampling=polygonize(primitives,bounds,step,True,
                                      field_fn=lambda p:_capital_field(p,width,height))
    v=np.asarray(vertices,dtype=float)
    low=v[:,2]<step*.12;high=v[:,2]>height-step*.12
    v[low,2]=0;v[high,2]=height
    # A tiny global envelope correction keeps the exact nominal width without
    # snapping individual rounded-corner samples into a ragged square boundary.
    xy_scales=[]
    for axis in (0,1):
        scale=(width/2)/float(np.max(np.abs(v[:,axis])))
        v[:,axis]*=scale;xy_scales.append(scale)
    bm=bmesh.new()
    bverts=[bm.verts.new(tuple(point)) for point in v]
    for face in faces:
        try:bm.faces.new([bverts[i] for i in face])
        except ValueError:pass
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    # Collapse only nearly coplanar tessellation on large planes. Curved corner
    # samples and visible chisel facets remain. No voxel/remesh modifier is used.
    bmesh.ops.dissolve_limit(bm,angle_limit=.012,verts=list(bm.verts),edges=list(bm.edges),
                            use_dissolve_boundaries=False,delimit={'NORMAL'})
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.verts.index_update()
    vv=np.asarray([tuple(point.co) for point in bm.verts])
    ff=np.asarray([tuple(point.index for point in face.verts) for face in bm.faces],dtype=int)
    bm.free()
    cross=np.cross(vv[ff[:,1]]-vv[ff[:,0]],vv[ff[:,2]]-vv[ff[:,0]])
    area=np.linalg.norm(cross,axis=1)
    ff=ff[area>1e-10]
    signed=float(np.sum(np.einsum('ij,ij->i',vv[ff[:,0]],np.cross(vv[ff[:,1]],vv[ff[:,2]])))/6)
    if signed<0:ff=ff[:,::-1]
    top=np.all(np.abs(vv[ff][:,:,2]-height)<1e-6,axis=1)
    bottom=np.all(np.abs(vv[ff][:,:,2])<1e-6,axis=1)
    normals=np.cross(vv[ff[:,1]]-vv[ff[:,0]],vv[ff[:,2]]-vv[ff[:,0]])
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-15)
    edges=np.sort(np.concatenate([ff[:,[0,1]],ff[:,[1,2]],ff[:,[2,0]]],axis=0),axis=1)
    _,edge_counts=np.unique(edges,axis=0,return_counts=True)
    CAPITAL_LAST_EVIDENCE={'source':'analytic layered rounded-box SDF with bounded chisel modulation',
        'sampling':sampling,'bounds_min':vv.min(0).tolist(),'bounds_max':vv.max(0).tolist(),
        'triangles':int(len(ff)),'degenerate_triangles':0,'finite_vertices':bool(np.isfinite(vv).all()),
        'top_planar_triangles':int(top.sum()),'bottom_planar_triangles':int(bottom.sum()),
        'top_normals_positive_z':bool(top.any() and np.all(normals[top,2]>.999)),
        'bottom_normals_negative_z':bool(bottom.any() and np.all(normals[bottom,2]<-.999)),
        'boundary_edges':int(np.sum(edge_counts==1)),
        'nonmanifold_edges':int(np.sum(edge_counts!=2)),
        'socket_snapped_vertices':int(low.sum()+high.sum()),'xy_envelope_scale':xy_scales,
        'postprocess':'plane correction, welded coincident vertices, coplanar dissolve, triangulation; no remesh'}
    if not CAPITAL_LAST_EVIDENCE['finite_vertices'] or not CAPITAL_LAST_EVIDENCE['top_normals_positive_z'] or not CAPITAL_LAST_EVIDENCE['bottom_normals_negative_z']:
        raise ValueError('Refined capital failed finite geometry or interface normal check')
    return vv.tolist(),ff.tolist()


def recipe_primitives(recipe,bounds,kwargs):
    """Explicit multi-part analytic blockouts; never reduced to a bounds cube."""
    lo,hi=np.asarray(bounds[0]),np.asarray(bounds[1]);size=hi-lo
    p=[]
    if recipe=='stone_capital_sdf':
        p=_capital_primitives(float(kwargs.get('width',size[0])),float(kwargs.get('height',size[2])))
    elif recipe in ('foundation_strip_4m','support_pad'):
        w,d,h=size
        foot=min(.14,h*.2);cap=min(.16,h*.22)
        p=[_box('ground foot',(w,d,foot),(0,0,foot/2),'stone_dark'),
           _box('closed load core',(w-.16,d-.16,h-foot-cap),(0,0,foot+(h-foot-cap)/2),'stone_dark'),
           _box('support cap',(w,d,cap),(0,0,h-cap/2),'sandstone')]
        divisions=4 if recipe=='foundation_strip_4m' else 2
        for i in range(divisions):
            p.append(_box('separate facing ashlar '+str(i),((w-.16)/divisions-.012,.07,h-foot-cap-.015),
                          (-w/2+.08+(i+.5)*(w-.16)/divisions,d/2-.065,foot+(h-foot-cap)/2),'stone_mid'))
    elif recipe=='interior_column':
        h=float(kwargs.get('height',size[2]))
        p=[_box('square foot',(.74,.74,.20),(0,0,.10),'stone_dark'),
           _cylinder('lower collar',.30,.18,(0,0,.29)),
           _cylinder('slender structural shaft',.175,h-.81,(0,0,.405+(h-.81)/2)),
           _cylinder('capital collar',.28,.22,(0,0,h-.29)),
           _box('square capital',(.72,.72,.18),(0,0,h-.09),'stone_light')]
    elif recipe=='beam_4m':
        p=[_box('main beam',(4,.24,.32),(0,0,0),'timber')]
        for x in (-1.82,1.82):p.append(_box('end strap',(.06,.26,.34),(x,0,0),'iron'))
    elif recipe=='roof_truss_8m':
        p=[_box('tie beam',(7.4,.28,.3),(0,0,.15),'timber'),
           _box('king post',(.2,.24,2.95),(0,0,1.625),'wood_dark')]
        for side in (-1,1):
            p.extend([_beam('principal rafter',(0,0,3.01),(side*3.59,0,.25),.22,.22),
                      _beam('rising strut',(side*.12,0,.29),(side*2.52,0,1.07),.14,.17,'wood'),
                      _beam('crossed brace',(side*.12,0,1.80),(side*2.13,0,.29),.14,.17,'wood_dark')])
    elif recipe=='floor_lamp':
        h=float(kwargs.get('height',1.8));seat=h-.4176
        p=[_cylinder('stable iron foot',.28,.12,(0,0,.06),'iron'),
           _cylinder('foot taper blockout',.15,.16,(0,0,.20),'iron'),
           _cylinder('slender bronze upright',.038,seat-.22,(0,0,(seat+.22)/2),'bronze'),
           _cylinder('lantern cup',.21,.07,(0,0,seat),'bronze'),
           _cylinder('lantern glass',.16,.29,(0,0,seat+.18),'window_glow'),
           _cylinder('lantern roof',.18,.085,(0,0,h-.045),'bronze')]
    elif recipe=='chandelier':
        drop=float(kwargs.get('drop',1));diameter=float(kwargs.get('diameter',1.5));r=diameter*.4;z=-drop+.12
        p=[_cylinder('ceiling mount',.115,.045,(0,0,-.0225),'iron'),
           _cylinder('chain volume candidate',.025,.42,(0,0,-.24),'iron'),
           _torus('load bearing circular ring',r,.038,z)]
        for i in range(6):
            a=i*math.tau/6;x,y=r*math.cos(a),r*math.sin(a)
            p.extend([_beam('radial arm',(0,0,z),(x,y,z),.046,.046,'iron'),
                      _cylinder('lantern cup',.135,.055,(x,y,z),'bronze'),
                      _cylinder('lantern glass',.105,.245,(x,y,z+.155),'window_glow'),
                      _cylinder('lantern lid',.125,.045,(x,y,z+.322),'bronze')])
        for i in range(3):
            a=(i+.25)*math.tau/3
            p.append(_beam('tension rod',(0,0,-.39),(r*math.cos(a),r*math.sin(a),z),.032,.032,'iron'))
    elif recipe in ('pew_2m','pew_seat_1m','pew_end'):
        w=2 if recipe=='pew_2m' else float(kwargs.get('width',1))
        if recipe=='pew_end':
            p=[_box('end rear upright',(.13,.16,1.15),(0,-.34,.575),'wood'),
               _box('side arm',(.13,.62,.13),(0,-.01,.64),'wood'),
               _box('lower side board',(.13,.48,.36),(0,-.02,.28),'wood')]
            for y in (-.31,.20):p.append(_box('end foot',(.13,.18,.20),(0,y,.10),'timber'))
        else:
            p=[_box('seat board',(w-.13,.45,.06),(0,.02,.45),'wood'),
               _box('lower back rail',(w-.13,.08,.09),(0,-.31,.58),'timber'),
               _box('back head rail',(w-.13,.085,.105),(0,-.36,1.085),'wood_dark'),
               _box('kneeler',(w-.17,.17,.045),(0,.34,.1375),'wood_dark')]
            for x in (-w/2+.12,w/2-.12):
                p.extend([_box('back structural upright',(.13,.14,1.10),(x,-.31,.55),'timber'),
                          _box('front floor leg',(.13,.14,.44),(x,.19,.22),'timber'),
                          _box('side arm',(.13,.56,.13),(x,-.01,.68),'wood')])
            for i in range(4 if w<=1 else 8):
                x=-w/2+(i+.5)*w/(4 if w<=1 else 8)
                p.append(_box('back slat',(.15,.052,.49),(x,-.33,.79),'wood'))
    elif recipe=='lectern':
        angle=math.atan(.185/.6);c,s=math.cos(angle),math.sin(angle)
        rotation=[[1,0,0],[0,c,-s],[0,s,c]]
        p=[_box('wide floor plinth',(.8,.55,.15),(0,0,.075),'timber'),
           _box('central pedestal',(.22,.22,.78),(0,0,.53),'wood'),
           _box('front carving shield',(.53,.065,.53),(0,.17,.72),'wood'),
           _box('sloped reading desk',(.8,.628,.052),(0,0,1.131),'wood',rotation),
           _box('book stop',(.75,.043,.045),(0,-.274,1.093),'wood_dark')]
    elif recipe=='altar_table':
        p=[_box('tabletop',(2.2,.9,.075),(0,0,1.0125),'wood'),
           _box('under edge moulding',(2.11,.81,.045),(0,0,.953),'wood_dark'),
           _box('low stretcher',(1.85,.10,.12),(0,0,.205),'wood_dark')]
        for x in (-.88,.88):
            for y in (-.29,.29):p.append(_box('load bearing leg',(.17,.17,.96),(x,y,.48),'timber'))
            p.append(_box('end apron',(.075,.65,.205),(x,0,.835),'wood_dark'))
        for y in (-.32,.32):p.append(_box('long apron',(1.83,.075,.205),(0,y,.835),'wood'))
    elif recipe=='wood_dais_2m':
        p=[_box('load bearing deck',(2,2,.08),(0,0,.44),'wood')]
        for x in (-.95,.95):p.append(_box('side frame',(.10,2,.40),(x,0,.20),'timber'))
        for y in (-.95,.95):p.append(_box('end frame',(1.8,.10,.40),(0,y,.20),'timber'))
        for x in (-.5,0,.5):p.append(_box('underfloor joist',(.12,1.81,.27),(x,0,.27),'wood_dark'))
    elif recipe=='wood_stairs':
        for i in range(3):
            top=(i+1)*.16;y=.875-i*.35
            p.extend([_box('stair tread',(2,.35,.035),(0,y,top-.0175),'wood'),
                      _box('closed stair riser',(1.78,.043,.125),(0,y+.1435,top-.0975),'wood_dark')])
            for x in (-.91,.91):p.append(_box('stepped stringer segment',(.12,.35,top-.035),(x,y,(top-.035)/2),'timber'))
    elif recipe=='altar_back_panel':
        p=[_box('base lintel',(2.15,.16,.20),(0,0,.29),'wood_dark'),
           _box('top lintel',(2.4,.20,.16),(0,0,2.5),'wood_dark')]
        for x in (-1.07,1.07):
            p.extend([_box('floor bearing foot',(.23,.42,.16),(x,0,.08),'timber'),
                      _box('vertical frame',(.17,.20,2.4),(x,0,1.32),'timber')])
        for x in (-.71,0,.71):
            p.append(_box('broad carved panel',(.68,.072,1.66),(x,0,1.20),'wood'))
            for side in (-1,1):p.append(_beam('pointed panel head',(x+side*.34,0,2.03),(x,0,2.39),.085,.09,'wood_dark'))
    else:raise ValueError('No explicit analytic blockout recipe for '+recipe)
    return p


def analytic_field(points,primitives,refined=False):
    p=np.asarray(points,dtype=float);result=np.full(p.shape[:-1],np.inf)
    for primitive in primitives:
        q=p-np.asarray(primitive['center'])
        if 'rotation' in primitive:q=q@np.asarray(primitive['rotation'])
        kind=primitive['kind']
        if kind=='box':
            half=np.asarray(primitive['size'])/2
            radius=min(.035,float(np.min(half))*.25) if refined else 0
            distance=SDF.rounded_box(q,half,radius)
        elif kind=='cylinder':
            d=np.stack([np.linalg.norm(q[...,:2],axis=-1)-primitive['radius'],np.abs(q[...,2])-primitive['height']/2],-1)
            distance=np.linalg.norm(np.maximum(d,0),axis=-1)+np.minimum(np.max(d,axis=-1),0)
        elif kind=='torus':
            d=np.stack([np.linalg.norm(q[...,:2],axis=-1)-primitive['major'],q[...,2]],-1)
            distance=np.linalg.norm(d,axis=-1)-primitive['minor']
        else:raise ValueError(kind)
        if refined and np.isfinite(result).all():result=SDF.smooth_union(result,distance,.028)
        else:result=np.minimum(result,distance)
    return result


def polygonize(primitives,bounds,step=.075,refined=False,field_fn=None):
    """Generic welded marching tetrahedra over actual world-space scalar samples."""
    low,high=np.asarray(bounds[0],dtype=float),np.asarray(bounds[1],dtype=float)
    pad=step*1.8
    axes=[np.linspace(low[k]-pad,high[k]+pad,max(5,int(math.ceil((high[k]-low[k]+2*pad)/step))+1)) for k in range(3)]
    points=np.stack(np.meshgrid(*axes,indexing='ij'),-1)
    values=field_fn(points) if field_fn is not None else analytic_field(points,primitives,refined)
    offsets=np.array([(0,0,0),(1,0,0),(1,1,0),(0,1,0),(0,0,1),(1,0,1),(1,1,1),(0,1,1)])
    corners=[values[a:values.shape[0]-1+a,b:values.shape[1]-1+b,c:values.shape[2]-1+c] for a,b,c in offsets]
    crossing=(np.min(corners,axis=0)<0)&(np.max(corners,axis=0)>=0)
    tets=[(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6),(0,5,1,6)]
    vertices=[];faces=[];cache={};flat=points.reshape(-1,3);val=values.ravel()
    stride=np.array([values.shape[1]*values.shape[2],values.shape[2],1])
    def edge(a,b):
        key=(min(a,b),max(a,b))
        if key not in cache:
            fraction=val[a]/(val[a]-val[b])
            point=flat[a]+fraction*(flat[b]-flat[a])
            cache[key]=len(vertices);vertices.append(tuple(point))
        return cache[key]
    for base in np.argwhere(crossing):
        ids=(base+offsets)@stride
        for tet in tets:
            inside=[int(ids[k]) for k in tet if val[ids[k]]<0]
            outside=[int(ids[k]) for k in tet if val[ids[k]]>=0]
            if len(inside)==1:
                faces.append(tuple(edge(inside[0],b) for b in outside))
            elif len(inside)==3:
                faces.append(tuple(edge(outside[0],b) for b in reversed(inside)))
            elif len(inside)==2:
                a,b=inside;c,d=outside
                polygon=[edge(a,c),edge(a,d),edge(b,d),edge(b,c)]
                faces.extend([(polygon[0],polygon[1],polygon[2]),(polygon[0],polygon[2],polygon[3])])
    if faces:
        a=np.asarray(vertices);f=np.asarray(faces)
        areas=np.linalg.norm(np.cross(a[f[:,1]]-a[f[:,0]],a[f[:,2]]-a[f[:,0]]),axis=1)
        faces=[tuple(face) for face in f[areas>1e-10].tolist()]
    return vertices,faces,{'grid_shape':list(values.shape),'sample_count':int(values.size),
                           'step_target_m':step,'cell_crossings':int(np.sum(crossing)),
                           'scalar_min':float(values.min()),'scalar_max':float(values.max()),
                           'raw_vertices':len(vertices),'raw_triangles':len(faces)}


def _primitive_object(primitive):
    kind=primitive['kind'];name='CSG '+primitive['name'];mat=primitive['material']
    if kind=='box':obj=G.box(name,primitive['size'],mat=mat)
    elif kind=='cylinder':
        r=primitive['radius'];h=primitive['height'];n=16
        vertices=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for z in (-h/2,h/2) for i in range(n)]
        faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
        obj=G.mesh(name,vertices,faces,mat)
    elif kind=='torus':
        R=primitive['major'];r=primitive['minor'];n=24;m=6
        vertices=[((R+r*math.cos(j*math.tau/m))*math.cos(i*math.tau/n),
                   (R+r*math.cos(j*math.tau/m))*math.sin(i*math.tau/n),r*math.sin(j*math.tau/m)) for i in range(n) for j in range(m)]
        faces=[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)]
        obj=G.mesh(name,vertices,faces,mat)
    if 'rotation' in primitive:obj.rotation_euler=Matrix(primitive['rotation']).to_euler()
    obj.location=primitive['center']
    obj['analytic_primitive']=json.dumps(primitive)
    obj['stage']='CSG blockout: independent constructive solid'
    return obj


def _stats(objects):
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    vertices=[];triangles=0;degenerate=0;mods={}
    for obj in objects:
        if obj.type not in ('MESH','CURVE'):continue
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        world=np.asarray([tuple(obj.matrix_world@v.co) for v in mesh.vertices])
        vertices.extend(world.tolist());triangles+=len(mesh.loop_triangles)
        indices=np.asarray([tuple(tri.vertices) for tri in mesh.loop_triangles],dtype=int)
        if len(indices):
            area=np.linalg.norm(np.cross(world[indices[:,1]]-world[indices[:,0]],world[indices[:,2]]-world[indices[:,0]]),axis=1)
            degenerate+=int(np.sum(area<1e-10))
        evaluated.to_mesh_clear()
        for mod in obj.modifiers:mods[mod.type]=mods.get(mod.type,0)+1
        if obj.type=='CURVE':mods['CURVE_BEVEL']=mods.get('CURVE_BEVEL',0)+1
    a=np.asarray(vertices)
    return {'objects':len(objects),'triangles':triangles,'bounds_min':a.min(0).tolist() if len(a) else None,
            'bounds_max':a.max(0).tolist() if len(a) else None,'retained_modifiers':mods,
            'finite_vertices':bool(np.isfinite(a).all()),'degenerate_triangles':degenerate}


def _final_recipe(recipe,kwargs,bounds):
    if recipe=='stone_capital_sdf':
        width=float(kwargs.get('width',bounds[1][0]-bounds[0][0]))
        height=float(kwargs.get('height',bounds[1][2]-bounds[0][2]))
        verts,faces=refined_capital_mesh(width,height,float(kwargs.get('step',.035)))
        obj=G.mesh('ABY3_StoneCapital_Final_AnalyticSDF',verts,faces,'sandstone')
        obj['source']='refined analytic SDF -> polygonization -> dimensional socket correction'
        obj['sdf_evidence']=json.dumps(CAPITAL_LAST_EVIDENCE)
        return [obj]
    if hasattr(F,recipe):return getattr(F,recipe)(**kwargs)
    if recipe=='support_pad' and not kwargs:
        lo,hi=np.asarray(bounds[0]),np.asarray(bounds[1]);w,d,h=hi-lo
        kwargs={'width':float(w),'depth':float(d),'height':float(h)}
    if recipe=='interior_column' and not kwargs:kwargs={'height':float(bounds[1][2]-bounds[0][2])}
    if hasattr(S,recipe):return getattr(S,recipe)(**kwargs)
    raise ValueError('No final dimensional recipe '+recipe)


def run(out,specs=None):
    """Create independent stage blend and route evidence, preserving caller scene.

    Thick SDF stages are candidates except the explicitly selected
    stone_capital_sdf final. Thin parts remain their editable modifier recipes.
    Returns the serializable report. Runtime normally tens of seconds to2min.
    """
    start=time.perf_counter();out=Path(out);out.mkdir(parents=True,exist_ok=True)
    specs=DEFAULT_SPECS if specs is None else specs
    old_col,old_root,old_scene=G.COL,G.ROOT,bpy.context.window.scene
    scene=bpy.data.scenes.new('ABY3_Inspectable_Pipeline_Stages')
    bpy.context.window.scene=scene;G.ROOT=None
    created_objects=[];created_collections=[];records=[]
    def collection(name):
        col=bpy.data.collections.new(name);scene.collection.children.link(col)
        created_collections.append(col);G.COL=col;return col
    try:
        for index,spec in enumerate(specs):
            asset=spec['id'];recipe=ALIASES.get(spec.get('recipe',asset),spec.get('recipe',asset))
            bounds=spec.get('bounds') or [spec['bounds_min'],spec['bounds_max']]
            kwargs=spec.get('kwargs',{});thick=recipe in THICK
            primitives=recipe_primitives(recipe,bounds,kwargs)
            sdf_final=recipe=='stone_capital_sdf'
            base=Vector((index*9.0,0,0))
            entry={'id':asset,'recipe':recipe,'target_bounds':bounds,'analytic_primitives':primitives,
                   'route':'refined_analytic_sdf_with_socket_correction_to_final' if sdf_final else ('thick_stone_sdf_comparison_then_dimension_control' if thick else 'thin_parts_retain_csg_and_editable_modifiers'),
                   'final_source':'refined analytic SDF and corrected interface planes' if sdf_final else 'dimension-controlled CSG and Blender modifiers; not derived from SDF',
                   'stages':[]}
            collection(asset+'__00_CSG_IndependentParts')
            blockout=[_primitive_object(p) for p in primitives]
            entry['stages'].append({'name':'CSG initial geometry / decomposition','stats':_stats(blockout),
                                    'construction':'independent box, cylinder and torus solids; constructive union; no combined mesh'})
            measured=entry['stages'][0]['stats']
            bounds_union=[np.minimum(bounds[0],measured['bounds_min']).tolist(),np.maximum(bounds[1],measured['bounds_max']).tolist()]
            for o in blockout:o.location+=base
            created_objects.extend(blockout)
            longest=float(np.max(np.asarray(bounds_union[1])-bounds_union[0]))
            step=max(.028,min(.10,longest/36))
            collection(asset+'__01_Pure_Analytic_SDF_Coarse')
            verts,faces,sampling=polygonize(primitives,bounds_union,step,False)
            if faces:
                coarse=G.mesh(asset+' analytic SDF coarse',verts,faces,'sandstone' if thick else 'wood')
                coarse['source']='analytic scalar field samples -> welded marching tetrahedra; no input mesh'
                stats=_stats([coarse]);coarse.location=base+Vector((0,5,0));created_objects.append(coarse)
            else:stats={'objects':0,'triangles':0,'empty_candidate':True}
            underresolved=[]
            for p in primitives:
                thickness=min(p['size']) if p['kind']=='box' else (2*p['radius'] if p['kind']=='cylinder' else 2*p['minor'])
                if thickness<step*2:underresolved.append({'part':p['name'],'thickness_m':thickness,'sample_step_m':step})
            entry['stages'].append({'name':'pure analytic SDF coarse candidate','sampling':sampling,'stats':stats,
                                    'under_two_voxel_features':underresolved,'selected_for_final':False})
            if thick:
                collection(asset+'__02_Pure_Analytic_SDF_Refined')
                fine_step=max(.02,step*.59)
                fv,ff,fs=polygonize(primitives,bounds_union,fine_step,True)
                fine=G.mesh(asset+' rounded smooth-union SDF refined',fv,ff,'sandstone')
                fine['source']='new finer analytic sampling with rounded boxes and smooth union'
                stats=_stats([fine]);fine.location=base+Vector((0,10,0));created_objects.append(fine)
                entry['stages'].append({'name':'SDF refined thick-stone candidate','sampling':fs,'stats':stats,'selected_for_final':False})
                collection(asset+'__03_SDF_InterfacePlane_Correction')
                corrected=np.asarray(fv,dtype=float).copy();bottom=float(bounds[0][2]);top=float(bounds[1][2]);band=fine_step*.75
                mask_low=np.abs(corrected[:,2]-bottom)<band;mask_high=np.abs(corrected[:,2]-top)<band
                corrected[mask_low,2]=bottom;corrected[mask_high,2]=top
                cf=np.asarray(ff);areas=np.linalg.norm(np.cross(corrected[cf[:,1]]-corrected[cf[:,0]],corrected[cf[:,2]]-corrected[cf[:,0]]),axis=1)
                corrected_mesh=G.mesh(asset+' SDF candidate socket planes corrected',corrected.tolist(),cf[areas>1e-10].tolist(),'sandstone')
                stats=_stats([corrected_mesh]);corrected_mesh.location=base+Vector((0,15,0));created_objects.append(corrected_mesh)
                entry['stages'].append({'name':'SDF candidate interface correction','stats':stats,
                    'bottom_plane':bottom,'top_support_plane':top,'snapped_vertices':int(mask_low.sum()+mask_high.sum()),
                    'selected_for_final':False,'note':'Candidate comparison only. Final sockets stay with the exact modifier recipe.'})
            collection(asset+'__04_DimensionControlled_Editable_Final')
            final=_final_recipe(recipe,kwargs,bounds)
            entry['stages'].append({'name':'actual SDF final with dimensional interface correction' if sdf_final else 'corrected final recipe with retained Blender construction','stats':_stats(final),
                                    'selected_for_final':True,'source':entry['final_source']})
            if sdf_final:entry['stages'][-1]['sdf_evidence']=dict(CAPITAL_LAST_EVIDENCE)
            # Preserve lamp sockets and parent relationships while offsetting the
            # recipe display. All current recipe outputs are direct children.
            for o in final:o.location+=base+Vector((0,20,0))
            created_objects.extend(final);records.append(entry)
            print('PIPELINE_ASSET',asset,'coarse',sampling['raw_triangles'],'final',entry['stages'][-1]['stats']['triangles'],flush=True)
        scene['pipeline_note']='Rows Y=0 CSG,5 analytic SDF coarse,10 thick fine,15 thick corrected candidate,20 actual final. stone_capital_sdf is SDF-derived; other finals retain dimension-controlled modifiers.'
        actual_stats=[stage['stats'] for asset in records for stage in asset['stages']]
        passed=all(s.get('finite_vertices',False) and s.get('degenerate_triangles',1)==0 for s in actual_stats)
        report={'passed':passed,'version':'abbey-v3-stages','assets':records,'asset_count':len(records),
                'elapsed_seconds':time.perf_counter()-start,
                'total_stage_triangles':sum(s.get('triangles',0) for s in actual_stats),
                'stage_geometry_checks':{'all_vertices_finite':all(s.get('finite_vertices',False) for s in actual_stats),
                    'total_degenerate_triangles':sum(s.get('degenerate_triangles',0) for s in actual_stats)},
                'sdf_algorithm':'direct analytic box/cylinder/torus signed distances, constructive union / smooth union, sampled grid, welded marching tetrahedra',
                'mesh_input_used_for_sdf':False,'remesh_used':False,
                'route_disclosure':'Thick masonry has coarse/fine SDF and planar-interface candidate comparisons. stone_capital_sdf is an explicitly selected refined analytic SDF final with corrected planes. Thin planks, joinery, chains and metal rods use dimensional CSG/modifier finals.',
                'stage_blend':'pipeline_stages.blend','assembly_stage':'Owned by the main v3 build; not synthesized or claimed by this stage project.'}
        bpy.data.libraries.write(str(out/'pipeline_stages.blend'),{scene},path_remap='RELATIVE_ALL',compress=True)
        (out/'pipeline_routes.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
        return report
    finally:
        bpy.context.window.scene=old_scene;G.COL=old_col;G.ROOT=old_root
        # Only temporary stage-owned datablocks are removed from the caller.
        for obj in created_objects:
            if obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
        for col in reversed(created_collections):
            if col.name in bpy.data.collections:bpy.data.collections.remove(col)
        bpy.data.scenes.remove(scene)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--specs',type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    import materials as M
    palette=M.use_game_palette()
    for key in ('wood_dark','bronze','window_glow'):
        M.COLORS[key]=palette['colors'][key];M.COLOR_KEYS[key]=key
    M.install(args.out)
    specs=json.loads(args.specs.read_text(encoding='utf8')) if args.specs else None
    report=run(args.out,specs)
    print('PIPELINE_COMPLETE',json.dumps({'passed':report['passed'],'assets':report['asset_count'],'seconds':report['elapsed_seconds'],'out':str(args.out)}),flush=True)
    if not report['passed']:raise SystemExit(1)


if __name__=='__main__':main()
