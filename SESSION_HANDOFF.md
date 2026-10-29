## 2026-10-29 — Live-rig review branch (not merged; remote assets pending)

- Current repository: TheOsmanYILDIRIM/TAMU-K-K. Branch:
  experiment/osman-rigby-4dir-20261029. Base main:
  497b98e1a361e4468994626cf82a2d3ff83cc2d2. This work does not merge or modify main.
- User explicitly authorized an alternate humanoid character on this experiment
  and rejected baked spritesheets. This scoped decision supersedes the old
  deferred-rig rule for this branch only. Preserve the original core/plasma
  implementation and assets; TAMU_USE_PLASMA=1 is the explicit rollback.
- Source implementation: player/rigby_runtime.lua (continuous sparse-key FK,
  Bezier interpolation, weighted mesh evaluation), player/rigby_visual.lua
  (reused LÖVE meshes, transitions, reflected anatomical right-hand sockets),
  objects/renderer.lua (idle/walk and target-facing mine/chop integration).
  Removed the rejected osman_sprite.lua implementation. No items were added.
- IMPORTANT: code is persisted, but the large original image/rig-data bundle
  has NOT been imported into GitHub. Complete data/tests are in the delivered
  self-contained .love and final source ZIP. A clean branch checkout is NOT
  playable with the new character until that bundle is imported. See existing
  game/love/assets/osman_rig/ASSETS_REQUIRED.md. Do not mark merge-ready.
- Actual local verification (Linux, official LÖVE 11.5 + Xvfb/OpenGL software
  rendering): all 44 clips rendered; production-world startup, water immersion,
  Stage4 harvest (stone=2), and unchanged plasma rollback passed. The packaged
  .love itself was launched and exited 0 with LOVE_INTEGRATION_SMOKE_OK.
- Native Lua 5.4 comparison with actual Rigby JS reference: 264 poses, 10560
  bone matrices, 224928 vertex checks, max absolute error 3.7252903e-9.
  Player/liquid/Stage4/Stage5, progression, explicit plasma tool contract and
  save_v2 regression passed locally (save_v2: 45 assertions). Mock graphics
  tests are recorded separately and are not real-engine or Android evidence.
- The prior branch quality run 40915376668 failed in the legacy plasma-only
  tool mock because the old sprite renderer had become the default. The test
  now explicitly selects the retained plasma mode; it passed locally. Full
  GitHub game CI is NOT claimed successful. The official-engine-download run
  40915376645 only retrieved a test dependency; that temporary workflow change
  is restored to the original package workflow in this source commit.
- Approved source: osman_saglak_4yon_v5.rigby,
  SHA256 86ed6aa3e40a082b9f7b67e9074a2d3b1149facb9c785a9e44956397ab22ad92.
  All 44 authored clips disable IK. Active IK/deform outside this narrow FK
  profile are explicitly rejected. No new combat/run logic, saves or physics.
- Open: import missing approved parts/data/tests from the final source bundle
  with current HEAD/blob checks, rerun targeted remote CI, review the .love on
  real Android, and obtain user approval before merge. Do not retry the blocked
  custom control-plane transfer or publish private signed download URLs.

---

# SESSION_HANDOFF — güncel LÖVE2D oyunu (2026-10-18)

