# Ürün vizyonu ve oyun döngüsü

## Kullanıcı problemi
Luanti/Mineclonia'da Android'de iki kişi oynarken kamera, tek tek blok hedefleme, fiziksel beceri ve yoğun sanal tuşlar yoruyor. Yeni ürün bunu tekrar etmeyecek.

## Tasarım ilkeleri
- **Portrait-first**: tek elde keşif, iki elde hassas inşa; ekranın üst yarısı dünya, alt yarısı kontrol ve üretim alanı. Gerçek cihazdan geri bildirimle ayarlanacak.
- **3D izometrik**: kamera yatayda kademeli dönebilir, occlusion için duvar/çatı fade/katman gösterimi. Açıyı bozacak 3D model ihtiyacı minimum.
- **Bir dokunuş = niyet**: bir ağaca dokun → karakter erişilebilir konuma gider → uygun aleti kullanır → toplama işlemi başlar. Hedef yoksa sessiz başarısızlık değil, neden mesajı.
- **Oynama becerisi düşük, karar derinliği yüksek**: kaynak, tarif, araştırma, iş istasyonu ve otomasyon; refleks savaşı öncelik değil.
- **İki kişilik rahat iş birliği**: ortak dünya, kişisel envanter, paylaşımlı sandık ve ayrı üretim görevleri.
- **Kısa seans**: 2–10 dakika içinde ilerleme; kalıcı kayıt ve geri bağlanma güvenli.

## Çekirdek döngü
1. Görünür hedefe dokun / rota seç.
2. İş emri (gather, cut, mine, interact, haul) oluştur.
3. Uygun aleti/menzili/kaynağı doğrula ve kaynak topla.
4. Envantere/kasa taşı; recipe/istasyon gereksinimini kontrol et.
5. Craft et ve yerleşimi genişlet.
6. Yeni biyom/maden/üretim seviyesine ilerle.

## İlk oynanabilirlik testinin kabulü
İki gerçek Android telefonda 10 dakikalık seans; ağaç toplama + masa yapma + arkadaşla sandık kullanma. Başarının sayısal eşiği kullanıcının cihaz testinden sonra belirlenecek; şimdiki repo yalnız iskelettir.

## Anti-hedefler
Tam Minecraft klonu, refleks-odaklı hızlı savaş, her kaynak için benzersiz elle rigli 3D model, tek seferde devasa procedural infinite-world vaatleri.
