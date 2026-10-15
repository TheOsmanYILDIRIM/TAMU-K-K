# oyun — 45° izometrik 2D hayatta kalma / crafting oyunu

**Güncel yön (15 Ekim 2026): LÖVE2D, 45° izometrik 2D, dikey mobil ekran ve görünür karo ızgarası bulunmayan prosedürel dünya.** Godot 4.6.3 3D yeniden başlangıç planı artık aktif oyun mimarisi değildir; ancak tarihsel iskelet ve eski kaynaklar korunmaktadır.

## Güncel çalışan temel (Aşama 1–4)

`game/love/` içinde gerçek LÖVE2D uygulaması: 45° dönüşüm, kamera kaydırma ve imleç çevresinde yakınlaştırma, mouse/WASD, dokunma/pinch, safe-area uyumlu portrait HUD, üç mevcut biyomla test sahnesi ve bölge seçimi. Gerçek LÖVE render döngüsü sanal ekranda CI ile açılıp doğrulanmıştır.

Dikkat: Üç biyomlu prosedürel seed/chunk ve Marching Squares dünyası, karakter/A*/CCD, deterministik kaynaklar ve geçici Wallet ile tek seferlik toplama **uygulandı**. Su geçilebilir: hareket çarpanı %55, görsel batma %50. JSON katalogdan türetilen paket içi kaynak tanımları CI ile kontrol edilir. Tam envanter, crafting, inşa, kalıcı kayıt, APK ve iki oyuncu **henüz uygulanmadı**. Gerçek Android cihaz/oynanış doğrulaması yapılmadı. Texture üretimi daha sonraki aşamaya bırakıldı.

## Çalıştır

LÖVE 11.x ile repo kökünde `love game/love` çalıştır. Windows/macOS/Linux'ta `game/love/` klasörünü LÖVE ile açabilirsin.

Kamera için WASD/yön tuşları veya fare sürükleme; zoom için fare tekerleği veya ekrandaki +/−; R kamerayı sıfırlar. Dokunmatik ortamda bir parmakla sürükleme, dokunarak bölge seçimi, iki parmakla zoom ve R düğmesi kullanılabilir.

```sh
cd game/love
lua5.4 tests/run.lua
lua5.4 tests/runtime.lua
```

GitHub Actions'taki `LOVE biome core validation` hem Lua kontrolünü hem Xvfb üzerinde gerçek LÖVE açılış/render smoke testini yapar. Kök `quality` workflow'u mevcut JSON katalog/Python testlerini sürdürür.

## Proje haritası

- [Uygulama yol haritası](docs/10_2D_GAME_IMPLEMENTATION_ROADMAP.md) — Aşama 1–9 hedefleri.
- [Yeni runtime mimarisi](docs/13_LOVE_2D_RUNTIME_STAGE1.md) — güncel 2D motor durumu ve kabul sınırları.
- [LÖVE runtime yönergeleri](game/love/README.md).
- `object-studio/` — görsel araçlar, mevcut davranışı ve kullanıcı verilerini koru.
- `data/catalog/`, `schemas/`, `tests/` — tanımlar ve doğrulayıcılar; motor adaptörleri sonraki aşama.
- `project.godot`, `scenes/`, `scripts/main.gd` ve eski 3D tasarım belgeleri — **tarihsel Godot iskeleti**, silinmedi.
- [Önceki yedek dalı](https://github.com/TheOsmanYILDIRIM/oyun/tree/backup/pre-portrait-reboot-20261011) — korunur.

## Koruma

`main` üzerindeki stüdyo ve veri dosyalarını, yedekleri, kayıtları, PNG'leri ve IndexedDB kullanıcı verilerini koru. `experiment/world-2d-design-20261012` dalında ayrı World Builder ve 2D tasarım çalışması bulunur; bu dal `main`in üzerine bütünüyle birleştirilmez. Varlıklar lisans/kaynak/hash doğrulaması sonrasında entegre edilir.
