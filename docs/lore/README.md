# Lore wiki kuralları

- **Tek kaynak:** `docs/lore/` içindeki Markdown dosyaları; teknik belgeler kanıt/kaynak olarak dışarıdan referanslanır, kopyalanmaz.
- **Bağlantı:** Obsidian biçimi `[[03_DUNYA/Fisilti_Ormani|Fısıltı Ormanı]]`. Yol `docs/lore/` köküne göre yazılır, `.md` eklenmez; böylece adaş sayfalar çakışmaz. GitHub wiki-linkleri doğal olarak tıklanabilir değildir; GitHub'da açmak için normal Markdown bağlantısı ayrıca kullanılabilir.
- **Boş başlık:** Henüz hazırlanmadıysa sahte dosya/link yerine `91_BOSLUKLAR.md` içinde `OPEN-...` kimliğiyle durur.
- **Frontmatter:** `id` (kalıcı, benzersiz), `title`, `type`, `status`, `canon`, `aliases`, `tags`. Yalnız katalog işleyişi için kullanılan metadata; oyun runtime/save şeması değildir.
- **status:** `empty` (yalnız konu indeksi), `draft`, `review`, `canon`, `deprecated`. **canon:** `accepted-framework`, `confirmed`, `pending`, `retired`. İçerik için nihai onay gelmeden `confirmed` seçilmez.
- **Karar:** Kanonik değişiklik [[90_KARARLAR]] kaydında karar kaynağı ve çeliştiği önceki ilkeyle belirtilir. Eski bilginin silinmesi yerine tarihsel olarak işaretlenmesi tercih edilir.
- **Bağlantı güvenliği:** Hedefteki `.md` gerçekten bulunmalı. Çift yönlü bağlantı Obsidian backlinks ile görünür; karşılıklı bağlantı gerekliyse iki sayfada da açıkça yazılır. Bağlantısı olmayan yeni kavram önce boşluk listesinde açılır.
- **Kaynak ayrımı:** Lore iddiası, oyun mekaniği, taslak spekülasyon ve tarihsel karar birbirine karıştırılmaz. Var olan Core/plazma belgeleri ilk fikirleri içerir; 29 Ekim Rigby görsel kararı daha yenidir.
- **Güncelleme:** Önce indeks ve boşluk kimliğini kontrol et; mevcut sayfayı genişlet, mükerrer sayfa oluşturma. Yeni sayfa oluşturulunca OPEN durumunu kapatıp bağlantısını yerine koy.
- **Doğrulama:** İlgili sayfaların frontmatter ve wikilink hedefleri, benzersiz `id` ve OPEN kimlikleri, kaynağa giden dosya yolları gözden geçirilir. Bu sürümde otomatik CI/graph jeneratörü kurulmadı.


---

# Uygulamalı rehber: Lore'dan özgün oyun canlısına

> **Hedef kitle:** TAMU geliştiricileri ve benzer biçimde sandbox survival-crafting dünyası kurmak isteyen tasarımcılar.
>
> **Nitelik:** Bu bölüm bir **üretim yöntemi/tutorial** belgesidir; buradaki aday türler, görsel promptlar, sayısal değerler ve simülasyon katsayıları otomatik olarak kanonik değildir. Oyun kodunda uygulanmış bir mob sistemi olduğu iddia edilmez.

## Hızlı rota

1. Dünya ve biyomun arka planını yaz.
2. Kurgu fiziğiyle normal kimyanın sınırlarını ayır.
3. Besin zinciri ve enerji kaynağını tanımla.
4. İç metabolizma *işlevlerini* kur, dışarıdan görülen organları belirle.
5. Organları gövde planına bağla ve fiziksel olarak uygunsuz kombinasyonları ele.
6. Habitat/avcı-av/enerji maliyetleri için **varsayımsal** bir simülasyon çalıştır.
7. En uygun *farklı ekolojik nişlerden* mob adaylarını seç.
8. GPT Image ile tam-vücut özgün tür referanslarını üret; görselleri anatomi açısından incele.
9. Rig/animasyon/AI için ayrı teknik değerlendirme yap. Görsel onayı, motor entegrasyonu veya biyolojik doğrulama demek değildir.

## 1. Önce sandbox dünya mantığını kur

TAMU hikâye zinciriyle yönlendirilmez. Evrenin doğası [[01_KOZMOLOJI/Buyuk_Sistem|Büyük Sistem]] sayfasında, Fısıltı Ormanı'nın arka planı [[03_DUNYA/Fisilti_Ormani|bölge sayfasında]], yerli halklar, önceki gelenler ve farklı dönem kalıntıları [[03_DUNYA/Test_Dunyasi_Toplumlar_ve_Kalintilar|test dünyası taslağında]] bulunur.

