# Mimari sınırlar ve çalışma planı

## Akış
```
input intent (tap/drag/joystick) --> command queue --> authority validation
                                     |                    |
                                     v                    v
                              navigation plan         game systems
                                                     /  |  |   \
                                               harvest craft storage build
                                                      |
                                                world mutations
                                                      |
                               persist (versioned) / event replication
                                                      |
                                                render adapter
                                                     / \
                                             3D meshes   portrait HUD
```

## Katmanlar
1. **Catalog** (salt-okunur, sürümlü): `data/catalog/definitions/*.json`, `recipes/*.json`; şemaya göre doğrulanmış, bozuk ref engellenir.
2. **Registry**: ID -> tanım; schema_version+migration, deterministic ordered loading. Runtime esnek key-string, yoğun sistemlerde world-local numeric palette.
3. **Domain systems**: harvest, inventory, crafting, storage, placement, growth, health, economy; statik tanımların davranış kompozisyonu.
4. **World storage**: seed + generator_version + chunk voxel + bağımsız durumlu objeler. Chunk v1 koordinat/tür/yalın palette; format optimize edilmeden önce referans test.
5. **Intent/nav**: kullanıcı hedefe dokunur; pathfinding ve state machine işi üstlenir. İptal/engel ve erişim hataları UI'ya kodla döner.
6. **Networking**: owner host authoritative, komut_id ve sequence/revision, doğrulanmış world events, snapshot + delta. İki kişi/yeniden bağlanma ayrı faz.
7. **Presentation**: kamera, occlusion, placeholder -> prosedürel GLB -> asset override; render kaynak tanımdan ayrılır.
8. **Persistence**: `user://` altında snapshot+world delta+inventory, atomic-write temp+rename+checksum; migration başarısızsa korumalı read-only.

## Bilinçli ertelemeler
- ECS framework veya third-party networking framework şu anda zorunlu değil.
- Godot `.tres` runtime derleme/asset cache için kullanılabilir, ancak sürümlü içerik sözleşmesinin kanonik metni **JSON**. İçerik farkı Git'te görülebilir.
- Sonsuz dünya, LZ4, greedy-mesh, karmaşık topology ve host migration henüz uygulanmıyor. Şemalar sürümler arası dönüşüme açık.
- İleri optimizasyonu ölçüm gelmeden kesin gereksinim olarak yazma.

## Kod yerleşimi
`scripts/core`: catalog adapter; `scripts/systems`: domain işlem motorları; `scripts/world`: chunk/instance; `scripts/input`: intent; `scripts/ui`: portrait HUD; `scripts/network`: host protocol; `scripts/persistence`: save/load; `scripts/visual`: procedural model render.
Klasörler gerçekten kodlandıkları fazda oluşturulur; boş klasörleri Git takip etmez.
