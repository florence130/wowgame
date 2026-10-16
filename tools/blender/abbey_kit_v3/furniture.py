"""Editable Aetherlands abbey wooden furniture, metres, +Z up, +Y front.

Caller sets geometry.COL, geometry.ROOT and geometry.material. Builders return
individual objects: legs, boards, seat, kneeler and ornamental rails stay
separable. Actual Mirror / Array / Solidify / curve-bevel modifiers are retained.
All origin coordinates are at floor level. No lights, scene state or colors are
changed. Required material keys: wood, timber, wood_dark and bronze.
"""
import math
import bpy
import geometry as G


RECIPES = {
    'pew_2m': {'bounds': [[-1,-.425,0],[1,.425,1.15]],
               'seat_top': .48, 'kneeler_top': .16, 'front': '+Y',
               'sockets': {'row_next': [0,1.25,0]}},
    'pew_end': {'overall_thickness': .13, 'carcass_thickness': .104, 'height': 1.15,
                'sockets': {'left_end_of_2m': [-.935,0,0], 'right_end_of_2m': [.935,0,0],
                            'left_end_of_4m_repeat_body': [-2,0,0], 'right_end_of_4m_repeat_body': [2,0,0]},
                'repeat_body_rule': 'For N metre bays centred at i-(N-1)/2, place ends at ±N/2. Overall length=N+.13.'},
    'pew_seat_1m': {'pitch_x': 1, 'seat_top': .48,
                    'sockets': {'start': [-.5,0,0], 'end': [.5,0,0]}},
    'lectern': {'width': .8, 'height': 1.25, 'reader_side': '-Y'},
    'altar_table': {'width': 2.2, 'depth': .9, 'table_top': 1.05},
    'wood_dais_2m': {'bounds': [[-1,-1,0],[1,1,.48]], 'tile_pitch': [2,2],
                     'sockets': {'front_stair_upper': [0,1,.48]}},
    'wood_stairs': {'bounds': [[-1,0,0],[1,1.05,.48]],
                    'rise': .16, 'run': .35, 'count': 3,
                    'sockets': {'upper_floor': [0,0,.48], 'lower_ground': [0,1.05,0]}},
}


def _tag(objects, family):
    for obj in objects:
        obj['asset_family']='Abbey v3 furniture'
        obj['recipe']=family
        obj['separable_component']=True
        # Broad painted timber marks instead of densely repeated 1m texture grain.
        if obj.type=='MESH' and not obj.get('furniture_uv_scaled',False):
            for layer in obj.data.uv_layers:
                for loop in layer.data:loop.uv*=.32
            obj['furniture_uv_scaled']=True
    return objects


def _mirror(obj, axes=(True,False,False)):
    mod=obj.modifiers.new('01 Mirror symmetric joinery','MIRROR')
    mod.use_axis=axes
    mod.use_clip=False
    mod.use_mirror_merge=False
    return obj


def _move_mesh(obj,x=0,y=0,z=0):
    """Move coordinates, preserving origin as the assembly's mirror plane."""
    if obj.type=='MESH':
        for vert in obj.data.vertices:
            vert.co.x+=x;vert.co.y+=y;vert.co.z+=z
    elif obj.type=='CURVE':
        for spline in obj.data.splines:
            for point in spline.points:
                point.co.x+=x;point.co.y+=y;point.co.z+=z
    return obj


def _yz_profile(name,outline,thickness=.13,x=0,material='wood'):
    n=len(outline)
    verts=[(x+dx,y,z) for dx in (-thickness/2,thickness/2) for y,z in outline]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return G.mesh(name,verts,faces,material)


def _square_post(name,rings,x=0,y=0,material='timber'):
    """Four-sided layered extruded carpenter's post; rings=(z,width,depth)."""
    verts=[]
    for z,w,d in rings:
        verts.extend([(x-w/2,y-d/2,z),(x+w/2,y-d/2,z),
                      (x+w/2,y+d/2,z),(x-w/2,y+d/2,z)])
    faces=[(3,2,1,0)]
    for j in range(len(rings)-1):
        for i in range(4):
            a=j*4+i;b=j*4+(i+1)%4
            faces.append((a,b,b+4,a+4))
    faces.append(tuple(range((len(rings)-1)*4,len(rings)*4)))
    obj=G.mesh(name,verts,faces,material)
    obj['construction']='03 layered profile extrusion'
    return G.bevel(obj,.008)


