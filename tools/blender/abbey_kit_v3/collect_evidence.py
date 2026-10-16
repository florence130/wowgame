"""Hash a finished candidate; never interpret hashes as visual acceptance."""
import json,hashlib,sys
from pathlib import Path
out=Path(sys.argv[1]).resolve();project=Path(__file__).resolve().parents[3]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
records=[]
for path in sorted(out.rglob('*')):
    if path.is_file() and path.name not in ('evidence_index.json','abbey_kit.blend1'):
        records.append({'path':str(path.relative_to(out)).replace('\\','/'),'bytes':path.stat().st_size,'sha256':sha(path)})
sources=[]
for folder in ['tools/blender/abbey_kit','tools/blender/abbey_kit_v2','tools/blender/abbey_kit_v3']:
    for path in sorted((project/folder).glob('*.py')):sources.append({'path':str(path.relative_to(project)).replace('\\','/'),'sha256':sha(path)})
checks={}
for name,key in [('export_validation','passed'),('palette_validation','passed'),('support_validation','pass_check'),('tool_validation','passed'),('hierarchy_validation','passed'),('godot_validation','passed')]:
    p=out/f'{name}.json';checks[name]=json.loads(p.read_text(encoding='utf8')).get(key,False) if p.exists() else None
checks['stages']=json.loads((out/'stages/pipeline_routes.json').read_text(encoding='utf8'))['passed']
data={'build_directory':str(out),'file_hashes':records,'source_hashes':sources,'validation':checks,'scope':'File identity and reported checks; independent visual acceptance is recorded separately in REVIEW.md.'}
(out/'evidence_index.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'files':len(records),'source_files':len(sources),'validation':checks},ensure_ascii=False))
