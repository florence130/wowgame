"""Original SVG icon sources. No extracted commercial art or external service.

Discrete painted-looking planes for skill tiles; simple strokes for UI symbols.
Run from any directory with Python 3. SVGs are the editable runtime assets.
"""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/ui/icons'

def path(d, fill, stroke='', width=3):
    return f'<path d="{d}" fill="{fill}"' + (f' stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"' if stroke else '') + '/>'

def circle(x, y, r, fill):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>'

def group(body, transform):
    return f'<g transform="{transform}">{body}</g>'

PALETTES = {
    'fire': ('#442e3d','#ed754e','#ffbd69','#fff0b0'),
    'ice': ('#283f58','#4c9dad','#a0e1df','#f1f6d9'),
    'arcane': ('#393253','#8d7bc2','#c6a7e3','#fff0d5'),
    'holy': ('#424a49','#b9a264','#efcf8b','#fff5d3'),
    'shadow': ('#342e4a','#916caa','#c6a4cc','#efdfdf'),
    'steel': ('#374650','#719daa','#c4d8d0','#fff0c9'),
    'rage': ('#49383a','#b96550','#e5ad73','#fff0bc'),
    'nature': ('#2d4947','#6caa8c','#b3d9a0','#f4efcb'),
}

def motif(name, p):
    bg, lo, mid, hi = p
    if name == 'flame':
        return path('M29 9 C34 23 16 23 19 39 C9 31 14 22 14 22 C3 43 15 57 32 56 C53 55 57 37 47 21 L41 34 C40 21 34 18 29 9Z',lo)+path('M31 24 C35 35 23 36 25 46 L20 40 C19 50 25 55 34 52 C46 48 46 39 40 33 L36 42Z',mid)+path('M33 38 L30 45 L33 51 L39 47Z',hi)
    if name == 'crystal':
        return path('M9 52 L21 29 L48 10 L54 18 L37 44Z',lo)+path('M9 52 L31 25 L48 10 L39 35Z',hi)+path('M9 52 L39 35 L54 18 L37 44Z',mid)+path('M14 27 L22 24 M38 50 L48 43 M8 39 L13 35','none',mid,3)
    if name == 'blade':
        return path('M20 42 L43 9 L53 8 L53 19 L27 47Z',lo)+path('M23 40 L45 12 L50 11 L25 44Z',hi)+path('M25 44 L50 11 L50 18 L30 42Z',mid)+path('M13 37 L33 51 L30 55 L10 41Z',mid)+path('M20 45 L12 56 L7 52 L15 42Z','#b0805b')+path('M11 48 L16 51','none',hi,2)
    if name == 'shield':
        return path('M12 14 L31 8 L53 16 L49 39 Q43 52 31 58 Q13 47 12 14Z',lo)+path('M17 18 L31 13 L47 19 L44 38 Q39 47 31 52 Q19 43 17 18Z',mid)+path('M20 21 L31 17 L31 45 Q22 39 20 21Z',hi)
    if name == 'star':
        return path('M32 5 L39 24 L59 31 L40 39 L33 59 L25 40 L5 32 L25 25Z',lo)+path('M32 12 L36 28 L51 32 L36 36 L32 52 L28 37 L13 32 L28 28Z',mid)+path('M32 17 L33 31 L43 33 L32 35 L30 44 L29 34 L21 31 L30 30Z',hi)
    if name == 'drop':
        return path('M32 8 C30 19 11 31 14 43 C17 61 49 60 51 40 C52 29 38 18 32 8Z',lo)+path('M30 18 C22 33 18 35 21 44 C24 51 35 54 42 45 C31 49 24 39 30 18Z',mid)+path('M21 36 Q19 44 26 47','none',hi,4)
    if name == 'orb':
        return circle(32,32,20,lo)+path('M15 29 Q21 11 39 17 L42 22 L26 24 L20 40Z',mid)+path('M20 26 L27 20 L36 20 L25 29Z',hi)+path('M9 40 Q33 56 55 23','none',mid,4)+circle(48,48,3,hi)
    if name == 'book':
        return path('M8 14 Q20 10 31 18 Q43 9 56 14 L53 48 Q40 46 31 54 Q20 47 10 49Z',lo)+path('M12 16 Q20 14 29 21 L29 47 Q23 42 13 43Z',hi)+path('M34 21 Q42 15 52 17 L49 43 Q39 44 34 48Z',mid)+path('M18 25 L24 28 M18 32 L24 35 M39 26 L46 23 M39 33 L46 30','none',lo,2)
    if name == 'burst':
        return path('M32 6 L39 21 L53 12 L47 28 L61 35 L44 39 L48 54 L35 46 L26 60 L23 44 L7 49 L16 35 L3 26 L21 25 L20 10Z',lo)+path('M32 17 L37 29 L48 31 L38 37 L34 49 L27 39 L15 35 L27 29Z',mid)+path('M32 26 L37 32 L33 39 L27 34Z',hi)
    if name == 'ring':
        return path('M9 39 L13 27 L22 20 L17 34 L28 43 L43 40 L51 30 L55 41 L46 52 L24 55Z',lo)+path('M11 37 L24 48 L45 45 L55 35 L51 45 L42 51 L24 52Z',mid)+path('M14 39 L25 46 L42 44','none',hi,3)
    if name == 'bolt':
        return path('M32 6 L50 6 L36 26 L49 25 L17 59 L25 36 L13 36Z',lo)+path('M32 10 L42 10 L29 29 L39 29 L23 48 L30 32 L20 32Z',hi)
    if name == 'heart':
        return path('M32 22 C16 3 0 26 13 40 L32 56 L52 37 C65 16 42 7 32 22Z',lo)+path('M32 28 Q18 11 12 26 Q11 32 21 40 L32 48 L46 34 Q51 21 40 22Z',mid)+path('M16 25 Q20 19 26 25','none',hi,4)
    if name == 'eye':
        return path('M5 34 Q30 5 59 32 Q33 56 5 34Z',lo)+path('M12 32 Q31 17 51 32 Q30 46 12 32Z',mid)+circle(32,32,10,bg)+path('M32 22 L36 30 L32 42 L28 34Z',hi)
    if name == 'skull':
        return path('M12 30 Q9 9 32 8 Q57 9 52 32 L43 44 L42 54 L22 54 L20 43Z',lo)+path('M16 27 Q17 12 34 14 L47 23 L45 36 L37 42 L37 48 L27 48 L26 40 L17 35Z',mid)+path('M20 27 L28 29 L26 36 L19 32Z M36 28 L44 26 L43 33 L36 36Z M32 35 L28 41 L35 41Z',bg)+path('M22 18 L32 16','none',hi,3)
    if name == 'boot':
        return path('M20 9 L44 12 L39 38 L53 46 L54 55 L10 55 L10 43 L18 35Z',lo)+path('M24 14 L39 16 L34 40 L47 46 L47 49 L17 49 L18 42 L24 36Z',mid)+path('M27 17 L36 19 M26 24 L35 26 M24 31 L33 33','none',hi,3)
    if name == 'horn':
        return path('M11 41 Q34 36 44 13 L56 43 Q34 36 15 53Z',lo)+path('M17 40 Q34 34 43 23 L47 34 Q32 35 19 46Z',mid)+path('M43 15 L55 43','none',hi,4)+path('M15 39 L20 51','none',hi,5)
    if name == 'bullet':
        return path('M18 52 L10 44 L36 16 Q48 6 55 8 Q56 19 46 29Z',lo)+path('M15 43 L38 20 L46 28 L23 50Z',mid)+path('M39 17 Q48 10 52 11 L44 24Z',hi)+path('M13 44 L21 52','none',hi,4)
    if name == 'gun':
        return path('M9 34 L45 16 L54 22 L24 39 L25 48 L15 54 L11 43 L5 44Z',lo)+path('M12 31 L44 14 L53 20 L17 39Z',mid)+path('M19 29 L44 17','none',hi,3)+path('M18 39 L26 37 L31 42 L23 47','none',mid,3)
    if name == 'hound':
        return path('M13 9 L27 21 L39 18 L52 9 L50 35 L44 48 L31 56 L17 47 L11 30Z',lo)+path('M19 21 L28 28 L38 24 L46 20 L43 40 L33 49 L23 43Z',mid)+path('M21 30 L29 32 M37 31 L43 27','none',hi,3)+path('M27 40 L37 38 L33 44Z',bg)
    if name == 'wing':
        return path('M7 13 L32 24 L57 10 L50 27 L43 29 L48 32 L38 40 L33 55 L27 41 L17 36 L19 29 L12 28Z',lo)+path('M12 18 L31 30 L51 17 L44 27 L32 36 L32 46 L27 35 L18 29Z',mid)+path('M14 19 L27 28 M48 20 L36 29','none',hi,3)
    if name == 'sheep':
        return circle(24,33,15,mid)+circle(37,26,12,hi)+circle(40,40,12,mid)+path('M15 40 L17 53 M37 45 L38 53','none',lo,6)+path('M40 21 L55 26 L52 39 L42 37Z',lo)+circle(49,29,2,hi)
    if name == 'hand':
        return path('M20 54 L12 40 L9 25 L15 24 L22 37 L22 12 L28 10 L30 31 L34 7 L40 9 L38 32 L44 16 L50 19 L43 39 L50 32 L55 37 L42 53Z',lo)+path('M24 48 L20 38 L30 37 L37 29 L40 38 L34 48Z',mid)+path('M27 40 L34 39','none',hi,3)
    raise ValueError(name)

