"""Content-contract checks for the reboot scaffold."""
import json
import re
import unittest
from copy import deepcopy
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data" / "catalog"
SCHEMAS = ROOT / "schemas"
IDENT = re.compile(r"^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$")
KINDS = {"item", "resource", "structure", "creature", "block", "machine"}
COMPONENTS = {"core:stackable", "core:harvestable", "core:inventory", "core:craft_station", "core:placeable", "core:health", "core:growable"}

def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def validate(schema_file, data):
    schema = read(SCHEMAS / schema_file)
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema, format_checker=FormatChecker()).validate(data)

def load_catalog():
    manifest = read(CATALOG / "manifest.json")
    validate("catalog-manifest.schema.json", manifest)
    for folder, group in (("definitions", "definitions"), ("recipes", "recipes")):
        actual = {str(p.relative_to(CATALOG)) for p in (CATALOG / folder).glob("*.json")}
        expected = set(manifest[group])
        if actual != expected:
            raise ValueError(f"{group} manifest mismatch: {actual ^ expected}")
    entries = [read(CATALOG / p) for p in manifest["definitions"]]
    ids = [d["id"] for d in entries]
    if len(set(ids)) != len(ids):
        raise ValueError("duplicate definition ID")
    defs = {d["id"]: d for d in entries}
    for item in entries:
        validate("entity.json", item)
        if not IDENT.fullmatch(item["id"]) or item["kind"] not in KINDS:
            raise ValueError("bad definition ID or kind")
        if item["schema_version"] != 1 or not item["name_key"]:
            raise ValueError("invalid definition fields")
        if not set(item["components"]) <= COMPONENTS:
            raise ValueError("unknown component")
        visual = item["visual"]
        if visual.get("kind") == "primitive" and not {"shape", "color"} <= visual.keys():
            raise ValueError("incomplete primitive")
        for stack in item["components"].get("core:harvestable", {}).get("drops", []):
            check_stack(stack, defs)
    recipes = [read(CATALOG / p) for p in manifest["recipes"]]
    recipe_ids = set()
    for recipe in recipes:
        validate("recipe.json", recipe)
        if not IDENT.fullmatch(recipe["id"]) or recipe["id"] in recipe_ids:
            raise ValueError("invalid/duplicate recipe")
        recipe_ids.add(recipe["id"])
        if recipe["schema_version"] != 1 or recipe["duration_ticks"] < 1:
            raise ValueError("bad recipe version or duration")
        if not recipe["inputs"] or not recipe["outputs"]:
            raise ValueError("empty recipe")
        for stack in recipe["inputs"] + recipe["outputs"]:
            check_stack(stack, defs)
    return defs, recipes

def check_stack(stack, definitions):
    if stack.get("def_id") not in definitions:
        raise ValueError("unknown item reference")
    if type(stack.get("count")) is not int or stack["count"] < 1:
        raise ValueError("bad stack count")

class CatalogTests(unittest.TestCase):
    def test_schema_files(self):
        for filename in ("entity.json", "recipe.json", "world.json", "player.json", "network-command.json", "asset.json", "catalog-manifest.schema.json"):
            Draft202012Validator.check_schema(read(SCHEMAS / filename))
    def test_catalog_and_references(self):
        defs, recipes = load_catalog()
        self.assertIn("core:oak_tree", defs)
        self.assertGreaterEqual(len(recipes), 2)
    def test_world_template(self):
        template = read(ROOT / "data/templates/empty_world.v1.json")
        validate("world.json", template)
        self.assertEqual(template["palette"][0], "core:air")
        self.assertEqual(template["instances"], [])
    def test_negative_missing_reference(self):
        defs, _ = load_catalog()
        with self.assertRaises(ValueError):
            check_stack({"def_id": "core:missing", "count": 1}, defs)
    def test_negative_zero_stack(self):
        defs, _ = load_catalog()
        with self.assertRaises(ValueError):
            check_stack({"def_id": "core:wood_log", "count": 0}, defs)
    def test_portrait_config(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn("window/size/viewport_width=720", project)
        self.assertIn("window/size/viewport_height=1280", project)
        self.assertIn("window/handheld/orientation=1", project)

if __name__ == "__main__":
    unittest.main()
