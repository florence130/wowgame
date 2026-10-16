"""Editable interior structure and foundations for the abbey kit, metres.

Caller supplies geometry.COL / ROOT and material(). No scene light is created.
Every public builder returns its new objects, including documented light sockets.
"""
import math
import bpy
from mathutils import Vector
import geometry as G


def _before():
    return set(G.COL.objects)


def _after(old):
    return [ob for ob in G.COL.objects if ob not in old]


def _mirror(ob,axis=0):
    modifier=ob.modifiers.new('Mirror paired construction','MIRROR')
    modifier.use_axis=(axis==0,axis==1,axis==2)
    modifier.use_clip=True
    modifier.use_mirror_merge=True
    return modifier


def _socket(name,point,energy_hint=22,radius_hint=.12):
    ob=bpy.data.objects.new(name,None)
    G.COL.objects.link(ob)
    if G.ROOT:ob.parent=G.ROOT
    ob.location=point
    ob.empty_display_type='SPHERE'
    ob.empty_display_size=.055
    ob.hide_render=True
    ob['socket_kind']='light_point'
    ob['local_position']=list(point)
    ob['suggested_energy_watts']=energy_hint
    ob['suggested_radius_metres']=radius_hint
    ob['palette_color']='window_glow'
    return ob


def foundation_strip_4m():
    """X +/-2 m, depth 1.35 m, bottom Z=0, supporting surface Z=.8.

    Actual Array modifiers lay the staggered ashlar courses and coping slabs.
    The recessed continuous core closes all joints and the underside.
    """
    old=_before()
    # Recess the core at the exposed end faces too, avoiding coplanar overlap
    # with the continuous 4 m footing when the last strip end remains visible.
    G.box('ABY3_Foundation_ClosedCore',(3.98,1.23,.72),(0,0,.36),'stone_dark',.009)
    G.box('ABY3_Foundation_GroundFoot',(4,1.35,.13),(0,0,.065),'stone_dark',.014)
    lower=G.box('ABY3_Foundation_AshlarCourseA',(.983,1.285,.235),(-1.5,0,.2675),'stone_mid',.011)
    G.array(lower,4,(1,0,0))
    upper=G.box('ABY3_Foundation_AshlarCourseB',(.983,1.285,.235),(-1,0,.5125),'sandstone',.011)
    G.array(upper,3,(1,0,0))
    for x in (-1.75,1.75):
        G.box('ABY3_Foundation_HalfBond',(.483,1.285,.235),(x,0,.5125),'stone_mid',.011)
    cap=G.box('ABY3_Foundation_CopingSlab',(.989,1.35,.15),(-1.5,0,.725),'sandstone',.012)
    G.array(cap,4,(1,0,0))
    result=_after(old)
    for ob in result:
        ob['foundation_bottom']=0.0
        ob['support_surface']=.8
        ob['repeat_pitch_x']=4.0
    return result


def support_pad(width=1.6,depth=1.8,height=.8):
    """Closed dressed-stone pad, centred in XY with bottom Z=0."""
    if min(width,depth,height)<=0:
        raise ValueError('Pad dimensions must be positive')
    old=_before()
    foot=min(.14,height*.2)
    cap=min(.16,height*.22)
    inset=min(.08,width*.08,depth*.08)
    G.box('ABY3_Pad_GroundFoot',(width,depth,foot),(0,0,foot/2),'stone_dark',min(.022,foot*.15))
    core_top=height-cap*.65
    G.box('ABY3_Pad_SolidCore',(width-inset*2,depth-inset*2,core_top-foot),
          (0,0,(core_top+foot)/2),'stone_dark',.012)
    G.box('ABY3_Pad_UpperDressedSlab',(width,depth,cap),(0,0,height-cap/2),'sandstone',.018)
    course=(height-foot-cap)/2
    for row in range(2):
        z=foot+(row+.5)*course
        block=G.box('ABY3_Pad_FrontAshlar',((width-2*inset)/2-.014,.075,course-.014),
                    (-(width-2*inset)/4,-depth/2+inset-.008,z),
                    'stone_mid' if row==0 else 'sandstone',.009)
        G.array(block,2,((width-2*inset)/2,0,0))
        _mirror(block,1)
        side=G.box('ABY3_Pad_SideAshlar',(.075,(depth-2*inset)/2-.014,course-.014),
                   (-width/2+inset-.008,-(depth-2*inset)/4,z),
                   'sandstone' if row==0 else 'stone_mid',.009)
        G.array(side,2,(0,(depth-2*inset)/2,0))
        _mirror(side,0)
    result=_after(old)
    for ob in result:
        ob['foundation_bottom']=0.0
        ob['support_surface']=height
    return result


