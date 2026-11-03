"""R2 map plan: old pilot identity, global world, deterministic geography and fail-closed routes."""
import copy
import json
import math
import subprocess
import sys
import unittest
from pathlib import Path

from jsonschema import ValidationError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from validate_worldbuild_contract import ContractError
from validate_worldbuild_map_v2 import (
    MAP_PATH, canonical_digest, resolve_world_position, validate_map,
)


class WorldMapRound2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = json.loads(MAP_PATH.read_text(encoding="utf-8"))
        cls.source_name = cls.doc["authored_maps"][0]["path"]
        cls.source = json.loads((ROOT / cls.source_name).read_text(encoding="utf-8"))
        cls.pilot = json.loads((ROOT / "data/worldbuild/fisilti_ormani.v1.json").read_text(encoding="utf-8"))

    def fails(self, change, overrides=None):
        doc = copy.deepcopy(self.doc)
        change(doc)
        with self.assertRaises((ContractError, ValidationError, ValueError, TypeError)):
            validate_map(doc, overrides=overrides)

    def test_scope_and_global_bounds(self):
        index = validate_map(self.doc)
        self.assertEqual(self.doc["format"], "osman-worldmap-v2")
        self.assertEqual(self.doc["generator_version"], 1)
        self.assertEqual(self.doc["seed"], 20261018)
        b = self.doc["bounds"]
        self.assertEqual((b["max_x"] - b["min_x"], b["max_y"] - b["min_y"]), (32768, 32768))
        self.assertEqual(len(self.doc["areas"]), 4)
        self.assertEqual(len(index["regions"]), 6)
        self.assertEqual(len(index["connectors"]), 6)
        self.assertEqual(len(index["sites"]), 7)
        self.assertLess(index["authored_fraction"], .10)
        self.assertGreater(index["authored_fraction"], 0)
        self.assertEqual(self.doc["generation"]["target_horizon"], "world_maturity")
        self.assertEqual((self.doc["generation"]["authored_target_min"],
                          self.doc["generation"]["authored_target_max"]), (.10, .20))
        self.assertEqual(self.doc["generation"]["map_activation"], "opt_in_future_adapter")
        self.assertEqual(self.doc["bounds"]["enforcement"], "design_only")

    def test_preserve_v1_pilot_ids_and_geometry(self):
        self.assertEqual(self.source["map_id"], self.pilot["map_id"])
        self.assertEqual(self.source["seed"], self.pilot["seed"])
        source_regions = {r["id"]: r for r in self.source["regions"]}
        for region in self.pilot["regions"]:
            self.assertEqual(source_regions[region["id"]], region)
        source_connectors = {c["id"]: c for c in self.source["connectors"]}
        for connector in self.pilot["connectors"]:
            self.assertEqual(source_connectors[connector["id"]], connector)
        source_features = {f["id"]: f for f in self.source["features"]}
        for feature in self.pilot["features"]:
            r2_feature = source_features[feature["id"]]
            self.assertEqual((r2_feature["kind"], r2_feature["width"], r2_feature["intent_only"]),
                             (feature["kind"], feature["width"], feature["intent_only"]))
            if feature["id"] == "feature:fisilti-dere-izi":
                # H explicitly approved river rerouting; the original pilot file
                # stays immutable while the v2 child source crosses (704,128).
                self.assertEqual(r2_feature["points"][:2], feature["points"][:2])
                self.assertEqual(r2_feature["points"][-1], feature["points"][-1])
                self.assertEqual(r2_feature["points"][2], [704, 128])
                self.assertEqual(len(r2_feature["points"]), len(feature["points"]) + 1)
            else:
                self.assertEqual(r2_feature["points"][:len(feature["points"])], feature["points"])
        self.assertEqual(len(self.source["regions"])-len(self.pilot["regions"]), 3)

    def test_global_fallback_and_boundary_tiebreak(self):
        i = validate_map(self.doc)
        self.assertEqual(resolve_world_position(self.doc, i, 64, 128),
                         {"source": "authored", "region_id": "region:fisilti-giris"})
        self.assertEqual(resolve_world_position(self.doc, i, 256, 128)["region_id"], "region:fisilti-giris")
        self.assertEqual(resolve_world_position(self.doc, i, 512, 128)["region_id"], "region:fisilti-dere")
        self.assertEqual(resolve_world_position(self.doc, i, 327, 267)["source"], "authored")
        self.assertEqual(resolve_world_position(self.doc, i, 12000, 12000),
                         {"source": "generator-v1", "region_id": None})
        self.assertEqual(resolve_world_position(self.doc, i, -4096, -4096)["source"], "generator-v1")
        for xy in ((28672, 128), (-4097, 0), (128, 28672)):
            self.assertEqual(resolve_world_position(self.doc, i, *xy)["source"], "out_of_bounds")
        with self.assertRaises(ContractError):
            resolve_world_position(self.doc, i, math.inf, 0)

    def test_main_route_branch_and_cycle(self):
        idx = validate_map(self.doc)
        routes = {r["id"]: r for r in self.doc["routes"]}
        self.assertEqual({r["kind"] for r in routes.values()}, {"main", "optional"})
        self.assertEqual(routes["route:fisilti-ana"]["sites"][0], "site:fisilti-uyanis")
        self.assertEqual(routes["route:fisilti-ana"]["sites"][-1], "site:fisilti-kayalik-cikis")
        self.assertEqual(idx["sites"]["site:fisilti-kalinti"]["role"], "ruin")
        edges = {frozenset(c["regions"]) for c in self.source["connectors"]}
        self.assertTrue({"region:fisilti-koruluk", "region:fisilti-dere"} in [set(e) for e in edges])
        self.assertTrue({"region:fisilti-dere", "region:fisilti-kuzey-iz"} in [set(e) for e in edges])
        self.assertTrue({"region:fisilti-koruluk", "region:fisilti-kuzey-iz"} in [set(e) for e in edges])
        self.assertTrue(all(s["discover_step"] in (0,1,2,3) for s in self.doc["sites"]))

    def test_canonical_digest_array_order_invariant(self):
        digest = canonical_digest(self.doc)
        self.assertEqual(len(digest), 64)
        doc = copy.deepcopy(self.doc)
        for field in ("areas", "frontiers", "authored_maps", "sites", "routes"):
            doc[field].reverse()
        authored = copy.deepcopy(self.source)
        for field in ("regions", "connectors", "features"):
            authored[field].reverse()
        self.assertEqual(digest, canonical_digest(doc, overrides={self.source_name: authored}))
        doc["seed"] += 1
        with self.assertRaises(ContractError):
            validate_map(doc)

    def test_reject_global_and_area_violations(self):
        self.fails(lambda d: d["bounds"].update(max_x=28673))
        self.fails(lambda d: d["areas"].append(copy.deepcopy(d["areas"][0])))
        self.fails(lambda d: d["areas"][0]["polygon"][0].__setitem__(0,-4000))
        self.fails(lambda d: d["frontiers"][0].update(edge="north"))
        self.fails(lambda d: d["generation"].update(authored_target_min=.30))
        self.fails(lambda d: d["generation"].update(map_activation="automatic"))
        self.fails(lambda d: d.update(generator_version=2))
        self.fails(lambda d: d.update(projection="perspective"))
        self.fails(lambda d: d["authored_maps"][0].update(path="../unsafe.v1.json"))
        self.fails(lambda d: d["authored_maps"][0].update(area_id="area:missing"))
        self.fails(lambda d: d["authored_maps"][0].update(id="worldmap:wrong"))

    def test_reject_site_and_route_violations(self):
        self.fails(lambda d: d["sites"].append(copy.deepcopy(d["sites"][0])))
        self.fails(lambda d: d["sites"][0].update(anchor=[10000,10000]))
        self.fails(lambda d: d["sites"][2].update(anchor=[310,430]))
        self.fails(lambda d: d["routes"][0].update(feature_id="feature:fisilti-dere-izi"))
        self.fails(lambda d: d["routes"][0].update(sites=list(reversed(d["routes"][0]["sites"]))))
        self.fails(lambda d: d["routes"][1]["sites"].append("site:does-not-exist"))
        self.fails(lambda d: d["routes"].append(copy.deepcopy(d["routes"][0])))
        self.fails(lambda d: d["routes"][0].update(kind="optional"))

    def test_reject_broken_authored_source(self):
        authored = copy.deepcopy(self.source)
        authored["seed"] += 1
        self.fails(lambda d: None, overrides={self.source_name: authored})
        authored = copy.deepcopy(self.source)
        authored["connectors"][2]["anchor"] = [320, 267]
        self.fails(lambda d: None, overrides={self.source_name: authored})
        authored = copy.deepcopy(self.source)
        authored["regions"][3]["polygon"][2] = [400, 160]
        self.fails(lambda d: None, overrides={self.source_name: authored})
        authored = copy.deepcopy(self.source)
        authored["features"][0]["points"].append([50000,50000])
        self.fails(lambda d: None, overrides={self.source_name: authored})

    def test_cli_validator_is_really_executed(self):
        p = subprocess.run([sys.executable, str(ROOT / "scripts/validate_worldbuild_map_v2.py"),
                            str(MAP_PATH)], cwd=str(ROOT), text=True, capture_output=True, timeout=20)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("WORLDMAP_V2_OK worldmap:osman-overworld", p.stdout)
        self.assertIn("sha256=", p.stdout)


if __name__ == "__main__":
    unittest.main()
