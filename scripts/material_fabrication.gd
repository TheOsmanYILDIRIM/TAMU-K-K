extends RefCounted
## Data-only material, furnace alloy and functional tool evaluator.
## Pure preview: it NEVER spends items, writes saves, changes world state,
## awards XP, or trusts client-provided craft authority.
const RULESET_VERSION := 1
const MAX_PARTS := 1000000

static func reject(reason: String) -> Dictionary:
    return {"ok": false, "status": reason}

static func number(value: Variant) -> bool:
    return (value is float or value is int) and is_finite(float(value))

static func unit(value: Variant) -> bool:
    return number(value) and float(value) >= 0.0 and float(value) <= 1.0

static func valid_id(value: String) -> bool:
    return value.length() <= 128 and RegEx.create_from_string("^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$").search(value) != null

static func valid_trait(value: String) -> bool:
    return value.length() <= 128 and RegEx.create_from_string("^[a-z][a-z0-9_]*(?::[a-z][a-z0-9_]*)?$").search(value) != null

static func material_valid(m: Dictionary) -> bool:
    if not m.get("schema_version", null) is int or m["schema_version"] != 1 or not valid_id(str(m.get("id", ""))):
        return false
    if not m.get("traits", null) is Dictionary or m["traits"].is_empty() or not m.get("visual", {}) is Dictionary:
        return false
    for trait_key in m["traits"]:
        if not trait_key is String or not valid_trait(trait_key) or not unit(m["traits"][trait_key]):
            return false
    return true

static func gcd(a: int, b: int) -> int:
    while b != 0:
        var rest := a % b
        a = b
        b = rest
    return a