def pew_end():
    """Removable end, overall thickness .13, height1.15; x0 floor origin.

    Carcass=.104, recessed trim/feet have different exterior planes, avoiding
    coincident exposed faces. For N metre bays, mount ends at x=±N/2; total N+.13.
    """
    parts=[]
    # Side silhouette rises into the back upright and curls into a broad arm.
    outline=[(-.425,.08),(-.425,1.07),(-.385,1.15),(-.30,1.15),
             (-.25,1.09),(-.25,.82),(-.18,.74),(.22,.71),(.30,.66),
             (.32,.57),(.30,.48),(.23,.43),(.23,.18),(.16,.10),(-.22,.10)]
    side=_yz_profile('Pew end carved side panel',outline,.104,0,'wood')
    G.bevel(side,.015)
    side['construction']='03 extruded side silhouette'
    parts.append(side)
    # Two load-bearing feet touch floor exactly; the panel actually overlaps them.
    for y in (-.31,.20):
        parts.append(_square_post('Pew end floor bearing foot',[(0,.13,.18),(.065,.13,.18),
                                  (.095,.11,.13),(.25,.11,.13)],0,y,'timber'))
    parts.append(G.box('Pew end lower stretcher',(.095,.59,.105),(0,-.055,.24),'timber',.008))
    # Raised inset follows the outer profile on both visible sides, mirrored in X.
    inset=[(-.353,.42),(-.353,.99),(-.32,1.055),(-.30,.99),(-.30,.63),
           (-.21,.56),(.16,.56),(.19,.52),(.14,.49),(-.20,.49)]
    inlay=_yz_profile('Pew end carved inset',inset,.012,.057,'wood_dark')
    G.bevel(inlay,.004)
    parts.append(_mirror(inlay))
    return _tag(parts,'pew_end')


def pew_seat_1m(width=1.0,supports=True,kneeler=True):
    """One repeatable X bay, no ornamental end boards; join at x=±width/2.

    +Y is the seated person's gaze. Back = -Y. Seat top=.48, kneeler top=.16.
    The visible 3-seat-board and 4-back-slat arrays remain editable.
    """
    parts=[]
    seat=G.box('Pew seat plank array',(width,.146,.060),(0,-.142,.450),'wood',.006)
    G.array(seat,3,(0,.154,0))
    parts.append(seat)
    for y in (-.19,.235):
        parts.append(G.box('Pew seat longitudinal apron',(width,.060,.095),(0,y,.3775),'timber',.006))
    # Repeating upper pointed slats; the broad top rail makes the back comfortable.
    pitch=width/4
    slat=G.profile('Pew back pointed slat array',
                   [(-pitch*.38,.565),(pitch*.38,.565),(pitch*.38,.985),
                    (0,1.045),(-pitch*.38,.985)],.052,'wood',-.307)
    _move_mesh(slat,-width/2+pitch/2)
    # A slight lean, implemented in geometry before the editable array.
    for v in slat.data.vertices:v.co.y-=(v.co.z-.565)*.11
    G.bevel(slat,.004)
    G.array(slat,4,(pitch,0,0))
    parts.append(slat)
    parts.append(G.box('Pew back lower framed rail',(width,.075,.087),(0,-.306,.577),'timber',.006))
    parts.append(G.box('Pew back shaped top rail',(width,.082,.105),(0,-.362,1.085),'wood_dark',.011))
    if supports:
        # One support assembly is mirrored to both ends of the metre-long bay.
        for y in (-.15,.19):
            leg=_square_post('Pew seat trestle mirrored legs',[(0,.12,.13),(.07,.12,.13),
                             (.10,.092,.105),(.43,.092,.105)],width*.31,y,'timber')
            parts.append(_mirror(leg))
        brace=G.box('Pew seat trestle crossbar',(.10,.44,.095),(width*.31,.02,.28),'wood_dark',.006)
        parts.append(_mirror(brace))
        upright=_yz_profile('Pew seat mirrored structural back uprights',
                            [(-.202,.055),(-.104,.055),(-.254,.59),
                             (-.323,1.11),(-.398,1.11),(-.343,.57)],
                            .092,width*.31,'timber')
        G.bevel(upright,.005)
        parts.append(_mirror(upright))
    if kneeler:
        parts.append(G.box('Pew removable kneeler board',(width-.03,.17,.045),(0,.34,.1375),'wood_dark',.010))
        kleg=G.box('Pew kneeler mirrored floor feet',(.105,.12,.115),(width*.30,.34,.0575),'timber',.006)
        parts.append(_mirror(kleg))
    return _tag(parts,'pew_seat_1m')


