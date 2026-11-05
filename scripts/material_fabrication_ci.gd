extends SceneTree
const Fabrication = preload("res://scripts/material_fabrication.gd")
var checks := 0
func require(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        push_error("TAMU_MATERIAL_FABRICATION_FAILED " + label)
        quit(1)

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
    print("TAMU_MATERIAL_FABRICATION_OK checks=", checks)
    quit(0)