# Name -> (motif, palette, composition). Compositions reinforce mechanics at 40–52px.
SKILLS = {}
def entries(palette, values):
    for name, spec in values.items():
        parts=spec.split(':'); SKILLS[name]=(parts[0],palette,parts[1] if len(parts)>1 else '')

entries('rage', dict(steady_slash='blade:rise',heroic_strike='blade:slash',battle_shout='horn',charge='shield:speed',rend='blade:bleed',victory_rush='blade:heart',thunder_clap='bolt:ring',hamstring='boot:slash',bloodrage='drop:burst',pummel='hand:burst',demo_shout='horn:ring'))
entries('fire', dict(fireball='flame:speed',fire_blast='flame:burst'))
entries('ice', dict(frostbolt='crystal:speed',frost_nova='crystal:ring',glacial_flow='drop:flow',frost_armor='shield:crystal',conjure_water='drop'))
entries('arcane', dict(arcane_intellect='book:star',arcane_explosion='orb:burst',arcane_missiles='crystal:triple',polymorph='sheep',blink='boot:speed'))
entries('holy', dict(smite='bolt',lesser_heal='hand:heart',pw_fortitude='shield:heart',pw_shield='shield:star',renew='heart:flow',inner_fire='flame:shield'))
entries('nature', dict(spirit_spark='star:flow'))
entries('shadow', dict(sw_pain='eye:bleed',mind_blast='skull:burst',psychic_scream='skull:ring',stealth='eye',backstab='blade:eye',gouge='eye:slash',evasion='shield:speed',sap='hand'))
entries('steel', dict(sinister_strike='blade:double',eviscerate='blade:burst',sprint='boot:speed',slice_dice='blade:ring',kick='boot:burst',attack='blade',auto_shot='gun',concussive='bullet:ring',scatter_volley='bullet:triple',recoil_jump='boot:gun'))
entries('nature', dict(steady_shot='bullet:flow',corrosive_round='bullet:drop',hawk_stance='wing'))
entries('arcane', dict(aether_shot='bullet:star',hearthstone_cast='orb:flow'))
entries('rage', dict(summon_hound='hound',bayonet='gun:blade',weak_mark='eye:target',mount_horse='hound:speed',mount_mech='gun:ring',eat_drink='heart'))
# 战斗系统重构（2026-10）新增技能
entries('rage', dict(gather_momentum='horn:ring',slash='blade:rise',heavy_slash='blade:slash',execute_slash='blade:burst',whirlwind='blade:ring',thunder_strike='bolt:ring',earth_shatter='boot:burst',armor_break='shield:slash',reckless_fury='flame:burst',taunt='horn:target'))
entries('fire', dict(pyroblast='flame:burst',living_bomb='orb:burst'))
entries('ice', dict(ice_lance='crystal:speed',ice_barrier='shield:crystal'))
entries('arcane', dict(arcane_barrage='orb:triple'))
entries('holy', dict(holy_fire='flame:star',penance='bolt:triple',flash_heal='hand:heart',power_word_shield='shield:star',power_word_fortitude='shield:heart'))
entries('shadow', dict(shadow_word_pain='eye:bleed',mind_flay='eye:flow',shadow_word_death='skull:burst',poisoned_blade='blade:bleed',shadow_strike='blade:eye',mutilate='blade:double',rupture='blade:bleed',kidney_shot='hand:burst',vanish='eye:flow',blind='eye:ring'))
entries('steel', dict(dodge_roll='boot:speed'))

