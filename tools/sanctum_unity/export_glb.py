"""Export the actual Unity scene meshes to glTF 2.0, with source hashes."""
import hashlib
import json
import struct
import io
import random
import argparse
from pathlib import Path
from collections import defaultdict
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.local/sanctum_unity_workshop'
parser=argparse.ArgumentParser()
parser.add_argument('--spatial',action='store_true')
args=parser.parse_args()
OUT=ROOT/('assets/models/sanctum_unity_v2' if args.spatial else 'assets/models/sanctum_unity_v1')
source=WORK/'export'/('unity_spatial_geometry.json' if args.spatial else 'unity_geometry.json')
scene=json.loads(source.read_text(encoding='utf-8'))
bins=bytearray()
doc={'asset':{'version':'2.0','generator':'Unity scene export / Dungeon Architect 1.22.0'},
     'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[],
     'accessors':[],'bufferViews':[],'buffers':[], 'images':[], 'textures':[],
     'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]}
groups=defaultdict(list)
for m in scene['meshes']:
    groups[(m['group'],tuple(round(c,4) for c in m['color']))].append(m)

def stone_texture(floor=False):
    # Authored, repeating masonry: restrained seams and broad colour variation
    # fit the existing storybook materials without photographic surface noise.
    rng=random.Random(211 if floor else 137)
    im=Image.new('RGB',(512,512),(167,167,159));draw=ImageDraw.Draw(im)
    rows,cols=(4,4) if floor else (8,4)
    cw,ch=512//cols,512//rows
    for row in range(rows):
        shift=0 if floor or row%2==0 else cw//2
        for col in range(-1,cols+1):
            x=col*cw+shift;y=row*ch;shade=rng.randrange(219,237)
            draw.rectangle((x+2,y+2,x+cw-2,y+ch-2),fill=(shade,shade,shade-4))
            draw.line((x+3,y+3,x+cw-3,y+3),fill=(min(250,shade+9),)*3,width=2)
            draw.line((x+cw-3,y+4,x+cw-3,y+ch-3),fill=(shade-12,)*3,width=1)
            if rng.random()<.35:
                k=rng.randrange(16,cw-16)
                draw.line((x+k,y+3,x+k-7,y+17,x+k+2,y+28),fill=(shade-18,)*3,width=1)
    data=io.BytesIO();im.save(data,format='PNG');return data.getvalue()

def texture(data,name):
    while len(bins)%4: bins.append(0)
    offset=len(bins);bins.extend(data)
    bv=len(doc['bufferViews']);doc['bufferViews'].append(dict(buffer=0,byteOffset=offset,byteLength=len(data)))
    ii=len(doc['images']);doc['images'].append(dict(name=name,bufferView=bv,mimeType='image/png'))
    ti=len(doc['textures']);doc['textures'].append(dict(source=ii,sampler=0))
    return ti

stone_wall=texture(stone_texture(),'sanctum_cut_stone')
stone_floor=texture(stone_texture(True),'sanctum_worn_paving')

def accessor(data,fmt,component,atype,count,limits=None,target=34962):
    while len(bins)%4: bins.append(0)
    offset=len(bins)
    bins.extend(struct.pack('<'+str(len(data))+fmt,*data))
    bv=len(doc['bufferViews']);doc['bufferViews'].append(dict(buffer=0,byteOffset=offset,byteLength=len(bins)-offset,target=target))
    a=dict(bufferView=bv,componentType=component,count=count,type=atype)
    if limits: a.update(min=limits[0],max=limits[1])
    doc['accessors'].append(a)
    return len(doc['accessors'])-1

for group in sorted({k[0] for k in groups}):
    primitives=[]
    for (g,color),parts in groups.items():
        if g!=group: continue
        p=[];n=[];indices=[];uv=[]
        for part in parts:
            offset=len(p)//3
            ps=part['positions'];ns=part['normals'];ts=part['triangles']
            for i in range(0,len(ps),3):
                x,y,z=ps[i:i+3];nx,ny,nz=ns[i:i+3]
                # Keep the authored world coordinates. Floor and vertical faces get
                # metre-based UVs for future material updates without geometry work.
                uv.extend((x/4,z/4) if abs(ny)>.5 else ((z if abs(nx)>.5 else x)/4,y/4))
            for i in range(0,len(ts),3):
                a,b,c=ts[i:i+3]
                va=ps[a*3:a*3+3];vb=ps[b*3:b*3+3];vc=ps[c*3:c*3+3]
                ab=[vb[j]-va[j] for j in range(3)];ac=[vc[j]-va[j] for j in range(3)]
                cross=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
                if sum(cross[j]*ns[a*3+j] for j in range(3))<0: b,c=c,b
                indices.extend([a+offset,b+offset,c+offset])
            p.extend(ps);n.extend(ns)
        minima=[min(p[i::3]) for i in range(3)];maxima=[max(p[i::3]) for i in range(3)]
        pos=accessor(p,'f',5126,'VEC3',len(p)//3,(minima,maxima))
        nor=accessor(n,'f',5126,'VEC3',len(n)//3)
        tex=accessor(uv,'f',5126,'VEC2',len(uv)//2)
        ind=accessor(indices,'I',5125,'SCALAR',len(indices),target=34963)
        mat=len(doc['materials'])
        pbr={'baseColorFactor':color,'metallicFactor':0,'roughnessFactor':.93}
        if group in ('floor','walls'):
            pbr['baseColorTexture']={'index':stone_floor if group=='floor' else stone_wall}
        doc['materials'].append({'name':group+'_'+str(mat),'pbrMetallicRoughness':pbr})
        primitives.append(dict(attributes={'POSITION':pos,'NORMAL':nor,'TEXCOORD_0':tex},indices=ind,material=mat))
    mi=len(doc['meshes']);doc['meshes'].append(dict(name=group,primitives=primitives))
    ni=len(doc['nodes']);doc['nodes'].append(dict(name=group,mesh=mi));doc['scenes'][0]['nodes'].append(ni)

while len(bins)%4: bins.append(0)
doc['buffers']=[dict(byteLength=len(bins))]
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
body=struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(bins),0x004E4942)+bins
dest=OUT/'sanctum_architecture.glb';dest.write_bytes(struct.pack('<III',0x46546C67,2,len(body)+12)+body)
report=dict(version=scene['version'],source=scene['source'],cells=scene['cells'],markers=scene['markers'],
            source_meshes=len(scene['meshes']),groups=len(doc['meshes']),materials=len(doc['materials']),
            source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),glb_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),
            bytes=dest.stat().st_size,unity_scene='.local/sanctum_unity_workshop/UnityProject/Assets/SanctumWorkshop/Scenes/'+('WindwhisperSanctumSpatial.unity' if args.spatial else 'WindwhisperSanctum.unity'))
(OUT/'provenance.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
