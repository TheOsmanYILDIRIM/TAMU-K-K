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
