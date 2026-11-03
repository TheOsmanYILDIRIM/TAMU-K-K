# 2026-10-11 — RPG odaklı sınırlı yükseklik + ayrı mağara/dungeon haritaları (değerlendirme, KARAR DEĞİL)

## Amaç
Android portre ekranda, düşük beceri yüküyle toplama/crafting/inşa ve iki kişilik co-op. Önceki "sonsuz dikey voxel dünya" hipotezine alternatif. Godot/Unity seçimi bu notla kesinleşmez.

## Ürün ve dünya önerisi
- Ana ton: yumuşak/cozy frontier fantasy; crafting, keşif, üssü geliştirme, isteğe bağlı hafif RPG karşılaşmaları. Aşırı savaş ve loot grind öncelik değil.
- Yüzey: ortografik izometrik 3D, yükseklik farkı prototipte 0–8 kademe (oyun tasarım sınırı, motor sınırı değil); 1–3 kat bina başlangıç hedefi.
- Arazi: grid tabanlı yükseklik + mesh/3D props (hibrit). Kaynak objeleri ve yapılar instanced; toprağın her hücresini serbestçe kazma zorunluluğu yok.
- Mağaralar: portal/entrance bağlanan ayrı map_id, katman ve kaynak düğümleri; istenirse içeride lokal breakable voxel.
- Dungeon: el-yapımı oda kitleri + seed tabanlı layout + kaydedilen tekil ödüller. Geçici mi kalıcı mı sorusu harita politikasında.
- Harita geçişi istemci ekranı değil, host onaylı transfer işlemi. Co-op oyuncuları aynı map instance'a girince aynı loot/state ile karşılaşmalı.
- Mini-map, navigation grid, occlusion ve hedefleme portre UX'de test edilmeli.

## Veri sözleşmesi taslağı (uygulama yok)
```
World { world_id, seed, save_version, map_catalog, player_records }
MapDefinition { map_id, map_type: overworld|cave|dungeon, seed, generator_version, height_policy, terrain_kind, persistence_policy, entrances }
MapInstance { map_instance_id, map_id, revision, loaded_regions, object_states, loot_claims, players_present }
Portal { portal_id, source_map_id, target_map_id, spawn_anchor, party_policy }
TerrainCell { x, z, height_index, terrain_id, flags }
WorldObject { instance_id, definition_id, map_instance_id, transform, component_state }
MapTransferCommand { command_id, player_id, portal_id, expected_map_revision }
```
Kimlik ayrımı: MapDefinition şablon, MapInstance kaydedilen gerçek durum; tekil dungeon seed'i ve loot yeniden girişte korunur. Disk/world dosyası ve network events kalıcı stable definition IDs kullanır; runtime integer refs diske yazılmaz.

## Riskler / karar deneyleri
- Ayrı haritalar yük/memory avantajı sağlayabilir ama geçiş ekranı, iki oyuncu ayrı maplarda iken host simülasyonu, kayıt ve transfer karmaşıklığı getirir.
- Yükseklik sınırı 0–8 sadece ilk prototip için aday; yol bulma, kamera görüşü ve inşa esnekliği test edilmeli.
- Surface 3D heightfield ile true voxel cave hibritinin görsel sürekliliği ve terrain collision test edilmeli.
- Tek dünya hissini korumak için harita girişleri fiziksel dünyadaki kapı/mağara ağzından tetiklenmeli.
- Dövüş şart değil; RPG derinliği üretim uzmanlığı, keşif ve hafif progression üzerinden verilebilir.
- Teknik kıyas: aynı içerik/saha boyutunda hibrit vs voxel; Android FPS, RAM, APK, sahne geçişi ve co-op sync ölçümü. Motor kararı bu deneyden bağımsız değil.

## Önerilen sonraki araştırma
1. 1 overworld, 1 cave, 1 dungeon (placeholder) + sabit portal ID ile haritalar arası geçiş
2. Yalın 3D terrain grid ve otomatik kaynak toplama
3. İki oyuncuda harita ayrışması, yeniden giriş, duplicate loot ve save migration testi

Kaynaklar: https://docs.godotengine.org/en/4.4/getting_started/step_by_step/instancing.html , https://corekeeper.atma.gg/en/World .
