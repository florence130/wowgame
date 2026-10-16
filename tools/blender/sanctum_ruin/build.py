"""Blender-authored sea-temple finish fitted to the unchanged MMO whitebox.

Run Blender --background --factory-startup --python-exit-code 1 --python this.py.
Godot coordinates are mapped to Blender (x, -z, y); glTF restores Y-up.
The original whitebox is retained; a separate structural copy raises the nave.
"""
import bpy, bmesh, math, json, random, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path('E:/wowgame')
OUT = ROOT / 'assets/models/sanctum_blender_ruin'
OUT.mkdir(parents=True, exist_ok=True)
R = random.Random(20261012)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
art = bpy.data.collections.new('SEA_TEMPLE_AUTHORED_FINISH')
scene.collection.children.link(art)
reference = bpy.data.collections.new('WHITEBOX_REFERENCE_DO_NOT_EXPORT')
scene.collection.children.link(reference)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/sanctum_unity_v2/sanctum_architecture.glb'))
for ob in list(scene.objects):
    for coll in list(ob.users_collection): coll.objects.unlink(ob)
    reference.objects.link(ob)
reference.hide_render = True
reference.hide_viewport = True

def P(p): return Vector((p[0], -p[2], p[1]))
def color(s):
    rgb = [int(s[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb)+(1,)
def material(name, hexcode, emit=0):
    m=bpy.data.materials.new(name);m.diffuse_color=color(hexcode);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=m.diffuse_color
    bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=0
    if emit:
        bs.inputs['Emission Color'].default_value=m.diffuse_color;bs.inputs['Emission Strength'].default_value=emit
    return m
stone=[material('Limestone_'+str(i),c) for i,c in enumerate(['aaa18f','b6ad99','c2baa8','9b9686','afa894'])]
cut=material('Exposed_Fracture','868471')
dark=material('Deep_Crack','515950')
trim=material('Salt_Worn_Trim','c7bfab')
vault=material('Bluegrey_Vault','68787c')
blue=material('Faded_Ocean_Inlay','999e97')
blue_dark=material('Ocean_Border','506d7d')
wood=[material('Rotten_Wood_'+str(i),c) for i,c in enumerate(['615443','78634c','554c3d'])]
rootmat=material('Ancient_Root','51553c')
leaves=[material('Leaf_Plane_'+str(i),c) for i,c in enumerate(['52693d','6b7d49','7c8952','5e7445'])]
moss=material('Moss_and_Soil','64724c')
glass=material('Pale_Seaglass','b9d4d7',.28)
bronze=material('Oxidized_Bronze','6e7963')
statue_mat=material('Goddess_Stone','bfc1b7')
group='Nave'

def mesh(name, verts, faces, mat):
    data=bpy.data.meshes.new(name);data.from_pydata([P(v) for v in verts],[],faces);data.update()
    ob=bpy.data.objects.new(group+'__'+name,data);art.objects.link(ob);ob.data.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces[:]);bm.to_mesh(data);bm.free()
    ob['zone']=group
    return ob

def box(name,p,size,mat,bevel=.04,yaw=0,chip=False):
    x,y,z=p;a,b,c=[v*.5 for v in size]
    v=[(x+dx,y+dy,z+dz) for dx,dy,dz in [(-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]]
    if yaw:
        co,si=math.cos(yaw),math.sin(yaw)
        v=[(x+(xx-x)*co+(zz-z)*si,yy,z-(xx-x)*si+(zz-z)*co) for xx,yy,zz in v]
    ob=mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],mat)
    if chip:
        bm=bmesh.new();bm.from_mesh(ob.data)
        # Cut a genuine corner off the solid, fill the exposed fracture face.
        corner=P(v[6]);n=P((.7,1,.6)).normalized()
        geom=list(bm.verts)+list(bm.edges)+list(bm.faces)
        result=bmesh.ops.bisect_plane(bm,geom=geom,dist=.00001,plane_co=corner-n*min(size)*.40,plane_no=n,clear_outer=True)
        edges=[e for e in result['geom_cut'] if isinstance(e,bmesh.types.BMEdge) and e.is_boundary]
        ob.data.materials.append(cut)
        if edges:
            filled=bmesh.ops.holes_fill(bm,edges=edges,sides=0)
            for f in filled['faces']:f.material_index=1
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    if bevel>0:
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,min(size)*.22),segments=1,affect='EDGES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    return ob

