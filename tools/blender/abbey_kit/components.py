"""Reusable abbey component recipes; each creates geometry below G.ROOT."""
import math, bpy
import geometry as G
from sdf import polygonize

def wall(width=4,opening=None,csg=True):
    o=G.box('plaster_core',(width,.4,3),(0,0,1.5),'plaster')
    if opening:
        w,s,b=(2,1.7,-.1) if opening=='door' else (1.4,2.05,.75)
        cut=G.profile('opening_cutter',G.arch_outline(w,s,b),1.2,'plaster')
        G.subtract(o,cut)
    # Exact full width end faces, no protruding corner trim at module seams.
    for z,h,mat in [(.18,.36,'sandstone'),(2.925,.19,'timber')]:
        trim=G.box('continuous_band',(width,.48,h),(0,0,z),mat)
        if opening=='door' and z<1:
            G.subtract(trim,G.box('threshold_cut',(2,.9,1),(0,0,.3)))
    for x,z in [(-width*.36,.68),(width*.35,1.35),(-width*.2,2.7)]:
        if opening and abs(x)<1.1:continue
        G.box('plaster_color_patch',(.22,.006,.11),(x,.204,z),'plaster_patch')

def window_frame():
    G.arch_frame('window',1.4,2.05,.75,.18,.48)
    G.box('sill',(1.96,.64,.16),(0,0,.70),'sandstone',.025)

def window_glass():
    G.profile('glass_insert',G.arch_outline(1.36,2.05,.78),.035,'glass',y=.025)
    G.line('mullion',[(0,.07,.8),(0,.07,2.7)],.038,'timber')
    G.line('transom',[(-.66,.07,1.65),(.66,.07,1.65)],.038,'timber')
    G.profile('amber_diamond',[(0,1.25),(.24,1.6),(0,1.95),(-.24,1.6)],.02,'glass_amber',y=.072)

def door_frame(): G.arch_frame('door',2,1.7,0,.25,.6)

def door(kind='wood'):
    mat='wood' if kind.startswith('wood') else 'stone_dark'
    # 2 cm lateral/vertical clearance relative to frame.
    o=G.profile('door_leaf',G.arch_outline(1.96,1.68,.025),.13,mat)
    if kind=='wood_double':
        # Static double-door insert with disconnected halves; no animation rig.
        G.subtract(o,G.box('center_gap',(.024,.6,3),(0,0,1.5)))
        for i in [-.72,-.48,-.24,.24,.48,.72]:
            height=1.68+math.sqrt(max(0,.98**2-i*i))-.055
            G.box('plank_seam',(.018,.01,height-.04),(i,.07,(height+.04)/2),'timber')
    for x in (-.5,.5):
        for z in (.52,1.55):G.box('strap',(.87,.07,.12),(x,.10,z),'iron',.008)
        G.ring('handle',.10,1.03,.023,'iron',12,y=.14).location.x=x*.4
    if kind=='stone':
        G.profile('stone_door_mark',[(0,.7),(.24,1.1),(0,1.5),(-.24,1.1)],.06,'sandstone',.1)

def rose_frame():G.ring('rose_stone_ring',1.05,0,.14,'sandstone',20)

def rose_glass():
    pts=[(.94*math.cos(i*math.tau/24),.94*math.sin(i*math.tau/24)) for i in range(24)]
    G.profile('rose_back',pts,.035,'glass')
    for k in range(8):
        a=k*math.tau/8
        pts2=[]
        for r,t in [(.20,a),(.61,a-.2),(.9,a),(.61,a+.2)]:pts2.append((r*math.cos(t),r*math.sin(t)))
        G.profile('flower_petal',pts2,.014,'glass_amber',.035)
        G.line('petal_lead',[(x,.055,z) for x,z in pts2],.025,'timber',True)
    G.ring('rose_hub',.18,0,.04,'timber',12,y=.06)

