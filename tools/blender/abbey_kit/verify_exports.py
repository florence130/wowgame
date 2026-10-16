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

def main():
    folder=Path(sys.argv[1]).resolve();manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'));checks=[];cache={};skipped=[]
    def ck(name,ok,**d):checks.append({'check':name,'passed':bool(ok),**d})
    for p in sorted(list((folder/'glb').glob('*.glb'))+list((folder/'assemblies').glob('*.glb'))):
        a=load_glb(p);cache[p.stem]=a;j=a['json'];v=a['vertices']
        ck(p.stem+'_single_scene',len(j['scenes'])==1)
        ck(p.stem+'_finite_uv_mesh',np.isfinite(v).all() and a['uv'] and a['triangles']>0,triangles=a['triangles'],primitives=a['primitives'])
        ck(p.stem+'_no_degenerates',a['degenerates']==0,count=a['degenerates'])
        ck(p.stem+'_unlit',all('KHR_materials_unlit' in m.get('extensions',{}) and max(m.get('emissiveFactor',[0]))==0 for m in j.get('materials',[])))
    for asset in manifest['assets']:
        a=cache[asset['id']];lo=np.min(a['vertices'],axis=0);hi=np.max(a['vertices'],axis=0);bl=asset['bounds_min'];bh=asset['bounds_max']
        err=float(max(np.abs(lo-[bl[0],bl[2],-bh[1]]).max(),np.abs(hi-[bh[0],bh[2],-bl[1]]).max()))
        ck(asset['id']+'_basis_bounds',err<2e-5,max_error_m=err)
    # Real boundary points translated using the declared socket pitch.
    for key,axis,pitch in [('wall_plain_4',0,4),('roof_gable_8x4',2,4),('bridge_segment_4',0,4)]:
        if key not in cache:continue
        v=cache[key]['vertices'];lo=float(v[:,axis].min());hi=float(v[:,axis].max())
        lower=v[np.abs(v[:,axis]-lo)<1e-5].copy();upper=v[np.abs(v[:,axis]-hi)<1e-5].copy();lower[:,axis]+=pitch
        dist=np.linalg.norm(lower[:,None,:]-upper[None,:,:],axis=2);err=float(max(dist.min(axis=0).max(),dist.min(axis=1).max()))
        ck(key+'_actual_interface_match',err<2e-5,max_gap_m=err,measured_pitch=hi-lo)
    if 'railing_wood_4' in cache and 'fence_post' in cache:
        v=cache['railing_wood_4']['vertices'];post=cache['fence_post']['vertices']
        shaft=post[(post[:,1]>.25)&(post[:,1]<1.1)]
        # Box vertices are only at extrema; take named post body instead.
        shaft=np.concatenate([v for n,v in cache['fence_post']['parts'] if 'post_cap' not in n])
        gap=float((2+shaft[:,0].min())-v[:,0].max())
        ck('actual_post_to_wood_rail',abs(gap)<2e-5,gap_m=gap)
    if 'stairs_4' in cache:
        a=cache['stairs_4'];v=a['vertices'];tread_parts=[v for n,v in a['parts'] if 'tread_nose' in n];t=np.concatenate(tread_parts)
        tops=sorted(set(np.round(t[:,1],4)));leveltops=[z for z in tops if abs((z-.025)/.2-round((z-.025)/.2))<.01]
        # Godot +Z is Blender -Y, towards the door in this stair local frame.
        values=[]
        for z in leveltops:
            level=t[np.abs(t[:,1]-z)<1e-4];values.append([float(z),float(np.mean(level[:,2]))])
        ck('stair_rises_towards_door',len(values)==4 and all(values[i+1][1]>values[i][1] for i in range(3)),tread_top_y_and_mean_z=values)
        if 'floor_stone_4' in cache and 'plinth_4' in cache:
            floor=cache['floor_stone_4']['vertices'];plinth=cache['plinth_4']['vertices']
            floor_top=float(floor[:,1].max()+plinth[:,1].max());stair_top=float(v[:,1].max())
            ck('stairs_meet_plinth_plus_floor',abs(floor_top-stair_top)<2e-5,floor_top_m=floor_top,stair_top_m=stair_top)
        else:
            skipped.append({'check':'stairs_meet_plinth_plus_floor','status':'not-applicable-to-selected-subset','reason':'Companion components were not selected for this build. Single stair direction is still measured.','requires':['floor_stone_4','plinth_4']})
    passed=all(c['passed'] for c in checks)
    (folder/'export_validation.json').write_text(json.dumps({'passed':passed,'checks':checks,'skipped_checks':skipped,'basis':'parsed actual GLB mesh positions, node matrices, UV attributes and materials'},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'passed':passed,'checks':len(checks),'skipped_checks':skipped,'failed':[c for c in checks if not c['passed']]},ensure_ascii=False))
    return 0 if passed else 1

if __name__=='__main__':sys.exit(main())