## Son doğrulanmış entegrasyon
- Proje: `TheOsmanYILDIRIM/oyun`, `main`; bu devir yazılmadan önce bağımsızca geri doğrulanan oyun entegrasyonu HEAD: `578bf16667ce963c3f7a7d8dc1f1aef1ee2e2c0e`. Yeni çalışmada önce güncel HEAD ve CI yeniden okunur.
- Aktif mimari: `game/love/` LÖVE2D/Lua, 45° izometrik prosedürel biyomlar/Marching Squares/chunk, A*/CCD, 55% suda hız ve 50% immersion, Core/crystal shader + ön/arka plazma, axe/tool efektleri, Stage5 inventory/crafting/workbench, mobil HUD.
- Stage6: `game/love/save/` sürümlü checksum/checkpoint/recovery ve detached Stage5 transaction bridge `main`e entegre; **yalnız `OSMAN_STAGE6_EXPLICIT=1` ile açık world UUID verildiğinde** çalışır. Varsayılan autosave kapalıdır; `F5` checkpoint reload test arayüzü vardır. Önceki sağlam state recovery ve corruption quarantine testleri mevcuttur; journal bağımsız event replay sistemi değildir.
- Birleştirme güvenliği: tek hedefli Stage6 dalı çalışma ağacı güncel main görsel değişiklikleriyle karşılaştırıldı; 29 dosya farkı, eski ObjectRenderer çağrısı korunarak CAS fast-forward ile main'e taşındı. `main` üzerinde 9 GitHub Actions işi başarılı: quality, Stage4, Stage5, Stage6, biome, data, core plasma, world-player, liquid. Stage6 hedefli Lua 5.4/LuaJIT, failure-injection, gerçek LÖVE/Xvfb iki-ayrı-süreç save→close→reopen testi yeşil (main run #39122330953); Stage5 touch-HUD Xvfb artifact (main run #39122331022).
- Korunanlar: eski `backup/pre-portrait-reboot-20261011`, World/Terrain/Object Studio, Godot geçmişi, kullanıcı verileri, katalog ID/instance sözleşmesi, Core/plazma/shader/axe aktif özellikleri ve bağımsız deney dalları.
- Açık kabul kapıları: gerçek Android cihazda save/recovery ve fsync/rename/power-loss dayanıklılığı; APK/cihaz FPS-görsel doğrulaması; host-authoritative co-op; onaylanmamış Core stat/skill/level ve crafting/blueprint tasarımları. Bunlar otomatik olarak üretim kuralı veya tamamlanmış özellik sayılmaz.
- Kanonik kurallar: `AGENTS.md`, `README.md`, `docs/14_CORE_PLASMA_PROGRESSION_DESIGN.md`, `docs/19_LOVE_STAGE6_SAVE_ENGINE.md`, özel Avenox Beyin `agy-vault/main` görev/knowledge kayıtları. Sonraki adım: Android depolama semantiğini izole test edip varsayılan save etkinleştirmesine dair bağımsız karar vermek.

---

## Tarihsel devir (2026-10-11; artık aktif mimari veya açık iş listesi değildir)

# SESSION_HANDOFF — oyun Android portrait reboot (2026-10-11; tarihsel)

## Kanonik kaynaklar
- Repo: `TheOsmanYILDIRIM/oyun`, `main`; güncel HEAD ve CI mutlaka yeniden sorgulanır.
- Eski ana sürümün yedeği: `backup/pre-portrait-reboot-20261011` = `e079890dac6b8beef2aaaf9f52539d5701953afc`. Eski kod, testler, .tres ve APK workflow bu dalda korunuyor.
- Yeni main: eski commit'i ebeveyn alan yeni ağaç ve sonrasında normal fast-forward commitler; force/reset yok.

## Yapılanlar ve doğrulamalar
- Yeni README / AGENTS / mimari, UX, object model, save/network, asset, yol haritası, 40 kaynak bağlantısı, açık kararlar.
- 5 içerik tanımı (air/tree/log/plank/workbench) ve 2 örnek crafting tarifi; manifest, sürümlü world şablonu.
- JSON schema sözleşme başlangıçları: entity (kanonik definition), recipe, world, player, network-command, asset, catalog manifest. `schemas/object.schema.json` daha eski boş taslak; geliştirmede entity sözleşmesini esas al.
- Portrait 720x1280, GL Compatibility, placeholder 3D box + orthographic kamera. Oynanabilir kontroller ve gerçek üretim **henüz yok**.
- Python `jsonschema` katalog/reference testleri yeni `quality` Actions üzerinde başarılı (örn. #38150429264); bunun Godot import/Android/APK/multiplayer kanıtı olmadığını koru.
- GitHub main dosyaları ayrı ayrı geri okundu; yedek SHA eşleşmesi doğrulandı.
- Araştırma+şema örneklerinden ayrıca sohbet içinde ZIP paket sağlandı, GitHub'a varlık (3rd-party model) eklenmedi.

## Açık işler (sonraki ayrı görevler)
1. Godot 4.6.3 import/headless scene smoke GitHub CI (mevcut `quality` yalnız Python).
2. JSON schema katılaştırma, catalog ve registry runtime adapter, duplicate schema taslağı düzenleme.
3. 3D orman ve karakter ile tap-to-move/harvest/craft ve portrait HUD; safe-area jest çakışması.
4. Atomik world save / migration ve iki gerçek Android telefon ENet LAN host-client doğrulaması.
5. Prosedürel 3D model kit ve lisans denetimli GLB/MTS import.

## Kurallar
- Önce `AGENTS.md`, `docs/03_OBJECT_MODEL.md`, `docs/09_OPEN_DECISIONS.md` oku.
- Eski yedeği düzenleme veya sessiz merge etme. `main`de kalıcı world verisi ilk etapta yok, yokmuş gibi davranma.
- Android FPS, input ve co-op başarılarını gerçek cihaz kanıtı olmadan belirtme.
