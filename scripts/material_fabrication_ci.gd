extends SceneTree
const Fabrication = preload("res://scripts/material_fabrication.gd")
var checks := 0
var failed := false
func require(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failed = true
        push_error("TAMU_MATERIAL_FABRICATION_FAILED " + label)

func mat(id: String, hardness: float, toughness: float, density: float, workability: float) -> Dictionary:
    return {"schema_version": 1, "id": id, "visual": {"family": "forged"},
        "traits": {"hardness": hardness, "toughness": toughness,
            "density": density, "workability": workability}}

func _initialize() -> void:
    var iron := mat("demo:iron", 0.65, 0.82, 0.77, 0.78)
    var copper := mat("demo:copper", 0.37, 0.58, 0.86, 0.91)
    var brittle := mat("demo:glassstone", 0.94, 0.12, 0.55, 0.22)
    var registry := {"demo:iron": iron, "demo:copper": copper, "demo:glassstone": brittle}
    require(Fabrication.material_valid(iron), "material_schema")
    var corrupt := iron.duplicate(true)
    corrupt["traits"]["hardness"] = NAN
    require(not Fabrication.material_valid(corrupt), "nan_rejected")
    var inputs := [{"material_id": "demo:iron", "parts": 7}, {"material_id": "demo:copper", "parts": 3}]
    var recipe := {"ruleset_version": 1, "required_station": "core:advanced_furnace", "min_heat": 0.65,
        "interactions": [{"a": "demo:iron", "b": "demo:copper", "trait": "toughness", "delta": 0.09}]}
    var furnace := {"station_tags": ["core:advanced_furnace"], "heat": 0.9, "quality": 0.6}
    require(not Fabrication.calculate_alloy(inputs, registry, {}, recipe).ok, "furnace_required")
    require(not Fabrication.calculate_alloy(inputs, registry,
        {"station_tags": ["core:advanced_furnace"], "heat": 0.4, "quality": 0.6}, recipe).ok, "insufficient_heat")
    var a := Fabrication.calculate_alloy(inputs, registry, furnace, recipe)
    require(a.ok, "alloy_valid")
    var b := Fabrication.calculate_alloy([inputs[1], inputs[0]], registry, furnace, recipe)
    require(b.ok and b.fingerprint == a.fingerprint, "order_invariant")
    var c := Fabrication.calculate_alloy([{"material_id": "demo:copper", "parts": 30},
        {"material_id": "demo:iron", "parts": 70}], registry, furnace, recipe)
    require(c.ok and c.fingerprint == a.fingerprint, "ratio_invariant")
    require(a.material.traits.toughness > 0.75, "alloy_synergy")
    require(not Fabrication.calculate_alloy([inputs[0], inputs[0]], registry, furnace, recipe).ok, "duplicate_reject")
    var blueprint := {"id": "demo:axe", "ruleset_version": 1,
        "roles": [{"id": "edge", "preferences": {
            "hardness": {"ideal": 0.9, "weight": 1.0},
            "toughness": {"ideal": 0.7, "weight": 1.0}}},
            {"id": "handle", "preferences": {"density": {"ideal": 0.25, "weight": 1.0}}}],
        "stats": {
            "cutting": {"base": 8.0, "span": 25.0, "terms": [
                {"role": "edge", "trait": "hardness", "weight": 1.0}]},
            "durability": {"base": 15.0, "span": 75.0, "terms": [
                {"role": "edge", "trait": "toughness", "weight": 0.7},
                {"role": "handle", "trait": "workability", "weight": 0.3}]},
            "speed": {"base": 0.5, "span": 1.5, "terms": [
                {"role": "edge", "trait": "density", "weight": 0.6, "inverse": true},
                {"role": "handle", "trait": "density", "weight": 0.4, "inverse": true}]}}}
    var t1 := Fabrication.evaluate_tool(blueprint, {"edge": iron, "handle": copper})
    var t2 := Fabrication.evaluate_tool(blueprint, {"edge": brittle, "handle": copper})
    require(t1.ok and t2.ok and t1.possible and t2.possible, "not_material_name_locked")
    require(t2.stats.cutting > t1.stats.cutting, "brittle_cuts_more")
    require(t2.stats.durability < t1.stats.durability, "brittle_breaks_faster")
    var strict := blueprint.duplicate(true)
    strict["roles"][0]["hard_limits"] = {"toughness": 0.15}
    require(not Fabrication.evaluate_tool(strict, {"edge": brittle, "handle": copper}).possible, "explicit_hard_limit")
    require(not Fabrication.evaluate_tool(blueprint, {"edge": iron, "handle": {}}).ok, "unknown_material_rejected")
    require(Fabrication.evaluate_tool(blueprint, {"edge": a.material, "handle": copper}).ok, "alloy_as_tool_part")
    var unknown := Fabrication.knowledge_view(iron, {"recognized": false,
        "observations": {"hardness": {"low": 0.4, "high": 0.8}}})
    require(unknown.ok and unknown.label == "unknown_material" and unknown.known_traits.size() == 1
        and not unknown.has("traits"), "knowledge_never_leaks_truth")

    # Distinct axe SCHEMAS, not player-adjusted handle/edge geometry.
    # Fixture dimensions are examples, not canonical content or final balance.
    var hatchet := blueprint.duplicate(true)
    hatchet["id"] = "demo:hatchet"
    hatchet["geometry"] = {
        "schema_version": 1, "sprite_id": "demo:hatchet_sprite", "mask_id": "demo:hatchet_mask",
        "regions": [
            {"id": "cutting_edge", "role": "edge", "volume": 0.20, "radius": 0.63, "spread": 0.10},
            {"id": "shaft", "role": "handle", "volume": 0.50, "radius": 0.25, "spread": 0.15}],
        "dynamics": {"edge_role": "edge", "critical_roles": ["edge", "handle"],
            "free_swing_rate": 4.8, "inertia_penalty": 2.0,
            "edge_factor": 1.0, "impact_factor": 1.0, "stress_factor": 0.04}}
    var felling := hatchet.duplicate(true)
    felling["id"] = "demo:felling_axe"
    felling["geometry"]["sprite_id"] = "demo:felling_sprite"
    felling["geometry"]["mask_id"] = "demo:felling_mask"
    felling["geometry"]["regions"][0]["volume"] = 0.75
    felling["geometry"]["regions"][0]["radius"] = 0.92
    felling["geometry"]["regions"][0]["spread"] = 0.17
    felling["geometry"]["regions"][1]["volume"] = 0.75
    felling["geometry"]["regions"][1]["radius"] = 0.35
    felling["geometry"]["dynamics"]["edge_factor"] = 1.2
    var bind := {"edge": iron, "handle": copper}
    var hatchet_result := Fabrication.evaluate_fixed_tool(hatchet, bind)
    var felling_result := Fabrication.evaluate_fixed_tool(felling, bind)
    require(hatchet_result.ok and felling_result.ok, "fixed_tool_axe_variants")
    require(felling_result.physical_stats.mass_index > hatchet_result.physical_stats.mass_index, "fixed_shape_mass")
    require(felling_result.physical_stats.rotational_inertia > hatchet_result.physical_stats.rotational_inertia, "fixed_shape_inertia")
    require(felling_result.physical_stats.swing_rate < hatchet_result.physical_stats.swing_rate, "fixed_shape_speed")
    require(felling_result.physical_stats.impact_energy > hatchet_result.physical_stats.impact_energy, "fixed_shape_impact")
    require(felling_result.physical_stats.cutting_effect > hatchet_result.physical_stats.cutting_effect, "fixed_shape_cutting")
    require(hatchet_result.fixed_visual.sprite_id == "demo:hatchet_sprite", "fixed_sprite_selection")
    require(felling_result.fixed_visual.mask_id == "demo:felling_mask", "fixed_mask_selection")
    require(hatchet_result.physical_stats == Fabrication.evaluate_fixed_tool(hatchet, bind).physical_stats, "deterministic_fixed_geometry")
    require(not Fabrication.evaluate_fixed_tool(hatchet, bind, {"geometry": {"head_length": 99.0}}).ok, "shape_override_rejected")
    require(not Fabrication.evaluate_fixed_tool(hatchet, bind, {"quality": 0.5, "head_length": 2.0}).ok, "length_override_rejected")
    var unsafe := hatchet.duplicate(true)
    unsafe["geometry"]["regions"][0]["volume"] = -1.0
    require(not Fabrication.evaluate_fixed_tool(unsafe, bind).ok, "invalid_volume_rejected")
    unsafe = hatchet.duplicate(true)
    unsafe["geometry"]["regions"][1]["role"] = "missing_part"
    require(not Fabrication.evaluate_fixed_tool(unsafe, bind).ok, "invalid_region_binding_rejected")
    var heavy := mat("demo:heavy", 0.65, 0.82, 0.95, 0.78)
    var light := mat("demo:light", 0.65, 0.82, 0.12, 0.78)
    var heavier := Fabrication.evaluate_fixed_tool(hatchet, {"edge": heavy, "handle": copper})
    var lighter := Fabrication.evaluate_fixed_tool(hatchet, {"edge": light, "handle": copper})
    require(heavier.ok and lighter.ok and heavier.physical_stats.mass_index > lighter.physical_stats.mass_index, "density_affects_mass")
    require(heavier.physical_stats.swing_rate < lighter.physical_stats.swing_rate, "density_affects_swing")
    var glass := Fabrication.evaluate_fixed_tool(hatchet, {"edge": brittle, "handle": copper})
    require(glass.ok and glass.physical_stats.cutting_effect > hatchet_result.physical_stats.cutting_effect, "brittle_can_cut_more")
    require(glass.physical_stats.structural_reliability < hatchet_result.physical_stats.structural_reliability, "brittle_is_weakest_link")
    var alloy_head := Fabrication.evaluate_fixed_tool(hatchet, {"edge": a.material, "handle": copper})
    require(alloy_head.ok and alloy_head.visual_bindings.edge.material_id == a.material.id, "alloy_material_binding")
    if failed:
        quit(1)
    else:
        print("TAMU_MATERIAL_FABRICATION_OK checks=", checks)
        quit(0)
