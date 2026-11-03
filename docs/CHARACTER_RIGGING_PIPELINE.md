# TAMU Karakter / Yaratık Rig Atlası Hazırlama Rehberi

Bu rehber, insan karakterleri ve organik yaratıkları aynı 2D rig hazırlama hattına sokmak için kullanılır. Temel ilke: **önce mevcut çizimi anatomik olarak ayır, sonra yalnız eksik bağlantı dokularını tamamla; ana görseli veya atlas yerleşimini yeniden üretme.**

## 1. Girdi sözleşmesi

Her varlık için iki görsel rolü ayrı tutulur:

- **Düzenleme hedefi (atlas):** Önceden kesilmiş, parçaları ayrı ve aralarında boşluk bulunan tek PNG. GPT Image'a düzenlenecek ana görsel olarak ilk bu verilir.
- **Anatomik referans:** Karakterin/yaratığın tam, birleşik orijinal görünümü. Yalnız anatomi, renk, doku ve örtüşme ilişkisini anlamak için ikinci referans olarak verilir.

Bir atlas yoksa önce segmentasyon yapılır. Kaynak tam görseli doğrudan "parçaları tamamla" aşamasına sokma; model bunu yeniden tasarlayıp keyfî biçimde bölebilir.

## 2. Segmentasyon

1. Kaynak görselin açısını ve rig hedefini sabitle: oyun kamerası ile uyumlu profil/3-4 görünüm, nötr ve eklemleri okunur poz.
2. Anatomik parçaları önceden listele. İnsan için baş, saç/sakal, gövde, üst-alt kol, el, üst-alt bacak, ayak ve kıyafet katmanları; dört ayaklı yaratık için gövde, baş, kulaklar, kuyruk ve yakın/uzak ön-arka bacaklar başlangıç şemasıdır. Modelin anatomisine göre listeyi değiştir; gereksiz uzuv üretme.
3. MobileSAM ViT-T CPU gibi erişilebilir segmentasyon modeliyle maske adayları çıkar. SAM maskesi nihai anatomi değildir: yakın/uzak uzuv karışması, arka plan sızıntısı ve gövdeyle birleşen köklerde elle kontrol gerekir.
4. Her parça için RGBA PNG ve ayrı maske üret; kaynak çözünürlüğü ve koordinatları manifestte sakla.
5. Parçaları kırpıp kaydederken orijinal atlas üzerindeki sol-üst koordinat ofsetini koru. Rig editöründe parçaları aynı noktaya geri yerleştirmek için `offset`, kaynak canvas ölçüsü ve pivot/eklem konumları kaydedilmelidir.

## 3. GPT Image ile eksik bölgeleri tamamlama

**GPT Image'a yeniden segmentasyon yaptırma.** İlk görsel her zaman mevcut parçalı atlas, ikinci görsel tam karakter referansı olmalı.

Düzenleme talimatı:
- Yalnız mevcut atlası düzenle; yeni atlas veya birleşik karakter üretme.
- Parçaların konumu, ölçeği, yönü, aralarındaki boşluk, canvas boyutu ve sağlam pikselleri kilitli tut.
- Yalnız maske kesiminde kaybolan alanları, kopuk kenarları ve eklem altına gizlenecek anatomik devamları tamamla.
- Omuz/kalça, boyun, kulak kökü, kuyruk kökü, dirsek/diz ve bilek bağlantılarında dönme sırasında boşluk açılmayacak kadar örtüşme payı bırak.
- Yakın/uzak tarafları karıştırma; yeni uzuv veya aksesuar ekleme.
- Tüy, kürk, deri, kumaş ve yüzey desenini kaynakla eşleştir.
- Sonuç tek şeffaf RGBA PNG atlas olmalı; etiket, gölge, zemin, grid veya dekor eklenmemeli.