def column():
    G.box('foot',(.78,.78,.2),(0,0,.1),'sandstone',.04)
    G.lathe('turned_column',[(0,.2),(.32,.2),(.32,.36),(.24,.43),(.22,2.5),(.3,2.6),(.32,2.74),(0,2.74)],'sandstone',12)
    G.box('capital',(.8,.8,.26),(0,0,2.87),'stone_light',.035)

def rail(stone=False):
    mat='sandstone' if stone else 'timber'
    for z in (.15,1.05):G.box('rail',(3.5,.18,.16),(0,0,z),mat,.015)
    if stone:
        o=G.lathe('baluster',[(0,.22),(.09,.22),(.11,.3),(.07,.58),(.11,.8),(.09,.96),(0,.96)],'sandstone',8)
        o.location.x=-1.5;G.array(o,7,(.5,0,0))
    else:
        for x in (-1.12,0,1.12):
            G.beam('cross_brace',(x-.5,0,.24),(x+.5,0,.98),.1)
            G.beam('cross_brace',(x+.5,0,.24),(x-.5,0,.98),.1)

def post():
    G.box('post',(.5,.5,1.12),(0,0,.56),'sandstone',.025)
    G.box('post_cap',(.64,.64,.16),(0,0,1.2),'stone_light',.025)

def arcade():
    # 4m centre-to-centre pitch; columns provided by caller only once per boundary.
    G.arch_frame('arcade',3.2,1.1,1.1,.25,.48)
    for x in (-1.8,1.8):G.box('spring_block',(.4,.65,.2),(x,0,1.1),'sandstone',.02)
    # Complete spandrel volume above the arch.
    o=G.box('spandrel',(4,.38,1.9),(0,0,2.05),'plaster')
    G.subtract(o,G.profile('arch_cut',G.arch_outline(3.2,1.1,-.1),.9))
    G.box('header',(4,.55,.18),(0,0,2.91),'timber')

def roof(width=8,length=4):
    half=width/2+.45; top=width*.34; verts=[];faces=[]
    # Half roof with broad segmented bands, mirrored across X.
    nx,ny=4,4
    for j in range(ny+1):
        y=-length/2+length*j/ny
        for i in range(nx+1):
            t=i/nx;x=half*t
            z=top*(1-t)-.12*math.sin(math.pi*t)
            verts.append((x,y,z))
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
    o=G.mesh('roof_half',verts,faces,'terracotta');G.patches(o,['tile_dark','tile_light'],7)
    m=o.modifiers.new('01 Mirror roof','MIRROR');m.use_clip=True
    m=o.modifiers.new('04 Roof thickness','SOLIDIFY');m.thickness=.16;m.offset=-1
    for side in (-1,1):G.box('eave_beam',(.18,length,.2),(side*half,0,-.06),'timber')

def ridge(length=4):
    pts=[(-.24,0),(.24,0),(.18,.2),(0,.29),(-.18,.2)]
    G.profile('ridge_cap',pts,length,'terracotta')

def gable(width=8,rose=True):
    top=width*.34;pts=[(-width/2,0),(width/2,0),(0,top)]
    o=G.profile('gable_infill',pts,.4,'plaster')
    if rose:
        circle=[(.98*math.cos(i*math.tau/24),1.19+.98*math.sin(i*math.tau/24)) for i in range(24)]
        G.subtract(o,G.profile('rose_cut',circle,1))
    for side in (-1,1):G.beam('bargeboard',(0,.25,top),(side*(width/2+.35),.25,-.22),.16)

def floor(stone=True):
    mat='sandstone' if stone else 'wood'
    G.box('floor_slab',(4,4,.2),(0,0,.1),mat)
    if stone:
        for i in range(4):
            for j in range(4):
                G.box('paving_tile',(.985,.985,.025),(-1.5+i,-1.5+j,.2125),'stone_light' if (i+j)%5==0 else 'sandstone')
    else:
        o=G.box('floor_board',(.486,4,.04),(-1.75,0,.22),'wood');G.array(o,8,(.5,0,0))