def interior_column(height=5.4):
    """Slim .36 m shaft with square seat/capital; exact bottom 0 and top height."""
    if height<1.1:raise ValueError('Interior column must be at least 1.1 m high')
    old=_before()
    G.box('ABY3_Column_SquareFoot',(.74,.74,.20),(0,0,.10),'stone_dark',.025)
    profile=[(0,.18),(.30,.18),(.30,.245),(.25,.29),(.25,.37),(.205,.43),
             (.185,.52),(.175,height*.43),(.165,height-.51),(.205,height-.45),
             (.205,height-.38),(.275,height-.32),(.30,height-.25),
             (.30,height-.18),(0,height-.18)]
    shaft=G.lathe('ABY3_Column_TurnedShaft',profile,'sandstone',16)
    shaft['shaft_nominal_diameter']=.36
    G.box('ABY3_Column_SquareCapital',(.72,.72,.18),(0,0,height-.09),'stone_light',.021)
    return _after(old)


def beam_4m():
    """4 m X-axis beam, .24 m Y x .32 m Z; exact endpoints +/-2.

    Flush end sockets with separate seated tenon cores preserve the 4 m grid.
    End straps and pegs stay inside the endpoint planes; no hidden overlength.
    """
    old=_before()
    timber=G.box('ABY3_Beam_MainTimber',(4,.24,.32),(0,0,0),'timber')
    for sign in (-1,1):
        cutter=G.box('Beam end mortise cutter',(.085,.105,.115),(sign*1.975,0,0),None)
        G.subtract(timber,cutter)
        G.box('ABY3_Beam_SeatedTenon',(.0675,.101,.111),(sign*1.96625,0,0),'wood_dark',.002)
        G.box('ABY3_Beam_EndStrap',(.058,.254,.334),(sign*1.82,0,0),'iron',.004)
        for y in (-.132,.132):
            G.line('ABY3_Beam_JointPeg',[(sign*1.82,y,-.085),(sign*1.82,y,.085)],.018,'bronze')
    G.bevel(timber,.013)
    for z in (-.074,.075):
        G.line('ABY3_Beam_CarvedGrain',[(-1.56,-.121,z),(-.73,-.123,z+.008),
               (.28,-.122,z-.006),(1.5,-.121,z+.009)],.0055,'wood')
    for ob in _after(old):
        ob['repeat_pitch_x']=4.0
        ob['joint_start']=[-2,0,0]
        ob['joint_end']=[2,0,0]
    return _after(old)


def _strut(name,a,b,width=.18,depth=.22,mat='timber'):
    a,b=Vector(a),Vector(b)
    direction=(b-a).normalized()
    side=Vector((-direction.y,direction.x))*width/2
    outline=[tuple(a-side),tuple(b-side),tuple(b+side),tuple(a+side)]
    return G.bevel(G.profile(name,outline,depth,mat),.011)


def roof_truss_8m():
    """King-post truss: inner span 7.4 m, bottom Z=0, peak Z=3.1.

    Two real Mirror modifiers generate the principal rafters and crossed struts.
    Nominal timber sections: tie .28x.30, principals .22x.22, struts .14x.17.
    """
    old=_before()
    G.box('ABY3_Truss_TieBeam',(7.4,.28,.30),(0,0,.15),'timber',.018)
    principal=_strut('ABY3_Truss_MirroredPrincipal',(0,3.01),(3.59,.25),.22,.22)
    _mirror(principal,0)
    G.box('ABY3_Truss_KingPost',(.20,.24,2.95),(0,0,1.625),'wood_dark',.014)
    upward=_strut('ABY3_Truss_MirroredRisingBrace',(.12,.29),(2.52,1.07),.14,.17,'wood')
    _mirror(upward,0)
    crossed=_strut('ABY3_Truss_MirroredCrossBrace',(.12,1.80),(2.13,.29),.14,.17,'wood_dark')
    _mirror(crossed,0)
    # Small straps fasten the actual junctions; they are architectural joinery.
    for x,z,w,h in [(0,.37,.36,.48),(0,2.87,.31,.31),(-3.34,.29,.36,.27),(3.34,.29,.36,.27)]:
        for y in (-.151,.151):
            G.box('ABY3_Truss_JunctionStrap',(w,.032,h),(x,y,z),'iron',.006)
            G.line('ABY3_Truss_BronzePeg',[(x,y-.020,z),(x,y+.020,z)],.028,'bronze')
    for ob in _after(old):
        ob['tie_beam_bottom']=0.0
        ob['tie_beam_span']=7.4
        ob['peak_height']=3.1
    return _after(old)


def _horizontal_ring(name,r,z,thickness,mat='iron',segments=32):
    points=[(r*math.cos(i*math.tau/segments),r*math.sin(i*math.tau/segments),z) for i in range(segments)]
    return G.line(name,points,thickness,mat,True)


