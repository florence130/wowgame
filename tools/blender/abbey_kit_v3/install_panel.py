"""Load editable kit catalog, measured snapping, repeat placement and door hinges."""
import bpy,runpy,json,math
from pathlib import Path
from mathutils import Vector
from bpy.props import FloatProperty,IntProperty
HERE=Path(__file__).resolve().parent
PROJECT=HERE.parents[2]
runpy.run_path(str(HERE.parent/'abbey_kit/blender_panel.py'),run_name='__main__')

def folder(ctx):return Path(bpy.path.abspath(ctx.scene.aby_settings.directory))
def root_of(ob):
    if not ob:return None
    while ob.parent and not ob.get('asset_id'):ob=ob.parent
    return ob

class ABY3_OT_editable(bpy.types.Operator):
    bl_idname='aby3.add_editable';bl_label='Add Editable Component';bl_options={'REGISTER','UNDO'}
    def execute(self,ctx):
        key=ctx.scene.aby_settings.asset;source=folder(ctx)/'abbey_kit.blend'
        if bpy.data.filepath and Path(bpy.data.filepath).resolve()==source.resolve():col=bpy.data.collections.get('ABY_'+key)
        else:
            with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.collections=['ABY_'+key]
            col=dst.collections[0]
        srcroot=next(o for o in col.objects if o.get('asset_id')==key)
        mapping={}
        for old in [srcroot]+list(srcroot.children_recursive):
            ob=old.copy();ob.data=old.data;ctx.scene.collection.objects.link(ob);mapping[old]=ob
        for old,ob in mapping.items():
            if old==srcroot:ob.parent=None;ob.location=ctx.scene.cursor.location
            else:ob.parent=mapping[old.parent];ob.matrix_basis=old.matrix_basis.copy()
        root=mapping[srcroot];root['source_build']=str(folder(ctx))
        bpy.ops.object.select_all(action='DESELECT');root.select_set(True);ctx.view_layer.objects.active=root
        return {'FINISHED'}

class ABY3_OT_door(bpy.types.Operator):
    bl_idname='aby3.set_door_angle';bl_label='Set Door Opening';bl_options={'REGISTER','UNDO'}
    def execute(self,ctx):
        root=root_of(ctx.active_object)
        if not root or root.get('asset_id')!='door_hinged' or root.instance_type=='COLLECTION':
            self.report({'ERROR'},'Select an editable door root. Use Add Editable Component.');return {'CANCELLED'}
        angle=ctx.scene.aby3_door_angle
        for ob in root.children_recursive:
            if 'open_sign' in ob:ob.rotation_euler.z=math.radians(angle)*ob['open_sign']
        root['door_angle_degrees']=angle
        return {'FINISHED'}

class ABY3_OT_repeat(bpy.types.Operator):
    bl_idname='aby3.repeat';bl_label='Repeat Along Socket Pitch';bl_options={'REGISTER','UNDO'}
    def execute(self,ctx):
        src=ctx.active_object
        if not src or src.instance_type!='COLLECTION':self.report({'ERROR'},'Select a catalog collection instance.');return {'CANCELLED'}
        if any(abs(v-1)>1e-5 for v in src.scale):self.report({'ERROR'},'Use unscaled source pieces for measured repeats.');return {'CANCELLED'}
        cat=json.loads((folder(ctx)/'manifest.json').read_text(encoding='utf8'))
        ports=next(a for a in cat['assets'] if a['id']==src['asset_id'])['sockets']
        try:start=next(p for p in ports if p['name']=='start');end=next(p for p in ports if p['name']=='end')
        except StopIteration:self.report({'ERROR'},'This component has no linear repeat sockets.');return {'CANCELLED'}
        delta=src.matrix_world.to_3x3()@(Vector(end['position_blender'])-Vector(start['position_blender']))
        for i in range(1,ctx.scene.aby3_repeat_count):
            ob=src.copy();ctx.scene.collection.objects.link(ob);ob.location=src.location+delta*i
        return {'FINISHED'}

class ABY3_PT_panel(bpy.types.Panel):
    bl_label='Interior / Repeat / Hinged Doors';bl_idname='ABY3_PT_panel';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Abbey Kit'
    def draw(self,ctx):
        l=self.layout;l.operator('aby3.add_editable');l.prop(ctx.scene,'aby3_door_angle');l.operator('aby3.set_door_angle')
        l.separator();l.prop(ctx.scene,'aby3_repeat_count');l.operator('aby3.repeat')
        l.label(text='Metres | +Z up | +Y front')

for cls in (ABY3_OT_editable,ABY3_OT_door,ABY3_OT_repeat,ABY3_PT_panel):
    old=getattr(bpy.types,cls.__name__,None)
    if old:bpy.utils.unregister_class(old)
    bpy.utils.register_class(cls)
bpy.types.Scene.aby3_door_angle=FloatProperty(name='Door angle',default=105,min=0,max=110)
bpy.types.Scene.aby3_repeat_count=IntProperty(name='Total repeats',default=3,min=2,max=30)
pointer=PROJECT/'assets/models/abbey_kit_v3/LATEST.json'
if pointer.exists():path=json.loads(pointer.read_text(encoding='utf8'))['build_directory']
else:path=str(PROJECT/'assets/models/abbey_kit_v3/build001')
bpy.context.scene.aby_settings.directory=path
bpy.context.scene.aby_settings.target_socket='end';bpy.context.scene.aby_settings.moving_socket='start'
bpy.ops.aby.read_catalog()
