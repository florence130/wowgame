"""Read GLB JSON chunks to confirm usable door pivots and lamp sockets survived."""
import json,struct,sys
from pathlib import Path
out=Path(sys.argv[1]);checks=[]
def read(path):
    blob=path.read_bytes();length,kind=struct.unpack_from('<II',blob,12)
    assert kind==0x4E4F534A
    return json.loads(blob[20:20+length])
def record(name,ok,**kw):checks.append(dict(check=name,passed=bool(ok),**kw))
for name,expected in [('chandelier',6),('floor_lamp',1)]:
    data=read(out/'glb'/f'{name}.glb')
    sockets=[n for n in data['nodes'] if n.get('extras',{}).get('socket_kind')=='light_point']
    record(name+'_exported_light_sockets',len(sockets)==expected,sockets=sockets)
for filename in ['glb/door_hinged.glb','assemblies/Door_Open_105deg.glb']:
    data=read(out/filename);pivots=[n for n in data['nodes'] if 'open_sign' in n.get('extras',{})]
    record(filename+'_hinge_hierarchy',len(pivots)==2 and all(n.get('children') for n in pivots) and sorted(n['extras']['open_sign'] for n in pivots)==[-1,1],hinges=pivots)
report=dict(passed=all(r['passed'] for r in checks),checks=checks)
(out/'hierarchy_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'passed':report['passed'],'checks':len(checks)}))
sys.exit(0 if report['passed'] else 1)