def steps():
    # Four treads x .3m, four risers x .2m plus .025m tread finish. Closed support below.
    pts=[(-.6,0),(.6,0),(.6,.8),(.3,.8),(.3,.6),(0,.6),(0,.4),(-.3,.4),(-.3,.2),(-.6,.2)]
    # Profile X/Z, rotate to ascend -Y, extrude full 4m width.
    o=G.profile('stair_closed',pts,4,'sandstone');o.rotation_euler.z=-math.pi/2
    o=G.box('tread_nose',(4,.30,.025),(0,.45,.2125),'stone_light');G.array(o,4,(0,-.3,.2))

def chimney():
    o=G.box('chimney_stack',(.8,.8,1.8),(0,0,.9),'plaster')
    G.subtract(o,G.box('flue',(.42,.42,2.1),(0,0,1.05)))
    for z in (.15,1.55,1.8):
        o=G.box('chimney_band',(1,1,.16),(0,0,z),'terracotta')
        G.subtract(o,G.box('flue',(.42,.42,.5),(0,0,z)))

def dome(glass=False):
    if glass:
        o=G.loft('dome_glass',[(2,0),(1.85,.77),(1.414,1.414),(.765,1.848),(.04,2)],'glass',16,False)
        m=o.modifiers.new('04 Glass shell','SOLIDIFY');m.thickness=.035
    else:
        G.lathe('dome_ring',[(1.9,0),(2.12,0),(2.12,.12),(1.9,.12),(1.9,0)],'sandstone',16)
        for k in range(8):
            a=k*math.tau/8
            G.line('dome_rib',[(2*math.cos(t)*math.cos(a),2*math.cos(t)*math.sin(a),2*math.sin(t)) for t in [i*math.pi/12 for i in range(7)]],.055,'timber')

def bridge():
    # A strip with segment boundaries at X=+-2; top is 0.40m.
    v=[];f=[]
    for i in range(9):
        x=-2+i*.5
        v += [(x,-1.5,0),(x,1.5,0),(x,-1.5,.4),(x,1.5,.4)]
    for i in range(8):
        a=i*4;b=a+4;f += [(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)]
    f += [(0,1,3,2),(32,34,35,33)]
    o=G.mesh('bridge_deck',v,f,'sandstone');G.patches(o,['stone_light','stone_dark'])
    # Same .5m sampling for deck, parapets and caps avoids curved surface intersections.
    for sy in (-1,1):
        for name,yhalf,zlo,zhi,mat in [('bridge_parapet',.11,.4,1,'sandstone'),('bridge_cap',.16,1,1.12,'stone_light')]:
            vs=[];fs=[]
            for i in range(9):
                x=-2+i*.5;vs += [(x,sy*1.4-yhalf,zlo),(x,sy*1.4+yhalf,zlo),(x,sy*1.4-yhalf,zhi),(x,sy*1.4+yhalf,zhi)]
            for i in range(8):
                a=i*4;b=a+4;fs += [(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)]
            fs += [(0,1,3,2),(32,34,35,33)]
            G.mesh(name,vs,fs,mat)

def balcony():
    G.box('balcony_floor',(4,1.5,.2),(0,0,.1),'wood')
    for x in (-1.5,1.5):G.beam('corbel',(x,-.65,-1.0),(x,.65,-.08),.2)

def curved_beam():
    # Deliberately tiny bend, editable; isolated decorative beam, no structural socket.
    v=[];f=[]
    for i in range(9):
        x=i*.5
        v += [(x,-.12,-.12),(x,.12,-.12),(x,.12,.12),(x,-.12,.12)]
    for j in range(8):
        for k in range(4):a=j*4+k;b=j*4+(k+1)%4;f.append((a,b,b+4,a+4))
    f += [(3,2,1,0),(32,33,34,35)]
    o=G.mesh('sagging_timber',v,f,'timber');o.location.x=-2
    m=o.modifiers.new('09 Gentle bend','SIMPLE_DEFORM');m.deform_method='BEND';m.deform_axis='Z';m.angle=math.radians(5)

