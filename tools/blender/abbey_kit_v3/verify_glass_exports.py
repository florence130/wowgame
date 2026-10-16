"""Validate transparent window material semantics in every final GLB."""
import json,struct,sys
from pathlib import Path
out=Path(sys.argv[1]);rows=[]
for path in sorted([*(out/'glb').glob('*.glb'),*(out/'assemblies').glob('*.glb')]):
    b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0];data=json.loads(b[20:20+n])
    for m in data.get('materials',[]):
        key=m.get('extras',{}).get('recipe_key')
        if key not in ('glass','glass_amber'):continue
        alpha=m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])[3]
        transmission=m.get('extensions',{}).get('KHR_materials_transmission',{}).get('transmissionFactor',0)
        emit=m.get('emissiveFactor',[0,0,0]);mode=m.get('alphaMode','OPAQUE')
        rows.append(dict(file=str(path.relative_to(out)),material=m['name'],recipe_key=key,alpha=alpha,transmission=transmission,alphaMode=mode,
            passed=mode=='BLEND' and abs(alpha-.28)<1e-5 and transmission>.7 and not any(emit) and 'KHR_materials_unlit' not in m.get('extensions',{})))
report=dict(passed=bool(rows) and all(r['passed'] for r in rows),material_uses=len(rows),checks=rows,scope='Actual GLB alpha blend, optical transmission extension, non-emissive lit window materials; rendered proof and Godot import checked separately.')
(out/'glass_export_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'passed':report['passed'],'material_uses':len(rows)}))
sys.exit(0 if report['passed'] else 1)
