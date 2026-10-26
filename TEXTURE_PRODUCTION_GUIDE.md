# Osman Oyun — Texture ve Nesne Görseli Üretim Rehberi

> **Kapsam:** LÖVE2D 45° izometrik, dikey mobil oyun için görsel üretim, Python işleme ve kabul. Bu belge **sanat/asset üretim yönergesidir**, oyun mantığı veya mevcut katalog/save sözleşmesini değiştirmez.
>
> **Kanonik stil:** `object-studio/src/catalog.js` içindeki `STYLE`; prompt aşamaları `object-studio/src/prompts.js`. MTS kaynak ilkeleri: `TheOsmanYILDIRIM/mineclonia-texture-studio/PROMPT_AUTHORING_GUIDE.md`. Bu dosyalarla çelişki olduğunda mevcut nesne üretim sözleşmesini ve oyun işlevini koru. Aşağıdaki küçültme/palet tercihleri Avenox Beyin `knowledge/oyun-grass-quantization-20261025.md` kaydındadır.

## 1. Ana tasarım dili — yalnızca “semi-realistic” değil

**MTS · Grounded Dark Fantasy**: grounded dark-fantasy material realism; **ancient, naturally weathered, somber, muted**, tactile, physically believable surfaces; soft diffuse lighting, low-to-medium contrast, restrained saturation, controlled environmental aging. **Semi-realistic**, bu sanat dilinin gerçekçilik düzeyini ifade eder, kendi başına stil tanımı değildir.

- Malzemeye özgü yaşlanma: yaşlı ağaçta kabuk çatlakları/liken, kayada mineral katmanları/erozyon, çimende hafif kuruma ve yer yer toprak. Uydurma süs/ışıltı yok.
- Büyük/orta formların mobil oyun mesafesinde okunurluğu, mikrodetaydan önce gelir. Her pikseli küçük yaprak, tane, çizik veya yüksek frekanslı gürültüyle doldurma.
- Bastırılmış, tutarlı renk aileleri; açık-koyu ilişkisi okunaklı, kontrast düşük-orta. Malzemeyi düz tek renge indirgeme.
- Kaçın: **pixel art**, büyütülmüş kare pikseller, voxel/kübik yüzey lekeleri, cartoon shading, aşırı fotoğrafik noise, sert baked ışık, yapay derin kabartma, aşırı doygunluk, plastik parlaklık ve stock-photo etkisi.
- Çıktıyı **gerçek hedef oyun ölçeğinde** kontrol et. Büyük resmin çekiciliği tek başına kabul ölçütü değildir.

## 2. Üretim isteği / prompt kuralları

1. Her varlık için **ayrı, bağımsız kaynak görsel** iste; kolaj, sunum, atlas/poster, yazı, 3×3 demo, etiket ve UI isteme. Birden çok çıktı istiyorsan nesnelerin isim/rol eşlemesini üretim kaydında ayrı tut. Görseli poster içinden kırpıp gerçek üretim kaynağı sayma.
2. Modelden doğrudan `128×128`, “low-res sprite” veya “pixelated” talep etme: **yüksek çözünürlüklü** üret, son oyun ölçeği Python işleme aşamasında uygulanır.
3. Her promptta **tam kanonik ana stil + malzemeye özgü içerik + teknik işlev + kaçınılacaklar** bulunmalı; yalnız “semi-realistic” yazma.
4. Zemin texture’ı: tam üstten/ortografik yüzey, sabit malzeme ölçeği, gölge/perspektif/objeye dönüşen büyük odak öğesi yok; **karşılıklı dört kenarda kesintisiz döşenebilir (seamless/tileable)** hedefi belirt. Üretilmiş görselin gerçekten dikişsiz olduğu varsayılmaz.
5. Ayrı duran ağaç/çalı/kaya: 45° izometrik yönle tutarlı tek obje; baştan sona görünür siluet, ayak/pivot referansı, **gerçek RGBA alpha**, gölgesiz, sahnesiz ve zeminsiz. Gerekirse `object-studio` akışındaki creative → Image A yalnız geometri / Image B stil referansı correction aşamasını kullan.
6. MTS'den gelen **UV atlas / foliage alpha mask / runtime tint / tiling** gibi teknik roller yeni oyunun sprite/zemin varlığıyla karıştırılmamalı. Mevcut varlığın gameplay işlevi ve yapısal kimliği dekorasyondan üstündür.

### Örnek: yeni çimen ana promptu (yüksek çözünürlüklü kaynak)

