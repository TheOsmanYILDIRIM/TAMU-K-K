#!/usr/bin/env python3
"""Validate rendered SE frames and produce a visual proof sheet + diagnostics."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path("rendered/mixamo_fourview_projection")
diag = json.loads((ROOT / "projection_diagnostics.json").read_text())
prep = json.loads((ROOT / "prepare_manifest.json").read_text())
images = [ROOT / ("SE_%02d.png" % i) for i in range(8)]
if any(not p.is_file() for p in images):
    raise RuntimeError("All eight real Walking render frames are required")
if diag["sampled_frames"] != list(range(diag["frame_range"][0], diag["frame_range"][0] + 32, 4)):
    raise RuntimeError("Walking frame selection mismatch")
assert prep["proxy_sha256"] == diag["reference_sha256"]
assert set(prep["views"]) == {"SE", "SW", "NE", "NW"}

def stats(img):
    im = img.convert("RGBA")
    bb = im.getchannel("A").getbbox()
    if not bb:
        raise RuntimeError("Empty alpha in rendered frame")
    alpha = im.getchannel("A")
    count = sum(1 for value in alpha.getdata() if value > 20)
    if count < 2000:
        raise RuntimeError(f"Suspiciously small 3D render silhouette ({count} pixels)")
    return {"alpha_bbox": list(bb), "solid_pixels": count}

checks = []
canvas = Image.new("RGB", (5 * 270, 2 * 300), (39, 43, 50))
draw = ImageDraw.Draw(canvas)
src = Image.open(ROOT / "references" / "SE_reference.png").convert("RGBA")
tile = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
tile.alpha_composite(src.resize((256, 256), Image.Resampling.LANCZOS))
canvas.paste(tile.convert("RGB"), (7, 28), tile)
draw.text((10, 8), "SOURCE: SE (uploaded, 320px proxy)", fill="white")
for i, p in enumerate(images):
    im = Image.open(p).convert("RGBA")
    checks.append({"file": p.name, "frame": diag["sampled_frames"][i], **stats(im)})
    row, col = divmod(i + 1, 5)
    # Print eight samples; compare them to the fixed initial reference.
    x, y = col * 270 + 7, row * 300 + 28
    thumbnail = im.resize((256, 256), Image.Resampling.LANCZOS)
    canvas.paste(thumbnail.convert("RGB"), (x, y), thumbnail)
    draw.text((x, y - 20), f"RENDER: SE frame {diag['sampled_frames'][i]}", fill="white")
canvas.save(ROOT / "SE_contact_sheet.png", optimize=True)
# Diagnostics cannot prove a fit: silhouettes are from different geometry.
report = {
    "source": "real FBX-skinned Blender EEVEE render",
    "render_frame_count": len(checks),
    "per_frame": checks,
    "mesh_diagnostics": diag["mesh_metrics"],
    "warning": "No ground truth for render quality: inspect contact sheet for seam, pose mismatch, hair/tunic silhouette and inner limbs",
}
(ROOT / "render_checks.json").write_text(json.dumps(report, indent=2) + "\n")
print("FOURVIEW_RENDER_CHECKS_SUCCESS", len(checks), [c["solid_pixels"] for c in checks])
