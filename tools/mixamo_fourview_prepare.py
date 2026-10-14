#!/usr/bin/env python3
"""Prepare four image-projected character views from the user-supplied sheet.

The committed chroma-key WebP is an explicitly downsampled *prototype proxy*, not the
full-resolution original.  It is never treated as a 3D reconstruction.
"""
import hashlib
import json
from collections import deque
from pathlib import Path
from PIL import Image

INPUT = Path("assets/reference/character_fourview_proxy_320.webp")
OUT = Path("rendered/mixamo_fourview_projection/references")
EXPECTED_SHA256 = "26e14b356e0f4a705eb10e69a574a7c812f80a57d60e26446e9d689f3441260c"
ORIGINAL_RGBA_SHA256 = "4686eacb9a2d11be4893b450cb73c02dd8b8a4abd564fabe34c91e3fad36d42c"
SIZE = 512
# Source image positions: upper-left, upper-right, lower-left, lower-right.
# Old photo has bottom-row hair entering the last 27 px of the top half;
# split at y = 600 / 1254, not at the exact vertical midpoint.
PANELS = {"SE": (0, 0), "SW": (0, 1), "NE": (1, 0), "NW": (1, 1)}


def extend_albedo(im):
    """Nearest opaque colour for uncovered projection texels (no alpha holes)."""
    rgb = im.convert("RGB")
    pix = rgb.load()
    a = im.getchannel("A").load()
    w, h = im.size
    seen = bytearray(w * h)
    todo = deque()
    for y in range(h):
        for x in range(w):
            if a[x, y] > 24:
                n = y * w + x
                seen[n] = 1
                todo.append(n)
    if not todo:
        raise ValueError("All-transparent view")
    while todo:
        n = todo.popleft()
        x, y = n % w, n // w
        rgb_at = pix[x, y]
        for neighbor in (n - 1 if x else -1, n + 1 if x + 1 < w else -1,
                         n - w if y else -1, n + w if y + 1 < h else -1):
            if neighbor < 0 or seen[neighbor]:
                continue
            seen[neighbor] = 1
            nx, ny = neighbor % w, neighbor // w
            pix[nx, ny] = rgb_at
            todo.append(neighbor)
    return rgb


def prepare():
    data = INPUT.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    if sha != EXPECTED_SHA256:
        raise ValueError(f"Reference proxy SHA mismatch: {sha}")
    rgb = Image.open(INPUT).convert("RGB")
    image = Image.new("RGBA", rgb.size)
    # Cyan is an intentionally reserved chroma key outside the character palette.
    pixels = []
    for red, green, blue in rgb.getdata():
        is_key = (green > 150 and blue > 150 and red < 145
                  and green - red > 55 and blue - red > 55)
        pixels.append((red, green, blue, 0 if is_key else 255))
    image.putdata(pixels)
    if image.size != (320, 320):
        raise ValueError(f"Unexpected reference sheet size: {image.size}")
    OUT.mkdir(parents=True, exist_ok=True)
    div_x = image.width // 2
    div_y = round(image.height * 600 / 1254)
    report = {
        "schema": 1, "kind": "user-image-projection-prototype",
        "full_source_sha256": ORIGINAL_RGBA_SHA256,
        "proxy_sha256": sha, "proxy_dimensions": list(image.size),
        "quality_warning": "320px lossy cyan-key WebP proxy of the uploaded 1254px RGBA sheet; diagnostic only",
        "view_assignment_assumption": "SE upper-left, SW upper-right, NE lower-left, NW lower-right",
        "views": {}
    }
    for name, (r, c) in PANELS.items():
        bounds = (c * div_x, r * div_y,
                  div_x if c == 0 else image.width,
                  div_y if r == 0 else image.height)
        panel = image.crop(bounds)
        mask = panel.getchannel("A").point(lambda x: 255 if x > 16 else 0)
        bbox = mask.getbbox()
        if not bbox:
            raise ValueError(f"No person silhouette in {name}")
        cropped = panel.crop(bbox)
        cropped.thumbnail((SIZE - 52, SIZE - 32), Image.Resampling.LANCZOS)
        if cropped.width < 30 or cropped.height < 100:
            raise ValueError(f"Suspicious reference crop {name}: {cropped.size}")
        canvas = Image.new("RGBA", (SIZE, SIZE))
        x0 = (SIZE - cropped.width) // 2
        y0 = (SIZE - cropped.height) // 2
        canvas.alpha_composite(cropped, (x0, y0))
        canvas.save(OUT / (name + "_reference.png"))
        extend_albedo(canvas).save(OUT / (name + "_albedo.png"))
        assert canvas.getchannel("A").getbbox()
        report["views"][name] = {
            "source_cell": list(bounds), "source_alpha_bbox": list(bbox),
            "aligned_bbox": list(canvas.getchannel("A").getbbox()),
            "filename": name + "_albedo.png"
        }
    path = OUT.parent / "prepare_manifest.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print("FOURVIEW_REFERENCE_PREPARED", sha, sorted(report["views"]))


if __name__ == "__main__":
    prepare()
