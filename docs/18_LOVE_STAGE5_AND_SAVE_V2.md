# Aşama 5 — Envanter, crafting, inşa ve Aşama 6 kayıt sözleşmesi

Durum: \`experiment/stage5-inventory-crafting-v1\` deney geliştirmesi. Main ve
eski Godot/voxel şemaları **değiştirilmemiştir**. Aşama 5 oyunla nihai
bütünleştirme ve gerçek cihaz henüz kabul edilmiş sayılamaz.

## Kanonik kaynaklar

\`data/catalog/manifest.json\` içindeki Definition ve Recipes JSON'ları
kanoniktir. \`scripts/generate_love_stage5_catalog.py\`, yalnız paketleme için
\`game/love/systems/catalog_generated.lua\` üretir. CI \`--check\` ile byte-for-byte
pariteyi doğrular. Aşama 4'ün \`objects/catalog_generated.lua\` dosyasına
dokunulmaz. \`systems/catalog.lua\` yalnız veri okur.

\`systems/inventory.lua\`:
- 12 slot varsayılan (1–256), her slot \`{def_id,count}\` ve JSON'daki
  \`core:stackable.max_count\` sınırı. Yerleştirilebilir yapılar tekli stack.
- Geçersiz Definition açık hata; eksik alan/ID için uydurma fallback yok.
- \`HarvestCompleted.transaction_id\` replay'i bir kez kredilendirir;
  kapasite doluysa hiçbir slot/ledger değişmez.
- \`preview/commit_preview\` ile tüketim ve üretim RAM içinde birlikte yazılır.

\`systems/crafting.lua\`: kanonik recipes, station tag doğrulaması, istasyon
yokken zorunlu tarif engeli, yetersiz girdide ya da dolu çıkışta **sıfır
malzeme değişimi**. Aynı \`command_id\` yine aynı sonucu döndürür. Şimdilik
recipe \`duration_ticks\` veri sözleşmesidir; üretim anında tamamlanır.
Asenkron iş kuyruğu/işçilik süresi Aşama 5 genişletmesinde gereklidir.

\`systems/building.lua\`: dünya kimliği UUIDv4; yeni placed ID bir host
tarafından verilmiş **ayrı UUIDv4** olmalıdır. Henüz UUID üreticisi,
kullanıcı/auth veya ağ host'u yok; test/demode yalnız sabit fixture ID
kullanılır. Değişmez \`worldobj:v1:<seed>:<gx>:<gy>\` procedural kaynak
kimliğinden farklıdır. Yerleştirme: dry/ground kontrolü, mesafe,
resource ve diğer placed collider örtüşmesi, oyuncu ayak izi,
rotation ve envanterden 1 öğe tüketimi. World revision yalnız başarıda
artar, placement ID/metadata snapshot'a girer.

## Hedef Stage 6 save_v2 (tasarım; diske yazılmaz)

**Yeni dosya ailesi:** \`love.filesystem\` altında
\`worlds/<world_uuid>/snapshots/<revision>.json\`,
\`worlds/<world_uuid>/journal/<sequence>.jsonl\`,
\`worlds/<world_uuid>/current.json\` ve
\`worlds/<world_uuid>/previous.json\`. Eski Godot \`user://\`
\`data/templates/empty_world.v1.json\`, \`schemas/world.json\` ve
oyuncu dosyalarına hiçbir yazma/migration bu fazda uygulanmaz.

Snapshot contract taslağı:

\`\`\`json
{
  "format": "love-world-2d",
  "save_version": 2,
  "world_id": "12345678-1234-4abc-8abc-123456789abd",
  "seed": 20261015,
  "generator_version": 1,
  "catalog_version": 1,
  "world_revision": 2,
  "player": {"id": "player:local", "x": 0, "y": 0, "inventory": {
    "version": 1, "capacity": 12,
    "slots": [{"slot": 1, "def_id": "core:wood_log", "count": 3}]
  }},
  "generated_object_delta": {"version": 1, "objects": {}},
  "placed_instances": {},
  "applied_commands": {},
  "applied_transactions": {},
  "journal_sequence": 2
}
\`\`\`

\`generated_object_delta\` ayrıca aynı \`seed\` ve
\`generator_version\` içerir. \`placed_instances\` keyed by UUID, immutable
\`definition_id\`, transform, owner and last revision. Resolved
runtime index/graphics mesh/viewport/cache **kaydedilmez**.

**Atomiklik:** Game domain tek revision altında
harvest depletion + material credit + both ledgers veya craft debit+credit
veya build debit+placed instance'ı staging state'te hazırlar. Durable journal
entry önce temp dosyada, checksummed payload (SHA-256) ile doğrulanır.
Tamamlanmış snapshot yeni revision altında yazılır,
read-back checksum ve schema kontrolü geçtikten sonra
\`current\` pointer atomik değiştirilir, \`previous\` rollback için
korunur. \`love.filesystem.write\` tek başına atomik
\`fsync+rename\` garantisi değildir; Android/desktop davranışı gerçek
cihaz testleriyle doğrulanmadan bu düzeyde dayanıklılık iddia edilmez.

Açılışta last complete pointer ve checksum doğrulanır; bozuk yeni
snapshot varsa \`previous\` sağlam sürüme dönülür, hiçbir bozuk veri
üzerine yazılmaz. Generator version mismatch veya bilinmeyen Definition
kimliğinde *read-only/quarantine* ve migration isteği; v1 voxel world
farklı format, otomatik varsayılanla yüklenmez. Exact-once ağ semantiği
için authoritative host revision/command ID ve \`HarvestCompleted\`
credit aynı durable transaction sınırına alınmalıdır. Şu an
\`harvesting.lua\` önce nesneyi deplete, sonra event yayınlar; full inventory
veya süreç ölümü halinde kaynak kaybı **hala mümkündür**. Bu düzelmeden
production save açılmamalıdır.

## Bitti kapıları

1. JSON->Lua parity, Lua5.4+LuaJIT, full previous regression, in-memory
   craft/build/slot/UUID/transaction tests CI geçmeli.
2. Gerçek LOVE envanter/craft/build smoke ve PNG için bağımsız deney
   sahnesi, ardından main entegrasyonu gereklidir.
3. Disk save, Android test, multiplayer ve senkronize host authority **henüz
   uygulanmadı**. Aşama 6 kalıcılık, Aşama 7 Android, Aşama 8 ağ kapsamıdır.

## Additive executable v2 schema

`schemas/love-world-v2.schema.json` and
`data/templates/empty_love_world_v2.json` are **new** files defining the
future save serialization. `tests/test_love_world_v2_contract.py` validates
the template, old v1 distinction, seed/version invariants, placed UUID refs,
inventory slot uniqueness/stack maxima and unknown IDs using JSON Schema
plus semantic validation. The schema is an interface contract only:
no `love.filesystem` writes, migration, replays or durability implementation
have been added. Inventory `:snapshot()` now exports a dense list of
`{slot,def_id,count}` entries for JSON-safe round trips.

## Stage5 live runtime integration (experiment only)

Real `game/love/main.lua` uses 12-slot inventory, safe-area portrait HUD,
5 hotbar selectors, canonical recipe selection, timed 30/60-tick crafting,
station proximity validation, touch/keyboard placement preview, rotate and
confirm. Harvest stages inventory drops before resource depletion, checks
duplicate transaction IDs, and credits only once in RAM. Inventory-full
rejects the harvest without depletion. A successful placement adds a workbench
collider for player and pathfinding queries, maintaining the existing water
surface behavior. Local UUIDv4 values are session-ephemeral; multiplayer
authoritative IDs are **not** implemented. `love.filesystem` persistent
save and crash durability remain Stage6 scope. Running the new
`OSMAN_LOVE_STAGE5_RUNTIME_SMOKE=1` exercises the main LÖVE scene and
produces `stage5-production-touch.png` in Xvfb Actions.
