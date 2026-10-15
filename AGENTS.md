# AGENTS.md — oyun (güncel LÖVE2D 45° izometrik 2D)

## Aktif mimari — 2026-10-15
- **Aktif motor LÖVE2D / Lua**; oyun çekirdeği `game/love/` konumundadır. 45° izometrik 2D dünya; prosedürel organik zemin ve Marching Squares Aşama 2'de. Görünür tilemap estetiği hedef değil; matematiksel grid/örnekleme gerekebilir.
- `README.md`, `docs/10_2D_GAME_IMPLEMENTATION_ROADMAP.md`, `docs/13_LOVE_2D_RUNTIME_STAGE1.md` güncel durum/planın kaynaklarıdır. Eski `docs/01-09` içindeki Godot 3D/voxel, `project.godot`, `scenes/main.tscn`, `scripts/main.gd` önceki reboot tasarımıdır. 3D çalışma yönü olarak yeniden uygulanmaz.
- Stüdyo, katalog, schema ve kullanıcı verileri ayrı katmanlardır; var olan çalışan çözümleri yeniden yazma. Üç biyom (`meadow`, `forest`, `rocky`), varyantlar veri ile tanımlı; su ve patika üst özelliklerdir. Texture üretimi Aşama 9.

## Değiştirilemez korumalar
- `backup/pre-portrait-reboot-20261011`, bağımsız deney dalları, World Builder, Terrain Studio, Object Studio, PNG, kullanıcı kaydı ve IndexedDB kaybına neden olacak dönüşüm yapma. Dalı tümüyle `main` üstüne geri birleştirme. Godot iskeletini doğrulanmış geçiş dışında silme.
- Asset ithalinde lisans, sürüm, kaynak ve hash doğrula; izinsiz Mineclonia/MTS/üçüncü taraf içeriğini gömme.
- Stable definition ID / instance ID, mantık/render ayrımı ve veri şeması ilkelerini koru. Bozuk/eksik tanımı sahte kayda sessizce dönüştürme.
- Kalıcılık Aşama 6: LÖVE için `love.filesystem` ile sürümlü, atomik ve geri alınabilir yazım geliştir; eski Godot `user://` varsayımını yeni motor için kopyalama.
- İki oyuncu Aşama 8: host authoritative, idempotent işlemler, client sahte eşya/dünya üretmez. CI = Android cihaz/A PK/FPS/çok oyuncu kanıtı değildir.

## Geliştirme ve doğrulama
- Faz sırası: 1 runtime/kamera/giriş; 2 seed/biome/Marching Squares/chunk; 3 oyuncu/hareket/çarpışma; 4 kaynak; 5 envanter/crafting/inşa; 6 kayıt; 7 Android/perf; 8 multiplayer; 9 görseller.
- Lua modülleri `game/love/core`, `world` ve `tests` içinde ayrı. `lua5.4 tests/run.lua` ve `lua5.4 tests/runtime.lua` (`game/love` dizininde) çalıştır. CI `LOVE biome core validation` gerçek LÖVE sanal ekran smoke sağlar. Python katalog testleri için `quality` workflow'unu koru.
- Android portrait için 320–360dp, 392–411dp, 19.5:9/20:9, safe-area ve 1.3 font scale matrisini sonradan gerçek cihazla doğrula. Birim testlerini gerçek cihaz diye sunma.
- GitHub yazımında güncel HEAD/tree ve blob içeriklerini doğrula → `create_tree` → `create_commit(parent=HEAD)` → `update_ref(force=false, expected_sha=HEAD)` → yeni HEAD, dosya, Actions ve varsa Pages geri oku. CAS çakışmasında dur.
- Avenox Beyin görevleri `agy-vault/main` kanoniktir; yalnız resmî `beyin-io` üzerinden güncelle. Kabul ölçütleri kanıtlanmadan `done` yapma.
