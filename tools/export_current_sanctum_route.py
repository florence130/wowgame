"""Export fixture waypoints from the authoritative current dungeon layout."""
from pathlib import Path
import importlib.util, json, math
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('current_sanctum_layout',root/'tools/sanctum_v2/layout.py')
layout=importlib.util.module_from_spec(spec);spec.loader.exec_module(layout)
route=[]
for segment in layout.MAIN:
    pts=segment['pts']
    lengths=[math.dist(a,b) for a,b in zip(pts,pts[1:])]
    total=sum(lengths);done=0
    phase=0
    if segment['id'] in ['s4','s5','s6','b2']:phase=2
    if segment['id'] in ['s7','s8','s9','s10','b3']:phase=3
    if segment['id'] in ['s11','s12','b4']:phase=4
    for i,pt in enumerate(pts):
        if i:done+=lengths[i-1]
        height=segment['y0']+(segment['y1']-segment['y0'])*done/max(total,.001)
        p=[pt[0],round(height,3),pt[1]]
        if route and route[-1]['position']==p:continue
        route.append({'position':p,'phase':phase,'segment':segment['id']})
out={'source':'tools/sanctum_v2/layout.py','waypoints':route}
(root/'data/sanctum_route_current.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print('CURRENT ROUTE',len(route))
