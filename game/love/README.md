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

**Sınırlar:** LÖVE `draw_ms` GPU beklemesi içerebilir; GPU nanosaniye
zamanlayıcısı değildir. `texture_mib` sürücünün raporladığı tahmindir.
Ölçümün kendisi yük oluşturur; `TAMU_DIAGNOSTICS=0` kontrolü ile A/B
kıyaslama yapılmalıdır. JSONL dosyası analiz için bilgisayara aktarılabilir;
oyuncu kimliği, konum, ağ isteği, envanter verisi ve kimlik bilgileri yazılmaz.

