"""Run in Blender Text Editor: reusable module library + metric socket snapping.
Only adds a panel and appends requested GS_ collections. Does not replace open work.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
BUILD=Path('E:/wowgame/assets/models/goldshire_kit_v1/build_004')
manifest=json.loads((BUILD/'manifest.json').read_text(encoding='utf8'))
ASSETS={x['id']:x for x in manifest['modules']}

class GS_OT_add(bpy.types.Operator):
    bl_idname='gs.add_module';bl_label='放置构件';bl_options={'REGISTER','UNDO'}
    def execute(self,context):
        key=context.scene.gs_module;name='GS_'+key
        col=bpy.data.collections.get(name)
        if col is None:
            with bpy.data.libraries.load(str(BUILD/'goldshire_kit.blend'),link=False) as (src,dst):dst.collections=[name]
            col=dst.collections[0]
        obj=bpy.data.objects.new('Placed_'+key,None);context.collection.objects.link(obj)
        obj.instance_type='COLLECTION';obj.instance_collection=col;obj.location=context.scene.cursor.location
        obj['asset_id']=key
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);context.view_layer.objects.active=obj
        return {'FINISHED'}

class GS_OT_snap(bpy.types.Operator):
    bl_idname='gs.snap_end';bl_label='末端接到活动件起端';bl_options={'REGISTER','UNDO'}
    def execute(self,context):
        anchor=context.active_object;selected=[o for o in context.selected_objects if o!=anchor]
        if not anchor or len(selected)!=1:return {'CANCELLED'}
        moving=selected[0];a=ASSETS.get(anchor.get('asset_id'),{}).get('sockets',[]);b=ASSETS.get(moving.get('asset_id'),{}).get('sockets',[])
        if len(a)<2 or len(b)<2 or a[0]['kind']!=b[0]['kind']:
            self.report({'WARNING'},'请选择同类接口的两个构件');return {'CANCELLED'}
        moving.rotation_euler=anchor.rotation_euler.copy()
        dest=anchor.matrix_world@Vector(a[1]['position_blender'])
        moving.location=dest-moving.rotation_euler.to_matrix()@Vector(b[0]['position_blender'])
        return {'FINISHED'}

class GS_PT_library(bpy.types.Panel):
    bl_label='金穗村 · 模块库';bl_idname='GS_PT_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Goldshire'
    def draw(self,context):
        l=self.layout;l.label(text='米制 · 墙体2m · 层高3.4m');l.prop(context.scene,'gs_module',text='构件');l.operator('gs.add_module');l.operator('gs.snap_end')
        l.label(text='光标定位；两构件同类接口可吸附')
        l.label(text='实例可共享编辑；独立编辑请转为实体')

for cls in (GS_OT_add,GS_OT_snap,GS_PT_library):
    old=getattr(bpy.types,cls.__name__,None)
    if old:bpy.utils.unregister_class(old)
    bpy.utils.register_class(cls)
bpy.types.Scene.gs_module=bpy.props.EnumProperty(items=[(k,v['label_zh'],k) for k,v in ASSETS.items()])
print('Goldshire panel installed; existing scene retained.')
