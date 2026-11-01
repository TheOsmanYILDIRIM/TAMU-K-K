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
