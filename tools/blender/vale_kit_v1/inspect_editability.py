"""Inspect the saved source file rather than inferring editability from code."""
import bpy,collections,json,pathlib,sys
folder=pathlib.Path(sys.argv[sys.argv.index('--')+1])
counts=collections.Counter();examples={}
for o in bpy.data.objects:
    for mod in o.modifiers:
        counts[mod.type]+=1
        examples.setdefault(mod.type,{'object':o.name,'modifier':mod.name})
expected=['MIRROR','ARRAY','SOLIDIFY','SCREW','CURVE','SIMPLE_DEFORM']
result={'source_file':bpy.data.filepath,'modifier_counts':dict(counts),'examples':examples,
    'editable_modifier_types_present':all(counts[t]>0 for t in expected),
    'scope':'Six modifier methods verified in saved Blend. Extrusion, bevel curves, bridge/loft and direct vertices are source geometry; see BREAKDOWN for all ten methods.'}
(folder/'source_inspection.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
