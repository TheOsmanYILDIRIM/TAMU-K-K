extends RefCounted
## Data-only Godot catalog port of TAMU's 19-piece LÖVE construction prototype.
## Not an inventory debit, Stage6 save migration, or runtime placement authority.
const UNIT := 32.0
const PIECES := {
    "tamu:foundation_wood": {"shape": "foundation", "material": "wood", "cost": {"core:wood_plank": 4, "core:wood_log": 2}, "mode": "foundation"},
    "tamu:foundation_stone": {"shape": "foundation", "material": "stone", "cost": {"core:stone": 8}, "mode": "foundation"},
    "tamu:floor_wood": {"shape": "floor", "material": "wood", "cost": {"core:wood_plank": 2}, "mode": "attached"},
    "tamu:floor_stone": {"shape": "floor", "material": "stone", "cost": {"core:stone": 4}, "mode": "attached"},
    "tamu:wall_wood": {"shape": "wall", "material": "wood", "cost": {"core:wood_plank": 3}, "mode": "attached"},
    "tamu:wall_stone": {"shape": "wall", "material": "stone", "cost": {"core:stone": 5}, "mode": "attached"},
    "tamu:window_wood": {"shape": "window", "material": "wood", "cost": {"core:wood_plank": 3}, "mode": "attached"},
    "tamu:window_stone": {"shape": "window", "material": "stone", "cost": {"core:stone": 5}, "mode": "attached"},
    "tamu:doorway_wood": {"shape": "doorway", "material": "wood", "cost": {"core:wood_plank": 3}, "mode": "attached"},
    "tamu:doorway_stone": {"shape": "doorway", "material": "stone", "cost": {"core:stone": 5}, "mode": "attached"},
    "tamu:halfwall_wood": {"shape": "halfwall", "material": "wood", "cost": {"core:wood_plank": 2}, "mode": "attached"},
    "tamu:railing_wood": {"shape": "railing", "material": "wood", "cost": {"core:wood_plank": 2}, "mode": "attached"},
    "tamu:post_wood": {"shape": "post", "material": "wood", "cost": {"core:wood_log": 2}, "mode": "attached"},
    "tamu:roof_flat_wood": {"shape": "roof_flat", "material": "wood", "cost": {"core:wood_plank": 3}, "mode": "attached"},
    "tamu:roof_slope_wood": {"shape": "roof_slope", "material": "wood", "cost": {"core:wood_plank": 4}, "mode": "attached"},
    "tamu:stairs_wood": {"shape": "stairs", "material": "wood", "cost": {"core:wood_plank": 5}, "mode": "attached"},
    "tamu:fence_wood": {"shape": "fence", "material": "wood", "cost": {"core:wood_log": 2}, "mode": "free"},
    "tamu:fence_stone": {"shape": "fence", "material": "stone", "cost": {"core:stone": 4}, "mode": "free"},
    "tamu:fence_gate_wood": {"shape": "fence_gate", "material": "wood", "cost": {"core:wood_plank": 3}, "mode": "free"}
}

static func ids() -> Array:
    var result: Array = PIECES.keys()
    result.sort()
    return result

static func get_piece(id: String) -> Dictionary:
    if not PIECES.has(id):
        return {}
    var result: Dictionary = PIECES[id].duplicate(true)
    result["id"] = id
    result["rotation_steps"] = 4
    result["unit"] = UNIT
    result["asset_status"] = "procedural_placeholder"
    result["collision_status"] = "not_integrated"
    return result

static func verify() -> bool:
    if PIECES.size() != 19:
        return false
    for id in PIECES:
        var p: Dictionary = get_piece(id)
        if not id.begins_with("tamu:") or not ["foundation", "attached", "free"].has(p["mode"]):
            return false
        if p["cost"].is_empty():
            return false
        for item in p["cost"]:
            if not str(item).begins_with("core:") or int(p["cost"][item]) <= 0:
                return false
    return true
