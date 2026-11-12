"""Re-encode mislabeled JPEG terrain maps to actual PNG without resampling.
Source ZIP packaged these 18 RGB JPEG bitstreams with .png extension.
Preserve current decoded pixels and exact 1536x1536 alignment.
This repair is limited to assets/terrain/<6 sets>/{albedo,height,normal}.png.
"""
from pathlib import Path
from PIL import Image
import sys, hashlib
ROOT = Path(__file__).resolve().parents[1]
SETS = (
    "forest_grass", "forest_rocky", "forest_sparse_litter",
    "forest_roots_litter", "conifer_needle_litter", "forest_moss_pebbles"
)
kinds = ("albedo", "height", "normal")
converted = 0
for material in SETS:
    for channel in kinds:
        path = ROOT / "assets" / "terrain" / material / (channel + ".png")
        if not path.is_file():
            sys.exit("TAMU_HD_MISSING " + str(path))
        with Image.open(path) as opened:
            if opened.size != (1536, 1536):
                sys.exit("TAMU_HD_DIMENSION_INVALID " + str(path))
            if opened.format == "PNG":
                if path.read_bytes()[:8] != bytes.fromhex("89504e470d0a1a0a"):
                    sys.exit("TAMU_HD_FALSE_PNG_MAGIC " + str(path))
                continue
            if opened.format != "JPEG":
                sys.exit("TAMU_HD_UNKNOWN_FORMAT " + str(path) + " " + str(opened.format))
            converted_image = opened.convert("RGB")
        old_sha = hashlib.sha256(path.read_bytes()).hexdigest()
        staging = path.with_suffix(".png.tmp")
        converted_image.save(staging, format="PNG", optimize=True)
        with Image.open(staging) as check:
            check.load()
            if check.format != "PNG" or check.mode != "RGB" or check.size != (1536,1536):
                sys.exit("TAMU_HD_PNG_VERIFY_FAILED " + str(path))
            # Pixel-identity check on decoded JPEG source, no resizing or editing.
            if check.tobytes() != converted_image.tobytes():
                sys.exit("TAMU_HD_PIXEL_CHANGED " + str(path))
        staging.replace(path)
        converted += 1
        print("TAMU_HD_JPEG_RENAMED_FIXED", material, channel, "old_sha256", old_sha)
# Every original .png path MUST be a valid PNG signature now.
for material in SETS:
    for channel in kinds:
        path = ROOT / "assets" / "terrain" / material / (channel + ".png")
        if not path.read_bytes()[:8] == bytes.fromhex("89504e470d0a1a0a"):
            sys.exit("TAMU_HD_SOURCE_NOT_PNG " + str(path))
print(f"TAMU_HD_TRUE_PNG_OK material_sets=6 maps=18 converted={converted}")
