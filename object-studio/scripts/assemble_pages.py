#!/usr/bin/env python3
"""Combine existing experimental World Builder root and main Object Studio.
Source branches are read-only in CI. No local application user data is touched.
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path


def _fp(content):
    return hashlib.sha256(content).hexdigest()[:12]


def assemble(preview: Path, studio: Path, destination: Path, preview_sha: str, main_sha: str):
    if not re.fullmatch(r"[a-f0-9]{40}", preview_sha) or not re.fullmatch(r"[a-f0-9]{40}", main_sha):
        raise ValueError("Commit SHAs must be full 40-character hexadecimal hashes")
    if destination.exists():
        raise FileExistsError("Refusing to overwrite an existing Pages output: " + str(destination))
    for p in ("index.html", "style.css", "app.js", "assembly.html", "assembly.js"):
        if not (preview / p).is_file():
            raise FileNotFoundError("Missing existing World Builder asset: " + p)
    for p in ("index.html", "latest.html", "build.json"):
        if not (studio / p).is_file():
            raise FileNotFoundError("Missing Object Studio build: " + p)
    obj_build = json.loads((studio / "build.json").read_text("utf-8"))
    if obj_build.get("sha") != main_sha:
        raise ValueError("Object Studio artifact SHA differs from main")
    shutil.copytree(preview, destination)
    for name in ("app.js", "style.css"):
        path = destination / name
        payload = path.read_text("utf-8")
        if name == "app.js":
            if payload.count("__BUILD_SHA__") != 1:
                raise ValueError("World Builder app has unexpected build markers")
            payload = payload.replace("__BUILD_SHA__", preview_sha)
        raw = payload.encode("utf-8")
        stem, suffix = name.rsplit(".", 1)
        hashed = f"{stem}.{_fp(raw)}.{suffix}"
        (destination / hashed).write_bytes(raw)
        page = (destination / "index.html").read_text("utf-8")
        (destination / "index.html").write_text(page.replace("./" + name, "./" + hashed), "utf-8")
    script = (destination / "assembly.js").read_text("utf-8")
    if script.count("__BUILD_SHA__") != 1:
        raise ValueError("Assembly preview has unexpected build markers")
    script = script.replace("__BUILD_SHA__", preview_sha)
    hashed = f"assembly.{_fp(script.encode('utf-8'))}.js"
    (destination / hashed).write_text(script, "utf-8")
    html = (destination / "assembly.html").read_text("utf-8")
    (destination / "assembly.html").write_text(html.replace("./assembly.js", "./" + hashed), "utf-8")
    root_html = (destination / "index.html").read_text("utf-8")
    link = ('<div style="padding:9px 16px"><a style="display:block;text-align:center;'
            'border:1px solid #b9d39b;border-radius:11px;padding:12px;color:#d5e9ba;'
            'text-decoration:none" href="./object-studio/latest.html">'
            '◈ Obje Stüdyosu / Ağaç & Kaya →</a></div>')
    if "object-studio/latest.html" not in root_html:
        if '<div class="legend">' not in root_html:
            raise ValueError("World Builder navigation insertion point missing")
        root_html = root_html.replace('<div class="legend">', link + '<div class="legend">', 1)
    (destination / "index.html").write_text(root_html, "utf-8")
    (destination / "latest.html").write_text(root_html, "utf-8")
    (destination / "build.json").write_text(json.dumps({"sha": preview_sha, "entry": "latest.html"}), "utf-8")
    (destination / ".nojekyll").write_text("", "utf-8")
    shutil.copytree(studio, destination / "object-studio")
    return destination


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--studio", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--preview-sha", required=True)
    parser.add_argument("--main-sha", required=True)
    args = parser.parse_args()
    assemble(args.preview, args.studio, args.out, args.preview_sha, args.main_sha)
    print("Pages assembled: existing World Builder + main Object Studio")


if __name__ == "__main__":
    main()
