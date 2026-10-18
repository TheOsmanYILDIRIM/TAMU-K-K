# Crafting ve Blueprint Keşfi — Tasarım Defteri

> 2026-10-18 | Durum: TASARIM. **En güncel tarama/üretim ve Tech-Magic kararları için sondaki «Kullanılabilirlik ve Ustalık» bölümünü esas al.** Önceki eşik, malzemeyi tam tanıma ve tam Tech/Magic eşdeğerliği varsayımları tarihsel önerilerdir.
> Repo: TheOsmanYILDIRIM/oyun | Dal: experiment/crafting-discovery-design-20261018
> Başlangıç main: decc19e7a4d7e6eda4f33631672932c184737966
> Beyin görevi: oyun-crafting-blueprint-discovery-design-20261018
> Bu belge kod, kayıt şeması veya mevcut oyun kuralları değildir.
> **Güncel ortak Core/Skill/Item/Obje/Bina standardı:** [26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md](26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md). Skill edinme, kullanım XP'si, pahalı silme ve Core kapasitesi hakkındaki yeni kararlar bu RFC'de; önceki skill sınırı sorusu tarihsel kalmıştır.

## Kullanıcıyla üzerinde uzlaşılan yön

- **B — Dengeli keşif, hayatta kalma, üretim ve inşa** temel oynanış yönüdür; başlangıç oyunu bir fabrika simülasyonu olmayacak.
- İleride bazı **moblar veya robotlar otomasyona** katkıda bulunabilecek; otomasyon keşif hissini ortadan kaldırmamalı.
- Oyuncu blueprint **bulabilmeli**, nesne/makine **analiziyle öğrenebilmeli** ve **kendi deneyleriyle icat edebilmeli**.
- İlk kez öğrenme güçlü **keşif/buluş hissi** vermeli. Bir kez öğrenilen tarifin sonraki üretimleri **kolay ve hızlı** olmalı; aynı bulmaca tekrar edilmemeli.
- Geleneksel **3×3 / dokuz hücreli crafting grid** yerine, malzemelerin işlevi, davranışı ve dünyadaki neden-sonuç bağlarına dayalı bir oyun mekaniği aranıyor.
- Oyuncu, insan değil, **metal büyülü-teknolojik Core ve kontrollü plazma**. Mekanik bu özgün karakter tasarımıyla anlamlı biçimde bütünleşmeli.
- Daha önce olumlu karşılanan üst düzey fikirler: eşya blueprint'i, kademeli/çok parçalı inşa blueprint'i, ileride davranış blueprint'i; plazma ile saydam yapı projeksiyonu, aşamalı malzeme teslimi, oyuncunun yapılarını plan olarak saklaması; modüler ürün geliştirme, alt-üretim zincirleri, harabe analizi, ileride öğrenilen planların robot/moblara atanması. **Ayrıntılı etkileşim, denge ve teknik sınırlar henüz karara bağlanmadı.**

## Önceki keşif alternatifleri (tarihsel: B + C birleşimi seçildi)

### A. Madde Yankıları — Dünya gözlemi
Core, yağmurda iletkenleşen taş, harabedeki titreşim veya mob davranışının ardındaki malzeme/enerji ilişkilerini algılar. Oyuncu ipucunu dünyada takip eder; yalnız taramaya basmak yetmez.
- Güçlü: Arazi keşfine gerçek değer katar.
- Risk: İpuçları fazla gizliyse rastgele dolaşma ve tekrarlı grind olur.

### B. Plazma Deney Alanı — Maddeyle etkileşim
Birkaç malzeme Core çevresinde askıda durur. Oyuncu `bağla`, `ayır`, `ilet`, `ısıt`, `soğut` gibi sınırlı işlemler uygular, gözlenebilir tepkiler alır.
- Güçlü: Oyuncu gerçekten icat yapmış hisseder; Core'a özgü.
- Risk: Tam fizik simülasyonu pahalıdır; her crafting'de mini oyun zorunluluğundan kaçınılmalıdır.

### C. İşlev Devreleri — Sebep-sonuç kurma
Oyuncu girdileri 3×3 karelere dizmez. `enerji kaynağı → iletken → ışık üreten eleman` gibi kısa işlev bağlantılarını kurar; hatalı bağlantı açık geri bildirim verir.
- Güçlü: Ezberlenmiş dizilim yerine çalışma prensibini öğretir.
- Risk: Sınırsız node editörü 320–360dp portrait ekranda kullanılamaz hale gelebilir.