Bölgeyi **görevleri barındıran boş harita** olarak değil, oyuncudan bağımsız işleyen bir ekosistem olarak düşün. Orman kıyısı, sık orman, dere çevresi ve kayalık kuşak; besin, sığınma, avcı baskısı ve hareket zorluğu bakımından farklı davranır. Yerliler, önceki tekil gelenler, terk edilmiş üsler ve canavarların sahiplenebildiği kalıntılar aynı bölgede bulunabilir. *Her kalıntı zindan değildir, her canavar düşman değildir.*

## 2. Kozmolojiyi biyolojiye bağla, ama normal fiziği bozma

### Kabul edilmiş kozmolojik zemin

- Tek evren vardır; Büyük Sistem evrenin kozmik bilincidir.
- Kozmik uyanış ve milyonlarca yıllık sessizlikten sonra olasılık sonuçlarında/fiziksel koşullarda değişimler belirginleşmiştir.
- Büyüyle ilgili parçacıklar yeni koşullarda oluşabildikleri bölgelerde ortaya çıkmıştır; dağılımları homojen değildir.
- Dünya özel olarak engellenmiş değildir; insanlık ileri teknolojik düzeye ulaşmamış genç bir uygarlıktır.
- Sistem'in gerçek niyeti ve bilinçlerle ilişkisinin iç yüzü bilinmiyor; oyuncuya açıklanması zorunlu değildir.

### Sonraki görüşmelerden gelen **çalışma hipotezi** — henüz kanon değil

Büyü parçacığı tek başına kullanılmaz. Normal atomların elektronlarını veya protonlarını topluca değiştirmek yerine, yalnız özel maddelerle/bağlayıcı yapılarla etkileşerek **bağlı büyüsel bileşiklerin** oluşmasını mümkün kılar. Bitkiler çevresel girdilerden ilgili molekülleri sentezler/depolar; otçullar bu molekülleri besinle alır; etçiller de avlarından devralır. Canlılar bunları kendi metabolizmalarında dönüştürür ve özel organlarla kullanır.

**Koruma şartı:** Su H₂O, karbon karbon olarak kalır; sıradan protein, DNA, atmosfer ve yaşam genel olarak çalışmaya devam eder. Yeni temel parçacığın adı, yükü, kütlesi, kesin bağı ve yeni element üretip üretmediği **henüz belirlenmedi**. Bu model fizik biliminin kanıtlanmış bir sonucu değil, bilimden esinlenen fantastik mekaniktir.

**Enerji denetimi:** “Parçacık = bedava sınırsız enerji” varsayılmaz. Enerji girdisi, taşınma kaybı, molekül rezervi, ısı/atık ve kullanımdaki risk açıklanmalıdır. Ateş püskürtme için *rezerv, uygun etki organı, ısıya dayanım ve öğrenilmiş kontrol* birlikte gerekir.

### Büyüsel besin zinciri

| Katman | İşlev | Tasarım sorusu |
| --- | --- | --- |
| Atmosfer/çevre | Kullanılamayan serbest kaynak | Nerede ve ne kadar mevcut? |
| Bitki/mantar | Bağlama ve özel molekül sentezi | Hangi doku, yaprak, reçine, meyve, kök? |
| Otçul | Besinle alım ve yeniden sentez | Yenilebilir hangi bitkiyi tüketiyor? |
| Etçil/hepçil | Av/besin yoluyla aktarım | Hangi av ve enerji maliyeti? |
| Özel organ | Rezervin kontrollü fiziksel etkiye dönüşmesi | Isı, savunma, algı vb. hangi işlev? |

Hayvanın **rezerv kapasitesi**, **rezervi yenilemesi** ve **yetenek ustalığı** ayrı değişkenlerdir. Yüksek kapasite her durumda daha iyi saldırı anlamına gelmez. Bitkisel, hayvansal ve pet besleme kuralları aynı ekolojiyle tutarlı olmalıdır.

## 3. Dışarıdan görülebilen fenotipik organları tasarla

İç bezler/sindirim organları yalnız işlevsel arka plan; karakter tasarımında **silueti değiştiren görünür yapılar** önceliklidir.

Önceki çalışmada **40 görünür organ adayı** beş ailede toplanmıştır:

