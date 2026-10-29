# TAMU Osman — canlı iskelet karakteri
**Durum:** Main kaynaklarına 30 orijinal PNG parçası, 44 seyrek anahtar-kareli klip, 40 kemik ve 24 slot aktarıldı. PNG'ler animasyon spritesheet'i değildir; 2D iskelet mesh'leri GPU üzerinde canlı deformasyonla çizilir.

Kaynak: kullanıcı onaylı `osman_saglak_4yon_v5.rigby`, SHA-256 `86ed6aa3e40a082b9f7b67e9074a2d3b1149facb9c785a9e44956397ab22ad92`. `provenance.json` her orijinal parça görselinin SHA256 değerini içerir.

**Varsayılan çizim:** `player/rigby_visual.lua` ve `player/rigby_runtime.lua`; R2 + kompakt atlaslı 2.5D dünya `main.lua` tarafından yüklenir. Dört izometrik yön, sağ el soketi `right_hand` API'sinde. Eşyalar henüz modele eklenmedi. Eski plazma sistemi `TAMU_USE_PLASMA=1` ile etkinleştirilebilir; tüm plazma kaynakları korunur.

Sınırlar: `tamu-rigby-fk/1` yalnız FK kemikler, eğri enterpolasyonu, region/weighted mesh destekler; mevcut 44 klipte IK karışımları sıfırlanmıştır. Yeni aktif IK/deform tipleri otomatik kabul edilmez. R2 geçici oturum dünyasıdır; Stage6 kaydına bağlı değildir. Gerçek Android cihaz FPS/görsel testi açık kabul maddesidir.