### D. Kayıp Teknoloji — Sistem arkeolojisi
Kırık makine, terk edilmiş tesis veya nadir mob parçası analiz edilir. Core çalışma izlerini çıkarır; oyuncu eksik ilkeyi başka dünyasal ipuçları ve kısa deneyle tamamlar.
- Güçlü: Keşif bölgeleri ve ödüller anlam kazanır.
- Risk: Tek başına kullanılırsa icat sistemi yalnız hazır harabe bulmaya indirgenir.

## Önceki birleşik yaklaşım — tarihsel öneri

**İz bul → İpucundan hipotez üret → Kısa deney yap → Çalışma ilkesini keşfet → Blueprint'i kalıcı öğren → Sonraki üretimi tek eyleme indir.**

Örnek (tamamı varsayımsal, kanonik item veya tarif değil): Fırtınada eski bir yön işareti yanıp söner. Core taş damarlarının iletkenliğini ve reçinenin yalıtım etkisini fark eder. Oyuncu küçük deneyde `enerji → iletken → ışık` ilişkisini kurar; yanlış bağlantı kıvılcım ve tanı ipucu üretir. İşlev çalıştığında `Fırtına Feneri` blueprint'i öğrenilir. Bundan sonra aynı feneri yapmak için yeniden keşif bulmacası gerekmez. Gelecekte robotlar bilinen üretim emirlerini uygulayabilir.

**Karar verilmedi:** İlk buluşu taşıyan asıl etkileşim çevre izini takip etmek mi, plazma deneyi mi, işlev bağlantısı mı, yoksa bunların sade bir birleşimi mi?

## UX ve oyun dengesi tasarım sınırları

- Oyuncuya anlaşılır ipucu ver; keşif rastgele yüzlerce kombinasyonun brute-force denemesi olmasın.
- Deney başarısız olduğunda bilgi üretsin; malzeme kaybı ve maliyet dengesi daha sonra kararlaştırılacak.
- Mobil portrait 320–360dp, 392–411dp ve font scale 1.3 dikkate alınsın; serbest sürükleme zorunlu olmamalı, tek dokunma/tap alternatifleri olmalı.
- Yeni keşif işlemi tekrar zorunlu bir zamanlama mini oyununa dönüşmesin.
- Serbest icat duygusu vaat edilirken sınırsız prosedürel yeni item ve kombinasyonların eksiksiz simülasyonu vaat edilmesin; kurallı işlev aileleri tanımlanabilir.
- Keşif eylemleri ileride host-authoritative, idempotent ve sürümlü kayıtlara uygun modellenmeli.

## Mevcut teknik durum ve güvenlik

- `game/love/systems/crafting.lua` ve `data/catalog/recipes/`: tarif `inputs`, `outputs`, `station_tags`, `duration_ticks` ile tanımlı; tarif keşfi, öğrenilen blueprint veya icat deneyleri henüz kodda yok.
- Stage5 12 slot, 5 hotbar, 1 odun → 4 tahta, 4 tahta → tezgâh, 0,5/1 sn başlangıç örnekleridir; tasarım kabulü değildir.
- Workbench JSON `queue_limit:2` tanımlar; çalışan tek-aktif crafting motorunun tamamlanmış üretim kuyruğu olduğu anlamına gelmez.
- Stage6 `save_v2` envanter/dünya/yerleştirme/ledger taşır; keşfedilmiş blueprint, deney durumu, gelecekte robot emirleri ve aşamalı inşaat ayrı sürümlü tasarım gerektirir. İzin ve migration olmadan mevcut kayıt sözleşmesini değiştirme.
- Stage6 görevi `oyun-stage6-save-recovery-20261016`, `experiment/stage5-stage6-integration-v1`, main ve backup, Core/Axe, plazma, fizik/kamera, stüdyolar ve kullanıcı verileri **değiştirilmez**.

## Önceki karar sorusu (yanıtlandı)

Kullanıcı 2. Plazma Deney Alanı ile 3. İşlev Devreleri birleşimini seçti. Önceki soru çözülmüştür; malzeme inceleme ve işlevsel parça tasarımı için yeni kararlar aşağıdadır.

