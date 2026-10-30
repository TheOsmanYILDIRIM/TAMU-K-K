#!/usr/bin/env python3
"""Deterministic LÖVE release ZIP: root main.lua, packaged pinned R2 maps.
No environment variables, user saves, or private files are copied.
"""
import argparse, hashlib, json, zipfile, subprocess, sys
from pathlib import Path
from build_creative_assets import generate
from build_tamu_static_shadow_atlases import build as build_static_shadows
R2={
 'fisilti_ormani.r2.v1.json':'df5d0eeca59030e6585558c15d8f1e7bf049638ea8032dc17c1b80c74106f598',
 'osman_overworld.v2.json':'ac5903fd22cd466cfc1786cbeef44f2679be87317c6bfd757a05a282172f78dc',
}
def main(repo,output,prebaked_dir=None):
    root=repo/'game/love'
    assert (root/'main.lua').is_file() and (root/'conf.lua').is_file()
    assets=output.parent/'tamu_creative_generated'
    raw_catalog=subprocess.check_output(["lua5.4","scripts/export_building_parts.lua"],cwd=repo)
    generate(assets,json.loads(raw_catalog),repo)
    shadow_dir=output.parent/'tamu_static_shadow_generated'
    shadow_manifest=build_static_shadows(root/'assets/terrain25d',shadow_dir)
    content=[]
    for p in root.rglob('*'):
        if p.is_file() and p.suffix.lower() not in ('.pyc','.log') and '__pycache__' not in p.parts:
            rel=p.relative_to(root).as_posix()
            if rel.startswith(('assets/tamu_creative_','assets/worldbuild/')) or rel in ('assets/creative_build_atlas.png','assets/creative_build_manifest.json'):
                continue
            content.append((rel,p.read_bytes()))
    for generated in sorted(shadow_dir.iterdir()):
        if generated.is_file():
            content.append(('assets/terrain25d/static_shadow/'+generated.name, generated.read_bytes()))
    assert len(shadow_manifest['pages'])==8
    for name,sha in R2.items():
        raw=(root/'assets/worldbuild'/name).read_bytes() if (root/'assets/worldbuild'/name).is_file() else (repo/'data/worldbuild'/name).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==sha,(name,'unpinned world data')
        content.append(('assets/worldbuild/'+name,raw))
    content.append(('assets/tamu_creative_25d.flag',b'packaged-only-25d-creative-v1\n'))
    for name in ('creative_build_atlas.png','creative_build_manifest.json'):
        content.append(('assets/'+name,(assets/name).read_bytes()))
    if prebaked_dir is not None:
        prebaked_dir=Path(prebaked_dir)
        bins=sorted(prebaked_dir.glob('c_*.verts.z'))
        metas=sorted(prebaked_dir.glob('c_*.meta.json'))
        assert len(bins)==len(metas)==156, 'authored bake incomplete'
        bases_bin={p.name[:-len('.verts.z')] for p in bins}
        bases_meta={p.name[:-len('.meta.json')] for p in metas}
        assert bases_bin==bases_meta,'authored binary metadata mismatch'
        content=[(name,raw) for name,raw in content
                 if not name.startswith('assets/terrain25d/baked/')]
        for src in bins+metas:
            content.append(('assets/terrain25d/baked/'+src.name,src.read_bytes()))
    paths=[key for key,_ in content]
    assert len(set(paths))==len(paths),'duplicate package path'
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=7) as z:
        for path,raw in sorted(content):
            info=zipfile.ZipInfo(path,(2026,10,29,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=0o644<<16
            z.writestr(info,raw)
    with zipfile.ZipFile(output) as z:
        assert z.testzip() is None
        assert 'main.lua' in z.namelist() and 'assets/creative_build_atlas.png' in z.namelist()
        assert len([p for p in z.namelist() if p.startswith('assets/terrain25d/static_shadow/objects_shadow_') and p.endswith('.png')])==8
        assert all(z.read('assets/worldbuild/'+n)==(repo/'data/worldbuild'/n).read_bytes() for n in R2)
    print(json.dumps({'file':str(output),'size':output.stat().st_size,
       'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'count':len(paths)}))
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,default=Path('.'))
    ap.add_argument('--output',required=True,type=Path)
    ap.add_argument('--prebaked-dir',type=Path,default=None)
    args=ap.parse_args();main(args.repo,args.output,args.prebaked_dir)
