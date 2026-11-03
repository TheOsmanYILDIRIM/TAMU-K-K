#!/usr/bin/env python3
"""OSMAN OYUN texture candidate processor. Never modifies input files."""
import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageCms
from sklearn.cluster import KMeans
from skimage.color import rgb2lab, lab2rgb


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def srgb_image(im):
    icc = im.info.get('icc_profile')
    if icc:
        src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        dst = ImageCms.createProfile('sRGB')
        mode = 'RGBA' if 'A' in im.getbands() else 'RGB'
        alpha = im.getchannel('A') if 'A' in im.getbands() else None
        rgb = ImageCms.profileToProfile(im.convert('RGB'), src, dst, outputMode='RGB')
        if alpha is not None:
            rgb.putalpha(alpha)
        return rgb, True
    # PNG with no embedded profile is treated as sRGB by convention.
    return im.convert('RGBA' if 'A' in im.getbands() else 'RGB'), False


def resize_premultiplied(im, size):
    if im.mode != 'RGBA':
        return im.resize(size, Image.Resampling.LANCZOS)
    data = np.asarray(im, dtype=np.float32)
    alpha = data[:, :, 3:4] / 255.0
    premultiplied = np.clip(np.rint(data[:, :, :3] * alpha), 0, 255).astype('uint8')
    channels = [np.asarray(Image.fromarray(premultiplied[:, :, i], 'L').resize(size, Image.Resampling.LANCZOS), dtype=np.float32) for i in range(3)]
    a = np.asarray(im.getchannel('A').resize(size, Image.Resampling.LANCZOS), dtype=np.uint8)
    af = a.astype(np.float32) / 255.0
    rgb = np.stack(channels, axis=-1)
    unpremult = np.zeros_like(rgb)
    np.divide(rgb, af[:, :, None], out=unpremult, where=af[:, :, None] > 0)
    out = np.dstack((np.clip(np.rint(unpremult), 0, 255).astype('uint8'), a))
    return Image.fromarray(out, 'RGBA')


def seam_stats(im):
    rgb = np.asarray(im.convert('RGB'), dtype=np.int16)
    return {'horizontal_edge_mean_rgb_delta': round(float(np.abs(rgb[:, 0] - rgb[:, -1]).mean()), 3),
            'vertical_edge_mean_rgb_delta': round(float(np.abs(rgb[0] - rgb[-1]).mean()), 3)}


def process(src, output, kind, size, colors, seed):
    src, output = Path(src), Path(output)
    if src.resolve() == output.resolve():
        raise ValueError('Refusing to overwrite input')
    with Image.open(src) as original:
        original.load()
        dims = list(original.size)
        mode = original.mode
        has_alpha = 'A' in original.getbands() or 'transparency' in original.info
        if kind == 'ground' and has_alpha:
            raise ValueError('Ground must be opaque RGB; transparent source requires review')
        if kind == 'object' and not has_alpha:
            raise ValueError('Object needs real alpha, refusing to infer from background')
        im, profile_converted = srgb_image(original)
    initial_seams = seam_stats(im) if kind == 'ground' else None
    if kind == 'ground':
        target = (size, size)
    else:
        w, h = im.size
        factor = min(size / w, size / h)
        newsize = (max(1, round(w * factor)), max(1, round(h * factor)))
        target = newsize
    im = resize_premultiplied(im, target)
    if kind == 'object':
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((size-target[0])//2, size-target[1])) # bottom-centered pivot
        im = canvas
    array = np.asarray(im, dtype=np.uint8)
    mask = (array[:, :, 3] > 0) if kind == 'object' else np.ones((size, size), bool)
    if not mask.any():
        raise ValueError('Fully transparent image')
    pixels = array[:, :, :3][mask] if kind == 'object' else array.reshape(-1, 3)
    lab = rgb2lab(pixels.astype(np.float32).reshape(1, -1, 3)/255.0).reshape(-1, 3)
    unique = np.unique(pixels, axis=0)
    k = min(colors, len(unique), len(pixels))
    km = KMeans(n_clusters=k, random_state=seed, n_init=10)
    ids = km.fit_predict(lab)
    palette = np.clip(np.rint(lab2rgb(km.cluster_centers_.reshape(1, k, 3))[0]*255), 0, 255).astype(np.uint8)
    mapped = palette[ids]
    if kind == 'ground':
        result = Image.fromarray(mapped.reshape(size, size, 3), 'RGB')
    else:
        out = np.zeros((size, size, 4), np.uint8)
        out[:, :, 3] = array[:, :, 3]
        out[:, :, :3][mask] = mapped
        result = Image.fromarray(out, 'RGBA')
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise FileExistsError(output)
    result.save(output, format='PNG', icc_profile=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes())
    with Image.open(output) as check:
        check.load()
        read = np.array(check.convert('RGBA'))
    actual_colors = len(np.unique(read[:, :, :3][read[:, :, 3]>0], axis=0))
    if actual_colors > colors:
        raise AssertionError(f'Palette limit exceeded: {actual_colors}')
    report = {'source':str(src),'source_sha256':sha256(src),'original_size':dims,'original_mode':mode,
              'embedded_icc_converted_to_srgb':profile_converted, 'unprofiled_assumed_srgb':not profile_converted,
              'kind':kind,'output':str(output),'output_sha256':sha256(output),'output_size':[size,size],
              'colors_requested_max':colors,'colors_actual_visible_rgb':actual_colors,'alpha_preserved':kind=='object',
              'initial_seams':initial_seams,'output_seams':seam_stats(result) if kind=='ground' else None,
              'random_state':seed,'n_init':10,'dithering':False,'seam_fixed':False,
              'acceptance':'candidate — manual 3x3 tiling / alpha / biome / in-game-scale review required'}
    if kind == 'ground':
        tiled = Image.new('RGB', (size*3, size*3))
        for y in range(3):
            for x in range(3): tiled.paste(result, (x*size, y*size))
        preview = output.with_name(output.stem + '_tile_preview.png')
        if preview.exists(): raise FileExistsError(preview)
        tiled.save(preview)
        report['tile_preview']=str(preview)
    manifest=output.with_name(output.stem + '.manifest.json')
    if manifest.exists(): raise FileExistsError(manifest)
    manifest.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--kind',choices=['ground','object'],default='ground')
    parser.add_argument('--size',type=int,default=128,help='Final square dimensions')
    parser.add_argument('--colors',type=int,default=64,help='Maximum visible RGB colors')
    parser.add_argument('--seed',type=int,default=42)
    args=parser.parse_args()
    if args.size < 8 or args.colors < 2 or args.colors > 256: parser.error('size>=8 and 2<=colors<=256 required')
    print(json.dumps(process(args.source,args.output,args.kind,args.size,args.colors,args.seed),indent=2,ensure_ascii=False))

if __name__=='__main__': main()
