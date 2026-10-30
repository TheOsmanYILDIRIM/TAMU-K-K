# Oyun — LÖVE2D 2D world runtime

The 2D engine lives in `game/love/` on `main`, with an
independent `experiment/world-2d-design-20261012` history. The Godot 3D scaffold
in the repository root is **historical**, not the agreed 45-degree 2D direction.
The branch is intentionally isolated: do not merge the old branch wholesale
into `main`, because `main` contains newer Object Studio changes.

## Run

Install LÖVE 11.5 on desktop and launch from repository root:

```sh
love game/love
```

Keyboard: WASD/arrows pan the camera; mouse drag to pan, wheel to zoom,
click polygon to select, R to reset, Escape to clear. On Android:
one-finger drag pans, tap selects, two-finger pinch zooms; on-screen
+/−/R controls work with touch. UI accommodates portrait dimensions,
resizes and safe-area insets.

The main entrypoint now includes seeded continuous terrain, Marching Squares,
chunk streaming, player physics/A*, object harvesting and traversable water.
Resource gameplay constants are generated from JSON catalog for packaged LÖVE.
The older polygon scene remains a Stage 1 test fixture. Stage5 crafting, inventory and workbench placement are playable on main.
Stage6 save/recovery and detached Stage5 transaction bridge are opt-in only
via OSMAN_STAGE6_EXPLICIT=1 and an explicit world UUID. Autosave and crash-
durable Android filesystem guarantees remain unverified; no production save
is silently created. Android APK and networking are not yet verified. World units are continuous,
no visible tilemap.

## Test

```sh
cd game/love
lua5.4 tests/run.lua
lua5.4 tests/runtime.lua
find . -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
```

GitHub Actions `LOVE biome core validation` performs Lua syntax and unit
tests and launches the real LÖVE render loop under Xvfb for three frames
on the experiment branch. CI proves startup/render smoke, **not** visual
correctness or Android compatibility. Those require real engine and device
tests in subsequent work.

## Boundaries

Preserve backup branch, `main`, World Builder, Terrain Studio, Object Studio,
other experiment branches, external assets, IndexedDB, and user saves.
No texture files were added; existing 18 terrain variants are out of scope.

## Core stat progression V1 (session-only)

Player gains general character XP from successful RAM-only resource harvest/craft/build.
Character level rewards free stat points; STATS touch panel or keyboard P spends them.
Core Level is separate: all six stats share a ceiling and all Core types share normal
skill capacity at the same Core level. Future skill definitions unlock typed actions
and earn separate usage XP; feat/proficiency systems are not adopted.

Run: cd game/love && lua5.4 tests/core_stat_progression.lua
Also run LuaJIT, quality CI and real LÖVE/Xvfb production UI smoke.

IMPORTANT: numeric curves are provisional. This demo does NOT upgrade Core,
transfer consciousness, activate skills, or persist progression in save_v2.
Stage6 explicit play does NOT award session XP to avoid non-atomic cross-save commits.
The HUD displays SESSION ONLY / NOT SAVED. Do not mistake test snapshot/restore
for production durable saving. A new versioned save contract and migration are required.

## Android Diagnostics JSONL — production triage (experiment)

Existing `core/diagnostics.lua` is **enabled by default on Android** and off by
default on desktop. It writes bounded JSONL files inside LÖVE's save directory,
not inside the .love archive:

- `diagnostics/tamu-trace-0.jsonl` through `tamu-trace-2.jsonl`, rotated
  at 4 MiB per file (approximately 12 MiB total).
- Schema v2 `session_start`, per-frame `frame`, `slow_frame`,
  `window_summary` (5-second p50/p95/p99 and stage averages),
  `chunk_coverage_changed`, `chunk_pending_changed`, `shadow_rebuilt`,
  `app_focus`, `app_visibility`, `android_low_memory`, `fatal_error`,
  and `session_end`.
