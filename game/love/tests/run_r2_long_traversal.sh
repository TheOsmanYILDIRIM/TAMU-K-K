#!/usr/bin/env bash
# EXPENSIVE, ON-DEMAND ONLY. Never used by routine quality.yml.
# Deterministic 10x virtual travel; all FPS/ms values are REAL wall-clock samples.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"
command -v love >/dev/null || { echo "LÖVE runtime required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "Python3 required" >&2; exit 2; }
max_seconds="${OSMAN_PROFILE_TIMEOUT_SEC:-120}"
[[ "$max_seconds" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid timeout" >&2; exit 2; }
output="${1:-$(mktemp -d "${TMPDIR:-/tmp}/osman-r2-long-XXXXXXXX")}"
mkdir -p "$output" "$output/isolation"
output="$(cd "$output" && pwd)"
export XDG_DATA_HOME="$output/isolation"
export OSMAN_R2_PILOT=1 OSMAN_CACHE_DISPLAY=360x780
unset OSMAN_STAGE6_EXPLICIT OSMAN_STAGE6_CREATE OSMAN_STAGE6_REOPEN_SMOKE
unset OSMAN_CHUNK_CACHE_SMOKE OSMAN_CHUNK_CACHE_BASELINE_SMOKE
unset OSMAN_CHUNK_CACHE_PREFETCH_SMOKE OSMAN_R2_G_SMOKE
echo "R2 10x virtual traversal / real frame timings / isolated save root"
for mode in baseline cold warm; do
  export OSMAN_R2_LONG_TRAVERSAL="$mode"
  if [[ "$mode" == baseline ]]; then
    export OSMAN_CHUNK_CACHE_PILOT=0
  else
    export OSMAN_CHUNK_CACHE_PILOT=1
  fi
  echo "Testing $mode (limit: ${max_seconds}s)..."
  if command -v xvfb-run >/dev/null; then
    timeout "$max_seconds" xvfb-run -a love game/love >"$output/$mode.log" 2>&1 || {
      tail -n 50 "$output/$mode.log"; exit 1;
    }
  else
    timeout "$max_seconds" love game/love >"$output/$mode.log" 2>&1 || {
      tail -n 50 "$output/$mode.log"; exit 1;
    }
  fi
  grep -q "R2_LONG_TRAVERSAL_OK mode=$mode " "$output/$mode.log" || {
    tail -n 50 "$output/$mode.log"; exit 1;
  }
  for suffix in frames.csv events.csv summary.json; do
    file="$(find "$XDG_DATA_HOME" -name "r2-long-$mode-$suffix" -print -quit)"
    test -n "$file" && test -s "$file"
    cp "$file" "$output/"
  done
  grep 'R2_LONG_TRAVERSAL_OK' "$output/$mode.log"
done
python3 - "$output" <<'PY'
import csv,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
runs={}
paths=[]
for mode in ('baseline','cold','warm'):
    data=json.loads((root/f'r2-long-{mode}-summary.json').read_text())
    with (root/f'r2-long-{mode}-frames.csv').open(newline='') as f:
        rows=list(csv.DictReader(f))
    with (root/f'r2-long-{mode}-events.csv').open(newline='') as f:
        events=list(csv.DictReader(f))
    assert data['mode']==mode and data['speed_multiplier']==10 and data['route_laps']==2
    assert data['frames']==len(rows) and 50<=len(rows)<=4000
    assert data['distinct_camera_chunks']>=18
    assert all(int(row['frame'])==i and float(row['frame_ms'])>0 and float(row['fps'])>0
               for i,row in enumerate(rows,1))
    assert any(e['event']=='frame_stall' for e in events)
    assert any(e['event']=='chunk_resident' for e in events)
    assert data['synthetic_motion'] and data['android_not_tested']
    movement=[]
    for row in rows:
        pos=(row['world_x'],row['world_y'])
        if not movement or movement[-1]!=pos: movement.append(pos)
    paths.append(movement)
    assert any(int(row['focal_ready'])==1 for row in rows)
    assert data['visibility_waits']>0 and data['frames_with_drawable_focal']>0
    runs[mode]=data
    print(f"{mode}: {len(rows)} frames, {data['distinct_camera_chunks']} camera chunks, "
          f"p95={data['frame_ms']['p95']:.2f}ms p99={data['frame_ms']['p99']:.2f}ms "
          f"max={data['frame_ms']['max']:.2f}ms stalls={data['stalls_over_33ms']}, "
          f"minFPS={data['min_fps']:.1f}")
assert paths[0]==paths[1]==paths[2], 'Camera paths differ; comparison invalid'
assert runs['cold']['cache'].get('misses',0)>0
assert runs['warm']['cache'].get('hits',0)>0
print('R2_LONG_TRAVERSAL_TRACE_OK: 10x virtual speed, same camera path, every-frame FPS/ms and event logs')
print('GPU driver execution time and Android performance were NOT measured.')
PY
echo "Evidence retained at $output (never touches real player save data)."