## Inputs: [{material_id,parts}], materials: {stable-id: MaterialDefinition},
## furnace: {station_tags,heat,quality}, specification: {required_station,
## min_heat,interactions,quality_modifiers,ruleset_version}. Two to twelve
## components; no whitelist of copper/iron/gold, no UI alloy menu here.
static func calculate_alloy(inputs: Array, materials: Dictionary, furnace: Dictionary, specification: Dictionary) -> Dictionary:
    if not specification.get("ruleset_version", null) is int or specification["ruleset_version"] != RULESET_VERSION:
        return reject("ruleset_mismatch")
    var station := str(specification.get("required_station", ""))
    if not valid_id(station):
        return reject("invalid_station")
    var tags: Variant = furnace.get("station_tags", null)
    if not tags is Array or not tags.has(station):
        return reject("furnace_required")
    var heat: Variant = furnace.get("heat", null)
    var quality: Variant = furnace.get("quality", null)
    var min_heat: Variant = specification.get("min_heat", 0.0)
    if not unit(heat) or not unit(quality) or not unit(min_heat):
        return reject("invalid_furnace_process")
    if float(heat) < float(min_heat):
        return reject("insufficient_heat")
    if inputs.size() < 2 or inputs.size() > 12:
        return reject("invalid_alloy_component_count")
    var amounts: Dictionary = {}
    var total := 0
    for row in inputs:
        if not row is Dictionary:
            return reject("invalid_alloy_input")
        var id := str(row.get("material_id", ""))
        var parts: Variant = row.get("parts", null)
        if not valid_id(id) or not parts is int or int(parts) <= 0 or amounts.has(id):
            return reject("invalid_alloy_input")
        if not materials.has(id) or not materials[id] is Dictionary or not material_valid(materials[id]) or materials[id]["id"] != id:
            return reject("unknown_material")
        amounts[id] = int(parts)
        total += int(parts)
        if total > MAX_PARTS:
            return reject("alloy_too_large")
    var ids: Array = amounts.keys()
    ids.sort()
    var names: Array = materials[ids[0]]["traits"].keys()
    names.sort()
    var divisor := 0
    for id in ids:
        divisor = gcd(divisor, amounts[id])
        var source_names: Array = materials[id]["traits"].keys()
        source_names.sort()
        if source_names != names:
            return reject("incompatible_trait_schema")
    var composition: Array = []
    var traits: Dictionary = {}
    for trait_key in names:
        traits[trait_key] = 0.0
    for id in ids:
        var ratio := float(amounts[id]) / float(total)
        composition.append({"material_id": id, "parts": int(amounts[id] / divisor), "fraction": ratio})
        for trait_key in names:
            traits[trait_key] += ratio * float(materials[id]["traits"][trait_key])
    var interactions: Variant = specification.get("interactions", [])
    if not interactions is Array:
        return reject("invalid_interactions")
    for interaction in interactions:
        if not interaction is Dictionary:
            return reject("invalid_interaction")
        var a := str(interaction.get("a", ""))
        var b := str(interaction.get("b", ""))
        var trait_key := str(interaction.get("trait", ""))
        var delta: Variant = interaction.get("delta", null)
        if a == b or not amounts.has(a) or not amounts.has(b) or not traits.has(trait_key) or not number(delta) or absf(float(delta)) > 1.0:
            return reject("invalid_interaction")
        var factor := 4.0 * float(amounts[a]) * float(amounts[b]) / float(total * total)
        traits[trait_key] = clampf(traits[trait_key] + factor * float(delta), 0.0, 1.0)
    var modifiers: Variant = specification.get("quality_modifiers", {})
    if not modifiers is Dictionary:
        return reject("invalid_quality_modifiers")
    for trait_key in modifiers:
        if not traits.has(trait_key) or not number(modifiers[trait_key]) or absf(float(modifiers[trait_key])) > 1.0:
            return reject("invalid_quality_modifier")
        traits[trait_key] = clampf(traits[trait_key] + (float(quality) - 0.5) * float(modifiers[trait_key]), 0.0, 1.0)
    var signature := "tamu-material-v1|" + station + "|" + str(snappedf(float(heat), 0.0001)) + "|" + str(snappedf(float(quality), 0.0001))
    var layers: Array = []
    for row in composition:
        signature += "|" + str(row["material_id"]) + ":" + str(row["parts"])
        layers.append({"source": row["material_id"], "fraction": row["fraction"], "visual": materials[row["material_id"]].get("visual", {}).duplicate(true)})
    for trait_key in names:
        signature += "|" + str(trait_key) + "=" + str(snappedf(float(traits[trait_key]), 0.000001))
    var fingerprint := signature.sha256_text()
    return {"ok": true, "status": "preview_only", "ruleset_version": RULESET_VERSION,
        "fingerprint": fingerprint, "material": {"schema_version": 1,
            "id": "alloy:m_" + fingerprint.substr(0, 24), "traits": traits,
            "composition": composition, "visual": {"seed": fingerprint.substr(0, 16), "layers": layers}}}

