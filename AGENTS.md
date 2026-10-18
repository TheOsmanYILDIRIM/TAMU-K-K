# AGENTS.md — oyun (güncel LÖVE2D 45° izometrik 2D)

## Aktif mimari — 2026-10-15
- **Aktif motor LÖVE2D / Lua**; oyun çekirdeği `game/love/` konumundadır. 45° izometrik 2D dünya; prosedürel organik zemin ve Marching Squares Aşama 2'de. Görünür tilemap estetiği hedef değil; matematiksel grid/örnekleme gerekebilir.
- `README.md`, `docs/10_2D_GAME_IMPLEMENTATION_ROADMAP.md`, `docs/13_LOVE_2D_RUNTIME_STAGE1.md` güncel durum/planın kaynaklarıdır. Eski `docs/01-09` içindeki Godot 3D/voxel, `project.godot`, `scenes/main.tscn`, `scripts/main.gd` önceki reboot tasarımıdır. 3D çalışma yönü olarak yeniden uygulanmaz.
- Stüdyo, katalog, schema ve kullanıcı verileri ayrı katmanlardır; var olan çalışan çözümleri yeniden yazma. Üç biyom (`meadow`, `forest`, `rocky`), varyantlar veri ile tanımlı; su ve patika üst özelliklerdir. Texture üretimi Aşama 9.

## Yeni oyuncu kararı — 2026-10-16
- Kanonik oyun karakteri insan/golem/insansı rig değil, **bilinci taşıyan
  metal büyülü-teknolojik core ve kontrollü plazma**:
  `docs/14_CORE_PLASMA_PROGRESSION_DESIGN.md`.
- Aktif LÖVE görsel uygulama `game/love/player/core_visual.lua`,
  `core_aura.lua`, `docs/20_CORE_PLASMA_AVATAR_STAGE1.md`.
  Özgün karakter hareketi ve çarpışması world-space 2D motorundadır;
  tool hareketini kemik animasyonu değil konum/açı/zaman eğrisi sağlar.
- Mixamo/Character Rig Studio, 2D segmented/mesh rig ve Blender testleri
  **şimdilik rafa kaldırıldı**. Bu kaynakları/yedekleri silme, aktüel
  karakter çözümüymüş gibi oyuna taşıma.
- Stat listesi ve renk paleti, Tech Level/Magic Level eğrileri,
  core türleri/ödüller henüz kararlaştırılmadı; bunları otomatik olarak
  kalıcı katalog/save modeline uydurma. Aura %10 bucket/5 puan
  histerezis sadece görsel prototip varsayımıdır.

## Değiştirilemez korumalar
- `backup/pre-portrait-reboot-20261011`, mevcut deney dalları, World Builder, Terrain Studio, Object Studio, PNG, kullanıcı kaydı ve IndexedDB'yi koru. Bir deney dalını bütünüyle `main` üstüne körlemesine birleştirme. Godot iskeletini doğrulanmış geçiş dışında silme.
- Asset ithalinde lisans, sürüm, kaynak ve hash doğrula; izinsiz Mineclonia/MTS/üçüncü taraf içeriğini gömme.
- Stable definition ID / instance ID, mantık/render ayrımı ve veri şeması ilkelerini koru. Bozuk/eksik tanımı sahte kayda sessizce dönüştürme.
- Kalıcılık Aşama 6: LÖVE için `love.filesystem` ile sürümlü, atomik ve geri alınabilir yazım geliştir; eski Godot `user://` varsayımını yeni motor için kopyalama.
- İki oyuncu Aşama 8: host authoritative, idempotent işlemler, client sahte eşya/dünya üretmez. CI = Android cihaz/A PK/FPS/çok oyuncu kanıtı değildir.

