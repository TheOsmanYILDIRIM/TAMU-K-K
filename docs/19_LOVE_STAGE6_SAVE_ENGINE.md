# Aşama 6 — LÖVE2D save v2 izolasyon ve recovery motoru

Stage6 modülü ve Aşama 5 transaction köprüsü `game/love/main.lua` üzerinde **yalnız opt-in** bağlıdır (`OSMAN_STAGE6_EXPLICIT=1`, açık world ID). **Otomatik kayıt varsayılan olarak kapalıdır.** Test edilen checkpoint/recovery semantiği Android fsync veya atomik rename dayanıklılığı sağlamaz.

## Kullanım / katman sınırı

\`save.store\` bağımsız sınıftır: \`Store.new(fs, {catalog=known_defs,
generator_version=1, catalog_version=1})\`; \`:commit(full_snapshot)\`;
\`:load(world_uuid)\`. \`fs\` portu \`read(path)\`, \`write(path, bytes)\`,
\`mkdir(path)\` ister. LÖVE adaptörü \`require("save.love_fs").new()\`.
JSON encoder/decoder \`save.json\` içinde, checksum SHA-256 \`save.hash\`
içindedir. \`save.validate\` uyum ve semantik kontrolüdür. Katalog
**explicit** enjekte edilir (Aşama 5 \`systems.catalog.items()\` ancak
Aşama 5 üretime alınırsa kullanılabilir); bilinmeyen ID reddedilir.

Snapshot tam state içerir: envanter dense \`slots\` dizisi, depleted
\`worldobj:v1:seed:gx:gy\` delta, placed UUIDv4, world revision, command
ve transaction ledgers. Kayıtlı sıralı \`journal_sequence\` asla RAM
terrain/render cache içermemelidir. İstemci, world + inventory +
depletion + ledgers değişikliklerini \`commit\` çağrısından **önce tek
immutable aday state** olarak hazırlamalıdır. Kaydetme modülü oyundaki
hasat/inşa atomikliği sorununu kendiliğinden çözmez.

\`worlds/<uuid>/journal/<seq>-<sha>.jsonl\` içinde revizyona ait komut ve
transaction ID listesi ve snapshot checksum'u bulunur; bu dosya bir
*checkpoint receipt* olup bağımsız event replay motoru değildir.
\`snapshots/<revision>-<sha>.json\` canonical state'tir. Önce journal,
ardından snapshot yazılıp read-back/hash/contract ile doğrulanır.
Eski sağlam \`current.json\` içeriği \`previous.json\` içine yazılıp
geri okunur, en son yeni \`current.json\` yayımlanır. Journal ve
snapshot içerikleri hash-adresli immutable'dır. Aynı state yeniden
kaydedilirse disk yazımı yapılmaz. Kayıp/bozuk current durumunda
previous yalnız **read-only** açılır. Her iki pointer da kullanılamazsa
quarantine; yeni boş dünya ile veri üzerine yazılmaz.

**Sınır:** LÖVE \`love.filesystem.write\` için fsync, atomik rename,
Android power-loss dayanıklılığı, storage permission, directory sync
ve crash sırasında dosya sırasının kalıcılığı doğrulanmış değildir.
Bu sözleşme doğrulanabilir uygulama-seviyesi checksum ve önceki
snapshot recovery sağlar, platform atomikliğini garanti etmez.
Eski voxel schema, v1 template, Godot \`user://\` veya kayıt dosyalarına
hiçbir göç/yazma işlemi yoktur. Dizinler LÖVE save sandbox içindedir.

## Kabul için açık bağımlılıklar

- Opt-in moddaki Stage5 hasat/craft/inşa işlemleri detached domain üzerinde hazırlanır ve Stage6 commit sonrası canlı oyun nesnelerine yayımlanır. Varsayılan Stage5 RAM akışında disk kaydı yoktur.
- Masaüstünde iki ayrı gerçek LÖVE/Xvfb sürecinde oluşturma ve yeniden açma CI ile sınanır. Gerçek Android işlem kesintisi/power-loss, dosya sıralaması ve host otoritesi doğrulanmadan production/autosave açılmaz.
- CI'da Lua 5.4/LuaJIT sözleşme ve hata enjeksiyonu; gerçek LÖVE
  filesystem smoke yalnız CI sanal ekranda ve izole sandbox'ta test
  edilir. Bu mobil dayanıklılık kanıtı değildir.

Ek idempotency kontrolü: bir kez checkpoint edilmiş `applied_commands`, `applied_transactions`, `placed_instances` kayıtları yeniden yazılamaz veya silinemez; `depleted=true` procedural delta geri alınamaz. Bu kural mutation replay / kaynak geri canlandırma riskini fail-closed yapar. Olası komut durum geçişleri (started → complete) için yeni tasarım gerekiyorsa yeni komut sürümü/kayıt yaklaşımı kararlaştırılmadan üretimde kullanılmaz.