def skill_svg(name, m, palette, comp):
    p=PALETTES[palette]; bg,lo,mid,hi=p
    body=f'<rect x="1" y="1" width="62" height="62" rx="9" fill="{bg}"/>'
    body+=path('M4 46 L17 52 L39 47 L61 36 L61 56 Q60 62 54 62 L10 62 Q3 61 4 46Z',lo+'', '') .replace(f'fill="{lo}"',f'fill="{lo}" opacity=".15"')
    # A single directional underpaint, broad enough to survive downsizing.
    if comp in ('speed','rise'):
        body+=path('M7 27 L25 20 M6 39 L18 33 M30 56 L42 49','none',lo,4)
    if comp in ('burst','target'):
        body+=motif('burst', (bg,lo,lo,mid)) if comp=='burst' else f'<circle cx="32" cy="32" r="24" fill="none" stroke="{lo}" stroke-width="3"/>'
    if comp in ('ring','flow'):
        body+=motif('ring',p)
    if comp=='triple':
        body+=group(motif(m,p),'translate(-4 10) scale(.7)')+group(motif(m,p),'translate(19 5) scale(.65)')+group(motif(m,p),'translate(15 29) scale(.48)')
    elif comp=='double':
        body+=group(motif(m,(bg,lo,lo,mid)),'translate(64 4) scale(-.85 .85)')+group(motif(m,p),'translate(3 1) scale(.9)')
    else:
        body+=group(motif(m,p),'translate(6 4) scale(.82)') if comp in ('flow','ring') else motif(m,p)
    if comp=='slash':
        body+=path('M7 49 Q15 27 49 16 L37 23 Q17 33 7 49Z',mid)
    if comp=='bleed':
        body+=group(motif('drop',PALETTES['fire']),'translate(36 34) scale(.42)')
    if comp in ('star','heart','eye','drop','blade','gun','shield','crystal'):
        body+=group(motif(comp,p),'translate(33 33) scale(.43)')
    body+=f'<rect x="1.5" y="1.5" width="61" height="61" rx="8" fill="none" stroke="{mid}" stroke-opacity=".24"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><title>{name}</title>{body}</svg>'

