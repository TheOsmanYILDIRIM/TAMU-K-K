#!/usr/bin/env python3
"""Pinned LPC source catalog / Godot addon installer. No game data or save changes.

Usage:
  python3 scripts/lpc_import.py --addon
  python3 scripts/lpc_import.py --catalog
  python3 scripts/lpc_import.py --addon --catalog --all-to-assets
Run from repository root. Requires git and network. Art credit/licensing review
is mandatory BEFORE publishing any copied sprites.
"""
from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_URL = "https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator.git"
SOURCE_SHA = "04140673ec02906f8233523639733c83690df750"
ADDON_URL = "https://github.com/alextrevisan/LPCAnimatedSprite2D.git"
ADDON_SHA = "abe214da0a71c55a295d42ef7ea64f11dcc69769"
CACHE = ROOT.parent / ".tamu-lpc-checkouts"


def execute(*args: str, cwd: Path | None = None) -> str:
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def checkout(name: str, url: str, commit: str, paths: list[str]) -> Path:
    target = CACHE / name
    CACHE.mkdir(parents=True, exist_ok=True)
    if not (target / ".git").exists():
        execute("git", "clone", "--filter=blob:none", "--no-checkout", "--sparse", url, str(target))
    execute("git", "fetch", "--depth=1", "origin", commit, cwd=target)
    execute("git", "sparse-checkout", "set", *paths, cwd=target)
    execute("git", "checkout", "--detach", commit, cwd=target)
    actual = execute("git", "rev-parse", "HEAD", cwd=target)
    if actual != commit:
        raise RuntimeError(f"Pinned SHA mismatch for {name}: {actual}")
    return target


def install_addon() -> None:
    source = checkout("LPCAnimatedSprite2D", ADDON_URL, ADDON_SHA, ["addons/LPCAnimatedSprite"])
    origin = source / "addons" / "LPCAnimatedSprite"
    if not (origin / "plugin.cfg").exists():
        raise RuntimeError("Upstream LPC addon does not contain expected plugin.cfg")
    destination = ROOT / "addons" / "LPCAnimatedSprite"
    if destination.exists():
        raise FileExistsError(f"Refusing to overwrite existing addon: {destination}")
    shutil.copytree(origin, destination)
    print(f"Installed pinned LPCAnimatedSprite2D {ADDON_SHA} into {destination}")


def catalog(copy_all: bool) -> None:
    # Full artist catalog stays in external checkout by default: importing every
    # artwork file into res:// would be expensive on Android.
    source = checkout("ULPC", SOURCE_URL, SOURCE_SHA,
                      ["spritesheets", "sheet_definitions", "CREDITS.csv", "README.md"])
    sprites = source / "spritesheets"
    if not sprites.is_dir():
        raise RuntimeError("Pinned source does not contain spritesheets/")
    paths = sorted(sprites.rglob("*.png"))
    credits = source / "CREDITS.csv"
    if not credits.exists():
        raise RuntimeError("Missing LPC credits. Import aborted.")
    with credits.open(encoding="utf-8-sig", newline="") as handle:
        credit_rows = sum(1 for _ in csv.reader(handle))
    buckets: dict[str, int] = {}
    for path in paths:
        relative = path.relative_to(sprites)
        key = relative.parts[0] if relative.parts else "unknown"
        buckets[key] = buckets.get(key, 0) + 1
    # The index is explicitly development-only metadata, not a save or mod schema.
    report = {
        "source_repository": SOURCE_URL, "source_commit": SOURCE_SHA,
        "credits_file": str(credits), "credit_csv_rows": credit_rows,
        "artwork_count": len(paths), "categories": buckets,
        "assets_root": str(sprites), "shipping_status": "license_review_required"
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if copy_all:
        destination = ROOT / "assets" / "lpc"
        if destination.exists():
            raise FileExistsError(f"Refusing to overwrite existing assets: {destination}")
        shutil.copytree(sprites, destination)
        shutil.copy2(credits, destination / "CREDITS.csv")
        (destination / ".source-revision").write_text(SOURCE_SHA + "\n", encoding="utf-8")
        print("Copied full LPC catalog. WARNING: do NOT package all assets into Android APK/PCK.")
    else:
        print("Full catalog is available externally. No large assets added to Godot automatically.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", action="store_true", help="Install pinned MIT Godot LPC addon")
    parser.add_argument("--catalog", action="store_true", help="Download/index full LPC asset catalog outside Godot")
    parser.add_argument("--all-to-assets", action="store_true", help="Copy all LPC artwork into assets/lpc (large, not advised for Android)")
    args = parser.parse_args()
    if args.all_to_assets and not args.catalog:
        parser.error("--all-to-assets requires --catalog")
    if not args.addon and not args.catalog:
        parser.error("choose --addon and/or --catalog")
    if args.addon:
        install_addon()
    if args.catalog:
        catalog(args.all_to_assets)


if __name__ == "__main__":
    main()
