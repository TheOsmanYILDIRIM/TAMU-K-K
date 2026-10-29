#!/usr/bin/env python3
"""Asset parity and truly image-backed placeholders acceptance."""
from pathlib import Path
import json,sys,unittest,tempfile,hashlib,zipfile,subprocess
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_creative_assets import generate
class CreativeAssetsTest(unittest.TestCase):
    def test_34_views_and_real_alpha(self):
        fixture=Path(__file__).parent/'sample_building_catalog.json'
        if fixture.is_file():
            catalog=json.loads(fixture.read_text('utf-8'))
        else:
            repository=Path(__file__).resolve().parents[1]
            catalog=json.loads(subprocess.check_output(['lua5.4','scripts/export_building_parts.lua'],cwd=repository))
        with tempfile.TemporaryDirectory() as folder:
            meta=generate(folder,catalog,Path(__file__).resolve().parents[1])
            self.assertEqual(len(meta['entries']),34)
            self.assertEqual(meta['atlas']['size'],[1024,640])
            with Image.open(Path(folder)/meta['atlas']['filename']) as atlas:
                self.assertEqual(atlas.size,(1024,640))
            for e in meta['entries']:
                with Image.open(Path(folder)/meta['atlas']['filename']) as atlas_image:
                    box=e['atlas_rect']
                    im=atlas_image.crop((box[0],box[1],box[0]+128,box[1]+128))
                    self.assertEqual(im.mode,'RGBA');self.assertEqual(im.size,(128,128))
                    colors={q[:3] for q in im.getdata() if q[3]>0}
                    self.assertLessEqual(len(colors),64)
                    self.assertTrue(im.getchannel('A').getbbox())
            self.assertEqual(len([e for e in meta['entries'] if e['shape']=='stairs']),4)
if __name__=='__main__':unittest.main()