## A blueprint describes roles + desired traits + explicit stat formulas.
## Material names are never permitted/forbidden by item class. Extremely
## unsuitable materials remain possible, unless an explicit physical hard
## limit is present in a trusted blueprint.
static func evaluate_tool(blueprint: Dictionary, bindings: Dictionary, process: Dictionary = {}) -> Dictionary:
    if not blueprint.get("ruleset_version", null) is int or blueprint["ruleset_version"] != RULESET_VERSION or not valid_id(str(blueprint.get("id", ""))):
        return reject("invalid_blueprint")
    var roles: Variant = blueprint.get("roles", null)
    var formulas: Variant = blueprint.get("stats", null)
    if not roles is Array or roles.is_empty() or not formulas is Dictionary or formulas.is_empty():
        return reject("invalid_blueprint_structure")
    var resolved: Dictionary = {}
    var suitability: Dictionary = {}
    var score_sum := 0.0
    var feasible := true
    for role in roles:
        if not role is Dictionary:
            return reject("invalid_role")
        var role_id := str(role.get("id", ""))
        if not valid_trait(role_id) or resolved.has(role_id) or not bindings.has(role_id) or not bindings[role_id] is Dictionary:
            return reject("invalid_role_binding")
        var m: Dictionary = bindings[role_id]
        if not material_valid(m):
            return reject("invalid_role_material")
        var preferences: Variant = role.get("preferences", {})
        var hard_limits: Variant = role.get("hard_limits", {})
        if not preferences is Dictionary or not hard_limits is Dictionary:
            return reject("invalid_role_requirements")
        var score := 0.0
        var weights := 0.0
        var notes: Array[String] = []
        for trait_key in preferences:
            var req: Variant = preferences[trait_key]
            if not req is Dictionary or not m["traits"].has(trait_key) or not unit(req.get("ideal", null)) or not number(req.get("weight", null)) or float(req["weight"]) <= 0.0:
                return reject("invalid_role_preference")
            var distance := absf(float(m["traits"][trait_key]) - float(req["ideal"]))
            score += (1.0 - distance) * float(req["weight"])
            weights += float(req["weight"])
            if distance >= 0.35:
                notes.append("tradeoff:" + str(trait_key))
        var possible := true
        for trait_key in hard_limits:
            if not m["traits"].has(trait_key) or not unit(hard_limits[trait_key]):
                return reject("invalid_hard_limit")
            if float(m["traits"][trait_key]) < float(hard_limits[trait_key]):
                possible = false
                notes.append("structural_limit:" + str(trait_key))
        var normalized := score / weights if weights > 0.0 else 0.5
        resolved[role_id] = m
        suitability[role_id] = {"material_id": m["id"], "score": normalized, "possible": possible, "notes": notes}
        score_sum += normalized
        feasible = feasible and possible
    if bindings.size() != resolved.size():
        return reject("unknown_role_binding")
    var quality: Variant = process.get("quality", 0.5)
    if not unit(quality):
        return reject("invalid_process_quality")
    var result: Dictionary = {}
    for name in formulas:
        if not valid_trait(str(name)) or not formulas[name] is Dictionary:
            return reject("invalid_stat_formula")
        var f: Dictionary = formulas[name]
        var terms: Variant = f.get("terms", null)
        var base: Variant = f.get("base", null)
        var span: Variant = f.get("span", null)
        var suitability_weight: Variant = f.get("suitability_weight", 0.0)
        var process_weight: Variant = f.get("process_weight", 0.0)
        if not terms is Array or terms.is_empty() or not number(base) or not number(span) or not unit(suitability_weight) or not unit(process_weight):
            return reject("invalid_stat_formula")
        if absf(float(base)) > 1000000.0 or absf(float(span)) > 1000000.0:
            return reject("stat_range_too_large")
        var sum_value := 0.0
        var sum_weight := 0.0
        for term in terms:
            if not term is Dictionary:
                return reject("invalid_stat_term")
            var role_id := str(term.get("role", ""))
            var trait_key := str(term.get("trait", ""))
            var weight: Variant = term.get("weight", null)
            if not resolved.has(role_id) or not resolved[role_id]["traits"].has(trait_key) or not number(weight) or float(weight) <= 0.0:
                return reject("invalid_stat_term")
            var value := float(resolved[role_id]["traits"][trait_key])
            if bool(term.get("inverse", false)):
                value = 1.0 - value
            sum_value += value * float(weight)
            sum_weight += float(weight)
        sum_value += (score_sum / float(resolved.size())) * float(suitability_weight) + float(quality) * float(process_weight)
        sum_weight += float(suitability_weight) + float(process_weight)
        result[name] = snappedf(float(base) + float(span) * sum_value / sum_weight, 0.001)
    var visuals: Dictionary = {}
    for role_id in resolved:
        visuals[role_id] = {"material_id": resolved[role_id]["id"], "visual": resolved[role_id].get("visual", {}).duplicate(true)}
    return {"ok": true, "status": "preview_only", "ruleset_version": RULESET_VERSION, "blueprint_id": blueprint["id"],
        "possible": feasible, "stats": result, "roles": suitability, "visual_bindings": visuals}

