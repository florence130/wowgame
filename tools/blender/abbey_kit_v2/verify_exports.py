"""Validate actual v2 GLB payloads with per-node/primitive failure attribution.

Usage: python verify_exports.py BUILD_FOLDER --out REPORT.json

Requires NumPy; Blender's bundled Python is sufficient. Reuses the v1 load_glb
reader for independently measured aggregate geometry, then examines every actual
primitive and image payload. No recipe/manifests are used as pass evidence.

GLB records glTF metallic/roughness PBR, not the source Blender node class. This
validator therefore verifies exported PBR semantics and never claims to prove
that a particular source node was used. Color-only glass/iron are listed, while
at least one real base-color image is required in every exported asset.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import urllib.parse
import zlib

import numpy as np


V1_READER = Path(__file__).resolve().parent.parent / 'abbey_kit' / 'verify_exports.py'
_spec = importlib.util.spec_from_file_location('abbey_v1_export_reader', V1_READER)
_legacy = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_legacy)
load_glb = _legacy.load_glb


def _chunks(path):
    raw=Path(path).read_bytes()
    magic,version,length=struct.unpack_from('<4sII',raw)
    if magic!=b'glTF' or version!=2 or length!=len(raw):
        raise ValueError('Invalid GLB header or declared length')
    chunks={}
    offset=12
    while offset<len(raw):
        size,kind=struct.unpack_from('<II',raw,offset)
        offset+=8
        if offset+size>len(raw): raise ValueError('GLB chunk exceeds file')
        chunks[kind]=raw[offset:offset+size]
        offset+=size
    return raw,chunks


def _accessor(j,binary,index):
    a=j['accessors'][index]
    if 'sparse' in a: raise ValueError('Sparse accessor unsupported by this export pipeline')
    view=j['bufferViews'][a['bufferView']]
    if view.get('buffer',0)!=0:raise ValueError('External position buffer unsupported')
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    size=np.dtype(dtype).itemsize
    offset=view.get('byteOffset',0)+a.get('byteOffset',0)
    stride=view.get('byteStride',size*width)
    data=np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=offset,strides=(stride,size)).copy()
    if a.get('normalized') and a['componentType']!=5126:
        info=np.iinfo(np.dtype(dtype))
        data=np.maximum(data.astype(np.float64)/info.max,-1)
    return data


def _node_matrix(node):
    if 'matrix' in node:return np.array(node['matrix'],dtype=float).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1])
    r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    m=np.eye(4)
    m[:3,:3]=r@np.diag(node.get('scale',[1,1,1]))
    m[:3,3]=node.get('translation',[0,0,0])
    return m


def _png_info(data):
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):raise ValueError('Image is not valid PNG')
    offset=8
    idat=[]
    dims=None
    ended=False
    while offset<len(data):
        size=struct.unpack_from('>I',data,offset)[0]
        kind=data[offset+4:offset+8]
        content=data[offset+8:offset+8+size]
        if len(content)!=size or offset+12+size>len(data):raise ValueError('Truncated PNG chunk')
        expected=struct.unpack_from('>I',data,offset+8+size)[0]
        if zlib.crc32(kind+content)&0xffffffff!=expected:raise ValueError('PNG CRC mismatch')
        if kind==b'IHDR':
            width,height,depth,color,comp,filtering,interlace=struct.unpack('>IIBBBBB',content)
            if width<1 or height<1:raise ValueError('PNG has empty dimensions')
            dims={'width':width,'height':height,'bit_depth':depth,'color_type':color}
        if kind==b'IDAT':idat.append(content)
        if kind==b'IEND':ended=True;break
        offset+=12+size
    if not dims or not idat or not ended:raise ValueError('Incomplete PNG image')
    decoded=zlib.decompress(b''.join(idat))
    if not decoded:raise ValueError('PNG has empty decoded pixels')
    dims['decoded_bytes']=len(decoded)
    return dims


def _image_payload(j,binary,image,path):
    if 'bufferView' in image:
        view=j['bufferViews'][image['bufferView']]
        start=view.get('byteOffset',0)
        data=binary[start:start+view['byteLength']]
        if len(data)!=view['byteLength']:raise ValueError('Image buffer view exceeds BIN chunk')
        source='embedded bufferView '+str(image['bufferView'])
    elif 'uri' in image:
        uri=image['uri']
        if uri.startswith('data:'):
            head,body=uri.split(',',1)
            data=base64.b64decode(body,validate=True) if ';base64' in head else urllib.parse.unquote_to_bytes(body)
            source='embedded data URI'
        else:
            if urllib.parse.urlparse(uri).scheme:raise ValueError('Remote image URI is not a self-contained export')
            source_path=(path.parent/urllib.parse.unquote(uri)).resolve()
            data=source_path.read_bytes()
            source=str(source_path)
    else:raise ValueError('Image has neither bufferView nor URI')
    if not data:raise ValueError('Referenced image is empty')
    mime=image.get('mimeType','')
    if data.startswith(b'\x89PNG'):
        dims=_png_info(data)
        mime='image/png'
    elif data.startswith(b'\xff\xd8'):
        # Blender's v2 exports are PNG; support JPEG if Pillow is available.
        import io
        from PIL import Image
        with Image.open(io.BytesIO(data)) as im:
            im.load()
            dims={'width':im.width,'height':im.height}
        mime='image/jpeg'
    else:raise ValueError('Unsupported or malformed actual image payload')
    return {'source':source,'mime_type':mime,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),**dims}


def validate_file(path,area_epsilon=1e-10):
    path=Path(path)
    result={'file':str(path),'checks':[],'materials':[],'images':[],
            'primitives':[],'degenerate_diagnostics':[]}
    def check(name,passed,**details):
        result['checks'].append({'check':name,'passed':bool(passed),**details})
    raw,chunks=_chunks(path)
    actual=load_glb(path)  # Shared proven reader; inspect real matrices and bytes.
    j=actual['json']
    binary=chunks.get(0x004E4942,b'')
    result['sha256']=hashlib.sha256(raw).hexdigest()
    result['bytes']=len(raw)
    result['triangles']=actual['triangles']
    result['degenerate_triangles']=actual['degenerates']
    check('single_scene',len(j.get('scenes',[]))==1)
    check('finite_transformed_vertices',np.isfinite(actual['vertices']).all())
    check('has_triangles',actual['triangles']>0)
    check('no_unlit_extension','KHR_materials_unlit' not in j.get('extensionsUsed',[])
          and 'KHR_materials_unlit' not in j.get('extensionsRequired',[])
          and all('KHR_materials_unlit' not in m.get('extensions',{}) for m in j.get('materials',[])))
    image_status={}
    for idx,img in enumerate(j.get('images',[])):
        entry={'index':idx,'name':img.get('name','')}
        try:
            entry.update(_image_payload(j,binary,img,path))
            entry['passed']=True
        except Exception as ex:
            entry.update(passed=False,error=str(ex))
        image_status[idx]=entry['passed']
        result['images'].append(entry)
    check('image_payloads_available_and_decodable',bool(image_status) and all(image_status.values()),image_count=len(image_status))
    texture_status={}
    for idx,texture in enumerate(j.get('textures',[])):
        source=texture.get('source')
        texture_status[idx]=source in image_status and image_status[source]
    check('all_texture_image_references_resolve',bool(texture_status) and all(texture_status.values()),texture_count=len(texture_status))
    for idx,m in enumerate(j.get('materials',[])):
        pbr=m.get('pbrMetallicRoughness')
        pbr_ok=isinstance(pbr,dict)
        params=pbr or {}
        factor=params.get('baseColorFactor',[1,1,1,1])
        rough=params.get('roughnessFactor',1)
        metal=params.get('metallicFactor',1)
        numeric_ok=len(factor)==4 and np.isfinite(factor).all() and all(0<=v<=1 for v in factor)
        numeric_ok=numeric_ok and np.isfinite([rough,metal]).all() and 0<=rough<=1 and 0<=metal<=1
        texture=params.get('baseColorTexture')
        entry={'index':idx,'name':m.get('name',''),'pbr_metallic_roughness':pbr_ok,
               'pbr_numeric_values_valid':bool(numeric_ok),'has_base_color_texture':texture is not None,
               'unlit':'KHR_materials_unlit' in m.get('extensions',{}),
               'roughness':rough,'metallic':metal}
        if texture:
            entry['base_color_texture']=texture['index']
            entry['base_color_texture_resolves']=bool(texture_status.get(texture['index'],False))
        result['materials'].append(entry)
    check('materials_export_as_valid_gltf_pbr',bool(result['materials']) and all(
        m['pbr_metallic_roughness'] and m['pbr_numeric_values_valid'] and not m['unlit'] for m in result['materials']))
    used_materials=set()
    def visit(idx,parent,pathnames):
        node=j['nodes'][idx]
        matrix=parent@_node_matrix(node)
        name=node.get('name',f'node_{idx}')
        names=pathnames+[name]
        if 'mesh' in node:
            mesh_idx=node['mesh']
            mesh=j['meshes'][mesh_idx]
            for primitive_idx,pr in enumerate(mesh['primitives']):
                att=pr['attributes']
                pos=_accessor(j,binary,att['POSITION'])
                world=(matrix@np.c_[pos,np.ones(len(pos))].T).T[:,:3]
                mode=pr.get('mode',4)
                material_idx=pr.get('material')
                if material_idx is not None:used_materials.add(material_idx)
                indices=_accessor(j,binary,pr['indices']).ravel() if 'indices' in pr else np.arange(len(pos))
                index_ok=bool(len(indices)%3==0 and np.all(indices<len(pos)) and np.all(indices>=0))
                uv=_accessor(j,binary,att['TEXCOORD_0']) if 'TEXCOORD_0' in att else None
                uv_ok=uv is not None and len(uv)==len(pos) and np.isfinite(uv).all()
                record={'node':name,'node_index':idx,'node_path':'/'.join(names),
                        'mesh':mesh.get('name',''),'mesh_index':mesh_idx,'primitive_index':primitive_idx,
                        'material_index':material_idx,'material_name':j['materials'][material_idx].get('name','') if material_idx is not None else None,
                        'vertices':len(pos),'triangles':int(len(indices)//3),
                        'finite_vertices':bool(np.isfinite(pos).all() and np.isfinite(world).all()),
                        'mode_triangles':mode==4,'indices_valid':index_ok,'finite_uv0':bool(uv_ok)}
                if mode==4 and index_ok:
                    tri=indices.reshape(-1,3)
                    area=np.linalg.norm(np.cross(world[tri[:,1]]-world[tri[:,0]],world[tri[:,2]]-world[tri[:,0]]),axis=1)
                    bad=np.flatnonzero(area<area_epsilon)
                    record['degenerate_triangles']=int(len(bad))
                    if len(bad):
                        # Keep all offending face IDs, and a bounded coordinate sample.
                        diag={k:record[k] for k in ('node','node_index','node_path','mesh','mesh_index','primitive_index','material_index','material_name')}
                        diag.update(count=len(bad),triangle_indices=bad.tolist(),samples=[])
                        for face_idx in bad[:32]:
                            vertex_ids=tri[face_idx]
                            diag['samples'].append({'triangle_index':int(face_idx),'vertex_indices':vertex_ids.tolist(),
                                                    'local_vertices_gltf':pos[vertex_ids].tolist(),
                                                    'world_vertices_gltf':world[vertex_ids].tolist(),
                                                    'twice_area':float(area[face_idx])})
                        result['degenerate_diagnostics'].append(diag)
                if material_idx is not None:
                    tex=j['materials'][material_idx].get('pbrMetallicRoughness',{}).get('baseColorTexture')
                    if tex:
                        channel=tex.get('extensions',{}).get('KHR_texture_transform',{}).get('texCoord',tex.get('texCoord',0))
                        key=f'TEXCOORD_{channel}'
                        useduv=_accessor(j,binary,att[key]) if key in att else None
                        record['basecolor_uv_available']=bool(useduv is not None and len(useduv)==len(pos) and np.isfinite(useduv).all())
                result['primitives'].append(record)
        for child in node.get('children',[]):visit(child,matrix,names)
    for root in j['scenes'][j.get('scene',0)].get('nodes',[]):visit(root,np.eye(4),[])
    result['degenerate_triangles']=sum(p.get('degenerate_triangles',0) for p in result['primitives'])
    check('no_degenerate_triangles',result['degenerate_triangles']==0,
          count=result['degenerate_triangles'],twice_area_epsilon=area_epsilon)
    check('every_primitive_has_finite_positions_uv_and_triangle_indices',bool(result['primitives']) and all(
        p['finite_vertices'] and p['finite_uv0'] and p['indices_valid'] and p['mode_triangles'] for p in result['primitives']))
    check('basecolor_texture_uv_sets_available',all(p.get('basecolor_uv_available',True) for p in result['primitives']))
    used=[result['materials'][idx] for idx in used_materials]
    textured=[m for m in used if m['has_base_color_texture']]
    check('actual_basecolor_texture_used_by_geometry',bool(textured) and all(m.get('base_color_texture_resolves',False) for m in textured),
          textured_material_count=len(textured),used_material_count=len(used),
          color_only_materials=[m['name'] for m in used if not m['has_base_color_texture']])
    result['passed']=all(c['passed'] for c in result['checks'])
    return result


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--area-epsilon',type=float,default=1e-10,help='Degenerate threshold for twice triangle area in world metres squared')
    args=parser.parse_args(argv)
    folder=args.folder.resolve()
    paths=sorted([*(folder/'glb').glob('*.glb'),*(folder/'assemblies').glob('*.glb')])
    files=[]
    for path in paths:
        try:
            files.append(validate_file(path,args.area_epsilon))
        except Exception as ex:
            files.append({'file':str(path),'passed':False,'error':f'{type(ex).__name__}: {ex}','checks':[]})
    checks=[c for f in files for c in f['checks']]
    report={'passed':bool(files) and all(f['passed'] for f in files),
            'created_utc':datetime.now(timezone.utc).isoformat(),'build_folder':str(folder),
            'basis':'Actual GLB bytes, scene/node matrices, accessors, UVs, material PBR properties, texture references and decoded image payloads',
            'source_node_limitation':'glTF does not encode Blender node classes; PBR export semantics are verified, not source Principled BSDF node identity',
            'legacy_reader':str(V1_READER),'legacy_unlit_expectations_used':False,
            'file_count':len(files),'check_count':len(checks),
            'passed_checks':sum(c['passed'] for c in checks),'failed_checks':sum(not c['passed'] for c in checks),
            'files':files}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'passed':report['passed'],'files':len(files),'checks':len(checks),
                      'failed':[{'file':Path(f['file']).name,'error':f.get('error'),
                                 'checks':[c for c in f['checks'] if not c['passed']],
                                 'degenerates':[{'node':d['node'],'primitive':d['primitive_index'],'material':d['material_name'],'count':d['count']} for d in f.get('degenerate_diagnostics',[])]}
                                for f in files if not f['passed']],
                      'report':str(args.out.resolve())},ensure_ascii=False))
    return 0 if report['passed'] else 1


if __name__=='__main__':sys.exit(main())
