"""Author the first sanctum route; Unity Dungeon Architect consumes this source."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.local/sanctum_unity_workshop'
ASSETS = ROOT / 'assets/models/sanctum_unity_v1'

def room(rid, name, kind, center, size, theme, mobs=(), boss='', flags=(), defeated='', poi=''):
    return dict(id=rid, name=name, kind=kind, center=list(center), size=list(size),
                theme=theme, mobs=list(mobs), boss=boss, required_flags=list(flags),
                defeated_flag=defeated, poi=poi or 'poi_sanctum_' + rid.lower())

rooms = [
    room('R0', '山门前庭', 'start', (200,368), (32,24), 'cloister', poi='poi_sanctum_in'),
    room('R1', '守门回廊', 'trash', (200,320), (32,40), 'cloister', ['d_bandit','d_bandit','d_bandit_gunner'], poi='poi_sanctum_court'),
    room('R2', '残泉庭院', 'trash', (136,320), (40,32), 'cloister', ['d_bandit','d_bandit','d_bandit_mage']),
    room('R3', '荆棘苗圃', 'trash', (80,276), (32,40), 'garden', ['d_vine','d_vine','d_treant']),
    room('R4', '腐根花园', 'boss', (80,216), (48,48), 'garden', boss='boss_rootguard', defeated='sanctum_ember_root', poi='poi_sanctum_garden'),
    room('R5', '修士旧书室', 'rest', (148,216), (32,24), 'cloister', flags=['sanctum_ember_root']),
    room('R6', '转运库房', 'trash', (208,216), (40,32), 'depot', ['d_bandit','d_bandit','d_bandit_gunner'], flags=['sanctum_ember_root']),
    room('R7', '灰巾军械院', 'trash', (272,216), (40,40), 'depot', ['d_bandit','d_bandit_gunner','d_bandit_mage'], flags=['sanctum_ember_root']),
    room('R8', '莱克的补给站', 'boss', (328,152), (48,48), 'depot', boss='boss_lake', flags=['sanctum_ember_root'], defeated='sanctum_ember_lake', poi='poi_sanctum_depot'),
    room('R9', '烛火前厅', 'trash', (256,88), (32,24), 'nave', ['d_bandit','d_bandit_mage','d_gargoyle'], flags=['sanctum_ember_lake']),
    room('R10', '失声唱诗席', 'trash', (196,88), (40,32), 'nave', ['d_gargoyle','d_gargoyle','d_bandit_mage'], flags=['sanctum_ember_lake']),
    room('R11', '圣歌正殿', 'boss', (132,88), (48,48), 'nave', boss='boss_sanctum_lantern', flags=['sanctum_ember_lake'], defeated='sanctum_ember_nave', poi='poi_sanctum_nave'),
    room('R12', '三火种圣龛', 'rest', (132,148), (24,24), 'bell', flags=['sanctum_final_open']),
    room('R13', '守钟长廊', 'trash', (196,148), (32,24), 'bell', ['d_gargoyle','d_gargoyle'], flags=['sanctum_final_open']),
    room('R14', '丧钟终局厅', 'final', (256,148), (48,48), 'bell', boss='boss_victor', flags=['sanctum_final_open'], poi='poi_sanctum_bell'),
]

def link(index, points, flag='', name=''):
    return dict(id=f'C{index}', **{'from': f'R{index}', 'to': f'R{index+1}'},
                points=[list(p) for p in points], width=8, door_flag=flag, gate_name=name)

connections = [
    link(0, [(200,356),(200,340)]),
    link(1, [(184,320),(156,320)]),
    link(2, [(116,320),(80,320),(80,296)]),
    link(3, [(80,256),(80,240)]),
    link(4, [(104,216),(132,216)], 'sanctum_ember_root', '腐根封印'),
    link(5, [(164,216),(188,216)]),
    link(6, [(228,216),(252,216)]),
    link(7, [(272,196),(272,152),(304,152)]),
    link(8, [(328,128),(328,88),(272,88)], 'sanctum_ember_lake', '灰巾封印'),
    link(9, [(240,88),(216,88)]),
    link(10, [(176,88),(156,88)]),
    link(11, [(132,112),(132,136)], 'sanctum_final_open', '三火种封印'),
    link(12, [(144,148),(180,148)]),
    link(13, [(212,148),(232,148)]),
]

layout = dict(version='sanctum-unity-v1', grid=4, floor_height=20, rooms=rooms, connections=connections)
ASSETS.mkdir(parents=True, exist_ok=True)
(ASSETS/'layout.json').write_text(json.dumps(layout, ensure_ascii=False, indent=2), encoding='utf-8')
editor_assets = WORK/'UnityProject/Assets/SanctumWorkshop'
editor_assets.mkdir(parents=True, exist_ok=True)
(editor_assets/'layout.json').write_text(json.dumps(layout, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Authored {len(rooms)} rooms, {len(connections)} connections; source {ASSETS / "layout.json"}')