def ringmesh(name, rings, mat):
    vertices=[]
    count=len(rings[0])
    for r in rings:vertices.extend(r)
    faces=[]
    for j in range(len(rings)-1):
        for i in range(count):faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
    faces.extend([tuple(range(count-1,-1,-1)),tuple((len(rings)-1)*count+i for i in range(count))])
    return mesh(name,vertices,faces,mat)

def tube(name, points, radius, mat, sides=7):
    rings=[]
    for j,p in enumerate(points):
        tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
        tangent.normalize();u=tangent.cross(Vector((0,1,0)))
        if u.length<.05:u=tangent.cross(Vector((1,0,0)))
        u.normalize();v=tangent.cross(u).normalized()
        rad=radius*(1-.65*j/max(1,len(points)-1))
        rings.append([Vector(p)+rad*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)])
    return ringmesh(name,rings,mat)

def crack(p,span=1.0,wall='front'):
    # Tapered seams follow stone faces, with a fork; no repeating noise texture.
    a=Vector(p);pts=[a,a+Vector((.16,span*.27,0)),a+Vector((-.12,span*.60,0)),a+Vector((.15,span,0))]
    if wall=='floor':pts=[a+Vector((q.x-a.x,0,q.y-a.y)) for q in pts]
    if wall=='side':pts=[a+Vector((0,q.y-a.y,q.x-a.x)) for q in pts]
    for i in range(3):
        direction=(pts[i+1]-pts[i]).normalized()
        normal=Vector((0,1,0)) if wall=='floor' else Vector((1,0,0)) if wall=='side' else Vector((0,0,1))
        edge=direction.cross(normal)*(.035 if i==0 else .018)
        mesh('Open_Masonry_Seam',[pts[i]-edge,pts[i]+edge,pts[i+1]+edge*.4,pts[i+1]-edge*.4],[(0,1,2,3)],dark)

def leaf(p,scale,yaw=0,tilt=0):
    # Broad six-plane ivy leaves, curved about a visible central ridge.
    v=[(-.4,0,0),(0,.11,-.55),(.4,0,0),(.27,.05,.45),(0,.20,.68),(-.27,.05,.45),(0,.24,.06)]
    co,si=math.cos(yaw),math.sin(yaw);ct,st=math.cos(tilt),math.sin(tilt)
    verts=[]
    for x,y,z in v:
        y,z=y*ct-z*st,y*st+z*ct
        verts.append((p[0]+scale*(x*co+z*si),p[1]+scale*y,p[2]+scale*(-x*si+z*co)))
    return mesh('Ivy_Leaf',verts,[(6,i,(i+1)%6) for i in range(6)],R.choice(leaves))

def foliage(p,spread=2,n=30):
    for i in range(n):
        a=R.random()*math.tau;r=spread*math.sqrt(R.random())
        leaf((p[0]+r*math.cos(a),p[1]+.04+R.random()*.3,p[2]+r*math.sin(a)),R.uniform(.5,1.15),a,R.uniform(-.35,.6))

def ivy(points,radius=.23,n=40):
    tube('Intruding_Root',points,radius,rootmat)
    for i in range(n):
        t=R.random()*(len(points)-1);idx=int(t);p=Vector(points[idx]).lerp(Vector(points[min(idx+1,len(points)-1)]),t-idx)
        leaf(p+Vector((R.uniform(-.55,.55),0,R.uniform(-.4,.4))),R.uniform(.55,1.25),R.random()*math.tau,R.uniform(-1.2,1.2))

def rubble(p,count=8):
    for i in range(count):
        a=R.random()*math.tau;r=R.uniform(.2,1.6)
        size=(R.uniform(.35,.95),R.uniform(.17,.50),R.uniform(.35,.85))
        box('Dislodged_Stone',(p[0]+r*math.cos(a),p[1]+size[1]*.5,p[2]+r*math.sin(a)),size,R.choice(stone),.07,R.random()*math.tau,True)

def pier(x,z,y=24,top=31.1,damaged=False):
    global group
    saved_group=group;group='Solid_Pier_'+str(x)+'_'+str(z)
    box('Pier_Foot',(x,y+.18,z),(2.85,.36,2.85),stone[3],.11,chip=damaged)
    box('Pier_Base',(x,y+.62,z),(2.5,.50,2.5),trim,.10,chip=damaged)
    h=top-y-.95
    n=9
    for i in range(n):
        hh=h/n-.025;sy=y+.9+(i+.5)*h/n
        block=box('Pier_Course',(x,sy,z),(2.05,hh,2.05),stone[(i+int(z))%len(stone)],.065,chip=damaged and i in (1,3,7))
        if i in (1,5):crack((x+.25,sy-hh*.4,z+1.032),hh*.8)
    box('Pier_Capital',(x,top-.18,z),(2.65,.42,2.65),trim,.09,chip=damaged)
    box('Pier_Crown',(x,top+.18,z),(2.32,.32,2.32),stone[2],.08)
    group=saved_group
    if damaged:rubble((x+.3,y,z+1.7),6)