- `frame_ms` is a **frame-pacing approximation** derived from dt and measured
  update/draw wall time. `draw_ms` can include driver stalls; neither is an
  actual GPU timestamp. `getStats()` is draw-call/texture telemetry.
- Unhandled errors, focus/background transitions, and memory warnings are
  flushed; every 2 seconds or 64 KiB also flushes. Trace I/O overhead is
  recorded as `trace_write_ms`.
- The save-directory location is printed at startup under
  `TAMU_DIAGNOSTICS_START save_dir=...`. Android access to app-private
  storage depends on the installed LÖVE client and Android version.
- Set `TAMU_DIAGNOSTICS=0` to disable collection; on a desktop
  `TAMU_DIAGNOSTICS=1` enables the same data format.

Once trace files have been copied from the device, run:

```sh
python3 scripts/analyze_tamu_diagnostics.py tamu-trace-*.jsonl --output report.json
```

The offline analyzer accepts v1/v2 files and reports per-session frame
distribution, hot phases, and correlations between slow frames and shadow,
pending-chunk, and missing-chunk counters. It does **not** claim causal
attribution where GPU fences or hardware counters were not measured.

## Manual performance investigation: 10x long traversal (expensive)

Run **only** after chunk streaming, terrain, GPU allocation, cache, camera, or
memory behavior changes, when investigating frame stalls, or before a risky
performance release. **Do not** run for routine edits, small tests, asset/UI
changes, or every CI push. Standard Lua regression parses the profiler only;
the full traversal is never part of routine `quality.yml`.

From the repository root, on a system with LÖVE, Python3, `timeout` and
optionally Xvfb:

```sh
bash game/love/tests/run_r2_long_traversal.sh
```

The script uses an **isolated disposable XDG_DATA_HOME** and three real-engine
runs (cache off / cold / warm), with the same seed, 10x scripted world-space
movement and two laps across a large area. Each **actual rendered frame** gets
wall-clock frame-ms/derived instantaneous FPS, update/terrain/object timings,
mesh allocation call durations, cache counters, resident/pending/build jobs,
memory and GPU-reported counters in CSV. A separate timestamped event log
correlates sudden spikes with chunk generation/eviction, mesh completion,
cache reads/writes, background prefetch, and large heap drops. One JSON summary
per mode gives p50/p95/p99/max and stall counts. Evidence is retained in the
path printed by the runner, which has a default 120-second **per-mode** timeout
(overridable with `OSMAN_PROFILE_TIMEOUT_SEC`). The test's virtual 10x travel
speed does **not** accelerate actual CPU/GPU work, and it does **not** validate
player collision, Android hardware FPS, or GPU execution timestamps.

The expensive GitHub cache workflow is explicitly `workflow_dispatch`-only;
the long-run test can be run manually with the script above when needed. Do not
treat an unexecuted or skipped long-run test as passing.

## Creative inşaat — LÖVE 2,5D teknik önizleme

Creative oyun modu varsayılan 2,5D R2 sahnesinde **CREATIVE** düğmesiyle açılır
(klavye **C**). Açınca 13 parça türünden seç, haritada dokunarak konum belirle,
**PLACE / BUILD** düğmesine bas. **TURN**, **FLOOR +/-**, **UNDO** ile döndür,
kat seviyesini değiştir ve son yerleştirmeyi geri al. Parmağınla sürükleyerek
kamerayı taşı; mouse tekerleği/pinch ile yakınlaştır. **Q**, **Enter**, **[**, **]**,
**Backspace** de aynı işlevleri sağlar.

Bağlantılar 32 birimlik dünya grid ve yakındaki temel yüksekliğiyle hizalanır.
Ücretsiz Creative uygulaması Stage5 üretim ekonomisine ve Stage6 kayıtlara
yazmaz; kalıcı bina ve çok oyunculu işlemler sonraki geliştirmedir.
Yapı görselleri 128×128/64 renk sınırında kodla üretilen 34 görünümlü
prototip atlasa dayanır. Bu, gerçek Android APK veya FPS kabulü değildir.

