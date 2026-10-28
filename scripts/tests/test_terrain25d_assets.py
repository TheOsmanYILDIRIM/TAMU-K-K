import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import terrain25d_assets as a
from PIL import Image

class AssetTests(unittest.TestCase):
    def test_determinism_uv_pixels_gate_and_duplicates(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            items = []
            for n, family in enumerate(['grass','forest','dirt','rock','wetland','oak','conifer','boulder','shrub','reeds']):
                kind = 'terrain' if family in a.TERRAIN else 'object'
                name = f'{family}.png'
                img = Image.new('RGBA', (128,128), (n * 17,20,60, 128 if kind=='object' else 255))
                img.putpixel((0,0),(12,23,34,0 if kind=='object' else 255))
                img.save(p/name)
                items.append({'kind':kind,'family':family,'source_drive_id':f'drive{n}', 'local_file':str(p/name), 'original_filename':name,'license_status':'approved','license_evidence':'synthetic-test'})
            items.append({**items[0], 'source_drive_id':'duplicate-binary'})
            items.append({**items[1], 'source_drive_id':'unauthorized', 'license_status':'unknown'})
            catalog={'version':1,'assets':items}
            d1,d2=p/'a',p/'b'
            m1=a.package(catalog,d1)
            m2=a.package({'version':1,'assets':list(reversed(items))},d2)
            self.assertEqual((d1/'manifest.json').read_bytes(),(d2/'manifest.json').read_bytes())
            self.assertEqual(9,len(m1['assets']))
            self.assertEqual(3,len(m1['rejected']))
            for page in m1['atlas_pages']:
                self.assertEqual((d1/page['filename']).read_bytes(), (d2/page['filename']).read_bytes())
                self.assertEqual(page['sha256'],hashlib.sha256((d1/page['filename']).read_bytes()).hexdigest())
            for item in m1['assets']:
                x,y,w,h=item['uv_rect']
                self.assertTrue(0<=x and 0<=y and x+w<=1 and y+h<=1)
                with Image.open(d1/item['atlas_page']) as atlas:
                    rect=(round(x*atlas.width),round(y*atlas.height))
                    with Image.open(p/item['original_filename']) as source:
                        self.assertEqual(atlas.crop((*rect,rect[0]+128,rect[1]+128)).tobytes(), source.convert('RGBA').tobytes())
    def test_invalid_size(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'bad.png'; Image.new('RGB',(64,64)).save(p)
            ok, bad=a.audit([{'family':'grass','kind':'terrain','source_drive_id':'x','original_filename':'bad.png','local_file':str(p),'license_status':'approved','license_evidence':'review'}])
            self.assertFalse(ok);self.assertIn('invalid_dimensions',bad[0]['reasons'])

if __name__ == '__main__': unittest.main()
