## [SOHBET-K | TAMU Entegrasyon ve Son Kabul] — EşRota uygulama raporu

- **Durum:** `review_requested` — masaüstü CI/regresyon kapıları başarılı; gerçek Android, görsel, bellek/VRAM ve FPS kabulü açık.
- **Proje / kaynak:** `TheOsmanYILDIRIM/TAMU-K-K`, yalnız `experiment/25d-binary-vertex-20261030`.
- **Başlangıç HEAD:** `a6856cda2525e582eb37d954e8b0eaba69f9ac31`.
- **Son test edilmiş kod HEAD:** `d3a044ea9305202db6fb2d7d85f9a9c7eb915d5f`.
- **Zaman (UTC):** 2026-10-31 17:27 (CI son artefaktının doğrulanmış zamanı).
- **Sahiplik:** `execution_mode=implementation`, `conflict_resolution=merged_single_writer`, `minimum_viable_agents=1`, yalnız izinli dal/kod kapsamı ve bu rapor bölümü; H/I/J kaynak raporlarına dokunulmadı.
- **Kayıt hedefi:** `SESSION_HANDOFF.md#SOHBET-K`; Contents API blob SHA koruması, GitHub sağlayıcıdan geri açma ve son HEAD kontrolü.
- **Rapor sürümü / geri okuma:** commit sonrası dosya SHA ile ayrı doğrulanır.

### Yeni bulgular ve kanıt