def pew_2m(kneeler=True):
    """Complete 2m pew: separate feet/back/ends and optional removable kneeler."""
    parts=[]
    # Two .89m inner bays overlap the end carcass by7mm without sharing its
    # exterior plane. Ends at ±.935 retain the complete pew's exact2m envelope.
    for obj in pew_seat_1m(width=.89,supports=False,kneeler=kneeler):
        # Append a second array after the local plank/slat arrays; never bake it.
        _move_mesh(obj,-.445)
        # Existing mirror on kneeler foot is first evaluated about its bay.
        # Moving a mirrored foot would move its plane, so replace those below.
        if 'kneeler mirrored floor feet' in obj.name:
            bpy.data.objects.remove(obj,do_unlink=True)
            continue
        G.array(obj,2,(.89,0,0))
        parts.append(obj)
    for obj in pew_end():
        if 'carved inset' in obj.name:
            # The inset's own X mirror is applied only to preserve two side faces;
            # the outer assembly mirror stays editable and duplicates the whole end.
            G.apply_modifier(obj,obj.modifiers[-1])
        _move_mesh(obj,.935)
        parts.append(_mirror(obj))
    if kneeler:
        foot=G.box('Pew complete kneeler floor supports',(.13,.12,.115),(.65,.34,.0575),'timber',.006)
        parts.append(_mirror(foot))
    return _tag(parts,'pew_2m')


def lectern():
    """Sloped reading desk, reader at -Y; maximum top Z1.25, width .8."""
    parts=[]
    base=[(-.34,0),(.34,0),(.40,.065),(.40,.13),(.31,.19),(-.31,.19),(-.40,.13),(-.40,.065)]
    parts.append(G.bevel(G.profile('Lectern chamfered heavy base',base,.55,'timber'),.014))
    parts.append(_square_post('Lectern layered pedestal',[(.16,.30,.26),(.24,.30,.26),(.28,.21,.19),
                (.77,.17,.17),(.83,.28,.24),(.88,.28,.24),(.93,.38,.32)],0,0,'wood'))
    # Wooden front shield gives a wide, readable silhouette with bevelled profile.
    shield=[(-.27,.52),(-.27,.97),(0,1.08),(.27,.97),(.27,.52),(0,.36)]
    parts.append(G.bevel(G.profile('Lectern pointed front shield',shield,.065,'wood',.17),.012))
    inner=[(-.18,.59),(-.18,.91),(0,.985),(.18,.91),(.18,.59),(0,.48)]
    parts.append(G.bevel(G.profile('Lectern inset carving',inner,.017,'wood_dark',.212),.006))
    support=_yz_profile('Lectern structural sloping desk support',
                        [(-.25,1.035),(.25,1.189),(.12,.88),(-.12,.88)],.34,0,'timber')
    parts.append(G.bevel(support,.006))
    # Actual four-corner open surface plus retained solidify modifier.
    plane=G.mesh('Lectern sloped reading surface',[(-.40,-.30,1.065),(.40,-.30,1.065),
                 (.40,.30,1.25),(-.40,.30,1.25)],[(0,1,2,3)],'wood')
    solid=plane.modifiers.new('04 Solidify sloping wooden desk','SOLIDIFY')
    solid.thickness=.052;solid.offset=-1
    G.bevel(plane,.008)
    parts.append(plane)
    parts.append(G.box('Lectern book retaining lip',(.75,.043,.045),(0,-.274,1.093),'wood_dark',.006))
    # Inlaid symbol, kept thick enough for game-distance reading.
    parts.append(G.box('Lectern bronze vertical inlay',(.033,.018,.23),(0,.230,.745),'bronze',.003))
    parts.append(G.box('Lectern bronze cross inlay',(.14,.018,.033),(0,.230,.785),'bronze',.003))
    return _tag(parts,'lectern')


def altar_table():
    """2.2m x .9m table, top1.05; mortised legs, framed apron, carved front."""
    parts=[]
    # A shaped slab and a narrower under-edge produce a stepped carpenter profile.
    parts.append(G.box('Altar broad wooden table slab',(2.2,.9,.075),(0,0,1.0125),'wood',.014))
    parts.append(G.box('Altar table lower moulding',(2.11,.81,.045),(0,0,.953),'wood_dark',.007))
    leg=_square_post('Altar four mirrored shaped legs',[(0,.20,.20),(.085,.20,.20),(.12,.15,.15),
                     (.65,.13,.13),(.72,.18,.18),(.78,.18,.18),(.96,.16,.16)],.88,.29,'timber')
    parts.append(_mirror(leg,(True,True,False)))
    apron=G.box('Altar front and back apron',(1.83,.075,.205),(0,.32,.835),'wood',.008)
    parts.append(_mirror(apron,(False,True,False)))
    endrail=G.box('Altar left and right apron',(.075,.65,.205),(.88,0,.835),'wood_dark',.007)
    parts.append(_mirror(endrail))
    parts.append(G.box('Altar low longitudinal stretcher',(1.85,.10,.12),(0,0,.205),'wood_dark',.008))
    brace=G.box('Altar low cross stretcher',(.11,.68,.11),(.88,0,.205),'timber',.007)
    parts.append(_mirror(brace))
    # Three framed diamond panels read as carved joinery, with no floating props.
    panel=G.profile('Altar recessed diamond panel array',[(-.18,.835),(0,.909),(.18,.835),(0,.761)],.020,'wood_dark',.367)
    _move_mesh(panel,-.55)
    G.bevel(panel,.004);G.array(panel,3,(.55,0,0));parts.append(panel)
    for z in (.744,.926):
        rail=G.line('Altar front carved border rail',[(-.87,.371,z),(.87,.371,z)],.012,'wood_dark')
        parts.append(rail)
    parts.append(G.box('Altar center bronze vertical',(.018,.009,.087),(0,.384,.835),'bronze',.002))
    parts.append(G.box('Altar center bronze horizontal',(.058,.009,.018),(0,.384,.845),'bronze',.002))
    return _tag(parts,'altar_table')


