
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
