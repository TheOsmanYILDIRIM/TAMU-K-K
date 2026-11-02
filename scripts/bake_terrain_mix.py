#!/usr/bin/env python3
"""Build-only diffuse material mix from pinned TAMU atlas; never mutates source.

No new source art or gameplay content: atlas_00_mix.png is a deterministic,
tileable derivative of the reviewed 168 terrain cells in atlas_00.png.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageChops

CELL = 132
GUTTER = 2
SIZE = 128
COLS, ROWS = 14, 12
PARTNERS = {"grass": "dirt", "dirt": "grass", "forest": "dirt", "rock": "forest"}
MIX = {"grass": 0.32, "forest": 0.29, "dirt": 0.28, "rock": 0.23}


def slot(entry):
    u, v = entry["uv_rect"][:2]
    return (min(COLS - 1, int(float(u) * 1848 / CELL)),
            min(ROWS - 1, int(float(v) * 1584 / CELL)))


def smooth(x):
    return x * x * (3.0 - 2.0 * x)


def mask_template():
    # Toroidal 8x8 value-noise field. Equal opposite edges are guaranteed;
    # details do not create disjoint circular or straight transition islands.
    grid = [[((x * 157 + y * 341 + 17) * (x * 59 + y * 113 + 11) % 65521) / 65521.0
             for x in range(8)] for y in range(8)]
    image = Image.new("L", (SIZE, SIZE))
    pixels = image.load()
    for y in range(SIZE):
        fy = y / 16.0
        iy = int(fy)
        ty = smooth(fy - iy)
        for x in range(SIZE):
            fx = x / 16.0
            ix = int(fx)
            tx = smooth(fx - ix)
            a = grid[iy % 8][ix % 8]
            b = grid[iy % 8][(ix + 1) % 8]
            c = grid[(iy + 1) % 8][ix % 8]
            d = grid[(iy + 1) % 8][(ix + 1) % 8]
            n = (a * (1 - tx) + b * tx) * (1 - ty) + (
                c * (1 - tx) + d * tx) * ty
            pixels[x, y] = round(255 * smooth(max(0, min(1, (n - .23) / .55))))
    return image


def bake(source, manifest, output):
    data = json.loads(manifest.read_text())
    src = Image.open(source).convert("RGBA")
    assert src.size == (1848, 1584), src.size
    declared = next(x for x in data["atlas_pages"] if x["filename"] == "atlas_00.png")
    assert hashlib.sha256(source.read_bytes()).hexdigest() == declared["sha256"], "unpinned terrain atlas"
    entries = [x for x in data["assets"] if x["kind"] == "terrain" and x["atlas_page"] == "atlas_00.png"]
    assert len(entries) == 168
    families = {}
    for entry in entries:
        families.setdefault(entry["family"], []).append(entry)
    target = src.copy()
    noise = mask_template()
    count = 0
    for entry in entries:
        family = entry["family"]
        if family not in PARTNERS:
            continue  # wetland stays pixel-identical until the water phase
        x, y = slot(entry)
        choices = families[PARTNERS[family]]
        to = choices[(x * 19 + y * 23) % len(choices)]
        other_x, other_y = slot(to)
        base_rect = (x * CELL + GUTTER, y * CELL + GUTTER,
                     x * CELL + GUTTER + SIZE, y * CELL + GUTTER + SIZE)
        blend_rect = (other_x * CELL + GUTTER, other_y * CELL + GUTTER,
                      other_x * CELL + GUTTER + SIZE, other_y * CELL + GUTTER + SIZE)
        first = src.crop(base_rect)
        second = src.crop(blend_rect)
        shifted = ImageChops.offset(noise, (x * 17 + y * 13) % SIZE,
                                    (y * 29 + x * 7) % SIZE)
        strength = MIX[family]
        alpha = shifted.point(lambda q: min(255, round(q * strength)))
        combined = Image.composite(second, first, alpha)
        px, py = base_rect[:2]
        target.paste(combined, (px, py))
        # Preserve the atlas's 2-pixel wrapping gutters after the mix.
        target.paste(combined.crop((0, SIZE - 2, SIZE, SIZE)), (px, py - 2))
        target.paste(combined.crop((0, 0, SIZE, 2)), (px, py + SIZE))
        target.paste(combined.crop((SIZE - 2, 0, SIZE, SIZE)), (px - 2, py))
        target.paste(combined.crop((0, 0, 2, SIZE)), (px + SIZE, py))
        count += 1
    assert count == 137, ("incorrect dry material coverage", count)
    output.parent.mkdir(parents=True, exist_ok=True)
    target.save(output, optimize=True)
    assert output.stat().st_size < 12 * 1024 * 1024
    assert output.read_bytes() != source.read_bytes()
    print("TAMU_TERRAIN_MIX_BAKED_OK materials=", count, "wetland_preserved=31 bytes=", output.stat().st_size)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="assets/terrain25d/atlas_00.png")
    parser.add_argument("--manifest", default="assets/terrain25d/manifest.json")
    parser.add_argument("--output", default="assets/terrain25d/atlas_00_mix.png")
    args = parser.parse_args()
    bake(Path(args.source), Path(args.manifest), Path(args.output))
