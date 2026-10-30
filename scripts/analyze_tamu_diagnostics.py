#!/usr/bin/env python3
"""TAMU JSONL diagnostics analyser. Standard library; offline and read-only.

Usage: python3 scripts/analyze_tamu_diagnostics.py path/to/tamu-trace-*.jsonl
"""
import argparse
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path

def percentile(values, fraction):
    if not values:
        return 0.0
    values = sorted(values)
    return round(values[max(0, math.ceil(len(values) * fraction) - 1)], 3)

def analyse(paths):
    events = []
    invalid = 0
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            for line_no, line in enumerate(handle, 1):
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                    if record.get("schema") not in (1, 2) or not isinstance(record.get("kind"), str):
                        invalid += 1
                        continue
                    record["_file"] = str(path)
                    events.append(record)
                except (ValueError, TypeError):
                    # Power loss may leave a final incomplete JSONL record.
                    invalid += 1
    frames = [r for r in events if r["kind"] == "frame"]
    by_session = defaultdict(list)
    for r in frames:
        by_session[r.get("session", "unknown")].append(r)
    sessions = []
    for sid, rows in by_session.items():
        fields = ["frame_ms", "fps", "dt_ms", "update_ms", "draw_ms", "drawcalls",
                  "shaderswitches", "texture_mib", "lua_kib",
                  "chunks", "objects", "missing", "pending",
                  "trace_write_ms"]
        phase_names = sorted({k for r in rows for k in (r.get("phases") or {})})
        metrics = {}
        for key in fields:
            samples = [r[key] for r in rows if isinstance(r.get(key), (int, float))]
            metrics[key] = {"p50": percentile(samples, .50),
                            "p95": percentile(samples, .95),
                            "p99": percentile(samples, .99),
                            "max": round(max(samples), 3) if samples else 0}
        phases = {}
        for name in phase_names:
            samples = [(r.get("phases") or {}).get(name) for r in rows]
            samples = [v for v in samples if isinstance(v, (int, float))]
            phases[name] = {"p50": percentile(samples, .50),
                            "p95": percentile(samples, .95),
                            "p99": percentile(samples, .99)}
        slow = sorted(rows, key=lambda r: max(r.get("dt_ms", 0),
                     r.get("draw_ms", 0)), reverse=True)[:12]
        sessions.append({
            "session": sid, "frames": len(rows),
            "metrics": metrics, "phases": phases,
            "slowest": [{"frame": r.get("frame"), "dt_ms": r.get("dt_ms"),
                         "update_ms": r.get("update_ms"), "draw_ms": r.get("draw_ms"),
                         "phases": r.get("phases"), "objects": r.get("objects"),
                         "missing": r.get("missing")} for r in slow]
        })
    counts = Counter(r["kind"] for r in events)
    return {"format": "tamu-diagnostics-analysis-v1", "files": len(paths),
            "invalid_lines": invalid, "event_counts": dict(counts),
            "sessions": sessions}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, help="Optional destination JSON")
    args = parser.parse_args()
    result = analyse(args.files)
    encoded = json.dumps(result, indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(encoded + "\n", encoding="utf-8")
    else:
        print(encoded)

if __name__ == "__main__":
    main()
