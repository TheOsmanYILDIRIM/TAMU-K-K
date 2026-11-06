extends RefCounted
## Godot 4.6 port of the isolated TAMU modular-building anchor contract.
## Source: experiment/modular-building-core-20261029,
## game/love/systems/building_anchors.lua and building_parts.lua.
## World coordinates only: no sprite-pixel matching and no placement bypass.
const UNIT := 32.0
const WALL_HEIGHT := 24.0
const EPSILON := 0.000001

static func _finite_vec(p: Vector3) -> bool:
    return is_finite(p.x) and is_finite(p.y) and is_finite(p.z)

static func line(name: String, kind: String, a: Vector3, b: Vector3) -> Dictionary:
    if name.is_empty() or kind.is_empty() or not _finite_vec(a) or not _finite_vec(b) or a == b:
        return {}
    return {"name": name, "kind": kind, "a": a, "b": b}

static func rotated_xy(point: Vector3, quarter_turn: int) -> Vector3:
    match quarter_turn:
        0: return point
        1: return Vector3(-point.y, point.x, point.z)
        2: return Vector3(-point.x, -point.y, point.z)
        3: return Vector3(point.y, -point.x, point.z)
    return Vector3(INF, INF, INF)

static func transform(edge: Dictionary, origin: Vector3, quarter_turn: int) -> Dictionary:
    if edge.is_empty() or not _finite_vec(origin) or quarter_turn < 0 or quarter_turn > 3:
        return {}
    return line(str(edge["name"]), str(edge["kind"]),
        rotated_xy(edge["a"], quarter_turn) + origin,
        rotated_xy(edge["b"], quarter_turn) + origin)

static func match_lines(first: Dictionary, second: Dictionary, tolerance: float = EPSILON) -> Dictionary:
    if first.is_empty() or second.is_empty() or not is_finite(tolerance) or tolerance < 0.0:
        return {"ok": false, "status": "invalid_anchor"}
    if str(first["kind"]) != str(second["kind"]):
        return {"ok": false, "status": "anchor_kind"}
    var direct: float = maxf(first["a"].distance_to(second["a"]), first["b"].distance_to(second["b"]))
    var inverse: float = maxf(first["a"].distance_to(second["b"]), first["b"].distance_to(second["a"]))
    var error: float = minf(direct, inverse)
    return {"ok": error <= tolerance, "status": "matched" if error <= tolerance else "anchor_gap", "error": error}

static func snap_line(parent: Dictionary, child: Dictionary, quarter_turn: int = 0) -> Dictionary:
    if parent.is_empty() or child.is_empty() or str(parent["kind"]) != str(child["kind"]):
        return {"ok": false, "status": "anchor_kind"}
    var oriented := transform(child, Vector3.ZERO, quarter_turn)
    if oriented.is_empty():
        return {"ok": false, "status": "invalid_rotation"}
    for reverse in [false, true]:
        var offset: Vector3 = parent["a"] - (oriented["b"] if reverse else oriented["a"])
        var placed := transform(child, offset, quarter_turn)
        if bool(match_lines(parent, placed).get("ok", false)):
            return {"ok": true, "origin": offset, "rotation": quarter_turn}
    return {"ok": false, "status": "unsnappable_piece"}

static func piece_line(piece_id: String, slot: String) -> Dictionary:
    ## Structural reference geometry from 19-piece prototype. These are named
    ## segment families, not an authoritative material/catalog registry.
    var shape := piece_id.trim_prefix("tamu:")
    var width := 32.0
    if shape.begins_with("wall_") or shape.begins_with("window_") or shape.begins_with("doorway_"):
        if slot == "top":
            return line(piece_id + ".top", "roof_eave",
                Vector3(-width/2.0, 0, WALL_HEIGHT), Vector3(width/2.0, 0, WALL_HEIGHT))
    if shape.begins_with("halfwall_") or shape.begins_with("railing_"):
        if slot == "top":
            return line(piece_id + ".top", "roof_eave",
                Vector3(-width/2.0, 0, 12), Vector3(width/2.0, 0, 12))
    if shape.begins_with("roof_slope_"):
        if slot == "eave":
            return line(piece_id + ".eave", "roof_eave",
                Vector3(-width/2.0, width/2.0, 0), Vector3(width/2.0, width/2.0, 0))
        if slot == "ridge":
            return line(piece_id + ".ridge", "roof_ridge",
                Vector3(-width/2.0, -width/2.0, 12), Vector3(width/2.0, -width/2.0, 12))
    return {}

static func snap_piece(parent_id: String, parent_origin: Vector3, parent_rotation: int,
        parent_slot: String, child_id: String, child_rotation: int, child_slot: String) -> Dictionary:
    var parent_edge := transform(piece_line(parent_id, parent_slot), parent_origin, parent_rotation)
    var child_edge := piece_line(child_id, child_slot)
    return snap_line(parent_edge, child_edge, child_rotation)

## Single source of truth for old 128px building sprites in Godot's native
## Cartesian/world projection. Old standalone art uses PPU=2, pivot=(64,92).
## Native WorldProjection uses PPU=1, with terrain elevation displayed at 0.35.
## Do NOT add raw terrain height to the construction's structural z coordinate.
const SPRITE_PIVOT := Vector2(64.0, 92.0)
const SPRITE_SCALE := 0.5
const ISO_X := 0.70710678118
const ISO_Y := 0.35355339059
const TERRAIN_HEIGHT_SCREEN_SCALE := 0.35

static func projected_foot(world_xy: Vector2, base_terrain_height: float, structural_z: float = 0.0) -> Vector2:
    if not is_finite(world_xy.x) or not is_finite(world_xy.y) or not is_finite(base_terrain_height) or not is_finite(structural_z):
        return Vector2(INF, INF)
    return Vector2((world_xy.x-world_xy.y)*ISO_X,
        (world_xy.x+world_xy.y)*ISO_Y - base_terrain_height*TERRAIN_HEIGHT_SCREEN_SCALE - structural_z)

static func sprite_draw_top_left(world_xy: Vector2, base_terrain_height: float,
        structural_z: float = 0.0) -> Vector2:
    ## Sprite2D must be non-centered, scale=(0.5,0.5). Position this top-left.
    ## For an AtlasTexture, the region itself is 128x128 and pivot is unchanged.
    return projected_foot(world_xy, base_terrain_height, structural_z) - SPRITE_PIVOT*SPRITE_SCALE

static func verify_projection_contract() -> bool:
    var foot := projected_foot(Vector2(32.0, 0.0), 12.0, 4.0)
    if foot.distance_to(Vector2(32.0*ISO_X, 32.0*ISO_Y-12.0*0.35-4.0)) > 0.00001:
        return false
    var top_left := sprite_draw_top_left(Vector2(32.0, 0.0), 12.0, 4.0)
    if (top_left+SPRITE_PIVOT*SPRITE_SCALE).distance_to(foot) > 0.00001:
        return false
    if projected_foot(Vector2(32.0, 0.0), 0.0, 0.0).distance_to(
            Vector2(32.0*ISO_X, 32.0*ISO_Y)) > 0.00001:
        return false
    return true
