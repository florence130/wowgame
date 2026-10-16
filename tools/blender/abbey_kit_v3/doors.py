"""Two separate oak leaves with real hinge origins. +Y opens outside."""
import bpy, math
import geometry as G
import details as D

def hinged_door(width=2.44,spring=2.43):
    before=set(G.COL.objects);parent=G.ROOT
    full=D.oak_double_door(width,spring)[0]
    for side,label in [(-1,'Left'),(1,'Right')]:
        leaf=full.copy();leaf.data=full.data.copy();G.COL.objects.link(leaf)
        leaf.name='DoorLeaf_'+label
        # Remove the other half, including a narrow true center seam.
        cut=G.box('Half leaf boolean',(width*2,3,8),(-side*width,.0,3),None)
        cut.location.x=side*.008
        G.subtract(leaf,cut)
        pivot=bpy.data.objects.new('HINGE_'+label,None);G.COL.objects.link(pivot)
        pivot.parent=parent;pivot.location=(side*width/2,0,0)
        pivot['hinge_axis']='Z';pivot['open_sign']=-side
        pivot.empty_display_type='ARROWS';pivot.empty_display_size=.25
        leaf.parent=pivot
        for v in leaf.data.vertices:v.co.x-=side*width/2
        leaf['separable_component']=True
        # Back bracing remains visible once the door is open.
        for z in (.32,2.04):
            brace=G.box('Door inner cross rail',(width*.43,.09,.16),(side*width*.255,-.145,z),'timber',.008)
            for v in brace.data.vertices:v.co.x-=side*width/2
            brace.parent=pivot
    bpy.data.objects.remove(full,do_unlink=True)
    for side in (-1,1):
        for z in (.29,2.04):
            G.box('Fixed iron hinge anchor',(.19,.42,.10),(side*(width/2+.08),-.16,z),'iron',.008)
            G.line('Fixed vertical hinge pin',[(side*width/2,0,z-.12),(side*width/2,0,z+.12)],.025,'iron')
    parent['door_angle_degrees']=0.0
    parent['threshold_width']=width
    return list(set(G.COL.objects)-before)

def set_angle(root,degrees):
    root['door_angle_degrees']=float(degrees)
    for ob in root.children_recursive:
        if 'open_sign' in ob:ob.rotation_euler.z=math.radians(degrees)*ob['open_sign']

def export_hierarchy(root,path):
    """Evaluated meshes, named pivots and local transforms survive GLB export."""
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    mapping={};temp=[]
    for src in [root]+list(root.children_recursive):
        if src.type not in ('EMPTY','MESH','CURVE'):continue
        data=bpy.data.meshes.new_from_object(src.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg) if src.type!='EMPTY' else None
        if data:
            import build as legacy
            legacy.add_uv(data)
        ob=bpy.data.objects.new(src.name,data);bpy.context.scene.collection.objects.link(ob)
        for key in src.keys():ob[key]=src[key]
        mapping[src]=ob;temp.append(ob)
    for src,ob in mapping.items():
        if src==root:ob.matrix_world.identity()
        else:ob.parent=mapping[src.parent];ob.matrix_basis=src.matrix_basis.copy()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in temp:ob.select_set(True)
    bpy.context.view_layer.objects.active=mapping[root]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_extras=True,export_yup=True,export_apply=False,export_animations=False)
    for ob in temp:bpy.data.objects.remove(ob,do_unlink=True)
