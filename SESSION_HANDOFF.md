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
