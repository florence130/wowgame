"""Continuous packed thatch with rounded, fibrous edges; never tiled shingles."""
import bpy,bmesh,math,random,pathlib
import kernel as G
TEXTURE=pathlib.Path('E:/wowgame/assets/models/vale_kit_v1/textures/thatch_fibre_albedo.png')
def material():
    name='VALE_thatch_fibre';m=bpy.data.materials.get(name)
    if m:return m
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=G.material('thatch').diffuse_color
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=1.0;bs.inputs['Specular IOR Level'].default_value=0.0
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(TEXTURE),check_existing=True);tex.image.pack();tex.interpolation='Linear';tex.extension='REPEAT'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    m['palette_reference']='thatch C8A868 / thatch_dark 9C7E48; hand-painted fibre albedo'
    return m

def roof(length,depth,rise,seed=11,caps=(False,False)):
    """One continuous thatch volume per slope, with no tiles or discrete courses."""
    half=depth/2;L=math.hypot(half,rise);dy=half/L;dz=-rise/L
    nx=max(8,math.ceil(length/.14));ns=28
    for side in [-1,1]:
        verts=[];uvs=[]
        for j in range(ns+1):
            t=j/ns
            for i in range(nx+1):
                q=i/nx;x=-length/2+length*q
                taper=math.sin(math.pi*q)**2
                # Low-frequency irregularity in a continuous packed blanket.
                wobble=taper*(.065*math.sin(x*2.7+1.3*t)+.035*math.sin(x*7.5-t*2.1))
                end=L+.20+taper*(.10*math.sin(x*9.3)+.04*math.sin(x*17.7))
                s=end*t-.055
                # Rounded, thick eave bulge, not a bevelled sheet or scalloped shingle.
                lift=.19+.11*math.sin(math.pi*t)+.22*math.exp(-((t-.91)/.13)**2)+wobble
                verts.append((x,side*(s*dy+lift*(-dz)),rise+s*dz+lift*dy))
                uvs.append((x*.5,-s*.24))
        faces=[]
        for j in range(ns):
            for i in range(nx):
                a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
        o=G.mesh('continuous_thatch_blanket',verts,faces,None);o.data.materials.append(material())
        if sum(p.normal.z for p in o.data.polygons)<0:
            bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
        uv=o.data.uv_layers.active
        for p in o.data.polygons:
            p.use_smooth=True
            for li in p.loop_indices:uv.data[li].uv=uvs[o.data.loops[li].vertex_index]
        m=o.modifiers.new('04 Continuous packed straw thickness','SOLIDIFY');m.thickness=.43;m.offset=-1;m.use_rim=True
        # Solidify rim UVs collapse onto the surface boundary and make a smooth slab.
        # Explicit rounded edge strips have independent, correctly oriented fibre UVs.
        normal=(0,side*(-dz),dy)
        def edge_strip(points,outward,label,side_edge):
            vv=[];ff=[];texcoords=[];nr=6
            for pindex,p in enumerate(points):
                phase=pindex*.9
                radius=.215+.022*math.sin(phase*1.8)
                center=[p[k]-.215*normal[k] for k in range(3)]
                slope=(side*p[1])*dy+(p[2]-rise)*dz
                for k in range(nr+1):
                    a=math.pi*k/nr
                    vv.append(tuple(center[d]+radius*(math.cos(a)*normal[d]+math.sin(a)*outward[d]) for d in range(3)))
                    texcoords.append((a*.12,-slope*.24) if side_edge else (p[0]*.5,-slope*.24+a*.055))
            for j in range(len(points)-1):
                for k in range(nr):
                    a=j*(nr+1)+k;ff.append((a,a+1,a+nr+2,a+nr+1))
            # Close each rounded edge volume at both ends; the closed blanket
            # underneath also prevents a view into the roof at intersecting rims.
            ff.extend([tuple(range(nr,-1,-1)),tuple(range((len(points)-1)*(nr+1),len(points)*(nr+1)))])
            rim=G.mesh(label,vv,ff,None);rim.data.materials.append(material());uv=rim.data.uv_layers.active
            for p in rim.data.polygons:
                p.use_smooth=True
                for li in p.loop_indices:uv.data[li].uv=texcoords[rim.data.loops[li].vertex_index]
        edge_strip(verts[ns*(nx+1):],(0,side*dy,dz),'rounded_packed_eave',False)
        for sign,enabled in [(-1,caps[0]),(1,caps[1])]:
            if not enabled:continue
            idx=0 if sign<0 else nx
            points=[verts[j*(nx+1)+idx] for j in range(ns+1)]
            edge_strip(points,(sign,0,0),'rounded_straw_gable_edge',True)
            for j in range(2,ns-1):
                p=points[j];p2=points[j+1]
                for offset in [.035,.11,.18]:
                    G.line('loose_side_straw',[(p[0]+sign*offset,p[1]+normal[1]*.035,p[2]+normal[2]*.035),(p2[0]+sign*(offset+.025),p2[1]+normal[1]*.012,p2[2]+normal[2]*.012)],.010,'thatch' if j%3 else 'thatch_dark')
        # The actual eave contains irregular straw ends, without a row of rectangular units.
        for i in range(nx*2+1):
            q=i/(nx*2);x=-length/2+length*q;taper=math.sin(math.pi*q)**2
            end=L+.20+taper*(.10*math.sin(x*9.3)+.04*math.sin(x*17.7));lift=.27+.035*math.sin(x*7.3)
            extra=.07+.055*(1+math.sin(x*21.5));w=.014
            pts=[(x-w,side*(end*dy+lift*(-dz)),rise+end*dz+lift*dy),(x+w,side*(end*dy+lift*(-dz)),rise+end*dz+lift*dy),(x+.015*math.sin(x*11),side*((end+extra)*dy+.10*(-dz)),rise+(end+extra)*dz+.10*dy)]
            G.mesh('eave_straw_end',pts,[(0,1,2)],'thatch_light' if i%4==0 else 'thatch')
    # Packed ridge-end plug closes the space where both rounded gable edges meet.
    # It is real geometry attached to the roof, independent of any wall behind it.
    for sign,enabled in [(-1,caps[0]),(1,caps[1])]:
        if not enabled:continue
        vv=[];ff=[]
        for x in [sign*(length/2-.12),sign*(length/2+.20)]:
            for k in range(12):
                a=k*math.tau/12;vv.append((x,.32*math.cos(a),rise-.04+.32*math.sin(a)))
        for k in range(12):ff.append((k,(k+1)%12,(k+1)%12+12,k+12))
        ff.extend([tuple(range(11,-1,-1)),tuple(range(12,24))])
        plug=G.mesh('packed_ridge_end',vv,ff,None);plug.data.materials.append(material())
        uv=plug.data.uv_layers.active
        for p in plug.data.polygons:
            for li in p.loop_indices:
                co=plug.data.vertices[plug.data.loops[li].vertex_index].co
                uv.data[li].uv=(co.y*.5,(co.z-rise)*.7)
    # Exact interface-bearing underlayer, hidden inside the continuous straw envelope.
    pts=[(-half,-.24),(-half,0),(0,rise),(half,0),(half,-.24),(0,rise-.28)]
    base=G.profile('thatch_underlayer',pts,length,'thatch_dark');base.rotation_euler.z=math.pi/2
    for side in [-1,1]:G.box('buried_eave_beam',(length,.21,.24),(0,side*half,-.20),'timber',.035)

def ridge(length):
    # Short, subtly irregular cylinders with fibres running along the bound roll.
    n=max(1,math.ceil(length/.8));seg=length/n
    for i in range(n):
        rings=[];verts=[];faces=[]
        for j in range(3):
            x=-length/2+(i+j/2)*seg;r=.36+(.035 if j==1 else 0)
            for k in range(12):
                a=k*math.tau/12;verts.append((x,r*math.cos(a),r*math.sin(a)))
        for j in range(2):
            for k in range(12):
                a=j*12+k;b=j*12+(k+1)%12;faces.append((a,b,b+12,a+12))
        faces.extend([tuple(range(11,-1,-1)),tuple(range(24,36))])
        o=G.mesh('organic_bound_ridge',verts,faces,None);o.data.materials.append(material())
        uv=o.data.uv_layers.active
        for p in o.data.polygons:
            for li in p.loop_indices:
                idx=o.data.loops[li].vertex_index;v=o.data.vertices[idx].co;uv.data[li].uv=(idx%12/12,v.x*.55)
    for x in [-length/2+.15,length/2-.15]:
        G.line('ridge_rope',[(x,.405*math.cos(k*math.tau/16),.405*math.sin(k*math.tau/16)) for k in range(16)],.043,'wood',True)