## Knowledge is a player-owned observation, never the true material record.
## Unknown properties and names must not leak into UI previews.
static func knowledge_view(material: Dictionary, observation: Dictionary) -> Dictionary:
    if not material_valid(material):
        return reject("invalid_material")
    var readings: Variant = observation.get("observations", {})
    if not readings is Dictionary:
        return reject("invalid_knowledge")
    var visible: Dictionary = {}
    for trait_key in readings:
        if not material["traits"].has(trait_key) or not readings[trait_key] is Dictionary:
            return reject("invalid_knowledge_trait")
        var interval: Dictionary = readings[trait_key]
        if not unit(interval.get("low", null)) or not unit(interval.get("high", null)) or float(interval["low"]) > float(interval["high"]):
            return reject("invalid_knowledge_interval")
        visible[trait_key] = interval.duplicate(true)
    var recognized := bool(observation.get("recognized", false))
    return {"ok": true, "label": material["id"] if recognized else "unknown_material",
        "recognized": recognized, "known_traits": visible}

## Schema-local fixed geometry. The PLAYER may bind materials to named roles,
## but cannot edit edge profile, handle length, mass distribution, silhouette
## or sprite/mask assignments. Every archetype is a distinct trusted blueprint.
## All physical values are normalized gameplay indices (NOT SI units).
## Region -> role connections also tell a future mask-aware GUI what to click.
## No crafting, inventory debit, item ID minting, save writes, or UI edits.
static func evaluate_fixed_tool(blueprint: Dictionary, bindings: Dictionary, process: Dictionary = {}) -> Dictionary:
    # The UI may only request a process quality preview. It cannot override
    # blueprint geometry, including by passing geometry through process.
    for key in process:
        if key != "quality":
            return reject("fixed_geometry_override_denied")
    var basic: Dictionary = evaluate_tool(blueprint, bindings, process)
    if not bool(basic.get("ok", false)):
        return basic
    var shape: Variant = blueprint.get("geometry", null)
    if not shape is Dictionary or not shape.get("schema_version", null) is int or int(shape["schema_version"]) != 1:
        return reject("invalid_fixed_geometry")
    var sprite := str(shape.get("sprite_id", ""))
    var mask := str(shape.get("mask_id", ""))
    if not valid_id(sprite) or not valid_id(mask):
        return reject("invalid_geometry_visual_ids")
    var regions: Variant = shape.get("regions", null)
    var dynamics: Variant = shape.get("dynamics", null)
    if not regions is Array or regions.is_empty() or regions.size() > 16 or not dynamics is Dictionary:
        return reject("invalid_geometry_parts")
    # Constants of the SCHEMA, not per-player parameters.
    var constants: Array = ["free_swing_rate", "inertia_penalty", "edge_factor", "impact_factor", "stress_factor"]
    for field in constants:
        if not number(dynamics.get(field, null)):
            return reject("invalid_geometry_dynamics")
    var rate := float(dynamics["free_swing_rate"])
    var penalty := float(dynamics["inertia_penalty"])
    var edge_factor := float(dynamics["edge_factor"])
    var impact_factor := float(dynamics["impact_factor"])
    var stress_factor := float(dynamics["stress_factor"])
    if rate <= 0.0 or rate > 20.0 or penalty < 0.0 or penalty > 50.0 \
            or edge_factor <= 0.0 or edge_factor > 5.0 \
            or impact_factor <= 0.0 or impact_factor > 5.0 \
            or stress_factor < 0.0 or stress_factor > 5.0:
        return reject("geometry_dynamics_out_of_range")
    var edge_role := str(dynamics.get("edge_role", ""))
    if not bindings.has(edge_role) or not bindings[edge_role] is Dictionary:
        return reject("missing_working_edge")
    var edge_material: Dictionary = bindings[edge_role]
    if not edge_material["traits"].has("hardness") or not edge_material["traits"].has("toughness"):
        return reject("missing_edge_traits")
    var critical: Variant = dynamics.get("critical_roles", null)
    if not critical is Array or critical.is_empty():
        return reject("missing_critical_roles")
    var seen_regions: Dictionary = {}
    var seen_roles: Dictionary = {}
    var total_mass := 0.0
    var weighted_radius := 0.0
    var inertia := 0.0
    var visual_regions: Array = []
    for part in regions:
        if not part is Dictionary:
            return reject("invalid_geometry_region")
        var region_id := str(part.get("id", ""))
        var role_id := str(part.get("role", ""))
        if not valid_trait(region_id) or seen_regions.has(region_id) or not bindings.has(role_id):
            return reject("invalid_geometry_region_mapping")
        var volume: Variant = part.get("volume", null)
        var radius: Variant = part.get("radius", null)
        var spread: Variant = part.get("spread", null)
        if not number(volume) or not number(radius) or not number(spread):
            return reject("invalid_geometry_dimensions")
        if float(volume) <= 0.0 or float(volume) > 10.0 or float(radius) < 0.0 \
                or float(radius) > 3.0 or float(spread) < 0.0 or float(spread) > 3.0:
            return reject("geometry_dimensions_out_of_range")
        var selected: Dictionary = bindings[role_id]
        if not selected["traits"].has("density") or not unit(selected["traits"]["density"]):
            return reject("missing_density_trait")
        # Normalize density to a nonzero relative mass factor (not kilograms).
        var part_mass := float(volume) * (0.25 + 0.75 * float(selected["traits"]["density"]))
        var distance := float(radius)
        total_mass += part_mass
        weighted_radius += part_mass * distance
        inertia += part_mass * (distance * distance + float(spread) * float(spread) / 12.0)
        seen_regions[region_id] = true
        seen_roles[role_id] = true
        visual_regions.append({"region_id": region_id, "role": role_id})
    if seen_roles.size() != bindings.size() or total_mass <= 0.0 or inertia <= 0.0:
        return reject("geometry_role_coverage_invalid")
    var weakest := 1.0
    for role_id in critical:
        if not role_id is String or not basic["roles"].has(role_id):
            return reject("invalid_critical_role")
        weakest = minf(weakest, float(basic["roles"][role_id]["score"]))
    var center := weighted_radius / total_mass
    var swing_rate := rate / sqrt(1.0 + penalty * inertia)
    var impact_energy := 0.5 * inertia * swing_rate * swing_rate * impact_factor
    var edge_hardness := float(edge_material["traits"]["hardness"])
    var edge_toughness := float(edge_material["traits"]["toughness"])
    var cutting_effect := impact_energy * edge_factor * (0.2 + 0.8 * edge_hardness) \
        * (0.7 + 0.3 * edge_toughness)
    var quality := float(process.get("quality", 0.5))
    var structural_reliability := clampf(weakest * (0.7 + 0.3 * quality) \
        / (1.0 + impact_energy * stress_factor), 0.0, 1.0)
    var response: Dictionary = basic.duplicate(true)
    response["fixed_visual"] = {"sprite_id": sprite, "mask_id": mask, "regions": visual_regions}
    response["physical_stats"] = {
        "mass_index": snappedf(total_mass, 0.0001),
        "center_of_mass": snappedf(center, 0.0001),
        "rotational_inertia": snappedf(inertia, 0.0001),
        "swing_rate": snappedf(swing_rate, 0.0001),
        "impact_energy": snappedf(impact_energy, 0.0001),
        "cutting_effect": snappedf(cutting_effect, 0.0001),
        "structural_reliability": snappedf(structural_reliability, 0.0001)
    }
    return response
