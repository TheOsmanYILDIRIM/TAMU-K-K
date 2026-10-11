# SESSION_HANDOFF — oyun Android portrait reboot (2026-10-11)

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
