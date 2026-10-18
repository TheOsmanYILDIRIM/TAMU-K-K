# 26 — Core, Skill ve Evrensel İçerik Sözleşmesi (Tasarım RFC)

**Tarih:** 2026-10-18. **Durum:** Kullanıcının kabul ettiği ilkeler + ayrı işaretlenmiş ileriye dönük standart önerileri. **Uygulama değil.**
**Bağlam:** TheOsmanYILDIRIM/oyun; LÖVE2D 45° izometrik Core/plazma; docs/25_CRAFTING_BLUEPRINT_DISCOVERY_DESIGN.md.
**Beyin görevi:** oyun-crafting-blueprint-discovery-design-20261018.
Bu belge ileride tanımlanacak tüm item, tool, resource, Core, skill, obje, bina, mob, robot ve tarayıcı sistemlerinin uyumlu kalması içindir. KARAR kullanıcının doğrudan belirlediği yön, ÖNERİ uygulanması ayrıca onay bekleyen mimari ilke, AÇIK ise cevaplanmamış tasarım kararı anlamına gelir.

## I. Değişmez ürün kararları

**KARAR K1 — Core ve kapasite:** Skill sayısı/kapasitesi sınırlıdır. Daha iyi veya farklı Core, boss/dungeon ödülleri, görev ödülleri ve başka özel kazanımlar kapasite artırabilir. Ne kadar artıracakları, başlangıç ve üst sınır henüz seçilmedi.

**KARAR K2 — Pahalı silme, bedelsiz değişim yok:** Skill'i kolayca çıkarıp başka skill takma sistemi yoktur. İstisnai ve pahalı skill silme yolu olabilir. Silinen skill'in seviyesi ve tecrübesi sıfırlanır. Yeniden edinilirse eski ustalık geri gelmez. Tam sökme maliyeti ve koşullar açık.

**KARAR K3 — Kullanımla ustalık:** Beceri gerçek kullanımda seviye kazanır; skill seviyesi geliştikçe verimlilik/yetkinlik artar. Skill'in sahibinde bulunması ile ustalaşması aynı şey değildir.

**KARAR K4 — Uzmanlaşma ve Tech/Magic:** Savaş/toplama/analiz/üretim gibi uzmanlıkların fırsat maliyeti vardır. Büyü ve teknoloji fraksiyon veya birbirinin birebir alternatifi değildir: bazı yetenekleri paylaşabilir, bazıları yalnız birinde, bazıları ikisi birleşince mümkün olur. Savaşçının teknoloji hammaddesini çıkarmakta zorlanması anlamlı handikaptır; bunun bedelsiz biçimde silinmesi istenmez.

**KARAR K5 — Keşif ve üretim:** Herkes temel kılıç yapabilir; aynı temel blueprint farklı materyal, işlem ve bağlantılarla farklı kalitede ve kullanım davranışlı çok sayıda item instance doğurur. Statik demir-kılıç, taş-kılıç tariflerinin her varyantı ayrı kayıt olmamalı. Görsel aile sayısı sınırlanabilir. Basit giriş, yüksek ustalık tavanı.

**KARAR K6 — Bilgiye bağlı tarama:** Malzeme kimliğini yalnız önceden tanıyan oyuncu tarama sırasında öğrenilmiş adla görebilir; tanımadığı materyalde tarama kapasitesine göre bazı ölçüm/ipuçları alır. Bilgi ve gerçek stat ayrı. Plazma deney alanı ile işlevsel blueprint/rol bağlantıları birleşir; öğrenilen tarif sonraki üretimde kolaylaşır ve ileri safhada otomasyona aktarılabilir.

## II. Definition / Instance / State / Knowledge / Visual

**ÖNERİ S1 — Ortak veri dilinin beş katmanı:**

| Katman | İçerik | Örnek |
| --- | --- | --- |
| Definition | Kanonik türün kuralları ve kimliği | CoreDefinition, SkillDefinition, MaterialDefinition, ItemDefinition, BlueprintDefinition, ObjectDefinition |
| Instance | O dünyadaki tekil nesne, sahibi, bileşimi, konumu | CoreInstance, ItemInstance, PlacedInstance, MobInstance |
| State | Değişken XP, level, kondisyon, ödül, kuyruk | PlayerSkillState, ItemCondition, ProgressionState, WorkOrder |
| Knowledge | Oyuncunun bildiği/kısmen bildiği özellikler | MaterialKnowledge, BlueprintKnowledge, ScanRecord |
| Visual | Sınırlı sprite/efekt ailesi | VisualProfile, material_family |