## Kaynaklar
- AGENTS.md, README.md
- docs/14_CORE_PLASMA_PROGRESSION_DESIGN.md
- docs/18_LOVE_STAGE5_AND_SAVE_V2.md
- schemas/love-world-v2.schema.json
- game/love/systems/{inventory,crafting,building}.lua

---

## 2026-10-18 — Yeni kullanıcı kararları: plazma analizi + işlevsel parça blueprint'i

**Bu bölüm önceki «B ve C hâlâ seçenek» ifadesini geçersiz kılar.** Bu konuşmada oyuncu aşağıdaki prensipleri benimsemiştir. Gerçek oyun kodu veya save schema henüz değiştirilmedi.

### Kabul edilen ilkeler (kullanıcının doğrudan tarif ettiği)

1. **Plazma Deney Alanı ve İşlev Devreleri birleşir.** Eşya tasarımı klasik 3×3 malzeme yerleştirme değil, yapısal/işlevsel bileşenlerin ihtiyaçlarına uygun malzeme seçimidir.
2. **Malzeme bilgisi keşifle açılır ve birikir.** Oyuncu bir maddeyi inceler; maddeye ilişkin bazı özellikler öğrenilir ve daha sonra kullanılmak üzere kaydolur. Tarama/analiz düzeyi daha ileri özellikleri ortaya çıkarır.
3. **Malzemelerin gerçek oynanış parametreleri vardır.** Dayanım, kırılganlık, esneklik vb. üretilmiş aracın davranışını etkiler. Yalnız «2 taş + 1 odun = taş kılıç; 2 demir + 1 odun = demir kılıç» gibi sabit eşya kombinasyonlarıyla sınırlı değildir.
4. **Blueprint işlevsel ihtiyaçları belirtir.** Örneğin kılıç I üç işlevsel yuvaya sahip olabilir; her yuva için farklı malzemelerin sağlaması gereken özellikler bulunur. Daha karmaşık cihazların yuvacıkları ve bağlantıları farklıdır.
5. **Bir malzeme farklı icatlarda yeniden kullanılabilir.** Yay kollarını ahşaptan yapmak başlangıçtır; ileride elastik enerji depolama ve geri kazanım özellikleri uygun özel metal bulununca aynı işlev farklı malzemeyle çözülebilir. Tek bir eşya için tek bir sabit malzeme doğru sayılmaz.
6. **Çalışan bir aygıtı bulmak analiz olanağı verir.** Düşük seviye analist sadece ne işe yaradığını; daha yüksek seviye analist önce kaç rol/slot bulunduğunu, sonra gerekli işlevleri ve giderek hangi malzemelerin uygun olduğunu öğrenebilir. Bilgi kademeli açılır.
7. **Teknoloji ve büyü/skill alternatif ilerleme yolları sağlar.** Tarama yeteneğini öğrenmiş karakter doğrudan kullanabilir; yeteneği olmayan karakter kendi geliştirdiği analiz cihazıyla aynı keşif alanına ulaşabilir. Her iki yolun düzeyi öğrenilebilen bilgi miktarını etkiler; birini seçen oyuncu diğerini zorunlu ilerleme duvarı olarak görmemeli.
8. Öğrenilen blueprint'in sonraki üretimi kolaydır; gelecekte robot veya uygun moblar aynı bilinen işleri otomatik yapabilir.

### Mekanik mimari önerisi (henüz kullanıcı onayı bekler)

**Öğrenme dört ayrı nesneye ayrılabilir:**
- `MaterialDefinition`: bir malzeme türünün dünya sabitleri; sertlik, darbe tokluğu, elastik geri kazanım, çekme dayanımı, yoğunluk, işlenebilirlik, enerji/büyü etkileşimi vb. statlar ve kaynak kimliği. Bunlar gerçek oyun simülasyonundaki kurallardır.
- `MaterialKnowledge`: oyuncunun *o malzeme hakkında* bilinen özellikleri, yaklaşık değer aralıklarını, güven seviyesini ve deney/analiz kayıtlarını saklar; **gerçek değerlerin kendisi değildir**. Eksik bilgi, malzemenin dünyadaki özelliğini değiştirmez.
- `BlueprintDefinition`: işlevsel roller/yuvalar, minimum gereksinimler, bağlantı uyumu, üretim işlemi ve malzeme/istasyon kısıtları. Ham malzeme isimleri genel tarifin tek geçerlilik ölçütü değildir.
- `BlueprintKnowledge + FabricationPreset`: oyuncunun çözdüğü şema ve başarılı prototip kombinasyonu; öğrenilmiş kombinasyon daha sonraki üretimlerde tek dokunuşla yeniden üretilebilir. Başarılı özel varyantlar kaydedilebilir.

