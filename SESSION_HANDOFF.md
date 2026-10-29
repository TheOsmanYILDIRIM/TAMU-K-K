# TAMU KÖK — modüler inşaat kod varsayılanları (2026-10-29)

**Kaynak dal:** `TheOsmanYILDIRIM/TAMU-K-K`, `experiment/modular-building-core-20261029`; doğrulanan son içerik commit'i `f7626df03e19fdf0ba0275eae50ba9a06c3d5f59`. `main` üzerinde inşaat entegrasyonu yapılmadı; güncel HEAD çalışmaya başlarken tekrar okunur.

- 19 mevcut `building_parts.lua` tanımı, 4 dünya yönü, 76 ayrı gerçek 128×128 RGBA kod varsayılanı; görüntü başına en fazla 64 görünür RGB renk. Pillow çokgen üretimi `scripts/building_default_assets.py`; Lua katalog export `scripts/export_building_parts.lua`; opt-in LÖVE SpriteBatch adaptörü `game/love/systems/building_default_atlas.lua`.
- 1024/256 eski görsel standardı yerine 128px kanonik `building_visual_contract.lua` geçerli. Prompt denemeleri bu kod işi için pasif; onaylı MTS stil/artistik PNG yeniden üretimi yapılmadı.
- GitHub Quality run #40897874133 `success`: Lua5.4/LuaJIT ve mevcut regresyonlar; Python 4 hedefli test başarılı (76 RGBA/<=64 renk, atlas SHA ve kadraj, 4 ayrı instance ile 2×2/L yerleştirme, pencere/kapı gerçek alfa, deterministik tekrar). Artifact `tamu-default-building-76-views` GitHub Actions'ta mevcut; atlas SHA-256 `255fd799adcad43a8565b29594970a37c132a93e6dc4bdf3b4e850fdd14dcb67`.
- Görseller bilerek **minimal prosedürel placeholder**; gerçek PNG sanat onayı, oyun içi opt-in renderer bağlantısı, kapı/merdiven özel çarpışması, save_v2 migration ve Android FPS **açık**. Yeni dünya motoru/25D/R2/Stage5/6, atlas arşivleri ve kullanıcı verileri korunur.
- Sonraki çalışma: önce yeni HEAD/CI ve kanonik açık görev kontrolü; kullanıcının isteğine göre bağımsız yeni dünya adaptörüne entegrasyon veya kod varsayılanlarının görsel iterasyonu. Kabul olmadan `main` merge veya done ilanı yok.

---

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