def arch(name,center,rx,rise,spring,depth=.65,thick=.55,yaw=0,missing=()):
    # Individual closed wedge stones; actual mortar joints and chipped ends.
    segments=22
    for i in range(segments):
        if i in missing:continue
        a=math.pi*i/segments+.003;b=math.pi*(i+1)/segments-.003
        v=[]
        for zz in [-depth*.5,depth*.5]:
            for rr,hh,ang in [(rx,rise,a),(rx,rise,b),(rx-thick,rise-thick,b),(rx-thick,rise-thick,a)]:
                xx=rr*math.cos(ang);yy=spring+hh*(1-abs(math.cos(ang)))**.65
                v.append((center[0]+xx*math.cos(yaw)+zz*math.sin(yaw),yy,center[1]-xx*math.sin(yaw)+zz*math.cos(yaw)))
        ob=mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],stone[2 if i%3 else 1])
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.bevel(bm,geom=list(bm.edges),offset=.025,segments=1,affect='EDGES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()

def vault_bay(z0,z1,rx=13,spring=31.1,rise=8.25):
    for i in range(20):
        a=i*math.pi/20;b=(i+1)*math.pi/20
        # Local missing finish tiles reveal the old structural roof; cover remains intact.
        if 4<=i<=6 and 113<z0<120:continue
        ya=spring+rise*(1-abs(math.cos(a)))**.65;yb=spring+rise*(1-abs(math.cos(b)))**.65
        v=[(104+rx*math.cos(a),ya,z0),(104+rx*math.cos(b),yb,z0),(104+rx*math.cos(b),yb,z1),(104+rx*math.cos(a),ya,z1)]
        mesh('Barrel_Vault_Panel',v,[(0,1,2,3)],vault)

def niche(x,z,y=29.8,right=False):
    sign=-1 if right else 1
    box('Seaglass_Blind_Window',(x,y+2.35,z),(.10,3.6,2.25),glass,.01)
    for dz in [-1.35,1.35]:box('Window_Reveal',(x+sign*.20,y+2.2,z+dz),(.45,4.2,.30),trim,.05)
    box('Window_Sill',(x+sign*.35,y+.20,z),(.9,.35,3.1),trim,.08)
    arch('Window_Arch',(x+sign*.20,z),1.48,1.30,y+3.4,.45,.25,math.pi/2)
    box('Window_Mullion',(x+sign*.12,y+2.2,z),(.25,3.8,.10),stone[3],.02)

def wave(z,width=3.4,y=24.048):
    for row in range(2):
        verts=[]
        for i in range(25):
            x=(i/24-.5)*width;zz=z+math.sin(i/24*math.tau*1.4)*.28+row*.47
            verts.extend([(104+x,y,zz-.065),(104+x,y,zz+.065)])
        mesh('Worn_Sea_Inlay',verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(24) if i not in (4,18)],blue_dark)

def floor():
    # Irregular stone edges and mortar bed. Thin finish follows existing level.
    for z in range(38,139,3):
        for x in [95,98.6,102.2,105.8,109.4,113]:
            mat=blue if 100<x<109 else stone[(z+int(x))%5]
            box('Weathered_Floor_Slab',(x,24.017,z),(3.57,.026,2.96),mat,.008,chip=(int(x)+z)%13==0)
            if (z+int(x))%11==0:crack((x-.4,24.033,z-.5),1.4,'floor')
    for x in [99.5,108.5]:box('Sea_Axis_Border',(x,24.033,87),( .35,.012,100),blue_dark,0)
    for z in [45,65,85,105,125]:wave(z)

def bench(p,broken=False,yaw=0):
    x,y,z=p
    for dx in [-1.15,1.15]:box('Pew_Leg',(x+dx,y+.32,z),(.20,.64,.7),wood[2],.03)
    box('Pew_Seat',(x,y+.67,z),(2.8,.14,.8),wood[0],.04,yaw)
    for dx in [-1.17,1.17]:box('Pew_Backpost',(x+dx,y+.9,z-.3),(.17,1.1,.17),wood[1],.035)
    if not broken:box('Pew_Back',(x,y+1.15,z-.3),(2.65,.36,.12),wood[1],.025)
    else:
        box('Snapped_Pew_Back',(x-.65,y+1.12,z-.3),(1.1,.35,.12),wood[1],.02,.09,True)
        box('Fallen_Pew_Plank',(x+.3,y+.08,z+.8),(1.4,.1,.27),wood[2],.025,.45,True)

