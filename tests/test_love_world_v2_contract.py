"""Stage 6 2D schema-contract proof; no game-save file writes occur."""
import copy
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator, ValidationError

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT / "schemas/love-world-v2.schema.json").read_text())
TEMPLATE = json.loads((ROOT / "data/templates/empty_love_world_v2.json").read_text())
OLD_SCHEMA = json.loads((ROOT / "schemas/world.json").read_text())
OLD = json.loads((ROOT / "data/templates/empty_world.v1.json").read_text())
CAT = ROOT / "data/catalog"

def semantic(snapshot):
    """Additional cross-field checks beyond JSON Schema."""
    Draft202012Validator(SCHEMA).validate(snapshot)
    if (snapshot["seed"] != snapshot["generated_object_delta"]["seed"]
        or snapshot["generator_version"] != snapshot["generated_object_delta"]["generator_version"]
        or snapshot["catalog_version"] != snapshot["player"]["inventory"]["catalog_version"]):
        raise ValueError("snapshot version/seed mismatch")
    inventory = snapshot["player"]["inventory"]
    item_defs = {}
    manifest = json.loads((CAT / "manifest.json").read_text())
    for path in manifest["definitions"]:
        entry = json.loads((CAT / path).read_text())
        if entry["kind"] in ("item", "structure"):
            item_defs[entry["id"]] = entry
    seen = set()
    for s in inventory["slots"]:
        if s["slot"] in seen or s["slot"] > inventory["capacity"]:
            raise ValueError("duplicate/out-of-range inventory slot")
        seen.add(s["slot"])
        d = item_defs.get(s["def_id"])
        if d is None:
            raise ValueError("unknown catalog item in save")
        limit = d["components"].get("core:stackable", {}).get("max_count", 1)
        if s["count"] > limit:
            raise ValueError("invalid stack size")
    for k, p in snapshot["placed_instances"].items():
        if k != p["id"] or p["revision"] > snapshot["world_revision"]:
            raise ValueError("placed ID/revision conflict")
        d = item_defs.get(p["def_id"])
        if not d or "core:placeable" not in d["components"]:
            raise ValueError("invalid placed definition")
    if snapshot["journal_sequence"] < snapshot["world_revision"]:
        raise ValueError("journal behind snapshot revision")
    return True

class SaveContract(unittest.TestCase):
    def test_valid_schemas_and_template(self):
        Draft202012Validator.check_schema(SCHEMA)
        Draft202012Validator.check_schema(OLD_SCHEMA)
        self.assertTrue(semantic(TEMPLATE))
        self.assertEqual(TEMPLATE["save_version"], 2)

    def test_old_voxel_template_remains_distinct(self):
        Draft202012Validator(OLD_SCHEMA).validate(OLD)
        with self.assertRaises(ValidationError):
            semantic(OLD)
        self.assertEqual(OLD["save_version"], 1)

    def test_invalid_mutations_rejected(self):
        cases = [
            ("seed mismatch", lambda x:x["generated_object_delta"].update(seed=10)),
            ("catalog mismatch", lambda x:x["player"]["inventory"].update(catalog_version=2)),
            ("unknown item", lambda x:x["player"]["inventory"]["slots"].append(
                {"slot":1,"def_id":"core:phantom","count":1})),
            ("wrong UUID", lambda x:x.update(world_id="arbitrary")),
            ("negative revision", lambda x:x.update(world_revision=-1)),
            ("wrong format", lambda x:x.update(format="godot-voxel")),
            ("schema drift", lambda x:x.update(generator_version=2)),
        ]
        for label,edit in cases:
            with self.subTest(label=label):
                x = copy.deepcopy(TEMPLATE)
                edit(x)
                with self.assertRaises((ValidationError, ValueError)):
                    semantic(x)

    def test_slot_and_placement_invariants(self):
        x=copy.deepcopy(TEMPLATE)
        x["player"]["inventory"]["slots"]=[
            {"slot":1,"def_id":"core:wood_log","count":2},
            {"slot":1,"def_id":"core:stone","count":3}
        ]
        with self.assertRaises(ValueError): semantic(x)
        x=copy.deepcopy(TEMPLATE)
        x["player"]["inventory"]["slots"]=[
            {"slot":1,"def_id":"core:wood_log","count":100}
        ]
        with self.assertRaises(ValueError): semantic(x)
        x=copy.deepcopy(TEMPLATE)
        ident="12345678-1234-4abc-8abc-123456789abe"
        x["placed_instances"][ident]={
            "id":ident,"def_id":"core:workbench","x":0,"y":0,
            "rotation":0,"owner_id":"player:local","command_id":"place:1","revision":1
        }
        with self.assertRaises(ValueError): semantic(x)
        x["world_revision"]=1
        x["journal_sequence"]=1
        self.assertTrue(semantic(x))

if __name__=="__main__":
    unittest.main()