Gerçek malzeme ve üretim özellikleri Knowledge veya Visual katmanından türetilemez; Knowledge, oyuncuya hangi gerçeğin ne ölçüde gösterileceğini belirler.

**S2 — Kimlik ve sürüm:** Definition ID kalıcı, namespaced ve mevcut katalog doğrulama kurallarıyla uyumlu. Item/placed/Core instance ID tekil ve çakışmasız. schema_version, catalog_version ve stat türetme kurallarının ruleset_version bağı açık. Eski ID'yi yeni anlamla yeniden kullanma; unknown ID'ye uydurma varsayılan eşya üretme. Kanonik JSON → paketleme için generated Lua; generated registry elle ana kaynak olarak düzenlenmez.

**S3 — Tipli kabiliyetler:** Skill veya cihazın katkısını adlandırılmış capability/effect kaydıyla tanımla. JSON'a serbest çalıştırılabilir kod gömme. İstemci/cosmetic tarafı world/item/skill gerçeklerini değiştirmez. Mantık/render ayrımı korunur.

## III. Core kapasitesi ve skill yaşam döngüsü

**S4 — CoreDescription/PlayerState sınırı:** Core tanımı hangi skill bütçesini ve özel capability'leri sağladığını ifade eder. Takılı Core bir instance olarak tutulur. Oyuncunun kalıcı skill yetkinlikleri, takılı skill kimlikleri, seviye ve XP kayıtları ayrı tutulur. Bir Core değişimi, skill kalıcı bilgisini kendiliğinden yok sayan rastgele bir yeniden doğuş değildir (Core ve bilinç arasındaki kesin mülkiyet açık).

**S5 — Kapasite muhasebesi:** Etkin kapasite = takılı Core tabanı + uygun benzersiz kapasite kazanımları + ileride ayrı onaylanmış eklentiler. Boss/quest grant tekil reward ID, kaynak event'i, owner ve sürüm ile tek kez sayılır. Bir skill'in 1 veya daha çok yuva tüketebileceği model genişlemeye açık olabilir; maliyet rakamları henüz sabitlenmedi.

**S6 — Yeni skill yükleme:** Oyuncu yeterli kapasite ve edinme koşulu olmadan yeni skill alamaz. Başarılı kurulum kalıcı unique skill ID, XP/level başlangıcı ve transaction ID üretir. Ücretsiz aktif loadout değişimi, kesin kullanıcı kararıyla çatışır; böyle bir mekanik varsayılmayacak.

**S7 — Skill kullanımı:** Doğrulanmış anlamlı aktivite XP kazandırır. Eylemin zorluk/verim başarısı ve skill seviyesi işlem katkısını etkileyebilir; somut eğriler açık. AFK tuş basma, aynı eylem event'inin replay'i, düşük zorluklu sonsuz spam gibi istismarları reddet. Level artışı, XP olayı ve kalıcı kayıt aynı yetkili işlem sınırında olmalı.

**S8 — Skill silme:** Pahalı ve açık onaylı silme işlemi ön koşul/cost doğrulama + skill kaldırma + level/XP sıfırlama + kapasite boşaltma + tekil ledger kaydını **bir atomik transaction** olarak yapmalı. Başarısız commit ne malzeme kaybettirir ne XP siler. Silinen skill sonradan yeniden edinildiğinde eski XP geri yüklenmez. Silme maliyeti, ritüel/istasyon veya eşya türü açık oyun kararıdır.

**S9 — Kapasitesi düşük Core'a geçiş:** Skill veya XP sessizce silinmez. **Varsayılan güvenli öneri:** Mevcut skill yükünü taşımayan Core'a geçiş reddedilir; oyuncu gerekiyorsa ayrı pahalı silme kararı verir. Bedelsiz pasif skill havuzu ile Core değiştirip build takası yapma yolu oluşturulmaz. Farklı politika kullanıcıya ayrıca sunulmadan kullanılmaz.

**S10 — Bilgi hafızası:** Skill silmek, skill level ve ilgili aktif yeteneği sıfırlamalı; önceden keşfedilmiş madde ve blueprint bilgisini otomatik yok etmemeli. Bu ayrım **tasarım önerisi**, henüz kullanıcıdan nihai onay bekler. Eski yapılmış bir eşya/yerleştirilmiş bina silinen skill yüzünden yok olmaz, ancak yeni bir etkinlik skill gerektiriyorsa yeni işlemde kontrol edilir.

