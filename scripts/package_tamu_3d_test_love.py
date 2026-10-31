#!/usr/bin/env python3
"""Create a tamper-checked .love that uses the two-view avatar by default.
Game source, player physics, saves and runtime stay unchanged in Git.
Only the distributed test archive changes its bootstrap and avatar selection.
"""
import argparse
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import zipfile

from package_tamu_love import main as build_standard

SOURCE = b'if not _G.TAMU_ISOLATION_SELECTED and'
BOOT = b'if false and not _G.TAMU_ISOLATION_SELECTED and'
RIG = (b'local CoreVisual=(os.getenv("TAMU_BAKED_3D_AVATAR")=="1")\n'
       b'  and require("player.side_baked_visual") or require("player.rigby_visual")')
BAKED = b'local CoreVisual=require("player.side_baked_visual")'
SMOKE = b'''
-- Opt-in CI-only LÖVE render smoke; mobile behavior has no environment dependency.
if os.getenv("TAMU_BAKED_DEMO_SMOKE")=="1" then
  local draw_game=love.draw
  local rendered=0
  love.draw=function(...)
    draw_game(...)
    rendered=rendered+1
    if rendered==8 then
      love.graphics.captureScreenshot("tamu-3d-game-smoke.png")
    elseif rendered==18 then
      print("TAMU_3D_GAME_REAL_LOVE_OK",rendered)
      love.event.quit()
    end
  end
end
'''

def replace_once(raw, a, b):
    if raw.count(a)!=1:
        raise ValueError(f"Expected one occurrence, got {raw.count(a)}: {a[:80]!r}")
    return raw.replace(a,b)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--repo',type=Path,default=Path('.'))
    parser.add_argument('--output',required=True,type=Path)
    opts=parser.parse_args()
    root=opts.repo.resolve()
    out=opts.output.resolve()
    atlas=root/'game/love/assets/character_side_bake/atlas.png'
    manifest=root/'game/love/assets/character_side_bake/manifest.json'
    meta=json.loads(manifest.read_text())
    assert meta['camera_pitch_degrees']==45 and meta['bottom_center_pivot'] is True
    assert hashlib.sha256(atlas.read_bytes()).hexdigest()==meta['atlas_sha256']
    with TemporaryDirectory(prefix='tamu-baked-demo-') as tmp:
        base=Path(tmp)/'base.love'
        build_standard(root,base)
        with zipfile.ZipFile(base) as z:
            assert z.testzip() is None
            expected=set(z.namelist())
            assert 'player/side_baked_visual.lua' in expected
            assert 'assets/character_side_bake/atlas.png' in expected
            assert 'assets/character_side_bake/manifest.json' in expected
            assert z.read('assets/character_side_bake/atlas.png')==atlas.read_bytes()
            modified={}
            main_src=z.read('main.lua')
            main_src=replace_once(main_src,SOURCE,BOOT) + SMOKE
            modified['main.lua']=main_src
            modified['objects/renderer.lua']=replace_once(z.read('objects/renderer.lua'),RIG,BAKED)
            out.parent.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=7) as dest:
                for item in z.infolist():
                    dest.writestr(item,modified.get(item.filename,z.read(item.filename)))
                dest.writestr('TAMU_3D_TEST_README.txt',
                    'TAMU two-view 3D avatar test; R2 gameplay enabled.\\n'
                    'Front/back rendered at 45 degrees; left/right mirrored.\\n'
                    'Controls: mobile joystick, WASD, pinch zoom, inventory.\\n'
                    'Experimental avatar is forced only inside this .love.\\n'
                    'No production files, saves, or default Rigby are replaced.\\n')
    with zipfile.ZipFile(out) as z:
        assert z.testzip() is None
        assert len(z.namelist())==len(set(z.namelist()))
        assert z.read('objects/renderer.lua').count(BAKED)==1
        assert z.read('main.lua').startswith(b'-- No gameplay')
        assert BOOT in z.read('main.lua')
        assert z.read('assets/character_side_bake/atlas.png')==atlas.read_bytes()
        assert z.read('assets/character_side_bake/manifest.json')==manifest.read_bytes()
    print('TAMU_3D_SPECIAL_LOVE_OK',out,out.stat().st_size,
          hashlib.sha256(out.read_bytes()).hexdigest())

if __name__=='__main__':
    main()
