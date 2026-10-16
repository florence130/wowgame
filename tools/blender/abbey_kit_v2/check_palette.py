"""Read the actual saved Blender materials and verify user-palette metadata."""
import bpy,json,sys,struct,zlib
from pathlib import Path
out=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(out/'abbey_kit.blend'))
palette=json.loads((out/'palette_mapping.json').read_text(encoding='utf8'))
checks=[]
def linear(v):
    v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def png_mean(blob):
    p=8;compressed=b'';w=h=0
    while p<len(blob):
        n=struct.unpack_from('>I',blob,p)[0];kind=blob[p+4:p+8];data=blob[p+8:p+8+n];p+=n+12
        if kind==b'IHDR':w,h=struct.unpack_from('>II',data)
        if kind==b'IDAT':compressed+=data
    raw=zlib.decompress(compressed);total=[0,0,0]
    for y in range(h):
        row=raw[y*(w*3+1):(y+1)*(w*3+1)]
        if row[0]!=0:raise ValueError('Expected unfiltered RGB source pigment image')
        for k in range(3):total[k]+=sum(row[1+k::3])
    return [x/(w*h) for x in total]
for m in bpy.data.materials:
    key=m.get('palette_key')
    if not key:continue
    expected=palette['colors'][key]
    principled=[n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED']
    actual=m.get('base_color_srgb')
    rgb=[int(expected[i:i+2],16) for i in (0,2,4)];values=list(principled[0].inputs['Base Color'].default_value[:3]) if principled else []
    socket_ok=bool(principled) and max(abs(a-linear(b)) for a,b in zip(values,rgb))<1e-6
    images=[n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    means=[png_mean(bytes(im.packed_file.data)) for im in images]
    image_ok=all(max(abs(a-b) for a,b in zip(mean,rgb))<2 for mean in means)
    checks.append(dict(material=m.name,palette_key=key,expected_srgb=expected,actual_srgb=actual,principled=bool(principled),actual_socket_linear=values,packed_png_mean_srgb=means,passed=actual==expected and socket_ok and image_ok))
result=dict(passed=all(c['passed'] for c in checks) and bool(checks),checks=checks,scope='Saved material source nodes: actual linear Base Color sockets and packed PNG mean within 2/255 of authoritative swatch. Pigment and shaded pixel variation are not flat-color violations.')
(out/'palette_validation.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result))