**Önerilen oyun eylemi:**
1. **İncele:** Yeni malzeme veya çalışan cihaz taranır. Core bilgi defterinde sadece elde edilebilen bilgi açılır.
2. **Hipotez:** Oyuncu blueprint'teki rol/yuvaların bilinmeyen ihtiyaçlarını ve malzemenin bilinen özelliklerini karşılaştırır. «Uygun», «muhtemelen uygun», «bilinmiyor», «uygunsuz» gibi geri bildirim sunulur.
3. **Prototiple:** Rol için bir malzeme seç, gerekli işleme yöntemini uygula, rol bağlantısını test et. `plazma alanı` kısa fiziksel deney ve `işlev bağlantısı` aynı prototip düzeninde olabilir. Hatalar açıklanabilir geri bildirim/özellik ipucu verir, kör deneme olmasın.
4. **Kaydet ve üret:** Çalışan prototip, oyuncunun `FabricationPreset` kaydına dönüşür. Bir daha aynı mini deney gerekmeyebilir; malzeme/istasyon koşulları uygunsa normal crafting veya ileride otomasyon iş emriyle yapılır.

**Malzeme slotlarından örnekler (kesin denge veya katalog değildir):**
- `Sword I`: 3 **işlevsel rol**, ör. **kesici gövde** (sertlik + tokluk + keskin kenar), **tutma bölümü** (tutuş ve dengeli kütle), **birleştirme** (mekanik yük altında bağlantı dayanımı). Her rol için `quantity` ayrıca ifade edilir; «3 slot» mutlaka «3 adet hammadde» anlamına gelmez.
- `Bow I`: **yay kolları** (elastik enerji depolama, geri toparlanma, yorulma dayanımı), **kiriş** (çekme dayanımı, düşük uzama, düşük kütle), **bağlantı/tutacak** (yük aktarımı). Ahşap yerine özel metal ancak onun `geometri + elastik geri kazanım + yorulma + yoğunluk` koşulları da uygunsa seçenek olur. Yalnız «esnek» statı tek başına yeterli değildir.
- Gevrek metalin kesici parçada sertliği yüksek ama tokluğu düşük olabilir; ilk birkaç sert darbe sonrasında kırılma riski artar. Sadece yüksek «damage» kılıcı mükemmel yapmaz.
- Sıradan taşla «büyülü kılıç» yapmak için malzeme veya alt-sistemlerin enerji tutma/iletme, büyü bağlama gibi **ek gereksinimlerini** karşılaması gerekir. Taş her bakımdan başka malzemelerin yerine geçemez.
- Karmaşık aygıtta işlevsel slot sayısı, bağlantı grafiği ve işleme gereksinimleri artabilir; **yeni cihazların tam parametreleri ayrı karardır**.

**Tarama ilerlemesi — önerilen bilgi çözünürlüğü (sayılar kesin değil):**
- R0: İşlev sezgisi: «Bu bir kesici/enerji aktarım aygıtıdır.»
- R1: Yapı: «3 işlevsel rol var.»
- R2: Rol açıklamaları: «kesici / tutacak / birleştirme», yaklaşık malzeme sınıfları.
- R3: Rol eşikleri ve uygun aday malzemeler; ölçüm aralıkları ve tahmin güveni.
- R4: Ayrıntılı bileşen/işleme, dayanıklılık/maliyet analizi ve iyileştirmeye uygun ilave bilgi.
- **Alternatif erişim:** `Analiz Skill` veya `Tarayıcı Cihazı` aynı hedef çözünürlük düzeylerine erişebilir. Magic ya da Tech zorunlu ortak seviye kapısı olmaz; ilerleme dengesi ve olası uzmanlaşma farkları ayrıca belirlenir. Sadece yüksek stat = her şeyi otomatik bilmek değil: gözlem/deney gereksinimleri korunur.
- Büyü yeteneği vs teknolojik cihazın bilginin **miktarına/erişimine** etkisi kullanıcı kararıdır; ek bir «ortak zorunlu skill» getirilmez.

### Kritik tasarım korumaları ve veri sözleşmesi

