# TAMU · Canlılar Atlası

Fantastik ekoloji, konsept varlıkları ve rigleme **hazırlığı** için referans kataloğu. [Katalog sayfasını aç](index.html). Tür sayfaları görsel ve kısa anatomik notlar içerir.

> **Önce üretim metodunu okuyun:** [TAMU Lore Wiki — Lore'dan özgün oyun canlısına uygulamalı tutorial](../lore/README.md#uygulamal%C4%B1-rehber-loredan-%C3%B6zg%C3%BCn-oyun-canl%C4%B1s%C4%B1na). Orada bilimden esinlenen kurgu fiziği, besin zinciri, 40 fenotipik organ, anatomi denetimi, V0.3 simülasyonun sınırları, GPT Image prompt şablonu ve doğrulama kapıları anlatılır. Bu atlas o rehberin **örnek tür ve görsel koleksiyonudur**, ikinci bir kanonik kural/öğretici kaynağı değildir.

[Lore ana indeksine dön](../lore/00_INDEX.md) · [Canlılar konu indeksi](../lore/05_VARLIKLAR/INDEX.md) · [Fısıltı Ormanı bağlamı](../lore/03_DUNYA/Fisilti_Ormani.md)

| Tür | Ekoloji | Konsept |
|---|---|---|
| [Fısıltı Tavşanı](fisilti-tavsani.md) | Küçük otçul | Var |
| [Kabuk Sırtı](kabuk-sirti.md) | Orta otçul | Var |
| [Taşkabuk](taskabuk.md) | Büyük otçul | Var |
| [Yosun Gezginciği](yosun-gezgincigi.md) | Küçük otçul | Var |
| [İz Avcısı](iz-avcisi.md) | Orta yırtıcı | Var |
| [Diken Omuz](diken-omuz.md) | Büyük yırtıcı | Var |
| [Dere Pusucusu](dere-pusucusu.md) | Yarı sucul yırtıcı | Var |
| [Kırıkdiş](kirikdis.md) | Orta yırtıcı | Var |
| [Saz Sırtı](saz-sirti.md) | Yarı sucul hepçil | Var |
| [Közboğaz](kozbogaz.md) | Isı yırtıcısı | Var |

## Durum ve doğrulama sınırları

- **10 tür** isim ve ekolojik rolü, şu an **konsept adayı** olarak belgelenmiştir; türlerin kesin kanon onayı yoktur.
- **10 türün konsept görseli mevcut**: Fısıltı Tavşanı, Kabuk Sırtı, Kırıkdiş, Saz Sırtı, Közboğaz. Bu aşamada tüm 10 türün konsept görseli mevcuttur.
- Fısıltı Tavşanı için ayrı bir **yan profil RGBA referansı** da vardır. Bu yalnız rigleme girdisidir; rig, ağırlıklandırma, animasyon ya da oyun entegrasyonu kanıtı değildir.
- `manifest.json` türlere ait görsel bağlantıları ve yükleme sırasında bildirilen kaynak SHA-256 değerlerini içerir. GitHub'daki dosya yolları/commit varlığı doğrulandı; ikili PNG içeriklerinin SHA-256 değerleri bu incelemede bağımsız yeniden hesaplanmadı.
- Harita görselleri arşivde korunmuştur; bunların yeni dünya verisi olarak oyuna entegre edildiği anlamına gelmez.
- `sim.py` ve sayısal ekosistem simülasyonu bu kataloğun parçası değildir. Rehberdeki V0.3 sonuçları gerçek ekolojik/popülasyon kanıtı değil, deneysel model çıktılarıdır.

## İki katmanlı dokümantasyonun kullanımı

- **Nasıl tasarlandı?** Bilimsel esin, bağlı moleküller, besin zinciri, 40 fenotipik organ ve simülasyon kabul sınırları için [tek esas yöntem rehberi](../lore/README.md#uygulamal%C4%B1-rehber-loredan-%C3%B6zg%C3%BCn-oyun-canl%C4%B1s%C4%B1na).
- **Ne üretildi?** Bu kataloğun tür sayfaları, PNG referansları ve `manifest.json`. Tür sayfalarındaki kısa “öğretici notlar” esas rehberi **tekrarlayan ikinci bir kural seti değil**, türe özel pratik hatırlatmalardır.
- **Hangi görseller onaylı?** Fısıltı Tavşanı ve Kabuk Sırtı'nın ilk konsept görünümü kullanıcı tarafından yeterli bulundu. Diğer üç PNG için aynı düzeyde tasarım onayı henüz doğrulanmadı.
- **Oyunda mı?** Hayır: 5 yüklü konsept ve 1 yan profil olması, rig, animasyon, pet AI veya Godot entegrasyonunun tamamlandığı anlamına gelmez.
- **Eksikler:** Beş türün konsept görseli ve 10 türün tamamının motor/rig kabulü hâlâ açık.

## Yayın
GitHub deposunda `docs/bestiary/index.html` ile birlikte görseller tutulur. GitHub Pages ancak depo yöneticisi tarafından yapılandırılmışsa tarayıcı sayfası olarak sunulur; GitHub Markdown öğreticileri Pages olmadan da okunabilir.

## Kaynak notu
Yüklenen kaynak PNG'ler korunur; yalnız dokümantasyon ve bağlantılar uzlaştırılmıştır. Tür açıklamaları tasarım adayıdır, bilimsel tür tanımları veya oynanabilir mob kabulü değildir.

Kırıkdiş için ikinci alternatif görsel: [alternatif konsept](images/Kirikdis_Alternatif_Konsept.png).
