"""Bind actual combat reports, final gate frames and current sources to hashes."""
from pathlib import Path
import hashlib, json
from datetime import datetime, timezone
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.local/sanctum_unity_workshop'
shots = ROOT / '.shots'
headless = json.loads((shots/'sanctum_combat_headless_final/combat_report.json').read_text('utf-8'))
visual = json.loads((shots/'sanctum_combat_delivery/combat_report.json').read_text('utf-8'))
route = json.loads((WORK/'spatial_route_report.json').read_text('utf-8'))
assert route['checks']==278 and not route['failures']
layout = json.loads((ROOT/'assets/models/sanctum_unity_v2/layout.json').read_text('utf-8'))
def brief(report):
    assert report['failed']==0 and report['arrived']==report['waypoints']==37
    assert report['teleport_samples']==0
    assert sum(k['boss'] for k in report['kills'])==4
    for pull in layout['pulls']:
        assert sum(k['room']==pull['id'] for k in report['kills'])==len(pull['mobs'])
    assert all(e['evades']==0 for e in report['encounters'].values())
    return {k:report[k] for k in ['conditions','elapsed_sim_seconds','walked_m','ally_deaths','teleport_samples','gate_flags','cast_outcomes']}

frames = [
 ('sanctum_combat_delivery/0142_boss_rootguard_cast.png','药园实战：正常远镜头，回廊屋顶仍可能遮挡'),
 ('sanctum_combat_delivery/0267_boss_lake_cast.png','装卸院：实际战斗与原生队伍'),
 ('sanctum_combat_delivery/0382_boss_sanctum_lantern_cast.png','圣歌祭坛：第三首领读条'),
 ('sanctum_combat_delivery/0461_boss_victor_cast.png','钟台：丧钟读条，完整伤害机制尚待专测'),
 ('sanctum_gates_delivery_final/final_2_seeds.png','隔离门状态：2/3，门仍关闭'),
 ('sanctum_gates_delivery_final/final_3_seeds.png','隔离门状态：3/3，门开且三槽保留'),
]
board=Image.new('RGB',(1440,1392),'#20252b')
draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
draw.text((24,16),'风语旧圣堂 · 连续实战与火种门反馈',font=font,fill='white')
draw.text((24,50),'上四张为实际战斗；下两张为单独门状态检查。保留屋顶、碰撞与正常相机。',font=small,fill='#bdcbd4')
for i,(name,caption) in enumerate(frames):
    x=16+(i%2)*712;y=92+(i//2)*424
    im=Image.open(shots/name).convert('RGB');im.thumbnail((696,392))
    board.paste(im,(x,y))
    draw.text((x+6,y+395),caption,font=small,fill='white')
board_path=shots/'sanctum_combat_review_board.png';board.save(board_path)

files=[
 'src/actors/mob.gd','src/world/sanctum_gate.gd','tools/gen_sanctum.gd',
 'tools/sanctum_unity/prepare_spatial.py','tools/sanctum_unity/spatial_proposal.json',
 'assets/models/sanctum_unity_v2/layout.json','assets/models/sanctum_unity_v2/sanctum_architecture.glb',
 'scenes/zones/windwhisper_sanctum.tscn','data/terrain/sanctum.res',
 'tests/sanctum_combat.gd','tests/sanctum_combat.tscn','tests/sanctum_route.gd',
 'tests/sanctum_gate_visual.gd','tests/sanctum_gate_visual.tscn',
 'docs/副本_风语旧圣堂_重制方案.md','tools/sanctum_unity/record_combat_delivery.py',
 '.shots/sanctum_combat_delivery/combat_report.json',
 '.shots/sanctum_combat_headless_final/combat_report.json',
 '.shots/sanctum_combat_review_board.png',
]
for folder in ['sanctum_combat_delivery','sanctum_gates_delivery_final']:
    files += [str(p.relative_to(ROOT)).replace('\\','/') for p in (shots/folder).glob('*.png')]
for name in ['combat_delivery','combat_headless_final','combat_gates_delivery_final',
             'combat_scripts_final','combat_delivery_final_gen','combat_route_delivery_final']:
    files += [f'.local/sanctum_unity_workshop/{name}.{ext}.log' for ext in ['out','err']]
files += ['.local/sanctum_unity_workshop/spatial_route_report.json']
manifest={
 'iteration':'sanctum-native-combat-gates-delivery',
 'recorded_utc':datetime.now(timezone.utc).isoformat(),
 'unity_rebuilt_this_round':False,
 'scene_checks':route['checks'],'shared_project_script_loads':215,
 'headless':brief(headless),'forward_plus':brief(visual),
 'final_gate_cosmetic_revision_after_full_combat':True,
 'final_cosmetic_verification':'scene regenerated; 278 checks and 8 real rendered gate states',
 'limits':[
   'Test driver uses native movement and combat APIs; not human/manual input acceptance.',
   'Fixed fps simulation duration is not a controlled performance or human clear-time result.',
   'Headless tank died once after the third boss summon; normal noncombat revive retained.',
   'Final boss bell casts interrupted in both runs; full uninterruptible damage/survival not tested.',
   'telegraph_far has no ground-preview branch; final bell readable mechanic still pending.',
   'Camera target 16m, observed minimum 6.625m; garden corridor roof can obscure some combat views.',
   'Isolated gate frames explicitly set fixture flags; only continuous combat proves natural seeds.',
   'Godot resource release warnings persist on exit.',
 ],
 'sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}
}
(WORK/'combat_delivery_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
print(json.dumps({'files':len(files),'scene_checks':route['checks'],'combat_runs':2,'board':str(board_path)},ensure_ascii=False))
