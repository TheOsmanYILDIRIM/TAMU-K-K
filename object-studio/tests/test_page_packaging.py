import json
import tempfile
import unittest
from pathlib import Path
from sys import path as sys_path
sys_path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from assemble_pages import assemble

A='a'*40
B='b'*40

class PackagingTest(unittest.TestCase):
    def test_preserves_world_links_and_object_studio(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);prev=p/'world';studio=p/'object';prev.mkdir();studio.mkdir()
            (prev/'index.html').write_text('<link href="./style.css"><script src="./app.js"></script><div class="legend">')
            (prev/'style.css').write_text('body{color:#fff}')
            (prev/'app.js').write_text('const BUILD="__BUILD_SHA__";')
            (prev/'assembly.html').write_text('<script src="./assembly.js"></script>')
            (prev/'assembly.js').write_text('const VERSION="__BUILD_SHA__"')
            (studio/'index.html').write_text('<h1>OBJECT STUDIO</h1>')
            (studio/'latest.html').write_text('<h1>OBJECT STUDIO</h1>')
            (studio/'build.json').write_text(json.dumps({'sha':B}))
            (studio/'character-rig.html').write_text('<h1>CHARACTER RIG STUDIO</h1>')
            out=assemble(prev,studio,p/'_site',A,B)
            self.assertIn('CHARACTER RIG STUDIO',(out/'index.html').read_text())
            self.assertIn('object-studio/latest.html',(out/'world-builder.html').read_text())
            self.assertEqual(json.loads((out/'build.json').read_text())['sha'],A)
            self.assertEqual(json.loads((out/'object-studio/build.json').read_text())['sha'],B)
            self.assertEqual(len(list(out.glob('assembly.*.js'))),1)
            self.assertIn(A,list(out.glob('assembly.*.js'))[0].read_text())
            self.assertTrue((out/'.nojekyll').exists())
    def test_refuses_to_overwrite_site(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);(p/'out').mkdir()
            with self.assertRaises(FileExistsError):
                assemble(p/'prev',p/'studio',p/'out',A,B)

if __name__=='__main__':
    unittest.main()
