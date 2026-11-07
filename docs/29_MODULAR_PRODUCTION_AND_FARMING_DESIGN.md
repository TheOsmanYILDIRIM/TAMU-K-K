# TAMU: Modüler üretim, hazır yapı özellikleri ve tarım

Tarih: 2026-11-06. Durum: kullanıcı tasarım kararı + ilk oturumluk prototip. Tam üretim entegrasyonu değildir.

## Temel mimari

- Hazır tek-PNG bina dışı; bina tek başına crafting tarifi açmaz.
- Farklı mimari görseller, sabit özellikleri gösterir: barınak, havalandırma, yangına dayanım, ağır makine altyapısı, temiz/kuru ortam, doğal ışık, açık hava, yetiştirme, hayvan barındırma.
- Modüler makine parçaları 90 derece yönlenen, tipli giriş/çıkış soketleriyle yapboz gibi birbirine bağlanır; ağ yeni işlevler oluşturur.
- Makine malzemesi/araç geometrisi/işlem ve bina/çevre etkileri bağımsızdır. Sabit demir/kömür/malzeme tarif patlaması yoktur.
- Bina-makine uyumsuzluğu yasak değil: kademeli duman, yangın, mekanik titreşim, elektrik ve basınç hasarı gibi gözlemlenebilir sonuçlar oluşturur.
- T0-T5 makine mühendislik sınıfıdır, oyuncu veya Core seviyesi değildir. Teknoloji ile büyü bazen birbirinin yerini tutar, bazen farklı, bazen hibrittir; lore'a göre her yerde büyü parçacığı yoktur.

## Teknoloji

| Kademe | Araç/makine ilerlemesi |
| --- | --- |
| T0 | Elle toplama, basit ateş |
| T1 | Balta, kazma, çapa, testere, tezgâh |
| T2 | Eritme, pota, örs, döküm, pompa |
| T3 | Mekanik pres, hassas işleme, basınç, analiz |
| T4 | Jeneratör, elektrikli üretim, otomasyon, robotik |
| T5 | Gelişmiş teknoloji/hibrit, nadir malzeme ve bölgesel koşullar |

Alet aileleri: el baltası, ağaç devirme baltası, yarma baltası, kazma, kürek, çapa, orak, bıçak, testere, çekiç, maşa, keski, eğe, matkap, ölçüm aleti, tarayıcı, sulama kabı, ekici, tamir aleti. Şekil ayrı blueprint; malzeme/proses statları değiştirir.

## Yapı tipleri

| Hazır görsel bina / alan | Özellik |
| --- | --- |
| Ahşap kulübe | barınak, yanıcı |
| Havalandırmalı ahşap atölye | barınak, yanıcı, havalandırmalı |
| Taş dökümhane | barınak, yangına dayanıklı, havalandırmalı |
| Güçlendirilmiş atölye | ağır makine destekli |
| Metal konstrüksiyon fabrika | ağır destek, havalandırma, enerji tesisatı |
| Korumalı laboratuvar | temiz, kuru, korumalı |
| Sera | ışık geçiren yetiştirme alanı |
| Açık tarla | açık hava, yetiştirme |
| Açık üretim sahası | ağır temel, açık hava |
| Kereste sahası | açık hava, stok |
| Taş ocağı | mineral saha, ağır ekipman |
| Hayvan ağılı | hayvan barınağı |

3x3 kulübe mevcut projeksiyona uyar. 4x4/5x5 bina planları daha sonra ayrı görsellerle hazırlanır. Bina boyutu ile teknoloji seviyesi aynı kavram değildir.

## Makine bağlantı ve içerikleri

Prototipte 30 makine modülü: fırın, körük, pota, kalıp, baca, kömür ocağı, dövme ocağı, testere, kırıcı, öğütücü, pres, basınç kazanı, vana, pompa, boru, sulayıcı, jeneratör, batarya, konveyör, robot kol, tarayıcı, çalışma tezgâhı, ısıtıcı, filtre, ekici, tohum haznesi, hasat kolu, soğutucu, numune masası, alaşım fırını.

Bağlantı aileleri: malzeme, sıvı, gaz/hava, ısı, mekanik hareket, elektrik, sinyal ve ileri özel enerji. Soketler tipli, yönlü ve rotasyona duyarlıdır; oyuncu piksel hassasiyetinde çizim yapmaz.