**S11 — Ayrı gelişimler:** Genel level, Tech Level, Magic Level, skill level, Core türü ve eşya statı ayrı kavramlardır. Aynı seviyeye tek bir sayıya sıkıştırma; birbirlerine katkıları tanımlı, test edilebilir yollarla olabilir. Bugünkü aura bucket değerleri oyun ilerleme kuralları değildir.

## IV. Capability modeli ve fırsat maliyeti

**S12 — Yetkinlik kontrolü:** Oyundaki her eylem aynı soruyu sorar: "hangi capability hangi güç/koşul/maliyet ile sağlanıyor?" Bu capability bir skill, Core özelliği, cihaz, yapı, robot veya bunların kombinasyonundan gelebilir. Kaynak bağımsız olmak **eşdeğer sonuç** demek değildir.

| İstek | Örnek olası yollar | Fırsat maliyeti |
| --- | --- | --- |
| Malzeme tarama | Core analiz yeteneği / tarayıcı cihaz / istasyon | Skill yatırımı veya cihaz/enerji/hammadde |
| Derin maden kazma | Kazı ustalığı / daha yavaş gelişmiş ekipman / iş bölümü | Skill, ekipman ve yüksek maliyetli kaynak erişimi |
| Hassas malzeme işleme | Plazma yeteneği / tezgâh/makine / karma | Becerinin seviyesi, ısı/enerji, makine |
| İleri teknoloji veya büyülü etkileşim | Bazılarında tek yol, bazılarında ortak iş | Aynı etkiyi vermek şart değil |

**S13 — Softlock kontrolü:** Savaş uzmanlığının madeni çıkarmada sıkıntı yaşaması istenen bedeldir. Ancak ileri madencilik cihazının hammaddesine erişmek için **zaten o cihaz gerekiyorsa** ilerleme mantığı çıkmaza girebilir. Düşük verimli başlangıç yöntemi, kaynak ticareti, kurtarma/salvage, keşif, ortak oyuncu yardımı veya robot desteği gibi alternatifler değerlendirilebilir. Bunlar bedelsiz ileri uzmanlık eşdeğeri olmak zorunda değildir; kesin çözüm sonraki denge kararıdır.

## V. Tüm item/tool/object/building/mob/robot içerik standartları

**S14 — İşlevsel blueprint:** Sword/Bow/Axe/Scanner/Generator/Wall gibi temel arketip, 3×3 grid yerine malzeme işlevi, parça rolleri, bağlantılar, üretim prosesi ve gerekli capability anlatır. Her malzeme/proses kombinasyonu yeni sabit katalog ID'si yaratmaz.

**S15 — Dereceli malzeme uygunluğu:** Sertlik, tokluk, yoğunluk, esneklik/enerji geri kazanımı, işlenebilirlik, iletkenlik, büyü uyumu gibi çok boyutlu niteliklerden performans çıkar. Çoğu durumda oyuncuya matematik hesabı zorunlu tutan "stat X > 60" kilidi değil, anlaşılır ödünleşim göster. Fiziksel olarak işlemesi imkânsız uç durumlar gerekçeli engel olabilir. Yayda salt esneklik değil enerjiyi geri verebilme; kılıçta salt sertlik değil darbe tokluğu da önemlidir.

**S16 — ItemInstance:** İlgili arketip kimliği, role→material bağları, proses ve üretim kurallarının versiyonu, kondisyon, sahibine ait gerçek instance ID, türetilen statların kontrol sürümü saklanabilir. Aynı görsel kategorideki iki kılıcın hızı/dayanıklılığı farklı olabilir. Kondisyonu veya bileşimi farklı eşya yanlış biçimde tek def_id/count stack'ine dönüşmez.

**S17 — Tarama ve knowledge:** Oyuncu bilinmeyen malzemeyi ileri taramayla otomatik isimlendiremez. Sınırlı ölçüm yapar; tanıdığı malzemede kimlik ve daha önce öğrenilen özellikler çözülür. Tarama kaydı, malzeme statı ve blueprint rol bilgisi ayrı katmanlardır; sonradan gelen bilgi eski taramayı anlamlandırabilir. UI/log/multiplayer verisi bilinmeyen bilgiyi sızdırmamalı.