def wood_dais_2m():
    """Tileable 2x2 platform, top Z=.48; X/Y tile pitch exactly2, origin floor."""
    parts=[]
    # Floor-bearing frame has closed perimeter: no apparently floating platform.
    apron=G.box('Dais mirrored outer X rim',(.10,2,.40),(.95,0,.20),'timber',.008)
    parts.append(_mirror(apron))
    apron=G.box('Dais mirrored outer Y rim',(1.80,.10,.40),(0,.95,.20),'timber',.008)
    parts.append(_mirror(apron,(False,True,False)))
    parts.append(G.box('Dais dark closed underdeck',(1.99,1.99,.045),(0,0,.4125),'wood_dark',.004))
    board=G.box('Dais floor plank editable ten array',(.194,2,.045),(-.9,0,.4575),'wood',.004)
    G.array(board,10,(.2,0,0));parts.append(board)
    # Two braces bear the decking; geometry remains inspectable from below.
    brace=G.box('Dais load bearing joist array',(.12,1.81,.27),(-.50,0,.27),'wood_dark',.007)
    G.array(brace,3,(.5,0,0));parts.append(brace)
    return _tag(parts,'wood_dais_2m')


def wood_stairs():
    """Three 0.16m rises, .35m runs. Upper edgeY=0, lower edgeY=1.05.

    Place at (0,1,0) to connect to wood_dais_2m's +Y edge. Upper walking
    surface=.48, lower walking surface=.16; the adjoining ground is Z=0.
    """
    parts=[]
    side=[(0,0),(1.05,0),(1.05,.125),(.70,.125),(.70,.285),
          (.35,.285),(.35,.445),(0,.445)]
    stringer=_yz_profile('Wood stair mirrored stepped stringer',side,.12,.91,'timber')
    G.bevel(stringer,.008);parts.append(_mirror(stringer))
    # Start at the lowest tread: one real array simultaneously moves Y and Z.
    tread=G.box('Wood stair three tread array',(2,.35,.035),(0,.875,.1425),'wood',.005)
    G.array(tread,3,(0,-.35,.16));parts.append(tread)
    riser=G.box('Wood stair three riser board array',(1.78,.043,.125),(0,1.0185,.0625),'wood_dark',.006)
    G.array(riser,3,(0,-.35,.16));parts.append(riser)
    # Under-tread bearers follow the same stair rhythm and join both stringers.
    joist=G.box('Wood stair tread support bearer array',(1.88,.10,.075),(0,.76,.0875),'timber',.006)
    G.array(joist,3,(0,-.35,.16));parts.append(joist)
    return _tag(parts,'wood_stairs')


def altar_back_panel():
    """Optional self-supporting 2.4m wooden reredos; floor origin, height2.8."""
    parts=[]
    for x in (-1.07,1.07):
        parts.append(_square_post('Reredos floor bearing carved post',[(0,.23,.42),(.15,.23,.42),
                     (.19,.17,.20),(2.38,.17,.20),(2.44,.25,.25),(2.53,.25,.25)],x,0,'timber'))
    parts.append(G.box('Reredos lower panel rail',(2.15,.16,.20),(0,0,.29),'wood_dark',.010))
    parts.append(G.box('Reredos top lintel',(2.4,.20,.16),(0,0,2.50),'wood_dark',.010))
    outline=[(-.34,.37),(.34,.37),(.34,1.97),(0,2.38),(-.34,1.97)]
    panel=G.profile('Reredos three pointed panel array',outline,.072,'wood',0)
    _move_mesh(panel,-.71)
    G.bevel(panel,.007);G.array(panel,3,(.71,0,0));parts.append(panel)
    for x in (-.71,0,.71):
        points=[(x-.27,.055,.50),(x-.27,.055,1.94),(x,.055,2.26),
                (x+.27,.055,1.94),(x+.27,.055,.50)]
        parts.append(G.line('Reredos raised pointed tracer',points,.023,'wood_dark'))
    parts.append(G.profile('Reredos triangular crown',[(-.65,2.58),(0,2.8),(.65,2.58)],.13,'wood',0))
    return _tag(parts,'altar_back_panel')
