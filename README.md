## 2026-11-02 — Android gri ekran: eksik GDScript export ve izole PCK açılış kapısı
Gerçek Android kullanıcı geri bildirimi: önceki harici PCK **ve** bağımsız Android APK yaklaşık 10 saniye boyunca gri ekranda kaldı. Önceki temiz PCK (16.603.328 bayt, 414 dosya) açılarak incelendi: yalnızca `scripts/main.gdc`, `scripts/content_entry.gdc`, `scripts/content_pack.gdc` derlenmiş script dosyaları bulunuyordu; `main.gd` içindeki R2/Stage6/FX/Save preloads ve `object_shadow.gdshader` seçili-kaynak export filtresinde eksikti. Bu, Android'deki sorunun **güçlü kaynaklı açıklamasıdır**, cihaz üzerinde kesin kök neden ölçümü değildir.

`export_presets.cfg` mevcut seçili varlıkları koruyarak tüm 24 zorunlu runtime `.gd/.gdshader` kaynaklarını açıkça dahil eder; CI yeni PCK'de 17 kritik script + shader'ı zorunlu tutar. Güncel export PCK **16.710.612 bayt / 461 dosya / 26 GDScript**, APK **36.298.566 bayt**. GitHub Actions [#41411687555](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41411687555) iki job `completed/success`: 7/7 dünya görsel paritesi, Stage6 ve FX, temiz PCK içeriği, kaynak dosyası bulunmayan boş dizinden `--main-pack` ile gerçek boot `TAMU_EXPORTED_PACK_BOOT_OK`, Android debug APK üretimi ve ZIP CRC kontrolü. Test edilen kod `9f37297a4135324f3d00c42b0f58cfb16a482888`. APK SHA256 `887aa8aa475b599f4ebb0f593e261a0ada3bc314e5b1b9a9b9ac393dcf7f6b5b`; PCK SHA256 `f1d3002bf0c0a6bf8c3c8b83c6d522e89f4200f8c0b59d7d4f5eeae91b5f7862`.

**Önemli sınır:** Bu çalışma test ortamında paket açılışını kanıtlar; kullanıcının gerçek Android telefonunda yeni APK/PCK açılışını ve FPS'i henüz kanıtlamaz. Gri ekran yeni APK'de sürerse kullanıcıdan Android logcat Godot/AndroidRuntime satırları istenerek grafik backend/asset boot ayrımı yapılmalı. `main`, LÖVE dalı, karakter ve HUD değişmedi.

## 2026-11-02 — Plasma temizliği ve ayrık PCK kabulü
- **Başarılı yeni CI:** [#41406279841](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41406279841) `completed/success`, tested code commit `a256a21334828ba7b79089e726439499a8f19950`. Godot 4.6 temiz external Loader PCK **16.603.328 bayt / 414 dosya / 15,83 MiB**; SHA256 `123485b71d19be2d8c427d68de0c391142e6f5b9b82aa5198bcf9e21905cc580`. PCK dizin kaydı gerçek Python yapısal çözümlemesiyle geri okundu; `plasma=0`, `screenshots=0`, `apk=0`, gerekli authored `chunks`, `data/catalog`, `data/worldbuild`, Rigby ve atlas kaynakları mevcut. Eski 70.776.864-bayt PCK ile karşılaştırmada %76,5 küçülme.
- **Kaynak temizliği:** Yetkili deney dalından Plasma adlı 21 dosya çıkarıldı (tarihsel commit ve ayrı LÖVE dalı korunur); Godot export preset `all_resources` yerine `resources` allowlist kullanır. CI tekrar Plasma, screenshot, LÖVE art-source veya 40 MiB üstü PCK çıkarmayı reddeder.
- **Üç ayrı artefakt:** `tamu-godot-loader-pck` (ID `13122993551`), `tamu-godot-debug-apk` (ID `13123088305`) ve `tamu-godot-test-results` (ID `13123382394`); FX görsel testi ayrıca `tamu-fx-visual-smoke` (ID `13123028203`). Test görselleri PCK/APK artefaktlarına dahil değildir. 7/7 dünya görsel ve önceki oyun/Stage6 regresyonları PASS; fiziksel Android Loader `--main-pack` başlatma ve gerçek cihaz FPS hâlâ doğrulanmadı.

## 2026-11-02 — Android Loader dağıtım artefaktlarını ayırma
- Oyun PCK'si `tamu-godot-loader-pck` artefaktında **yalnız PCK** olarak yayımlanır. `tamu-godot-debug-apk` yalnız APK'dir. `tamu-godot-test-results` yalnız CI ekran görüntüleri, doğrulama logları ve testte kullanılan source indexini içerir; PCK/APK içine test sonuçları konmaz.
- `export_presets.cfg` mevcut selected-resources değişikliği ve CI'daki `TAMU_CLEAN_PCK_OK` dosya/boyut kontrolü korunur. PCK bağımsız test çıktısı ve APK taşımaz. Godot Loader harici PCK'yi değiştirmeden çalıştırır; gerçek Android cihaz kabulü ayrıdır.

## 2026-11-02 — Godot Loader PCK temizleme kararı
- Godot deney dalında Plasma varlıkları, kaynak üreticileri, ilgili eski belgeler ve Plasma test dosyaları **kaldırıldı**. LÖVE ana dalı, tarihsel commitler, kullanıcı verileri ve yedekler değişmez.
- Godot `export_presets.cfg`: `all_resources` yerine yalnız seçili sahne, gerçek terrain atlası, aktif Rigby parçaları ve derlenmiş katalog; ayrıca gerekli binary chunk, authored R2 ve JSON tanımları. Ekran görüntüsü, eski LÖVE varlıkları ve art-source dosyaları PCK dışında.
- CI PCK dosya tablosunu okuyup Plasma/screenshot/legacy kaynaklarını ve 40 MiB üstünü reddeder. Yeni doğrulanmış boyut, test sonucu oluştuğunda geçerlidir; bu kayıt tek başına yeni PCK kabulü değildir.

## 2026-11-02 — Godot R2 native surface/collision + test edilmiş FX/APK
- Kanonik LÖVE `field.lua` / `r2_valley_surface.lua` / `topography_surface.lua` hesapları `scripts/r2_surface.gd` üzerinde port edildi. Kaynak `data/worldbuild/fisilti_ormani.r2.v1.json` ve `osman_overworld.v2.json` kontrol edilir; Generator v1 yüksekliği, su çizgisi, vadi alçaltması, eğim hesabı gerçek matematikle örneklenir. `domain_building.gd` 4 birim aralıklı örnekleme, grade<=0.12 ve height-delta<=0.8 ile hatalı yüzeyi reddeder. `r2_collision.gd` LÖVE fizik süpürülmüş AABB/duvar boyunca kayma mantığını Godot için taşır. Depleted worldobj ID'leri R2 obstacle sorgusundan kaldırılır; karakter görselleri değiştirilmez.
- `scripts/r2_surface_ci.gd` bağımsız hızlı test: spawn yüksekliği 12.830245, nehir `water` ve build-reject, kuru alan örnekleme ve sweep-slide PASS. `scripts/r2_authority_ci.gd` aynı oturumdan re-open, 832 authored ID/parite, collected obstacle remove testlerini doğrular.
- En güncel **CI accepted SHA `a84951a6cbb7064fdc2076eb032cf5e8669e8cb0`**, [Actions #41351728924](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41351728924) `completed/success`, tam APK artefaktı `13101776333`. Gerçek `720x1100` Android portrait simüle desktop Xvfb ekranı açıldı, 7/7 legacy-vs-merged dünya görsel regresyonu geçti (zoom mean_abs_rgb 0.2766, changed_ratio 0.00732). ZIP içinde `build/TAMU_Godot_Baseline.apk` doğrulandı; APK 88,171,406 bayt, SHA256 `bcd6000b3ae56914e0383a26b3adb243a5618b863fe9908fce53702cac1e1c6a`. Bağımsız `FX` job da başarılı; görsel önizleme açıldı. Masaüstü llvmpipe FPS değeri Android ölçümü değildir.
- **Kalan açık iş:** gerçek Android telefon üzerinde APK açılışı, termal/frametime ölçümü, yetkili R2 çarpışma/topography sınır senaryoları ve tam inşa (kaynak objesi engel/terrain karmaşık bölgeler), tüm LÖVE oynanış parity/migration, lisanslı gerçek SFX ve müzik dosyalarının eklenmesi. Stage6 korunur; karakter, demo UI ve main/LÖVE dallarına dokunulmaz.

## 2026-11-01 — Yeni görsel/ses aşaması: objeye özgü gölge, VFX ve ses portları
- `scripts/object_shadow.gdshader`: objenin gerçek atlas alfa siluetini kullanan ve mevcut güneş vektörü/saatine göre eğilip uzayan dinamik gölge. Var olan küçük temas elipsi tamamen silinmedi; zemin temasını destekler, koyuluğu azaltıldı. Bu, 2D siluet izdüşümüdür; fiziksel ışın izleme, zeminin yüksekliğine göre gölge kırılması veya GPU ışık oklüzyonu iddiası değildir.
- `scripts/impact_effects.gd`: sınırlı GPU parçacıkları, kaynak toplama başlangıç/bitiş ve craft tamamlama olaylarında çalışır; eşya için gerçek konum kullanılır. Harici efekt asseti gerektirmez. Combat/projektil hasarı bu dilime dahil değildir.
- `scripts/audio_cues.gd`: `TAMU_SFX` ve `TAMU_Music` bus'ları, en fazla 8 ses kanalı ve isteğe bağlı müzik oynatıcı. Hazır ama **ses dosyası yoksa sessiz** kalır: `audio/sfx/harvest_start.ogg`, `harvest_complete.ogg`, `craft_complete.ogg`, `hit.ogg`, `footstep.ogg`; `audio/music/forest.ogg`. Bu dosyalar sağlandığında kod/sözleşme bozulmadan kullanılabilir. Gerçek eser/müzik uydurulmadı veya telifsizmiş gibi kaydedilmedi.
- Bu aşama Godot `experiment/godot4-android-apk-20261031` üzerinde, karakter/HUD görselleri ve LÖVE/main kodunu değiştirmeden ilerler. Görsel/CI smoke testleri ayrıca doğrulanmalıdır; gerçek Android FPS ve ses doğrulaması açık.

## 2026-11-01 — Godot üretim R2 kimlik ve Stage6 bağlantısı
`scripts/r2_authority.gd` derlenmiş kanonik `r2_objects.json` içindeki 832 sabit `worldobj:v1` kimliğini, gerçek world x/y/radius değerlerini, 256 birimlik kaynak hücre koordinatlarını, isometrik x izdüşümünü ve `source_integrity.json` SHA256'sını doğrular. Gerçek ağaç/kaya footprint'lerinden obstacle sorgusu oluşturulur; sahte dünya veya alternatif obje ID'si üretilmez. `scripts/world_identity.gd` kalıcı UUIDv4'ü ilk açılışta `user://saves/world_identity.txt` içinde kontrollü yaratır, sonraki açılışlarda geri okur; eski checkpoint varken kimlik eksikse yeni UUID atamaz.

`main.gd` normal merged R2 çalıştırmada `GameplaySession.enable_durable` ile Stage6'ya bağlanır, önceden depleted objeleri gizler ve TOPLA komutlarında kaynağın ID/koordinatını tekrar doğrular. Önceki kullanıcı karakteri ve demo HUD yerleşimi değişmemiştir. **Güvenlik sınırı:** Derlenmiş mesh+tasarım haritasında yetkili su/topografya yürünebilirlik maskesi yoktur. `surface()` bu yüzden bilinmeyen zemini `walkable=false` olarak reddeder; üretim build placement tamamlanmış sayılmaz. Fiziksel Android ve gerçek fsync/güç kesintisi kabulü de yoktur.

## 2026-11-01 — Godot Stage6 kalıcı gameplay (opt-in, native domain)
`GameplaySession.enable_durable(slot, world_uuid, region_id, terrain, obstacles)` açıkça çağrıldığında kullanıcıya ait `user://saves/<slot>.checkpoint` üzerinden güvenli kalıcı mod devreye girer. Gerçek derlenmiş `chunks/merged_terrain.json` bölge kimliği ve kaynak çalıştırma ID'si, terrain manifest SHA256 ve R2 obje kaynağının SHA256'sı ile doğrulanır. World UUID farklı kayıtla eşleşirse kaydı değiştirmeden `world_region_mismatch` reddi döner. Durumdan bağımsız `worldobj:v1` kimlikleri korunur.

Kalıcı modda mevcut süreli `begin_harvest` / `begin_craft` ve `tick` akışlarının tamamlanan işlemleri önce ayrı domain kopyasında hesaplanır; checkpoint + monoton journal/command-ID kaydı başarıyla yazıldıktan sonra envanter, depletion ve craft yayınlanır. `place_building` aynı işlem kapısından geçer, otoritatif terrain/obstacle Callable'ları sağlanmadıkça güvenli reddeder. `checkpoint_credit` önceki Stage6 API'si korunur. Kayıt yazma veya kimlik uyuşmazlığı halinde yayımlama engellenir; şüpheli hata sonrası yeni işleme izin verilmeden reload gerekir. CI, bağımsız süreçlerde harvest → craft → build → reopen → replay ve eski dünya görsel kıyasını doğrular.

**Kabul sınırı:** Bu, veri kaybı riskini azaltan ve açıkça etkinleştirilen Stage6 domain API'sidir; varsayılan demo için otomatik açılmadı. Gerçek R2 yüzey/obstacle portlarının üretim sahnesine bağlanması, gerçek cihaz/fsync-güç kesintisi doğrulaması ve kapsamlı save göçü henüz açık. Karakter, demo UI, eski LÖVE kayıtları değiştirilmedi.

## 2026-11-01 — Godot Stage 6 checkpoint V1 (ayrı store API)
`scripts/stage6_checkpoint.gd` yalnız `user://saves/<slot>.checkpoint` içinde V1 format+SHA256 ile JSON-safe snapshot kaydeder; temp flush/readback, ana dosya→`.bak` ve temp→ana dosya rename kullanır. Eksik modlu/kimliği uyuşmayan snapshot kapısı herhangi bir oyun durumu yayımlanmadan reddeder. Yapısal olarak bozuk veya eksik ana dosyada doğrulanmış `.bak` okunabilir; kullanıcı onayı olmadan silinmez/taşınmaz. `GameplaySession.save_checkpoint/load_checkpoint/restore_checkpoint` erişim yöntemleri eklendi; `restore_checkpoint` doğrulanmış detached envanter/toplama/crafting/inşa durumunu yeni native domain nesnelerinde hazırlar ve ancak tüm kontroller başarılıysa yayımlar. `checkpoint_credit` yalnız açık çağrıyla 1 kalıcı envanter kredisi, monoton `journal_sequence` ve `world_revision` ile duplicate komut koruması uygular. **Genel hasat/craft/build yollarının her işlemi henüz otomatik olarak durable transaction'a bağlı değildir**; eski journal'sız snapshot otomatik taşınmaz, reddedilir. Dosya sistemi düzeyinde güç kesintisi/fsync ve Android cihaz kabulü yok; mevcut LÖVE Stage6 kayıtlarına dokunulmaz.

## 2026-11-01 — Godot harici TOML/PNG modları (opt-in)
`TAMU_ENABLE_MODS=1` ile `user://mods/<namespace>/pack.toml` içindeki **kısıtlı veri-odaklı TOML altkümesi** açılır. Paket: `namespace = "example"`, `version = 1`, `catalog_version = 1`, `dependencies = ["core"]`. `[[definitions]]` için `id`, `kind = "item"`, `max_stack`, opsiyonel `name_key`, `icon = "gem.png"`; `[[recipes]]` için `id`, `duration_ticks`, `inputs = ["core:wood_log=1"]`, `outputs = ["example:gem=2"]`. Diziler yalnız düz tırnaklı metinleri, değerler yalnız tırnaklı düz string veya pozitif tamsayıları destekler; tam TOML uyumluluğu **yoktur**. Icon PNG 2 MiB / 1024² sınırında okunup doğrulanır; mevcut HUD'a görsel entegrasyonu yok. Güvenilmeyen `.res/.pck`, script, ZIP veya keyfî dosya yolu çalıştırılmaz. Açılışta eksik/çakışan/bozuk mod paketi **reddedilir**, modlar varsayılan kapalıdır. Modlara bağımlı save geri yükleme ve Android gerçek cihaz testleri hâlâ açık.

## 2026-11-01 — TAMU modlanabilir içerik sözleşmesi
**İçerik önce veri, ardından kod.** Eşya/tarif/kaynak/yapı/bölge ve gelecekte oynanış içerikleri genişletilebilir ve isim alanlı olacak (`core:*` korunur). Geliştirici için Godot Custom Resource / `.tres`, CI/release için derlenmiş `.res`, oyuncu modları için planlanan TOML + görseller ayrı güvenlik kapılarıdır. Harici TOML/ZIP mod yükleyici henüz tamamlanmadı; keyfî GDScript çalıştırma varsayılan olarak yasaktır. Save dosyaları eksik mod kimliklerini sessizce yeniden eşlemez. Geçişte mevcut `data/catalog/` JSON kaynakları yalnız kaynak/geri dönüş için korunur; derleme-time doğrulama ve ikili paket kıyası zorunludur.
**Geliştirme dalı sınırı:** `experiment/godot4-android-apk-20261031`; karakter/Faz 2 ertelendi, demo arayüzü değiştirilmez. Güncel kanıt ve açık işler: `SESSION_HANDOFF.md`.

## Godot dünya birimi — 1 Kasım 2026
**Her bölge bir büyük chunk.** Şimdiki Fısıltı Ormanı, kaynağındaki 156 terrain hücresi korunarak tek bölge olarak derlenir (zemin için iki yerel z katmanı). Bu, oyunun tüm gelecekteki bölgelerini tek mesh'e toplama kararı değildir. Başka bölgeler bağımsız manifest, residency ve yaşam döngüsüyle eklenecek. Mevcut `TAMU_TERRAIN_MODE=legacy` kıyas modu korunur. Android testinden önce GitHub görsel kıyasları zorunludur.

## 2026-11-01 — TAMU engine migration status
**Primary development target: Godot 4** on `experiment/godot4-android-apk-20261031`. The LÖVE reference remains `experiment/25d-binary-vertex-20261030`; old engine guidance below is preserved as source history, not current migration policy.
The current Godot APK is a **prototype**, not full gameplay or pixel parity: 156 original authored chunks, 832 stable R2 objects, 40-bone/44-clip source bridge, 30-second solar test, touch joystick, TOPLA trial, HUD/JSONL and ground shadows exist. Weighted Rigby mesh/animation equivalence, gameplay/save migration, actual Android sustained-performance parity are open. The build imports canonical world/rig assets from a pinned LÖVE CI artifact; those binaries are not regenerated here.
Project architecture, phase gates and evidence: existing `SESSION_HANDOFF.md` section `[GODOT-MIGRATION]`. No main merge without approval.

## Aktif oyuncu görünümü — 29 Ekim 2026
**Varsayılan:** Osman canlı Rigby2D kemik/mesh animasyonu (4 izometrik yön, anatomik sağ el, 44 klip). Görselde önceden render edilmiş spritesheet kullanılmaz; yalnız PNG vücut parçaları ağırlıklı mesh'lerle hareket eder. R2 + kompakt atlaslı 2.5D/3N dünya standart kalır. Plazma yedeği `TAMU_USE_PLASMA=1` ile açılır. Canlı karakter ana oyun `player` objesiyle çizilir; hareket, su, hasat, envanter ve save kodu korunur. R2 session-only ve Stage6 kayıt mekanizması ayrı.

## Güncel standart dünya — 29 Ekim 2026
Normal LÖVE2D açılışı artık **R2 Fısıltı Ormanı + kompakt atlaslı 2.5D/3N** görünümdür. Authored haritalar `game/love/assets/worldbuild/` içinden hash denetimli paketlenir; `.love` dosyası depo dışından çalışır. Önceki dünya varsayılan olmaktan çıktı ama güvenli geri dönüş ve Stage6 için korunur. `OSMAN_R2_PILOT=0 OSMAN_25D_RUNTIME=0` eski görünüme geçer. R2 henüz session-only'dir, Stage6 kayıtları yeni haritaya taşınmaz. Plazma/çekirdek sistemi main'de korunmuştur; yeni canlı rigli Osman karakteri ayrı deney dalında ve indirilebilir birleşik önizlemededir, main'e eksik varlıklarla eklenmez.

# TAMU KÖK — 45° izometrik 2D hayatta kalma / crafting oyunu

**Proje kod adı:** TAMU KÖK (`tamu-kok`). Bu ad geliştirme projesinin kimliğidir; oyunun nihai yayın adı henüz belirlenmemiştir. GitHub depo yolu `TheOsmanYILDIRIM/oyun` ve çalışma dizinleri uyumluluk için korunur.

**Güncel yön (16 Ekim 2026): LÖVE2D, 45° izometrik 2D, dikey mobil ekran ve görünür karo ızgarası bulunmayan prosedürel dünya.** Godot 4.6.3 3D yeniden başlangıç planı artık aktif oyun mimarisi değildir; ancak tarihsel iskelet ve eski kaynaklar korunmaktadır.

## Oyuncu: çekirdek + plazma (2026-10-16)

Aktif karakter yönü [çekirdek/plazma karar belgesidir](docs/14_CORE_PLASMA_PROGRESSION_DESIGN.md).
Oyuncu, insansı/taş golem değil; bilinç taşıyan **büyülü-teknolojik metal
core** ve onun kontrol ettiği **plazma** olarak çizilir. İlk LÖVE2D
geometri prototipi [docs/20_CORE_PLASMA_AVATAR_STAGE1.md](docs/20_CORE_PLASMA_AVATAR_STAGE1.md)
ve `game/love/player/core_visual.lua` içindedir. Balta/kazma hasatta
rig olmadan zaman/dönüş eğrisiyle hareket eder; hareket, Y-depth,
kaynak toplama, su %55 hız/%50 immersion korunur.

Karakter Level'dan dağıtılabilir stat puanı, Core seviyesinden altı ortak stat tavanı ve normal skill slotları
için oyun içinde oturumluk V1 prototipi etkin: game/love/progression/. Mobilde STATS, klavyede P.
Başarılı normal Stage5 toplama/üretim/inşa karakter XP'si kazandırır. Prototip dengesi kesin değildir.
ÖNEMLİ: Stat ilerlemesi henüz save_v2'de kalıcı değildir ve Stage6 explicit modunda XP bağlantısı devre dışıdır.
Nihai stat adları/paleti, Tech Level, Magic Level ve özel Core yeteneklerinin mevcut aura yalnız geçici
nötr görünüm + parametrik iki baskın stat demo sözleşmesidir. Eski
Mixamo/2D mesh rig ve Character Rig Studio çalışmaları silinmedi,
**aktif oyuncu yöntemi değil, ertelenmiş tarihi deneylerdir.**

## Güncel çalışan temel (Aşama 1–5)

`game/love/` içinde gerçek LÖVE2D uygulaması: 45° dönüşüm, kamera kaydırma ve imleç çevresinde yakınlaştırma, mouse/WASD, dokunma/pinch, safe-area uyumlu portrait HUD, üç mevcut biyomla test sahnesi ve bölge seçimi. Gerçek LÖVE render döngüsü sanal ekranda CI ile açılıp doğrulanmıştır.

Üç biyomlu prosedürel seed/chunk ve Marching Squares dünyası, karakter/A*/CCD, deterministik kaynak toplama, **12 slotlu envanter ve hotbar, süreli crafting ve workbench yerleştirme** gerçek oyun döngüsüne bağlandı. JSON → Lua katalog paritesi, envanter doluluğunda kayıpsız hasat reddi, komut/transaction tekrar koruması ve RAM içi atomik kredi/tüketim test edilir. Su geçilebilir: hareket çarpanı %55, görsel batma %50. **Aşama 6 sürümlü checkpoint/recovery ve Stage5 işlem köprüsü yalnız açıkça etkinleştirilen deneysel modda bağlıdır; otomatik kayıt varsayılan olarak kapalıdır.** Masaüstünde iki ayrı LÖVE sürecinde kaydet/kapat/yeniden aç smoke test edilir; fsync/atomik rename, gerçek Android cihaz, APK ve ağ otoritesi/iki oyuncu doğrulanmadı. Yerel UUIDv4 üretimi yalnız geçici tek oyuncu içindir. Texture üretimi sonraki aşamadır.

## Çalıştır

LÖVE 11.x ile repo kökünde `love game/love` çalıştır. Windows/macOS/Linux'ta `game/love/` klasörünü LÖVE ile açabilirsin.

Hareket için WASD/yön tuşları veya sol dokunmatik joystick; R kamerayı sıfırlar, E/topla düğmesi kaynak toplar. Envanter için I veya BAG, tarifler için 1/2 veya CRAFT düğmeleri; B ile işleme tezgâhı yerleştirme önizlemesi, Q ile döndürme, Enter/CONFIRM ile yerleştirme. Fare/dokunma ile hedef seçimi, iki parmakla yakınlaştırma desteklenir. Mobil safe-area ve 320×700 / 360×780 / 720×1100 smoke görünümleri CI'da doğrulanır.

```sh
cd game/love
lua5.4 tests/run.lua
lua5.4 tests/runtime.lua
```

GitHub Actions'taki `LOVE Stage 5 inventory crafting building` workflow'u Lua 5.4/LuaJIT, JSON şema/katalog, geçmiş Aşama 1–4 regresyonları ve Xvfb üzerinde üretim oyununun gerçek LÖVE dokunmatik envanter→craft→yerleştirme PNG smoke testlerini çalıştırır. `quality` ve önceki dünya/oyuncu/stüdyo workflow'ları ayrıca korunur. Bu testler gerçek Android telefon doğrulaması değildir.

## Proje haritası

- [Uygulama yol haritası](docs/10_2D_GAME_IMPLEMENTATION_ROADMAP.md) — Aşama 1–9 hedefleri.
- [Yeni runtime mimarisi](docs/13_LOVE_2D_RUNTIME_STAGE1.md) — güncel 2D motor durumu ve kabul sınırları.
- [LÖVE runtime yönergeleri](game/love/README.md).
- [Stage5 envanter/crafting/inşa ve Stage6 kayıt sözleşmesi](docs/18_LOVE_STAGE5_AND_SAVE_V2.md).
- `object-studio/` — görsel araçlar, mevcut davranışı ve kullanıcı verilerini koru.
- `data/catalog/`, `schemas/`, `tests/` — tanımlar ve doğrulayıcılar; motor adaptörleri sonraki aşama.
- `project.godot`, `scenes/`, `scripts/main.gd` ve eski 3D tasarım belgeleri — **tarihsel Godot iskeleti**, silinmedi.
- [Önceki yedek dalı](https://github.com/TheOsmanYILDIRIM/oyun/tree/backup/pre-portrait-reboot-20261011) — korunur.

## Koruma

`main` üzerindeki stüdyo ve veri dosyalarını, yedekleri, kayıtları, PNG'leri ve IndexedDB kullanıcı verilerini koru. World Builder'ın yayınlanan `world-builder/` kaynakları ve 2D tasarım notu `main` üzerinde korunur; Pages artık ayrı deney dalından checkout yapmaz (doğrulama: Actions #39125381260). Tamamlanmamış mobil vadi demosu ayrı Beyin görevinde açık kalır; eski deney kodları topluca `main`e taşınmaz. Varlıklar lisans/kaynak/hash doğrulaması sonrasında entegre edilir.

## 🎨 Obje texture sürüm arşivi (Google Drive)

GPT Image kaynakları, Python ile işlenmiş adaylar ve izometrik kontrol görsellerinin **tüm sürümleri** Drive'daki [Texture_Archive](https://drive.google.com/drive/folders/1n3nkFdX3rPluAHU5aS95Ci5nYBp8_CHe) altında obje kimliğine göre saklanır. [Üretim/kalite yönergesi](TEXTURE_PRODUCTION_GUIDE.md) ve [Python hazırlama aracı](scripts/texture_prepare.py). Zemin texture'ları tamamlanmıştır; yeni üretim kapsamı mevcut ağaç ve kaya objeleridir. Drive saklama işlemi otomatik senkronize değildir; her onaylı kaynak/aday yüklenip dosya kimliği ve SHA-256 manifestte doğrulanmalıdır. Drive klasörü oyun runtime bağımlılığı değildir.

---

## TAMU bina PNG üretimi — iki referans, 3×3 teknik izometrik standart (2026-11-06)

> **Durum:** Görsel üretimi için belgelenmiş tasarım/deney standardı. İki referanslı 3×3 bina yaklaşımı kullanıcı tarafından beğenildi; bütün PNG üretimlerinin matematiksel doğruluğu, gerçek Android görüntüsü, nihai collision/interior entegrasyonu **henüz doğrulanmış değildir**. Bu bölüm kaynak oyunun canlı davranışını değiştirmez.

### 1. Neden bu üretim yöntemine geçildi?

Önceki TAMU inşaat prototipi, temel/duvar/kapı/pencere/çatı parçalarını ayrı sprite'larla birleştiriyordu; 19 parça tanımı ve 4 rotasyonda 76 görsel üretiliyordu. Bu, görsel birleşim, ölçek, üst üste çizilme ve mobil yerleştirme sorunları yarattı. Yeni **hedef mimari** dış dünyada tek izometrik PNG ile temsil edilen, metadata üzerinden footprint/kapı/çarpışma/interior bilgisi taşıyan, seviye bazlı binalardır. Çit gibi serbest objeler daha sonra bağımsız olabilir. **Henüz uygulanmış yeni oyun mekaniği değildir.**

İlk üretimlerde yalnızca TAMU harita görseli referans alınarak bir ahşap kulübe istendi. Evde bazı dış duvar/çatı kenarları doğru izometrik yöne yaklaşırken kapılı ön cephe ve kimi çatı çizgileri farklı perspektife kaydı. Bunun nedeni promptun fotoğrafik üç çeyrek perspektifi tamamen dışlayamaması ve harita görselinin *stil* sağlamasına karşın kesin geometri şablonu sunmamasıydı. HTML'deki grid sorunun kök nedeni değildi; hatalı geometri PNG'nin içinde oluşturulmuştu.

### 2. Her üretimde iki ayrı görsel referans

**Ref A — TAMU harita/stil referansı:** Kullanıcının sohbette verdiği `harita_Ref.png` (ve aynı dünya stilini gösteren oyun görüntüleri). Referansın görevi yalnızca atmosfer/renk paleti, 2.5D dünya hissi, yumuşak ışık, materyal yoğunluğu, dokusal ayrıntı ve genel nesne stilini belirlemektir. Kaynak görsel kullanıcı girdisidir; bu rehber dosyanın GitHub'a yüklendiğini ileri sürmez. Harita ekranındaki UI, zemin veya başka objeler bina PNG'sine taşınmaz.

**Ref B — 3×3 teknik izometrik referans:** Sohbette **SVG kodu** verilerek oluşturulması tarif edilen teknik `isometric_ref_3x3.svg` şablonu. Bu referansın işlevi estetik değil, **kamera eksenleri**, paralel çizgiler, çatının iki kenarı ve taban footprint'inin değişmez yönünü kilitlemektir. SVG'nin kendisi bu commit'e eklenmemiştir. Önceki sohbette yazılan örnek SVG kodunun bütün iç grid çizgilerinin koordinatları bir testle onaylanmadığından, üretimde kanonik ölçüt olarak aşağıdaki matematiksel projeksiyon kullanılmalıdır.

**Referans önceliği:** Ref B geometri için kesin kaynak; Ref A görsel stil için kesin kaynak. İkisi birlikte model girdisi olmalı. Ref A tek başına perspektif/footprint kısıtı olarak değerlendirilmemeli.

### 3. Matematiksel koordinat ve ölçek sözleşmesi

TAMU kodundaki `scripts/world_projection.gd` ile uyumlu dünya → ekran izdüşümü:

```text
screen_x = 0.70710678118 * (world_x - world_y)
screen_y = 0.35355339059 * (world_x + world_y)
screen_z = -world_height_screen_offset  # düşey doğrultu: x değişmez
```

Dolayısıyla **+X dünya ekseni** sağa 2, aşağı 1 oranıyla; **+Y dünya ekseni** sola 2, aşağı 1 oranıyla ilerler. Ekrandaki zemin izdüşümü her iki yatay eksende mutlak **0.5 eğim** taşır. Fotoğrafik perspektif yakınsaması, vanishing point, lens distorsiyonu, serbest kamera rotasyonu **yasaktır**. Düşey bina köşeleri her zaman dikey; mahya/saçak/pencere üstleri/kapı yatay çizgileri, ait oldukları dünya yatay eksenine paralel olmalıdır.

Bir dünya hücresi = **32 world unit**. Başlangıç kulübesinin footprint'i **3×3 hücre = 96×96 world unit**. Matematiksel gridin dört dünya köşesi `(0,0), (96,0), (96,96), (0,96)` olarak tanımlanır; bu noktalar yukarıdaki formülle projekte edilerek tam simetrik bir eşkenar dörtgen verir. Görselin RGBA tuvalinin **1024×1024 olması asla tek başına 3×3 ölçeği garanti etmez**: sprite taban teması, kapı, pivot ve görsel-to-world ölçek metadata ile kalibre edilmeli. Dünya verilerindeki footprint ile yalnızca PNG şeffaf boşluğu aynı kavram değildir.

İnsan ölçeği testi: oyunun referans karakter görünür yüksekliği yaklaşık **72 oyun-ekran pikselidir** (ilgili canlı görüntü ve kamera zoom'una bağlı); kapı kullanılabilir yükseklikte, duvar ve çatı karakterden büyük/gerçekçi görünmelidir. **İnsanın yarısı kadar görünen ev reddedilir.** Ağaç boyu tek başına güvenilir ölçek kıstası değildir. 1024 kaynak PNG, oyun içinde gerektiğinde uygun filtreyle küçültülecek *kaynak görseldir*; geometrik projeksiyonu veya footprint'i değiştirmek için keyfî sprite esnetmesi yapılmaz.

### 4. Ref B teknik şablonunu kodla yeniden üretme

Aşağıdaki Python 3 kodu üçüncü taraf paket kullanmadan, **kontrol edilebilir 3×3 SVG** üretir. Kodda `tile=32`, eksen ölçeği `s=2.5`: projeksiyon katsayıları, dünyadaki 32 birimlik hücreye görselde 80 piksel genişlik ve 40 piksel yükseklik düşecek şekilde ortak çarpanla büyütülür. Bu, perspektif değişikliği değil, tekdüze ekran çözünürlüğü ölçeklemesidir. Çıktı `isometric_ref_3x3.svg` dosyasıdır.

```python
from pathlib import Path

TILE = 32
ZOOM = 2.5
CX, CY = 512, 440
def iso(ix, iy, z=0):
    wx, wy = ix * TILE, iy * TILE
    return (
        round(CX + 0.70710678118 * (wx - wy) * ZOOM),
        round(CY + 0.35355339059 * (wx + wy) * ZOOM - z * ZOOM),
    )
def pt(ix, iy):
    x, y = iso(ix, iy)
    return f"{x},{y}"
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">',
         '<rect width="1024" height="1024" fill="#f7f7f4"/>']
# Her satır tam olarak izometrik X/Y akslarına paralel çizilir.
for i in range(4):
    parts.append(f'<polyline points="{pt(i,0)} {pt(i,3)}" stroke="#777" stroke-width="2" fill="none"/>')
    parts.append(f'<polyline points="{pt(0,i)} {pt(3,i)}" stroke="#777" stroke-width="2" fill="none"/>')
corners = " ".join([pt(0,0), pt(3,0), pt(3,3), pt(0,3)])
parts.append(f'<polygon points="{corners}" stroke="#386a4a" stroke-width="5" fill="#b5d5a7" fill-opacity="0.18"/>')
x0, y0 = iso(0,0)
parts.append(f'<line x1="{x0}" y1="{y0}" x2="{x0}" y2="{y0-230}" stroke="#4f9d63" stroke-width="4"/>')
parts.append('</svg>')
Path("isometric_ref_3x3.svg").write_text("\n".join(parts), encoding="utf-8")
```

Bu koda göre Ref B, **temel/cephe yönlerinin sabit geometrik rehberi** olarak modele eklenir; oyun sprite'ının içine çizilmez. Teknik doğrulamada gridin iç çizgileri yeniden projeksiyon formülüyle karşılaştırılır.

### 5. Ana üretim promptu (İngilizce, model girdisi)

Aşağıdaki **ORTAK PROMPT** her bina çeşidinde aynıdır. Ardından 6. bölümden **tek** yapı türü tanımı eklenir. Bütün çeşitlemelerde iki referansı da yeniden yüklemek gerekir:

```text
Using two provided references, create EXACTLY ONE standalone TAMU exterior isometric game building sprite.

REFERENCE A: TAMU MAP STYLE. Match the natural forest-survival world,
earthy material palette, texture density, lighting softness, and edge treatment.
REFERENCE B: CODE-GENERATED 3x3 ISOMETRIC GRID. Treat this as the strict,
higher-priority geometric contract for all axes, facade edges and footprint.
Do not copy any part of either reference into the resulting image.

CAMERA: Fixed orthographic 2.5D isometric projection. Ground-plane world
X maps to screen (right 2, down 1); world Y maps to (left 2, down 1).
Both projected horizontal world axes have slopes +0.5 and -0.5.
All vertical edges remain perfectly vertical. NO vanishing points,
NO lens perspective, NO converging lines, NO front-facade skew.
Foundation, front/side walls, roof ridge, roof eaves, window frames
and door structure must use exactly the SAME shared axes.
Show the roof and the TWO exterior walls visible from Reference B.

WORLD SCALE: Exactly 3x3 placement footprint, one cell = 32 TAMU world units,
base = 96x96 world units. Entire ground-contact perimeter follows Reference B.
The building is realistically habitable relative to a standing game character.
Its front-facing entrance must be a plausible human-sized door.
No miniature toy proportions, no floating base.

MATERIAL AND ARCHITECTURE: [INSERT ONE OF SIX SUBJECT VARIANTS BELOW]

OUTPUT: ONE full building sprite only, transparent RGBA PNG, 1024x1024
source resolution, no background, terrain, grass, shadows baked into a
ground plane, trees, rocks, props, fences, people, UI, text or labels.
Keep the entire roof and foundation visible. No cropping. Keep camera
and footprint identical for every building of this series.

FINAL SELF-CHECK: Both ground axes are exactly symmetric (slope ±0.5).
All roof and wall horizontal edges are parallel to one of those axes;
all verticals are perfectly vertical. The door sits in a correct facade.
If any original visual styling conflicts with strict geometry,
correct the geometry instead of preserving the distortion.
```

### 6. Altı farklı bina türü: ortak prompt + SUBJECT VARIANT

| Model | Seviye/kullanım | Promptun `MATERIAL AND ARCHITECTURE` kısmına eklenecek metin |
|---|---|---|
| **Ahşap kulübe** | Lv1 / başlangıç evi | `Level 1 wooden survival cabin. Rough plank walls, sturdy corner timber posts, hand-built stone foundations, low weathered gable roof, one front-facing wooden entrance, two small glazed windows. Modest realistically habitable compact form; no toy proportions.` |
| **Taş ev** | Lv2 / dayanıklı konut | `Level 2 stone cottage. Uneven hand-set masonry walls, reinforced timber framing, weathered slate-and-wood pitched roof, solid front door, small windows and a modest stone chimney. Keep the entire roof within the same 3x3 footprint logic.` |
| **Avcı evi** | Lv2 / orman barınağı | `Level 2 hunter's lodge. Dark aged timber, prominent log beam joints, moss-stained shingles, modest protected doorway, small front and side windows, restrained rustic framing and sturdy stone footings. No antlers, animals or loose props.` |
| **Marangoz atölyesi** | Yapı / üretim | `Compact woodworker's workshop. Reinforced wooden walls, a wider front entrance for handling lumber, functional pitched roof, stone footings, discrete ventilation and one side window. Practical construction. No exterior equipment piles, signs or loose tools.` |
| **Depo** | Yapı / saklama | `Compact survival storehouse. Heavy horizontal timber boards, front double loading doors, steep weatherproof roof, reinforced stone plinth, small high ventilation openings. Secure simple utilitarian silhouette, still exactly 3x3, never an enormous warehouse.` |
| **Gelişmiş ev** | Lv3 / gelişmiş konut | `Level 3 upgraded survival home. Carefully fitted timber, dressed stone foundation, fine wooden siding, weathered shingle roof, sturdy framed front entrance and tasteful modest glazed windows. Better craftsmanship, not a castle, palace or oversized building.` |

Bu altı prompt **altı farklı dış mimari görsel** üretir; her birinin 3×3 footprint'i, kamera yönü ve grid aksları aynıdır. Gerçek seviye (Lv1–Lv3) yapısal yetkileri, malzeme maliyetleri, interior kapasitesi, dayanıklılık ve oyun dengesinin bu görsel taslakla tanımlandığı **iddia edilmez**.

### 7. PNG teslimi ve oyun verisi sözleşmesi

Minimum önerilen bir yapı tanımı (gelecek tasarım; şu anda aktif şema değildir):

```json
{
  "id": "tamu:house_wood_lv1",
  "level": 1,
  "exterior_png": "house_wood_lv1.png",
  "canvas_px": [1024, 1024],
  "footprint_cells": [3, 3],
  "cell_world_units": 32,
  "pivot_px": null,
  "door_world_offset": null,
  "collision_polygon_world": null,
  "interior_id": null
}
```

`null` değerler **bilinçli olarak ölçülmemiş** bağlantı alanlarıdır; üretimde bina sprite'ından taban referans noktası ölçülerek pivot kaydedilir, kapı konumu world offset'e çevrilir, çarpışma poligonu gerçek bina tabanına göre ayrı onaylanır, iç mekân bağlantısı şemaya bağlanır. Bunlar modelin PNG'sinden veya 1024×1024 tuval ölçüsünden otomatik doğru çıkarılmış gibi gösterilmez. Dış dünya görseli veri kontrollü; `core:*` ID ve save sürüm sözleşmeleri korunmalıdır.

### 8. Bina kabul testi (HTML laboratuvarı ve sonrasında Godot)

1. PNG'nin alpha kanalı şeffaf ve yalnız tek bina içeriyor; zemin/çit/UI yok.
2. Ref B SVG'nin dört köşesi 3×3 olarak tam izdüşürülüyor; evin gerçek temel kenarları bu aksta. **Kapılı ön duvar yanlış açıdaysa reddet.**
3. Mahya ve saçak çizgileri ilgili zemin kenarına paralel; pencerelerin üstleri uyumlu; düşeyler dik.
4. PNG'yi keserek/esneterek perspektif hatasını gizleme; hatalı görünümü referansla tekrar üret.
5. HTML test ortamına `terrain.png`, transparan `objects.png`, `alignment.json` ve bina PNG'sini yükle. Üç kaynak 2026-11-05 deney koşusundaki 128 px bake'den gelebilir: [GitHub Actions #42104704821](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/42104704821). İki büyük harita eş boyutlu **4888×2621**, kayıtlı **832** çevre objesi vardır.
6. Grid'i 32 world unit aç; bina footprint'ini 3×3 seç, kapıya karakter yüksekliği kıyası yap, taşı, sabitle ve başka ağacın önüne/arkasına getir.
7. Derinlik (Y-sort), taban çarpışması ve kapı tetikleyicisini **aynı dünya ayak izi** üzerinden hesapla. Tek bake `objects.png` katmanı bireysel obje z-sırasını tam olarak yeniden sağlayamaz; HTML laboratuvarındaki önde/arkada görünüm yaklaşık olabilir.
8. Final kabul ayrı kapılardır: SVG matematiksel çizgi kontrolü; görsel manuel onay; HTML kayıt/taşıma testi; Godot yerleştirme/çarpışma; export/Android gerçek cihaz. Bunlardan biri geçmeden tamamı başarılı sayılmaz.

### 9. Bu denemede ne yapıldı / henüz ne yapılmadı?

- **Yapıldı:** İlk tek-referanslı ahşap ev üretiminde yüzey/açı uyumsuzluğu görüldü; teknik 3×3 SVG referansı için kod ve iki-referanslı iyileştirilmiş prompt hazırlandı; kullanıcı teknik referans yaklaşımını beğendi; aynı esasla altı bina türü için prompt çeşitlemeleri tanımlandı.
- **Harita kaynak kanıtı:** Tek seferlik 128 px bake workflow'u, `experiment/tamu-128-layered-bake-20261105` dalında [#42104704821](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/42104704821) başarılı; terrain ve nesneler ayrı PNG olarak aynı dünya görüntü koordinatına bake edildi.
- **Yapılmadı:** Bu belge içinde PNG dosyaları depoya yüklenmedi, üretici modelin projeksiyonu matematiksel olarak otomatik doğrulanmadı; yeni bina blueprint/interior/placement sistemi ana oyuna entegre edilmedi; Android oyun içi kabul yapılmadı.
- **Korunanlar:** Orijinal terrain, kanonik dünya kimlikleri/objeler, Stage5/6 save sistemi, eski LÖVE kaynakları, `main` ve kullanıcı görselleri değiştirilmedi.

