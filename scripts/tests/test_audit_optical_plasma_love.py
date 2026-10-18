import importlib.util
import io
import pathlib
import tempfile
import unittest
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("auditor", root / "audit_optical_plasma_love.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def archive(files):
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w") as z:
        for path, value in files.items():
            z.writestr(path, value)
    return out.getvalue()


class OpticalGateTests(unittest.TestCase):
    def test_empty_game_is_not_optical_art(self):
        r = mod.audit_love(archive({"main.lua": "return true"}), "fixture.love")
        self.assertEqual(r["status"], "missing_art")
        self.assertEqual(r["missing_count"], 103)
        self.assertFalse(r["render_ready"])
        self.assertFalse(r["visual_accepted"])

    def test_one_frame_is_not_102_frames(self):
        r = mod.audit_love(archive({"main.lua": "return true",
                                   mod.CORE: b"fake core",
                                   mod.FRAMES[0]: b"fake frame"}), "fixture.love")
        self.assertEqual(r["frame_count"], 1)
        self.assertEqual(r["missing_count"], 101)
        self.assertFalse(r["render_ready"])

    def test_no_entrypoint(self):
        r = mod.audit_love(archive({"README": "hi"}), "fixture.love")
        self.assertFalse(r["entrypoint_present"])
        self.assertFalse(r["render_ready"])

    def test_nested_artifact_is_supported_without_upload(self):
        love = archive({"main.lua": "return true"})
        with tempfile.TemporaryDirectory() as d:
            path = pathlib.Path(d) / "artifact.zip"
            path.write_bytes(archive({"out/game.love": love}))
            content, name = mod.choose_love(str(path))
            self.assertEqual(name, "out/game.love")
            self.assertEqual(content, love)
            self.assertFalse(mod.audit_love(content, name)["render_ready"])

    def test_alpha_required(self):
        hdr = mod.PNG_SIG + b"\x00\x00\x00\rIHDR" + (
            20).to_bytes(4, "big") + (20).to_bytes(4, "big") + bytes([8, 2, 0, 0, 0])
        with self.assertRaises(ValueError):
            mod.png_info(hdr)


if __name__ == "__main__":
    unittest.main()
