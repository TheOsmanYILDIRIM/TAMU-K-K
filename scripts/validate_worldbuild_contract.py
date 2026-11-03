#!/usr/bin/env python3
"""Strict, pure-Python semantic checks for the *authoring* graph.

Does not modify the game, world generator, editor, or persistent saves.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "schemas" / "worldbuild-region-v1.schema.json"
PILOT_PATH = ROOT / "data" / "worldbuild" / "fisilti_ormani.v1.json"
EPS = 1e-7
VARIANTS = {
    "meadow": {"default", "wildflower", "dry"},
    "forest": {"default", "clearing", "dense"},
    "rocky": {"default", "ridge", "gravel"},
}


class ContractError(ValueError):
    """An authored graph is unsafe or ambiguous."""


def fail(message):
    raise ContractError(message)


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def on_segment(a, b, p):
    return (abs(cross(a, b, p)) <= EPS
            and min(a[0], b[0]) - EPS <= p[0] <= max(a[0], b[0]) + EPS
            and min(a[1], b[1]) - EPS <= p[1] <= max(a[1], b[1]) + EPS)


def intersect(a, b, c, d):
    o1, o2, o3, o4 = cross(a, b, c), cross(a, b, d), cross(c, d, a), cross(c, d, b)
    if (o1 > EPS and o2 < -EPS or o1 < -EPS and o2 > EPS) and (
        o3 > EPS and o4 < -EPS or o3 < -EPS and o4 > EPS
    ):
        return True
    return (on_segment(a, b, c) or on_segment(a, b, d)
            or on_segment(c, d, a) or on_segment(c, d, b))


def proper_intersection(a, b, c, d):
    o1, o2, o3, o4 = cross(a, b, c), cross(a, b, d), cross(c, d, a), cross(c, d, b)
    return ((o1 > EPS and o2 < -EPS or o1 < -EPS and o2 > EPS)
            and (o3 > EPS and o4 < -EPS or o3 < -EPS and o4 > EPS))


def sides(poly):
    return [(poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))]


def location(poly, p):
    """1=inside, 0=boundary, -1=outside; deterministic on shared edges."""
    inside = False
    for a, b in sides(poly):
        if on_segment(a, b, p):
            return 0
        if (a[1] > p[1]) != (b[1] > p[1]):
            x = a[0] + (p[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
            if p[0] < x:
                inside = not inside
    return 1 if inside else -1


def interior_witness(poly):
    """Point close to a convex vertex, strictly inside a CCW simple polygon."""
    for i, b in enumerate(poly):
        a, c = poly[i - 1], poly[(i + 1) % len(poly)]
        if cross(a, b, c) > EPS:
            return [(98 * b[k] + a[k] + c[k]) / 100 for k in (0, 1)]
    fail("polygon has no convex vertex")


def check_polygon(poly, region_id):
    if any(not all(math.isfinite(x) for x in p) for p in poly):
        fail(f"{region_id}: nonfinite coordinate")
    if len(set(map(tuple, poly))) != len(poly):
        fail(f"{region_id}: repeated vertex")
    if any(math.dist(a, b) <= EPS for a, b in sides(poly)):
        fail(f"{region_id}: zero-length edge")
    twice_area = sum(a[0] * b[1] - b[0] * a[1] for a, b in sides(poly))
    if twice_area <= EPS:
        fail(f"{region_id}: require CCW nonzero polygon")
    for i, (a, b) in enumerate(sides(poly)):
        for j, (c, d) in enumerate(sides(poly)):
            if j <= i or j == i + 1 or (i == 0 and j == len(poly) - 1):
                continue
            if intersect(a, b, c, d):
                fail(f"{region_id}: self-intersecting polygon")


def overlap(poly_a, poly_b):
    if any(proper_intersection(a, b, c, d)
           for a, b in sides(poly_a) for c, d in sides(poly_b)):
        return True
    if any(location(poly_b, p) == 1 for p in poly_a):
        return True
    if any(location(poly_a, p) == 1 for p in poly_b):
        return True
    return (location(poly_b, interior_witness(poly_a)) == 1
            or location(poly_a, interior_witness(poly_b)) == 1)


def boundary_support(poly, p, width):
    """Full centered opening must fit on a single polygon edge."""
    return any(on_segment(a, b, p)
               and min(math.dist(a, p), math.dist(b, p)) + EPS >= width / 2
               for a, b in sides(poly))


def line_intersection_parameters(a, b, c, d):
    """Parameter t along AB for intersections with CD, including collinear ends."""
    rx, ry = b[0] - a[0], b[1] - a[1]
    sx, sy = d[0] - c[0], d[1] - c[1]
    den = rx * sy - ry * sx
    qx, qy = c[0] - a[0], c[1] - a[1]
    if abs(den) <= EPS:
        if abs(qx * ry - qy * rx) > EPS:
            return []
        rr = rx * rx + ry * ry
        if rr <= EPS:
            return []
        return [max(0, min(1, (qx * rx + qy * ry) / rr)),
                max(0, min(1, ((d[0] - a[0]) * rx + (d[1] - a[1]) * ry) / rr))]
    t = (qx * sy - qy * sx) / den
    u = (qx * ry - qy * rx) / den
    if -EPS <= t <= 1 + EPS and -EPS <= u <= 1 + EPS:
        return [max(0, min(1, t))]
    return []


def line_in_union(a, b, regions):
    ts = [0.0, 1.0]
    for region in regions:
        for c, d in sides(region["polygon"]):
            ts.extend(line_intersection_parameters(a, b, c, d))
    ts.sort()
    for t0, t1 in zip(ts, ts[1:]):
        if t1 - t0 <= EPS:
            continue
        t = (t0 + t1) * 0.5
        p = [a[k] + t * (b[k] - a[k]) for k in (0, 1)]
        if not any(location(r["polygon"], p) >= 0 for r in regions):
            return False
    return True


def validate_document(document):
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(document)
    ids = {}
    for region in document["regions"]:
        rid = region["id"]
        if rid in ids:
            fail("duplicate region ID: " + rid)
        ids[rid] = region
        if region["variant"] not in VARIANTS[region["biome"]]:
            fail(rid + ": unsupported generator v1 biome variant")
        check_polygon(region["polygon"], rid)
    regions = list(ids.values())
    for i, r in enumerate(regions):
        for other in regions[i + 1:]:
            if overlap(r["polygon"], other["polygon"]):
                fail(r["id"] + " and " + other["id"] + ": overlapping interiors")

    fids = set()
    for feature in document["features"]:
        fid = feature["id"]
        if fid in fids:
            fail("duplicate feature ID: " + fid)
        fids.add(fid)
        if not math.isfinite(feature["width"]):
            fail(fid + ": nonfinite width")
        points = feature["points"]
        for a, b in zip(points, points[1:]):
            if not all(math.isfinite(x) for p in (a, b) for x in p):
                fail(fid + ": nonfinite point")
            if math.dist(a, b) <= EPS:
                fail(fid + ": degenerate polyline")
            if not line_in_union(a, b, regions):
                fail(fid + ": feature line exits authored region union")

    cids = set()
    edges = set()
    for connector in document["connectors"]:
        cid, pair = connector["id"], connector["regions"]
        if cid in cids:
            fail("duplicate connector ID: " + cid)
        cids.add(cid)
        if pair[0] == pair[1] or pair != sorted(pair):
            fail(cid + ": pair must contain two different sorted IDs")
        if any(rid not in ids for rid in pair):
            fail(cid + ": unknown region reference")
        anchor, width = connector["anchor"], connector["width"]
        if not all(math.isfinite(x) for x in anchor) or not math.isfinite(width):
            fail(cid + ": nonfinite connector geometry")
        edgekey = (tuple(pair), tuple(anchor), connector["kind"])
        if edgekey in edges:
            fail(cid + ": duplicate physical opening")
        edges.add(edgekey)
        if not all(boundary_support(ids[rid]["polygon"], anchor, width) for rid in pair):
            fail(cid + ": missing common boundary or opening exceeds shared edge")
        if not any(f["kind"] == connector["kind"]
                   and f["width"] + EPS >= width
                   and any(on_segment(a, b, anchor)
                       for a, b in zip(f["points"], f["points"][1:]))
                   for f in document["features"]):
            fail(cid + ": no matching line center crossing its anchor")
    return True


def resolve_region(document, x, y):
    """Authoring-only region lookup; not a replacement for Lua WorldQuery."""
    if not all(isinstance(n, (int, float)) and not isinstance(n, bool)
               and math.isfinite(n) for n in (x, y)):
        fail("invalid world coordinate")
    for region in sorted(document["regions"], key=lambda r: r["id"]):
        if location(region["polygon"], [x, y]) >= 0:
            return region["id"]
    return None  # outside authored area: delegate unchanged to Generator v1


def canonical_digest(document):
    """Order-neutral identity fingerprint. IDs never derive from geometry/seed."""
    validate_document(document)
    clone = copy.deepcopy(document)
    for key in ("regions", "connectors", "features"):
        clone[key].sort(key=lambda item: item["id"])
    raw = json.dumps(clone, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main():
    parser = argparse.ArgumentParser(description="Validate authoring-only world graph")
    parser.add_argument("file", type=Path, nargs="?", default=PILOT_PATH)
    args = parser.parse_args()
    if args.file.stat().st_size > 2_000_000:
        fail("file over 2 MB limit")
    with args.file.open(encoding="utf-8") as fh:
        document = json.load(fh, parse_constant=lambda x: fail("invalid JSON constant: " + x))
    digest = canonical_digest(document)
    print("WORLDBUILD_CONTRACT_OK", document["map_id"], "regions=" + str(len(document["regions"])),
          "connectors=" + str(len(document["connectors"])), "sha256=" + digest)


if __name__ == "__main__":
    main()