> Create **one standalone top-down seamless ground material texture** for a 45-degree isometric survival game's terrain. Art direction: **grounded dark-fantasy material realism**, semi-realistic, ancient and naturally weathered, somber muted colors, tactile physically believable grass and soil, restrained saturation, soft diffuse ambient lighting, low-to-medium contrast. Natural medium/large-scale clumps and readable earth/vegetation balance, sparse small accents, controlled weathering; avoid dense micro-noise and excessive individual blades. Preserve a consistent world material scale and continuous detail across all four opposite edges. Flat orthographic surface, no horizon, scene, framing, decorative props, isolated objects, text, shadow, normal-map illusion, pixel art, enlarged pixels, cartoon strokes, voxel noise, glossy surfaces or photographic grain. Output **only the texture image**, no poster, contact sheet or demonstration grid.

Varyant ekleri `meadow` (açık çayır/kuru-yeşil dengesi), `forest` (daha yaşlı, nemli, gölgeli/likenli), `rocky` (seyrek ot, soğuk mineral yüzey) olarak **malzeme ölçeğini değiştirmeden** uygulanır. `grass_meadow_0/1`, `grass_forest_0/1`, `grass_rocky_0/1` altı **mevcut asset slotudur**; biyom ve varyant isimlerini kaynak görsele bakarak eşleştir. “Çiçekli” görünümü ayrı onaylanmadan belirli slotla özdeşleştirme.

## 3. Python işleme — çimen için onaylanan varsayılan

**Kaynak:** her texture'ın ayrı büyük RGB/RGBA PNG'si. Hedef: `128×128` PNG, en fazla/tercihen **64 görünür RGB renk**, **CIELAB (Lab) K-means** renk indirgeme, **dithering kapalı**.

1. Orijinal yüksek çözünürlüklü PNG'yi **değiştirmeden koru**; kaynak adını ve SHA-256'sını manifestte tut. Yalnız işlenmiş çıktılar istendiğinde teslim ZIP’ine kaynakları koyma.
2. Kaynak materyali incele: rol, görüntü ölçüsü, alfa kanalı, renk profili, ölçek, döşeme veya siluet ihtiyacı. RGB'yi sRGB olarak işle; gömülü ICC varsa açıkça dönüştür. Aşırı ayrıntıyı palette zorlamak yerine kaynak/prompta geri dön.
3. Zemin: görseli **Pillow `Image.Resampling.LANCZOS`** ile `128×128` küçült. RGBA objelerde kenar halelerini önlemek için premultiplied-alpha mantığına dikkat et; RGB siyah arka planı “alpha” kabul etme. Obje boyutlandırırken siluet/yerleşimi koru, kırpma varsayma.
4. Dikişsizliği **palet indirgemesinden önce** kontrol et. Karşılıklı kenar farkını ölç; 3×3 döşemeyi hem kaynak boyutunda hem hedef boyutunda gör. Gerekiyorsa `offset` (yarım boy yatay+dikey wrap), merkezi dikişte kontrollü compositing/clone/heal uygula; ardından kenar ve motif tekrarlarını tekrar kontrol et. **Yalnız son piksel sütun/satırını eşitlemek veya kenarı bulanıklaştırmak kusursuz tileable kanıtı değildir.**
5. `128×128` sRGB piksellerini CIELAB'a dönüştür; sabit `random_state` ve belgelenmiş parametrelerle 64 kümeli K-means uygula. Küme merkezlerini sRGB'ye geri dönüştür; `uint8` çıktıda **gerçek farklı RGB renk sayısını ölç**. Dithering kullanma; ölçüm/önizlemede gereksiz gürültüyü arttırabilir.
6. Beyaz/sarı çiçek gibi küçük önemli bölgeler palette kayboluyorsa yeniden üretimi veya ayrı *ağırlıklandırılmış* renk korunması denemesini değerlendir; bu yöntem **henüz standart/onaylanmış değil**.
7. Nihai PNG'leri `grass_<biome>_<index>.png` adlarıyla çıkar; görünümün slotla **gerçekten eşleştiğini görsel kontrol et**. Belirsiz çiçekli/kayalık isimlerini otomatik tahmin edip yeniden adlandırma.

Örnek çekirdek yaklaşım (bağımsız program değil; hata, renk profili ve alpha kontrolleri eklenmelidir):