- Simülasyon değeri / bilinen değer birbirinden ayrılmalı; istemci/oyuncu bilgi seviyesi gameplay'i değiştiren malzeme statını değiştirmez.
- Dünya katalog tanımları ve materyal türleri kanonik, versiyonlu ID kullanmalı. Her mümkün material×tool kombinasyonu için yeni statik katalog tanımı üretilmemeli; üretilen eşya **base_blueprint_id + material role bindings + process version + derived stats** gibi instance-level metadata taşıyabilir.
- Stacklenebilir ham malzeme ile farklı bileşim ve farklı dayanıklılıkta üretilen aletleri aynı stack'e koymak yanlış olur. Stage5 `{def_id,count}` slot modelinin **genişletilmesi** ve Stage6 `save_v2` için güvenli yeni sürüm/migrator gerekecektir. Bu oturumda bu dosyalarda **hiçbir değişiklik yapılmaz**.
- `Crafting:begin/update`, checkpoint, inventory, ledger ve gelecekte robot/mob iş emri atomik/idempotent sınırları korunmalı; uydurma client-crafted stat ve sahte item üretimine izin verilmemeli.
- Basit başlangıç eşyaları uzun uğraştıran araştırmaya mahkûm olmamalı; bilinmeyen malzeme keşif heyecanı yaratırken, kabul edilebilir başarısızlıklar anlamlı geri bildirim üretmeli.
- Blueprint taraması ile materyal taraması farklı: biri **işlevsel tasarım/rolleri**, diğeri **malzeme davranışlarını** açıklar. Oyuncu iki tür bilgiyi bilgi defterinde bir araya getirir.
- Malzemenin iyi bir kullanım alanı başka özelliklerinden ötürü sınırlanabilir: kalıcı deformasyon, kırılma, yorgunluk, yoğunluk, işleme yöntemi, ısı/büyü uyumsuzluğu. Fiziksel özellikler anlaşılır, tutarlı, test edilebilir, telefon performansına uygun deterministik skor modellerinden üretilebilir.

### Sıradaki tek tasarım kararı — kullanıcıyla netleştir

**İlk kez prototip edilen bir eşyanın sonucu nasıl belirlenmeli?**
(A) Uygun malzeme eşikleri ve işleme teknikleri sonucu deterministik hesaplar; oyun öncesi bilginin eksikliği nedeniyle risk/ödül vardır.
(B) Oyuncunun plazmayı yönettiği kısa, beceri temelli mini deney de kaliteyi etkiler.
(C) Karma: statlar uygunluğu ve kalite tavanını belirler; tek seferlik opsiyonel plazma deneyi ilk prototip optimizasyonunu etkiler; başarılı tasarım kaydedilir ve tekrar üretim kolaylaşır.

Henüz denge formülleri, stat dağılımı, tarama R seviyesi eşikleri ve prototip başarısızlığında malzeme tüketimi kararlaştırılmamıştır.

### Açık kullanım sınırları
- `main` ve Stage6 bağımsız deney dalına yazma yok.
- Kod, JSON katalog, schema, kayıt motoru, gerçek cihaz veya otomasyon uygulaması yok.
- Kararlar sadece tasarım belgesinde ve ayrı Beyin kaydında izlenir.

---

## 2026-10-18 — Kullanılabilirlik ve Ustalık (güncel kullanıcı düzeltmeleri)

**Bu bölüm önceki fikirlerin eksik/yanlış yorumlarını düzeltir.** Önceki R3/R4 tarama açıklamalarının bilinmeyen malzemeyi otomatik tanıdığı, basit kılıç için stat eşiklerinin katı kilit olduğu veya Tech ve Magic'in birebir aynı şey olduğu varsayılmamalıdır. Bu bölüm kabul edilen güncel yön, alt başlıkları açıkça «öneri» denilenler tasarım alternatifidir.

### Onaylanan tasarım hedefleri

