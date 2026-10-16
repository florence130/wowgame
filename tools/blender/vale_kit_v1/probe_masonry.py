import sys,pathlib,bpy
sys.path.insert(0,str(pathlib.Path(__file__).parent));import build as B
r,c=B.context('MASONRY_PROBE')
start=set(c.objects);B.wall(4,3,'farm')
for o in set(c.objects)-start:o.location.x-=2.35
start=set(c.objects);B.wall(4,3,'barn')
for o in set(c.objects)-start:o.location.x+=2.35
B.export(r,c,'stages');c.hide_render=True;B.lighting();B.SC.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(B.OUT/'material_probe.blend'))
B.render(c,'masonry_probe','hero')
