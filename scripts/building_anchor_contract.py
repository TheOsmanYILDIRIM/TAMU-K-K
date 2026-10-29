#!/usr/bin/env python3
"""TAMU KOK structural anchor points and edge matching, independent of art pixels.

Everything is in WORLD units. The 128x128 sprite pivot and 45-degree projection
are only a view of these coordinates. No pixel/image analysis is needed.
"""
from dataclasses import dataclass
from math import hypot, sqrt
from typing import Iterable

MODULE = 32.0
FOUNDATION_H = 4.0
FLOOR_H = 2.0
WALL_H = 24.0
ROOF_RISE = 12.0
PIVOT = (64.0, 92.0)
PPU = 2.0

@dataclass(frozen=True)
class Point:
    x: float
    y: float
    z: float

    def moved(self, dx=0, dy=0, dz=0):
        return Point(self.x + dx, self.y + dy, self.z + dz)

    def rotate(self, direction):
        direction %= 4
        x, y = ((self.x, self.y), (-self.y, self.x),
                (-self.x, -self.y), (self.y, -self.x))[direction]
        return Point(x, y, self.z)

    def distance(self, other):
        return sqrt((self.x-other.x)**2+(self.y-other.y)**2+(self.z-other.z)**2)

    def tolist(self):
        return [self.x, self.y, self.z]

@dataclass(frozen=True)
class Edge:
    name: str
    a: Point
    b: Point
    kind: str

    def moved(self, dx=0, dy=0, dz=0):
        return Edge(self.name, self.a.moved(dx,dy,dz), self.b.moved(dx,dy,dz), self.kind)

    def rotate(self, direction):
        return Edge(self.name, self.a.rotate(direction), self.b.rotate(direction), self.kind)

    def tojson(self):
        return {'name':self.name,'kind':self.kind,'a':self.a.tolist(),'b':self.b.tolist()}


def screen(point: Point, ppu=PPU):
    return (PIVOT[0]+(point.x-point.y)/sqrt(2)*ppu,
            PIVOT[1]+((point.x+point.y)/(2*sqrt(2))-point.z)*ppu)


def endpoints_match(first: Edge, second: Edge, tol=1.e-6):
    if first.kind != second.kind:
        return False, 'incompatible_kind', None
    d_same=max(first.a.distance(second.a), first.b.distance(second.b))
    d_rev=max(first.a.distance(second.b), first.b.distance(second.a))
    dist=min(d_same,d_rev)
    return dist <= tol, ('matched' if dist <= tol else 'endpoint_mismatch'), dist


def require_match(first: Edge, second: Edge, tol=1.e-6):
    ok,reason,dist=endpoints_match(first,second,tol)
    if not ok:
        raise ValueError(f'{first.name} vs {second.name}: {reason} error={dist}')
    return {'first':first.name,'second':second.name,'error_world':dist,
            'world_line':[first.a.tolist(),first.b.tolist()]}


def snap_translation(parent: Edge, child: Edge, reverse=True):
    """Find the translation to snap a rotated child line onto a parent line.

    Returns 3D translation and verifies BOTH endpoints. Translation cannot
    compensate incorrect line length/angle: those must be fixed by geometry.
    """
    if parent.kind != child.kind:
        raise ValueError('anchor kinds differ')
    ca,cb=(child.b,child.a) if reverse else (child.a,child.b)
    move=Point(parent.a.x-ca.x,parent.a.y-ca.y,parent.a.z-ca.z)
    relocated=child.moved(move.x,move.y,move.z)
    require_match(parent,relocated)
    return move


def snap_roof_eave_to_wall(wall: Edge, rotation: int):
    """Exact roof placement from one wall-top line, no sprite pixel search."""
    local=Edge('roof.eave',Point(-MODULE/2,MODULE/2,0),
               Point(MODULE/2,MODULE/2,0),'roof_eave').rotate(rotation)
    errors=[]
    for reverse in (False,True):
        try:
            pos=snap_translation(wall,local,reverse)
            return pos
        except ValueError as error:
            errors.append(str(error))
    raise ValueError('roof edge cannot snap: '+str(errors))


def segment_x(name, cx, y, z, kind='roof_eave'):
    return Edge(name,Point(cx-MODULE/2,y,z),Point(cx+MODULE/2,y,z),kind)


def segment_y(name, x, cy, z, kind='roof_eave'):
    return Edge(name,Point(x,cy-MODULE/2,z),Point(x,cy+MODULE/2,z),kind)


