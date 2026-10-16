"""Continuous stone reveals sealing legacy wall/frame coplanar surfaces.

Local X is opening width, +Y faces outside, Z is vertical. Place at the WALL
centre, not the externally offset glazing root. The small inner overlap hides
the old coplanar frame/reveal seam while retaining the external blockwork.
Caller provides geometry.COL, ROOT and material(). Builders return mesh lists.
"""
import math
import geometry as G


def _pointed(width,height,sill,segments=12):
    radius=width/2
    spring=sill+height-math.sqrt(3)*radius
    result=[(-radius,sill),(radius,sill),(radius,spring)]
    result += [(-radius+width*math.cos(math.pi*i/(3*segments)),
                spring+width*math.sin(math.pi*i/(3*segments))) for i in range(1,segments+1)]
    result += [(radius+width*math.cos(2*math.pi/3+math.pi*i/(3*segments)),
                spring+width*math.sin(2*math.pi/3+math.pi*i/(3*segments))) for i in range(1,segments+1)]
    return result


def _ring_solid(name,inner,outer,y_inner,y_outer):
    if len(inner)!=len(outer):raise ValueError('Reveal profiles must correspond')
    count=len(inner)
    vertices=[]
    # Inner and outer loops at each end make a closed solid ring, not a decal.
    for y in (y_inner,y_outer):
        for loop in (inner,outer):
            vertices.extend((x,y,z) for x,z in loop)
    faces=[]
    for i in range(count):
        j=(i+1)%count
        faces.extend([(i,j,j+2*count,i+2*count),
                      (i+count,i+3*count,j+3*count,j+count),
                      (i,i+count,j+count,j),
                      (i+2*count,j+2*count,j+3*count,i+3*count)])
    ob=G.mesh(name,vertices,faces,'sandstone')
    G.bevel(ob,.004)
    ob['construction']='Closed continuous profile reveal with 15 mm inner lap'
    ob['placement_datum']='Wall centre; exterior normal +Y'
    ob['purpose']='Hide coincident CSG reveal and legacy segmented frame surfaces'
    return [ob]


def pointed_window_reveal(width=1.1,height=2.3,sill=3.1,wall_depth=.46,frame_offset=.22):
    """Window reveal aligned to its wall centre; outside glazing remains intact.

    Defaults match the game clerestory: wall +/- .23 Y, frame root +.22 Y.
    Inner opening is 30 mm narrower and 15 mm shorter; the old glass extends
    behind the new stone lip to close all light leaks. Bottom trim covers sill.
    """
    if width<.2 or height<width*.87:raise ValueError('Invalid pointed opening dimensions')
    inner=_pointed(width-.030,height-.015,sill+.008)
    outer=_pointed(width+.18,height+.18,sill-.085)
    # Stop in the peripheral glazing rebate, beyond the old .15 .. .23 m
    # coincident interval. The visible clear pane is never covered centrally.
    front=max(wall_depth/2+.010,frame_offset+.022)
    return _ring_solid('ABY3_PointWindow_ContinuousStoneReveal',inner,outer,
                       -wall_depth/2-.025,front)


def round_arch_reveal(width=5.2,spring=2.75,bottom=0,wall_depth=.46,frame_depth=.52):
    """Continuous round-arched jamb/soffit return, including the hidden sill.

    Place at the same transform as the wall/portal asset. For the sanctuary
    portal use origin (0,-8,.8), rotation Z=180 under the chapel root.
    """
    if width<.2 or spring<=bottom:raise ValueError('Invalid round opening dimensions')
    # Match the 12-segment wall cutter. A denser circular approximation can
    # actually protrude behind the original inscribed polygon at large spans.
    inner=G.arch_outline(width-.030,spring,bottom+.008,segments=12)
    outer=G.arch_outline(width+.18,spring,bottom-.06,segments=12)
    reach=max(wall_depth/2,frame_depth/2+.046)+.018
    return _ring_solid('ABY3_RoundArch_ContinuousStoneReveal',inner,outer,-reach,reach)


def door_reveal(width=2.5,spring=2.55,bottom=0,wall_depth=.46,frame_depth=.62):
    """Reusable front-door return using the same closed arch construction."""
    return round_arch_reveal(width,spring,bottom,wall_depth,frame_depth)


def window_reveal():
    """Use exactly the existing window_clerestory instance position/rotation.

    Its origin is the old glazing/frame origin, already .22 m outside the wall.
    This wrapper offsets the return back to the wall centre automatically.
    """
    objects=pointed_window_reveal()
    for ob in objects:
        ob.location.y-=.22
        ob['placement_datum']='Existing window_clerestory instance; frame offset compensated'
    return objects


def portal_reveal():
    """Use exactly the rear_portal instance position and rotation."""
    return round_arch_reveal()


def entry_reveal():
    """Use front wall (0,8,.8), Z rotation 0 under the chapel root."""
    objects=door_reveal()
    # The front stone arch itself is mounted .15m outside the wall centre.
    # Cover its full front-to-back inner return as well as the wall thickness.
    for ob in objects:
        for vertex in ob.data.vertices:
            if vertex.co.y>0:vertex.co.y+=.15
        ob.data.update()
    return objects