1. **Bilgiye koşullu tarama:** Gelişmiş taramada item'da hangi malzeme kullanıldığının kimliği ancak oyuncu o malzemeyi zaten tanıyorsa çıkarılabilir. Malzeme bilinmiyorsa analiz, tarayıcının çözünürlüğüne göre **bazı davranış/stat/iz ipuçları** gösterir; bilinmeyen maddelerin tam tanımını sihirli şekilde vermez. Oyuncu yeni bilgiyi kaydedip zamanla daha iyi teşhis eder.
2. **Sınırlı temel tasarım, çok büyük varyant uzayı:** Temel kılıcı herkes üretebilir. Ahşap, taş, demir ve özel alaşım kombinasyonları her biri için ayrı sabit tarif olmak zorunda değil. Şekil/bileşen malzemesi, üretim süreci ve kullanım koşullarına göre nitelikleri değişen çok sayıda eşya örneği bulunur. «Sonsuz kılıç» deneyimsel çeşitlilik hedefidir; gerçekten sonsuz içerik veya sonsuz güç değil.
3. **Görsel aileleri sınırlı:** Malzemeye göre ahşap/taş/metal gibi az sayıda siluet, renk/materyal ve küçük detay varyantı kullanılabilir. İki benzer görünen kılıcın istatistikleri aynı olmak zorunda değildir.
4. **Kolay başlayan, ustalaşması uzun süren sistem:** Mühendislik cetveliyle koşul hesaplamak zorunlu değil. Düzgün malzeme kullanınca basit bir kılıç üretmek kolay olmalı; oyuncu malzeme sinerjisi, işleme, hedef, build ve eşya kullanımını öğrenerek ustalaşmalı. LoL item build okuryazarlığı gibi: herkes eşyaya ulaşabilir, uzman iyi dizilim ve zamanlamadan ciddi avantaj üretir.
5. **Skill + teknoloji iki sınıf/faksiyon değil:** Kullanılabilir skill kapasitesi sınırlanarak uzmanlaşma/tercih yaratılabilir. Savaş ağırlıklı skill seçen kişi gelişmiş madencilikte geri kalabilir; bunu teknolojik cihazla telafi etmek için ileri malzemelere erişmek de zor olabilir. Bu gerçek fırsat maliyeti korunmalı. Magic/skill ve teknoloji bazen aynı probleme çözümler verir, bazen farklılaşır, bazen birlikte işe yarar; birebir ikame şartı yoktur.

### Tarama mantığı — önerilen iç model

- Dünyada malzemenin GERÇEK kimliği ve nitelikleri sabittir.
- Oyuncunun MaterialKnowledge kaydı bildiği madde kimliklerini, ölçüm sonuçlarını, gözlemsel kanıt ve belirsizliğini tutar.
- Tarayıcı her analizde cihaz/skill düzeyinin çözebileceği kadarıyla eşyanın işlevini, slot/rol yapısını, proses izlerini ve bileşen malzeme özelliklerini gözlemler.
- **Tanıma adımı:** Bilinmiş kimliğin imzası ölçümle eşleşiyorsa malzeme adı görünür. Oyuncu o kimliği öğrenmemişse «Bilinmeyen alaşım, sertlik yüksek, darbede çatlama eğilimi, oldukça yoğun» gibi kısmi ölçüm görünür. Statların tamamı tek seferde açılmaz; aralık/hata payı mümkün olabilir.
- Daha sonra aynı bilinmeyen malzeme örneği toplanıp incelendiğinde önceki eşya taraması daha anlamlı hale gelebilir. Malzemeyi tanımak ile o malzemenin her statını eksiksiz bilmek de aynı şey değildir.
- Tarama düzeyi yüksek olması tüm maddeleri otomatik tanıma, tüm slotları kesin kopyalama veya bütün tarifi öğrenme garantisi değildir. Önceden edinilmiş bilgi ve örnek bulunabilirliği belirleyicidir.
- Maddelerin statları oyuncunun bilgisizliğine göre rastgele değişmez. Eksik bilgi tahminde bulunmayı gerektirir.

### Aynı kılıç şemasından sayısız oynanabilir varyant — önerilen deneyim

