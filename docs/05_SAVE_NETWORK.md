# World / save / network veri sözleşmeleri

## Disk
`user://worlds/<world_uuid>/manifest.json`, `chunks/<coords>.bin`, `entities/<region>.json`, `players/<player_uuid>.json`, `journal/<sequence>.jsonl` (gelecekte). Sözleşme: `schemas/world.schema.json`, `schemas/player.schema.json`, `schemas/network-command.schema.json`.

- `save_version` zorunlu; `generator_version` dünya yeniden üretimini deterministik yapar.
- Chunk palette `core:block_id` dizisi ve indeksli byte array; boş blok index 0. Serialization formatı optimize edilmeden önce yeniden açma testi.
- `instance_id` kaybolmaz; istemcide bir objenin iki kere spawn edilmesini önleyen benzersiz anahtar.
- Atomic temp file + fsync/rename ve önceki snapshot saklama planı; ilk iskelette uygulanmadı.
- Kaydedilemeyen kayıt sessizce yok edilmez; kullanıcıya açık hata, orijinal dosya korunur.
- Avatar slot ve dünya yetkisi birbirinden ayrılır; Android reinstall sırasında yedek/aktarma ayrı modül.

## Ağ
```
Client intent {command_id, session_id, player_id, seq, kind, target, params}
  -> Host validate (range, tool, inventory, reservation, rate, ownership)
  -> Commit world mutation once
  -> Event {world_revision, command_id, entity_id, change}
  -> Reliable replication + ack; late join snapshot then deltas
```

Host yetkisi: kırma, toplama, crafting, envanter ve drop. İstemci movement prediction yapabilir; önemli dünya işlemlerinde yerel kesin kayıt yok. Komut idempotent (command_id), tekrar gelirse iki kez ürün verilmez. Paketler boyut sınırı, max command rate ve allowlist kullanır.

Godot ENet UDP; LAN ilk MVP, dış internet NAT/dedicated/relay değerlendirmesi sonra. Android export için `INTERNET` permission unutulmaz. İki telefonla test yapılmadan co-op çalışıyor denmez.

## Kayıt sürümü testleri
- Snapshot round-trip deterministik
- Yeni tanım ekleme eski dünyayı bozmaz
- Missing definition = explicit error / read-only koruma
- Yarıda kalan save yazımı önceki sürümü korur
- Replay double-command inventory duplike etmez
- Host disconnect/yeniden bağlanma davranışı belgelenir (ilk sürümde host migration yok)
