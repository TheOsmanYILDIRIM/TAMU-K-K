# Güncel 2D yön (2026-10-12)

**Kesin karar:** Dünya 3D yerine **45° izometrik 2D** olacak; karakter 2D, dört yönlü sprite animasyonu hedefleniyor. Önceki tabloda geçen 3D voxel/heightfield/3D kamera/renderer varsayımları artık güncel dünya kararı değildir. Bunlar tarihsel araştırma olarak korunmuştur. Güncel kaynak: [`12_WORLD_2D_DIRECTION_20261012.md`](12_WORLD_2D_DIRECTION_20261012.md).

**Açık:** Tek parça veya prosedürel parçalı zemin, mantıksal grid/tilemap, 2D yükseklik/occlusion, world sınırları, mağaralar ve pathfinding. Bu sorular için henüz teknik seçim yapılmadı. Karakter deney dalına müdahale edilmez.

---

# Açık karar kaydı

Bu sorular tamamlanmış karar değildir; şema buna göre boş/esnek tasarlanmıştır.

| Alan | Başlangıç varsayımı | Karar deneyi |
| --- | --- | --- |
| Zemin | 3D voxel + 3D objeler hibrit | Chunk voxel mi, 3D heightfield + destructible hücre mi? |
| Kamera | Döndürülebilir ortografik iso | 90° snap, serbest 360° orbit, duvar fade kıyasla |
| Yürüme | Tap-to-move varsayılan, joystick opsiyonel | 10 dk iki telefon testi |
| Harvest | İş emri ile otomatik toplama | İlerleme süresi/iş kesilme UX |
| Craft | Kategori/listeli + istasyon | Drag grid ek değer yaratıyor mu? |
| World | Küçük region ve gerektiğinde genişleme | Sonsuz chunk mobil için ertelensin mı? |
| Save | Slotlar, dünya owner, offline-first | Cross-device backup kullanıcı akışı |
| Co-op | Host-authoritative LAN | Relay ihtiyacı, NAT, host offline davranışı |
| Stil | Stilize voxel/low-poly | MTS kaynak texture ve low-poly birlikteliği |
| Asset | Prosedürel öncelik | Hayvan rig/animasyon preset sayısı |
| Render | Compatibility baseline | Hedef Android donanımda Mobile renderer A/B |
| Accessibility | Kontrol ölçeği, sol/sağ el | Dokunma hedefi gerçek cihazda |
| Modlama | JSON katalog | İleri sürümde güvenli eklenti/sandbox gereği |

Değişen tasarım kararı bu tabloda gerekçe, ölçüm, tarih ile kaydedilir; ilk öneri otomatik kalıcı karar olmaz.
