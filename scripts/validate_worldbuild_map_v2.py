#!/usr/bin/env python3
"""Fail-closed R2 authoring-only overworld/area/site/route validator.

Generator v1, active Lua WorldQuery, LÖVE rendering and saves are untouched.
V1 authored submaps are validated by the existing strict v1 validator.
"""
import argparse
import copy
import hashlib
import json
import math
from collections import deque
from pathlib import Path

from jsonschema import Draft202012Validator
from validate_worldbuild_contract import (
    ContractError, check_polygon, location, on_segment, overlap,
    validate_document,
)

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "data/worldbuild/osman_overworld.v2.json"
SCHEMA_PATH = ROOT / "schemas/worldbuild-map-v2.schema.json"
EPS = 1e-7


def reject(message):
    raise ContractError(message)


def finite_tree(value):
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            reject("nonfinite number")
    elif isinstance(value, dict):
        for item in value.values():
            finite_tree(item)
    elif isinstance(value, list):
        for item in value:
            finite_tree(item)


def read_json(path):
    if path.stat().st_size > 2_000_000:
        reject("map document exceeds 2MB")
    with path.open(encoding="utf-8") as fh:
        return json.load(fh, parse_constant=lambda value: reject("invalid JSON constant: " + value))


def rect_of_area(area, bounds):
    points = area["polygon"]
    check_polygon(points, area["id"])
    xs, ys = {p[0] for p in points}, {p[1] for p in points}
    if len(xs) != 2 or len(ys) != 2:
        reject(area["id"] + ": area must be an axis-aligned rectangle")
    x0, x1 = sorted(xs)
    y0, y1 = sorted(ys)
    if set(map(tuple, points)) != {(x0, y0), (x1, y0), (x1, y1), (x0, y1)}:
        reject(area["id"] + ": invalid rectangle corners")
    if not (bounds["min_x"] <= x0 < x1 <= bounds["max_x"] and
            bounds["min_y"] <= y0 < y1 <= bounds["max_y"]):
        reject(area["id"] + ": outside global world bounds")
    return x0, y0, x1, y1


def area_partition(areas, bounds):
    rects = [rect_of_area(a, bounds) for a in areas]
    for index, a in enumerate(areas):
        for b in areas[index + 1:]:
            if overlap(a["polygon"], b["polygon"]):
                reject(a["id"] + " overlaps " + b["id"])
    xs = sorted({bounds["min_x"], bounds["max_x"]} |
                {x for x0, _, x1, _ in rects for x in (x0, x1)})
    ys = sorted({bounds["min_y"], bounds["max_y"]} |
                {y for _, y0, _, y1 in rects for y in (y0, y1)})
    for x0, x1 in zip(xs, xs[1:]):
        for y0, y1 in zip(ys, ys[1:]):
            x, y = (x0 + x1) / 2, (y0 + y1) / 2
            if sum(a <= x < c and b <= y < d for a, b, c, d in rects) != 1:
                reject("areas do not partition the global world")


def line_position(points, point):
    distance = 0.0
    for a, b in zip(points, points[1:]):
        if on_segment(a, b, point):
            return distance + math.dist(a, point)
        distance += math.dist(a, b)
    return None


def connected_regions(a, b, feature, connectors):
    if a == b:
        return True
    graph = {}
    for c in connectors:
        if c["kind"] != "path" or line_position(feature["points"], c["anchor"]) is None:
            continue
        left, right = c["regions"]
        graph.setdefault(left, set()).add(right)
        graph.setdefault(right, set()).add(left)
    seen, queue = {a}, deque([a])
    while queue:
        current = queue.popleft()
        for neighbor in graph.get(current, ()):
            if neighbor == b:
                return True
            if neighbor not in seen:
                seen.add(neighbor)
                queue.append(neighbor)
    return False