GPT Image piksel hizalamasını garanti etmez. Çıktı alındıktan sonra önceki atlasla piksel farkı/overlay karşılaştırması yapılır. Değişmemesi gereken parçalar kaynak atlas üzerinden korunur; yalnız tamamlama yapılan bölgeler aktarılır. Ölçek ve konum kritikse tüm çıktı körlemesine kabul edilmez.

## 4. Rig'e hazırlık kalite kapısı

- Her parça ayrı ve gerçekten şeffaf mı?
- Kaynak atlas koordinatına geri yerleştirildiğinde tam karakter silueti kapanıyor mu?
- Eklemlerde döndürme için yeterli örtüşme var mı?
- Yakın ve uzak uzuvlar ayrı mı; yanlış uzuvdan piksel çalınmış mı?
- Parça maskeleri arasında açıklanamayan boşluk veya çakışma var mı?
- Tüm parçalar aynı kaynak ölçeğini ve açı perspektifini koruyor mu?
- Pivotlar anatomik eklem merkezlerine yerleştirilebilir mi?
- PNG'ler RGBA ve alfa kanalları dolu mu?

Bu kapı geçilmeden otomatik rig/animasyon üretimine geçme. Özellikle gizli anatomi segmentasyonla geri kazanılamaz; referanstan kontrollü tamamlanmalı.

## 5. Paketleme ve boyut kontrolü

- Her parçayı tam kaynak canvas boyutunda tekrar tekrar saklama. Şeffaf bounding-box'a göre kırp; kaynak koordinat ofsetini JSON manifestte sakla.
- Orijinal kaynak, final atlas, maske ve preview dosyalarını ayrı adlandır; aynı ZIP'i kendi içine koyma.
- Tek teslim ZIP'inde yalnız gerekli PNG'ler, manifest, gerekirse preview ve kısa README bulunsun.
- Paketlemeden önce dosya boyutlarını, PNG boyutlarını ve ZIP içeriğini listele; açıp CRC/test doğrulaması yap.
- Kaynak görsel 2.5 MB ise dokuz tam boy RGBA PNG'nin toplamının bunun birkaç katına çıkması normaldir; her maske ayrı tam canvas olarak saklanırsa şişme artar. Crop + offset ve optimize PNG ile tekrarları azalt.

## 6. Önerilen çıktı düzeni

```text
<creature_or_character>/
  source/
    original.png
  atlas/
    rig_atlas.png
    manifest.json
  parts/
    torso.png
    head.png
    ...
  masks/
    torso_mask.png
    ...
  review/
    overlay.png
    contact_sheet.png
  delivery/
    <name>_rig_parts.zip
```

Projede mevcut klasör/isim sözleşmesi varsa bu örneği kopyalama; mevcut düzeni koru.

## 7. İnsan ve yaratık farkları

- Humanoid: omuz/dirsek/bilek, kalça/diz/ayak bileği zincirleri; kıyafet katmanları ve saç/sakal ikincil katmanlar olabilir.
- Dört ayaklı: omuz ve kalça kökleri, dirsek/karpal ve diz/ayak bileği eklemleri; ön/arka ve yakın/uzak bacakları ayrı tut. Kuyruk ve kulaklar ikincil kemik zinciri olabilir.
- Kanatlı: kanat kökü, ana kol/ön kol ve primer sekonder tüy grupları; tüm tüyleri tek tek kesmek yerine animasyon gereksinimine göre gruplandır.
- Özel anatomi: serbest parça listesi kullan; insan iskeletini zorla uygulama.

## 8. Doğrulama kaydı

Her üretimde kaynak SHA-256, model/sürüm, maske yöntemi, canvas ölçüsü, parça adları, bounding box/pivot/offset, PNG dosya boyutları, ZIP CRC ve görsel inceleme sonucu kaydedilmelidir. Otomatik maske çıktısı "rig-ready" sayılmaz; rig-ready kararı görsel ve eklem örtüşme kontrolünden sonra verilir.
