#!/usr/bin/env python3
"""OSMAN 2.5D deterministic asset import. No license inference or pixel resizing.

Input catalog JSON: {"version":1,"assets":[{"family":"grass", "source_drive_id":"...",
"original_filename":"tile.png", "local_file":"/path/tile.png", "license_status":"approved",
"license_evidence":"document identifier or reviewed grant", "kind":"terrain"|"object"}]}
Only reviewed assets are packaged; rejected/unverified candidates remain in audit.
"""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from PIL import Image

TERRAIN = {'grass', 'forest', 'dirt', 'rock', 'wetland'}
OBJECTS = {'oak', 'conifer', 'broadleaf', 'shrub', 'boulder', 'rock_spire', 'rock_cluster', 'water_rocks', 'reeds', 'stump', 'fallen_log', 'dead_tree'}
VERSION = 1
SIZE = 128
PAD = 2
COLS = 8


def canonical(data):
    return (json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def stable_id(kind, family, drive_id):
    prefix = 'material' if kind == 'terrain' else 'object_variant'
    return f'{prefix}_{family}_{digest(drive_id.encode())[:16]}'


def audit(candidates):
    """Read bytes, enforce 128x128, alpha and license with explicit evidence."""
    accepted, rejected = [], []
    ids = Counter(a.get('source_drive_id') for a in candidates)
    for a in sorted(candidates, key=lambda x: (str(x.get('family')), str(x.get('original_filename')), str(x.get('source_drive_id')))):
        errors = []
        family, kind = a.get('family'), a.get('kind')
        if kind not in ('terrain', 'object') or family not in (TERRAIN if kind == 'terrain' else OBJECTS):
            errors.append('unknown_kind_or_family')
        source_id = a.get('source_drive_id', '')
        if not isinstance(source_id, str) or not source_id or ids[source_id] != 1:
            errors.append('missing_or_duplicate_drive_id')
        if a.get('license_status') not in ('approved', 'user_declared_ai_generated') or not str(a.get('license_evidence', '')).strip():
            errors.append('license_not_verified')
        p = Path(a.get('local_file') or '/NONEXISTENT')
        name = a.get('original_filename')
        if not name or p.name != name or p.suffix.lower() != '.png':
            errors.append('filename_mismatch')
        raw = None
        try:
            raw = p.read_bytes()
            with Image.open(p) as im:
                im.verify()
            with Image.open(p) as im:
                if im.size != (SIZE, SIZE): errors.append('invalid_dimensions')
                if im.mode not in ('RGB', 'RGBA', 'P', 'LA'): errors.append('unsupported_color_mode')
                alpha_mode = 'opaque' if im.getextrema() is None else 'opaque'
                rgba = im.convert('RGBA')
                extrema = rgba.getchannel('A').getextrema()
                alpha_mode = 'transparent' if extrema[0] == 0 and extrema[1] > 0 else ('partial' if extrema[0] < 255 else 'opaque')
                if kind == 'object' and alpha_mode == 'opaque': errors.append('object_missing_alpha')
        except (OSError, ValueError):
            errors.append('missing_or_invalid_png')
        if errors:
            rejected.append({'source_drive_id': source_id, 'original_filename': name, 'reasons': sorted(set(errors))})
            continue
        accepted.append({**a, 'sha256': digest(raw), 'width': SIZE, 'height': SIZE, 'alpha_mode': alpha_mode,
                         'id': stable_id(kind, family, source_id)})
    hashes = Counter(a['sha256'] for a in accepted)
    for a in accepted[:]:
        if hashes[a['sha256']] > 1:
            accepted.remove(a)
            rejected.append({'source_drive_id': a['source_drive_id'], 'original_filename': a['original_filename'], 'reasons': ['duplicate_binary_hash']})
    return accepted, sorted(rejected, key=lambda x: (x['original_filename'] or '', x['source_drive_id']))


def package(catalog, dest, pilot_per_family=2):
    accepted, rejected = audit(catalog['assets'])
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    chosen = []
    for family in sorted(TERRAIN | OBJECTS):
        entries = sorted((a for a in accepted if a['family'] == family), key=lambda x: x['id'])
        chosen.extend(entries[:pilot_per_family])
    # Repeated 2 px edge pixels form an extrusion gutter; no sampling bleed.
    tilesize = SIZE + 2 * PAD
    pages = []
    for start in range(0, len(chosen), COLS * COLS):
        group = chosen[start:start + COLS * COLS]
        rows = (len(group) + COLS - 1) // COLS
        atlas = Image.new('RGBA', (COLS * tilesize, rows * tilesize), (0, 0, 0, 0))
        for j, item in enumerate(group):
            im = Image.open(item['local_file']).convert('RGBA')
            x = (j % COLS) * tilesize + PAD
            y = (j // COLS) * tilesize + PAD
            atlas.paste(im, (x, y))
            atlas.paste(im.crop((0, 0, 1, SIZE)).resize((PAD, SIZE)), (x-PAD,y))
            atlas.paste(im.crop((SIZE-1, 0, SIZE, SIZE)).resize((PAD, SIZE)), (x+SIZE,y))
            atlas.paste(im.crop((0, 0, SIZE, 1)).resize((SIZE, PAD)), (x,y-PAD))
            atlas.paste(im.crop((0, SIZE-1, SIZE, SIZE)).resize((SIZE, PAD)), (x,y+SIZE))
            for bx,by,sx,sy in ((x-PAD,y-PAD,0,0),(x+SIZE,y-PAD,SIZE-1,0),(x-PAD,y+SIZE,0,SIZE-1),(x+SIZE,y+SIZE,SIZE-1,SIZE-1)):
                atlas.paste(Image.new('RGBA',(PAD,PAD), im.getpixel((sx,sy))), (bx,by))
            item['atlas_page'] = f'atlas_{len(pages):02d}.png'
            item['uv_rect'] = [x/atlas.width, y/atlas.height, SIZE/atlas.width, SIZE/atlas.height]
        filename = f'atlas_{len(pages):02d}.png'
        atlas.save(dest / filename, optimize=False)
        pages.append({'filename': filename, 'sha256': digest((dest/filename).read_bytes()), 'width': atlas.width, 'height': atlas.height})
    data = {'version': VERSION, 'atlas_padding': PAD, 'atlas_pages': pages, 'assets': [], 'rejected': rejected}
    chosen_ids = {a['id'] for a in chosen}
    for a in accepted:
        e = {k: a[k] for k in ('id','kind','family','source_drive_id','original_filename','sha256','width','height','alpha_mode','license_status','license_evidence')}
        e['material_id' if a['kind']=='terrain' else 'object_variant_id'] = a['id']
        e['atlas_page'] = a.get('atlas_page') if a['id'] in chosen_ids else None
        e['uv_rect'] = a.get('uv_rect') if a['id'] in chosen_ids else None
        data['assets'].append(e)
    (dest/'manifest.json').write_bytes(canonical(data))
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('catalog', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = package(json.loads(args.catalog.read_text(encoding='utf8')), args.output)
    print(f"accepted={len(result['assets'])} rejected={len(result['rejected'])} pages={len(result['atlas_pages'])}")

if __name__ == '__main__': main()
