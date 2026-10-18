"""Worldbuild region/connector geometry, determinism and negative tests."""
import copy
import json
import math
import sys
import unittest
from pathlib import Path

from jsonschema import ValidationError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from validate_worldbuild_contract import (
    PILOT_PATH, SCHEMA_PATH, ContractError, canonical_digest,
    location, resolve_region, validate_document,
)


class WorldbuildContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pilot = json.loads(PILOT_PATH.read_text(encoding="utf-8"))

    def mutate_fails(self, edit):
        document = copy.deepcopy(self.pilot)
        edit(document)
        with self.assertRaises((ContractError, ValidationError, ValueError, TypeError)):
            validate_document(document)

    def test_pilot_schema_and_regions(self):
        self.assertTrue(SCHEMA_PATH.is_file())
        self.assertTrue(validate_document(self.pilot))
        self.assertEqual(self.pilot["generator_version"], 1)
        self.assertEqual(len(self.pilot["regions"]), 3)
        self.assertEqual(len(self.pilot["connectors"]), 2)
        self.assertEqual(resolve_region(self.pilot, 100, 128), "region:fisilti-giris")
        self.assertEqual(resolve_region(self.pilot, 400, 128), "region:fisilti-koruluk")
        self.assertEqual(resolve_region(self.pilot, 650, 128), "region:fisilti-dere")
        self.assertIsNone(resolve_region(self.pilot, -200, 128))
        self.assertIsNone(resolve_region(self.pilot, 800, 128))

    def test_order_invariance_and_seed_identity(self):
        original = canonical_digest(self.pilot)
        clone = copy.deepcopy(self.pilot)
        for name in ("regions", "connectors", "features"):
            clone[name].reverse()
        self.assertEqual(canonical_digest(clone), original)
        for p in ([256, 128], [512, 128], [0, 0], [768, 256]):
            self.assertEqual(resolve_region(self.pilot, *p), resolve_region(clone, *p))
        clone["seed"] += 1
        self.assertNotEqual(canonical_digest(clone), original)
        self.assertEqual({r["id"] for r in clone["regions"]},
                         {r["id"] for r in self.pilot["regions"]})

    def test_shared_seams_and_connector_stability(self):
        doc = self.pilot
        self.assertEqual(resolve_region(doc, 256, 128), "region:fisilti-giris")
        self.assertEqual(resolve_region(doc, 512, 128), "region:fisilti-dere")
        for c in doc["connectors"]:
            self.assertEqual(c["regions"], sorted(c["regions"]))
            self.assertEqual(c["kind"], "path")
            self.assertEqual(c["width"], 18)
        before = [c["id"] for c in doc["connectors"]]
        self.assertEqual(before, [c["id"] for c in json.loads(json.dumps(doc))["connectors"]])

    def test_malformed_regions(self):
        self.mutate_fails(lambda d: d["regions"].append(copy.deepcopy(d["regions"][0])))
        self.mutate_fails(lambda d: d["regions"][0].update(variant="dense"))
        self.mutate_fails(lambda d: d["regions"][0].update(polygon=[[0,0],[256,256],[256,0],[0,256]]))
        self.mutate_fails(lambda d: d["regions"][0].update(polygon=list(reversed(d["regions"][0]["polygon"]))))
        self.mutate_fails(lambda d: d["regions"][0].update(polygon=[[0,0],[256,0],[256,0],[0,256]]))
        self.mutate_fails(lambda d: d["regions"][0].update(polygon=[[0,0],[400,0],[400,256],[0,256]]))
        self.mutate_fails(lambda d: d["regions"][0].update(polygon=[[256,0],[512,0],[512,256],[256,256]]))

    def test_connectors_fail_closed(self):
        self.mutate_fails(lambda d: d["connectors"].append(copy.deepcopy(d["connectors"][0])))
        self.mutate_fails(lambda d: d["connectors"][0].update(anchor=[254,128]))
        self.mutate_fails(lambda d: d["connectors"][0].update(anchor=[256,2],width=18))
        self.mutate_fails(lambda d: d["connectors"][0].update(regions=["region:phantom", "region:fisilti-koruluk"]))
        self.mutate_fails(lambda d: d["connectors"][0].update(regions=list(reversed(d["connectors"][0]["regions"]))))
        self.mutate_fails(lambda d: d["connectors"][0].update(kind="water"))
        self.mutate_fails(lambda d: d["connectors"][0].update(width=float("nan")))
        self.mutate_fails(lambda d: d["connectors"][0].update(id="connector:fisilti-dere-koruluk"))

    def test_features_and_version_guards(self):
        self.mutate_fails(lambda d: d.update(generator_version=2))
        self.mutate_fails(lambda d: d.update(seed=-1))
        self.mutate_fails(lambda d: d.update(coordinate_space="screen"))
        self.mutate_fails(lambda d: d.update(save_version=2))
        self.mutate_fails(lambda d: d["features"].append(copy.deepcopy(d["features"][0])))
        self.mutate_fails(lambda d: d["features"][0].update(intent_only=False))
        self.mutate_fails(lambda d: d["features"][0].update(width=1))
        self.mutate_fails(lambda d: d["features"][0].update(points=[[64,128],[1500,128]]))
        self.mutate_fails(lambda d: d["features"][0].update(points=[[64,128],[64,128]]))
        self.mutate_fails(lambda d: d["features"][1].update(points=[[536,56],[800,62]]))
        self.mutate_fails(lambda d: d["features"][0].update(points=[[64,float("nan")],[256,128]]))
        with self.assertRaises(ContractError):
            resolve_region(self.pilot, float("nan"), 0)

    def test_no_runtime_or_save_compat_claim(self):
        self.assertNotIn("world_id", self.pilot)
        self.assertNotIn("placed_instances", self.pilot)
        self.assertTrue(all(f["intent_only"] for f in self.pilot["features"]))
        code = (ROOT / "game/love/world/liquids.lua").read_text(encoding="utf-8")
        self.assertIn("speed_multiplier=0.55", code)
        self.assertIn("immersion=0.5", code)
        field = (ROOT / "game/love/world/field.lua").read_text(encoding="utf-8")
        self.assertIn("generator_version = 1", field)


if __name__ == "__main__":
    unittest.main()