def bell():
    G.loft('bell',[(.64,0),(.68,.1),(.48,.24),(.33,.65),(.18,.78),(.08,.82)],'iron',12,False)
    G.lathe('clapper',[(0,-.18),(.1,-.16),(.14,-.06),(.08,.08),(.05,.55),(0,.55)],'wood',8)

def sdf_asset(kind,refined=True):
    v,f=polygonize(kind,.075,refined);low=min(x[2] for x in v)
    o=G.mesh('SDF_'+kind,[(x,y,z-low) for x,y,z in v],f,'sandstone' if kind!='rock' else 'stone_dark')
    if refined:
        m=o.modifiers.new('SDF low-poly reduction','DECIMATE');m.ratio=.32
    o['construction']='analytic signed distance field -> marching tetrahedra';o['sample_step_m']=.075
    return o

def buttress():
    G.profile('buttress', [(-.35,0),(.35,0),(.3,1.0),(.18,2.8),(-.18,2.8),(-.3,1)],.8,'sandstone')
    G.box('buttress_cap',(.7,1,.18),(0,0,2.83),'stone_light',.02)

def prop(kind):
    if kind=='bench':
        for x in (-.8,.8):G.box('bench_leg',(.2,.55,.5),(x,0,.25),'timber',.02)
        G.box('bench_seat',(2.2,.65,.14),(0,0,.57),'wood',.02)
        for x in (-.85,.85):G.box('back_support',(.1,.1,.55),(x,-.25,.85),'timber')
        G.box('bench_back',(2.2,.1,.3),(0,-.26,.98),'wood',.02)
    elif kind=='planter':
        G.lathe('planter',[(0,0),(.35,0),(.47,.65),(.52,.7),(.5,.8),(.38,.8),(.33,.65),(.22,.14),(0,.14)],'terracotta',10)
        G.loft('plant',[(.2,.72),(.45,1.0),(.3,1.3),(.02,1.45)],'leaf',7)
    elif kind=='crate':
        G.box('crate',(1,1,1),(0,0,.5),'wood',.03)
        for x in (-.4,.4):G.box('crate_band',(.1,1.05,1.05),(x,0,.5),'timber')
    elif kind=='barrel':
        rings=[(.38,0),(.44,.15),(.49,.55),(.44,1.0),(.38,1.1)]
        G.loft('barrel',rings,'wood',12)
        for z,r in [(.12,.447),(.96,.457)]:G.lathe('hoop',[(r,z),(r+.02,z),(r+.02,z+.08),(r,z+.08),(r,z)],'iron',12)
    elif kind=='grave':
        G.box('grave_base',(.8,.55,.2),(0,0,.1),'stone_dark',.04)
        G.box('cross_stem',(.22,.22,1.15),(0,0,.72),'sandstone',.03)
        G.box('cross_arm',(.8,.22,.22),(0,0,1.05),'sandstone',.03)
    elif kind=='dummy':
        G.box('stand',(1,.7,.14),(0,0,.07),'timber')
        G.box('post',(.16,.16,1.9),(0,0,1),'timber')
        G.loft('straw_body',[(.15,.8),(.4,1.0),(.35,1.6),(.15,1.7)],'glass_amber',8)
        G.loft('straw_head',[(.08,1.7),(.22,1.8),(.21,2.05),(.04,2.15)],'glass_amber',8)
        G.box('arm',(1.45,.18,.18),(0,0,1.5),'timber')
    elif kind=='rack':
        for x in (-.8,.8):G.box('rack_post',(.14,.5,1.7),(x,0,.85),'timber')
        G.box('rack_bar',(2,.15,.2),(0,0,1.35),'wood')
        for x in (-.5,0,.5):
            G.beam('spear',(x,-.2,.1),(x,.15,2.25),.07)
            G.loft('spearhead',[(.10,2.25),(0,2.55)],'iron',4).location.x=x
    elif kind=='altar':
        G.box('altar_base',(2.4,1.2,.18),(0,0,.09),'sandstone',.03)
        G.box('altar_body',(2.1,.95,.9),(0,0,.6),'plaster',.025)
        G.box('altar_top',(2.5,1.3,.18),(0,0,1.13),'sandstone',.035)
        G.box('altar_cloth',(.65,1.36,.035),(0,0,1.24),'cloth')
    elif kind=='lamp':
        G.box('lamp_base',(.6,.6,.16),(0,0,.08),'sandstone',.03)
        G.lathe('lamp_pole',[(0,.15),(.13,.15),(.07,2.2),(.18,2.25),(0,2.25)],'iron',8)
        G.box('lamp_glass',(.4,.4,.5),(0,0,2.55),'glass_amber')
        G.loft('lamp_roof',[(.36,2.83),(.05,3.1)],'terracotta',4)
        for x in (-.2,.2):
            for y in (-.2,.2):G.box('lamp_frame',(.035,.035,.53),(x,y,2.55),'iron')
    elif kind=='fountain':
        G.lathe('basin',[(0,0),(1.6,0),(1.6,.3),(1.4,.4),(1.24,.26),(0,.26)],'sandstone',16)
        G.lathe('water',[(0,.28),(1.2,.28),(1.2,.30),(0,.30)],'glass',16)
        G.lathe('fountain_pedestal',[(0,.3),(.3,.3),(.18,1.3),(.7,1.4),(.75,1.55),(.58,1.5),(.18,1.48),(.1,1.9),(0,1.98)],'sandstone',12)
    elif kind=='cypress':
        G.lathe('trunk',[(0,0),(.12,0),(.12,2.8),(0,2.8)],'timber',7)
        for r,z in [(.7,.6),(.64,1.5),(.49,2.4)]:G.loft('cypress_foliage',[(r*.65,z),(r,z+.35),(r*.65,z+1),(.02,z+1.7)],'leaf',7)
    elif kind=='banner':
        G.beam('banner_arm',(-.65,0,2.4),(.65,0,2.4),.1)
        G.profile('banner_cloth',[(-.5,2.3),(.5,2.3),(.5,1.05),(0,.75),(-.5,1.05)],.02,'cloth')
        G.profile('banner_symbol',[(0,1.25),(.16,1.6),(0,1.95),(-.16,1.6)],.02,'glass_amber',.024)
    else:raise ValueError(kind)

