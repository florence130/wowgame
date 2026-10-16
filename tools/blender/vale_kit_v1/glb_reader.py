"""Independently measure actual GLB payloads, not recipe constants. Plain Python + NumPy."""
import json,struct,sys,math
from pathlib import Path
import numpy as np

def load_glb(path):
    raw=Path(path).read_bytes();magic,version,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and length==len(raw)
    n,t=struct.unpack_from('<II',raw,12);j=json.loads(raw[20:20+n]);start=20+n
    bn,bt=struct.unpack_from('<II',raw,start);binary=raw[start+8:start+8+bn]
    def accessor(idx):
        a=j['accessors'][idx];bv=j['bufferViews'][a['bufferView']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];cols={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        size=np.dtype(dtype).itemsize;offset=bv.get('byteOffset',0)+a.get('byteOffset',0)
        return np.ndarray((a['count'],cols),dtype=dtype,buffer=binary,offset=offset,strides=(bv.get('byteStride',size*cols),size)).copy()
    def matrix(n):
        if 'matrix' in n:return np.array(n['matrix']).reshape(4,4).T
        x,y,z,w=n.get('rotation',[0,0,0,1]);r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
        m=np.eye(4);m[:3,:3]=r@np.diag(n.get('scale',[1,1,1]));m[:3,3]=n.get('translation',[0,0,0]);return m
    vertices=[];parts=[];primitive_count=0;uv=True;triangles=0;degen=0
    def visit(idx,parent):
        nonlocal uv,primitive_count,triangles,degen
        n=j['nodes'][idx];m=parent@matrix(n)
        if 'mesh' in n:
            for pr in j['meshes'][n['mesh']]['primitives']:
                pos=accessor(pr['attributes']['POSITION']);v=(m@np.c_[pos,np.ones(len(pos))].T).T[:,:3]
                vertices.append(v);parts.append((n.get('name',''),v))
                uv &= 'TEXCOORD_0' in pr['attributes'];primitive_count+=1
                inds=accessor(pr['indices']).reshape(-1,3);triangles+=len(inds)
                area=np.linalg.norm(np.cross(v[inds[:,1]]-v[inds[:,0]],v[inds[:,2]]-v[inds[:,0]]),axis=1);degen+=int(np.sum(area<1e-10))
        for k in n.get('children',[]):visit(k,m)
    for i in j['scenes'][j.get('scene',0)]['nodes']:visit(i,np.eye(4))
    return {'json':j,'vertices':np.concatenate(vertices),'parts':parts,'uv':uv,'triangles':triangles,'degenerates':degen,'primitives':primitive_count}