UI = {
 'char':'M8 21 Q8 14 16 14 Q24 14 24 21 L24 26 L8 26Z M21 7 A5 5 0 1 1 11 7 A5 5 0 1 1 21 7Z',
 'bag':'M7 11 L25 11 L27 27 L5 27Z M11 11 L11 7 Q16 2 21 7 L21 11 M12 17 L20 17 M14 21 L18 21',
 'spells':'M4 7 Q10 4 16 9 Q23 4 28 7 L27 25 Q21 23 16 27 Q10 23 5 25Z M16 9 L16 27 M9 12 L12 13 M20 13 L24 11 M9 17 L12 18 M20 18 L24 16',
 'prof':'M7 5 L12 10 L10 14 L6 15 L2 10 Q2 21 12 20 L23 29 L28 24 L18 14 Q20 4 11 3 M23 5 L27 9 L13 23 L9 19Z',
 'quests':'M7 4 L25 4 L25 28 L7 28Z M12 10 L20 10 M12 15 L20 15 M12 20 L17 20',
 'dungeon':'M5 27 L5 9 L10 9 L10 4 L22 4 L22 9 L27 9 L27 27 M11 27 L11 19 Q16 11 21 19 L21 27 M3 27 L29 27',
 'map':'M3 7 L12 3 L21 7 L29 3 L29 25 L21 29 L12 25 L3 29Z M12 3 L12 25 M21 7 L21 29',
 'menu':'M5 7 L27 7 M5 16 L27 16 M5 25 L27 25 M11 4 L11 10 M21 13 L21 19 M14 22 L14 28',
 'bank':'M3 11 L16 3 L29 11Z M7 15 L7 25 M16 15 L16 25 M25 15 L25 25 M3 29 L29 29',
 'vendor':'M4 11 L7 4 L25 4 L28 11 L28 15 L4 15Z M7 16 L7 28 L25 28 L25 16 M13 20 L19 20',
 'trainer':'M3 10 L16 3 L29 10 L16 17Z M7 13 L7 22 Q16 28 25 22 L25 13 M29 11 L29 23',
 'craft':'M7 23 L20 10 L25 15 L12 28Z M16 6 L20 2 L30 12 L26 16Z M3 6 L9 12 M3 12 L9 6',
 'loot':'M4 14 L28 14 L28 28 L4 28Z M4 14 Q4 4 11 4 L22 4 Q28 4 28 14 M14 13 L18 13 L18 21 L14 21Z',
 'mail':'M3 7 L29 7 L29 26 L3 26Z M3 8 L16 19 L29 8',
 'coin':'M28 16 A12 12 0 1 1 4 16 A12 12 0 1 1 28 16Z M19 9 Q10 8 10 13 Q10 17 17 16 Q23 16 21 21 Q19 25 12 23 M16 6 L16 26',
}

def main():
    for folder in ('skills','ui'):(OUT/folder).mkdir(parents=True,exist_ok=True)
    for name,(m,p,c) in SKILLS.items():(OUT/'skills'/f'{name}.svg').write_text(skill_svg(name,m,p,c),encoding='utf-8')
    for name,d in UI.items():
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">{path(d,"none","#e6d9bc",2)}</svg>'
        (OUT/'ui'/f'{name}.svg').write_text(svg,encoding='utf-8')
    print(f'{len(SKILLS)} skill icons, {len(UI)} UI icons')

if __name__=='__main__':main()
