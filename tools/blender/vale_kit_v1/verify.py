"""Validate exported GLB bytes (world-space triangles, colour factors, sockets)."""
import pathlib,sys,json,math
import numpy as np
from glb_reader import load_glb
OUT=pathlib.Path(sys.argv[1]);manifest=json.loads((OUT/'manifest.json').read_text());checks=[];files={}
def ck(name,value,**details):checks.append({'name':name,'passed':bool(value),**details})
def linear(h):
    c=np.array([int(h[i:i+2],16)/255 for i in [0,2,4]])
    return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
for path in sorted([*(OUT/'modules').glob('*.glb'),*(OUT/'assemblies').glob('*.glb'),*(OUT/'stages').glob('*.glb')]):
    a=load_glb(path);files[path.stem]=a;j=a['json'];v=a['vertices']
    ck(path.stem+'_mesh',np.isfinite(v).all() and a['triangles']>0,triangles=a['triangles'])
    ck(path.stem+'_nondegenerate',a['degenerates']==0,degenerates=a['degenerates'])
    ck(path.stem+'_scene',len(j['scenes'])==1)
    errors=[]
    for m in j.get('materials',[]):
        key=m['name'].removeprefix('VALE_').split('.')[0]
        if key in ['thatch_fibre','plaster','plaster_patch','sandstone','stone_dark','stone_light','barn','barn_light','barn_dark']:
            pbr=m.get('pbrMetallicRoughness',{})
            if 'baseColorTexture' not in pbr or pbr.get('roughnessFactor',1)<.95:errors.append(m['name'])
            if key!='thatch_fibre' and 'normalTexture' not in m:errors.append(m['name']+'_missing_grain_normal')
            continue
        expected=linear(manifest['palette_srgb'][key]);pbr=m.get('pbrMetallicRoughness',{});actual=np.array(pbr.get('baseColorFactor',[1]*4)[:3])
        if np.max(abs(expected-actual))>1e-6:errors.append(m['name'])
    ck(path.stem+'_authoritative_palette',not errors,bad_materials=errors)
    ck(path.stem+'_lit_materials',all('KHR_materials_unlit' not in m.get('extensions',{}) for m in j.get('materials',[])))
    ck(path.stem+'_matte_no_specular',all(m.get('pbrMetallicRoughness',{}).get('roughnessFactor',1)>=.99 and m.get('extensions',{}).get('KHR_materials_specular',{}).get('specularFactor',1)==0 for m in j.get('materials',[])))
    if j.get('images'):
        ck(path.stem+'_embedded_images',all('bufferView' in im and 'uri' not in im for im in j['images']))
for entry in manifest['modules']+list(manifest['assemblies'].values()):
    name=pathlib.Path(entry['file']).stem;v=files[name]['vertices'];lo,hi=entry['bounds_blender']
    err=max(np.max(abs(v.min(axis=0)-[lo[0],lo[2],-hi[1]])),np.max(abs(v.max(axis=0)-[hi[0],hi[2],-lo[1]])))
    ck(name+'_coordinate_conversion',err<3e-5,error_m=float(err))
for name in ['V_farm_wall_solid','V_barn_wall_solid','V_roof_tile_4m','V_roof_thatch_4m']:
    a=files[name];parts=[v for n,v in a['parts'] if n.startswith(('wall_core','roof_half','thatch_underlayer'))];v=np.concatenate(parts)
    lo=v[np.isclose(v[:,0],v[:,0].min(),atol=1e-5)].copy();hi=v[np.isclose(v[:,0],v[:,0].max(),atol=1e-5)].copy();lo[:,0]+=4
    dist=np.linalg.norm(lo[:,None]-hi[None,:],axis=2);err=max(dist.min(axis=0).max(),dist.min(axis=1).max())
    ck(name+'_actual_4m_interface',err<2e-5,gap_m=float(err))
rotor=files['VALE_windmill'];parts=[v for n,v in rotor['parts'] if 'V_mill_sail__' in n];v=np.concatenate(parts)
# Tube/cap max forward reach 3.3m; rotating an X/Y rotor never changes Z.
nearest=-v[:,2].max();ck('sails_clear_full_tower_rotation',nearest>3.3,minimum_clearance_m=float(nearest-3.3))
rot=files['VALE_rotor']['json'];pivots=[n for n in rot['nodes'] if n.get('name','').startswith('V_mill_sail__V_mill_sail')]
ck('rotor_four_separate_sails',len(pivots)==4,count=len(pivots))
for cx in [-4.8,4.8]:
    blocked=[]
    for name,verts in files['VALE_barn']['parts']:
        if not name.startswith('brick_course'):continue
        lo=verts.min(axis=0);hi=verts.max(axis=0)
        if lo[2]>5.45 and lo[0]<cx+.58 and hi[0]>cx-.58 and lo[1]<2.55 and hi[1]>1.45:blocked.append(name)
    ck('barn_rear_window_clear_'+str(cx),not blocked,blocking_bricks=blocked)
ck('all_ten_methods_recorded',all(any(str(i).zfill(2)+' ' in method for rec in manifest['modules'] for method in rec['methods']) for i in range(1,11)))
ck('SDF_initial_and_refinement_present',all(name in files for name in ['STAGE_02_SDF_initial','STAGE_07_SDF_refined_batch']))
result={'passed':all(c['passed'] for c in checks),'files':len(files),'checks':checks,'mesh_statistics':{k:{x:a[x] for x in ['triangles','primitives','degenerates','uv']} for k,a in files.items()},'boundary':'Palette/geometry/interfaces only; visual quality independently reviewed. Collision/navigation/live-map performance not tested.'}
(OUT/'validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'passed':result['passed'],'files':len(files),'checks':len(checks),'failed':[c for c in checks if not c['passed']],'assemblies':{k:result['mesh_statistics'][k] for k in files if k.startswith('VALE_')}},indent=2))
sys.exit(0 if result['passed'] else 1)