| Aile | Sekiz görünür organ |
| --- | --- |
| Baş/ağız | Alev boğaz kesesi; çift püskürtme kanalı; açılır ağız plakası; rezonans boynuzu; titreşim ibiği; uzatılabilir dil; duyusal bıyık; mineralize diş sırası |
| Gövde/sırt | Enerji yelesi; sırt kristalleri; ısı yüzgeci; şişebilir göğüs kesesi; koruyucu kabuk; dikenli sırt plakaları; ışık nodülleri; açılır yan zar |
| Deri/yüzey | Kamuflaj pulları; ışıldayan benekler; sertleşen deri plakaları; iletken çizgiler; salgı gözenekleri; yalıtıcı tüyler; zehirli dikenler; renk değiştiren şeritler |
| Uzuv/hareket | Enerji destekli pençe; tutunma yastığı; sıçrama tendonu; açılır süzülme zarı; denge kuyruğu; dikenli kuyruk topuzu; yüzme yüzgeci; kazıcı ön uzuv |
| Algı/iletişim | Çift rezonans anteni; titreşim tarağı; ışık algılayıcı taç; koku yelpazesi; yan çizgi duyargası; dokunsal filamentler; yön bulma boynuzcuğu; uyarı yelesi |

**Görünür organ ≠ bağımsız güç eklentisi.** Her yapı bir iskelet/deri tabanına, dolaşıma, enerji kaynağına ve kontrollü hareket aralığına ihtiyaç duyar.

### Anatomik eleme

Her yeni kombinasyonda şu altı kapıyı işlet:

1. **Bağlantı:** Kemik, kıkırdak, kas veya deriye sabitlenebiliyor mu?
2. **Yer:** Solunum yolu, eklem, göz ve diğer organların hacmine giriyor mu?
3. **Kütle:** Baş, sırt veya kuyruktaki yük dengeyi bozuyor mu?
4. **Beslenme:** Büyüsel öncül ve normal metabolik maliyet karşılanabiliyor mu?
5. **Hareket:** Yürüme/sıçrama/yüzme/süzülme mekaniklerini engelliyor mu?
6. **Isı/atık:** Saldırı veya savunma sonrasında ortaya çıkan ısı ve ürünler nereye gidiyor?

**Örnek ret:** Dar boyun + dev alev kesesi; ince denge kuyruğu + dev kuyruk topuzu. **Koşullu:** Sırt kabuğu + geniş ısı yüzgeci (açıklık ve ankraj gerekir); kamuflaj + ışıldayan deri (ışık kapatılabilmeli). Biyolojik uygunluk için her organın *kendi maliyetini de* yaratması beklenir.

### Tür oluştururken doldurulacak kısa profil

| Alan | Örnek açıklama |
| --- | --- |
| Gövde planı | Küçük/orta/iri dört ayaklı, iki ayaklı, sucul, böceksi |
| Habitat | Orman kıyısı, sık orman, dere, kaya/yeraltı |
| Diyet | Otçul, etçil, hepçil; kaynak türleri |
| Görünür organ | Tür siluetine etki eden 2–4 baskın yapı |
| Fonksiyon ve bağımlılık | Hangi bileşik, organ, hareket ve kontrol gerekir? |
| Dezavantaj | Ağırlık, ısı, enerji, hareket, avcı baskısı |
| Öğrenme | Genç/yetişkin bireyin kontrol farkı |
| Pet uygunluğu | Sosyallik, bakım, güven; zorunlu değil |

## 4. Kodlu simülasyonla adayları **dengele**, gerçek evrim sanma

Bu sohbette Python tabanlı bir fenotip sıralama prototipi V0.1 → V0.2 → **V0.3** olarak denendi. V0.3 ZIP arşivi konuşma eki olarak üretildi; **henüz bu depoda kanonik kaynak kodu veya dağıtılan test artefaktı değildir**. Dolayısıyla aşağıdaki sayılar sohbetin yerel prototip sonuçlarıdır; GitHub CI kanıtı değildir.

### Yeniden üretim (arşive sahip olanlar için)