**S18 — Kolay üretim ve ustalık:** Başlangıç oyuncusu "Kılıç yap" gibi tek eylemle uygun malzemelerden çalışan ürün alabilir. İsteyen, role/process/synergy ile derin tasarım yapar. Örneğin hızlı/sağlam/dengeli yardımcı seçimleri **öneridir**. Başarılı varyant preset olarak kaydedilirse yeniden üretim kolaylaşır; otomasyonda aynı preset kullanılır.

**S19 — Dünya objesi ve yapı:** World resource ve placed structure aynı tür gibi saklanmaz. Placed instance kimliği, owner, transform, footprint, malzeme durumu, işlevsel istasyon tag'leri, collision/zemin/su kontrolleri belirgindir. Yarım inşa ve tamir ileride state olabilir; bunlar mevcut Stage5 veya save_v2 ile bugün uygulanmış değildir.

**S20 — Mob/robot üretimi:** Yardımcı canlı/robot yalnız erişebildiği malzeme, araç, enerji, rota ve izin verilen capability ile iş emrini yürütebilir. İkinci gizli tarif motoru kurulmaz; öğrenilmiş blueprint'i ve malzeme/rol bağlantılarını kullanır. Client sahte drop, işlem veya skill XP üretmez.

**S21 — Görsel sınırı:** Az sayıda siluet ve malzeme/görsel aile seçeneği, çok sayıda item instance'ı gösterebilir. Görselin türü fiziksel statı veya oyuncunun bilmediği tam malzeme adını otomatik ifşa etmez.

## VI. Her yeni tanım için kontrol kapısı

**S22 — Tanım ekleme şartları:**

1. Stable ID, schema/catalog/ruleset version ve sahibi tanımlanmalı.
2. Definition/Instance/State/Knowledge/Visual sınırlarına uyumlu olmalı.
3. Hangi role, malzeme özelliği, skill/capability ve proses kullandığı açıklanmalı.
4. Malzeme ve nesne taramasının neyi açtığı, neyi gizlediği belli olmalı.
5. Stat ve kondisyon güncellemesi açıklanabilir, deterministik ve versiyonlu olmalı.
6. Yeni statik tarif patlaması veya herkes için evrensel en iyi malzeme yaratmamalı.
7. Hasat, craft, trade, skill XP, boss reward, bina veya robot işi kalıcı işlem ID/ledger ile tutarlı olmalı.
8. Eski katalog/world/save sürümleri korunmalı; migration veya açık uyumsuzluk bilgisi bulunmalı.
9. Portrait/touch HUD, görsel aile ve erişilebilirlik doğrulama kapsamı olmalı.
10. Lua/JSON parity, gerçek LÖVE, Android ve multiplayer host test sınırları belirtilmeli.

Bu kontrol listesi gelecekteki işlerin tasarım kabul ölçütüdür; şu anda CI tarafından uygulanmıyor.

## VII. Save, atomiklik, ağ ve testler

**S23 — Stage5/Stage6 ile açık sınır:** Mevcut inventory çoğunlukla def_id+count taşır; farklı bileşimli tool, skill, CoreInstance ve bilinçteki knowledge için yeterli değildir. Stage6 love-world-v2 schema bu yeni alanları bugün içermez ve ilave alanlara kapalıdır. Aynı şemaya sessiz ekleme yapma; yeni sözleşme + versioned migrator + negatif test + ilgili Stage6 sahibinin koordinasyonu gerekir.

**S24 — Olay muhasebesi:** Skill edinme/seviye, pahalı silme, Core değişimi, boss ödülü, malzeme/blueprint keşfi, crafting, bina yerleştirme, taşıma ve gelecekte robot iş emri tekrar edilebilir benzersiz command/event ID ve monoton revision ile yürür. Bir eylem envanter, skill veya dünya state'ini birlikte etkiliyorsa **ya tamamı durable commit olur ya hiçbiri**. RAM'i önce canlıya yayıp başarısız disk yazımından sonra başarı iddia etme.

**S25 — Fail-closed:** Eksik Definition/instance/material/skill ID, katalog veya generator sürüm uyuşmazlığı, corruption ya da snapshot tutarsızlığı önceki sağlam kaydı kaybetmeden read-only/quarantine olur. Eski eşya yerine sahte taş koyma; Core kapasitesi azalırken skill XP silme; ödülü aynı event ile iki kez kabul etme yasak.

