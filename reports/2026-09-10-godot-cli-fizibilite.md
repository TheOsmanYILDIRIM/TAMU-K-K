# Rapor: Godot 4 CLI/Headless Geliştirme Fizibilitesi (Termux ARM64)

**Tarih:** 2026-09-10 · **Araştıran:** Antigravity (plan fazı araştırması)

## Soru
Godot 4 arayüz (GUI) kullanmadan, tamamen CLI ile sıfırdan kodlanabilir, derlenebilir
ve derlemeden test/önizleme yapılabilir mi? Termux (ARM64 Android) ortamında?

## Bulgular

### 1. Resmi ARM64 binary — ✅ DOĞRULANDI
`godotengine/godot` GitHub release 4.4.1-stable varlıkları arasında
`Godot_v4.4.1-stable_linux.arm64.zip` mevcut (API sorgusuyla teyit edildi).
→ Cihaz üzerinde native çalışır, QEMU emülasyonu gerekmez.

### 2. Termux bionic uyumsuzluğu — ⚠️ proot GEREKLİ
Godot resmi derlemesi glibc'ye bağlı ( dynamically linked). Termux bionic linker
kullanır → binary doğrudan çalışmaz. Çözüm: `proot-distro install ubuntu` +
binary'yi Ubuntu içinden çalıştırmak. proot-distro cihazda zaten kurulu.

### 3. CLI yetenekleri (resmi dokümantasyon)
- `--headless` : rendering/display olmadan çalıştır (test, export, import)
- `--check-only --script X.gd` : GDScript sözdizimi/statik denetimi (CI lint)
- `-s script.gd` : SceneTree/NormalMap script çalıştırma → unit test framework'ü
- `--import` : asset import pipeline'ını headless çalıştır
- `--export-release` : export templates ile paketleme (Android APK → GitHub Actions)
- `--write-movie` : frame-by-frame render → önizleme video/PNG

### 4. Görsel önizleme (display olmadan)
- xvfb (sanal X sunucusu, kurulu) + Mesa llvmpipe (software GL rasterizer).
- Renderer: **GL Compatibility** (OpenGL 3.3) zorunlu — Forward+ Vulkan istemez.
- Screenshot: `viewport.get_texture().get_image().save_png()` — GPU'suz kanıt.
- Beklenen performans: 2 çekirdek ARM64'te düşük çözünürlükte ~5-15 fps (sadece doğrulama için yeterli).

### 5. Android export
- AGENTS.md kuralı gereği Termux'ta Gradle YOK → APK derleme GitHub Actions CI'da.
- Godot export templates headless export üretir; imzalama CI'da sabit keystore ile.

## Karar
Godot 4.4.1 arm64 + proot Ubuntu + xvfb/llvmpipe üçlüsü ile:
kodlama ✅ · lint ✅ · unit test ✅ · görsel önizleme ✅ · export (CI) ✅

## Kaynaklar
- https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- https://docs.mesa3d.org/drivers/llvmpipe.html
- https://github.com/godotengine/godot/releases/tag/4.4.1-stable
