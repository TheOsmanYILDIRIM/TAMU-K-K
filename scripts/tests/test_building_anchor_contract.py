import sys
import unittest
import tempfile
from PIL import Image
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from building_anchor_contract import (Point,Edge,require_match,segment_x,
    endpoints_match,snap_translation,house_2x2_plan,to_manifest)

class AnchorContractTest(unittest.TestCase):
    def test_eaves_ridge_gables_no_gap(self):
        plan=house_2x2_plan()
        self.assertEqual(len(plan['matches']),14)
        self.assertEqual(len(plan['pieces']),24)
        self.assertTrue(all(m['error_world']==0 for m in plan['matches']))
        self.assertEqual(plan['world']['wall_top'],30)
        self.assertEqual(plan['world']['ridge_z'],42)
        self.assertIn('gable_flanks',to_manifest(plan)['anchors'])

    def test_wrong_height_rejected(self):
        good=segment_x('wall',0,48,30)
        shifted=segment_x('roof',0,48,31)
        with self.assertRaisesRegex(ValueError,'endpoint_mismatch'):
            require_match(good,shifted)

    def test_wrong_angle_and_size_rejected(self):
        good=segment_x('wall',0,48,30)
        wrong=Edge('roof',Point(0,32,30),Point(0,64,30),'roof_eave')
        self.assertFalse(endpoints_match(good,wrong)[0])
        too_long=segment_x('too-long',0,48,30)
        too_long=Edge('long',too_long.a,Point(17,48,30),'roof_eave')
        self.assertFalse(endpoints_match(good,too_long)[0])
        with self.assertRaises(ValueError):
            require_match(good,too_long)

    def test_kind_rejected(self):
        one=segment_x('w',0,48,30)
        two=Edge('r',one.a,one.b,'ridge')
        self.assertEqual(endpoints_match(one,two)[1],'incompatible_kind')

    def test_roof_slope_does_not_fake_a_gable_wall(self):
        from building_anchor_demo import render_shape
        from building_anchor_contract import screen
        roof=render_shape('roof_slope',0)
        # The roof side must remain transparent below its slope;
        # separate gable pieces own this vertical triangular infill.
        x,y=screen(Point(16,0,3))
        self.assertEqual(roof.getpixel((round(x),round(y)))[3],0)
        x,y=screen(Point(0,0,6))
        self.assertGreater(roof.getpixel((round(x),round(y)))[3],0)

    def test_house_render_and_anchor_overlay(self):
        from building_anchor_demo import make_review
        with tempfile.TemporaryDirectory() as folder:
            out=Path(folder)
            manifest=make_review(out)
            self.assertEqual(len(manifest['matches']),14)
            for filename in ('01_foundation.png','02_walls.png','03_roof.png',
                             '04_anchor_overlay.png','05_comparison_strip.png'):
                path=out/filename
                self.assertTrue(path.is_file(),filename)
                with Image.open(path) as image:
                    image.load()
                    self.assertGreater(image.width,200)
            with Image.open(out/'03_roof.png') as im:
                self.assertIsNotNone(im.getchannel('A').getbbox())
            # Real scene renders 24 distinct instances, not a stretched platform.
            self.assertEqual(manifest['preview_records'][2]['instances'],24)

    def test_anchor_snap_only_translates_exact_geometry(self):
        parent=Edge('parent',Point(0,0,30),Point(32,0,30),'roof_eave')
        child=Edge('child',Point(32,0,0),Point(0,0,0),'roof_eave')
        move=snap_translation(parent,child)
        self.assertEqual(move,Point(0,0,30))
        bad=Edge('bad',Point(30,0,0),Point(0,0,0),'roof_eave')
        with self.assertRaises(ValueError):
            snap_translation(parent,bad)

if __name__=='__main__': unittest.main()
