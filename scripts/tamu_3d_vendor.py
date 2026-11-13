#!/usr/bin/env python3
"""TAMU 3D vendor bootstrap. Only pinned, documented CC0/MIT sources.

Called on an isolated GitHub Actions checkout. Never commits or overwrites
the existing 2.5D player, authored R2 data, production save, or assets.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
USER_AGENT = "TAMU-3D-Pilot/1.0 (Github Actions)"
SOURCES = [
    ("terrain_3d", "TokisanGames/Terrain3D", "v1.1.0-stable",
     "https://github.com/TokisanGames/Terrain3D/releases/download/v1.1.0-stable/Terrain3D_v1.1.0-stable.zip",
     45665295, "MIT"),
    ("asset_placer", "levinzonr/godot-asset-placer", "1dbf9fd782566780d6a6c52bd4197f448622f0aa", "", 0, "MIT"),
    ("phantom_camera", "ramokz/phantom-camera", "d20277eb0f9f7f0068e7aed7d7fe777ab72a0f07", "", 0, "MIT"),
    ("JehenoThirdPersonController", "Jeh3no/Godot-Third-Person-Controller",
     "380d949d2324a4ee6264d96753217ddfbaaab9ab", "", 0, "MIT"),
    ("gloot", "peter-kish/gloot", "ce88b7adc7b952b4df8ebe4836339de334d0d0cc", "", 0, "MIT"),
]
# Git object hashes are verified after download, including binary .glb files.
MODELS = {
    "forest.glb": ("396480", "386f990dfc5580dd6c6063a1ee4838bdf4df6742"),
    "nature.glb": ("1227364", "8421ab596c59e1920f3eda271665ed2c3f0a57cf"),
    "crew.glb": ("2098540", "9b3442deb757249081243be68c74422af018dd6a"),
}
MODELS_COMMIT = "9f7dc6536aacbce2203bb705e3f0cf1772ea3fb7"
CREDITS_URL = ("https://raw.githubusercontent.com/Station-Sciences/bot-crossing/"
               + MODELS_COMMIT + "/public/assets/CREDITS.md")
QUATERNIUS_URL = "https://quaternius.itch.io/universal-animation-library-2"


def get_bytes(url, cap):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=150) as response:
        if response.status != 200:
            raise RuntimeError("Download failed: %s HTTP %d" % (url, response.status))
        data = response.read(cap + 1)
    if not data or len(data) > cap:
        raise RuntimeError("Empty or oversized download: " + url)
    return data


def archive_url(full_name, commit):
    return "https://codeload.github.com/%s/zip/%s" % (full_name, commit)


def extract_addon(raw, addon_name):
    destination = ROOT / "addons" / addon_name
    if destination.exists():
        raise RuntimeError("Refusing to overwrite existing add-on: " + str(destination))
    extracted = 0
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        for item in archive.infolist():
            segments = Path(item.filename).parts
            if item.is_dir() or ".." in segments:
                continue
            found = -1
            for n in range(len(segments) - 2):
                if segments[n] == "addons" and segments[n + 1] == addon_name:
                    found = n
                    break
            if found < 0:
                continue
            rest = segments[found + 2:]
            if not rest:
                continue
            output = destination.joinpath(*rest)
            if not output.resolve().is_relative_to(destination.resolve()):
                raise RuntimeError("Unsafe archive path: " + item.filename)
            output.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as inp, open(output, "wb") as out:
                shutil.copyfileobj(inp, out)
            extracted += 1
    required = ("PlayerCharacter/player_character_scene.tscn"
                if addon_name == "JehenoThirdPersonController" else "plugin.cfg")
    if not (destination / required).is_file() or extracted < 3:
        raise RuntimeError("Missing upstream addon entrypoint: " + addon_name + "/" + required)
    return extracted


def repair_controller_paths():
    root = ROOT / "addons" / "JehenoThirdPersonController"
    old = "res://Godot-State-Machine-Third-Person-Controller/addons/"
    new = "res://addons/"
    changed = 0
    for path in root.rglob("*"):
        if path.is_file() and path.suffix in (".tscn", ".tres", ".gd", ".cfg"):
            data = path.read_text("utf-8")
            if old in data:
                path.write_text(data.replace(old, new), "utf-8")
                changed += 1
    if not changed:
        raise RuntimeError("Upstream third-person controller path layout changed")
    return changed


def verify_git_blob(raw, expected):
    git_sha = hashlib.sha1(("blob %d\0" % len(raw)).encode("ascii") + raw).hexdigest()
    if git_sha != expected:
        raise RuntimeError("Pinned Git blob SHA mismatch: " + expected)
    return hashlib.sha256(raw).hexdigest()


def run_install():
    report = {"addons": {}, "models": {}, "sources": {}, "limitations": [
        "Terrain3D mobile rendering/physics is experimental; requires physical Android test",
        "Quaternius UAL2 is CC0 but itch.io requires interactive acquisition; not auto-downloaded",
        "GLoot is staged only; TAMU durable inventory remains authoritative",
    ]}
    for addon, owner_repo, tag, direct, expected_size, licence in SOURCES:
        url = direct or archive_url(owner_repo, tag)
        raw = get_bytes(url, 200_000_000)
        if expected_size and len(raw) != expected_size:
            raise RuntimeError("Terrain3D pinned release size changed")
        count = extract_addon(raw, addon)
        report["addons"][addon] = {"repo": owner_repo, "ref": tag, "url": url,
                                   "license": licence, "files": count,
                                   "source_sha256": hashlib.sha256(raw).hexdigest()}
    report["controller_repaired_files"] = repair_controller_paths()

    target = ROOT / "assets" / "tamu_3d"
    if target.exists():
        raise RuntimeError("Refusing to overwrite existing TAMU 3D assets")
    target.mkdir(parents=True)
    for filename, (size, blob_sha) in MODELS.items():
        url = ("https://raw.githubusercontent.com/Station-Sciences/bot-crossing/"
               + MODELS_COMMIT + "/public/assets/" + filename)
        raw = get_bytes(url, 8_000_000)
        if len(raw) != int(size):
            raise RuntimeError("Pinned model size mismatch: " + filename)
        digest = verify_git_blob(raw, blob_sha)
        (target / filename).write_bytes(raw)
        report["models"][filename] = {"url": url, "git_blob": blob_sha,
                                      "size": len(raw), "sha256": digest, "license": "CC0"}
    credits = get_bytes(CREDITS_URL, 100_000)
    (target / "CREDITS.md").write_bytes(credits)
    report["sources"]["model_provenance"] = CREDITS_URL
    report["sources"]["optional_quaternius"] = QUATERNIUS_URL
    (target / "vendor_manifest.json").write_text(json.dumps(report, indent=2) + "\n", "utf-8")
    print("TAMU3D_DOWNLOAD_OK addons=%d models=%d" % (len(SOURCES), len(MODELS)))


def verify():
    for addon, _, _, _, _, _ in SOURCES:
        entry = ("PlayerCharacter/player_character_scene.tscn"
                 if addon == "JehenoThirdPersonController" else "plugin.cfg")
        if not (ROOT / "addons" / addon / entry).is_file():
            raise RuntimeError("Missing vendored addon: " + addon)
    manifest_path = ROOT / "assets" / "tamu_3d" / "vendor_manifest.json"
    manifest = json.loads(manifest_path.read_text("utf-8"))
    for filename, (_, blob_sha) in MODELS.items():
        raw = (ROOT / "assets" / "tamu_3d" / filename).read_bytes()
        verify_git_blob(raw, blob_sha)
        if hashlib.sha256(raw).hexdigest() != manifest["models"][filename]["sha256"]:
            raise RuntimeError("Model SHA256 mismatch: " + filename)
    # No old authoritative IDs, saves, or 2D sources are rewritten by installer.
    print("TAMU3D_VENDOR_VERIFY_OK addons=%d models=%d" % (len(SOURCES), len(MODELS)))


def audit():
    if len({x[0] for x in SOURCES}) != len(SOURCES):
        raise RuntimeError("Duplicate addon targets")
    if any(x[2] in ("main", "master", "") for x in SOURCES):
        raise RuntimeError("Unpinned add-on dependency")
    if any("http" not in x[3] and len(x[2]) != 40 for x in SOURCES):
        raise RuntimeError("Unexpected dependency revision")
    print("TAMU3D_SOURCES_PINNED_OK addons=%d models=%d" % (len(SOURCES), len(MODELS)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["audit", "install", "verify"])
    args = parser.parse_args()
    if args.operation == "audit":
        audit()
    elif args.operation == "install":
        audit()
        run_install()
    else:
        verify()