Paketleme: `python scripts/package_tamu_love.py --repo . --output /tmp/TAMU_KOK_Creative_25D.love`
(kaynak katalog için Lua 5.4, atlas üretimi için Pillow gerekir).
`TAMU_CREATIVE_SMOKE=1` ile paketi Xvfb üzerinde açarak gerçek .love kontrolü yapılır.

## TAMU Android tanılama ve performans kayıtları (JSONL v1)

Android'de varsayılan açık; masaüstünde yalnız `TAMU_DIAGNOSTICS=1` ile etkin.
Kapatmak için `TAMU_DIAGNOSTICS=0`. Kayıtlar LÖVE'nin
`love.filesystem.getSaveDirectory()` dizininde `diagnostics/tamu-trace-0.jsonl`,
`tamu-trace-1.jsonl`, `tamu-trace-2.jsonl` dosyalarına yazılır
(her biri yaklaşık 4 MiB döngüsel sınır, toplam yaklaşık 12 MiB).
Oyun save/checkpoint verileri değiştirilmez.

Her JSONL satırı bağımsız JSON nesnesidir (`schema:1`,
`session`, `t` monotonic saniye ve `frame`).
`session_start`: Android/DPI/framebuffer bilgileri.
`frame`: `dt_ms`, `update_ms`, `draw_ms`,
`phases` (terrain, objeler, gölge, Rigby, sprite, HUD),
GPU sürücüsünün sunduğu `drawcalls`, `shaderswitches`,
`texture_mib`, Lua KiB, chunk/obje sayısı ve gölge cache sayaçları.
`slow_frame`: 34 ms üzeri kare aralığı, 25 ms üzeri draw veya
12 ms üzeri update. `summary`: 5 saniyelik durum.
`fatal_error` olayları varsayılan LÖVE hata ekranını bozmadan kaydedilir.
Buffer en geç 2 saniyede ya da 64 KiB'de diske gönderilir;
`trace_write_ms` tanılama yazma maliyetidir.

Çevrimdışı analiz: `python3 scripts/analyze_tamu_diagnostics.py tamu-trace-*.jsonl --output report.json`.
Rapor oturum bazında p50/p95/p99 ölçümlerini, faz sürelerini, en yavaş 12 kareyi,
bozuk satır sayısını ve olay türlerinin sayılarını üretir. JSONL dosyalarını
gönderirken hata mesajlarını kontrol edin; oturum loglarını yalnız güvenilir
kanallarda paylaşın. Konsol başlangıcında `love.filesystem.getSaveDirectory()`
ile gerçek kayıt dizini öğrenilebilir.

**Son kare dışa aktarma (ek):** Masaüstü klavyesinde `F10`, son 120 kareyi
`diagnostics/tamu-export-recent.jsonl` dosyasına yerel olarak yazar.
Otomatik paylaşım yoktur. Android dokunmatik dışa aktarma düğmesi henüz yoktur.
Hata olaylarının ham mesajı tutulmaz; yalnız korelasyon hash'i ve uzunluğu kaydedilir.
Bu özelliklerin gerçek Android dosya/izin doğrulaması ve performans overhead testi açıktır.

**Sınırlar:** LÖVE `draw_ms` GPU beklemesi içerebilir; GPU nanosaniye
zamanlayıcısı değildir. `texture_mib` sürücünün raporladığı tahmindir.
Ölçümün kendisi yük oluşturur; `TAMU_DIAGNOSTICS=0` kontrolü ile A/B
kıyaslama yapılmalıdır. JSONL dosyası analiz için bilgisayara aktarılabilir;
oyuncu kimliği, konum, ağ isteği, envanter verisi ve kimlik bilgileri yazılmaz.


## Prebaked static object-shadow atlases (experimental, not device-accepted)