- Sword gibi bir temel blueprint, kesici gövde, kabza ve bağlantı gibi işlevsel **rolleri** tanımlar; «üç rol» doğrudan «üç birim ham madde» değildir.
- Dört rolün her biri için her durumda sabit «tokluk >= X» şartları getirip basit crafting'i kilitleme. Fiziksel olarak anlamlı uç durumlar hariç uygunluk **dereceli** sonuç versin. Sert ama gevrek gövde keskin fakat kırılabilir; ağır gövde güçlü ama yavaş; dengeli alaşım daha pahalı ve kararlı olabilir.
- Sadece hasar tek kalite sayısı değildir. Ağırlık, hız, darbe davranışı, keskinliğin korunması, yıpranma, tamir masrafı, oyuncunun kullandığı skill ve hedef tipi birbirini dengeleyebilir. Tek bir bileşen evrensel en iyi olmayabilir.
- **İki katmanlı arayüz önerisi:** Normal oyuncu «Kılıç yap» der, oyun elindeki kaynaklardan «Ucuz / Dengeli / Hızlı» gibi birkaç anlaşılır kombinasyon önerir. İsteyen oyuncu «Ayrıntılı Tasarla» yolunda malzemeleri, prosesleri, ilişkileri inceleyip varyantı kaydeder. Örnek skorlar/semboller yeterli; herkesin formül ezberlemesi gerekmez.
- Öğrenilen kombinasyon tekrar üretimde kolayca seçilir; ileride robot/mob otomasyonu aynı kayıtlı varyanta iş emri gönderebilir. Karmaşık deney ilk buluş veya geliştirme için değer taşımalı, sürekli zorunlu olmamalı.
- Nihai stat hesapları ve işleme minioyununun rolü henüz onaylanmadı. Ustalık bilgi/tercih/kullanım becerisinden de doğabilir; rastgele kalite zarından tek başına doğmamalı.

### Büyü + teknoloji + sınırlı beceriler — ekonomi tuzağı çözümlemesi

- Kullanıcının önerisi: Karakter belirli miktarda skill **kullanabilir**; savaş, toplama, araştırma vb. uzmanlaşma farklı güçlü ve zayıf yanlar üretir. Bunun aktif yükleme yuvası mı kalıcı öğrenme sınırı mı olduğu **açık karardır**.
- Büyüsel tarama skill'i ve teknolojik analiz cihazı bazı sonuçlarda örtüşebilir, ama her zaman aynı çözünürlük, enerji maliyeti veya özellik setini paylaşmak zorunda değildir. Farklı yöntemlerin özgün güçlü yanları olabilir; hiçbirinin «zorunlu sınıf» olmaması hedeflenir.
- Savaş skill'leriyle ilerleyen karakterin zor bir madeni çıkartamaması gerçek bir handikaptır. Ancak ekipman yapmak için gerekli maden de aynı cihazın önkoşuluysa **kaynak edinme çıkmazı** olabilir.
- Olası (henüz kabul edilmemiş) telafi yolları: düşük verimli başlangıç toplama, erken ve pahalı/ucuz farklı cihazlar, ticaret, keşif, salvage, oyuncu-oyuncu iş bölümü, gelecekte yardımcı moblar. **Bedelsiz şekilde ileri uzmanlıkla tamamen eşdeğer** kılma; zorluk anlamlı kalsın, imkânsız kilit oluşmasın.
- Sadece Tech vs Magic arasından seçim değil; her oyuncunun savaş/toplama/tarama/üretim gibi alanlardan bir build kurması ve gerekirse cihazlarla açıklarını kapatması hedeflenir. Karma yatırımlar desteklenir.

### Teknik sonuç — tasarım, henüz uygulama değil

- Kanonik ItemDefinition/Blueprint aynı temel şemayı taşır; her fiziksel ItemInstance işlevsel rol → malzeme ID, proses seçimi, dayanıklılık/kondisyon ve hesaplanmış statlar gibi instance meta tutabilir.
- Görsel sınıf, ana yapı/malzeme ailesinden türetilebilir; güç sınıfı ile birebir aynı değildir.
- Mevcut Stage5 envanter stack modelinde eşya-örneği ve farklı koşul statı yok. Stage6 save_v2 henüz ilgili MaterialKnowledge, öğrenilmiş varyantlar ve dinamik ekipman alanlarını saklamıyor. Yeni sürüm, migration, host yetkisi, atomic transaction ve güvenli geri alma tasarlanıp ayrıca onaylanmalı.
- Main, Stage6 deney dalı, eski kayıtlar, fizik/kamera ve Core/Axe/plazma korunacak. Bu kayıtta kod veya gerçek oyun mekanik uygulaması yapılmaz.

### Bir sonraki dar kapsamlı tasarım sorusu

**Skill sınırının türü nasıl olmalı?** A: Bilgi kaybolmadan yalnızca aynı anda kullanılabilen skill yuvaları; B: Öğrenilebilecek skill toplamında daha kalıcı uzmanlık sınırlaması; C: İkisinin kontrollü birleşimi. Hiçbiri henüz kabul edilmedi.
