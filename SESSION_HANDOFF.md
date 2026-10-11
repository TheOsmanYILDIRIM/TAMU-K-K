# Oyun — Teknik devir (2026-10-11)

## Durum
Yeni Android portrait 3D crafting/co-op oyunu için sıfırdan repo iskeleti. Bu commit oynanabilir APK ve bitmiş gameplay değildir.

## Geri alınabilir yedek
- Eski `main` commit: `e079890dac6b8beef2aaaf9f52539d5701953afc`.
- Ayrı branch: `backup/pre-portrait-reboot-20261011` — SHA eşlemesi kontrol edildi.
- Eski Eylül prototipi, tüm testleri ve workflow geçmişi bu dalda. Yeni `main` eski kodunu varsayılan olarak çalıştırmaz.
- Yeni `main` eski commit'in çocuğu olan **yeni tam ağaç** commit'i ile oluştu, zorla geçmiş yazma yok.

## Mimari kararlar
- Oyun gerçek 3D, portrait-first, izometrik ve kolay toplama/crafting odaklı.
- Sabit, namespaced tanım ID; instance UUID; durum ve görsel ayrı; chunk blokları world-local palette.
- Önce minimal üretim kataloğu ve JSON Schema; tarif, world save, input/network sözleşmeleri.
- Engine Godot 4.6.3, Compatibility başlangıç hedefi; model ve performans cihazda henüz doğrulanmadı.

## Sonraki adım
1. Godot headless + içerik CI test sonuçlarını gerçek Actions üzerinden doğrula.
2. Portrait Android UI prototipi: tıkla git / topla, seçili hedef vurgusu, jest çakışma testi.
3. Tanım registry runtime + iş emri kuyruğu + craft sistemi; atomik world save.
4. İki Android cihazla LAN/host doğrulaması, paket ve FPS ölçümü.
5. Prosedürel model kitini kur; lisans manifesti ve GLB/UV pipeline.

Açık kararlar: `docs/09_OPEN_DECISIONS.md`. Önceki başarı iddiaları (61/137/155 test) **arşiv prototipine** aittir.