## Geliştirme ve doğrulama
- Faz sırası: 1 runtime/kamera/giriş; 2 seed/biome/Marching Squares/chunk; 3 oyuncu/hareket/çarpışma; 4 kaynak; 5 envanter/crafting/inşa; 6 kayıt; 7 Android/perf; 8 multiplayer; 9 görseller.
- Lua modülleri `game/love/core`, `world` ve `tests` içinde ayrı. İlgili Lua 5.4/LuaJIT birim ve regresyon testlerini çalıştır; mevcut `tests/run.lua`, `tests/runtime.lua`, görsel LÖVE/Xvfb ve `quality` iş akışlarını ihtiyaç duyulduğunda yeniden kullan. Her küçük dosya değişikliğinde bütün testleri/CI'ları tekrarlama; hangi kanıtın yeterli olduğunu değişiklik kapsamı ve risk belirler.
- Android portrait için 320–360dp, 392–411dp, 19.5:9/20:9, safe-area ve 1.3 font scale matrisini sonradan gerçek cihazla doğrula. Birim testlerini gerçek cihaz diye sunma.
- **Dal seçimi:** Kullanıcı açıkça dal istemedikçe sırf test, paketleme, dokümantasyon, shader veya küçük geliştirme için yeni `experiment/*` dalı açma. İlgili mevcut dalı sürdür; düşük riskli ve bağımsız doğrulanabilir değişikliklerde güvenli `main` yazımı yapılabilir. Yeni deney dalı yalnızca çakışma ihtimali, büyük/riskli mimari değişiklik, paralel ajan müdahalesi, doğrulanmamış oyun davranışı veya kullanıcının açık dal isteği varsa gerekçesiyle açılır. Yeni dal rutin varsayılan değildir. Başka ajanların aktif çalışmalarını etkileme.
- **En fazla üç aşamalı teslim:** (1) HEAD, ilgili kayıt ve etkilenen dosyaları tek seferde doğrula; (2) kod/varlık/paketleme işlemini yap, mevcut kanıtları yeniden kullan, gerekli hedefli testleri toplu çalıştır ve çıktı/artifact'ı görsel olarak incele; (3) uygun dalda tek mantıksal commit/CAS ile yaz, HEAD/dosya/CI/artifact geri okumasını yap ve Beyin görevini güncelle. Aynı problem için art arda yeni dal/workflow/test dosyası açıp kullanıcıyı gereksiz döngüye sokma. Hata çıkarsa aynı iş içinde hedefli düzeltme ve tekrar; hangi testin neden yeniden koştuğunu açık tut.
- **Test maliyeti ve kabul:** Mevcut geçmiş başarılı testleri yeniden koşturma; değişen kapsamı doğrulamıyorsa yalnız gereken testleri ekle. Tek gerçek LÖVE/Xvfb smoke + ilgili birim/regresyon + çıktı gözlemi, düşük riskli görsel iş için yeterli olabilir. Yeni workflow yalnız mevcut CI ile doğrulanamayan tekrarlanabilir gereksinim varsa eklenir; yinelenen/geçici workflow'ları çoğaltma. Paketlemeyi mümkünse mevcut iş akışına ekle veya doğrudan doğrulanmış paket oluştur. Dosya/ZIP/artifact SHA ve içeriğini kontrol et. CI başarısı gerçek Android cihaz, FPS, APK veya shader'ın tüm cihazlarda çalıştığı kanıtı değildir; istenen platform kanıtını açık tut.
- GitHub yazımında güncel HEAD/tree ve blob içeriklerini doğrula → `create_tree` → `create_commit(parent=HEAD)` → `update_ref(force=false, expected_sha=HEAD)` → yeni HEAD, dosya, Actions ve varsa Pages geri oku. Uygun olduğu durumda eşdeğer blob-SHA korumalı dosya güncelleme de kullanılabilir. CAS çakışmasında dur.
- Avenox Beyin görevleri `agy-vault/main` kanoniktir; yalnız resmî `beyin-io` üzerinden güncelle. Kabul ölçütleri kanıtlanmadan `done` yapma.
