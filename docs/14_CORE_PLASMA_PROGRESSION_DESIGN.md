# Yeni 2D izometrik oyun — çekirdek, plazma ve gelişim tasarım kararları

> Tarih: 2026-10-16. Durum: konsept kararları; henüz uygulanmış özellikler değil.
> Kapsam: `TheOsmanYILDIRIM/oyun` deposundaki sıfırdan geliştirilen LÖVE2D / Lua tabanlı **2D izometrik** survival-crafting oyun. Mineclonie veya eski 3D/Godot prototipi değil.

## Oyun ve dünya

- Keşif, hayatta kalma, kaynak toplama, crafting, inşa ve gelişim ana motivasyonlar. Karakter draması, roleplay, kozmetik koleksiyonu veya hikâye ana oyun döngüsü değil.
- Multiplayer desteklenir; sürekli çevrimiçi/live-service bir oyun hedeflenmez. P2W ve kozmetik satışına göre tasarım yapılmaz.
- *Defiance of the Fall* türü sistem-entegrasyonu fikrinden esinlenen **özgün** kurgu: Evrenleri kapsayan bir Sistem Dünya'yı da içine almıştır. İnsan bilinçleri hayatta kalma, öğrenme ve gelişim sınavı için başka bir test dünyasına aktarılır.
- Oyuncu bir taş golem **değildir**. Bilinci taşıyan merkez, belirli bir metal/alaşımla hazırlanmış **büyülü-teknolojik bir icat olan core (çekirdek)**tir. Core, bilincin plazmayı kontrol etmesini ve çevreye müdahale etmesini sağlar. Başlangıçta tüm oyuncular temel çekirdekle başlar.
- Çevredeki plazma, hareket, etkileşim ve araç kullanımının görsel/işlevsel temsili. Tam insan/insansı model ve karmaşık rig animasyonuna bağımlı kalınmaması hedeflenir.
- Balta, kazma ve diğer ekipmanlar çekirdeğin/plazmanın kontrolüyle bağımsız hareket edebilir. Başlangıç uygulamasında araçların konum, dönüş ve zaman eğrileriyle animasyonu tercih edilir.

## İstatistik ve aura görselleştirmesi

- Her ana statın tanımlı bir rengi olacak. Kesin stat listesi/palet **henüz kararlaştırılmadı**.
- **Model 1 benimsendi:** en baskın stat ana plazma/aura rengi, ikinci baskın stat ikincil vurgusu. Düz ve kontrolsüz tüm-RGB karışımı yerine okunabilir renk katmanları. Core türü ile stat rengi karıştırılmamalı.
- Renk dağılımı her küçük stat artışında değişmeyecek; oranları belirli adımlara bölüp kesirli kısmı atarak basamaklandırma uygulanacak. Önerilen başlangıç basamağı **%10**, ancak ayarlanabilir parametre olacak.
- Örnek taslak: `p_i = 100 * stat_i / sum(all_stats)`; `bucket_i = floor(p_i / step) * step`. Sıfır toplam ve eşit ağırlık durumları özel ele alınmalı. Ham statları doğrudan 10'a bölmek ile normalize oranı bölmek farklı sonuç verir; nihai görsel eşleme prototipte doğrulanacak.
- İki baskın statın küçük değer değişimleriyle sürekli yer değiştirmesi durumunda görsel titremeyi önleyecek geçiş eşiği/histerezis değerlendirilecek.
- Level arttıkça **plazma miktarı/hacmi** ve **yoğunluğu/kararlılığı** farklı boyutlar olarak değişebilir. Her level'da görünür artış **olmayacak**; sınırlı sayıda gelişim eşiği kullanılacak. Kesin maksimum level, eşikler ve artış eğrileri kararlaştırılmadı.
- Kalabalık 2D izometrik sahnelerde, özellikle mobilde, hitbox ve oyuncu silueti okunabilir kalacak; aşırı bloom, büyük yarı saydam bulutlar ve çok sayıda parçacık kullanılmayacak.

## Gelişim eksenleri

- Genel karakter gelişimi/statlar ve level sistemi bulunacak.
- **Tech Level** ayrı bir gelişim ekseni olarak planlanacak: teknoloji, makineler, enerji/otomasyon, üretim altyapısı gibi sistemlerle ilişkisi tasarlanacak.
- **Magic Level** ayrı bir gelişim ekseni olarak planlanacak: büyü, plazma hâkimiyeti, büyülü etkileşimler gibi sistemlerle ilişkisi tasarlanacak.
- Tech Level ve Magic Level'ın deneyim kaynakları, ilerleme eğrileri, açtıkları tarifler/özellikler ve genel level ile ilişkileri **henüz kesinleşmedi**. Bunlar ayrı kavramlar olarak korunacak; tek bir level'a sessizce indirgenmeyecek.

## Özel core türleri ve ödüller

- **Crafter Core, Techno Core, Elemental Core** gibi nadir/özelleşmiş çekirdekler başlangıç sınıfı veya ücretli kozmetik **değil**; dungeon, boss, keşif ve zorlu içerik ödülleri olarak elde edilir.
- Farklı core'ların yalnızca düz sayısal bonus yerine üretim, teknoloji veya element etkileşimlerinde anlamlı işlevsel özellikler sağlaması hedeflenir.
- Core türleri ile Tech/Magic Level aynı sistem değildir. Aralarındaki gereksinimler ve sinerjiler sonra tasarlanacak.
- Core değişimi, bilinç transferi, kayıp/ölüm sonuçları ve ödül dengesi henüz açık kararlardır.
- Oyuncu ismi ve en fazla hafif temel kimlik özelleştirmesi yeterli; aşırı karakter kozmetiği tasarlanmayacak.