Arşivdeki \`sim.py\` ve \`README.md\` birlikte açılır. Python kuruluyken \`python sim.py\` çalıştırılır; \`rankings.csv\`, \`matchups.json\`, \`results.json\`, \`niche_rankings.json\` ve \`log.txt\` ile doğrulanır. Script'in mevcut kaynak/seed değerlerini değiştirmeden ilk koşu karşılaştırılır. Sadece rastgele tek koşuyu “evrim kanıtı” kabul etme.

| V0.3 gözlemi | Doğru yorumu |
| --- | --- |
| 125.000 aday denemesi; 47.887 geçerli kombinasyon bildirimi | Kurgusal anatomi/uygunluk filtrelerinin sonucu; gerçek hayatta kalma oranı değil |
| Zırhlı otçul ilk seçili profillerde ~13. sıra | Tüm evrende on üçüncü en güçlü tür demek değil |
| Fiziksel saldırı: 0,132; alev organı: 4,632 | Aynı zırhlı hedefe karşı **sentetik hasar puanı** |
| Büyüsel saldırı maliyeti ve kaynak kıtlığı | Avantajı sınırsız yapmayan tasarım değişkenleri |

**Önemli sınır:** V0.3 gerçek zamanlı avcı-av karşılaşmaları, göç, üreme, nesiller boyu seçilim veya popülasyon kararlılığı simülasyonu değildir. Skorlar model varsayımlarına duyarlıdır. Ayrıca “zırh” mutlak hasar bağışıklığı olarak değil, belirli saldırı türlerine karşı yüksek direnç olarak yorumlanmalıdır. Büyü direnci, kıtlığı ve açlık dengede yer alır.

### Geliştirmede önerilen deney sırası

1. Tek bir habitat ve aynı gövde planında organlı/organsız eşleştirilmiş karşılaşma.
2. Zırhlı otçula fiziksel avcı ve büyüsel avcı baskısını ayrı ölçme.
3. Enerji kıtlığı, kuraklık ve habitat değişimini ayrı parametrelerle tarama.
4. Popülasyon, besin yenilenmesi, üreme ve ölüm ancak **ayrı uygulama** sonrasında çok nesilli ölçülebilir.
5. Parametreleri ve tohumları raporda sabitle; istatistiksel belirsizlikleri göster.

## 5. Ekolojik nişlere göre ilk 10 mob adayı

**Özgün isimler bu görüşmede üretilmiş *adaylardır*, onaylanmış kanonik tür dosyaları değildir.** Simülasyondaki genel gövde profilleriyle örtüşebilirler; tek tek birebir hesaplanmış fenotipler değildir.

| Mob | Ekolojik rol | Görünür ayırt edici özellik | Tasarım uyarısı |
| --- | --- | --- | --- |
| Fısıltı Tavşanı | Küçük otçul / av / olası pet | Yaprak damarlı büyük kulaklar, yelpaze duyargalar, sıçrama bacakları | Sadece gerçek tavşana süs eklemekle kalma |
| Kabuk Sırtı | Orta zırhlı otçul | Bark benzeri üst üste dermal plaka, geniş otçul ağız | Omuz eklemi esnekliği |
| Taşkabuk | Dev ağır zırhlı otçul | Kaya/şist benzeri organik plaka zırh, kalın ayaklar | Aşırı kütle ve büyüsel avcı karşı baskısı |
| Yosun Gezginciği | Küçük orman tabanı otçulu | Altı uzuv, yosun benzeri nodüler deri, raspalayıcı ağız | Böcek-kemirgen kopyası olmasın |
| İz Avcısı | Orta takipçi yırtıcı / olası pet | Açılır koku yelpazesi, kamuflaj pulları | Avcılık ve evcilleştirme uyumu |
| Diken Omuz | İri yırtıcı | Güçlü ön uzuv ve omuz kökenli savunma dikenleri | Önden ağırlık ve kazı biyomekaniği |
| Dere Pusucusu | Yarı sucul pusu avcısı | Sırt plakaları, titreşim duyargaları, yüzme kuyruğu | Suda ve karada hareket dengesi |
| Kırıkdiş | İki ayaklı leşçi-avcı | Asimetrik mineralize dişler, kalın kuyruk ucu | Kuyruk denge yükü |
| Saz Sırtı | Yarı sucul hepçil / olası pet | Saz gibi katlanan sırt saçakları, yüzme ayakları | Düşük tehdit ve bakım ihtiyacı |
| Közboğaz | Büyüsel ısıl avcı | Şişen gırtlak keseleri, ısı dağıtan sırt yüzgeci | Beslenme, rezerv, yanma/ısı riski |

### İki somut referans üzerinde yapılan seçim

Bu sohbette kullanıcı **Fısıltı Tavşanı** ve **Kabuk Sırtı** görsellerini üretti/paylaştı ve mevcut hâllerini yeterli buldu. Bu görsellerin kabulü, **tasarım referansı kabulüdür**; otomatik olarak Godot'a yüklenmiş asset, riglenmiş mob veya uygulanan AI anlamına gelmez. Yerel kullanıcı görsellerinin depoya yüklenmesi/lisans ve kaynak SHA doğrulaması ayrıca yapılmalıdır.

## 6. GPT Image ile kopya değil, özgün tür tasarla

Önce **fonksiyonel anatomi ve siluet** yaz, sonra görseli üret. Yeni promptu her seferinde sıfırdan rastgele karakter uydurarak değil, tür fişindeki anatomik gereksinimlerle oluştur.

### Yeniden kullanılabilir prompt şablonu

\`\`\`text
Design an entirely original biologically grounded fantasy species for a
survival-crafting game. Species: [NAME].
Ecological role: [DIET, PREDATORS, HABITAT, BEHAVIOR].
Body plan and locomotion: [SKELETON, LEGS, TAIL, CENTER OF MASS].
Defining external organs: [2-4 DISTINCT FUNCTIONAL ORGANS].
For each organ, show credible anchoring, tissue transitions,
movement clearance and biological purpose.
Materials and palette: [SPECIFIC SKIN/FUR/PLATES/COLOR DISTRIBUTION].
Explain visually how the animal eats, moves and defends itself.
Distinct silhouette even at small game scale.
Detailed full-body three-quarter side view, plain neutral warm background,
consistent lighting, entire creature and every limb visible,
realistic organic textures, no clothing, no gear, no rider,
no labels, no text, no watermark.
Avoid a familiar real animal with superficial fantasy accessories.
\`\`\`

### Özgünlük denetimi

- İskelet/gövde oranı gerçek hayvanın kopyası mı, yoksa tutarlı yeni bir adaptasyon mu?
- En az **iki işlevsel siluet değişikliği** var mı? Ör. yaprak damarlı kulak + hava akımı duyan yelpaze bıyık.
- Organ gövdeye gerçekten bağlanmış mı, yoksa yapıştırılmış aksesuar gibi mi?
- Ayak sayısı, eklem yönleri, kuyruk ve çene her bakışta tutarlı mı?
- Organın etkisi, doğal beslenmesi ve saldırı biçimiyle çelişiyor mu?
- Görsel **oyun boyutunda** okunuyor mu? İnce tüy dokusu tek başına yeterli değil.
- Ayrıntı/şekil sayısı rigleme ve animasyon için yönetilebilir mi?

**Tur başına yaklaşım:** (a) ilk tam-vücut tür referansı, (b) yanlış anatomi düzeltmesi, (c) aynı tasarımın ön/yan/arka turnaround'u, (d) gerekiyorsa ayrılmış rig parçaları ve eksik bölgelerin tamamlanması. Parçalanmış referansın yerine yeniden hayvan tasarlamamak için “preserve exact silhouette, proportions, patterns and part identities; complete only occluded or missing regions” gibi sınırlar kullan.

### Kalite kontrol / sürümleme

Kaynak görsel ile türetilmiş asset dosyalarını ayır. Kaynak adını, üretim tarihini, model/araç sürümünü, promptu, çıktı boyutlarını, mümkünse SHA-256 ve kullanıcı onayı durumunu kaydet. Görsel yeniden üretildiğinde eski sürümü silme. Godot/LÖVE atlasına veya mob kataloğuna geçişte **onaylı asset ile yalnız aday referansı karıştırma**.

## 7. Başkalarının tekrar kullanabileceği kabul listesi

- [ ] Tür, bir habitat ve besin zinciri rolüne sahip.
- [ ] Fiziksel silueti, başka bir mevcut mobdan ayırt ediliyor.
- [ ] Görünür organın biyolojik işlevi, yerleşimi ve maliyeti tanımlı.
- [ ] Anatomik çakışmalar ve hareket kısıtları incelendi.
- [ ] Büyüsel yetenek için besin, molekül rezervi, organ ve ustalık ayrı.
- [ ] Avcı-av ve zırh/büyü eşleşmeleri karşılaştırıldı.
- [ ] Simülasyonun varsayımları, seed'i ve sonuç dosyaları belgeli.
- [ ] GPT Image referans görseli bütün uzuvlarla incelendi.
- [ ] Referans, rig ve oyun içi mob ayrı kabul kapılarına sahip.
- [ ] **Taslak / onaylandı / kodlandı / CI / cihazda test edildi** durumları birbirine karıştırılmadı.

## 8. Bilinçli olarak henüz çözülmeyen konular

Yeni temel parçacığın kesin fiziği, büyüsel molekül ailelerinin kimyası, bütün canlı organlarının anatomik validasyonu, pet AI/evcilleştirme, ekosistemin gerçek çok nesilli simülasyonu, 10 mobun kesin kanon statüsü, Godot varlık entegrasyonu ve Android üzerinde oynanış testi açık işlerdir.

Bu rehberin tekrar kullanılabilir değeri **yöntem + denetim kapılarıdır**; sayısal katsayıların veya yapay zekâ görsellerinin bilimsel olarak doğrulanmış olduğu iddiası değildir.