```python
from PIL import Image
import numpy as np
from sklearn.cluster import KMeans
from skimage.color import rgb2lab, lab2rgb

img = Image.open("source.png").convert("RGB").resize(
    (128, 128), Image.Resampling.LANCZOS
)
rgb = np.asarray(img, dtype=np.float32) / 255.0
lab = rgb2lab(rgb).reshape(-1, 3)
km = KMeans(n_clusters=64, random_state=42, n_init=10)
ids = km.fit_predict(lab)
centers = np.clip(
    np.rint(lab2rgb(km.cluster_centers_.reshape(1, 64, 3))[0] * 255),
    0, 255
).astype(np.uint8)
pixels = centers[ids].reshape(128, 128, 3)
out = Image.fromarray(pixels, "RGB")
out.save("candidate.png")
print("colors:", len(np.unique(pixels.reshape(-1, 3), axis=0)))
```

Bu örnek **tileable düzeltmesi yapmaz**. Çimen için 64 RGB renk sınırıdır; alpha içeren nesne PNG'lerinde alpha korunması ve görsel palet/şeffaflık ilişkisi ayrıca doğrulanmalıdır.

## 4. Kalite kapıları ve teslim

- **Doğrula:** PNG gerçekten açılıyor, doğru sRGB/RGBA rolünde, boyut `128×128` (zemin hedefi), gerçek benzersiz RGB renk `<=64`, adı ve biyomu doğru, PNG kaynak/çıktı SHA-256 kayıtlı.
- **Dikiş kontrolü:** karşılıklı kenar piksel kıyası, renk/siluet devamlılığı ve **3×3 büyük motif tekrarı**; piksel eşitliği tek başına sanatsal kabul değildir.
- **Görsel kontrol:** orijinal yüksek çözünürlüklü kaynak, `128×128` işlenmiş sürüm ve doğal oyun ölçüsü aynı ortamda karşılaştırılır; aşırı blur, keskinlik haleleri, karanlıkta detay kaybı ve gürültü incelenir.
- **Manuel kabul:** asset yönü/alpha/pivot/dikişler/biome uyumu kullanıcı tarafından onaylanmadan “nihai” veya “oyunda doğrulandı” deme.
- **Teslim:** Her dosya bağımsız; PNG adları, parametreler, giriş-çıkış hash, renk ölçümleri ve kabul durumu `manifest.json` içinde. ZIP yalnız istenen işlenmiş görselleri ve gerekiyorsa ayrı 3×3 önizlemeleri içersin. ZIP’i açıp üyeleri ve CRC/bütünlüğü doğrula.
- **GitHub:** Mevcut `game/love/assets/` PNG, save, kullanıcı verisi, backup ve performans dallarını koru. Yeni adayları izinli dalda dene; onaydan önce mevcut production texture üzerine sessizce yazma. GitHub commit/HEAD/asset geri okuması, CI, LÖVE görsel smoke ve gerçek Android testi **farklı doğrulamalardır**.

## 5. Önceki denemelerin hata dersleri

- GPT Image bir **sunum/contact sheet** üretebilir; üzerinde “64 renk” yazması **gerçek piksellerin 64 renk olduğu** anlamına gelmez. Bağımsız görseli üret, palette/sizesı Python ile ölç.
- Sunumdan 177×177 kutu kırpılması gerçek yüksek çözünürlüklü kaynak üretimi değildir.
- “128×128 sprite” vurgusu görseli istemeden pixel-art'a kaydırabilir; **kaynak promptunda yüksek çözünürlüklü semi-realistic grounded dark-fantasy** dilini koru.
- `grass_meadow_1` gibi isimleri görsel doğrulama olmadan “çiçekli” sayma; çiçekli ile taşlı karışıklığı yaşandı. Entegrasyondan önce ayrı gözle denetle.
- Kesin dikişsizliği GPT Image'ın iddiasından veya kenar metriklerinden çıkarma. 3×3 tekrar görünümü ve gerekiyorsa manuel rötuş şart.

Bu rehber, texture ailesini çoğaltmak için bir **karar/kabul sözleşmesidir**, otomatik oyun entegrasyonu veya henüz yapılmamış testlerin başarı beyanı değildir.

## 6. Test edilmiş yardımcı Python aracı (2026-10-26)

Kod: [`scripts/texture_prepare.py`](scripts/texture_prepare.py). Bağımlılıklar: `pillow`, `numpy`, `scikit-learn`, `scikit-image` (örn. `python -m pip install pillow numpy scikit-learn scikit-image`). Aracı kaynak dosyadan ayrı çıktı yoluyla kullan:

```sh
python scripts/texture_prepare.py source_grass.png grass_meadow_0.png --kind ground
python scripts/texture_prepare.py source_tree.png T-01_candidate.png --kind object --size 256
```

