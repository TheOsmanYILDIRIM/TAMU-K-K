# TAMU — 2D İzometrik Gölge Sistemi Araştırması

**Tarih:** 2026-11-03  
**Durum:** Araştırma ve mimari karar önerisi; henüz prototip/uyumluluk testi yapılmadı.  
**Kapsam:** Godot 4.6, 2D izometrik/2.5D dünya, Android hedefi.

## Mevcut sorunun özeti

Önceki özel gölge uygulamasında ağaç/kaya gölgelerinin bazı açılarda iyi görünmesine rağmen güneş yönü değiştikçe gölgenin dönmesi ve kısalıp uzaması görsel tutarlılığı bozuyor. Önceki değişiklikte ikinci Polygon2D gölge yolu kaldırılmış, alfa siluetli Sprite2D gölgesi bırakılmıştı. Bu sadeleştirme temel sorunu çözmüş sayılmıyor: projeksiyon geometrisi ve güneş parametrelerinin davranışı hâlâ istenen izometrik sanat yönetimine uymuyor.

## Araştırılan hazır Godot çözümleri

### 1. Gnomon — ilk incelenecek aday
- Ürün: https://csaf.itch.io/gnomon-godot
- Sprite alfa siluetinden gölge, farklı gölge stilleri/aileleri, güneş açısı ve uzunluğu kontrolü, AnimatedSprite2D ve Y-sort odaklı iş akışı olarak tanıtılıyor.
- Lite sürümü/ücretli sürüm ayrımı bulunuyor.
- **Doğrulanmamış:** Godot 4.6 uyumluluğu, lisans/ücret koşulları, Android Compatibility renderer davranışı ve cihaz FPS maliyeti. Kurulumdan önce güncel ürün sayfası ve paket içeriği kontrol edilmeli.

### 2. PixelLight 2D — ücretsiz alternatif
- Ürün: https://antahonist.itch.io/pixellight-2d
- Godot 2D ışıklandırma, sprite alfa/occluder tabanlı gölge ve izometrik demo yaklaşımı açısından incelenmeye değer.
- **Doğrulanmamış:** Güncel Godot 4.6 desteği, Android renderer uyumu, bakım durumu ve performans.

### 3. 2D Projected Ground Shadow
- Ürün: https://store.godotengine.org/asset/csocram/a2d-projected-ground-shadow/
- Raycast/zemin çarpışma noktalarından projeksiyonlu gölge geometrisi üretme yaklaşımı.
- **Risk:** Dinamik polygon üretimi ve fizik sorguları çok sayıda mob/obje için maliyetli olabilir. TAMU'nun statik/öngörülebilir gölge hedefiyle ölçülmeden kabul edilmemeli.

### 4. Lit
- Kaynak: https://github.com/shawndeprey/lit
- Cone-traced/raymarched/stochastic 2D ışık-gölge yaklaşımları.
- **Önemli kısıt:** Araştırma notunda Forward+ gereksinimi belirtilmiş; Android Compatibility/Mobile hedefi için uygunluğu varsayılmamalı. TAMU için ilk tercih değil.

## Godot yerleşik araçları

Godot'un DirectionalLight2D ve LightOccluder2D bileşenleri var. Yönlü 2D ışık/gölge sistemleri fiziksel ışık yaklaşımına yakındır; sonlu gölge uzunluğu ve yumuşaklık için renderer ve SDF ayarları/shader davranışı ayrıca değerlendirilmelidir. Bu sistemin izometrik sanat yönetimi için otomatik olarak doğru görsel sonucu vereceği varsayılmamalı.

## TAMU için sanat yönetimi önerisi

Fiziksel güneş simülasyonundan önce tutarlı, stilize zemin gölgesi hedeflenmeli:

- Tek bir global izometrik gölge yönü; kamera/eksen yönleriyle görsel olarak sabitlenmiş.
- Gündüz döngüsü ilk sürümde gölge açısını ve uzunluğunu değiştirmesin. İstenirse yalnız yoğunluk/rengin çok hafif değişimi.
- Obje türüne göre sabit uzunluk/ölçek profilleri: ağaç uzun, kaya kısa, ot/ufak nesne çok kısa veya yalnız temas gölgesi.
- Sprite alfa silueti korunmalı; ancak gölge sprite'ı zemine projekte edilirken taban/ayak temas noktası sabitlenmeli.
- Objeye yakın koyu ve küçük temas gölgesi (ambient/contact shadow) ile daha açık, yumuşak yönlü gölge katmanı ayrılabilir. Bunlar tek tutarlı ışık yönüyle hizalanmalı; çift, farklı açılı gölge gibi görünmemeli.
- Gölge kenarı yumuşaklığı ve opaklık sanat yönetimi parametreleri olmalı; aşırı blur/pixel art bulanıklığı engellenmeli.
- Aynı obje için birden fazla bağımsız gölge caster yolu çalışmamalı. Üst üste gelen gölgelerde aşırı kararmayı önle.

## Prototip ve kabul planı

Ana oyuna doğrudan eklenti entegre etme. Ayrı bir test sahnesinde aynı ağaç, kaya, ot ve hareketli karakter sprite'larıyla şu üç varyantı karşılaştır:

1. Gnomon (paket gerçekten 4.6 ile açılıyorsa).
2. PixelLight 2D veya projected-ground-shadow (renderer uyumu doğrulanırsa).
3. TAMU'ya özel basit projeksiyon: sabit yön + obje türü başına sabit uzunluk + alfa silueti + kontrollü yumuşatma.

Test matrisi:
- 4 izometrik gölge yönü ve farklı sprite boyutları.
- Zoom seviyeleri ve Y-sort/üst üste binme.
- Gün/gece boyunca gölge yönü/uzunluğunun sabitliği.
- Godot 4.6 headless parse/import, gerçek sahne screenshot karşılaştırması.
- Android hedef renderer'da gerçek cihaz FPS, GPU/CPU frame-time ve bellek.
- Gameplay, HUD, LÖVE kaynakları ve mevcut atlas/asset referansları değişmeden kalmalı.

Kabul ölçütleri:
- Gölge her yönde objenin zemine temas ettiği tabana bağlı kalır.
- Kamera izometrik yönüyle çelişen dönme veya beklenmedik kısalma/uzama yoktur.
- Obje başına yalnız tek tutarlı gölge silueti görünür; temas gölgesi varsa aynı yöne hizalıdır.
- Zoom değişiminde gölge titreme/yeniden üretim kaynaklı FPS düşüşü yapmaz.
- Godot 4.6 export/PCK ve Android cihaz testi ayrı ayrı geçer.

## Karar durumu

**Henüz eklenti seçilmedi ve ana oyuna yeni gölge kodu uygulanmadı.** İlk adım Gnomon'un güncel paketini ve lisansını inceleyip Godot 4.6 + Android renderer uyumluluğunu izole sahnede test etmektir. Uyumsuzsa PixelLight 2D ve özel sabit projeksiyon varyantı aynı test sahnesinde karşılaştırılmalıdır.
