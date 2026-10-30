"""Regression checks for bounded JSONL analysis; standard library only."""
import json
import tempfile
import unittest
from pathlib import Path
from analyze_tamu_diagnostics import analyse

class TestTelemetry(unittest.TestCase):
    def test_rotation_and_shadow_correlation(self):
        with tempfile.TemporaryDirectory() as d:
            a=Path(d)/"tamu-trace-0.jsonl"
            b=Path(d)/"tamu-trace-1.jsonl"
            def frame(n, dt, shadow):
                return {"schema":2,"kind":"frame","session":"S","frame":n,
                    "t":n/60,"dt_ms":dt,"frame_ms":dt,"draw_ms":dt-6,
                    "update_ms":6,"shadow_rebuilds":shadow,
                    "contact_rebuilds":shadow,"shader_switches":3,
                    "phases":{"shadows_ms":dt-10}}
            a.write_text("\n".join(json.dumps(x) for x in [
                frame(3,43,2),frame(4,16,2)])+"\n")
            b.write_text("\n".join(json.dumps(x) for x in [
                frame(1,16,1),frame(2,16,1)])+"\n")
            report=analyse([a,b]); sess=report["sessions"][0]
            self.assertEqual(sess["frames"],4)
            self.assertEqual(sess["slow_frame_count"],1)
            self.assertEqual(sess["slow_vs_all"]["shadow_rebuilt_this_frame"]["slow_rate"],1)
            self.assertEqual(sess["slow_vs_all"]["shadow_rebuilt_this_frame"]["all_rate"],.25)
            self.assertEqual(sess["metrics"]["shader_switches"]["p50"],3)

    def test_corrupt_jsonl(self):
        with tempfile.TemporaryDirectory() as d:
            a=Path(d)/"bad.jsonl"
            a.write_text('{"kind":"frame","schema":2,"session":"S","frame":1,"dt_ms":16}\n{"cut":')
            report=analyse([a])
            self.assertEqual(report["invalid_lines"],1)
            self.assertEqual(report["sessions"][0]["frames"],1)

if __name__=="__main__":
    unittest.main()
