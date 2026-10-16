"""Load with Blender Text Editor > Run Script, or through existing Blender MCP.

Adds an Abbey Kit sidebar. Appends a selected source collection as a linked-data
instance, preserving editable source meshes/modifiers. Does not clear any scene.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from bpy.props import StringProperty,EnumProperty,PointerProperty

_ITEMS=[('NONE','Load a build folder','')]
_MANIFEST={}

class ABY_Settings(bpy.types.PropertyGroup):
    directory:StringProperty(name='Build folder',subtype='DIR_PATH',default='E:/wowgame/assets/models/abbey_kit_v1/build_004/')
    asset:EnumProperty(name='Component',items=lambda self,context:_ITEMS)
    target_socket:StringProperty(name='Active socket',default='right')
    moving_socket:StringProperty(name='Moving socket',default='left')

class ABY_OT_read(bpy.types.Operator):
    bl_idname='aby.read_catalog';bl_label='Read Catalog'
    def execute(self,ctx):
        global _ITEMS,_MANIFEST
        try:
            folder=Path(bpy.path.abspath(ctx.scene.aby_settings.directory))
            _MANIFEST=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
            _ITEMS=[(a['id'],a['label_zh']+' / '+a['id'],str(a['triangles'])+' triangles') for a in _MANIFEST['assets']]
            ctx.scene.aby_settings.asset=_ITEMS[0][0]
        except Exception as e:self.report({'ERROR'},str(e));return {'CANCELLED'}
        return {'FINISHED'}

class ABY_OT_add(bpy.types.Operator):
    bl_idname='aby.add_component';bl_label='Add at Cursor';bl_options={'REGISTER','UNDO'}
    def execute(self,ctx):
        st=ctx.scene.aby_settings;key=st.asset;folder=Path(bpy.path.abspath(st.directory));source=str((folder/'abbey_kit.blend').resolve())
        if key=='NONE':return {'CANCELLED'}
        found=next((c for c in bpy.data.collections if c.get('aby_source_file')==source and c.get('aby_asset_id')==key),None)
        if not found and bpy.data.filepath and Path(bpy.data.filepath).resolve()==Path(source):
            found=bpy.data.collections.get('ABY_'+key)
        if not found:
            with bpy.data.libraries.load(source,link=False) as (src,dst):
                name='ABY_'+key
                if name not in src.collections:self.report({'ERROR'},'Collection missing: '+name);return {'CANCELLED'}
                dst.collections=[name]
            found=dst.collections[0]
        found['aby_source_file']=source;found['aby_asset_id']=key
        o=bpy.data.objects.new('KIT_'+key,None);o.instance_type='COLLECTION';o.instance_collection=found;o.location=ctx.scene.cursor.location
        o['asset_id']=key;o['source_build']=str(folder)
        ctx.scene.collection.objects.link(o);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);ctx.view_layer.objects.active=o
        return {'FINISHED'}

class ABY_OT_snap(bpy.types.Operator):
    bl_idname='aby.snap_component';bl_label='Snap Other to Active';bl_options={'REGISTER','UNDO'}
    def execute(self,ctx):
        target=ctx.view_layer.objects.active;others=[o for o in ctx.selected_objects if o!=target]
        if len(others)!=1 or not target:self.report({'ERROR'},'Select two kit instances; active object is the fixed target.');return {'CANCELLED'}
        moving=others[0];st=ctx.scene.aby_settings;catalog={a['id']:a for a in _MANIFEST.get('assets',[])}
        try:
            ta=next(s for s in catalog[target['asset_id']]['sockets'] if s['name']==st.target_socket)
            ma=next(s for s in catalog[moving['asset_id']]['sockets'] if s['name']==st.moving_socket)
        except (KeyError,StopIteration):self.report({'ERROR'},'Socket not available on selected components.');return {'CANCELLED'}
        if ta['kind']!=ma['kind']:self.report({'ERROR'},'Socket families differ: '+ta['kind']+' / '+ma['kind']);return {'CANCELLED'}
        if any(abs(x-1)>1e-5 for o in (target,moving) for x in o.scale):self.report({'ERROR'},'Use unscaled kit instances for measured snapping.');return {'CANCELLED'}
        tn=target.matrix_world.to_3x3()@Vector(ta['normal_blender']);mn=moving.matrix_world.to_3x3()@Vector(ma['normal_blender'])
        q=mn.rotation_difference(-tn);moving.rotation_mode='QUATERNION';moving.rotation_quaternion=q@moving.matrix_world.to_quaternion();ctx.view_layer.update()
        moving.location += (target.matrix_world@Vector(ta['position_blender']))-(moving.matrix_world@Vector(ma['position_blender']))
        return {'FINISHED'}

class ABY_PT_panel(bpy.types.Panel):
    bl_label='Dawnbell Abbey Kit';bl_idname='ABY_PT_panel';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Abbey Kit'
    def draw(self,ctx):
        l=self.layout;s=ctx.scene.aby_settings;l.prop(s,'directory');l.operator('aby.read_catalog');l.prop(s,'asset');l.operator('aby.add_component')
        l.separator();l.label(text='Select moving, then active target');l.prop(s,'moving_socket');l.prop(s,'target_socket');l.operator('aby.snap_component')
        l.label(text='Source modifiers stay in collections')

CLASSES=(ABY_Settings,ABY_OT_read,ABY_OT_add,ABY_OT_snap,ABY_PT_panel)
def unregister():
    if hasattr(bpy.types.Scene,'aby_settings'):del bpy.types.Scene.aby_settings
    for cls in reversed(CLASSES):
        old=getattr(bpy.types,cls.__name__,None)
        if old:
            try:bpy.utils.unregister_class(old)
            except RuntimeError:pass
def register():
    unregister()
    for cls in CLASSES:bpy.utils.register_class(cls)
    bpy.types.Scene.aby_settings=PointerProperty(type=ABY_Settings)
if __name__=='__main__':register()
