#!/usr/bin/env python3
"""Fail-closed inventory gate for approved art-bearing core/plasma LÖVE packages.

A successful inventory is *not* optical visual acceptance or Android proof.
This script never creates, downloads, replaces, or uploads artwork.
"""
import argparse
import hashlib
import io
import json
import struct
import sys
import zipfile
from pathlib import Path

ROOT = "assets/core_plasma/"
CORE = ROOT + "core_original.png"
FRAMES = [ROOT + f"loop/frame_{i:03d}.png" for i in range(102)]
PNG_SIG = b"\x89PNG\r\n\x1a\n"
MAX_FILE = 20 * 1024 * 1024
MAX_TOTAL = 1024 * 1024 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def png_info(data):
    if len(data) < 33 or data[:8] != PNG_SIG or data[12:16] != b"IHDR":
        raise ValueError("invalid PNG header")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if not (0 < width <= 4096 and 0 < height <= 4096 and depth == 8):
        raise ValueError("unsupported PNG dimensions or bit depth")
    if color not in (4, 6) and not (color == 3 and b"tRNS" in data):
        raise ValueError("plasma source PNG lacks RGBA/alpha")
    return (width, height)


def choose_love(path):
    content = Path(path).read_bytes()
    if path.lower().endswith(".love"):
        return content, Path(path).name
    with zipfile.ZipFile(io.BytesIO(content)) as outer:
        candidates = [m for m in outer.infolist()
                      if not m.is_dir() and m.filename.lower().endswith(".love")]
        if len(candidates) != 1:
            raise ValueError(f"expected exactly one nested .love, found {len(candidates)}")
        info = candidates[0]
        if info.file_size > MAX_TOTAL:
            raise ValueError("nested game archive exceeds size limit")
        return outer.read(info), info.filename


def audit_love(data, source_name, expected_core_sha256=None):
    report = {"source": source_name, "love_sha256": sha(data),
              "status": "missing_art", "render_ready": False,
              "visual_accepted": False}
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as game:
            members = {m.filename: m for m in game.infolist() if not m.is_dir()}
            total = sum(m.file_size for m in members.values())
            if total > MAX_TOTAL or any(m.file_size > MAX_FILE for m in members.values()):
                raise ValueError("archive exceeds decompression safety limits")
            present = set(members)
            absent = [n for n in [CORE, *FRAMES] if n not in present]
            report.update(entry_count=len(present), missing_count=len(absent),
                          missing_preview=absent[:5], frame_count=sum(n in present for n in FRAMES),
                          core_present=CORE in present, entrypoint_present="main.lua" in present)
            if absent or not report["entrypoint_present"]:
                return report
            sizes, hashes = [], []
            for name in [CORE, *FRAMES]:
                item = game.read(name)
                sizes.append(png_info(item))
                hashes.append(sha(item))
            if len(set(sizes[1:])) != 1:
                raise ValueError("frame dimensions inconsistent")
            report.update(core_sha256=hashes[0], core_dimensions=sizes[0],
                          frame_dimensions=sizes[1],
                          unique_frame_sha256=len(set(hashes[1:])),
                          missing_count=0, missing_preview=[])
            if len(set(hashes[1:])) < 8:
                raise ValueError("fewer than eight unique frame byte hashes")
            if expected_core_sha256 is None:
                report["status"] = "source_provenance_unverified"
                return report
            if hashes[0] != expected_core_sha256:
                report["status"] = "core_hash_mismatch"
                return report
            report["status"] = "ready_for_visual_review"
            report["render_ready"] = True
            return report
    except (zipfile.BadZipFile, ValueError, OSError, RuntimeError) as exc:
        report["status"] = "invalid_art_archive"
        report["error"] = str(exc)
        return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("package", help=".love or GitHub Actions artifact .zip containing one .love")
    p.add_argument("--approved-core-sha256",
                   help="independently approved source SHA256, no implicit provenance")
    p.add_argument("--require-ready", action="store_true")
    p.add_argument("--json-out", help="optional report output")
    args = p.parse_args()
    try:
        data, name = choose_love(args.package)
        result = audit_love(data, name, args.approved_core_sha256)
    except (FileNotFoundError, ValueError, OSError, zipfile.BadZipFile) as exc:
        result = {"source": args.package, "status": "invalid_package",
                  "render_ready": False, "visual_accepted": False, "error": str(exc)}
    output = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    print(output, end="")
    if args.json_out:
        Path(args.json_out).write_text(output, encoding="utf-8")
    return 3 if args.require_ready and not result["render_ready"] else 0


if __name__ == "__main__":
    sys.exit(main())