def validate_map(manifest, root=ROOT, overrides=None):
    """Return a validated read-only index; optional test overrides are not persisted."""
    finite_tree(manifest)
    schema = read_json(root / "schemas/worldbuild-map-v2.schema.json")
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(manifest)
    bounds = manifest["bounds"]
    width = bounds["max_x"] - bounds["min_x"]
    height = bounds["max_y"] - bounds["min_y"]
    if width <= 0 or height <= 0 or width != height:
        reject("global world bounds must be positive and square")
    if {f["edge"] for f in manifest["frontiers"]} != {"north", "south", "east", "west"}:
        reject("frontier edge missing or duplicated")
    generation = manifest["generation"]
    if generation["authored_target_min"] > generation["authored_target_max"]:
        reject("authored target range inverted")
    areas = {a["id"]: a for a in manifest["areas"]}
    if len(areas) != len(manifest["areas"]):
        reject("duplicate area ID")
    area_partition(manifest["areas"], bounds)

    region_index, feature_index, connector_index = {}, {}, {}
    map_index, authored_payloads = {}, []
    area_authored = set()
    root = Path(root).resolve()
    source_root = (root / "data/worldbuild").resolve()
    for ref in manifest["authored_maps"]:
        map_id, area_id, rel = ref["id"], ref["area_id"], ref["path"]
        if map_id in map_index:
            reject("duplicate authored map ID: " + map_id)
        if area_id not in areas:
            reject("unknown area in authored map: " + area_id)
        path = (root / rel).resolve()
        if not path.is_relative_to(source_root) or not path.is_file():
            reject("invalid authored map path: " + rel)
        authored = (overrides or {}).get(rel)
        if authored is None:
            authored = read_json(path)
        finite_tree(authored)
        validate_document(authored)
        if (authored["map_id"] != map_id or authored["seed"] != manifest["seed"] or
            authored["generator_version"] != manifest["generator_version"] or
            authored["coordinate_space"] != "world" or authored["projection"] != "iso-45"):
            reject("authored source identity, seed or generator mismatch: " + map_id)
        map_index[map_id] = authored
        area_authored.add(area_id)
        for region in authored["regions"]:
            rid = region["id"]
            if rid in region_index:
                reject("duplicate global region ID: " + rid)
            if any(location(areas[area_id]["polygon"], p) == -1 for p in region["polygon"]):
                reject(rid + ": region escapes its parent area")
            for old_region in region_index.values():
                if overlap(region["polygon"], old_region["polygon"]):
                    reject(rid + ": cross-map polygon overlap")
            region_index[rid] = region
        for feature in authored["features"]:
            if feature["id"] in feature_index:
                reject("duplicate global feature ID: " + feature["id"])
            feature_index[feature["id"]] = feature
        for connector in authored["connectors"]:
            if connector["id"] in connector_index:
                reject("duplicate global connector ID: " + connector["id"])
            connector_index[connector["id"]] = connector
        authored_payloads.append((rel, authored))
    if not area_authored:
        reject("at least one authored anchor area required")

    sites = {s["id"]: s for s in manifest["sites"]}
    if len(sites) != len(manifest["sites"]):
        reject("duplicate site ID")
    for site in sites.values():
        region = region_index.get(site["region_id"])
        if region is None or location(region["polygon"], site["anchor"]) != 1:
            reject(site["id"] + ": site not strictly inside referenced region")
    if not any(s["role"] == "spawn" for s in sites.values()):
        reject("no spawn site")

    route_ids = set()
    main_routes = 0
    for route in manifest["routes"]:
        if route["id"] in route_ids:
            reject("duplicate route ID")
        route_ids.add(route["id"])
        main_routes += route["kind"] == "main"
        feature = feature_index.get(route["feature_id"])
        if feature is None or feature["kind"] != "path":
            reject(route["id"] + ": route must reference an authored path feature")
        if len(set(route["sites"])) != len(route["sites"]):
            reject(route["id"] + ": repeated waypoint")
        waypoints = []
        for site_id in route["sites"]:
            site = sites.get(site_id)
            if not site:
                reject(route["id"] + ": missing route site: " + site_id)
            offset = line_position(feature["points"], site["anchor"])
            if offset is None:
                reject(route["id"] + ": site off route feature: " + site_id)
            if waypoints and offset <= waypoints[-1][0] + EPS:
                reject(route["id"] + ": route site order is not forward")
            if waypoints and not connected_regions(waypoints[-1][1]["region_id"], site["region_id"],
                                                  feature, connector_index.values()):
                reject(route["id"] + ": no matching connector graph path between sites")
            waypoints.append((offset, site))
        if route["kind"] == "main" and waypoints[0][1]["role"] != "spawn":
            reject(route["id"] + ": main route must start at spawn")
    if main_routes != 1:
        reject("exactly one main route required")

    total_authored = sum(abs(sum(a[0]*b[1] - b[0]*a[1]
                          for a, b in zip(r["polygon"], r["polygon"][1:] + r["polygon"][:1])))/2
                         for r in region_index.values())
    fraction = total_authored / (width * height)
    if fraction > 1 + EPS:
        reject("authored area exceeds world")
    return {"regions": region_index, "connectors": connector_index,
            "features": feature_index, "sites": sites, "maps": map_index,
            "authored_payloads": authored_payloads, "authored_fraction": fraction}


def resolve_world_position(manifest, index, x, y):
    if any(type(v) not in (float, int) or not math.isfinite(v) for v in (x, y)):
        reject("invalid world coordinate")
    bounds = manifest["bounds"]
    if not (bounds["min_x"] <= x < bounds["max_x"] and
            bounds["min_y"] <= y < bounds["max_y"]):
        return {"source": "out_of_bounds", "region_id": None}
    for region in sorted(index["regions"].values(), key=lambda r: r["id"]):
        if location(region["polygon"], [x, y]) >= 0:
            return {"source": "authored", "region_id": region["id"]}
    return {"source": "generator-v1", "region_id": None}


def canonical_digest(manifest, root=ROOT, overrides=None):
    index = validate_map(manifest, root, overrides)
    doc = copy.deepcopy(manifest)
    for field in ("areas", "authored_maps", "sites", "routes"):
        doc[field].sort(key=lambda item: item["id"])
    doc["frontiers"].sort(key=lambda item: item["edge"])
    sources = []
    for path, authored in index["authored_payloads"]:
        source = copy.deepcopy(authored)
        for field in ("regions", "connectors", "features"):
            source[field].sort(key=lambda item: item["id"])
        sources.append({"path": path, "document": source})
    sources.sort(key=lambda item: item["path"])
    raw = json.dumps({"map": doc, "authored": sources}, ensure_ascii=False,
                     sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main():
    parser = argparse.ArgumentParser(description="Validate R2 worldmap v2 authoring manifest")
    parser.add_argument("file", type=Path, nargs="?", default=MAP_PATH)
    args = parser.parse_args()
    manifest = read_json(args.file)
    index = validate_map(manifest)
    digest = canonical_digest(manifest)
    bounds = manifest["bounds"]
    print("WORLDMAP_V2_OK", manifest["map_id"],
          "size=" + str(bounds["max_x"]-bounds["min_x"]),
          "regions=" + str(len(index["regions"])),
          "sites=" + str(len(index["sites"])),
          "authored_fraction=" + format(index["authored_fraction"], ".8f"),
          "sha256=" + digest)


if __name__ == "__main__":
    main()
