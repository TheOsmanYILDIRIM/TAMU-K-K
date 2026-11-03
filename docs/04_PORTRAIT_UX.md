# Dikey ekran UX sözleşmesi

**Öncelik:** Android dokunmatik kullanım, 9:16, 19.5:9, 20:9. Referans logical layout: 720×1280 px, dp değil. İlk fiziksel cihaz testi 320–360dp ve 392–411dp ile 1.3× font.

## Yerleşim (ihtiyaç, sabit piksel değil)
- Üst şerit (safe-area altında): oyuncu/dünya, bağlı arkadaş, saat ve küçük sistem durumu.
- Orta ~%55–65: 3D çevre ve hedefler; parmakla kapatmayan otomatik hedef vurgusu; yüksek kamerayla ön/arka görünürlük.
- Alt 1/3: tek elle erişilebilir konumda tek ana aksiyon, iş listesi, envanter/crafting erişimi.
- Modal olarak açılan crafting paneli dünyayı tümden gizlemek zorunda değil; yarım sayfa (bottom sheet) + kaydırma.
- Özelleştirilebilir sol/sağ el, UI ölçeği, titreşim, joystick tercihi; alanları gelecekte save settings şemasında.

## Dokunma durumu
Tap: dünya raycast → erişilebilir hedef → context action + nav job. Drag: kamera orbit veya pan. Uzun bas: obje detayı. Pinch: zoom. UI parmağı dünya hareketini tetiklemez. Çoklu parmak `index` izlenir, gameplay ile pinch çakışmaz.

## Kamera
Orthographic 3D, 35.264° eğim referansı (izometrik hissi), 45° yaw; kullanıcı 90° orbit tuşu. Çatı/duvar oyuncuyu gizlerse fade veya cutaway; zemindeki hedef ikonları perspektif sabitleme. Oyun mekaniği açı değişse de değişmez.

## Android özel
Android 15 edge-to-edge/kesik ve jest çubuğu için safe-area padding; kesin sabit margin yasak. HUD input alanları sistem gesture bölgelerine uzanmamalı.
Godot `DisplayServer.get_display_safe_area()` API ve Android insets gerçek cihazda kontrol edilecek; yalnız dokümantasyonla çalışıyor sayma.

## Test senaryoları
1. Üstte çentik + altta gesture bar → buton gizlenmez.
2. Sağ/sol el + iki parmak pinch → kazma tetiklenmez.
3. 10 dakika iki oyuncu, birinde crafting paneli açıkken diğerinde hareket.
4. 1.3× metin, localization TR/EN ve dar 320dp viewport → metin kırpılmaz.
5. Kısa 9:16 ve uzun 20:9 telefon → ana eylem sabit ekranda erişilebilir.
