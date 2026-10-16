# oyun — 45° izometrik 2D hayatta kalma / crafting oyunu

**Güncel yön (16 Ekim 2026): LÖVE2D, 45° izometrik 2D, dikey mobil ekran ve görünür karo ızgarası bulunmayan prosedürel dünya.** Godot 4.6.3 3D yeniden başlangıç planı artık aktif oyun mimarisi değildir; ancak tarihsel iskelet ve eski kaynaklar korunmaktadır.

## Güncel çalışan temel (Aşama 1–5)

`game/love/` içinde gerçek LÖVE2D uygulaması: 45° dönüşüm, kamera kaydırma ve imleç çevresinde yakınlaştırma, mouse/WASD, dokunma/pinch, safe-area uyumlu portrait HUD, üç mevcut biyomla test sahnesi ve bölge seçimi. Gerçek LÖVE render döngüsü sanal ekranda CI ile açılıp doğrulanmıştır.

Üç biyomlu prosedürel seed/chunk ve Marching Squares dünyası, karakter/A*/CCD, deterministik kaynak toplama, **12 slotlu envanter ve hotbar, süreli crafting ve workbench yerleştirme** gerçek oyun döngüsüne bağlandı. JSON → Lua katalog paritesi, envanter doluluğunda kayıpsız hasat reddi, komut/transaction tekrar koruması ve RAM içi atomik kredi/tüketim test edilir. Su geçilebilir: hareket çarpanı %55, görsel batma %50. **Aşama 6 disk kayıt/geri yükleme, Android APK ve gerçek cihaz testi, ağ otoritesi/iki oyuncu henüz uygulanmadı.** Yerel UUIDv4 üretimi yalnız geçici tek oyuncu içindir. Texture üretimi sonraki aşamadır.

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

`main` üzerindeki stüdyo ve veri dosyalarını, yedekleri, kayıtları, PNG'leri ve IndexedDB kullanıcı verilerini koru. `experiment/world-2d-design-20261012` dalında ayrı World Builder ve 2D tasarım çalışması bulunur; bu dal `main`in üzerine bütünüyle birleştirilmez. Varlıklar lisans/kaynak/hash doğrulaması sonrasında entegre edilir.
