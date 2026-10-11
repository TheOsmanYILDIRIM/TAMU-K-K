# oyun — Android Portrait Crafting Survival (yeniden başlangıç)

**Durum: Mimari ve veri sözleşmesi iskeleti. Henüz oynanabilir oyun veya APK değildir.**

Godot 4 tabanlı, **dikey ekran öncelikli**, gerçek 3D ortamlı, döndürülebilir izometrik kamera kullanan ve 2 kişilik co-op hedefleyen kaynak toplama / crafting / inşa oyunu.

## Önceki sürüm

11 Ekim 2026 öncesi `main` sürümü silinmedi: [backup/pre-portrait-reboot-20261011](https://github.com/TheOsmanYILDIRIM/oyun/tree/backup/pre-portrait-reboot-20261011), commit `e079890dac6b8beef2aaaf9f52539d5701953afc`. Yeni `main` çalışma ağacı sıfırdan kuruldu; Git geçmişi korunur.

## Temel ilkeler

- Android portrait 720x1280 referans; 9:16, 19.5:9, 20:9, 3:4 ve ekran kesikleri kontrol edilir.
- Dokun → hareket et / topla; isteğe bağlı sanal joystick; agresif savaş becerisi değil üretim ve keşif.
- `Definition` (ne?) / `Instance` (hangisi, nerede?) / `State` (anlık durum) / `Visual` (nasıl görünür?) ayrımı.
- Tanımlar JSON + JSON Schema; Godot runtime adaptörü ayrı. Kayıt `user://` ve sürümlü.
- İlk Android MVP için 2 eşzamanlı oyuncu, host yetkili komut onayı; genişletilebilir protokol.
- İçerik taslağı ile üretim verisi ayrıdır; eksik tanım asla sessiz varsayılan objeye dönüşmez.
- Model üretimi prosedürel/modüler; MTS ve üçüncü taraf varlıklar ancak lisans ve uyum kontrolünden sonra içe alınır.

## Repo haritası

`docs/` kararlar, UX, save/network, asset hattı, kaynaklar, açık sorular; `schemas/` JSON sözleşmeleri; `data/catalog/` örnek canlı içerik; `scripts/` Godot başlangıç iskeleti; `tests/` içerik ve yapı doğrulama; `.github/workflows/` CI.

## Başlangıç

Godot **4.6.3-stable** ile `project.godot` aç. `python -m unittest discover -s tests -v` içerik testlerini çalıştır. Sözleşme doğrulayıcısı için `python tests/validate_content.py`. Yerel testler gerçek Android FPS veya multiplayer kanıtı değildir.

Önce [docs/01_VISION.md](docs/01_VISION.md), [docs/02_ARCHITECTURE.md](docs/02_ARCHITECTURE.md), [docs/03_OBJECT_MODEL.md](docs/03_OBJECT_MODEL.md) ve [docs/09_OPEN_DECISIONS.md](docs/09_OPEN_DECISIONS.md) oku.