def goddess():
    x,z=104,33.6;y=26.15
    for width,yy,depth in [(13,24.15,3),(11.7,24.5,2.55),(10.3,24.91,2.0)]:
        box('Chipped_Altar_Tier',(x,yy,34.2),(width,.36,depth),trim,.10,chip=True)
    # Twelve fluted scallop ribs, complete solid backplate with a sea altar frame.
    for i in range(12):
        a=math.radians(8+i*164/12);b=math.radians(8+(i+1)*164/12);mid=(a+b)*.5
        base=(104,29.0,31.8);left=(104+7.1*math.cos(a),30+8.1*math.sin(a),31.8)
        tip=(104+7.25*math.cos(mid),30+8.2*math.sin(mid),32.3);right=(104+7.1*math.cos(b),30+8.1*math.sin(b),31.8)
        mesh('Fluted_Scallop_Backplate',[base,left,tip,right,(104,29,31.5),(left[0],left[1],31.5),(tip[0],tip[1],31.5),(right[0],right[1],31.5)],[(0,1,2),(0,2,3),(4,6,5),(4,7,6),(1,5,6,2),(2,6,7,3),(0,4,5,1),(0,3,7,4)],trim if i%2 else stone[1])
    statue_start=set(art.objects)
    n=16;rings=[]
    for h,rx,rz in [(0,1.92,.94),(.65,1.68,.85),(2.3,1.22,.71),(3.65,1.04,.61),(4.30,.74,.43),(4.90,.65,.39),(5.45,.89,.57),(6.02,1.03,.50),(6.35,.96,.36)]:
        rings.append([(x+rx*(1+.09*(i%2))*math.cos(i*math.tau/n),y+h,z+rz*math.sin(i*math.tau/n)) for i in range(n)])
    ringmesh('Goddess_Folded_Gown',rings,statue_mat)
    # Head shape, neck, restrained stylized face, draped hair and lowered sleeves.
    tube('Goddess_Neck',[(104,y+6.3,z),(104,y+7.1,z)],.32,statue_mat,10)
    head=[]
    for h,rx,rz in [(6.95,.32,.3),(7.15,.49,.40),(7.65,.53,.44),(8.04,.31,.30)]:
        head.append([(104+rx*math.cos(i*math.tau/12),y+h,z+.03+rz*math.sin(i*math.tau/12)) for i in range(12)])
    ringmesh('Goddess_Head',head,statue_mat)
    # Face points towards the entering party (+Godot Z).
    mesh('Goddess_Nose',[(103.94,y+7.52,z+.44),(104.06,y+7.52,z+.44),(104,y+7.28,z+.57),(104,y+7.19,z+.43)],[(0,1,2),(0,2,3),(1,3,2)],statue_mat)
    for sign in [-1,1]:
        # Stone veil frames the face and continues over each shoulder.
        mesh('Goddess_Veil',[(104+sign*.12,y+8.14,z-.31),(104+sign*.61,y+7.96,z-.04),(104+sign*.83,y+6.62,z+.16),(104+sign*1.10,y+5.88,z+.23),(104+sign*.67,y+6.02,z+.35),(104+sign*.43,y+7.23,z+.31)],[(0,1,5),(1,2,5),(2,4,5),(2,3,4)],stone[2])
        tube('Draped_Stone_Hair',[(104+sign*.38,y+7.96,z-.16),(104+sign*.62,y+7.22,z-.27),(104+sign*.69,y+6.12,z-.26),(104+sign*.47,y+5.92,z-.25)],.32,stone[3])
        tube('Goddess_Lowered_Sleeve',[(104+sign*.93,y+6.34,z),(104+sign*1.28,y+5.68,z+.13),(104+sign*1.45,y+4.76,z+.42)],.46,statue_mat)
        tube('Goddess_Hand',[(104+sign*1.45,y+4.8,z+.42),(104+sign*1.17,y+4.35,z+.59)],.23,statue_mat)
    # Uneven longitudinal folds, rather than a single conical gown.
    for i in range(7):
        dx=(i-3)*.38
        tube('Goddess_Robe_Fold',[(104+dx*.43,y+4.4,z+.40),(104+dx*.75,y+2.9,z+.59),(104+dx,y+.5,z+.82),(104+dx*1.20,y+.04,z+.87)],.095,stone[2],5)
    for sign in [-1,1]:
        mesh('Goddess_Eyelid',[(104+sign*.13,y+7.47,z+.443),(104+sign*.33,y+7.46,z+.396),(104+sign*.33,y+7.42,z+.396),(104+sign*.13,y+7.43,z+.443)],[(0,1,2,3)],stone[3])
    crack((103.6,y+2.1,z+.73),1.8)
    for ob in set(art.objects)-statue_start:
        for v in ob.data.vertices:
            # Keep the statue's human proportions: uniform sculpt enlargement.
            v.co.x=104+(v.co.x-104)*1.85
            v.co.y=-z+(v.co.y+z)*1.85
            v.co.z=y+(v.co.z-y)*1.85
        ob['statue_uniform_scale']=True
    for sign in [-1,1]:
        ivy([(104+sign*10,24.1,43),(104+sign*9.3,25.2,39),(104+sign*9.7,29,35),(104+sign*7,31,32.8),(104+sign*7.5,34.1,32.5),(104+sign*4.2,37,32.5)],.54,210)
        foliage((104+sign*8,24.04,40),3,50)
        rubble((104+sign*8.5,24,38),15)