**S26 — Gelecekte doğrulanacak testler:**

- Kapasite doluysa skill kurulmaz ve hiçbir veri değişmez.
- Aynı boss reward tekrarlanırsa kapasite bir kez artar.
- Gerçek skill kullanımı XP kazandırır; aynı event tekrar XP üretmez; boş/AFK eylem istismarı sınanır.
- Sökme başarısızsa maliyet ve XP korunur; başarılıysa skill ve level/XP sıfırlanır.
- Core düşürmesi bedelsiz skill swap'a veya sessiz veri kaybına dönüşmez.
- Bilinmeyen madde taramada kimlikle sızmaz; tanıdığında tanımlanabilir.
- Aynı blueprint farklı materyalle farklı item instance üretir; uygunsuz item stack birleşmesi reddedilir.
- Skill silinince kazanılmış world object/item ve önceden edinilmiş Knowledge kaybolmaz (bu kuralın kullanıcı onayı ayrıca alınacak).
- Skill/Tech/Magic yollarında yetkinlik ve maliyet ayrımı korunur; fiziksel ilerleme çıkmazı testi yapılır.
- Crash/rollback/duplicate command ve save migrator negatif testleri çalışır.
- Lua5.4/LuaJIT, kanonik JSON↔Lua parity, LÖVE/Xvfb, gerçek Android ve multiplayer test kanıtları birbirine karıştırılmaz.

## VIII. Henüz kullanıcıyla kararlaştırılacaklar

**AÇIK A1:** Başlangıç skill kapasitesi, skill başına maliyet, Core artış miktarı, görev/boss kapasite ödülleri ve üst sınır.

**AÇIK A2:** Skill'in kalıcı sahibi oyuncu bilinci mi Core instance mı? Önerim oyuncu bilinci: Core kapasite sağlar; beceri seviyesi Core değiştirilince kaybolmaz. Ancak düşük kapasiteye geçiş reddi kuralı kullanıcı tarafından ayrıca seçilmeli.

**AÇIK A3:** CapacityGrant oyuncu kazanımı mı Core'a gömülü modül mü, yoksa iki ayrı kaynak mı? Tekrar alınması ve transfer kuralları.

**AÇIK A4:** Pahalı skill silme için kaynak/ritüel/istasyon, işlem süresi ve yeniden edinme yöntemi.

**AÇIK A5:** Skill XP eğrisi, level üst sınırı, risk/zorluk karşılığı ve oyun ekonomisi.

**AÇIK A6:** Silinen skill'in önceden kazandırdığı Knowledge korunması önerisinin kesin onayı.

**AÇIK A7:** Aynı malzemenin işlenmesinde oyuncu becerisi, proses/mini-deney ve başarı olasılığı ile final stat ilişkisi.

**AÇIK A8:** Kaynak erişimindeki uzmanlık dezavantajlarının kabul edilebilir boyutu ve anti-softlock erişim yolları.

**AÇIK A9:** Core ve karakter level/Tech Level/Magic Level ilişkileri; ayrı mekanik ve ödül eğrileri.

**AÇIK A10:** Mob/robot ownership, knowledge transfer, ticaret, dünya inşa ve multiplayer yetkileri.

## IX. Uygulama sırası ve koruma

Önce bir örnek dikey kesitte iki Core, birkaç skill, bir Sword blueprint, bir bilinmeyen metal, bir tarayıcı, bir maden ve bir station prototipinin oyuncu deneyimini kavramsal olarak sınayın. Sonra yalnız kullanıcının onayından sonra sürümlü tanım şeması ve test kontratları; ayrı uygulama dalı, Stage6 ile gelecekte yazılı entegrasyon.

**Bu turda hiçbir kod, şema, save, build, main veya Stage6 dalına uygulama yapılmaz.** Korunacaklar: backup, Core/Axe, plazma, fizik/kamera, World/Object/Terrain Studio, stüdyolar, PNG ve bütün kullanıcı kayıtları.


---

## X. 2026-10-18 — Core statları, skill ve yükseltme: güncel kararlar

> **Durum:** Kullanıcı tarafından seçilen kararlar, yalnızca önerilen mekanik ayrıntılardan ayrı tutulur. Önceki açık soru ve tarihsel RPG/meslek-skill taslaklarıyla çelişen bu bölüm güncel tasarım yönüdür; uygulanan oyun kodu, katalog ya da save şeması değildir.

