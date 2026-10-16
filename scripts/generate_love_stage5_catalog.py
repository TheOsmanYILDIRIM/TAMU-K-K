#!/usr/bin/env python3
"""Build the Stage 5 inventory/recipe registry ONLY from canonical JSON.

The existing Stage 4 registry is untouched. Use --check to prevent drift.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/catalog"
OUTPUT = ROOT / "game/love/systems/catalog_generated.lua"

def encode(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return repr(value)
    if isinstance(value, list):
        return "{" + ",".join(encode(x) for x in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + encode(key) + "]=" + encode(value[key])
                              for key in sorted(value)) + "}"
    raise ValueError("unsupported catalog type")

def render(catalog=CATALOG):
    root = Path(catalog)
    manifest = json.loads((root/"manifest.json").read_text(encoding="utf-8"))
    definitions = {}
    for relative in manifest["definitions"]:
        d = json.loads((root/relative).read_text(encoding="utf-8"))
        ident = d["id"]
        if ident in definitions:
            raise ValueError("duplicate ID " + ident)
        definitions[ident] = d

    items = {}
    for ident, d in definitions.items():
        if d["kind"] not in ("item", "structure"):
            continue
        comp = d["components"]
        stack = comp.get("core:stackable")
        max_count = stack["max_count"] if stack else 1
        if type(max_count) is not int or max_count < 1:
            raise ValueError("invalid stack size " + ident)
        place = comp.get("core:placeable")
        if place and d["kind"] != "structure":
            raise ValueError("only structures may be placed in this Stage 5 version")
        if place:
            fp = place["footprint"]
            if len(fp) != 2 or any(type(x) is not int or x < 1 for x in fp):
                raise ValueError("invalid placement footprint " + ident)
        items[ident] = {
            "id": ident,
            "kind": d["kind"],
            "max_stack": max_count,
            "tags": sorted(d["tags"]),
            "placeable": place,
            "station_tags": comp.get("core:craft_station", {}).get("station_tags", []),
        }

    recipes = {}
    for relative in manifest["recipes"]:
        recipe = json.loads((root/relative).read_text(encoding="utf-8"))
        ident = recipe["id"]
        if ident in recipes:
            raise ValueError("duplicate recipe ID " + ident)
        for group in ("inputs", "outputs"):
            if not recipe[group]:
                raise ValueError("recipe with empty " + group)
            for stack in recipe[group]:
                if stack["def_id"] not in items:
                    raise ValueError("non-inventory recipe reference " + stack["def_id"])
                if type(stack["count"]) is not int or stack["count"] < 1:
                    raise ValueError("invalid recipe stack count")
        recipes[ident] = {
            "id": ident, "duration_ticks": recipe["duration_ticks"],
            "inputs": recipe["inputs"], "outputs": recipe["outputs"],
            "station_tags": recipe["station_tags"],
        }
    if not recipes or not items:
        raise ValueError("empty inventory registry")
    output = {"catalog_version": manifest["catalog_version"],
              "items": items, "recipes": recipes}
    return ("-- Generated from data/catalog. Do not hand edit.\n"
            "-- scripts/generate_love_stage5_catalog.py --check validates parity.\n"
            "return " + encode(output) + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = render()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != generated:
            parser.error("Stage5 Lua catalog drift from canonical JSON")
        print("STAGE5_CATALOG_SYNC_OK")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(generated, encoding="utf-8")
        print(OUTPUT)

if __name__ == "__main__":
    main()
