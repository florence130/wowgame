"""Extend the established editable SVG icon system to advancement skills."""
from pathlib import Path
import importlib.util,json,sys
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('icon_builder',root/'tools/build_ui_icons.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
current=json.loads((root/'data/combat_expansion.json').read_text(encoding='utf-8'))
# Existing mechanical export contains stable IDs and artwork roles, no copied UI.
base=json.loads((root/'data/advancement_icon_roles.json').read_text(encoding='utf-8'))
catalog={**base,**current['skills']}
out=root/'assets/ui/icons/skills';out.mkdir(parents=True,exist_ok=True)
created=[]
for sid,skill in catalog.items():
    path=out/(sid+'.svg')
    if path.exists() and '--refresh' not in sys.argv:continue
    school=skill.get('school','physical');job=skill['requires_spec']
    palette={'fire':'fire','frost':'ice','water':'ice','lightning':'holy','light':'holy','holy':'holy','shadow':'shadow','wind':'nature','arcane':'arcane','neutral':'arcane'}.get(school,{'paladin':'holy','berserker':'rage','assassin':'nature','duelist':'arcane','shadow_priest':'holy'}.get(job,'steel'))
    effects=skill.get('effects',[]);types={e['type'] for e in effects}
    motif={'fire':'flame','frost':'crystal','water':'drop','lightning':'burst','light':'star','shadow':'orb','wind':'horn','arcane':'orb','neutral':'orb'}.get(school,'blade')
    comp=''
    if 'aoe' in types or 'chain' in types:comp='triple'
    if 'interrupt' in types:motif='boot';comp='star'
    elif types.intersection({'heal','heal_pct','heal_self_pct'}):motif='heart';comp='star'
    elif any(e.get('aura',{}).get('absorb_pct') or e.get('aura',{}).get('mods',{}).get('dmg_taken',0)<0 for e in effects):motif='shield';comp='star' if 'party_aura' in types else ''
    elif 'riposte' in types:motif='blade' if job=='duelist' else 'shield';comp='burst'
    elif job in ['marksman','gadgeteer'] and types.intersection({'ranged','ranged_multi','aoe','weapon'}):motif='gun';comp='triple' if 'aoe' in types or 'ranged_multi' in types else 'star'
    elif 'reload' in sid or 'load' in sid or 'vent' in sid:motif='gun';comp='crystal'
    elif 'charge' in types or 'leap_back' in types or 'teleport_behind' in types:motif='boot';comp='star'
    elif skill.get('animation')=='shield':motif='shield';comp='burst'
    elif school=='physical' and 'aoe' in types:motif='blade';comp='triple'
    path.write_text(builder.skill_svg(sid,motif,palette,comp),encoding='utf-8')
    created.append(sid)
print('Rendered',len(created),'advancement SVG icons; other icons preserved')