İlk gerçekten simüle edilen süreçler: fırın -> pota -> kalıp bağlantısıyla demo külçe; testereyle tahta; kırıcıyla kırıntı; başlangıç açık tarla ek/sula/büyüt/hasat.

## Ortak etki matrisi

| Kaynak etki | Çevre/bina koşulu | Sonuç adayı |
| --- | --- | --- |
| Yüksek ısı | Yanıcı ahşap | kızarma, yangın, bina kaybı |
| Yanma dumanı | Kapalı, tahliyesiz | duman birikimi, canlıya göre maruziyet |
| Gaz ve toz | Havalandırmalı/açık hava | daha hızlı dağılma |
| Basınç | Tahliye vanası yok | sızıntı, arıza, patlama |
| Titreşim | Hafif temel | yapısal hasar |
| Elektrik + nem | Kötü yalıtım | kısa devre, yangın |
| Aşırı sıcak metal + su | Kontrolsüz soğutma | sıçrama ve ürün hatası |
| Kimyasal uyumsuzluk | Yanlış kap | korozyon veya kirlenme |
| Toz + alev | Yanıcı partikül birikmesi | toz yangını |
| Kirli üretim + gıda | Temiz olmayan alan | ürün kontaminasyonu |
| Tarla + yetersiz su | Yetiştirme koşulu | yavaş büyüme, kuruma |
| Tarla + fazla su | Yetersiz drenaj | çürüme |
| Açık ağıl + yırtıcı | Koruma yok | hayvan kaybı |
| Özel enerji + bilinmeyen malzeme | Lore'a özgü | tasarlanacak kararsızlık |

Bütün eşleşmeler tek tek makine-bina istisnası olarak kodlanmaz: makinenin etkisi, bağlantı ağı, ortam etiketi ve biriken tehlike sisteminden çıkarılır. Görsel uyarı -> müdahale -> olası hasar; gizli anlık tüm-ev kaybı tasarım hedefi değildir. Solunum gazı Core/teknolojik varlığı biyolojik canlıyla aynı şekilde etkilemeyebilir.

## Tarım ve açık alan

Tarla ayrı bir yapı/alan olarak seçilir. Toprak, su, ışık, sıcaklık, besin, zararlı ve ürün zamanı gelecekteki değişken aileleridir. İlk prototip yalnız ekim, su tüketimi, büyüme süresi, hasat ve demo stok kullanır. Açık alanlar için taş ocağı, kereste sahası, hayvan ağılı, su sistemi, kömür üretim alanı, enerji ve tarla büyütmeleri planlıdır.

## Çalışan prototip / eksikler

Kaynaklar:
- data/catalog/production_sandbox.v1.json
- scripts/production_engine.gd
- scripts/production_sandbox_ui.gd
- scripts/production_sandbox_ci.gd
- scripts/single_house_world.gd (ÜRETİM / TARLA düğmesi)
- scripts/house_world_ci.gd (mevcut CI kapısı)

Gerçek davranış: dokunmatik ızgara, kur/sök/döndür, bina/alan seç, port eşleşmesi, stoklu demo üretim, ısı-duman-yangın-bina hasarı, tarla işlemleri. Görseller UI kontrolleriyle kodla çizilir. Bu oturumluk model gerçek Stage5 envanterini veya Stage6 kayıtlarını değiştirmez.

AÇIK: 30 modülün tamamına özgü iş akışı, gerçek dünya üzerinde çoklu bina PNG yerleştirme, iç mekân eşya sürükleme, gerçek stok ve alaşım üretim emri, tüm zincir reaksiyonları, biyolojik maruziyet ve avatar sağlığı, hayvan/ürün ekolojisi, gerçek sulama boru ağı, otomasyon AI, dayanıklı Stage6 save migration, multiplayer host, mobil test ve PCK/APK kabulü.

Sürümleme: Definition/Instance/State/Knowledge/Visual ayrı olmalı. Kalıcı işlem için atomik ledger, migration ve save replay gerekir. Yeni katalog Stage5 manifestine sessizce eklenmez; mevcut kullanıcının PNG, R2 dünya, kayıt ve karakter dosyaları korunur.