def banner(x,z):
    # Cloth hangs into the nave, visibly torn at the foot; sea-wave embroidery.
    sign=1 if x<104 else -1;xx=x+sign*1.08
    box('Banner_Crossbar',(xx,30.7,z),( .15,.13,2.45),wood[1],.025)
    points=[(xx,30.55,z-1),(xx,30.55,z+1),(xx+sign*.05,26.4,z+1),(xx+sign*.05,26.1,z+.44),(xx+sign*.04,26.7,z+.21),(xx+sign*.06,26.2,z-.5),(xx,26.55,z-1)]
    mesh('Torn_Voyage_Banner',points,[(0,i,i+1) for i in range(1,len(points)-1)],blue_dark)
    for row in range(2):
        vertices=[]
        for i in range(17):
            zz=z+(i/16-.5)*1.5;yy=27.55+row*.35+math.sin(i/16*math.tau*1.5)*.12
            vertices.extend([(xx+sign*.035,yy-.028,zz),(xx+sign*.035,yy+.028,zz)])
        mesh('Banner_Sea_Waves',vertices,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(16)],trim)
    # Scallop crest composed of broad fan planes.
    for i in range(7):
        a=(i/7-.5)*math.pi;b=((i+1)/7-.5)*math.pi
        mesh('Banner_Scallop',[(xx+sign*.04,28.6,z),(xx+sign*.04,28.6+math.cos(a)*.66,z+math.sin(a)*.66),(xx+sign*.04,28.6+math.cos(b)*.66,z+math.sin(b)*.66)],[(0,1,2)],trim)

