# Core Crystal Pulse V3 — shader işi ve doğrulanmış görsel teslimler

Tarih: 2026-10-16. Ana tasarım: [21_CORE_PLASMA_MTS_ART_FX_PIPELINE.md](21_CORE_PLASMA_MTS_ART_FX_PIPELINE.md).

## Karar
Kullanıcının onayladığı Core için **tek base model PNG + tek hizalanmış shader maskesi + canlı LÖVE2D shader** tercih edildi. Shader yalnız kristalde pulse, merkezden dışa azalan enerji, yumuşak feather sınırları, küçük zamansal edge noise ve screen ağırlıklı/ölçülü additive karışım üretir. Metal shell ve önündeki fiziksel bar sabit ve etkilenmez. Oyuncu core'unun konumu/foot/Y-depth/collider/world kamera sözleşmesi korunur. Gerekirse gerçek mobil testle gerekçelendirilen *opsiyonel* küçük spritesheet fallback; bu aşamada spritesheet üretimi şart değildir. V3 görünümü onaylandı; uzun karakter rig/video animasyonuna geri dönülmeyecek.

## Üretilmiş dosyaların doğrulanmış yerel örnekleri
Dosyalar ChatGPT sohbetinde container çıktısıdır; **bu deney dalına Git binary dosyaları olarak henüz aktarılmadı**. Repo bağlantısı veya commit varmış gibi kullanma. Yeniden uygulamada aşağıdaki hash ile kontrol et.

| Dosya | Boyut | İçerik | SHA-256 |
|---|---|---|---|
| 121222.png | 1254x1254 RGBA | GPT Image A onaylı MTS metal Core master | 2c63bc1645ab1718e8f612f17a8821ed4f22cd557ffd66c2e506e8d46d2dcf0b |
| core_crystal_mask_aligned.png | 1254x1254 RGBA | Kristal/hazne hizalı binary maske, yalnız kristal yüzeyi değil | b718d0cab981f23d8334a868e268d45535fac61292af8d34733120999161f55b |
| core_crystal_pulse_v3.gif | 1254x1254, 32 frame | V3 animasyon önizleme; oynanış varlığı değildir | 3c1220b32c06de9f325dedbf8d36bd5dc263582325af5aa35beea8b65e11f28d |
| core_crystal_pulse_v3_peak.png | 1254x1254 RGBA | V3 en yüksek ışık referans karesi | c5eee221b0f048c54710b3f587e613d10ca9caa4df2b07a0a34016a2cdc1a40b |

V3 GIF, yalnız görsel referans niteliğinde Python/Pillow önizlemesi: Core original sabit, tek maske, iç merkez radial falloff, pulse loop, soft feather, animated edge noise ve screen/additive karışımı. Bu bir LÖVE shader testi veya cihaz performans kanıtı değildir. Maskenin kristal dışı hazne pikselleri de içermesi bilinçli açık kusurdur; shader maskeyi frame-to-frame sabit kullanmalı, metali etkilememeli. Üretim kabulü için gerekirse daraltılır.

## Bağımsız küçük LÖVE shader kapsamı (İş A / takip)
1. Görselleri binary olarak güvenilir yöntemle **AGENTS.md dal seçimi ilkesine göre uygun dala** al; dosya hash, alpha, mask boyutu kontrol et. Kullanıcı referansına erişilemiyorsa dosyayı iste; sıfırdan Core çizme.
2. `game/love/player/` içinde ayrı shader modülü; sabit base texel `121222.png` + maske. Tek ek texture sample, zaman uniformu; `mask` aliası, radial merkez ve yarıçapı pixel/UV koordinatlarında ölç ve belgele. Metal bar masked-off; maske gerekirse düzelt.
3. Efekt: ortadaki parlaklığı V3 düzeyinde tut, dışarı doğru azaltsın; Gaussian edge feather shader/mask preprocess ile; küçük animasyonlu noise; crystal-screen + düşük additive katkı. Shader renk karışımının LÖVE premultiplied/straight-alpha `setBlendMode` sözleşmesiyle uyumunu kanıtla, çift glow yok.
4. Mevcut `core_visual.lua` ve `objects/renderer.lua` içinde yalnız render adaptation; action/tool, movement, physics, depth, Stage5/6 save kapsamına dokunma. Unavailable shader için basit Core PNG fallback; optimize spritesheet ancak gerekli ölçüm çıkarsa.
5. Lua5.4/LuaJIT ve gerçek Xvfb/LÖVE screenshot testleri, 320/360 dp ölçek görsel okuma, mask passthrough ve metal pixel invariant kontrolü. FPS/RAM cihaz testini yapmadan başarı iddia etme.
6. CI ve HEAD'i kapsam/risk kadar doğrula; aynı kanıtı gereksiz tekrar üretme, yeni dalı yalnız gerekçeli riskte aç. Paylaşılmış dal üzerindeki diğer ajanların yazdığı dosyaları ezme. Beyin `oyun-core-plasma-art-assets-20261016` görevini ve revision değişimlerini resmî beyin-io üzerinden yönet.

## Sıradaki ayrı işler
Metal araçlar her biri tek rigid alpha PNG; matematiksel kavis/rotasyon. Ortak swing/strike/craft/build/plasma FX, gerektiğinde GPT Image key refs -> koşullu Veo 3.1 -> video-to-sprite, runtime video bağımlılığı olmadan. Stat paleti, seviyeler, özel güçler kesinleştirilmedi.
