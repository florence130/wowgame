"""Build a self-contained, editable ground planning map from the city source."""
import json, hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
ground = ROOT / 'docs/city_v5/ground_plan.json'
plan = json.loads(ground.read_text(encoding='utf8'))
layout = json.loads((ROOT / 'docs/city_v5/layout.json').read_text(encoding='utf8'))
for face in plan['faces']:
    if 'level' not in face:
        ys = [v[1] for v in face.get('vertices', [])]
        face['level'] = sum(ys)/len(ys) if ys else 0
data = dict(plan=plan, buildings=layout['buildings'], roads=layout['roads'], hash=hashlib.sha256(ground.read_bytes()).hexdigest())
template = (Path(__file__).parent/'index.html').read_text(encoding='utf8')
payload = json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
output = ROOT/'docs/city_v5/晴岚港-地面规划.html'
output.write_text(template.replace('/* PLAN_DATA */',payload),encoding='utf8')
print(output)