def _little_lantern(x,y,z,radius=.105,scale=1.0,name='Chandelier'):
    """Lantern seat at Z=z, top at z+.36*scale; no scene lamp object."""
    s=scale
    base=G.lathe('ABY3_'+name+'_BronzeCup',[(0,-.045*s),(radius*1.35,-.045*s),
                     (radius*1.35,0),(radius*.95,.04*s),(0,.04*s)],'bronze',12)
    base.location=(x,y,z)
    glass=G.lathe('ABY3_'+name+'_GlowingGlass',[(0,.032*s),(radius*.78,.032*s),
                      (radius,.073*s),(radius,.243*s),(radius*.68,.285*s),(0,.285*s)],'window_glow',8)
    glass.location=(x,y,z)
    cap=G.lathe('ABY3_'+name+'_Hood',[(0,.281*s),(radius*1.15,.281*s),
                      (radius*1.15,.310*s),(radius*.65,.335*s),(radius*.28,.360*s),(0,.360*s)],'bronze',8)
    cap.location=(x,y,z)
    for a in (0,math.pi/2,math.pi,math.pi*1.5):
        px,py=x+radius*math.cos(a),y+radius*math.sin(a)
        G.line('ABY3_'+name+'_CageRib',[(px,py,z+.025*s),(px,py,z+.27*s),
               (x+radius*.65*math.cos(a),y+radius*.65*math.sin(a),z+.30*s)],.010*s,'iron')
    socket=_socket('LIGHT_SOCKET_'+name,(x,y,z+.16*s),18 if name=='Chandelier' else 38,.09*s)
    glass['light_socket_name']=socket.name


def chandelier(diameter=1.5,drop=1.0):
    """Six-lantern pendant; origin is ceiling hook, geometry hangs toward -Z.

    Six LIGHT_SOCKET empties sit at radius diameter*.40, Z=-drop+.28.
    Actual light creation and emission strength are owned by the caller.
    """
    if diameter<.7 or drop<.6:raise ValueError('Chandelier is too small for its six lanterns')
    old=_before()
    radius=diameter*.40
    ring_z=-drop+.12
    G.lathe('ABY3_Chandelier_CeilingMount',[(0,-.045),(.095,-.045),(.115,-.017),(.115,0),(0,0)],'iron',12)
    links=max(2,math.floor(drop*.26/.09)+1)
    for parity in (0,1):
        count=(links+1-parity)//2
        if count<1:continue
        center=-.055-parity*.09
        points=[]
        for i in range(12):
            a=i*math.tau/12
            across=.027*math.cos(a)
            points.append((across if parity==0 else 0,across if parity else 0,center+.038*math.sin(a)))
        link=G.line('ABY3_Chandelier_AlternatingChainLink',points,.008,'iron',True)
        G.array(link,count,(0,0,-.18))
    hub_z=-.055-(links-1)*.09-.041
    G.lathe('ABY3_Chandelier_ChainHub',[(0,hub_z-.055),(.06,hub_z-.055),(.07,hub_z),(.025,hub_z+.026),(0,hub_z+.026)],'bronze',10)
    _horizontal_ring('ABY3_Chandelier_CastRing',radius,ring_z,.037,'iron')
    _horizontal_ring('ABY3_Chandelier_BronzeRingTrim',radius,ring_z+.032,.012,'bronze')
    for i in range(3):
        a=(i+.25)*math.tau/3
        c,s=math.cos(a),math.sin(a)
        G.line('ABY3_Chandelier_TensionRod',[(.035*c,.035*s,hub_z-.025),
               (radius*.50*c,radius*.50*s,(hub_z+ring_z)/2+.035),
               (radius*c,radius*s,ring_z)],.016,'iron')
    G.lathe('ABY3_Chandelier_LowerFinial',[(0,-drop),(.043,-drop+.04),(.065,ring_z-.025),(.035,ring_z+.005),(0,ring_z+.005)],'bronze',10)
    for i in range(6):
        a=i*math.tau/6
        c,s=math.cos(a),math.sin(a)
        # Six curved radial lamp trays are physical supports for the cups.
        G.line('ABY3_Chandelier_CurvedLampArm',[(0,0,ring_z),
               (radius*.52*c,radius*.52*s,ring_z-.026),
               (radius*c,radius*s,ring_z)],.024,'iron')
        _little_lantern(radius*c,radius*s,ring_z,diameter*.07,1.0,'Chandelier')
    return _after(old)


def floor_lamp(height=1.8):
    """Freestanding lantern with stable .56 m foot; bottom 0, top height.

    LIGHT_SOCKET is at local (0,0,height-.232). No actual scene lamp is added.
    """
    if height<1.0:raise ValueError('Floor lamp must be at least 1 m high')
    old=_before()
    G.lathe('ABY3_FloorLamp_StableFoot',[(0,0),(.24,0),(.28,.035),(.28,.09),
                (.235,.14),(.15,.18),(.085,.23),(.065,.28),(0,.28)],'iron',16)
    lantern_scale=1.16
    lantern_seat=height-.36*lantern_scale
    G.lathe('ABY3_FloorLamp_TurnedStandard',[(0,.20),(.064,.20),(.064,.29),
                (.033,.34),(.029,lantern_seat-.13),(.062,lantern_seat-.09),
                (.072,lantern_seat-.035),(.072,lantern_seat),(0,lantern_seat)],'bronze',12)
    for z in (.32,lantern_seat-.16):
        _horizontal_ring('ABY3_FloorLamp_ShaftCollar',.039,z,.011,'iron',12)
    _little_lantern(0,0,lantern_seat,.16,lantern_scale,'FloorLamp')
    return _after(old)
