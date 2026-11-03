# World tasarımının güncel yönü — 2026-10-12

## Kullanıcı tarafından kesinleştirilen kararlar
- Oyun dünyası **3D değil, 45° izometrik 2D** olacak. Önceki 3D voxel, 3D heightfield, 3D Godot scene ve 3D overworld önerileri güncel world hedefi değildir.
- Oyuncu karakteri dünyada 2D sprite olarak temsil edilecek. Dört yön için animasyon kareleri üzerinde ayrı deney yürütülüyor; bu not o deneye müdahale etmez.
- Ağaç, kaya, bina ve dünya nesnelerinin görsel temsili 2D dünya düzenine uyarlanacak. Sprite üretim tekniği ile dünya mantığı birbirinden ayrılacak.

## Henüz karar olmayanlar
- Zeminin büyük/tek parça görsellerle mi, parçalı-prosedürel bir düzenle mi üretileceği.
- Mantıksal grid, tilemap, serbest nesne koordinatları ve bunların hibrit kullanımı. Kullanıcı klasik tilemap estetiğini tercih etmiyor; bu teknik grid kullanımının yasak olduğu anlamına gelmez.
- Yükseklik, katman, occlusion, bina katları, arazi değiştirme/kazma ve mağara/dungeon geçişlerinin 2D karşılıkları.
- Kamera kaydırma/zoom, dünya sınırı, chunk/region yükleme ve pathfinding ayrıntıları.
- Eski Godot 4.6.3 başlangıç iskeletinin 2D implementasyona nasıl göç edeceği; mevcut 3D sahne kodu hedef mimarinin kanıtı değildir.

## Korunabilecek soyut sistemler (uyarlama ve test gerektirir)
- Stable definition ID, instance UUID, catalog, envanter/crafting/harvest sistemleri.
- Seed + generator_version, kayıt sürümü, atomik yazım ve eski kayıtların korunması.
- Host-authoritative iki oyunculu world mutation/senkronizasyon ve dokunarak hedef seçimi.
- Region, map/portal gibi kavramlar yalnız uygun 2D tasarım kabulünden sonra uygulanabilir.

## Önceki belgelerin statüsü
- `docs/11_RPG_MAP_STRUCTURE_PROPOSAL.md` 2026-10-11 tarihli **tarihsel ve henüz kabul edilmemiş 3D öneridir**. 2D kararının yerine geçmez.
- `docs/09_OPEN_DECISIONS.md`, `docs/01_VISION.md`, `docs/02_ARCHITECTURE.md` ve mevcut 3D scene, eski varsayımları içerebilir. Bu not güncel görsel/world yönü için önceliklidir. Ayrıntılı mimari revizyon, zemin tekniği seçimi ve ayrı testlerle yapılacaktır.
- Karakter referansı/animasyonu üzerinde paralel çalışılan dala ve `main`/`backup` dallarına bu not kapsamında dokunulmaz.

## Sıradaki tasarım kararı
2D dünya zemini nasıl temsil edilecek: büyük kesintisiz zemin, parça bazlı/prosedürel zemin veya hibrit? Görsellik ile mantıksal erişilebilirlik/pathfinding ayrılmalı; kararlaştırılmadan kod sistemi seçilmemeli.
