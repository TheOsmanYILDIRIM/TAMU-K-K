# notes.md — oyun (ham döküm & mimari notlar)

## 2026-09-10 — Oturum 1: Planlama

### Karar özeti
- Motor: Godot 4.4.1 stable linux.arm64 (resmi GitHub release; ARM64 build mevcut doğrulandı).
- Geliştirme %100 CLI/headless: `--check-only` lint, `-s test.gd` unit test, `--import` asset import.
- Önizleme: xvfb + Mesa llvmpipe (software GL) + Compatibility renderer → PNG screenshot kanıtı.
- Portrait 1080×1920; izometrik = orthographic kamera, rotation 45° yaw + -35.26° pitch (2:1 iso).

### Neden Compatibility renderer?
- llvmpipe = OpenGL (GL 4.5 / ES 3.1) software implementasyonu. Vulkan lavapiipe da var ama
  Termux/proot ARM64'te GL llvmpipe daha stabil. Godot Compatibility = OpenGL 3.3 → sorunsuz.
- Mobil hedef zaten Compatibility ile export edilecek — tek renderer, tutarlılık.

### Data-driven mimari (kullanıcı kararı)
- "Kurallar" (BlockDef/ItemDef/BiomeDef/MobDef = Resource .tres) ile "objeler" ayrı tutulur.
- Davranışlar kompozisyon: mineable, collectible, placeable, gravity_affected...
- Registry autoload: `Blocks.get_def(&"stone")`. Chunk'ta yalnız `u16 id` tutulur.
- Kazanç: yeni obje = 0 satır kod; aynı kuralı kullanan objeler aynı davranışı paylaşır.
- Moblar sonra eklenecek — aynı Registry/Def sistemine oturacak (MobDef iskeleti şimdiden).

### Worldgen (kullanıcı: "Minecraft noise'unun aynısı")
- FastNoiseLite (Godot built-in) — Perlin/Simplex.
- Katman 1: continentalness/heightmap → yüzey yüksekliği.
- Katman 2: sıcaklık (temperature), Katman 3: nem (humidity) → biyom seçimi (BiomeDef lookup).
- 32 blok derinlik (bedrock y=0), gökyüzü maksimum yükselmede (build limit = üst sınır).
- Seed deterministik → test edilebilir worldgen.

### Multiplayer
- ENetMultiplayerPeer, server-authoritative. Dünya mutasyonu (kır/yerleştir) sunucuda doğrulanır.
- Portrait mobil + multiplayer → düşük paket sıklığı, chunk delta sync.

### Riskler
- 2 çekirdek + llvmpipe: önizleme yavaş (5-10 fps) → screenshot tabanlı doğrulama.
- proot I/O cezası: asset import yavaş olabilir; .godot cache'i korunmalı.
- Bellek: 7.6GB toplam, ~2.7GB available → chunk mesh budget'i düşük tutulmalı (render distance 3-4 chunk).

### Açık sorular
- Kontrol şeması (portrait: sol joystick + sağ action butonları?) — UI fazında netleşecek.
- Crafting tarzı: Minecraft 3x3 grid mi, liste-bazlı mı? → MVP liste-bazlı önerilir (mobil dostu).