## Öncelikler ve henüz açık sorular

1. İlk prototip: çekirdek + kontrollü plazma, bağımsız balta/kazma hareketi, basamaklı iki-renk aura.
2. Genel level, Tech Level, Magic Level ve statların her birinin hangi eylemlerle geliştiğini, birbirlerini nasıl sınırlandırdıklarını belirle.
3. Plazmanın sadece kontrol alanı mı yoksa gerçekten biçimlenebilir bir madde mi olduğunu kararlaştır. İlk sürümde **araç kontrolü odaklı basit yaklaşım** uygun; gelecekte biçimlenebilirlik kapatılmamalı.
4. Nadir core ödüllerinin oyun döngüsü, dungeon yapısı ve denge kurallarını tasarla.
5. Level görünüm eşikleri, renk basamağı, stat paleti ve performans sınırlarını oynanabilir prototip üzerinde ayarla.

**İlke:** Oyuncunun karaktere duygusal bağlanmasını zorlayan RPG ağırlığı yerine keşfin, crafting'in, dünya üzerindeki kalıcı ilerlemenin ve oynanışta hissedilen gelişimin öncelikli olması.


---

## 2026-10-18 — Core seviyesi ve bilinç transferi: güncel karar

> Önceki bölümlerde Core türleri, stat sistemi ve transferin tümüyle açık olduğu ifadeleri tarihsel bağlamdır. **Kullanıcı tarafından seçilen yeni kararları** aşağıda ayırıyoruz; nihai stat kuralları hâlâ tasarımdadır. Ayrıntılı sözleşme: [26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md](26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md), bölüm X.

- **Core fiziksel taşıyıcıdır:** Seviye atlatılabilir, fakat bu gelişim toplanan malzeme ve zorlu bir yükseltme işlemi gerektirir. Core seviyesi arttıkça **altı statın ortak üst limiti** ve **normal skill slot sayısı** artar. Sayısal eğriler/koşullar açık.
- **Aynı seviyede eşit tavanlar:** Özel Core'lar standart Core ile **aynı Core Level sistemini**, aynı altı stat tavanını ve aynı normal skill kapasitesini kullanır. Tür bazlı yüksek stat/slot üst sınırı verilmez.
- **Özel Core'un farkı:** Kendi dahili skill/yetenekleri **slot tüketmeden** kullanılabilir; belirli işlerde ayrıca **verimlilik avantajları** sağlayabilir. Kesin yetenek ve katsayılar açık.
- **Yeni Core + bilinç transferi:** Özel/yeni Core elde edilerek bilinç başka Core'a aktarılabilir. Transfer bedeli, geçmiş stat/skill XP'sinin etkinleştirilmesi, düşük seviyeli Core'a geçiş ve dahili skill XP'sinin mülkiyeti henüz kesin değildir; geçmiş birikimi sessizce kaybetme veya bedelsiz skill değiş tokuşu kuralı türetilmez.
- **Skill yaklaşımı:** Feat ağacı kullanılmayacak; skill'lerin çoğunun asli değeri yeni eylem **açmak**, sonrasında kullanım XP'siyle ustalaşmaktır. Tüm skill listesi şimdiden sabitlenmez, genel “madencilik” skill'i zorunlu değildir.
- **Stat isimleri henüz taslak:** Etkime, Hâkimiyet, Kararlılık, Duyarlılık, Biliş ve Rezonans büyüsel-teknolojik adlandırma yönüdür. Rezonans için dış canlı/bağımsız sistemlerle **bağ ve senkronizasyon** anlamı seçildi; nihai stat formülü ve isim onayı henüz verilmedi.

**Uygulama sınırı:** Bu kayıt yalnız tasarım; çalışma motoru, shader, aura, save_v2, Stage6, envanter ve katalog sözleşmelerini değiştirmez.

## 2026-10-18 — Karakter Level stat puanı V1 (uygulama kanıtı)

- **Kullanıcı kararı:** Genel karakter seviyesi atlandığında stat puanı verilir; oyuncu serbestçe altı stat arasında dağıtır. Statların ayrı kullanım XP'si **yoktur**. Skill'lerin kullanım XP'si bundan bağımsızdır.
- **Uygulama:** progression/rules.lua, character.lua, hud.lua ve skill_contract.lua ile saf domain + mobil stat ekranı; game/love/main.lua içinde yalnız RAM Stage5 başarılı harvest/craft/build eylemlerinden karakter XP. Dahili Core yeteneği 0 normal slot, öğrenilmiş skill 1 normal slot standartları tanımlandı; gerçek yeni skill listesi ve çalışma motoru daha sonra geliştirilecek.
- **Prototip değerleri:** Core Level 1 stat tavanı 10, iki normal skill slotu; sonraki Core seviyelerinde +5 tavan/+1 slot; karakter seviyesi başına 2 dağıtılabilir puan. **Sayılar henüz dengesi onaylanmamış geçici ayarlardır.** Aynı seviyedeki bütün Core türlerinin limitleri aynıdır.
- **Kalıcılık engeli:** V1 stat ilerlemesi oturum sonu kaybolur; Stage6 save_v2 şeması değiştirilmedi, explicit Stage6 işlemlerinden XP verilmez. Ayrı durable stat dosyası yazıp iki transaction'ı sahte atomik göstermeyiz. Kalıcı kayıt, Core yükseltme/transfer/ödül ekonomisi ve mevcut statın fiziksel eylem etkileri ayrı sürümlü entegrasyon gerektirir.
- Güncel teknik tasarım/gap listesi: [26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md](26_CORE_SKILL_CONTENT_FOUNDATION_RFC.md), bölüm XI.