### Kabul edilen kararlar

1. **Skill yaklaşımı:** Hazır RPG skill/feat sistemi taşınmayacak; **feat ağacı gereksiz**. Skill'lerin çoğu sadece verimi yükseltmek yerine **önceden yapılamayan eylemi açar**; kullanılan beceri XP/seviye ile ayrıca gelişir. Tüm skill listesini bugünden kararlaştırmak gerekmez. Genel bir Madencilik skill'i zorunlu değildir; örneğin belirli ore'ları tespit eden, bazılarını daha verimli çıkaran veya baltaya enerji aktararak özel darbe açan işlevsel skill'ler tasarlanabilir.
2. **Core seviyesi ve yükseltme:** Her fiziksel Core seviyesi artırılabilir; nadir/toplanması gereken malzemeler ve **zor bir yükseltme işlemi** gerektirir. Yükselen Core seviyesi **statların üst limitini** ve **normal skill slot kapasitesini** artırır. Eşikler, tarifler ve maliyetler henüz seçilmedi.
3. **Ortak Core gelişim sistemi:** Standart ve özel Core'lar **aynı Core Level sistemine** uyar. Aynı Core seviyesinde hem **altı temel statın ortak üst sınırı** hem de **normal skill slot sayısı** bütün Core türlerinde aynıdır. Özel Core, aynı seviyede stat tavanını veya normal slot sayısını arttırmaz; altı stat için ayrı ayrı zorunlu tavan farkları da yoktur.
4. **Özel Core farkı:** Yeni özel Core, boss/keşif/üretim gibi yollarla elde edilebilir; **dahili özel skill/yetenek** sağlar ve bu yetenek **normal skill slotu tüketmez**. Ayrıca belirli işlerde **verimlilik avantajları** sağlayabilir. Hangi skill, etki ve bonus değerleri olduğu henüz belirlenmedi.
5. **Core değiştirme yönü:** **B — yeni bir fiziksel Core edinip bilinç transferiyle değiştirme** seçildi. Mevcut Core'un zorunlu dönüştürülmesi tek yöntem sayılmaz. Transfer bedeli, şartları, düşük seviyeye geçiş ve anlık etkiler henüz kesinleşmedi.
6. **Korunan önceki kararlar:** Normal skill kapasitesi sınırlı; kazanılmış normal skill'in pahalı silinmesi XP/level'ını sıfırlar; bedelsiz loadout takası yok. Boss/görev gibi özel kapasite kazanımları fikri, keşfedilmiş MaterialKnowledge, Tech/Magic ayrımı ve Definition/Instance/State/Knowledge/Visual sınırları korunur. Özel kapasite ödüllerinin ortak Core-level slot formülüne **nasıl ekleneceği henüz açık**.

### Temel statlar: kabul edilmiş yön, henüz nihai isim/formül değil

Kullanıcı **büyüsel-teknolojik adlandırma** yönünü seçti. Aşağıdaki altı çalışma ismi ve mekanik sınırı değerlendiriliyor; **nihai stat kataloğu, sayısal formüller veya tam stat kazanım kuralları onaylanmış sayılmaz**. Rezonans için özellikle **A — dış varlık ve bağımsız sistemlerle bağ/senkronizasyon** yaklaşımı tercih edildi.

| Çalışma adı | Temel işlev | Dışarıda tutulan |
| --- | --- | --- |
| **Etkime** | Plazmayla mekanik etki ve kuvvet yaratma | İsabet, enerji deposunun hacmi |
| **Hâkimiyet** | Kendi plazmasının yönünü, biçimini ve hassasiyetini kontrol | Ham kuvvet, yabancı sistemle karşılıklı bağ |
| **Kararlılık** | Core/plazma düzenini zorlanmaya karşı koruma | Depolanan enerji miktarını doğrudan belirleme |
| **Duyarlılık** | Çevresel sinyal/değişimleri algılama | Bilinmeyen malzemeye otomatik isim verme |
| **Biliş** | Algılananı yorumlama, öğrenme, ilişkilendirme | Keşfedilmemiş bilgiyi yoktan bilme |
| **Rezonans** | Canlılar, bağımsız varlıklar veya özel enerji düzenleriyle karşılıklı uyum/senkronizasyon | Genel enerji gücü, sıradan robot kumandası ve bütün büyüler |