RECIPES={
 'wall_plain_4':lambda:wall(), 'wall_plain_2':lambda:wall(2),
 'wall_door_4':lambda:wall(opening='door'), 'wall_window_4':lambda:wall(opening='window'),
 'window_arch_frame':window_frame,'window_arch_glass':window_glass,
 'door_arch_frame':door_frame,'door_wood_double':lambda:door('wood_double'),
 'door_wood_plain':lambda:door('wood_plain'),'door_stone':lambda:door('stone'),
 'rose_frame':rose_frame,'rose_glass':rose_glass,'column_3':column,
 'railing_wood_4':rail,'railing_stone_4':lambda:rail(True),'fence_post':post,
 'arcade_4':arcade,'roof_gable_8x4':roof,'roof_gable_4x4':lambda:roof(4),
 'roof_ridge_4':ridge,'gable_rose_8':gable,'gable_plain_4':lambda:gable(4,False),
 'floor_stone_4':floor,'floor_wood_4':lambda:floor(False),
 'plinth_4':lambda:G.box('plinth',(4,4,.6),(0,0,.3),'sandstone'),
 'stairs_4':steps,'chimney':chimney,'dome_frame_4':dome,'dome_glass_4':lambda:dome(True),
 'bridge_segment_4':bridge,'balcony_4':balcony,'sagging_beam_4':curved_beam,'bell':bell,
 'buttress':buttress,'sdf_stone':lambda:sdf_asset('stone'),'sdf_plinth':lambda:sdf_asset('plinth'),
 'sdf_rock':lambda:sdf_asset('rock'),
 **{f'prop_{k}':(lambda k=k:prop(k)) for k in ['bench','planter','crate','barrel','grave','dummy','rack','altar','lamp','fountain','cypress','banner']}}