| Bulgu | Gerçek kanıt | Mekanizma ve minimal değişiklik | Test / durum |
|---|---|---|---|
| **P0 ilk görünür chunk GPU beklemesi** | [CI #41206688479](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41206688479): `TAMU_WALK_COVERAGE frames=480 max_missing=2`; `TAMU_WALK_CAUSE` ile eksik `-1:-3`, `3:1` CPU worker hazır, GPU slot bekliyordu | `stream.lua` halo sırası eski iki-chunk uzak merkeze göre yapılıyordu; öngörülen yakın viewport kesişen adayları öne alan, **upload cap değiştirmeyen** sınırlı öncelik düzeltmesi. [Kod commit de31d202](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/de31d202a0653c2ac5b79215b2e326008ef390d1), blob `29672fc7eb30fe013a257c5b0896cc9e1b7e5062` | [quality #41224440746](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41224440746): **480 kare max_missing=0, distance=1099.287**. Yön/zoom dışındaki Android viewportlar ayrıca gerçek cihazda doğrulanmadı |
| **Obje regresyon test fixture sayaç eksikliği** | #41224122179 `terrain25d_sprites.lua:540`, `nil batches`; üretim constructor/begin_frame sayaçları zaten başlatıyor | Sadece mevcut `tests/terrain25d_object_population.lua` fixture'ına `batches=0,visible=0`; [commit 57ad9543](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/57ad954309f677324eadbdd13ed0f00fa3794d0a) | Lua5.4 + LuaJIT `TAMU_OBJECT_PLAYER_SLOT_RANGE_OK` ve `TAMU_SELECTED_OBJECT_CACHE_OVERLAY_OK` |
| **Eski tool testi kaldırılmış plasma renderer'a bağlıydı** | #41224281665 `player/rigby_visual.lua:12` — `love.filesystem=nil`; `core_tool_integration` yanlış modülü stub'lıyordu | Sadece var olan testi production Rigby `player.rigby_visual` aracına uyarladı, ağaç=axe/kaya=pickaxe, eski PNG yüklemesi yok ve hasat state'i değişmez; [commit d3a044ea](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/d3a044ea9305202db6fb2d7d85f9a9c7eb915d5f) | Lua5.4 + LuaJIT `RIGBY_TOOL_INTEGRATION_OK`, gerçek Rigby pose/socket testleri ayrıca CI'da başarılı |

### Tekrar edilmemesi gereken geçmiş çalışmalar

SOHBET-G/H/I/J rapor ve commitleri korunmuştur. H'nin visible/GPU-ready önceliği, I'nin pacing `dt_confirmed` düzeltmesi, J'nin world-query alias güvenlik düzeni ve önceki diagnostics/Creative/Rigby optimizasyonları yeniden yazılmadı. Yeni workflow, yeni test modu, yeni TASKS veya rapor dosyası açılmadı. Worker kapasitesi veya hareket halindeki 1 upload/kare limiti körlemesine artırılmadı.

### Yapılanlar / yapılmayanlar

- **Kod:** yalnız `game/love/world/stream.lua`; **test fixture:** yalnız `game/love/tests/terrain25d_object_population.lua`, `game/love/tests/core_tool_integration.lua`. Commits: `de31d202` → `57ad9543` → `d3a044ea`; mevcut dal dışında kod yazılmadı, eski commit force/reset/revert edilmedi.
- **CI:** Son HEAD `d3a044ea` üzerinde [quality #41224440746](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41224440746) `completed/success`; gate/test job başarılı, failing step yok. Lua5.4/LuaJIT, gerçek LÖVE/Xvfb, 480 kare yürüyüş, terrain/atlas, diagnostics JSONL mock, nesne depth/range/selection, Creative, stat/HUD, Stage5/Stage6 save/reopen (`LOVE_STAGE6_REOPEN_OK revision=4`), collision/Rigby/hasat kontratları geçti. `LOVE_INTEGRATION_SMOKE_OK frames=20 chunks=56 objects=117`. Masaüstü batched CPU `p95=7.544ms`, 2.5ms eski hedefe ilişkin uyarı **Android FPS değildir**; drawcall 21→2 olarak ayrı CI kanıtı.
- **Paket:** CI `.love` üretti, workflow'un `zipfile.testzip() is None` ve 156 baked `.verts.z` varlığı kapısı başarılı. `tamu-authored-r2-binary-cache` artifact **ID 13051691107**, **16,506,415 byte**, provider ZIP digest `sha256:73767266c1e2a0bbc90eb89b16270fa958f0778966ed2e6be1d0aec2008bb4aa`. İkinci `core-stat-progression-smoke` **ID 13051721125**, digest `sha256:959b1cff932d57afdcbafded1df9ff9e3603196729d4b1c5d06a41afd541af45`. Artefaktlar bağımsız indirilip yeniden açılmadı; workflow içi ZIP kontrolü ile GitHub sağlayıcı digest'i farklı kanıtlardır.
- **Beyin:** `agy-vault/main` HEAD `5c6bfef372e2272cda36e40f8a50cb0526a80389`, mevcut `tasks/oyun-25d-runtime-renderer-integration-20261028.md` **rev14/active** okundu. Bu oturumda resmi v3.12.0 DirectSync motorunun hedef vault üzerinde güvenli işlem/receipt + CAS write-back zinciri tamamlanmadığından **Beyin'e yazılmadı**, görev `done` yapılmadı.
- **Android:** Gerçek Android/JSONL export ve donanım üzerinde p50/p95/p99 FPS, GPU/VRAM/termal, görsel/Y-depth ve safe-area/fontScale kabulü **doğrulanmadı**. Masaüstü smoke Android cihaz doğrulaması değildir.

### Açık işler, engeller ve sonraki adım

1. Koordinatör, son `.love` artifact'ını gerçek Android cihazda çalıştırıp sabit/yürüyüş/dönüş/zoom JSONL, FPS p50/p95/p99 ve görünür eksik chunk=0 kanıtını toplamalı; alpha, socket, HUD safe-area, Creative, Stage6 kapat/aç ve bellek/termal davranışı görsel + cihaz düzeyinde kontrol etmeli.
2. Avenox Beyin rev14 `active` görevi yalnız resmî DirectSync motor, güncel revision, CAS, receipt ve geri okuma sonrası ilerletilebilir. Mükerrer görev yaratılmadı.
3. P2 getVertex/selektif Rigby mesh upload ve P3 worker/atlas/collision fallback için yeni ölçülmüş darboğaz yok; kapsam büyütülmedi, performans kazanımı ileri sürülmedi.
4. Main merge/yayın/nihai Android kabulü **açık**; bu rapor yalnız masaüstü entegrasyon kapısını doğrular.

### Koordinatöre teslim

Doğrulanmış rapor bağlantısı: [SESSION_HANDOFF.md#SOHBET-K](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/experiment/25d-binary-vertex-20261030/SESSION_HANDOFF.md). Kullanıcı koordinatör sohbetinde raporu yeniden açıp gerçek Android kabulünü yönetmeli; otomatik ajan bildirimi yok.

### 2026-10-31 — Android JSONL kaynaklı P0 terrain fallback düzeltmesi (kısmi)

- Android kullanıcısı JSONL frame 2499–2618 aralığında `mesh_prepare_ms` 30–49ms, `mesh_resumes=1`, `mesh_uploads=0`, `missing=3–5` ve 11–40 FPS örnekleri sağladı. Android GPU süresi doğrudan ölçülmedi.
- Kaynakta worker kapasitesi doluyken `binary_pending[c.key]` olmayan chunk için main thread `self:prepare()` coroutine fallback'i başlıyordu; tek `coroutine.resume` maliyeti frame budget'ı aşıyordu. Aktif worker varsa henüz kuyruğa girmemiş chunk artık main thread'de hazırlanmaz, mevcut worker kuyruğu ve GPU upload limiti korunur. Worker arızası için mevcut legacy fallback korunur.
- Kod commit [3b347653](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/3b347653bfed491c2e697f5aee2e82be5810141a), `world/terrain25d_runtime.lua` blob `9feed40a661b303ee06c3c8c7c1395879e4a345b` geri okundu.
- Son `quality.yml` [#41229535069](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41229535069) `completed/success`, gate/test başarılı; yeni `.love` artifact ID `13052942536`, provider SHA256 `8ebece1641debbbbf515c93c349e0e8ddc9af465a9f2a8f067eeec1b27b6680e`, bağımsız ZIP testzip ve `.love` 550 dosyalı içerik testzip geçti. Android yeniden test edilmedi.
- **Açık:** Chunk geçişinde statik obje/gölge titremesi için per-chunk kalıcı world-space render batch mimarisi uygulanmadı. Gölge attachment, Y-depth, seçili obje, reveal, güneş slotu ve save regresyonu doğrulanmadan render cache genişletilmemeli. Bu teslim 60 FPS veya sıfır takılma garantisi değildir; Android FPS p95/p99 ve missing=0 yeniden ölçülmeli. Avenox Beyin resmî DirectSync write-back yapılmadı; task rev14/active olarak gözlendi.


### 2026-10-31 — Rigby selective GPU upload, test edilmiş kısmi teslim

- Android loglarında sahne sabitken Rigby çizim aşaması ~0,3–4ms arasında dalgalanıyor; bu tek başına GPU yükleme kök nedenini ispatlamaz.
- Kod: `player/rigby_visual.lua` birebir aynı attachment vertex koordinatlarını yeniden `mesh:setVertices` ile GPU'ya göndermiyor; yeni attachment ilk yükleme normal, değişen pozlar normal güncelleniyor. Commit [ea0a9710](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/ea0a97103adba30407bbfed7ce9abceaaa39f278).
- Var olan `tests/rigby_visual.lua` içindeki aynı idle pozun iki kere hazırlanmasında tekrar upload olmaması testi eklendi. Commit [c05b79f3](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/c05b79f3006d2d8ce83c6c09d75972141e644f8c).
- [Quality #41230452958](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41230452958) son kod HEAD'de `success`; artifact `tamu-authored-r2-binary-cache` ID `13053766217`, SHA256 `07948d8bb3c42589862958512d51746623961315fdca1281d952cf2ad9892322`. İndirilen artifact ZIP ve 550 girdili .love `testzip` başarılı; .love içinde yeni kod doğrulandı.
- **AÇIK:** İstenen chunk bazlı dünya-koordinatlı sabit obje/gölge önbelleği **henüz uygulanmadı**; Android titreme ve gölge yerleşimi test edilmedi. Rigby değişikliğinin Android FPS kazancı kanıtlanmadı; vertex karşılaştırma maliyeti de cihazda ölçülmedi. 60FPS sabitlik ve görüntü kabulü bekliyor. Avenox Beyin görevine DirectSync yazımı yapılmadı.

### 2026-10-31 — Android cached scene pixel lock (kısmi görsel stabilizasyon)

- `objects/terrain25d_sprites.lua` içindeki ortak `draw_camera_batch` dönüşümü Android'de fiziksel pixel grid'e yuvarlandı. Sabit objelerin, cached contact ve static/dynamic shadow batch'lerinin kamera pan esnasında aynı translasyonu kullanması korunur. Kod commit [b31b5d25](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/b31b5d25ee8ce1a0c615a99a07725119f3ad225e).
- CI [#41231294354](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41231294354) gate ve test başarı, artifact ID `13052864878` SHA256 `47d7513fc2e58b31dcbba8555d09c3e619f37a6850a8a227d66eca78e560f768`; ZIP testzip, 550 girdili .love testzip ve yeni kod içeriği bağımsız doğrulandı.
- **Açık:** Bu, chunk bazlı world-space kalıcı batch mimarisinin yerine geçmez. Camera pan'de cached/uncached geçiş farkı, zoom, reveal, GPU yükü, gerçek Android titreme ve 60FPS p95/p99 görsel/fonksiyonel kabulü doğrulanmadı. Pixel-grid snapping tek başına chunk girişinde önce görünmeyen objenin belirmesini veya günışığı slot geçişlerini engellemez. Beyin DirectSync güncellemesi yapılmadı.

---


## [SOHBET-G | TAMU Performans Uygulama] — EşRota raporu

- **Durum:** `review_requested` — P0 kabul başarısız, Android cihaz kanıtı yok; tamamlandı/verified değildir.
- **Proje / kaynak:** `TheOsmanYILDIRIM/TAMU-K-K`; yalnız `experiment/25d-binary-vertex-20261030`. `main` değişmedi.
- **Başlangıç:** `425f97b9bf58761f20e632ee03bfa5407702af5d`; **kod teslim HEAD:** `79714288975d4a2b197bcb68b1bafb6fb5e4ee46`.
- **Zaman (UTC):** 2026-10-31 09:42.
- **Sahiplik / EşRota:** tek yazıcı SOHBET-G; `scoped_write` kod, `report_only` bu bölüm. Kanal: `github:TheOsmanYILDIRIM/TAMU-K-K@experiment/25d-binary-vertex-20261030:SESSION_HANDOFF.md#SOHBET-G`; `revision_guard=cas`, `readback=provider_reopen`, otomatik bildirim yok.
- **Kayıt hedefi / revizyon:** yalnız mevcut `SESSION_HANDOFF.md`; yazımdan sonra GitHub'da yeniden açılarak rapor commit'i ve blob SHA teslim mesajında doğrulanacak.
- **Kanonik Beyin:** `TheOsmanYILDIRIM/agy-vault/main:tasks/oyun-25d-runtime-renderer-integration-20261028.md` rev14, `active` başlangıçta okundu. Resmî DirectSync yazma sözleşmesi bu oturumda işletilemediği için **Beyin'e yazılmadı**; GitHub raporu Beyin senkronu değildir.

### Yeni bulgular, önce/sonra kod kanıtı

| Öncelik ve gerçek bulgu | Önce → sonra (kod kanıtı) | Commit / dosyalar | Doğrulama ve risk |
|---|---|---|---|
| **P0 — Worker sıra baskısı:** kamera değişse bile `binary_pending` eski işleri tutup 12 istek sınırını doldurabiliyor | `Runtime:enqueue_binary` sadece eski `binary_ready` temizliyordu → artık stale request kanalı temizleniyor, her iş `ticket` taşıyor ve `poll_binary_results` yalnız geçerli ticket kabul ediyor. Worker sonucu aynı ticket ile döndürüyor. 1 GPU upload/kare korunuyor | `e0fca2e46bd0c8d1343ee41ac181ddb895af49ab`; `world/terrain25d_runtime.lua`, `world/terrain25d_binary_worker.lua`, `tests/terrain25d_runtime.lua` | Kaynak geri okundu; mevcut Lua testine iptal/ABA regresyonu eklendi. CI yürüyüşü **max_missing=6**, tek başına çözmedi |
| **P0 — Görünür küme ve halo:** 80 toplam residency slotu, geniş gerçek görünür sette 77 chunk varken sadece üç halo slotu bırakıyor | `Stream:needed` mevcut uzaklık sıralaması → kamera hareket yönünde halo önceliği, daha geniş aday taraması ve `max(80, visible+24)` sınırlı ön hazırlık kapasitesi; görünürlerin tamamı önce tutuluyor. Yarım mesh gösterilmiyor | `9e0cacf55e6d19cd5898298f4e78b294a0b10d6c`, `79714288975d4a2b197bcb68b1bafb6fb5e4ee46`; `world/stream.lua`, `tests/r2_viewport.lua` | **Başarısız:** CI #41189436053 max_missing=7, #41189613196 max_missing=7. Sonuncu 480 kare / distance=621.553. CPU/bellek maliyeti ve gerçek görünür küme sınırı yeniden değerlendirilmeli; bu hipotez **kabul edilmedi** |
| **P1 — Eşzamanlı loglama:** `M.flush` LÖVE ana thread üzerinde `love.filesystem.append` çağırıyordu | 4 girişlik bounded `love.thread` Channel ve `core/diagnostics_worker.lua`; dolu kuyrukta `dropped` artırma; worker `ack`, hata kontrolü ve `close` sırasında `!stop`/`wait` | `c4b66a1c6fba6af8b0a26e67e240278d2d6decdc`; `core/diagnostics.lua`, **yeni üretim modülü** `core/diagnostics_worker.lua`, mevcut `tests/diagnostics.lua` | Lua5.4/LuaJIT mocked queue testinde `TAMU_DIAGNOSTICS_ASYNC_QUEUE_OK`. Gerçek Android depolama/backpressure, worker ömrü ve dosya çıkarımı **doğrulanmadı** |
| **P1 — Yanlış kareye dt:** draw_done güncel `update_ms/draw_ms` ile önceki `dt`yi birleştiriyordu | `M.draw_done` geçerli frame örneğini saklıyor; *sonraki* `M.begin(dt)` önceki frame'i `finish_frame` ile sonlandırıyor. Son çerçeve CPU-only ve `dt_confirmed=false`; JSONL `frame`, `slow_frame`, `window_summary` türleri korunuyor | `b6cad2681248fe8c56cee764f5cab1aa85b71f4b`; `core/diagnostics.lua`, `tests/diagnostics.lua` | Lua5.4/LuaJIT `TAMU_DIAGNOSTICS_FRAME_ALIGNMENT_OK`; 16.667ms pencere sayacı var. Gerçek cihaz frame pacing/Android FPS ayrı kabul |
| **P1 — Seçim önbelleği:** `renderer.lua` `not selected_id` koşulu ile bütün statik objeleri her seçili karede tekrar kuyruğa alıyordu | Koşul kaldırıldı; `Sprite:draw_selection` seçili objenin halkasını player öncesi/sonrası doğru Y-depth katmanında ayrı çiziyor | `dd56c0278a7babe8690f52150bee2cdc23b8bb3e`; `objects/renderer.lua`, `objects/terrain25d_sprites.lua`, `tests/terrain25d_object_population.lua` | Kod/commit geri okundu; görsel seçim, alfa, hasat ve cihaz karşılaştırması **açık** |
| **P1 — Player slot:** iki ayrı `SpriteBatch` ve `cache.player_slot` eşitliği nedeniyle oyuncu ağaçların önünden arkasına geçince tüm batch yeniden kuruluyordu | Tek değişmez batch + `SpriteBatch:setDrawRange(start,count)`; prefix görünür sprite sayaçlarıyla player öncesi/sonrası eşdeğer sıra. Obje kimliği/pozisyonu değişirse yeniden oluşturma korunuyor | `3c8e38947fa28b6e583f4915dd295e69f48202ce`; `objects/terrain25d_sprites.lua`, `tests/terrain25d_object_population.lua` | LÖVE 11.x draw range API uygun; kaynak testi eklendi. İlgili CI adımı P0 yürüyüşte durduğu için bu sürümde **çalışmadı**; cihaz Y-depth ve alpha görsel kıyası açık |
| **P3 — Creative boş sahne:** açılışta `CreativeRenderer.new` atlası ve batch'i hemen yaratıyordu; boş sahnede `visible`, clear/flush/draw çalışıyordu | `R.new` hafif; `ensure_assets` yalnız ilk görünür yapı veya preview ile çağrılıyor. `model.items` boşsa erken dönüş; var olan yerleştirilmiş yapılar Creative kapalıyken de görünür tutuluyor | `9667f03322c1c7be225c18e8dae5425f41f3e540`; `systems/creative_build_renderer.lua`, `tests/creative_build.lua` | Kaynak testi eklendi; Creative test adımı P0 sonrasında olduğundan yeni CI'de koşulmadı. Yüklü save/startup somut görüntüsü açık |

### Tekrar edilmedi / korunmuş mevcut işler

21→2 terrain drawcall, 1/kare hareketli GPU mesh upload cap, object/shadow pan cache, 32px gölge atlası, iki atlas sayfası, düşük DPI, Rigby 30Hz, opaque/alpha denemeleri, JSONL mevcut şeması, paket temizliği ve desktop p95=2.5ms bilgilendirme eşiği **önceden yapılmış olarak kabul edildi**. `main`, Stage6/save/yedekler, Rigby kaynak görselleri, Stage6 altyapısı ve authored atlaslar değiştirilmedi. Yeni görev/takip dosyası, yeni test modu ve workflow eklenmedi.

### Test, CI ve artefakt kanıtı

- Başlangıç P0 başarısızlık: [CI #41183440151](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41183440151), `max_missing=6` (eski `f5589962`).
- İlk müdahale kontrolü: [CI #41189085513](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41189085513) (`b6cad268`): gate başarılı; Lua/JSONL testleri çalıştı; `TAMU_WALK_COVERAGE frames=480 max_missing=6`, sonuç **failure**.
- Yönlü ön hazırlık: [CI #41189436053](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41189436053) (`9e0cacf`): gate başarılı, `max_missing=7`, **failure**.
- Son HEAD: [CI #41189613196](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41189613196) (`79714288`): gate başarılı, `TAMU_AUTHORED_LOVE_OK binary_chunks=156`; mevcut `.love` arşivi Python `zipfile.testzip() is None` testinden geçti; `max_missing=7`, **failure**. Desktop CPU p95=3.819ms bir **Android FPS ölçümü değildir**.
- Son CI artefaktı: [tamu-authored-r2-binary-cache](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41189613196/artifacts/13037869827), artifact ID `13037869827`, arşiv SHA256 `68dbb3132d369e3e521d560d5f60edeb9ce5909ef80a740aab43117f59eed668`; ZIP GitHub Actions'ta üretildi/yüklendi. Yerel cihazda paket çalıştırma, görsel ve artefaktın bağımsız yeniden indirilip test edilmesi bu sohbetten doğrulanmadı.
- Luac/LuaJIT, LÖVE/Xvfb **CI'de geçilen adımlar kadar** doğrulandı. Quality'nin sonraki object/Creative/Stage6/diğer testleri P0 adımı başarısız kaldığı için tamamlandı sayılmadı. Gerçek Android cihaz FPS/JSONL, Rigby attachment, alfa/yön ve uzun süreli disk I/O **doğrulanmadı**.

### Açık işler, engeller, ikinci EşRota dalgası kontrol listesi

1. **P0 BLOCKED — kabul kapısı:** Son yürüyüşte `max_missing=7` (hedef `0`). Görünür/görünmez kesin kesişim (AABB fazla sayım riski), 77 görünür chunk, ön hazırlık kümesi, yükleme önceliği, stale jobs, GPU `newMesh/setVertices` sürelerini ayrı sayaçlarla yeniden analiz et. Düşük bütçeli Android bellek ve frametime etkisini ölçmeden staging kapasitesini üretime kabul etme; `upload_cap=1` otomatik artırılmasın.
2. **P1 doğrulama:** Yeni selected overlay ve player_slot `setDrawRange` sırasının alpha/shadow/harvest/selection davranışını ve mevcut `tests/terrain25d_object_population.lua` / `tests/creative_build.lua` testlerini P0'dan bağımsız **mevcut** test düzeninde çalıştırıp görsel kıyasla; henüz çalıştırılmadı.
3. **P1 Android telemetry:** `diagnostics/tamu-trace-*.jsonl` aktar; `dt_confirmed`, 16.667/33.333ms, `trace_write_ms`, `dropped`, `mesh_uploads`, `object_cache_rebuilt` olaylarını korele et; asenkron writer kapanışını/dolmayı cihazda sınayarak FPS hakkında karar ver.
4. **P2 Terrain batch — uygulanmadı:** `terrain25d_runtime.lua` aggregate rebuild `mesh:getVertex` başına Lua tablo tahsislerini binary vertex spans kullanarak kaldırma adayını incele; atlas, renk, layer, pass sırası ve LÖVE/Xvfb birebir kontrolü olmadan değiştirme.
5. **P2 Rigby — uygulanmadı:** yön/skin vertex hesaplarını, çoklu mesh draw maliyetini, hasatta 30Hz bypass davranışını ve attachment/alpha deformasyonunu mevcut Rigby testleriyle incele; tahmini kazanımı doğrulanmadan yapma.
6. **P3 Gameplay/Assets — kısmen açık:** HUD layout churn, collision allocation/sort ve atlas worker timeout'taki senkron image yaratımı değişmedi. Açılışta zaten var olan Creative parçaları/save, Stage6 ve paketleme tam regresyonu gözden geçir.
7. **Kayıt/senkron:** Beyin rev14 görevini yalnız resmî DirectSync sözleşmesi ve revision-CAS ile senkronla; bu sohbetten doğrudan vault düzenlemesi yapılmadı. Başka ajanın bu raporu veya branch HEAD'i haber verilmeden değiştirmediğini ikinci dalga başında yeniden oku.

### Koordinatöre teslim

Kod ve rapor GitHub yetkili dalında. Koordinatör ikinci araştırma dalgasını yalnız bu raporu ve üç CI başarısızlığını okuyup güncel HEAD'i tekrar doğruladıktan sonra açmalı. Otomatik bildirim veya Android performans başarısı iddiası yok. **Raporun gerçek GitHub geri okuma SHA'sı sohbet tesliminde verilir.**


### 2026-10-31 — SOHBET-G devam / P0 canlı kuyruk ve gelecekteki ekran ön hazırlığı

- **Durum:** `review_requested` / **P0 kabul başarısız**. İlk çalışma HEAD `bb937ddf7fe3b171e38b5d0b5b6eb7ffeee4c626`; devam kod HEAD `4af26a5e1a5f026e3181994bc611a8c8432c7830`. Yalnız `experiment/25d-binary-vertex-20261030` yazıldı; `main`, Stage6/save, texture atlasları, Rigby kaynak görselleri ve mevcut yedekler korunuyor.
- **Kanonik görev:** `agy-vault/main:tasks/oyun-25d-runtime-renderer-integration-20261028.md` rev14, `active` okunarak doğrulandı. Bu turda resmî Beyin motorunun semantik yazım/receipt akışı tamamlanmadığı için vault görevi **güncellenmedi**. Bu Markdown, Beyin task-update/receipt yerine geçmez.
- **EşRota sahipliği:** tek SOHBET-G yazıcısı, kod `scoped_write`, bu dosyada rapor `report_only`; yeni görev/workflow/rapor dosyası oluşturulmadı.

| Bulgu | Önce → sonra / somut kod kanıtı | Commit, dosya ve test | Kabul |
|---|---|---|---|
| P0: Bir halo işi eskidiğinde **tüm** `binary_pending` ve request Channel temizleniyordu; geçerli sıra/ticket tekrar üretiliyordu | `Runtime:enqueue_binary` içindeki `requests:clear(); self.binary_pending={}` → yalnız eski anahtarların kaldırılması, kuyruktaki geçerli ticket'ların FIFO korunması, `binary_inflight` yeniden sayımı | [`682fa058`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/682fa058e9dcd96affee44dc9c98773793acab06); `game/love/world/terrain25d_runtime.lua` (blob `af0874ac9d4fb641207b2bec6f0110a0bbeab14a`), `game/love/tests/terrain25d_runtime.lua` (blob `1277d5b78a6a97a911a26990b74d2516b0e3d150`), geçerli-ticket/FIFO regresyonu | CI [#41192291392](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41192291392): Lua/sözdizimi/worker adımları geçti, yürüyüş **max_missing=7, failure**. Kod düzeltmesi P0 kabul kanıtı değildir |
| P0: Halo uzaklığı, yaklaşan ekranın tüm ön kenarını doğrudan önceliklendirmiyordu | `Stream:needed` içindeki yalnız ileri nokta `lookscore` sırası → 0.25/0.5/1/2 chunk uzaklıktaki gelecekteki viewport'a ilk kesişen halo kümesini önceleme; mevcut mesafe sırasını eşit grup içinde koruma | [`4af26a5e`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/4af26a5e1a5f026e3181994bc611a8c8432c7830); `game/love/world/stream.lua` (blob `651a8366ae4a6f3d4918517b23a18e334e2f4c24`), mevcut `game/love/tests/r2_viewport.lua` (blob `44efa1dd7ffb222840a1ca33e3c65ac161c56a52`) güncellendi | CI [#41192683940](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41192683940) **failure, max_missing=7**. Yeni viewport testi, CI P0 adımından önce bağımsız yürütülmedi; bu testin geçtiği iddia edilmiyor |

**Doğrulama ayrımı:** İki GitHub commit/HEAD/hedef blob geri okundu, `force` kullanılmadı. CI #41192683940 `gate=success`, Lua 5.4/LuaJIT Rigby ve terrain batch testleri ile syntax ve worker/Xvfb kontrol adımları başarılı; statik terrain görsel karşılaştırması `changed_ratio=0.000000`, `mean_rgb_delta=0.0000` (79.125 piksel). `TAMU_WALK_COVERAGE frames=480 max_missing=7 distance=1062.485`; x≈274.78, 529.90, 785.96, 1041.43 noktasında yedi görünür chunk aynı karede eksik. `quality.yml` sonraki Stage5/6, Creative, HUD, object smoke adımları P0 hatası nedeniyle **çalışmadı**. Masaüstü `p95=7.876ms` (batched CPU) Android FPS değildir. `upload_cap=1` hareket halinde değiştirilmedi; yarım chunk gösterme eklenmedi.
- **Paket:** CI #41192683940 ürettiği `tamu-authored-r2-binary-cache` artifact ID [13038949958](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41192683940/artifacts/13038949958), API digest `sha256:ecf1723903ba9fe31d938874d8caa05dc459b8d628d38a3b1f17baedabd81d64`, size `16503612` byte. CI'de `.love` arşivi için `zipfile.testzip() is None` assertion adımı geçti; ZIP'in dışarı indirilip bağımsız tekrar açılması ve Android'de çalışması **doğrulanmadı**.
- **P1/P2/P3 durumu:** Önceki handoff'taki asenkron diagnostics/frame alignment, object selection/player slot ve boş Creative sahne düzeltmeleri korundu; yeni commitlerde değiştirilmedi. P2 terrain aggregate `mesh:getVertex` tablo tahsisi, Rigby skin/upload ve P3 HUD/collision/image timeout incelemeleri **açık**. Android JSONL, görünür Y-depth/alpha/attachment karşılaştırmaları ve gerçek FPS yok.

**İkinci dalga kontrol listesi (kabul edilmemiş hipotezler ayrı):**
1. P0 ilk eksik karede 7 **chunk anahtarı** için önceki kare `Stream:needed` görünür/halo listesi, worker pending/ready/ticket, chunk `_25d_meshes`, GPU `newMesh/setVertices` zamanını mevcut `TAMU_25D_WALK_PROBE` altında izole et; görünür AABB'nin gerçek geometri kesişimiyle eşdeğerliğini doğrula.
2. İstek seçim sırası, halo eviction, 12 in-flight slot, başlangıçtaki 77 görünür + yalnız 24 halo bütçesi ve worker sonucu GPU'ya yükleme sırası ayrı ölçülsün. Yeni bellek/CPU ölçümü olmadan halo kapasitesi veya 1 upload/kare sınırı körlemesine büyütülmesin.
3. P0 `max_missing=0` kanıtlanmadan veya P1 visual/telemetry doğrulanmadan gerçek Android performansı hakkında başarı ilan etme; sonraki aşamadaki mevcut testler ve Stage6/save korunmalı.
4. Kanonik Beyin rev14 görevi ancak resmî yazım sözleşmesinde revision-CAS, kaynak ve receipt geri okumasıyla güncellenebilir. Şu an Beyin yazımı **engelli/açık**; otomatik EşRota bildirimi yok.



### 2026-10-31 — SOHBET-G teslim güncellemesi / gerçek görünürlük ve HUD

**Son test edilen kod HEAD:** `ff55a993d6b065ca8df12dd47305d01809b6c2b3`. Bu bölüm önceki iki tarihsel raporu **silmeden** eklenmiştir; eski CI değerleri tarihsel olup en son test sonucu aşağıdadır. Dal dışına yazılmadı, `main` birleştirilmedi, save/Atlas/Stage6/Rigby görsellerine dokunulmadı.

| Bulgu ve kanıt | Önce → sonra | Commit / dosyalar | Doğrulama |
|---|---|---|---|
| **P0 gerçek kök neden: alias yüzünden halo, görünür sayılıyordu.** `Stream:needed` içinde `local required=visible` tablosuna halo eklendiğinde `#visible` de artıyordu. | `local required=visible` → `local required={}; for i,c in ipairs(visible) do required[i]=c end`; görünür anahtar/count ayrı, halo hâlâ yükleme kuyruğunda. Eski `r2_viewport.lua` testine ekran kesişimi ile `visible_required_count/keys` karşılaştırması eklendi. | [`4193ca5`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/4193ca5bcfc6d0beb81bee45fa89a523d6f28696) ve önceki başarısız ETA tahminini geri alan [`ff55a993`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/ff55a993d6b065ca8df12dd47305d01809b6c2b3). Etkin `stream.lua` blob `7874bfe9e02bac18dc1560020835702736ee9edd`; `r2_viewport.lua` blob `f49e45b0e0a3b212d26d078079f36040466206d3`. | Gerçek LÖVE yürüyüşünde başlangıç bildirimi **77 → 18** görünür chunk; `max_missing=7 → 2` CI [#41193621234](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41193621234). Son koşu `max_missing=1`; P0 **açık**. |
| **P0 kalan fiziksel yükleme açığı:** ilk 7 hatalı halo sayımı giderildikten sonra yeni görünür olabilecek 1–2 chunk'ın CPU worker sonucu hazır, ancak aynı karede GPU'ya yüklenememiş. | Mevcut `TAMU_25D_WALK_PROBE` içine yeni mod açmadan `TAMU_WALK_CAUSE` (chunk key, önceki resident/visible, pending/ready, viewport) tanı logu eklendi. Yükleme sınırı hareket halinde **1/kare**, yarım chunk yok. | [`a5d72712`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/a5d72712ce683753aec2dd30e83dca1dff0d3af9) yalnız `game/love/main.lua` (blob `80d742be8c66d77c21650ffec38a1b3800aabb67`). Denenen ETA önceliği [`eb00a46c`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/eb00a46ce9f13923ba4a1ecd66207f8f3b658b62) `max_missing=4` verdiği için geri alındı. | Son CI [#41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897), `TAMU_WALK_COVERAGE frames=480 max_missing=1 distance=885.783`; `frame=7 missing=[-1:-3] no_previous_resident=0 first_visible=1 worker_pending=0 worker_ready=1`. Bu bir karelik GPU-gecikmesi kabul dışı. |
| **P3 HUD tablo/layout churn:** her çizim/hit'te Stage5, Creative ve stat HUD geometri tabloları yeniden üretiliyor, Creative menü 10 kez çağrılıyordu. | Safe-area/aktif panel/sayfa değişmediği sürece `_layout_cache` geri kullanılır, panel veya viewport değişince yeniden hesaplanır; `creative.menu()` tek çağrı. Canlı envanter, seçili stat ve metinler çizim anında okunmaya devam eder. | [`8067f1a6`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/8067f1a6fdcffdade2f66feb6a0d451e22201f79): `core/stage5_hud.lua`, `core/creative_build_hud.lua`, `progression/hud.lua`; mevcut `tests/stage5_hud_layout.lua`, `tests/creative_build.lua`, `tests/core_stat_progression.lua` cache/invalidasyon assertions eklendi. | GitHub kod/blob geri okundu; **bu 3 güncellenmiş HUD/Creative testinin çalıştığı henüz doğrulanmadı**, çünkü quality.yml P0 yürüyüş hatasında sonlandı. Android etkisi ölçülmedi. |

**Son CI ve artefakt kanıtı:** [quality #41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897) `gate=success`; Lua/LuaJIT fail-fast, terrain batch, diagnostics, Rigby ve gerçek LÖVE worker smoke adımları geçti. Authored 25D görsel karşılaştırması `changed_ratio=0.000000`, `mean_rgb_delta=0.0000`. P0 `max_missing=1` sebebiyle iş akışı **failure**; sonraki HUD/Creative/Stage6 uçtan uca adımları koşulmadı. `tamu-authored-r2-binary-cache` artifact ID [13039019225](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897/artifacts/13039019225), size `16504078` byte, GitHub digest `sha256:27298d73457eb91e7140c0230011864e429d06c7b4a92477059c32b875a77da4`. Workflow içindeki `.love` zip bütünlük assert'ı geçti; artefakt ayrıca indirilip Android cihazda **doğrulanmadı**. Masaüstü CPU p95/microbenchmark **Android FPS** değildir.

**Tamamlanan:** GitHub kanıtlanmış kaynak değişiklikleri, P0 halo/visible sayım hatası düzeltmesi, worker ticket/FIFO koruması, sadece yürüyüş probunda chunk neden tanılaması, P3 HUD geometri cache kodu/test assertions, başarısız ETA sırasının geri alınması, SHA/CAS ve rapor readback.

**Açık / sonraki adım:** (1) P0 tek GPU-ready yeni görünür chunk'ın ekran eşiğinden *önce* yüklenmesini garanti eden yön bağımsız, bütçe ölçümlü ön hazırlık önerisi; `max_missing=0` hem Xvfb/CI hem Android JSONL ile ispatlanmalı. 1 upload/kare körlemesine artırılmamalı; frame-time ve VRAM bütçesi ölçülmeli. (2) P3 HUD/Creative/stat testleri ayrı mevcut test komutlarıyla doğrulanmalı; sonraki CI green olmadan tamam sayılmamalı. (3) P2 terrain `mesh:getVertex` tahsisi ve Rigby render/hasat, P3 collision/creative atlas timeout hâlâ açık; P1 object/diagnostics önceki düzeltmeler korunuyor. (4) Avenox Beyin kanonik rev14 görevine **resmî motor + revision CAS + receipt + readback** yolu tamamlanmadı; vault'da yazım yapılmadı ve bu rapor onun yerine geçirilmedi. Koordinatöre ikinci EşRota araştırma dalgasında yalnız bu açık kanıt/işler devredilmeli.


---

## 2026-10-31 — Devam: CI desktop 400 FPS hedefi mobil kabulden ayrıldı (AÇIK)

- Yetkili dal HEAD başlangıçta `019729f0dc1818c0c2be85ff52cacf8ec209a191` olarak doğrulandı. `.github/workflows/quality.yml` içindeki eski `p95<=2.5ms` masaüstü eşdeğer-400FPS assert'i, ölçümü ve drawcall karşılaştırma kontrollerini koruyan fakat başarısızlığı `TAMU_DESKTOP_CPU_BUDGET_WARNING` olarak raporlayan bilgilendirme koşuluna çevrildi. Bunun Android 60 FPS kabulüyle ilgisi yoktur.
- Kod commit: `f5589962a1f2fb60f8a0cab532b769a06e12878f`; dosya blob `49223f9abac75de20f98298ddf4754d082ff5a78` geri okundu. Yeni manuel quality dispatch Supabase yönetici RPC tarafından kabul edildi; GitHub run [41183440151](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41183440151) aynı SHA üzerinde oluştu, son görülen durum queued. CI başarı, derlenmiş .love, ZIP içeriği ve Android cihaz FPS henüz kabul edilmedi.
- Android JSONL aktarımı olmadığı için `slow_frame`, `mesh_upload`, `object_cache_rebuilt` ile gerçek spike korelasyonu henüz hesaplanamadı. Cihazdaki `diagnostics/tamu-trace-*.jsonl` ile p50/p95/p99 ve olay eşleşmesi sonraki adımdır. Mevcut `upload_cap=1` ve object cache tanılama koduna yeniden dokunulmadı; main'e merge yok.

---

## 2026-10-31 — Devir: Android frame pacing ve CI sonucu (AÇIK)

- **Proje:** TAMU / `TheOsmanYILDIRIM/TAMU-K-K`. Yetkili dal: `experiment/25d-binary-vertex-20261030`. Bu devir öncesi HEAD: `66a1aea28441c30234d3c4f1a1f75294c99f7e15`. `main` kontrol HEAD: `91ef74cacfb98716ac628a47f52a910681320abd` — bu oturumda main'e dokunulmadı.
- **Android kullanıcı kanıtı (önceki sürüm):** Statik halde 58–63 FPS; yürürken 50–60 FPS, çok kısa (<1 s) ~30 FPS düşüşleri. Bunlar yeni `66a1aea` sürümüne ait doğrulanmış cihaz sonuçları değildir. Önceki opak/obje GPU atlama deneyleri tek başına çözüm olmadı.
- **Son kod müdahalesi:** `world/terrain25d_runtime.lua` hareketli kamerada mesh upload üst sınırını 3'ten 1'e indiriyor; statik halde ve bake işlemlerinde önceki bütçe korunuyor. `mesh_prepare_ms` / `mesh_resumes_per_frame` / `uploads_per_frame` sayaçları eklendi. `objects/terrain25d_sprites.lua` statik SpriteBatch cache rebuild/reuse sayaçları eklendi; `main.lua` ve `core/diagnostics.lua` bunları Android JSONL `frame`, `slow_frame`, `mesh_upload`, `object_cache_rebuilt` kayıtlarına bağlıyor. Kaynak ve kayıtlar HEAD'den geri okunarak doğrulandı. Yerel Android telemetry `diagnostics/tamu-trace-*.jsonl`; otomatik GitHub'a yüklenmez.
- **Son CI:** `quality.yml` manuel Supabase yönetici dispatch ile başlatıldı: `https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41182144425`. Commit `66a1aea`. Gate ve ilk Lua/sözdizimi kontrolleri geçti; final **failure**, `Precompile complete authored R2 polygon area with safety halo` aşamasında eski `p95 <= 2.500ms` masaüstü 400 FPS eşdeğeri assert yüzünden durdu. Log: p50=5.344ms, p95=8.004ms, p99=11.337ms; `object_batches=2`, `shadow_calls=1`, `gpu_drawcalls=45`. Bu ölçüm Android FPS değildir. CI artefaktı `tamu-authored-r2-binary-cache` (ID `13034848513`) var; **güncel çalışır .love / Android FPS kabulü doğrulanmadı**.
- **CI politikası:** `quality.yml` push ile otomatik tetiklenmez; `workflow_dispatch` kullanılır. Supabase `github-control-plane` projesindeki mevcut `control_private.tamu_dispatch_quality()` yönetici komutu GitHub dispatch için doğrulanmıştır. Kullanıcı panelde işlem yapmamalı; asistan gerekli olursa mevcut güvenlik kapısından manuel tetikleyebilir. Giriş sırlarını, private capability değerlerini sohbet/repo/ZIP'e taşımama.
- **Açık ve sonraki adımlar:** (1) `66a1aea` paketinin gerçek .love/Android cihazda çalıştığını doğrula; eski CI 2.5ms/400FPS şartını mobil 60FPS sonucu gibi yorumlama. (2) GPU upload / obje cache rebuild / diagnostic flush ile slow_frame korelasyonunu gerçek Android JSONL'de incele; gerekirse kullanıcıdan export iste. (3) Yürürken <16.7ms hedefli kare zamanı p95/p99, görünür chunk açıklığı ve gözlemlenen kısa ~30FPS düşüşünü yeniden değerlendir; tam kanıt olmadan "çözüldü" deme. (4) R2 cache CI ölçütünün mobil cihazdan bağımsız, gerçekçi CI şartını ayrı değerlendirme; kabul geçmeden main merge yok. (5) Önceki dal bazlı asset/ölü kod temizliğinin tamamını bitmiş sayma.
- **Kayıt düzeni:** Kök `TASKS.md` bu dalda bulunamadı; kullanıcı onayı olmadan yenisi oluşturulmadı. Kanonik Avenox Beyin görevi bu devrin kapsamında değiştirilmedi. `AGENTS.md` içindeki 2026-10-29 tarihli plasma geri dönüş metni, kullanıcının 2026-10-31'deki "geri dönüş olmayacak" kararıyla tarihsel olarak çelişiyor; bu devirde AGENTS değiştirilmedi, sonraki geliştirmede gerçek kod/kararla uzlaştır.
- **Kabul:** son commit + son CI + yeni .love dosyası ve ZIP bütünlüğü + gerçek Android yürüyüş kare zamanı p50/p95/p99 + slow_frame kök nedenine dair loglar ayrı ayrı doğrulanmalı. Main ve kaynak arşivi korunmalı.

---

## 2026-10-31 — Frame pacing: yürürken kısa FPS düşüşü (kod düzeltmesi; Android doğrulaması açık)

- Kullanıcı gerçek Android'de sabitken 58–63 FPS, yürürken 50–60 FPS, çok kısa süreli ~30 FPS ölçtü. Bu ölçümler loglardan değil kullanıcı cihazından; nedeni kesin kanıtlanmadı.
- Son GitHub CI #41180926047: kaynak Lua testleri geçti; p50=5.168ms, p95=7.297ms, p99=10.564ms masaüstü CPU; kalite işi, mobil 60 FPS kabul ölçütü olmayan eski 2.5ms/400FPS-eşdeğeri eşikten başarısız. Aynı çalışmanın ilk 10 kare logu yükleme döneminde kare başına üç `TAMU_25D_BINARY_LOADED` örneği ve `object_batches=2` gösteriyor.
- `world/terrain25d_runtime.lua`: hareketli kamerada `upload_cap=1`, sabit ve bake sahnesinde mevcut throughput korunuyor. `mesh_prepare_ms`, `mesh_resumes_per_frame`, `uploads_per_frame` izleniyor.
- `objects/terrain25d_sprites.lua`: obje statik batch yeniden kurma/yeniden kullanım sayaçları eklendi. `main.lua` ve `core/diagnostics.lua` bu metrikleri slow_frame ve `mesh_upload` / `object_cache_rebuilt` JSONL olaylarına bağlıyor. Tanılama cihazın mevcut save alanında kalır; otomatik GitHub'a yüklenmez.
- Test menüsüne yeni mod eklenmedi; yalnız mevcut `quality.yml` manuel Supabase kontrolü üzerinden tetiklenmeli. Değişiklik sonrası Android kare zamanı ve gerçek cihaz kabulü açık; `main`e merge yapılmadı.

---

## 2026-10-31 — Kod incelemesiyle obje gölgesi yeniden kullanım düzeltmesi (CI/Android kabulü açık)

- Kullanıcı test profillerini çoğaltmak yerine kaynak kod üzerinden gerçek optimizasyon istedi. Eski 30 FPS gözlemlerine göre CPU/driver dağılımı sayısal olarak kesinleşmedi.
- `objects/terrain25d_sprites.lua` statik 32×32 gölge atlasını her kare `batch:clear()` ve `batch:add()` ile yeniden hazırlıyordu; üretimdeki gereksiz tekrar kaldırıldı.
- Aynı nesneler, dünya koordinatları, görüntü alanı ve zoom ile aynı 3 saatlik güneş slotunda, yalnız kamera kayıyorsa `static_shadow_cache` ve `draw_camera_batch` kullanılır. İlk batch tüm ilgili nesneleri, kamera pan sırasında görünür hâle gelebilecek dış ekran nesneleri dâhil oluşturur. Sis/reveal tamamlanmamışsa eski gölgeyi tekrar kullanmaz.
- Commit `30e6b7578d0976766f5467c821b08e74ce3a1d01`; SHA ve dosya geri okuması doğrulandı. Gerçek LÖVE/Android testleri çalıştırılmadı; FPS iyileşmesi kanıtlanmadı. `main` değiştirilmedi. Açık sonraki optimizasyon: sabit obje SpriteBatch hazırlığı ve derinlik sıralama tekrarı, ancak Rigby ile dünya-depth örtüşmesi korunmalı.

---

## 2026-10-30 — LÖVE paket temizliği / kaynak arşivi (KISMİ, TEST BEKLİYOR)

- Kullanıcının gözlemi: eşdeğer opak obje modu da ~30 FPS; alpha blending tek başına darboğaz değil.
- Kaynak saklama dalı: archive/tamu-source-assets-20261030, başlangıç commit ece9610c. Kaynakların mevcut depodaki tarihsel içeriğini saklamak için branch oluşturuldu; içerik fiziksel olarak bu dalda ayrı klasöre taşınmadı.
- experiment/25d-binary-vertex-20261030 scripts/package_tamu_love.py: manifestteki packed atlas_00/atlas_01 dosyaları SHA-256 ile doğrulanır, source_png/ tekil authored PNG dosyaları .love içine konmaz. Bağımlılığı bulunmayan settle_at_the_edge.mp3 ve CreativeRenderer'ın kullanmadığı tekil creative_*.png önizlemeleri de paketten çıkarılır; birleşik creative_build_atlas.png korunur.
- Korunan opsiyonel geri dönüş: eski plazma/core assetleri, axe ve ilgili kodlar hâlâ referanslandığı için silinmedi. Ana dal/yedekler/tarihsel dallara otomatik silme uygulanmadı; bütün dallarda toplu çalışma açık ve dal bazında bağımlılık doğrulaması gerektirir.
- AÇIK: Bu commit için gerçek paket üretimi/ZIP bütünlüğü, LÖVE/Android regresyonu ve APK kontrolü henüz doğrulanmadı. Tüm dallarda dosya ve ölü kod temizliği yapılmış sayılmaz. CI gereksiz kuyruğu yaratmamak için bu deney dalında quality push kapalıdır.

---

## 2026-10-30 — Eşdeğer tam sahne render izolasyon profilleri (CI BEKLİYOR)

- Önceki 24 sabit obje/izole boş dünya FPS kıyaslaması geçersiz kabul edildi: normal tam oyunda 137 nesne, R2 ve gameplay vardı. Kullanıcının Android kanıtında tam oyun ~25 FPS, yalnız izolasyon 60 FPS, chunk yüklemesinde kısa ~51 FPS.
- core/perf_isolation_boot.lua girişindeki kıyaslama profilleri artık normal tam oyun başlatmasını kullanıyor. Tam oyun/terrain-only/objects-only/Rigby-only/terrain+objects/HUD-off/Rigby-off ile aynı authored dünya, oyun mantığı, kamera ve nesne popülasyonu korunuyor; yalnız draw katmanları filtreleniyor. Boş motor tabanı ayrı kıyaslanamaz baseline.
- objects/renderer.lua opsiyonel flags nesne ve Rigby çizimini kapatır, nesne toplama ve derinlik sıralaması korunur. main.lua HUD ve terrain draw gate uygular. terrain25d_runtime.lua terrain GPU draw kapalıyken de stream/chunk/asset hazırlığını devam ettirir. DOLAYISIYLA bu modlar yalnız draw-stage ayrımı içindir; kapalı sistemlerin CPU update işi devam eder ve bağımsız no-call testi değildir.
- Main'e merge yok. Değişikliklerin HEAD/dosya geri okuması dışında Lua5.4/LuaJIT, quality CI, .love üretimi, Android görsel ve A/B testleri doğrulanmadı; yeni CI sonuçları üzerinden kabulü yap. Grafik geçişinde beklenen obje sayısı ve chunk gap sabit tutulmalı.

---

## 2026-10-30 — İzole gerçek R2 arazi ve kamera hareketi (AÇIK KABUL)

- Performans açılış seçicisindeki terrain ve terrain+objects profilleri statik doku tekrarı yerine gerçek authored R2 + world.stream (render_only_25d) + world.terrain25d_runtime kullanıyor. Gameplay/Rigby/inventory/harvest yaratılmıyor; R2 query/geometry/chunk worker yalnız arazi için gerekli.
- Tüm izolasyon modlarında parmak/mouse sürükleme, pinch/wheel zoom, WASD/yön tuşu kamera hareketi; obje SpriteBatch camera transform eklendi. Tam oyun kendi mevcut kamera/input sistemini koruyor.
- tests/perf_isolation_boot.lua menü yüklenmeden oyun modülü çağrılmaması ve kamera callback'lerinin varlığını kontrol etmek üzere genişletildi. Repo dosya SHA ve HEAD geri okundu.
- AÇIK: gerçek LÖVE/Xvfb, Lua5.4/LuaJIT, Android kamera/R2 görüntüsü ve FPS A/B kabulü. Main'e merge yok.

---

## 2026-10-30 — Açılış performans izolasyon profilleri (KABUL BEKLİYOR)

- Kullanıcının isteğiyle mod seçilmeden gerçek oyun başlatılmayacak şekilde main.lua başına hafif core/perf_isolation_boot.lua yönlendiricisi eklendi; ayrı karakter, arazi doku örneği, obje örneği, ikili kombinasyonlar, boş sahne ve tam oyun seçimi var.
- Yalıtılmış modlarda kapalı katmanlar hiç require edilmez; world/stream/worker/save/gameplay döngüsü kurulmaz. Karakter gerçek Rigby görselini yükler; arazi yalnız mevcut atlas grass tekrarından oluşan statik proxy, objeler yalnız 24 adet atlas proxy'dir. Tam R2 tek başına renderer testi henüz YOK.
- Var olan quality.yml içine tests/perf_isolation_boot.lua Lua5.4/LuaJIT kontrolü eklendi. Gerçek oyun yolu GitHub CI ortamında CI=true ile mevcut davranışını korur.
- Kabul: CI, izole Android screenshot ve FPS, boş sahne vs karakter vs gerçek R2 kıyaslaması açık; normal mod Stage5/6 ve R2 regresyonları henüz tekrar doğrulanmadı. Main'e merge yok.

---

## 2026-10-30 — Düşük çözünürlüklü gölge atlasları (KABUL BEKLİYOR)

- Kullanıcı kararı: gölgeleri ağaçların GERÇEK 128px RGBA alpha siluetlerinden üret, 32x32 gölge texture atlaslarını ağaç atlasından ayrı tut; GitHub CI ve .love test paketi isteği.
- Deney dalı: scripts/build_tamu_static_shadow_atlases.py artık source atlas_01.png SHA denetimi ile 60 varyant için 8 adet küçük gölge atlası + v3 manifest üretir. Orijinal 128px ağaç dokuları korunur.
- objects/terrain25d_sprites.lua paketlenmiş v3 manifest varsa önce gölge SpriteBatch (32px mask), ardından özgün object atlasını kullanır; dinamik/contact shadow algoritması bu yolda çalışmaz. Paketleme 8 sayfayı ekler. quality.yml içinde Lua test ve LOVE ZIP sayfa/manifest kontrolü vardır.
- Açık: yeni CI sonucunu oku; gerçek 8 PNG ve .love artifact çıktısı henüz doğrulanmadı. GitHub repo içinde üretilmiş PNG binary dosyalarının commit'i henüz yoktur, build aşamasında üretilir. Android cihaz A/B FPS/görsel kabulü açık. Main'e merge yok.

---
## 2026-10-30 — Statik obje-gölge atlas deneyi (KABUL BEKLİYOR)

- Karar: önceden gölgeli obje atlasları, karakter boyutu aynı kalırken ağaçlar dünya ölçeğinde büyütüldü. Main'e merge yok.
- scripts/build_tamu_static_shadow_atlases.py 60 object variant'ı mevcut atlas_01.png'den alarak 8 adet üç saatlik dilim için 4'er sayfa (toplam 32 PNG) ve v2 manifest üretmek üzere eklendi.
- scripts/package_tamu_love.py build aşamasında bu atlasları pakete eklemek üzere güncellendi. game/love/objects/terrain25d_sprites.lua manifest mevcutsa birleşik gölgeli atlası çizer ve eski dynamic/contact shadow pass'ini atlar; manifest yoksa eski kodu kullanır.
- Lua5.4/LuaJIT için tests/terrain25d_static_shadows.lua ve mevcut quality.yml testi eklendi.
- AÇIK: Yeni CI, gerçek PNG/.love üretimi, mobil max texture/memory, LÖVE/Xvfb visual overlap, Android gerçek FPS ve mevcut görsel/saklama regresyonları kanıtlanmadı. Kaynak değişikliklerini üretim kabulü sayma.
- Sonraki adım: quality logunu ve üretilmiş ZIP'i açarak 32 sayfa + manifesti doğrula; görüntüyü incele ve Android sabit/yürüme karşılaştırmasını yap. Main'e merge yapma.

---
## 2026-10-30 — Telemetri iyileştirmesi (kısmi, CI/Android doğrulanmadı)

- Aynı deney dalında var olan `core/diagnostics.lua`, analiz betiği ve quality testleri tespit edildi; devirdeki 'henüz yapılmadı' notu kod durumunu yansıtmıyordu.
- Değişiklikler: bellek içi 120 kare ring buffer, F10 ile yerel son-kare JSONL export, dosya yazma istisnasında oyunu durdurmama, idempotent close, fatal hata mesajı yerine korelasyon hash'i, mevcut diagnostics testinde export doğrulaması.
- Main'e merge yok. GitHub dosyaları/diff geri okundu; CI çalışma sonucu ve gerçek LÖVE/Android telemetri dosyası doğrulanmadı. `quality.yml` mevcut Lua5.4/LuaJIT diagnostics testini içerir.
- Açık: CI kabulü, Android `.love` kurulumu ve JSONL export erişimi, log overhead A/B, mobil dışa aktarma UI, gölge sabit/yürüme cihaz karşılaştırması, kapsamlı exception/worker/sun korelasyonu. Beyin kanonik görevine bu sohbette yazılmadı.

---
## 2026-10-30 — TAMU Android performans ve telemetri devri (AKTİF, açık)

**Proje:** `TheOsmanYILDIRIM/TAMU-K-K`, yetkili deney dalı `experiment/25d-binary-vertex-20261030`; main'e merge yok. Çalışmadan önce güncel HEAD, `AGENTS.md`, `game/love/README.md` ve kanonik agy-vault görev revizyonunu kontrol et. Kullanıcı gerçek Android'de stabil 60 FPS, yürürken görünür eksik chunk sıfır ve gelecekte AI/mob bütçesi istiyor. GitHub Xvfb CPU zamanı Android GPU FPS'si değildir.

### Bu sohbetin doğrulanmış gelişmeleri
- İlk çok uzun açılışın başlıca nedeni terrain legacy JSON ve Rigby sayısal JSON parse maliyetiydi. 27 chunk binary cache testi 152,12 s → 8,71 s; hızlı JSON parser Rigby sayısal parse yaklaşık 7 s → 0,3 s (ilgili önceki CI). 156 authored chunk önden binary bake + worker, warm GPU LRU ve background decode hazır. WFC/R2/Stage5/6/Creative, eski veriler korunacak.
- Normal Android ölçümlerinde kullanıcının bildirdiği genel FPS 15–30 (yaklaşık 20). İlk HUD gözlemi yaklaşık 33 FPS, CPU update 5,1 ms, draw 20,7 ms, eksik chunk 0/37.
- Android ayrıntılı teşhis iki ekran görüntüsünde durma/yürüme için sırasıyla: FPS **46/23**; terrain **0,36/0,53 ms**; obje toplama **0,19/0,18**; sıralama **0,12/0,10**; gölgeler **0,79/20,77**; Rigby **0,97/1,91**; sprite **10,24/10,62**; HUD/diğer **3,10/3,01**; toplam draw **15,88/37,25 ms**. Bu, **yürüyüşte gölge yeniden hazırlama** için güçlü doğrudan cihaz kanıtıdır. Ölçümün wall-clock süresi grafik sürücüsü beklemesini içerebilir.
- `objects/terrain25d_sprites.lua`: kamera hareketinde `same_scene` yanlış biçimde önbelleği bozduğu için her kare projeksiyon gölge ve temas SpriteBatch'i yeniden yapılıyordu. Deney dalında `19c79eac` kamera pans sırasında batch transform ile yeniden kullanım, `bd3a8777` ilgili test beklentileri güncellendi. **Android bu değişiklikle tekrar ölçülmedi.**
- 156-chunk terrain GPU mesh birleştirme (deney dalında zaten mevcut) 21→2 terrain draw call, 63→44 toplam draw call; 79.125 pikselde sıfır görsel fark. Buna karşılık Xvfb CPU p95 örn 9,387→10,023 ms, başka run 9,499→10,404 ms: CPU/GPU ödünleşimi; mobil kabul henüz bilinmiyor.
- Diğer deneyler: obje/sıralama scratch havuzu, terrain reveal shader state/projeksiyon cache, atlas sayfası taramasını her kareden 2 Hz'e azaltma (`55c8ee57`), `conf.lua` varsayılan düşük-DPI + `TAMU_NATIVE_DPI=1` geri dönüş, Android Rigby görsel pose 30 Hz + `TAMU_RIGBY_POSE_HZ=0` geri dönüş; telefon FPS'sinde belirgin iyileşme görülmedi. GitHub ekran tanısı 720×1100 DPI 1.0'dır, Android fiziksel framebuffer ölçümü değildir.
- CI 400 FPS eşdeğeri **CPU p95 ≤2,5 ms** hedefliyor; güçlü runner'ın FPS'sini mobil FPS ile eşleme. Son gölge değişikliği run [41094870012](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41094870012) **failure**, çünkü desktop CPU p95 hedefi geçilmedi: unbatched p95 10,117 ms (21 çağrı), batched 11,216 ms (2 çağrı), görsel fark sıfır. Önceki Lua sözdizimi, GPU worker, warm cache testleri yeşil; run sonraki yürüyüş kabulünü tamamlamadı.
- En son `.love` Android karşılaştırma ve ayrıntılı teşhis paketleri sohbet eki olarak verilmişti; **yeni sohbette sandbox varlıklarının taşındığını varsayma**. Telefondaki fotoğraflar kaynak cihaz kanıtıdır; GitHub Actions değildir.

### AÇIK / sonraki iş — kullanıcının son kesin isteği
Kullanıcı **görsel HUD yerine ciddi, otomatik analiz edilebilir, bol verili standart performans ve hata loglama/telemetri altyapısı** istedi; **bu kapsamlı sistem henüz kodlanmadı**. Öncelik bunu geliştirmek ve mevcut gölge düzeltmesinin telefonda yararını kanıtlamak. Mevcut kayıt yollarını ve `game/love` mimarisini koru; onay olmadan yeni görev/üst klasör düzeni açma. Gerekirse oyun içinde modüler log toplama bileşeni mevcut `core/` altına, performans ring buffer/structured JSONL kayıtları LÖVE `love.filesystem` user save dizinine: frame sequence, timestamp/monotonic saat, frame dt/FPS p50/p95/p99, update/draw alt fazları (terrain, objects, shadow, Rigby, sprite, UI), GC/alloc, GPU drawcalls/batched, shader switch, texture memory, camera hareketi, resident/chunk gap/worker/cache, sun/reveal, thermal/renderer/device metadata elde edilebilenler, yükleme/istisna/error ve semptom tetikleyici spike/correlation raporları. GPU zamanı LÖVE getStats ile **doğrudan ölçülemez**; CPU-wall ve Android GPU sınırını ayrıştır. Ölçüm overheadi ve gizlilik/retention/rotation caps test et; kullanıcı verisini/sırları dump etme. Logları dışarı otomatik aktarma, kullanıcı kontrollü export. Hata ve crash için son N kare ring buffer; kapanış/fluş güvenliği. Eski HUD opsiyonel, temel analiz dosyada.
- Sabit/hareketli kamera cihaz A/B testi: shadow cache reuse/rebuild, duration, object counts, sprite queue/flush, sun change, frame spikes. Mevcut CI regresyonu gerçek Android FPS kabulünün yerine geçmez.
- Görsel kabul, Stage5/6 save, Rigby socket, Creative, zero visible missing chunks ve Android bellek/thermal regressions kontrol edilmeden merge yapma.
- **Kabul ölçütleri:** Telemetri üretimi gerçek Android cihazda dosya olarak kanıtlanmalı; analiz scripti raporu doğru okuyabilmeli; overhead düşük, döngüsel kayıt kapasitesi sınırlı ve bozuk log hatasında oyun çalışmaya devam etmeli; sabit/yürüme karşılaştırmasında gölge CPU ve draw maliyeti doğrulanmalı; mevcut testler bozulmamalı.
- Canonical Beyin görevine işlem yapılacaksa yalnız resmî DirectSync/CAS motoru ve mevcut görev kullanılmalı; plain GitHub write ile Beyin'e el ile yazma. Henüz kanonik görev güncellendiği iddia edilmemeli.

---
## 29 Ekim 2026 — Creative 2,5D bütünleştirme

- En son main 2,5D ve karakter/rig değişikliklerini kayıpsız korumak için
  `experiment/tamu-creative-main-reconcile-20261029` dalında düzenlendi.
- 13 modüler tür, 34 atlas görünümü, Creative seçim/dokunma/döndürme/kat/geri alma,
  32 dünya birimi yerleşim ve yakındaki temel kotuna hizalama.
- Creative eşyaları envanter düşürmeden ve Stage6 kayıtlarına dokunmadan
  oturum içinde üretir; kullanıcının kalıcı save ve eski World Builder verisi korunur.
- Kalıcı save, çok oyunculu otorite, geçilebilir kapı/merdiven fiziği,
  gerçek Android FPS ve nihai görsel kabul hâlâ açıktır.
- Görev ancak Quality CI + gerçek LÖVE paket smoke + artefakt incelemesi
  ardından main'e alınır. HEAD ve CI sonuçları çalışma sonunda doğrulanır.

## 2026-10-29 — Osman canlı rig, main entegrasyonu
- Kullanıcı kararı: Plazma yerine canlı iskeletli ve sağlak 4 yönlü Osman; 2.5D/R2 dünya aynı kalır. `TAMU_USE_PLASMA=1` kontrollü geri dönüş. Orijinal core/plazma görselleri ve Stage6 kayıtları korunur.
- 30 PNG parçası + `rig.json` (40 kemik, 24 slot, 44 animasyon) GitHub deney dalında gerçek binary dosyalar olarak import ve real LÖVE testine tabi tutuldu (run 40924546618, başarılı). Frame atlası yok.
- Kaynak SHA256 onaylı `86ed6aa3e40a082b9f7b67e9074a2d3b1149facb9c785a9e44956397ab22ad92`; `provenance.json` parça SHA listesi. Yeni Lua player/rigby_runtime.lua + player/rigby_visual.lua ve objects/renderer.lua; düzeltmeli core_tool_integration.lua testi.
- Bu entegrasyon, en son doğrulanmış `main` `0a27cbfcda4bd524389056616b6f9fcbfab2668e` ağacıyla uzlaştırılarak hazırlanmıştır. Yalnız diff/CI/gerçek LÖVE/test paket sonucu kontrol edilirse yeni main sürümü doğrulanmış sayılabilir.
- Oyun mantığı, prosedürel R2 dünya, kaynak hasat, kayıt, bağımsız R2/Stage6 güvenlik sözleşmeleri değişmedi. Android gerçek cihaz görsel/perf ve item socket oyun ekranı kanıtı henüz açık.
---
## 2026-10-29 — R2 + kompakt atlas 2.5D normal açılış
- Son doğrulanan main tabanı `497b98e1a361e4468994626cf82a2d3ff83cc2d2`; R2/25D default değişikliği `experiment/tamu-25d-standard-packaged-20261029` dalında test edildi: `4fa69d320a6631500dc162c511a86ac5293b8e22`.
- Derlenmiş .love içinde iki authored JSON `assets/worldbuild` altında, SHA256 doğrulanıyor; paketlenen dosya gerçek LÖVE smoke ile açılıyor. Paket workflow run 40922389453 ve quality 40922389592 başarılı. Eski Stage5/stat fixture'ları kendi legacy modunda tutuldu. R2 session-only; Stage6 kayıt moduna otomatik taşıma yok.
- Eski dünyayı **varsayılan olmaktan çıkar**; eski dosyaları, ana plazma ve SaveV2'yi silme. Yeni canlı rig karakteri bağımsız deneyde durur; main'e varlıkları henüz tam aktarılmadı. Birleşik yerel .love önizlemesi R2+25D+rig gösterir; Android cihaz doğrulanmadı.
- Devirden sonra güncel main HEAD, yeni main workflow/quality CI sonuçları ve paket SHA tekrar kontrol edilir.

# SESSION_HANDOFF — güncel LÖVE2D oyunu (2026-10-18)

## Son doğrulanmış entegrasyon
- Proje: `TheOsmanYILDIRIM/oyun`, `main`; bu devir yazılmadan önce bağımsızca geri doğrulanan oyun entegrasyonu HEAD: `578bf16667ce963c3f7a7d8dc1f1aef1ee2e2c0e`. Yeni çalışmada önce güncel HEAD ve CI yeniden okunur.
- Aktif mimari: `game/love/` LÖVE2D/Lua, 45° izometrik prosedürel biyomlar/Marching Squares/chunk, A*/CCD, 55% suda hız ve 50% immersion, Core/crystal shader + ön/arka plazma, axe/tool efektleri, Stage5 inventory/crafting/workbench, mobil HUD.
- Stage6: `game/love/save/` sürümlü checksum/checkpoint/recovery ve detached Stage5 harvest/craft/build işlem köprüsü `main`e entegre; **yalnız `OSMAN_STAGE6_EXPLICIT=1` ile açık world UUID verildiğinde** çalışır. Varsayılan autosave kapalıdır; `F5` checkpoint reload test arayüzü vardır. Önceki sağlam state recovery ve corruption quarantine testleri mevcuttur; journal bağımsız event replay sistemi değildir.
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

---

## [SOHBET-H | TAMU Terrain P0] — EşRota ikinci dalga salt okunur araştırma raporu

- **Durum:** `review_requested` — neden zincirinin GPU aşaması doğrulandı; max_missing=0 ve Android kabulü doğrulanmadı.
- **Proje / kaynak:** `TheOsmanYILDIRIM/TAMU-K-K`, yalnız `experiment/25d-binary-vertex-20261030`.
- **Başlangıç HEAD (doğrulandı):** `59b3fcf94f6d5a02c840a1198a05c73c89fa99d8` (compare branch = identical).
- **Zaman (UTC):** 2026-10-31; kesin UTC saat alınmadı.
- **Sahiplik:** yalnız SOHBET-H bölümü; kod, CI, Beyin, görev, workflow değiştirilmedi.
- **Rapor hedefi:** `SESSION_HANDOFF.md#SOHBET-H`; `revision_guard=cas`; `readback_method=provider_reopen`; `report_only`.
- **Ön okuma:** AGENTS.md (`2730a8e17fd1a91ca607e8d4007b6929ceeb2c04`), README.md (`ee6ba8fe72ffaa18998069594a8551bea6d3af0b`), SOHBET-G devri, CI #41194049897 job adımları, ilgili Lua kaynakları.

### Yeni bulgular ve kanıt

| Bulgu | Gerçek kanıt | Mekanizma ve kesinlik | Minimal değişiklik önerisi | Test/kabul ve risk |
|---|---|---|---|---|
| **P0 kesin anlık durum:** frame=7 key `-1:-3` yeni görünür, önceki kare resident, worker sonucu hazır fakat GPU mesh yok | SOHBET-G / CI #41194049897: `max_missing=1`, `worker_pending=0`, `worker_ready=1`, `no_previous_resident=0`, `first_visible=1`; `main.lua` 990–1015; `terrain25d_runtime.lua` 903–948 | Sorun bu karede *resident chunk'ın mesh yüklemesini/görünür tamamlanmasını kaçırmasıdır*. Ancak tek karelik snapshot, worker sonucunun **hangi karede** hazır olduğunu veya önceki karede upload bütçesinin hangi key tarafından tüketildiğini göstermediği için yukarı akış kesin kök neden henüz ispatlanmadı. | Öncelikle var olan WALK_PROBE'ye key bazında `ready_since_frame`, `first_visible_frame`, `selected_upload_key`, `upload_cap_hit` ve `deadline_hit` tanısı ekleme önerisi; üretim davranışını değiştirmez | Mevcut CI yürüyüşünde `-1:-3` için ilk ready ve seçilebilir upload karelerini ispatla. Gözlem olmadan 'worker geç kaldı' veya 'tek neden sıralama' deme. |
| **P0 güçlü sıra hipotezi:** halo CPU ready iken görünür chunk iş yükünün arkasında GPU kuyruğunda bekleyebilir | `stream.lua` 68–144: required dizisi önce tüm visible, sonra bounded halo; `terrain25d_runtime.lua` 838–915: `for c in ipairs(chunks)`, moving `upload_cap=1`, deadline ~2ms; `poll_binary_results` → `enqueue_binary` → upload | Tek GPU upload slotu mevcut görünür ilk eksik chunk'a harcanabilir; daha sonra görünür olacak halo aynı karede yüklenemez. `ready=1` gözlemi hipotezle uyumlu, fakat mevcut log bu özel karede tüketilen upload key'ini vermiyor. | **Koşullu görünürlük-eşiği önceliği:** Mevcut görünürlerin hepsi GPU-ready ve bütçe boşsa, halo içinden bir sonraki kamera viewport'una en erken girecek `binary_ready` chunk'ı seçerek izinli tek upload'u ona ayır. Önce görünür eksikleri tamamla; `upload_cap=1` ve 2ms guard korunur. İlk deneme yalnız mevcut sıra değiştirme + scoped test; bellek kapasitesini artırma. | R2 viewport sınırları hem x/y/diyagonal/ters kamera yönü hem zoom senaryolarında test edilsin. Olumsuz etki: yanlış edge tahmini, halo churn, CPU aşımı. Eski ETA denemesi `max_missing=4` verdi; salt ETA skorunu tekrarlama. |
| **P0 ölçüm boşluğu:** CPU ready ≠ GPU drawable | `terrain25d_runtime.lua` 874–906: `Baked.load_ready` GPU üretimi, başarısız veya deadline geçişi; 926–944 `missing_visible` ancak `_25d_meshes` sonrası azalıyor | Worker hazır veriyi tek başına çizemez; `binary_ready` → `_25d_meshes` arasındaki geçişi bütçe, öncelik ve aşama kilitleri belirler. | Ayrı tanıda `load_ready` başarı/başarısızlık, süre ve key; görünür hâle gelişten bir kare önce GPU-ready olma durumunu logla. | `max_missing=0` 480 kare yürüyüş, ek uç ve ters-yön fixture'ları; CPU p95/p99, upload sayısı, VRAM artışı ayrıca değerlendirilsin. CI masaüstüdür, Android FPS kanıtı değildir. |

### Tekrar edilmemesi gereken geçmiş çalışmalar

SOHBET-G'nin uygulanmış ticket/FIFO düzeltmesi, visible/halo Lua tablo alias düzeltmesi (77→18, max_missing 7→2), yönlü halo ve `max(80,visible+24)` kapasitesi, başarısız ETA denemesi ve `upload_cap=1` korunuyor. Bunlar yeni keşif veya kabul edilmiş çözüm olarak sunulmuyor. `stream.lua` blob `7874bfe9e02bac18dc1560020835702736ee9edd`; `terrain25d_runtime.lua` blob `af0874ac9d4fb641207b2bec6f0110a0bbeab14a`; `main.lua` blob `80d742be8c66d77c21650ffec38a1b3800aabb67`.

### Yapılanlar / yapılmayanlar

GitHub connector ile AGENTS, README, SESSION_HANDOFF, Stream/Runtime/Main/test kodu açıldı; branch/başlangıç SHA eşitliği doğrulandı. CI #41194049897 job listesi: gate success, test failure, precompile authored R2 safety halo adımı failure; takipteki HUD/Stage5/Stage6 ve başka adımlar skipped. SOHBET-G'nin `max_missing=1` ve `frame=7` metrikleri mevcut tesliminden okundu, bağımsız yeni log/artifact çekimi veya test koşusu yapılmadı. Kod/CI/Beyin/workflow değişikliği yapılmadı. Gerçek Android JSONL yok, masaüstü testler mobil FPS değildir.

### Açık işler, engeller ve sonraki adım

Bir sonraki **uygulama** sohbeti mevcut WALK_PROBE altında GPU upload selection/ready timing kanıtını ekleyip aynı CI yürüyüşünü değerlendirmeli; ancak bu kanıttan sonra yön-bağımsız, yalnız hazır ve bir sonraki görünürlük eşiğine yakın halo'yu seçen minimal algoritmayı deneyip `max_missing=0` göstermeli. Herhangi bir yeni hız/VRAM maliyetini ölçmeden upload cap ve halo kapasitesini büyütmemeli. Kullanıcı bu raporla koordinatöre dönecek; otomatik iletim yok.

### Koordinatöre teslim

Bu bölüm için sağlayıcı yeniden açma ve blob/commit SHA sonucu rapor yazımı sonrasında doğrulanır. Rapor yazıldı diye P0 düzelmiş veya Android testi geçmiş sayılmaz.

### 2026-10-31 — SOHBET-H uygulama / WALK_PROBE GPU sıra tanısı (P0 açık)

- **Durum:** `in_progress` / `pending_unverified`; **max_missing=0 kanıtlanmadı**. Başlangıç HEAD `e78e8364c15a3b49bebd8634199974a94d87f231`. Yalnız yetkili deney dalına yazıldı.
- **Kapsam ve neden:** Mevcut SOHBET-H frame=7, key=-1:-3, worker_ready=1 örneği GPU yükleme bütçesi sıralamasını tek başına kanıtlamıyor. Öncelikle mevcut `TAMU_25D_WALK_PROBE=1` akışında CPU-ready zamanı ile GPU seçim/yükleme sonucunu ilişkilendirecek tanı eklendi.
- **Değişiklik:** `game/love/world/terrain25d_runtime.lua` içine yalnız aktif WALK_PROBE sırasında `TAMU_WALK_GPU_UPLOAD` (frame/key/ready_since/loaded/visible) ve `TAMU_WALK_GPU_WAIT` (frame/upload_cap/kalan eksik görünür hazır işleri) logları kondu. Üretim sırasında bu tanı kapalıdır; `upload_cap=1`, CPU fallback, yükleme sırası, halo kapasitesi ve görsel pipeline değiştirilmedi.
- **Commit:** [`46ec0399ad33065b1f5eb214d7e036e0c5f5e7ce`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/46ec0399ad33065b1f5eb214d7e036e0c5f5e7ce). Kod dosyası sağlayıcıdan tekrar açıldı; blob SHA `623190628508c664ee244a27f7fd1b03e0415d20`. Commit sonrası dal HEAD aynı commit olarak doğrulandı.
- **Test/CI/artefakt:** Mevcut tarihsel CI [#41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897) `failure`, `max_missing=1`; **bu yeni commit için CI, LuaJIT, LÖVE/Xvfb veya Android testi çalıştırılmadı**. Workflow/dispatch açılmadı. Kod kaynağı geri okundu; sentaks ve yürütme kabulü doğrulanmadı.
- **Kanonik Beyin:** `agy-vault/main` mevcut görev `oyun-25d-runtime-renderer-integration-20261028` rev14/`active` okundu. Resmî DirectSync motor işlemi/receipt tamamlanmadığından Beyin yazımı yapılmadı; bu rapor onun yerine geçmez.
- **Engel / açık iş:** Log çıktısı olmadan mevcut upload slotunu hangi key'in tükettiği kesinleşmiyor; bu aşamada yeniden sıralama spekülatif olur. Yürüyüşü mevcut test ortamında bu loglarla çalıştır, `-1:-3` için hazır olma ve seçilme karelerini karşılaştır, ardından gerekçeli minimal sıralama düzeltmesini uygula. 480 kare için `max_missing=0`, x/y/diyagonal/ters yön regresyonu ve bütçe ölçümü şart. P2/P3 henüz başlatılmadı; Android FPS bilinmiyor.
- **Rapor:** Yalnız mevcut H bölümü; `report_only`, blob-SHA CAS, diğer ajan alanları korunacak. Rapor geri-okuma blob SHA'sı commit sonrası ayrıca doğrulanır.

### 2026-10-31 — SOHBET-H GPU-ready öncelik düzeltmesi (kabul açık)

- **Durum:** `pending_unverified`; yalnız H'nin kod sahipliği `world/terrain25d_runtime.lua` değiştirildi. Başlangıç HEAD `d238431482fea2c18f6015546db77725d3ea17ec`; diğer ajanların G/I/J kayıtları ve kaynakları korunuyor.
- **Somut kod bulgusu:** Eski draw döngüsü görünür/halo listesini tek sırada işliyor; CPU coroutine işi deadline veya resume bütçesini tüketirse `binary_ready` durumundaki chunk'ın GPU yüklemesi aynı karede seçilmeyebiliyor. Önceki WALK_PROBE frame=7 kanıtı bu ihtimalle tutarlı, kesin kök nedeni veya yeni çözümün kabulünü tek başına kanıtlamıyor.
- **Minimal kod:** Hazır ve eksiksiz binary sonuçları `visible_ready → halo_ready → diğerleri` sırasıyla GPU hazırlama döngüsüne sunuluyor. `Stream:visible()` listesi mutasyona uğramıyor; mevcut visible/halo kendi sırasını koruyor. GPU upload cap=1, deadline, fallback, atlas, cache ve bake davranışı değiştirilmedi.
- **Commit:** [`e00f63480a94a94992a4924be9447cf8c51909ce`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/e00f63480a94a94992a4924be9447cf8c51909ce); kod readback blob SHA `06e1aee6edec407d412ce4ab2fcfc637be0d3258`; commit HEAD ile doğrulandı.
- **Test/CI:** Bu ortamda Lua5.4/LuaJIT/LÖVE yürütücüsü yok; hedefli regresyon ve gerçek WALK_PROBE **çalıştırılamadı**. GitHub eklentisinde yeni workflow dispatch aracı yok; Supabase özel job kuyruğunun doğrulanmış enqueue/invoke sözleşmesi ve yetkisi yok. Bu nedenle yeni quality CI tetiklenmedi. Eski [CI #41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897) `failure/max_missing=1`, yeni commit için kanıt sayılmaz.
- **Avenox Beyin:** Kanonik rev14/`active` görev mevcut; resmi DirectSync semantik task update/receipt uygulanmadı, kalıcı Beyin güncellemesi iddia edilmiyor.
- **Açık/engel:** Yeni kod için 480 kare WALK_PROBE `max_missing=0`; x/y/diyagonal/ters kamera yönleri ve worker race, upload deadline/resume maliyeti, Lua/LÖVE regresyonu koşulmalı. Başarısız olursa güncel logla H kapsamındaki algoritma yeniden düzeltilmeli. P2/P3 ve Android FPS kabulü açık. `main`, Stage6, yedekler, PNG atlasları, workflow değiştirilmedi.
- **Rapor:** `report_only`, CAS; diğer bölümler korunuyor, readback blob SHA gönderimden sonra doğrulanır.

### 2026-10-31 — SOHBET-H VM yerel test teslimi (eski CI artefaktı)

- **Durum:** `pending_unverified`; bu kayıt önceki SOHBET-H VM çalışmasının kullanıcıya teslim edilen sonuçlarını aktarır. **Bu rapor güncellemesi sırasında testler yeniden çalıştırılmadı**. Eski CI artefaktı `13039019225` indirildi; bu artefakt `e00f63480a94a94992a4924be9447cf8c51909ce` sonrası GitHub HEAD'i değildir.
- **VM test yöntemi:** İndirilen Actions ZIP ve içindeki `.love` paketinin ZIP bütünlüğü başarılı olarak bildirildi; 550 oyun dosyası çıkarıldı. Testler VM'de LuaTeX Lua çalıştırıcısıyla, eski `.love` tabanı ve yerelde uygulanan GPU-ready öncelik değişikliği üzerinde yürütüldü. Bu, gerçek LÖVE GPU/Android cihaz testi değildir; yerel değişiklik GitHub'a ayrıca yazılmadı.
- **Önceki oturumun bildirdiği PASS:** `tests/terrain25d_runtime.lua`, `tests/r2_viewport.lua`, terrain batching, shore/water/path, static shadows.
- **Önceki oturumun bildirdiği FAIL:** terrain geometry (eksik worldbuild JSON); object population (`batches` alanı `nil`). Eski artefakt üzerinde gözlendi; güncel dal için aynı hatalar doğrulanmadı.
- **Açık kabul:** VM'de LÖVE bulunmadığı için 480 kare `WALK_PROBE`, gerçek GPU upload sırası ve `max_missing=0` test edilemedi. Android FPS ve yeni commit'e ait CI geçişi doğrulanmadı. `#41194049897` geçmiş `failure/max_missing=1` ölçümüdür, yeni çözümün kabulü değildir.
- **Kayıt/sahiplik:** Yalnız mevcut SOHBET-H bölümüne `report_only` CAS güncellemesi; G/I/J içerikleri, `main`, oyun kaynakları ve workflow korunur. GitHub rapor readback blob SHA'sı teslimde belirtilecektir.
- **Sonraki hedef:** Eksik fixture ile eski paket uyumsuzluğunu güncel kaynaktan ayır; hedefli Lua/LÖVE regresyonu ve 480 kare yürüyüşü güncel `e00f6348` veya daha yeni yetkili dal üzerinde çalıştırarak `max_missing=0` ve bütçe/parite kabulünü kanıtla.

## [SOHBET-I | TAMU Regresyon Denetimi] — EşRota ikinci dalga

- **Durum:** `review_requested`; salt okunur bağımsız kod incelemesi, **regresyon kabulü açık**. İncelenen başlangıç HEAD `59b3fcf94f6d5a02c840a1198a05c73c89fa99d8`; rapor CAS anındaki HEAD `f0319d15df1bd7d47bb8d736ae6a616afce841ee`. Değişen başka bölümler korundu.
- **Sahiplik/kanal:** `github:TheOsmanYILDIRIM/TAMU-K-K@experiment/25d-binary-vertex-20261030:SESSION_HANDOFF.md#SOHBET-I`; `report_only`, `revision_guard=cas`, `readback_method=provider_reopen`. Kod, CI, Beyin, görev ve workflow değiştirilmedi.
- **CI:** [#41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897), test edilen `ff55a993d6b065ca8df12dd47305d01809b6c2b3`: `gate=success`, `test=failure`, `Precompile complete authored R2 polygon area with safety halo` adımı başarısız; bu sonuç sonraki object/Creative/Stage6 testleri ve yeni HEAD için geçiş kanıtı değildir.

### Kaynak ve regresyon matrisi

| Alan | Somut kaynak ve test | Denetim kararı |
|---|---|---|
| Diagnostics async writer / backpressure | `game/love/core/diagnostics.lua:56-87,89-117,304-319`, `core/diagnostics_worker.lua:8-29`, `tests/diagnostics.lua:85-118`. Normal `flush` 4 girişlik dolu kuyrukta drop sayıyor; üretimde thread append kullanıyor. | **Kaynakta doğrulandı, Android açık.** `flush(true)` doluluk sınırını atlıyor, `close()` `writer:wait()` yapıyor: shutdown baskısı ve worker hatası/kayıp kayıt gerçek cihazda doğrulanmalı. Açık kullanıcı export'u senkron `filesystem.write` yapar; her karelik writer değildir. |
| dt alignment | `core/diagnostics.lua:159-167,218-260,284-302`; `tests/diagnostics.lua`. `draw_done` örneği sonraki `begin(dt)` ile kesinleniyor. Son frame `dt_confirmed=false`. | **Kod mantığı uygun**, ancak gerçek VSYNC/Android FPS ölçümü yok. Doğrulanmamış son kare pacing yüzdeliklerine katılmamalı. |
| Selection + player depth + setDrawRange | `objects/renderer.lua`, `objects/terrain25d_sprites.lua:459-541`, `tests/terrain25d_object_population.lua:57-124`. Seçim ayrı overlay; statik batch prefix/split ile oyuncu öncesi/sonrası çiziliyor. | **Mock cache/range testleri mevcut**, gerçek LÖVE GPU, alpha occlusion, equal-depth, selection/harvest/depletion, contact/shadow görsel kıyası **açık**. |
| Creative lazy atlas | `systems/creative_build_renderer.lua:6-51,73-105`; `tests/creative_build.lua:68-92`. Boş durumda atlas yüklenmez, ilk görünür/preview durumunda yüklenir; Creative kapalı olsa da mevcut yapılar çizilir. | **Mock lazy/fallback testi mevcut**; gerçek GPU ilk atlas upload gecikmesi ve saved yapı görüntüsü açık. |
| HUD cache / safe-area | `core/creative_build_hud.lua:7-51`; `tests/creative_build.lua:53-65`. x/y/w/h, active, page değişikliği cache'i geçersiz kılar. | **Mock geometri kanıtı var**; Android 320–360dp, 392–411dp, 19.5:9/20:9, 1.3 font scale matrisinde gerçek cihaz kanıtı yok. |
| Stage6 / alpha / depth | `main.lua:38-77`: R2 session-only ile explicit Stage6 bayrakları birlikte reddedilir. | **Kaynakta koruma görüldü**, Stage6 save/reopen ve alpha/silhouette/depth görüntü regresyonlarının bu HEAD'de geçtiğine dair kanıt yok. |

### Doğrulama, engel ve koordinatöre teslim

- İnceleme yalnız mevcut repo içeriği + CI metadata üzerinden yapıldı; **yeni test çalıştırılmadı**. Test dosyalarının bulunması testlerin başarıyla çalıştığı anlamına gelmez.
- SOHBET-G'nin terrain batching, halo, ticket/FIFO, shadow cache, atlas ve diğer optimizasyonları yeni keşif sayılmadı.
- **Açık kabul:** mevcut `tests/diagnostics.lua`, `tests/terrain25d_object_population.lua`, `tests/creative_build.lua`, Stage6 ve gerçek LÖVE/Xvfb alpha/depth/safe-area regresyonları P0'dan bağımsız koşulmalı. Android'de `dt_confirmed`, `dropped`, `trace_write_ms`, 16.667/33.333ms pacing, selection/depth/Creative görüntüsü ayrıca doğrulanmalı. Masaüstü p95 Android FPS kanıtı değildir.
- **Sonuç:** `review_requested`; genel regresyon PASS, Stage6 güvenliği ve Android 60 FPS kabulü **verilmedi**. Kullanıcı bu kayıt bağlantısını koordinatöre taşıyacak.


### 2026-10-31 — SOHBET-I P1 uygulama oturumu / engel ve readback

- **Durum:** `blocked / pending_unverified` — bu oturumda yeni kod commit'i veya gerçek regresyon test sonucu yok. Önceki rapor korunmuştur. İlk HEAD `e78e8364c15a3b49bebd8634199974a94d87f231`, paralel ajanların yeni commitleri saptanınca güncel handoff blob yeniden okunmuştur.
- **Kaynak doğrulaması:** `core/diagnostics.lua` blob `64113bb6903e34b8e628c096677480b06c746100`; `tests/diagnostics.lua` blob `1e20d076cbc110fde1b6a7cfcead5d5f852019b6`; Stage5 HUD blob `92d839bf09a9b4e0427945daaf81def0179f1787`, Creative HUD blob `587490318e7f0d0897afc29121315badf81e844e`, stat HUD blob `0a7bd35b06a6e22cc8a54b0642f17d57d0789f8d`. İlgili testlerin kaynak metinleri okundu, **yürütülmedi**.
- **CI:** [#41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897) gate `success`, test `failure` P0 authored R2 precompile; takip eden Stage5/Stage6/Creative/LÖVE testleri `skipped`. Manuel dispatch yapılmadı.
- **Test ortamı engeli:** erişilen konteynerde `lua5.4`, `luajit`, `love` yok; `git ls-remote` GitHub DNS çözümleme hatası verdi. Bağımsız Lua/LuaJIT ve LÖVE/Xvfb çalıştırılmış gibi gösterilmedi. Tahmine dayalı kod değişikliği yapılmadı.
- **Açık regresyonlar:** diagnostics shutdown/backpressure ve dt son kare; alpha/Y-depth/setDrawRange; saved Creative atlas; HUD safe-area/fontScale; Stage6 iki süreç save/reopen. Android FPS iyileşti iddiası yok; kullanıcı save/atlas/yedekleri korunuyor.
- **Sonraki hedef:** erişilebilir Lua5.4/LuaJIT + LÖVE/Xvfb ortamında `game/love/tests/{diagnostics,stage5_hud_layout,creative_build,core_stat_progression,terrain25d_object_population}.lua` hedefli testlerini ve mevcut Stage6 smoke'u P0 yürüyüş kapısından bağımsız koştur; çıkan tekrarlanabilir hatayı yalnız SOHBET-I sahipliğinde CAS ile düzelt ve test/readback kanıtı sun.
- **Beyin:** `agy-vault/main` kanonik `oyun-25d-runtime-renderer-integration-20261028` rev14 `active` okundu; resmî DirectSync güncellemesi/receipt yürütülmedi. Kod commit SHA `N/A`, test/artefakt `N/A`; yalnız mevcut SOHBET-I raporunun `report_only` güncellemesidir.


### 2026-10-31 — SOHBET-I P1 pacing ölçümü kod düzeltmesi

- **Durum:** `in_progress` / CI sonucu `pending_unverified`. Önceki engel raporu korunmuştur.
- **Bulgu:** `core/diagnostics.lua:finish_frame` son oturum karesini `dt_confirmed=false` işaretlese de CPU-only `frame_ms` değerini `window` p50/p95/p99 ve 16.667/33.333 sayaçlarına katıyordu; böylece mobil VSYNC pacing dağılımı kirlenebiliyordu.
- **Kod değişikliği:** `076cf0eb25001afbda795293908a62b05ab0f1be` — `dt_ms~=nil` değilse son frame'in JSONL `frame` kaydı korunuyor, ancak onaysız kare pacing histogramına / aşım sayaçlarına eklenmiyor. `game/love/core/diagnostics.lua` readback blob `12c01e2d37e477e70cb0546098ab7c35102b2f11`.
- **Regresyon testi:** `085b9b220338e0728fbf8215934dc3866a628aed` — mevcut `game/love/tests/diagnostics.lua` içine 90 frame için 89 confirmed / 1 unconfirmed ve `window_summary.count==confirmed` assertion eklendi. Readback blob `899bc35a427016549b9b7676c441b80e5948a0c5`. Yerel Lua/LuaJIT bulunmadığı için test **henüz koşulmadı**.
- **CI dispatch:** Supabase `control_private.tamu_dispatch_quality()` çağrısı mevcut `quality.yml` için `job_id=316dc5a0-8a44-4d3b-ab4f-064747d36c37` verdi; job sağlayıcı readback `status=success`, `result.accepted=true`, branch `experiment/25d-binary-vertex-20261030`. **Bu yalnız dispatch kabulüdür; GitHub run/test başarısı henüz doğrulanmadı.** Yeni workflow yaratılmadı; `main`/terrain/Rigby/Stage6/save/atlas/yedek değiştirilmedi.
- **Açık/engel:** CI yeni run ID ve Lua/LuaJIT/LÖVE/Xvfb fiili sonucu; diagnostics worker gerçek shutdown/backpressure, alpha/Y-depth, HUD safe-area, Creative lazy atlas, Stage6 save/reopen, Android p95/p99 ve FPS kabulü. Sonraki hedef yeni quality run'ı ve bağımsız P0-dışı regresyonları doğrulamak; kanıtlanan regresyonları yalnız SOHBET-I kapsamında düzeltmek.
- **Kanonik Beyin:** task rev14 `active` önceki okumadan biliniyor; bu aşamada DirectSync task-update veya receipt **uygulanmadı**.

---

## [SOHBET-J | TAMU Kalan Performans] — EşRota ikinci dalga raporu

- **Durum:** `review_requested` / `report_only`. Yalnız salt okunur kaynak incelemesi yapıldı; kod, CI, Beyin, görev ve workflow değiştirilmedi.
- **Başlangıç SHA:** `59b3fcf94f6d5a02c840a1198a05c73c89fa99d8` (sağlayıcıdan doğrulandı). Paralel SOHBET-H raporu nedeniyle dal `f0319d15df1bd7d47bb8d736ae6a616afce841ee` SHA'sına ilerledi; compare yalnız SESSION_HANDOFF.md +36 satır gösterdi, SOHBET-J bölümü yoktu. CAS ön okuma yenilendi.
- **Referans:** AGENTS.md, README.md, SESSION_HANDOFF.md SOHBET-G, [CI #41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897) job listesi ve ilgili Lua kaynakları GitHub'dan okundu. `assets/agent-report.md` bu deney dalında **404**; mevcut EşRota raporunun bulgu/kanıt/öneri/test/engel düzeni kullanıldı.
- **CI kabul sınırı:** `gate=success`, `test=failure`, authored R2 precompile/safety halo adımı `failure`; sonraki Stage5/Stage6/hud smoke adımları `skipped`. SOHBET-G'nin son `TAMU_WALK_COVERAGE frames=480 max_missing=1`, `frame=7 missing=[-1:-3] worker_ready=1` gözlemi P0'ın hâlâ açık olduğunu gösterir.

### Yeni bulgular ve en fazla üç optimizasyon adayı

| Öncelik / aday | Kanıt (mevcut HEAD kaynakları) | Yeni deney önerisi / ölçülebilir kabul kapısı | Risk / durum |
|---|---|---|---|
| **P2 Terrain `getVertex` batch rebuild** | [`game/love/world/terrain25d_runtime.lua#L740-L768`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/world/terrain25d_runtime.lua#L740-L768): `aggregate_pass` her vertex için `mesh:getVertex(i)` ve `{...}` Lua tablosu oluşturuyor; 1024 vertex başına yield; >96000 vertex merge dışı. | Worker/mesh üretiminden gelen CPU vertex dizilerini düzen ve UV/renk paritesini koruyarak tekrar kullanıp GPU mesh readback ve tablo tahsisini azaltmayı *deney* olarak karşılaştır. Merge CPU p95/p99, tahsis KiB, geçici peak RAM, drawcall, görsel diff kaydı zorunlu. | CPU vertex kopyası tepe bellek maliyeti yaratabilir; 96000 güvenlik sınırını ölçümsüz kaldırma. Uygulanmadı. |
| **P2 Rigby selective mesh upload, harvest çizimi** | [`player/rigby_visual.lua#L49-L62`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/player/rigby_visual.lua#L49-L62): her `prepare` aktif mesh'ler için `setVertices`. [`#L113-L153`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/player/rigby_visual.lua#L113-L153): mobil 30Hz pose sampling zaten mevcut, tool/forced frame sırasında bypass. [`rigby_runtime.lua#L291-L315`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/player/rigby_runtime.lua#L291-L315) CPU vertex konumlandırma. | `idle/walk/chop/mine` için skinning ms, GPU vertex upload sayısı, drawcall ve tahsisi ayrı ölç; değişmeyen attachment mesh'lerini dirty/fingerprint kontrolüyle atlamayı değerlendir. Hasat tool/socket görsel eşdeğerliği ve 4 yön regresyonu zorunlu. | 30Hz throttling tekrar keşif değildir, var olan uygulamadır. Hasatta kare atlama/attachment sapması riski; uygulanmadı. |
| **P3 Collision allocation ve atlas startup/fallback ayrıştırma** | [`physics/collision.lua#L21-L55`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/physics/collision.lua#L21-L55): `can_stand` ve `move` boyunca en çok üç sweep turunda tekrar `W.obstacles` sorgusu. [`world/terrain25d_runtime.lua#L170-L212`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/world/terrain25d_runtime.lua#L170-L212): atlas worker yanıtı yoksa 3sn timeout sonrası ana thread `Atlas.load(meta)` fallback; [`world/terrain25d_atlas.lua#L11-L32`](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/blob/59b3fcf94f6d5a02c840a1198a05c73c89fa99d8/game/love/world/terrain25d_atlas.lua#L11-L32) ImageData ve kaynak yükü. | İki bağımsız maliyet sayacı: collision obstacle dizi alloc/call/p95 ve başlangıç timeout, main-thread fallback süresi, siyah ekran süresi. Kanıt varsa yeniden kullanılan sorgu tamponu veya frame-budget fallback'i değerlendirme; davranış/atlas hash/UV paritesi test edilmeli. | Tahsisin gerçek Android etkisi bilinmiyor; fallback'i silmek sonsuz siyah ekran üretebilir. Ölçüm adayı, uygulanmadı. |

### Korunanlar, doğrulama ve açık işler

SOHBET-G'nin uygulanmış worker ticket/FIFO, visible/halo alias, `upload_cap=1`, obje/gölge batch/cache, iki atlas sayfası, Rigby 30Hz, diagnostics ve HUD layout cache uygulamaları **yeni optimizasyon olarak sayılmadı**. Bu rapor H sohbetinin P0 GPU upload sıralama araştırmasına karışmaz.

**Tamamlanan:** Repo HEAD/AGENTS/README/G raporu/CI ve hedef kaynak satırları salt okunur incelendi; üç yeni aday sunuldu. **Açık:** `max_missing=0`, Android JSONL ve gerçek FPS; adayların ölçümü ve kaynak/ekran parite testleri. **Doğrulanmayan:** Mobil kazanım, bağımsız çalışma/Android cihaz testi, açılış fallback'in gerçekten tetiklendiği. Masaüstü CI p95'i mobil FPS kabulü değildir.

**Koordinatöre teslim:** `github:TheOsmanYILDIRIM/TAMU-K-K@experiment/25d-binary-vertex-20261030:SESSION_HANDOFF.md#SOHBET-J`; `revision_guard=cas` (güncel blob SHA); `readback_method=provider_reopen`; yalnız bu bölüm. Otomatik koordinatör bildirimi yok.


### 2026-10-31 — SOHBET-J uygulama: Rigby örnekleme ve CCD sorgu tahsisi

- **Durum:** `in_progress` / `pending_unverified`. Yalnız `experiment/25d-binary-vertex-20261030`; başlangıç HEAD `e78e8364c15a3b49bebd8634199974a94d87f231`. H eşzamanlı değişikliği sonrası kod yazımından önce güncel HEAD `8a09659a4a1b6e078eb1373d84e1fe3488a5cd05` ve hedef blob tekrar okundu; H dosyalarına dokunulmadı.
- **Bulgu / düzeltme 1:** `physics/world_query.lua` her `obstacles` çağrısında geçici bounds dizisi ve ayrıca obstacle sonuç dizisi oluşturuyordu. `93e5a7204674d188e1d564a5155a245d67f730b3`: sınırlar doğrudan denetleniyor; provider'ın dense, doğrulanmış sonuç dizisi kopyalanmadan döndürülüyor. Collision move/can_stand sadece senkron okuyucu; CCD ve sıralama algoritması değiştirilmedi. **Risk:** sağlayıcının geri döndürdüğü dizinin artık aynı referans olması; çağıran tarafından mutasyona uğratılmamalı.
- **Bulgu / düzeltme 2:** `player/rigby_runtime.lua:R.sample` çok sık çağrılan kanal örnekleme için her seferinde `val` closure oluşturuyordu. `09818c150813c66e666b89c12f95aff05ae4e12e`: ortak `sample_value` helper'ı; interpolate/ease/formül aynı. **Rigby 30Hz, 4 yön, 44 klip, procedural bone, tool socket ve hasat zamanlaması değiştirilmedi.**
- **Regresyon kaydı:** `9b0cf9e0d0014eba8c6bcc2b7e05ed31bfbdaf77`: mevcut `game/love/tests/integration.lua` içine obstacle sonuç referansı, NaN bounds ve dense-array reddi assertions eklendi. Yeni test dosyası/workflow oluşturulmadı.
- **Provider readback SHA:** `physics/world_query.lua` blob `440a8e7ca966ccc255a2215fd122f8f62cf12a82`; `tests/integration.lua` blob `7857453dcbff7127f1afc3a26dbdba845f97e27e`; `player/rigby_runtime.lua` blob `e825bb804657b87ab21538324847db88052bbe44`. Üçü commit sonrası sağlayıcıdan yeniden açılıp istenen içerikle eşleşti.
- **Test/CI/artefakt:** Geçmiş CI [#41194049897](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41194049897) bu commitleri kapsamaz ve `failure/max_missing=1`. Bu turda `lua5.4 tests/integration.lua`, `tests/rigby_runtime.lua`, `tests/rigby_visual.lua` ile LuaJIT, LÖVE/Xvfb ve Android çalıştırılamadı; mevcut ortamda Lua/LÖVE yürütücüsü yok. **Test geçti, FPS arttı veya görsel parite sağlandı iddiası yok.** Gereksiz manual CI dispatch yapılmadı.
- **Kanonik Beyin:** `agy-vault/main:tasks/oyun-25d-runtime-renderer-integration-20261028.md` rev14/`active` ve vault HEAD `5c6bfef372e2272cda36e40f8a50cb0526a80389` salt okunur doğrulandı. Resmî DirectSync semantik motor/receipt uygulanmadı; **Beyin güncellemesi yapılmadı**.
- **Engeller / açık işler:** hedefli Lua/LuaJIT testleri ve Rigby 4 yön/skin/vertex/upload/hasat görünüm paritesi çalıştırılmalı. Mesh dirty-selective upload bu tur uygulanmadı: mevcut 30Hz ve zorunlu hasat bypass nedeniyle kazanç/regresyon ölçümü olmadan riskli. Collision no-copy entegrasyonunun provider arayüzünde mutasyon/alias regresyonu ayrıca test edilmeli. FPS, CCD determinism ve cihaz kabulü açık. H'nin terrain P0 alanı üstlenilmedi.
- **Sonraki hedef:** mevcut `game/love` testleri ve gerçek LÖVE/Xvfb sonrası yalnız ölçülen skin/upload hot-spot'a müdahale; Android JSONL ile frametime p95/p99 ayrıca ölçülsün. Otomatik koordinatör iletişimi yok.
- **Rapor hedefi:** `SESSION_HANDOFF.md#SOHBET-J` / `report_only`, `revision_guard=cas`, `readback_method=provider_reopen`.

### 2026-10-31 — SOHBET-J CI #41206688479 sonuç doğrulaması

- **Durum:** `review_requested` — Rigby hedefli testleri geçti, collision entegrasyonu yürütülmedi, genel CI P0 terrain nedeniyle başarısız. Run: https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41206688479 ; test edilen HEAD `e00f63480a94a94992a4924be9447cf8c51909ce`.
- **Kanıt:** GitHub job `gate=success`, `test=failure`. `Fail fast on Lua and packaging syntax in streaming experiment=success`. Lua 5.4 ve LuaJIT `tests/rigby_runtime.lua` iki kez `RIGBY_REFERENCE_OK samples=264 bone_matrices=10560 vertex_checks=224928 max_abs_error=3.7252903e-09`. İki `tests/rigby_visual.lua` çıktısı `RIGBY_VISUAL_MOCK_OK` (textures=24, mesh_updates=94/74, draws=160/128). Rigby Lua/LuaJIT derleme/sözdizimi adımları başarılı.
- **Genel hata H'ye ait:** `Precompile complete authored R2 polygon area with safety halo` başarısız; `TAMU_WALK_COVERAGE frames=480 max_missing=2 distance=1101.392`; `TAMU_WALK_GAP` frame 5 missing=2, frame 6 missing=1. H terrain P0 dosyaları J kapsamı dışında; değişiklik yapılmadı.
- **Açık collision kabulü:** `tests/integration.lua` içindeki yeni no-copy, NaN ve dense-array assertions, CI yürüyüşü erken sonlandığından bağımsız yürütme kanıtına sahip değil. `WORLD_PLAYER_INTEGRATION_OK` veya `WORLD_PLAYER_EDGE_OK` çıktısı bu koşuda yok. Collision CCD determinism PASS iddiası yapılmadı.
- **Kapsam/sıradaki iş:** Yeni J kod değişikliği yapılmadı; mevcut J commitleri `93e5a720`, `9b0cf9e0`, `09818c15` korunuyor. Mevcut runner ile ayrı `lua5.4 tests/integration.lua` ve `luajit tests/integration.lua` çalıştırılmalı; 4 yön, socket, harvest ve gerçek LÖVE görsel eşdeğerliği ayrıca açık. Android FPS ölçülmedi. Ek workflow/dispatch açılmadı, main'e dokunulmadı.
- **İşlem:** `report_only` / `revision_guard=cas` / `provider_reopen`; diğer ajan bölümleri değiştirilmedi. Avenox Beyin görevine bu raporla senkron yazılmadı.


## [SOHBET-3D | 45° iki profil render deneyi — güncel taban] — 2026-10-31

- **Dal:** `experiment/25d-two-view-3d-20261031`, taban `5d9dba547db4a553daaf0c114c7d30b1b1297be6` (`experiment/25d-binary-vertex-20261030`). Main ve performans dalına yazılmadı.
- **Kaynak:** depo kökündeki Quaternius Adventurer GLB; önceki izole `experiment/25d-profile-baked-3d-20261031` prototipinden render-only dosyalar mevcut en güncel tabana taşındı.
- **Uygulama:** Blender 45° ortografik iki görüntü (`front`/`back`), 8 kare idle/walk sprite atlası, SE/SW ve NE/NW aynalama, ayak merkezi pivotu; `TAMU_BAKED_3D_AVATAR=1` opt-in. Rigby varsayılan, fizik/kamera/kayıt/Stage6 değişmez.
- **Kabul engeli:** Bu oturumun konteynerinde Blender ve LÖVE yok. PNG atlas ve manifest henüz üretilmedi; script ve Lua kodu görsel/Android/oynanış olarak doğrulanmış değildir. Opt-in açılırsa bu dosyalar yokken açık hata verir. Mobil FPS ve 3B animasyonlar doğrulanmadı.
- **Sonraki adım:** Blender ile `blender -b -t 2 --python scripts/bake_3d_profile_character.py -- --repo .` çalıştır; `game/love/assets/character_side_bake/{atlas.png,manifest.json}` çıktılarını boyut/SHA/alpha/görsel, ardından gerçek LÖVE ve Android yön/hasat/su/Y-depth testleriyle doğrula. Beyin task/receipt bu commitin parçası değildir; resmî DirectSync olmadan tamamlandı kaydı yapma.

### 2026-10-31 — Blender Actions gerçek üretim kabulü

- **Başarılı otomasyon:** [Actions #41233070234](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41233070234), `completed/success`. Önceki #41232834247 NumPy eksikliği, #41232927536 Ubuntu Blender OpenImageDenoiser eksikliği yüzünden başarısızdı; her iki neden kod/workflow düzeltmeleriyle giderildi.
- **Kullanılan çalışma:** GitHub Ubuntu 24.04, Blender 4.0.2 ve `python3-numpy`; kaynak model glTF import, 45° ön/arka iki kamera, idle/walk 8'er kare, toplam 32 PNG render ve tek RGBA sprite atlası.
- **Gerçek üretim ve kalıcılık:** `game/love/assets/character_side_bake/atlas.png` 150307 byte, 1024×768 RGBA, SHA256 `20f07c4c92313547eb12e7c61bf928cf3adf2f6d61dc4f74566726508f7726b3`; manifest kaynak model SHA256 `4a8639cd8eee9d8a150464edc25eb0536ced464790704a64e40c8620d99f66db`, 45° ve bottom-center pivot kaydı. Otomatik GitHub bot commit [28b03270](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/commit/28b03270b9481adc56591ee2eed8f00967959fef) yalnız izinli deney dalında; atlas `1721e1ac205ecd756529d62f33236cae7d270bd6` ve manifest `72e34567f2485b92a542a0907f616179d807ac55` blob SHA ile GitHub'da geri okundu.
- **CI kapıları:** Kaynak/atlas SHA256 karşılaştırması, 4 satır / 8 kare ve walk frame çeşitliliği, RGBA/alpha border, Blender→PNG sıra dönüşümü, Lua5.4/LuaJIT yön+ayna testleri `TAMU_SIDE_BAKED_4DIR_MIRROR_OK`, `TAMU_3D_ATLAS_VALIDATED` geçmiştir. Actions artifact ID `13054192140` (provider digest `sha256:ad7422d4b66a726a685a6235dc543f262e117ddd74a5a837a04b12002b58ecb7`).
- **AÇIK / kabul sınırı:** LÖVE 11.x gerçek oyun ekranı, Blender sprite görüntüsünün insan gözüyle inspeksiyonu, hasat/tool, su-immersion, y-depth ve Android gerçek FPS/cihaz doğrulaması henüz yok. `TAMU_BAKED_3D_AVATAR=1` opt-in; normal Rigby varsayılan. `main` değişmedi. Beyin görevi ve receipt resmî DirectSync üzerinden güncellenmedi.

### 2026-10-31 — Tam oyun 3B karakter özel .love (CI doğrulaması bekliyor)
- Mevcut `scripts/package_tamu_love.py` taban alınarak `scripts/package_tamu_3d_test_love.py` ile yalnız **dağıtım ZIP'inde** Rigby yerine `player.side_baked_visual` seçilir ve açılış izolasyon ekranı atlanır. Depo oyun kaynakları, kayıtlar ve varsayılan Rigby korunur.
- Mevcut Blender workflow'unda tam oyun `.love`, `TAMU_BAKED_DEMO_SMOKE=1` LÖVE/Xvfb gerçek render testi, ekran görüntüsü ve indirilebilir artifact eklenir. Sonuç CI # ile ayrıca geri okunacak; Android cihaz, oynanış, FPS kanıtı değildir.

### 2026-10-31 — 3B özel tam-oyun .love gerçek Actions teslimi

- **CI:** [Actions #41235119369](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41235119369) `completed/success`, tüm Blender, kaynak SHA, Lua yön/ayna, özel tam-oyun .love üretimi, LÖVE/Xvfb gerçek boot/18 draw, PNG screenshot ve artifact adımları başarılı.
- **Artifact:** `tamu-special-3d-avatar-love` ID `13054809659`, provider ZIP digest `sha256:aa6687c447fd5096c079977241bf99b3bd940711021a70fe033986f1eacef142`. Bağımsız indirilen ZIP `testzip() is None`, içindeki `TAMU-3D-Avatar-TEST.love` **11,574,094 bytes**, SHA256 `bbae84c3b587dbe855ed0e6b027cda0b4cf4aa0ce9b94a278b31221be223b0c5`, `testzip() is None`, **243 dosya**. İçeride gerçek baked atlas SHA ve iki yönlü görsel zorlaması doğrulandı; kaynak karakter ve normal Rigby değişmedi.
- **Görsel inceleme:** Gerçek LÖVE/Xvfb screenshot'ta karakter ve portrait HUD görünüyor, test paketindeki yükseltilmiş karakter ölçeği uygulanmış. İlk 8. kare ekranında dünya terrain akışı henüz tamamlanmamış (HUD `Eksik 14/18`); *tam dünya görsel/parite ve performans kabulü değildir*. Android yürüyüş/Y-depth, su, hasat, FPS, açılışta terrain ilerleme ve GLB kostüm kalitesi cihaz üzerinde ayrıca test edilmeli.
- **Kaynak:** `scripts/package_tamu_3d_test_love.py`, yalnız test ZIP'inde `main.lua` isolation preamble ve `objects/renderer.lua` avatar seçimi değiştirir. Gerçek kaynak `game/love/main.lua`, `objects/renderer.lua`, Stage6/save ve `main` değiştirilmedi.
- **Sınır:** Avenox Beyin'e resmî DirectSync task/receipt yazımı yapılmadı; bu GitHub handoff kanıtı kanonik Beyin semantik güncellemesi değildir.

### 2026-10-31 — Düz yan profil dönüşümü
- Kullanıcının düz profil talebine göre Blender kamera elevation=0°, sprite 2 satır side_idle/side_walk; 45° açı **yalnız oyun dünyası/kamera projeksiyonunda**. NE/SE aynı profil, NW/SW yatay aynalama. 
- Deney branch'inde mevcut dosyalara müdahale; ana dal, oyun fiziği, kayıt değişmez. Actions CI, gerçek paket ve Android kabul durumunu ayrıca doğrula.