- Zemin varsayılanı: 128×128 LANCZOS, Lab K-means (64 renk üst sınır, `random_state=42`, `n_init=10`, dithering yok), sRGB PNG, SHA-256 içeren `*.manifest.json` ve `*_tile_preview.png` (3×3) çıktısı.
- Obje: gerçek RGBA girdisi zorunlu; alfa tahmin edilmez. Premultiplied-alpha mantığıyla LANCZOS boyutlandırma, oranı koruma, kare tuvale alt-orta pivotla yerleştirme ve yalnız görünür RGB piksellerini en fazla 64 renge indirme uygular. `--size 256` sadece obje için **aday** bir değerdir, onaylı oyun ölçüsü değildir.
- ICC varsa sRGB'ye dönüştürür; ICC yoksa sRGB varsayımını manifestte kaydeder. Kaynak dosyayı değiştirmez, aynı isimli çıktı üzerine yazmayı reddeder. **Seam tespit metrikleri ve 3×3 önizleme vardır; otomatik dikiş düzeltme yoktur.** Dikişsizliği metrikler değil manuel görsel kabul belirler.
- 2026-10-26 sentetik kontrolü: 256×256 RGB zemin ve rastgele alfa içeren 256×256 RGBA obje girdilerinden 128×128 çıktı alındı; dosyalar yeniden açıldı, ikisinde de 64 görünür RGB renk ölçüldü, obje alfa değerleri 0–244 aralığında korundu. Python sözdizimi kontrol edildi. Bu sentetik test; gerçek üretim görseli, oyun içi smoke, CI veya Android cihaz kabulü değildir.
- GPT Image için 7 mevcut obje (T-01/02/03, R-01/02/03/04) ve 6 çimen slotu ayrı bağımsız kaynak promptları olarak hazırlanmıştır; gerçek image üretimi ve oyuna entegrasyon **henüz yapılmadı**. Mevcut production texture dosyalarına dokunulmaz.


## 7. T-01 onayı ve standart sunum protokolü (2026-10-26)

- Kullanıcı, `T-01 — Yaşlı geniş yapraklı` için önceki MTS Grounded Dark Fantasy malzemesini koruyan, daha yukarıdan görülen izometrik **yüksek çözünürlüklü kaynak görseli** ve izometrik grid üzerinde yapılan görsel sunumu kabul etti. Kaynak üretim görseli, 1254×1254 RGBA PNG; kaynak SHA-256: `2153e7223010a53ae1476916ce54b9e0ff38931b83480e6d095f8e9cad3010bd`. Bu, **görsel kaynak onayıdır**; izometrik kamera açısının matematiksel ispatı veya oyun içi render kabulü değildir.
- Kaynağın ayrı bir kopyası, mevcut `scripts/texture_prepare.py` algoritmasıyla `--kind object --size 128 --colors 64 --seed 42` kullanılarak işlenmiş **aday** haline getirildi. Çıktı: `T-01_candidate_128x128_64c.png`, 128×128 RGBA, 64 görünür benzersiz RGB renk, dithering kapalı, ön-çarpımlı alfa/Lanczos, Lab K-means (`n_init=10`). Çıktı SHA-256: `b5606b648f5890d4082eaef33e6002a1ddfcbb099b0e7370f7c238ca320643e0`. Ölçüm PNG yeniden okunarak yapıldı; kaynak değiştirilmedi. Çıktı **henüz ayrıca kullanıcı tarafından onaylanmadı**, production asset olarak commit edilmedi.
- Onay sunumu **gerçek işlenmiş PNG** üzerinden izometrik 2:1 grid üzerinde, doğal oyun mesafesiyle birlikte gösterilir. Sunumdaki büyütme yönteminin yalnız önizleme olduğu açıkça belirtilir. Her asset için kaynak / işlenmiş aday statüsü, tam piksel ölçüsü, gerçek görünür RGB renk sayısı, alfa, SHA-256/manifest ve production'a yazılma durumu belirtilir. Bir sunum çizimi üretim PNG'sinin yerini alamaz.
- Önce kullanıcı **kaynak görseli**, sonra **işlenmiş adayın grid ve oyun ölçeğindeki görünümünü** ayrı kabul eder; ikisi olmadan production asset'i değiştirme. Doğal ağaç siluetiyle salt PNG'den tam 45° azimut / 35,264° ortografik kamera açısı matematiksel olarak doğrulanamaz. Bu kontrol için gerçek 3D geometri/kamera veya bilinen referans eksenleri gerekir.
- İşlenmiş PNG ve manifest bu oturumda yerel teslimdir; **GitHub'a production görseli yüklenmedi**. Kaynağın, adayın ve manifestin kalıcı asset depolaması ve gerçek LÖVE/Android oyun testleri ayrıca açık kalır.