def wall_scar(x,z):
    sign=1 if x<104 else -1
    # Irregular plaster loss reveals rubble masonry, a localized damage story.
    outline=[(x,24.04,z-2),(x,27,z-1.8),(x,28.7,z-.9),(x,28.2,z+.6),(x,26.4,z+1.7),(x,24.04,z+2.5)]
    mesh('Missing_Limewash',outline,[(0,i,i+1) for i in range(1,len(outline)-1)],cut)
    for i in range(12):
        h=.3+(i//3)*.78;zz=z-1+(i%3)*.77
        box('Exposed_Rubble_Core',(x+sign*.06,24+h,zz),(.13,.62,.68),stone[3 if i%2 else 0],.045,chip=True)
    rubble((x+sign*.65,24,z),14)
    ivy([(x+sign*.3,24.08,z+1.1),(x+sign*.18,26.4,z+.5),(x+sign*.14,29.5,z-.3),(x+sign*.10,31,z-1.0)],.36,75)

# MAIN NAVE: mass, material courses, arcade, vault, age.
print('BUILD_STAGE nave',flush=True)
floor()
for z in [102,116,130]:
    for x in [91,117]:
        damaged=(x,z) in [(91,116),(117,130)]
        pier(x,z,damaged=damaged)
        banner(x,z+.12)
        # Root actually climbs each support from its wall-side foundation.
        sign=1 if x<104 else -1
        ivy([(x-sign*.8,24.04,z+1.8),(x+sign*.9,26.0,z+.95),(x+sign*1.08,29,z-.6),(x-sign*.3,32,z-1.05),(x-sign*.8,35.8,z-.6)],.34,85)
        foliage((x,24.03,z+1.4),2.1,42)
    arch('Cross_Nave_Rib',(104,z),13.05,8.15,31.1,.85,.52)
for z in range(96,139,7):vault_bay(z,min(z+7,139))
for z0 in [102,116]:
    for reverse in [False,True]:
        pts=[]
        for i in range(25):
            t=i/24;xx=13*(2*t-1)
            yy=31.1+8.15*(1-abs(2*t-1))**.65
            pts.append((104+xx,yy,z0+14*(1-t if reverse else t)))
        tube('Crossed_Vault_Rib',pts,.17,trim,6)
for x in [91,117]:
    for z in [109,123]:
        arch('Aisle_Arcade',(x,z),6.95,5.8,31.1,1.45,.58,math.pi/2,missing=(1,2) if x==91 and z==109 else ())
    for z in [109,123,136]:niche(89.06 if x<104 else 118.94,z,right=x>104)
    box('High_Cornice',(89.10 if x<104 else 118.90,29.5,118),(.40,.28,41),trim,.065)
    wall_scar(89.06 if x<104 else 118.94,110 if x<104 else 126)
    for z in [104,120,132]:bench((94.5 if x<104 else 113.5,24,z),broken=z!=120)
    for z in [106,124,134]:
        crack((88.56 if x<104 else 119.44,27.3,z),3.0,'side')
    # One damaged wall-facing pilaster and its displaced capital, beside the route.
    rubble((89.2 if x<104 else 118.8,24,110 if x<104 else 126),12)

# The transept remains broad for combat; suspended ribs continue the architecture.
for z in [66,84]:
    for x in [88,120]:
        if z==66:pier(x,z,top=31.1,damaged=x==120)
        else:box('Crossing_High_Corbel',(x,31.1,z),(2.3,.8,2.1),trim,.1,chip=True)
    arch('Upper_Nave_Rib',(104,z),16,8.15,31.1,.85,.65)
for z in range(60,96,6):vault_bay(z,z+6,16,31.1,8.15)
for z in [44,58]:arch('Apse_High_Rib',(104,z),18.5,8.15,31.1,.70,.55)
for z in range(44,60,4):vault_bay(z,z+4,18.5,31.1,8.15)
for x in [86.5,121.5]:
    for z in [48,61]:pier(x,z,damaged=x<104 and z==48)
    arch('Apse_Wall_Arcade',(x,54.5),6.5,5.8,31.1,1.0,.55,math.pi/2)
    niche(85.12 if x<104 else 122.88,54,y=29.8,right=x>104)
    wall_scar(85.12 if x<104 else 122.88,48.8 if x<104 else 59)
    for z in [48,61]:
        ivy([(x,24.05,z),(x,26,z-1),(x+.7,29,z-.5),(x+.6,33,z-1.2)],.35,45)
        foliage((x,24,z),2.0,32)
goddess()
# Cathedral proportions: 29m clear height above the same y24 floor. This is
# a structural height change, not a camera trick. Keep leaves and furniture
# at their original size while moving climbing foliage up the taller piers.
HEIGHT_SCALE=1.90
for ob in list(art.objects):
    if ob['zone']!='Nave' and not ob['zone'].startswith('Solid_Pier_'):continue
    if ob.get('statue_uniform_scale'):continue
    if any(key in ob.name for key in ['Floor','Inlay','Border','Paving','Dislodged','Pew_']):continue
    if 'Ivy_Leaf' in ob.name:
        center=sum((v.co for v in ob.data.vertices),Vector())/len(ob.data.vertices)
        shift=max(0,center.z-24)*(HEIGHT_SCALE-1)
        for v in ob.data.vertices:v.co.z+=shift
    else:
        for v in ob.data.vertices:
            if v.co.z>24.06:v.co.z=24+(v.co.z-24)*HEIGHT_SCALE
print('BUILD_STAGE other_rooms',len(art.objects),flush=True)

# Ruin finish elsewhere follows the same temple palette, not different room themes.
layout=json.loads((ROOT/'assets/models/sanctum_unity_v2/layout.json').read_text(encoding='utf-8'))
skip={'nave','apse','broken_stair','loading_ramp','east_stair','bell_stair','bell_bridge','garden_ramp'}
for f in layout['floors']:
    if f['id'] in skip or 'link' in f['id']:continue
    group='Ruin_'+f['id'];y=float(f['level']);poly=f['polygon']
    # Fractured threshold/corner paving is flat; centre and empty side rooms stay free.
    cx=sum(p[0] for p in poly)/len(poly);cz=sum(p[1] for p in poly)/len(poly)
    for index,pt in enumerate(poly):
        if index%2:continue
        inward=Vector((cx-pt[0],0,cz-pt[1])).normalized()
        p=(pt[0]+inward.x*1.6,y,pt[1]+inward.z*1.6)
        if f['id'] not in ('side_gate_rest','side_hermit'):
            rubble(p,4)
        for i in range(3):
            box('Broken_Corner_Paving',(p[0]+inward.x*i*.65,y+.018,p[2]+inward.z*i*.65),(1.25,.025,1.4),stone[(index+i)%5],.015,chip=True)
        foliage((p[0],y+.04,p[2]),1.5,15)
    # Vertical dry damp stains and chipped low wall courses beside a corner,
    # away from middle-of-edge doors. Underground keeps its covered silhouette.
    for j in [0,2]:
        if j>=len(poly):continue
        a=Vector((poly[j][0],y,poly[j][1]));bb=Vector((poly[(j+1)%len(poly)][0],y,poly[(j+1)%len(poly)][1]));direction=(bb-a).normalized()
        inward=Vector((cx-a.x,0,cz-a.z)).normalized()
        start=a+direction*2+inward*.18
        ivy([start+Vector((0,.15,0)),start+direction*.3+Vector((0,1.4,0)),start+direction*.6+Vector((0,3.3,0))],.17,18)

# Crypt bays: broken stone ribs and a detached wall-facing block, no reduced route.
group='Ruin_Cellar'
for z in [114,132]:
    arch('Crypt_Vault_Rib',(107,z),9.7,3.2,19.0,.62,.40)
    for x in [97.4,116.6]:
        box('Crypt_Wall_Pilaster',(x,14,z),(1.0,11.9,1.1),stone[3],.055,chip=z==132)
        crack((x+.15,10.3,z+.56),2.6)

# Save editable, named source first. References remain recoverable in the file.
print('BUILD_STAGE save',len(art.objects),flush=True)
structure=bpy.data.collections.new('STRUCTURE_HEIGHT_REVISION')
scene.collection.children.link(structure)
nave_polygons=[f['polygon'] for f in layout['floors'] if f['id'] in ('nave','apse')]
def inside_or_edge(x,z,poly):
    inside=False
    for i,a in enumerate(poly):
        b=poly[(i+1)%len(poly)]
        pa=Vector((a[0],a[1]));pb=Vector((b[0],b[1]));p=Vector((x,z))
        edge=pb-pa;t=max(0,min(1,(p-pa).dot(edge)/edge.length_squared))
        if (p-(pa+edge*t)).length<1.15:return True
        if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:inside=not inside
    return inside
changed=0
for ob in reference.objects:
    if ob.type!='MESH':continue
    copy=ob.copy();copy.data=ob.data.copy();structure.objects.link(copy);copy.name=ob.name
    if any(key in ob.name for key in ['walls','roofs','detail']) and 'buried' not in ob.name:
        inv=copy.matrix_world.inverted()
        for v in copy.data.vertices:
            world=copy.matrix_world@v.co;x,y,z=world.x,world.z,-world.y
            if y>24.06 and any(inside_or_edge(x,z,poly) for poly in nave_polygons):
                world.z=24+(y-24)*HEIGHT_SCALE;v.co=inv@world;changed+=1
    # Original node names are needed by Godot material/collision setup.
    ob.name='REFERENCE_'+ob.name;copy.name=ob.name.replace('REFERENCE_','')
    if copy.name=='terrain':copy.hide_render=True
print('STRUCTURE_CHANGED_VERTICES',changed,flush=True)
# Real clerestory apertures in the above-ground walls. These are high windows,
# not player exits, and do not excavate or expose any basement roof.
cutters=bpy.data.collections.new('WINDOW_APERTURE_TOOLS');scene.collection.children.link(cutters)
old_group=group;group='WindowTools'
tools=[]
for x in [88.5,119.5]:
    for z in [109,123,136]:
        ob=box('High_Window_Cutter',(x,39.45,z),(4.5,7.1,2.18),glass,0)
        art.objects.unlink(ob);cutters.objects.link(ob);tools.append(ob)
for x in [84.5,123.5]:
    ob=box('Apse_Window_Cutter',(x,39.45,54),(4.5,7.1,2.18),glass,0)
    art.objects.unlink(ob);cutters.objects.link(ob);tools.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for ob in tools:ob.select_set(True)
bpy.context.view_layer.objects.active=tools[0];bpy.ops.object.join();cutter=tools[0]
wall=next(ob for ob in structure.objects if ob.name=='walls')
mod=wall.modifiers.new('Real_Clerestory_Apertures','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
bpy.context.view_layer.objects.active=wall;bpy.ops.object.modifier_apply(modifier=mod.name)
wall.data.validate(verbose=True,clean_customdata=False)
bm=bmesh.new();bm.from_mesh(wall.data)
# The original merged whitebox contains intersecting wall solids. An exact
# Boolean left one internal sliver at the western window. Partition against
# cutter planes and remove interior faces deterministically as a final repair.
window_boxes=[(x,z) for x in [88.5,119.5] for z in [109,123,136]]+[(84.5,54),(123.5,54)]
inv=wall.matrix_world.inverted()
for wx,wz in window_boxes:
    for axis,coord in [(0,wx-2.25),(0,wx+2.25),(1,35.9),(1,43.0),(2,wz-1.09),(2,wz+1.09)]:
        p=[0.0,0.0,0.0];p[axis]=coord;n=[0.0,0.0,0.0];n[axis]=1.0
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=inv@P(p),plane_no=wall.matrix_world.to_3x3().transposed()@P(n),dist=.00001)
    delete=[]
    for face in bm.faces:
        co=wall.matrix_world@face.calc_center_median();xx,yy,zz=co.x,co.z,-co.y
        if wx-2.25+.0001<xx<wx+2.25-.0001 and 35.9+.0001<yy<43.0-.0001 and wz-1.09+.0001<zz<wz+1.09-.0001:delete.append(face)
    bmesh.ops.delete(bm,geom=delete,context='FACES')
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(wall.data);bm.free();wall.data.validate(clean_customdata=False);wall.data.update()
cutters.hide_render=True;cutters.hide_viewport=True;group=old_group
print('STRUCTURE_HIGH_WINDOWS',8,flush=True)
group='Source'
for ob in art.objects:
    if ob.type=='MESH':
        for poly in ob.data.polygons:poly.use_smooth=False
scene.world.color=(.18,.20,.23)
cam_data=bpy.data.cameras.new('Review_Camera');cam=bpy.data.objects.new('Review_Camera',cam_data);scene.collection.objects.link(cam)
cam.location=P((104,32,132));direction=P((104,29,38))-cam.location;cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler();cam_data.lens=23
scene.camera=cam
for x in [91,117]:
    for z in [104,120,133,68,47]:
        ld=bpy.data.lights.new('Window_Review_Light','AREA');ld.energy=1300;ld.shape='DISK';ld.size=5
        ob=bpy.data.objects.new(ld.name,ld);scene.collection.objects.link(ob);ob.location=P((x,44,z));direction=P((104,25,z-5))-ob.location;ob.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
engines=[i.identifier for i in scene.render.bl_rna.properties['engine'].enum_items]
scene.render.engine='BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engines else 'BLENDER_EEVEE'
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sea_temple_ruin.blend'))
source_objects=len(art.objects)
bpy.ops.object.select_all(action='DESELECT')
for ob in structure.objects:ob.hide_render=False;ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'sea_temple_structure.glb'),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_materials='EXPORT')
# Export palette/zone batches. Editable .blend above retains individual stone courses.
for key in sorted(set(ob['zone'] for ob in art.objects)):
    bpy.ops.object.select_all(action='DESELECT')
    objs=[ob for ob in art.objects if ob['zone']==key and ob.type=='MESH']
    for ob in objs:ob.select_set(True)
    if not objs:continue
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.join();objs[0].name=key
    # Consolidate identical material slots produced by joining individual blocks.
    bpy.ops.object.material_slot_remove_unused()
bpy.ops.object.select_all(action='DESELECT')
for ob in art.objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'sea_temple_ruin.glb'),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
manifest={'tool':bpy.app.version_string,'whitebox_reference':'assets/models/sanctum_unity_v2/sanctum_architecture.glb','original_whitebox_sha256':hashlib.sha256((ROOT/'assets/models/sanctum_unity_v2/sanctum_architecture.glb').read_bytes()).hexdigest(),'source_objects':source_objects,'export_meshes':len(art.objects),'triangles':sum(len(o.data.loop_triangles) for o in art.objects),'bounds':'original footprints, routes and floor levels retained; nave/apse wall and solid roof height revised from y40 to y54.4','structure_changed_vertices':changed,'scope':'rebuilt tall nave and altar; consistent ruin finish in other rooms; not full dungeon art acceptance','lighting':'Blender review lamps are not exported; Godot owns real window lights','blend_sha256':hashlib.sha256((OUT/'sea_temple_ruin.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((OUT/'sea_temple_ruin.glb').read_bytes()).hexdigest(),'structure_sha256':hashlib.sha256((OUT/'sea_temple_structure.glb').read_bytes()).hexdigest()}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('SANCTUM_BLENDER_BUILD',json.dumps(manifest))
