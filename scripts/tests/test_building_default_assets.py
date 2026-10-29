"""Deterministic code-generated construction visuals: no prompt or R2 dependency."""
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
GEN=ROOT/'scripts/building_default_assets.py'
EXP=ROOT/'scripts/export_building_parts.lua'


class DefaultConstructionAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory()
        cls.base=Path(cls.tmp.name)
        cls.catalog=cls.base/'catalog.json'
        # Lua must provide the canonical definitions; do not embed a second list.
        with cls.catalog.open('wb') as f:
            subprocess.run(['lua5.4',str(EXP)],cwd=ROOT,check=True,stdout=f)
        cls.output=cls.base/'output'
        subprocess.run([sys.executable,str(GEN),'--catalog',str(cls.catalog),
            '--output',str(cls.output)],cwd=ROOT,check=True)
        cls.manifest=json.loads((cls.output/'building_default_manifest.json').read_text())

    @classmethod
    def tearDownClass(cls): cls.tmp.cleanup()

    def test_registry_and_atlas(self):
        m=self.manifest
        self.assertEqual(len(m['entries']),76)
        self.assertEqual(len({(x['def_id'],x['rotation']) for x in m['entries']}),76)
        self.assertEqual(m['canvas'],[128,128])
        self.assertEqual(m['directions'],['south','west','north','east'])
        with Image.open(self.output/m['atlas']['filename']) as atlas:
            self.assertEqual(atlas.mode,'RGBA')
            self.assertEqual(atlas.size,(1024,1280))
            for e in m['entries']:
                sprite=self.output/'sprites'/e['filename']
                with Image.open(sprite) as im:
                    self.assertEqual(im.mode,'RGBA')
                    self.assertEqual(im.size,(128,128))
                    self.assertLessEqual(e['colors'],64)
                    self.assertEqual(len({p[:3] for p in im.get_flattened_data() if p[3]>0}),e['colors'])
                    self.assertEqual(hashlib.sha256(sprite.read_bytes()).hexdigest(),e['sha256'])
                    self.assertTrue(im.getchannel('A').getextrema()[0]==0)
                    self.assertGreater(im.getchannel('A').getextrema()[1],0)
                    x,y,w,h=e['atlas_rect']
                    self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),im.tobytes())
        self.assertEqual(hashlib.sha256((self.output/m['atlas']['filename']).read_bytes()).hexdigest(),m['atlas']['sha256'])

    def test_actual_four_piece_assembly(self):
        m=self.manifest
        four=m['assembly_2x2']
        self.assertEqual(len(four),4)
        self.assertEqual({tuple(x['world']) for x in four},
            {(0,0,0),(32,0,0),(0,32,0),(32,32,0)})
        self.assertEqual(len({tuple(x['pixel_origin']) for x in four}),4)
        self.assertEqual(len(m['assembly_L']),3)
        for name in ('foundation_2x2.png','foundation_L.png'):
            with Image.open(self.output/name) as im:
                self.assertEqual(im.mode,'RGBA')
                self.assertGreater(im.getchannel('A').getbbox()[2]-im.getchannel('A').getbbox()[0],90)
                bbox=im.getchannel('A').getbbox()
                self.assertGreater(bbox[0],0)
                self.assertGreater(bbox[1],0)
                self.assertLess(bbox[2],im.width)
                self.assertLess(bbox[3],im.height)

    def test_openings_and_slope_exist(self):
        entries={(e['def_id'],e['rotation']):e for e in self.manifest['entries']}
        def sprite(id,rot=0):
            return Image.open(self.output/'sprites'/entries[(id,rot)]['filename']).convert('RGBA')
        for shape in ('doorway','window'):
            im=sprite('tamu:'+shape+'_wood')
            # The center of the clear opening has no painted 'black hole'.
            self.assertEqual(im.getpixel((64,68))[3],0)
            self.assertGreater(im.getchannel('A').getbbox()[2],64)
        im=sprite('tamu:roof_slope_wood')
        self.assertGreater(im.getchannel('A').getbbox()[3]-im.getchannel('A').getbbox()[1],20)

    def test_reproducible_atlas(self):
        second=self.base/'repeat'
        subprocess.run([sys.executable,str(GEN),'--catalog',str(self.catalog),
            '--output',str(second)],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
        self.assertEqual((second/'building_default_atlas.png').read_bytes(),
                         (self.output/'building_default_atlas.png').read_bytes())

if __name__=='__main__': unittest.main()
