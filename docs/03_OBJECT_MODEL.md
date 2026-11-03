# Obje modelinin temel sözleşmesi

## Beş farklı kimlik
- **Definition ID**: değişmez, insan-okunur, namespaced `core:oak_tree`; `core:wood_log`. Save ve network ID kararlı kalır.
- **Runtime registry index**: yükleme başına geçici hızlı sayısal indeks; kesinlikle tek başına diske veya ağa yazılmaz.
- **World-local voxel palette index**: chunk'taki block slotu world manifest'teki kalıcı ID eşlemesine bağlı; 0='core:air'. Katalog değişse de eski save okunmalı.
- **Instance ID**: durum tutan nesnenin UUID'si; tekil ağaç, sandık, workbench, mob. Spawn/despawn ve command hedefi.
- **Network player ID**: oturum geçici peer ID; kalıcı oyuncu kimliği ve save slotu bundan bağımsız.

## Tanım / durum / görsel ayrımı
```
Definition{ id, kind, name_key, tags, components, visual_ref }
   + Instance{ instance_id, definition_id, transform, component_state }
   + Asset{ asset_id, source, license, sha256, variant }
   + World{ generator_version, palette, chunks, entities }
```

### Definition (statik)
Bir tanımın kind'ı: `item`, `resource`, `structure`, `creature`, `block` veya `machine`. `components` davranış yeteneklerini tanımlar:
- `core:stackable`: `max_count`
- `core:harvestable`: `duration_ticks`, `drops`, `tool_tags`
- `core:inventory`: `slots`, `access`
- `core:craft_station`: `station_tags`, `queue_limit`
- `core:placeable`: `footprint`, `rotation_steps`
- `core:health`, `core:growable`, `core:interactable` sonraki faz
Yetenekler isteğe bağlı ve tür bağımsız olabilir. Ortak motor, yalnız tanımlı bileşenleri işler. Undefined component = validation error.

### Instance (dinamik)
Ağaç `core:oak_tree` tanımından doğar. Kendi `instance_id`, `health`, `growth_stage`, `position`, `reserved_by` gibi **değişen** alanları world save taşır. Catalog güncellense bile eski snapshot'ın def ID'si korunmalı.

### Item stack
`{def_id:"core:wood_log",count:4,instance_state?:{...}}`. Unstackable/durable eşya ayrı instance metadata taşıyabilir; stacking key = def ID + özelleştirilmiş metadata. Kaynağın instance ID'si ile envanter stack ID'si karıştırılmaz.

### Recipe / job
Recipe `id`, `inputs`, `outputs`, `station_tags`, `duration_ticks`; üretim işi `job_id`, `recipe_id`, `owner_player_id`, `progress_ticks`, `reservation_ids`. Malzeme harcama ve çıktı oluşumu host tarafında atomik işlem.

### Örnek ilişki
`core:oak_tree` (resource) --harvest-> `core:wood_log` (item) --`core:planks_from_log`-> `core:wood_plank` (item). Yeni obje önce JSON Schema ve referans bütünlüğü testinden geçer. Örneklerin gerçek oynanışa bağlı olduğu iddia edilmez.

## İleride göç ihtiyacı
Her kayıt `schema_version` içerir; eski ID silinmek yerine `aliases/migrations` belgesiyle dönüştürülür. Tanım değiştirme ve world save yükseltmesi ayrı işlemler ve yedekli migration gerektirir.