**Eylem ayrımı:** Normal balta darbesi stat/araç koşullarıyla mümkündür; enerji yüklemeli balta darbesi için ilgili **skill eylemi açar**. Ore algılama skill'i yeni sinyallere erişebilir ama bilgi kaydı yoksa ore kimliği açılmaz. Evcilleştirme/bağ kurma için ilgili skill ve canlı koşulları gerekir; yüksek Rezonans tek başına evcilleştirme değildir. Her eylem bütün statları kullanmak zorunda değildir.

### Yeni içerikler için teknik yön (ÖNERİ; uygulanmış sözleşme değil)

- SkillDefinition kimlik/sürüm, **açtığı capability/eylemler**, önkoşullar, tipli etkiler, enerji/malzeme/süre maliyeti ve kullanım XP ilerlemesini taşıyabilsin; PlayerSkillState edinim ve XP/level'ı saklayabilsin. Bağımsız feat/proficiency veya genel meslek skill ağacı zorunlu değil.
- Normal skill, **Core dahili skill'i (slot maliyeti 0)** ve cihaz kaynaklı capability aynı eylem denetimine bağlanabilsin; çift aktivasyon/çift XP üretmesin.
- Taslak denge fonksiyonları: **common_stat_cap(core_level)** altı stat ve bütün Core türleri için ortak; **normal_skill_slots(core_level)** aynı seviyedeki bütün türlerde ortak. Bunlar yalnız sınırdır; mevcut kazanılmış statları otomatik artırma değildir.
- Bilinç transferinde kazanılmış stat/skill XP'si ve Knowledge'ın korunması, daha düşük limit durumunda etkin stat bastırma veya transfer reddi, Core dahili skill XP'sinin sahibi ve mevcut normal skill yüküyle düşük kapasiteli Core'a geçiş **ayrı kullanıcı kararı bekler**. Hiçbir ilerleme sessizce silinmeyecek veya bedelsiz skill takası varsayılmayacak.
- Fiziksel Core instance, bilinç gelişimi, skill XP, bilinç bilgisi, özel kapasite ödülleri ve Core türü tanımları sürümlü/kimlikli kalmalı. Mevcut Stage5/Stage6 save_v2 veya üretim kataloğu bu kararla **değiştirilmez**.

### Hâlâ açık kalanlar

Stat adlarının nihailiği ve statların gelişme yolu; Core level / ortak tavan / slot sayısı / yükseltme maliyeti; bonus kapasite ödülleri ile ortak slot hesabı; Core transferinde XP/Knowledge, düşük Core ve dahili skill ustalık davranışı; başlangıç skill örneklerinin XP/işlev dengesi; Tech ve Magic level ilişkileri.

**Kapsam koruması:** Yalnız tasarım. Main, backup, Stage6 deney dalı, Core/Axe/plazma, fizik/kamera, stüdyolar, katalog, save, kullanıcı verileri veya runtime kodu değiştirilmez.


---

## XI. 2026-10-18 — Kullanıcı kararı: karakter puanı, Core tavanı ve stat V1 uygulaması

### Kabul edilen gelişim kuralları

- **Karakter Level:** Genel karakter XP'si kazanılır; level atlanınca oyuncuya istediği statlara dağıtabileceği puanlar verilir. Statların **kullanım XP'si YOKTUR**. Genel XP; anlamlı toplama/üretim/inşa, keşif, savaş veya görev gibi etkinliklerden sağlanabilir; somut kaynak/miktarlar ayrıca dengelenir.
- **Skill Level:** Skill'ler **kullanılınca kendi XP'sini** kazanır; çoğunun birincil amacı yüzdelik verim yerine **daha önce mümkün olmayan eylemi açmaktır**. Genel karakter XP'si skill XP'sinin yerini almaz. **Feat/proficiency katmanı yok.** Tam skill listesi bugünden sabitlenmeyecek.
- **Core Level:** Fiziksel Core yalnız zorlu, malzemeye dayalı yükseltmeyle gelişir; **bütün Core türlerinde aynı Core level → altı statın ortak tavanı ve normal skill kapasitesi** kuralı geçerlidir. Özel Core'lar aynı seviyede daha yüksek tavan/slot alamaz; ancak **0-slot dahili skill** ve verimlilik avantajı getirir.
- **Stat çalışma adları** (nihai değil): Etkime, Hâkimiyet, Kararlılık, Duyarlılık, Biliş ve Rezonans. Rezonansın kabul edilen kavramsal yönü dış canlı/bağımsız düzeneklerle **bağ ve senkronizasyon**dur; bütün büyü/teknoloji eylemlerinin zorunlu statı değildir.
- **Core edinimi:** Yeni Core elde edilerek bilinç transferi yapılabilen yol tercih edildi. Kazanılmış stat/skill XP mülkiyeti, düşük Core'a geçiş ve transfer maliyeti hâlâ ayrıca kararlaştırılacak. Daha önceki kayıpsızlık ve pahalı silme ilkeleri korunur.