def house_2x2_plan():
    """One exact roof-wall seam plan with a 2x2 footprint and a gable ridge.

    Bases are at z=0, foundation tops 4, floor tops 6, wall tops 30.
    Roof pitches rise from eaves at z=30 to the central ridge z=42.
    """
    width=2*MODULE
    centers=[0, MODULE]
    outer_min=-MODULE/2
    outer_max=3*MODULE/2
    wall_bottom=FOUNDATION_H+FLOOR_H
    wall_top=wall_bottom+WALL_H
    ridge_y=MODULE/2
    ridge_z=wall_top+ROOF_RISE
    pieces=[]
    walls=[]
    roof=[]
    for x in centers:
        for y in centers:
            pieces.append({'kind':'foundation','x':x,'y':y,'z':0,'rotation':0,'layer':0})
            pieces.append({'kind':'floor','x':x,'y':y,'z':FOUNDATION_H,'rotation':0,'layer':1})
    for x in centers:
        for y,typ in ((outer_min,'wall'),(outer_max,'doorway' if x==MODULE else 'wall')):
            pieces.append({'kind':typ,'x':x,'y':y,'z':wall_bottom,'rotation':0,'layer':2})
            walls.append(segment_x('wall.%s.x%d.top'%(typ,x),x,y,wall_top))
    for y in centers:
        for x,typ in ((outer_min,'wall' if y==0 else 'window'),(outer_max,'window' if y==0 else 'wall')):
            pieces.append({'kind':typ,'x':x,'y':y,'z':wall_bottom,'rotation':1,'layer':2})
            # Gable end walls have eave points, while their central top line
            # remains flat: a real triangular infill piece is future art.
    gables=[]
    roof_flanks=[]
    # Both exposed x-ends need half-gable infill, snapped on side-wall top.
    for x in (outer_min,outer_max):
        for y,typ in ((0,'gable_up'),(MODULE,'gable_down')):
            pieces.append({'kind':typ,'x':x,'y':y,'z':wall_top,'rotation':0,'layer':2.5})
            gables.append(segment_y('gable.%s.x%d.base'%(typ,x),x,y,wall_top,'gable_base'))
        # Matching side-wall top lines live on the very same x and y intervals.
    side_walls=[]
    for x in (outer_min,outer_max):
        for y in centers:
            side_walls.append(segment_y('side_wall.x%d.y%d.top'%(x,y),x,y,wall_top,'gable_base'))
    # Solve every roof position from its matching wall-top segment.
    for x in centers:
        north_wall=segment_x('wall.north.x%d.top'%x,x,outer_min,wall_top)
        south_wall=segment_x('wall.south.x%d.top'%x,x,outer_max,wall_top)
        north_pos=snap_roof_eave_to_wall(north_wall,2)
        south_pos=snap_roof_eave_to_wall(south_wall,0)
        north={'kind':'roof_slope','x':north_pos.x,'y':north_pos.y,
               'z':north_pos.z,'rotation':2,'layer':3}
        south={'kind':'roof_slope','x':south_pos.x,'y':south_pos.y,
               'z':south_pos.z,'rotation':0,'layer':3}
        roof.extend((north,south));pieces.extend((north,south))
    roof_eaves=[]
    ridge=[]
    for x in centers:
        roof_eaves.append(segment_x('roof.north.x%d.eave'%x,x,outer_min,wall_top))
        roof_eaves.append(segment_x('roof.south.x%d.eave'%x,x,outer_max,wall_top))
        ridge.append(segment_x('roof.north.x%d.ridge'%x,x,ridge_y,ridge_z,'roof_ridge'))
        ridge.append(segment_x('roof.south.x%d.ridge'%x,x,ridge_y,ridge_z,'roof_ridge'))
    for x in (outer_min,outer_max):
        roof_flanks.append(Edge('roof.flank_n.x%d'%x,Point(x,outer_min,wall_top),
                               Point(x,ridge_y,ridge_z),'gable_slope'))
        roof_flanks.append(Edge('roof.flank_s.x%d'%x,Point(x,ridge_y,ridge_z),
                               Point(x,outer_max,wall_top),'gable_slope'))
    gable_flanks=[]
    for x in (outer_min,outer_max):
        gable_flanks.append(Edge('gable.flank_n.x%d'%x,Point(x,outer_min,wall_top),
                                Point(x,ridge_y,ridge_z),'gable_slope'))
        gable_flanks.append(Edge('gable.flank_s.x%d'%x,Point(x,ridge_y,ridge_z),
                                Point(x,outer_max,wall_top),'gable_slope'))
    # Corners of wall top -> corresponding edge of roof tile.
    matched=[]
    for i in range(len(walls)):
        matched.append(require_match(walls[i],roof_eaves[i]))
    for i in range(0,len(ridge),2):
        matched.append(require_match(ridge[i],ridge[i+1]))
    for a,b in zip(side_walls,gables):
        matched.append(require_match(a,b))
    for a,b in zip(roof_flanks,gable_flanks):
        matched.append(require_match(a,b))
    return {
        'layout':'house_2x2_gable', 'pieces':pieces,
        'world':{'footprint':[outer_min,outer_max,outer_min,outer_max],
                 'foundation_top':FOUNDATION_H,'floor_top':wall_bottom,
                 'wall_top':wall_top,'ridge_z':ridge_z,'ridge_y':ridge_y},
        'wall_top':walls,'roof_eaves':roof_eaves,
        'ridge':ridge,'gable_bases':gables,'gable_flanks':gable_flanks,
        'matches':matched,
        'note':'Eaves, roof ridge, and gable infill edges exactly matched in world coordinates.'
    }


def to_manifest(plan):
    return {'layout':plan['layout'],'world':plan['world'],
            'pieces':plan['pieces'],'matches':plan['matches'],
            'anchors':{'wall_top':[e.tojson() for e in plan['wall_top']],
                       'roof_eaves':[e.tojson() for e in plan['roof_eaves']],
                       'ridge':[e.tojson() for e in plan['ridge']],
                       'gable_bases':[e.tojson() for e in plan['gable_bases']],
                       'gable_flanks':[e.tojson() for e in plan['gable_flanks']]},
            'note':plan['note']}
