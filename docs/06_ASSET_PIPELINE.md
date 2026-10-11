# 3D modelleme yükünü düşürme planı

Üç kaynak birlikte kullanılabilir fakat varlıkların kaynak hakları ayrı ayrı kayıt edilir.

## A — prosedürel kit
- Taş/kaya: seeded icosphere/polyhedron varyasyonları
- Ağaç: gövde silindir/küp + dal generator + yaprak demetleri
- Mob: gövde/kafa/bacak/eklem primitive parçaları; temel rig şablonları
- Yapılar: modüler duvar, çatı, kapı, zemin, iş masası
- Üretilen GLB stable generator_version + seed ile fingerprint edilir.
- `assets/manifest.json` veya `schemas/asset.schema.json` kuralları ile tasarım kaynağı ve hash eşlenir.

## B — lisanslı hazır varlıklar
- Kenney Nature Kit ve Survival Kit: CC0 bilgisi **paket sayfasında** denetlenmeli; aynı stil içinde seç.
- Poly Haven: CC0, ancak gerçekçi 3D modeller voxel/stilize oyunla uyumsuz olabilir.
- Quaternius: resmi site/asset başına lisans+format incelenmeden oyun içine ekleme.
- Varlık lisansları proje gizli diye serbestleşmez; üçüncü taraf dosyalarını bulk kopyalamak yerine kaynak katalogu tut.

## C — MTS'den seçmeli adaptör
- Mineclonia texture, UV/B3D/GLB pipeline teknik olarak yararlı olabilir, fakat Mineclonia lisansı, mod katkısı, texture pack hakları ayrı incelenmeli.
- Eski MTS modelleri ve farklı oyunların sistemleri varsayılan içerik değildir. Yeni oyuna bağımlılık zorunlu değil.
- B3D -> GLB aktarımında rig/animasyon, UV/alpha, primitive pivot, scale doğrulanmadan kullanma.

## Üretim işlemi (ileride)
`asset_sources.csv` -> lisans gate -> import -> origin normalization -> collider LOD -> texture atlas -> GLB -> mobile benchmark -> content_def.visual_ref.
Kopyalanmış asset yoktur; şu an yalnız plan/şemalar ve procedural placeholder vardır.
