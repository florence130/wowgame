import sys,pathlib,bpy
sys.path.insert(0,str(pathlib.Path(__file__).parent))
import build as B
r,c=B.context('THATCH_PROBE_01')
B.roof_section(8,9,4.3,'thatch',caps=(True,True))
before=set(c.objects);B.ridge(8,'thatch')
for o in set(c.objects)-before:o.location.z+=4.3
B.export(r,c,'stages');c.hide_render=True;B.lighting();B.SC.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(B.OUT/'thatch_probe.blend'))
B.render(c,'thatch_probe','hero')
print('THATCH_PROBE_COMPLETE')
