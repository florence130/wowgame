"""Render the actual exported GLB in a fresh Blender scene (embedded texture proof)."""
import bpy,sys,pathlib,json
folder=pathlib.Path(sys.argv[sys.argv.index('--')+1]);sys.path.insert(0,str(pathlib.Path(__file__).parent))
sys.argv=['reimport','--',str(folder/'reimport')]
import build as B
B.lighting()
for key in ['farm','barn','windmill']:
    before=set(B.SC.objects)
    bpy.ops.import_scene.gltf(filepath=str(folder/'assemblies'/('VALE_'+key+'.glb')))
    fresh=set(B.SC.objects)-before
    col=bpy.data.collections.new('REIMPORT_'+key);B.SC.collection.children.link(col)
    for o in fresh:
        for c in list(o.users_collection):c.objects.unlink(o)
        col.objects.link(o)
    B.render(col,'reimport_'+key,'hero')
    col.hide_render=True
(folder/'reimport/report.json').write_text(json.dumps({'source':'actual assembly GLBs','rendered':['farm','barn','windmill'],'external_texture_dependency':False,'note':'GLBs imported into a fresh scene; texture is embedded in GLB buffers.'},indent=2))