İlgili tasarım belgeleri: docs/25_CRAFTING_BLUEPRINT_DISCOVERY_DESIGN.md ve docs/26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md.

## 2026-11-07 — Yönlü ağ ve risk işlemleri, ikinci kesit

Bu bölüm önceki oturumluk prototipe eklenen gerçek kodu anlatır. Üretim hâlâ Stage5 envanterinden ayrı demo stoklarla ve Stage6 kaydını değiştirmeden çalışır.

- **Döküm güvenliği:** Kalıp bağlanmadığında cevher kaybolmaz; ancak giriş/çıkış portlarına doğru bağlanan fırın → pota → kalıp zinciri stok üretir. Körüğün doğru yönden fırına hava vermesi üretim hızını artırır.
- **Baca/vananın fiziksel bağlantısı:** Uzaktan yerleştirilen baca tüm binayı sihirli biçimde havalandırmaz; egzoz portu gerçekten baca girişine uymalıdır. Basınç vanası da yalnız doğru kazan bağlantısında etkilidir.
- **İleri malzeme işlemleri:** Kömür ocağı kömür, testere tahta, kırıcı mıcır, öğütücü toz, dövme ocağı ve pres şekillendirilmiş metal elde edebilir. Bunlar **demo ürünleridir**; özgün alaşım/blueprint instance kaydı değillerdir.
- **Yönlü kaynak grafı:** Pompa → boru → sulayıcı hattı çalışırken çevresindeki ürünü stoktan su tüketerek sular. Kesilen bağlantı otomatik sulamayı durdurur. Jeneratör → batarya → elektrik alıcısı yönlü enerji bağlantısı olarak doğrulanabilir; makine AI ve elektrikli üretim ekonomisi henüz yoktur.
- **Tehlike müdahalesi:** Makineler durunca ısı/duman dağılır; başlayan yangın yapı hasarı yaratabilir. Oyuncu su harcayarak söndürür, odun/taş harcayarak duran binayı onarır. Yakın filtre tozu azaltır. Bunlar fiziksel dünya yangın yayılımına bağlanmamış iç simülasyondur.
- **Bina belleği:** Yapı seçimi değiştirildiğinde eski makine ve ekin dizilimi oturum boyunca korunur; yeni alana geçiş çalışmayı otomatik sürdürmez. Bu, kayıt dosyasına yazma değildir.
- **Dokunmatik kullanım:** Küçük ekran için ızgara hücreleri daraltıldı, dikey seçimler, ürün seçimi, yön göstergesi, SÖNDÜR ve ONAR eklendi.
- **Regresyon:** Mevcut house_world_ci.gd içine bağlantısız baca/vananın işe yaramaması, cevher korunması, alan değişiminde düzenin korunması, sulama ve sökme, onarım/söndürme, elektrik portu rotasyonu kontrolleri eklendi. Bu satırın varlığı CI'nin geçtiği anlamına gelmez.

Hâlâ açık: otoriter gerçek crafting transaction, kalıcı Stage6 schema migration, oyunda açık alan yerleştirme, gerçek avatar zehirlenmesi, hasarın fiziksel dünyaya yayılması, mob/tarım ekolojisi, bütün modüllerin tam işlevleri ve cihaz görsel kabulü.

## 2026-11-07 — Spawn yakını görünür ev ve bilgi paneli

Kullanıcı PCK'de evi göremedi: 1254px orijinal PNG GitHub kaynak ağacında bulunmadığından önceden setup() doğrudan başarısız oluyordu. scripts/single_house_world.gd artık önce orijinal PNG'yi dener; paketli görsel yoksa Godot Polygon2D/Line2D ile temsilî ahşap kulübe çizer. Bu geçici görsel orijinal kullanıcı PNG'si değildir. İki kademeli spawn yakınında arazi/engel kontrolü, her iki görsel için tıklama, bilgi paneli İÇİNE GİR butonu ve mevcut otomatik kapı rotası kullanılır. Testlerde procedural çizim ve hitbox doğrulanır; Stage6 ve R2 kimlikleri korunur. Gerçek cihaz görsel ve dokunmatik kabulü açık kalır.
