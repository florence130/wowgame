"""Independently inspect actual GLB accessors, embedded material/image contracts and seams."""
import sys,json,struct,hashlib,importlib.util
from pathlib import Path
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('reader',HERE.parent/'abbey_kit_v2/verify_exports.py');V=importlib.util.module_from_spec(spec);spec.loader.exec_module(V)
out=Path(sys.argv[1]);pal=json.loads((HERE.parents[2]/'docs/palette/palette.json').read_text(encoding='utf8'))
colors={tuple(int(c[2][i:i+2],16) for i in (1,3,5)) for g in pal['groups'] for c in g['colors']}
checks=[]
for f in sorted(out.glob('textures/*.png')):
    a=np.asarray(Image.open(f).convert('RGB'));unique={tuple(v) for v in np.unique(a.reshape(-1,3),axis=0)}
    checks.append({'id':str(f.relative_to(out)),'check':'all texture texels are source palette swatches','passed':unique<=colors,'unique_rgb':[[int(v) for v in x] for x in unique],'size':list(a.shape[:2])})
for f in sorted(out.glob('*/*.glb')):
    raw,chunks=V._chunks(f);j=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
    bad=0;tris=0;finite=True;uv=True
    for mesh in j.get('meshes',[]):
        for p in mesh['primitives']:
            pos=V._accessor(j,binary,p['attributes']['POSITION']);idx=V._accessor(j,binary,p['indices']).reshape(-1,3)
            tri=pos[idx];cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);bad+=int(np.sum(np.linalg.norm(cross,axis=1)<1e-9));tris+=len(idx);finite &= bool(np.isfinite(pos).all());uv &= 'TEXCOORD_0' in p['attributes']
    glass=[m for m in j.get('materials',[]) if m.get('name','')=='GS_glass']
    lit=all('KHR_materials_unlit' not in m.get('extensions',{}) for m in j.get('materials',[]))
    glassok=all(m.get('alphaMode')=='BLEND' and m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1])[3]<1 for m in glass)
    checks.append({'id':str(f.relative_to(out)),'check':'GLB actual geometry and lit PBR','passed':finite and bad==0 and uv and lit and glassok,'triangles':tris,'degenerate':bad,'uv':uv,'lit':lit,'glass_transparent':glassok,'sha256':hashlib.sha256(raw).hexdigest()})
r={'passed':all(c['passed'] for c in checks),'checks':checks,'scope':'Actual texels and binary GLB primitives. Performance and traversal are separate runtime observations.'}
(out/'validation.json').write_text(json.dumps(r,indent=2),encoding='utf8');print(json.dumps({'passed':r['passed'],'checks':len(checks),'failures':[c for c in checks if not c['passed']]}))
