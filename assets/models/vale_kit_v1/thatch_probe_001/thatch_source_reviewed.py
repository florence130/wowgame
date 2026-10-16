"""Thick, staggered straw bundles with directionally mapped hand-painted fibres."""
import bpy,math,random,pathlib
import kernel as G
TEXTURE=pathlib.Path('E:/wowgame/assets/models/vale_kit_v1/textures/thatch_fibre_albedo.png')
def material():
    name='VALE_thatch_fibre';m=bpy.data.materials.get(name)
    if m:return m
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=G.material('thatch').diffuse_color
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.97;bs.inputs['Specular IOR Level'].default_value=.13
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(TEXTURE),check_existing=True);tex.image.pack();tex.interpolation='Linear';tex.extension='REPEAT'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    m['palette_reference']='thatch C8A868 / thatch_dark 9C7E48; hand-painted fibre albedo'
    return m

def roof(length,depth,rise,seed=11):
    rng=random.Random(seed);half=depth/2;L=math.hypot(half,rise);dy=half/L;dz=-rise/L;rows=5;nx=max(1,round(length/.8));pitch=length/nx
    # A thick closed substrate keeps small bundle gaps opaque and roof sockets exact.
    pts=[(-half,-.24),(-half,0),(0,rise),(half,0),(half,-.24),(0,rise-.28)]
    base=G.profile('thatch_underlayer',pts,length,'thatch_dark');base.rotation_euler.z=math.pi/2
    for side in [-1,1]:
        for row in range(rows):
            # Rows vary in width allocation while the module side boundaries remain exact.
            cuts=[-length/2]+[-length/2+pitch*(i+(.40 if row%2 else 0))+rng.uniform(-.16,.16)*pitch for i in range(1,nx)]+[length/2]
            for ix in range(nx):
                x0,x1=cuts[ix],cuts[ix+1];w=x1-x0;s0=row*L/rows-.06;s1=(row+1)*L/rows+.34
                if row==rows-1:s1=L+.17
                s0+=rng.uniform(-.10,.10);s1+=rng.uniform(-.08,.08)
                verts=[];uvs=[];nu=4;nv=8
                tips=[rng.uniform(-.065,.07) for _ in range(nv+1)]
                for j in range(nu+1):
                    t=j/nu
                    for k in range(nv+1):
                        q=k/nv;x=x0+w*q;s=s0+(s1-s0)*t+(tips[k] if j==nu else 0)
                        bulge=.10+.13*math.sin(math.pi*q)+.12*math.sin(math.pi*t*.7)
                        # soft waviness below fibre scale, never regular scalloped tiles
                        bulge+=.025*math.sin(q*math.pi*5+row*.7+ix)
                        verts.append((x,side*(s*dy+bulge*(-dz)),rise+s*dz+bulge*dy))
                        uvs.append((x*.70+ix*.13,-s*.38+row*.07))
                faces=[]
                for j in range(nu):
                    for k in range(nv):
                        a=j*(nv+1)+k;faces.append((a,a+1,a+nv+2,a+nv+1))
                o=G.mesh('organic_straw_bundle',verts,faces,None);o.data.materials.append(material())
                uv=o.data.uv_layers.active
                for p in o.data.polygons:
                    p.use_smooth=True
                    for li in p.loop_indices:uv.data[li].uv=uvs[o.data.loops[li].vertex_index]
                m=o.modifiers.new('04 Bundle thickness','SOLIDIFY');m.thickness=.13;m.offset=-1
                # Small sparse tapered strands at tips change the actual silhouette.
                for k in range(2,nv,2):
                    x=x0+w*k/nv;s=s1+tips[k];extra=rng.uniform(.08,.21);width=rng.uniform(.018,.029)
                    p0=(x-width,side*(s*dy+.20*(-dz)),rise+s*dz+.20*dy)
                    p1=(x+width,side*(s*dy+.20*(-dz)),rise+s*dz+.20*dy)
                    p2=(x+rng.uniform(-.035,.035),side*((s+extra)*dy+.11*(-dz)),rise+(s+extra)*dz+.11*dy)
                    G.mesh('loose_straw_tip',[p0,p1,p2],[(0,1,2)],'thatch_light' if k%4 else 'thatch')
    for side in [-1,1]:G.box('buried_eave_beam',(length,.21,.24),(0,side*half,-.20),'timber',.04)

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