### V1 kodlanmış çalışma sınırı

- game/love/progression/rules.lua: altı stat ID'si; stat tavanı, normal slot ve karakter XP/puan konfigürasyonu. **Denge sayıları yalnız prototiptir, onaylı ekonomi değildir:** Core Lv1 stat tavanı 10 ve 2 normal slot, sonraki Core level başına +5 stat tavanı ve +1 slot; karakter level başına 2 dağıtılabilir puan ve bir sonraki karakter seviyesi için 100× mevcut seviye XP. Maksimum teknik seviye sınırı 1000 bir oyun tasarım kararı değildir.
- game/love/progression/character.lua: genel XP event ledger (idempotent), stat puanı dağıtımı, 6-stat ve eşit Core tavanı kontrolü; type-safe, sürümlü snapshot/restore ve bozuk kayıt reddi. **Stat kullanımı XP kazandırmaz.**
- game/love/progression/skill_contract.lua: gelecekteki SkillDefinition için namespaced ID/version, açılan capability, varsa stat ilişkileri, kullanım XP modu ve skill kaynağı (learned: 1 slot, core_innate: 0 slot) doğrulayıcısı. **Bunlar henüz takılabilir gerçek skill veya feat değildir**; gelecekteki içerik kodu için fail-closed yazar sözleşmesidir.
- game/love/progression/hud.lua ve game/love/main.lua: mobil STATS paneli/klavyede P, düz puan dağıtımı ve mevcut **Stage5 RAM** harvest/craft/build başarılı olaylarından prototip karakter XP'si. Mevcut savaş/fizik/enerji, aura paleti, kaynak ekonomisi veya hitbox üzerinde yeni stat çarpanları uygulanmaz; sayısal etkileri daha sonra kararlaştırılır.
- **Kalıcılık açık engeli:** V1 stat state **oturumluk**; açıkça SESSION ONLY / NOT SAVED yazılır. Mevcut Stage6 save_v2 strict schema yeni alanları kabul etmez. Stage6 explicit domain işlemlerinden XP verilmez: dünyaya durable commit yapılıp başka dosyada XP yazılması **atomik olmayan** bir split-transaction yaratır. Gerçek kalıcı progression için onaylı versioned save migrator, world event ledger entegrasyonu, fail-closed restore, corruption/rollback/duplicate negatif testleri ve gerçek cihaz doğrulaması gereklidir. Var olan save_v2 dosyalarına yazılmaz.
- **Henüz uygulanmamış:** Gerçek skill edinim ve kullanımla XP; Core level yükseltmenin malzeme/istasyon işlem entegrasyonu; bilinç transferi; Core dahili skill çalıştırma; Tech/Magic ilerlemesi; boss/quest kalıcı slot ödülü; keşif/savaş/görevlerden canlı XP; statların güç/hareket/algı gibi aktif oyun formüllerine etkisi. Bunlar otomatik çalışıyor olarak gösterilmez.

### Test standardı

- tests/core_stat_progression.lua: stat tavanı/puan, karakter level/XP, olay replay reddi, strict snapshot round-trip/tamper reddi, SkillDefinition capability ve mobil panel hit-test.
- quality CI: Lua 5.4 + LuaJIT, mevcut Core/Stage5/Stage6 regresyonları ve gerçek LÖVE/Xvfb stat panel screenshot smoke. Test sonucu ayrıca Actions üzerinde doğrulanacak.
- Android gerçek cihaz, kalıcı/atomic save_v3 ve multiplayer host yetkisi doğrulanmadan gerçekleşmiş sayılmaz.

**Not:** Önceki VIII/IX/X bölümlerindeki "stat XP açık", "bu tur kod yok" ve "prototip yok" ifadeleri **önceki tasarım zamanına** aittir; bu bölüm bunları yalnız bu yeni V1 için geçersiz kılar. Sayısal tuning ve statların nihai isimleri yine açık kalır.
