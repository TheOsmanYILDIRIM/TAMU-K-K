# Core + plazma oyuncusu — ilk LÖVE2D entegrasyon prototipi

Kanonik karar: [docs/14_CORE_PLASMA_PROGRESSION_DESIGN.md](14_CORE_PLASMA_PROGRESSION_DESIGN.md),
2026-10-16. Bu belge kararı **uygulanmış sistemden ayırır**.

## Uygulama

- Oyuncunun bilincini büyülü-teknolojik metal **core** taşır; insan/golem
  anatomisi ve 2D mesh rigging oyuncu karakterinde kullanılmaz.
- `player/core_visual.lua`, oyuncunun mevcut `x,y,time,state,immersion`
  alanlarını kullanarak 45° izometrik dünyaya çekirdek, kontrollü
  plazma ve çevresel aura çizer. Karakterin çarpışma `radius`,
  Y-depth/ayak tabanı anchor, kamera takibi ve hareket motoru aynıdır.
- `objects/renderer.lua` eski sarı insansı placeholder yerine
  `core_visual.draw` çağırır. Sadece hasat sırasında mevcut kaynak
  `tree/rock` türünden balta/kazma üretir; `tool_pose()` zaman ve
  açı eğrisi kullanır. **Yeni sprite/texture gerektirmez.**
- Suya girme %55 yürüme hızı mevcut `player/controller.lua` içinde
  değişmeden korunur. Plazma ve çekirdek `player.immersion=0.5`
  kullanarak su çizgisinde kliplenir, karakter kısmen batmış görünür.
- `player/core_aura.lua`, isteğe bağlı stat/palet girdisini normalize eder.
  Ana ve ikinci stat rengi katmanlıdır, yüzdelik oranlar varsayılan %10
  basamağa indirgenir ve lider değişimine varsayılan 5 yüzde puan
  histerezis uygular. Gerçek stat listesi ve resmi palet **henüz
  kararlaştırılmadı**. Oyun içinde bu karar verilene kadar nötr
  plazma rengi kullanılır; örnek test ID'leri kanonik değildir.
- Genel level, Tech Level, Magic Level, özel core ödülleri ve plasma
  biçimlendirme henüz veri/mekanik kapsamı değildir. Ayrı sözleşmeler
  gerektirir; mevcut envanter veya kayıt şemasına sahte alan yazma.
- Geçmiş Mixamo/2D mesh rig deney dosyaları ve Character Rig Studio
  silinmez; **aktif oyuncu geliştirme yönü değillerdir**.

## Uygulama planı ve kabul

1. <strong>Şimdi:</strong> geometri/renk prototipi, su sınırı, ayak tabanı
   Y-depth, balta-kazma zaman eğrisi ve gerçek üretim sahnesi LÖVE smoke.
2. <strong>Görsel onay sonrası:</strong> core siluet/alaşım çizgileri,
   aura kalınlığı ve stat renkleri onayı; mobil 320/360dp ölçek ve
   GPU/pixel bütçesi testi.
3. <strong>Gelişim sistemi tasarımı sonrası:</strong> gerçek stat katalogu,
   dominans oranı, Tech/Magic level, özel core yetenekleri ve ödüller.
   Bunlar bu prototipin bir parçası değildir.

Test: `lua5.4 tests/core_avatar.lua`, `luajit tests/core_avatar.lua`,
LÖVE/Xvfb sahne smoke ve `tests/core_avatar_smoke.lua` görsel artifact.
Gerçek Android cihaz veya bağımsız game-save entegrasyonu iddia edilmez.

**Korunacaklar:** `main`, backup, world generator, Stage5, açık Stage6
deney dalı, Object/Terrain/World Builder, PNG, IndexedDB ve tüm eski
karakter/rig kaynakları. Bu prototip bir deney dalında doğrulanmalıdır.
