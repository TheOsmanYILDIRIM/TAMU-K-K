# AGENTS.md — oyun (Iso Voxel Survival) Atölye Kuralları

> Bu dosya `~/AGENTS.md` (ana ev kuralları) ile birlikte okunur. Proje-özel
> kurallar burada; çakışma halinde daha sıkı olan geçerlidir.

## Ortam ve Çalıştırma
- Godot 4.4.1 linux.arm64 binary: `~/godot/Godot_v4.4.1-stable_linux.arm64`
  - glibc binary → **`grun` (glibc-runner) ile Termux'ta NATIVE çalıştırılır.**
  - proot/Ubuntu KULLANILMAZ (2026-09-10 kararı; glibc-runner + mesa + xvfb kurulu).
- Render: GL Compatibility + llvmpipe (software, native Mesa). Forward+ KULLANILMAZ.
- Portrait: 1080×1920. Kamera: ortografik izometrik.
- Termal koruma: uzun derleme/render `nice -n 15`; paralel ağır iş YOK.

## Görsel Önizleme ve APK (2026-09-10 KARARI)
- **Görsel önizleme kullanıcıya ait:** Ajan ekran görüntüsü/render almaz, bu konuda çalışmaz.
- Ajan doğrulaması = headless test + `--check-only` lint (görsel iş yok).
- **APK derlemesi GitHub Actions CI'da** (Termux'ta Gradle yok — ev kuralı 4).
  - Sabit keystore hem debug hem release'e atanacak (üst üste kurulum kuralı).
- Preview script'i (`tools/preview.sh`) yalnız kullanıcı manuel çalıştırmak isterse var.

## Kod Standartları
- GDScript: static typing zorunlu (`:=`, `: Type`), `class_name` her Def sınıfında.
- Data-driven: blok/item/mob davranışı KOD'A DEĞİL `.tres` TANIMINA yazılır.
  - Yeni obje = yeni .tres; ortak davranış `behaviors/` script'inde tek sefer.
- World verisi: chunk voxel'leri `u16 id` dizisi; instance yalnız durumlu varlıklar.
- Hata yönetimi: sessiz fallback yasak (ev kuralı 1.1). Eksik def = push_error + null.
- Test kapısı: her sistem için `tests/` altında headless test; PR öncesi yeşil.

## Çeviri
- Kullanıcıya görünen HİÇBİR metin hard-coded olmaz → `tr(key)` üzerinden.
- `data/translations/en.csv` (kaynak) + `tr.csv`. Yeni metin = önce en.csv'ye.

## Multiplayer
- Server-authoritative: dünya değişikliği (kır/yerleştir) yalnız sunucuda uygulanır, RPC ile yayınlanır.
- İstemci tahmini (prediction) sadece hareket için.

## Vault Senkronu
- Mimari karar → `AGY-Vault/10-Projects/oyun/Proje.md` "Son Kararlar" bölümüne tarihli eklenir.
- Yarım iş → `backlog.md`. Araştırma çıktıları → `reports/`.