The approved 128px object variants are **not resized or overwritten**. Trees
are rendered at a larger world scale; the Rigby character, collision and
gameplay world coordinates are unchanged. The package builder reads the
checked-in `assets/terrain25d/atlas_01.png`, precomposes objects and their
ground shadows, and generates **eight 3-hour time slots**, each split into
four 2048px-or-smaller PNG pages (32 separate PNG atlas pages total).

`python3 scripts/package_tamu_love.py --repo . --output /tmp/tamu-static.love`
automatically includes `assets/terrain25d/static_shadow/` and a versioned
manifest. The runtime chooses the nearest slot and draws its precomposited
objects in one pass; the old per-frame projected shadow/contact passes are
bypassed **only when the complete baked manifest is packaged**. Running the
unpackaged source preserves the legacy shadow path. Static shadow lighting
changes in 3-hour increments, not continuously.

The atlas generator is `scripts/build_tamu_static_shadow_atlases.py`; Pillow
is required at build time, not on the device. Lua 5.4/LuaJIT regression is
`tests/terrain25d_static_shadows.lua`. **Android FPS, generated PNG inspection,
visual shadow/overlap acceptance and actual packaging CI remain unverified**.
Do not merge without these checks. Approximate precomposed shadows can differ
from the prior two-layer live projections.

## 32px texture-derived static shadows (experiment)

The source `atlas_01.png` remains the full-resolution 128px object atlas.
The Python builder uses each variant's actual alpha to generate 32x32
shadow masks in **eight separate small time-of-day atlas pages**. The
`package_tamu_love.py` build embeds these pages; at runtime the shadow
batch is drawn once underneath the original full-resolution object sprites.
No realtime rotated RGBA silhouettes or procedural contact ellipses run in
this packaged path. Fallback without a manifest still uses legacy shadows.

CI validates shadow page count, dimensions, and embedded manifest. Actual
Android visual and performance acceptance are still open. The 3-hour shadow
slots deliberately step rather than continuously animate.

## Startup render isolation (experimental)

A lightweight selector loads before any original gameplay modules. Seven
profiles: full game, Rigby-only, **authored R2 terrain-only**, objects-only,
R2 terrain+objects, character+objects, and empty-engine baseline.

R2 terrain modes instantiate the existing authored R2 query, real 25D terrain
renderer and chunk streamer, with their actual baked-cache/worker paths.
They do not create the object renderer, Rigby or gameplay update loop unless
those layers were selected. Objects-only is still a controlled 24-object
sprite atlas baseline rather than the original procedural ecology; do not
mistake this mode for a full-world object benchmark.

All isolated profiles accept single-finger drag, mouse drag, two-finger pinch,
wheel zoom and WASD/arrow camera movement. For accurate A/B comparison, fully
restart the app before switching profiles. Full game loads original modules
after its selection; CI=true keeps the previous direct production entrypoint,
and TAMU_ISOLATION_BOOT=1 forces the selector for test runs. Device FPS,
camera/visual checks and regression acceptance still require testing.

## Matched full-world render diagnosis (experimental)

The startup menu now prioritizes comparable full-world modes. Each comparison
loads the same authored R2 world, normal stream, original 137-ish visible
population (count varies with camera), player and gameplay logic. It gates
only drawing: terrain only, objects only, Rigby only, terrain+objects,
all except HUD, all except Rigby, and full reference. A blank engine mode is
retained as a separate non-equivalent baseline.

Unlike the older 24-object synthetic preview, these matched profiles run the
original object collection and depth sorting with the same camera/world
context; disabled rendering does not imply disabling gameplay CPU work.
The 25D renderer still prepares resident terrain/chunks even when its GPU
terrain draws are suppressed, retaining object discovery and texture readiness.
These are **draw-stage isolation tests**, not independent no-call system tests.
Interpret all FPS comparisons with that explicit distinction. Reboot the app
to switch profiles. Android CI and visual correctness remain to be confirmed.
