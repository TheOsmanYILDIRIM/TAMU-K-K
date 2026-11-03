# OSMAN OYUN — 2,5D İzometrik Terrain / Görsel Yön ve Devir
**Karar tarihi:** 2026-10-27 · **Durum:** tasarım ve Python ile render prototipleri; **oyuna entegrasyon yapılmadı**.
**Repo:** `TheOsmanYILDIRIM/oyun` · **Kaynak dal:** `main` @ `def0d8a8ce26683e874ddf88d12a518b75673b27` (belge yazımından hemen önce okunan HEAD).
**Ayrı bloklu deney:** `experiment/wfc-static-world-20261025` @ `8683ecc9a5bc2d10e9f41a6fd5a84cbb4e03ea23`; bu belge onun kabulü veya main birleşmesi değildir.

## 1. Kullanıcı tarafından onaylanmış görsel hedef
- **3D oyun/render mimarisi değil:** oyun **LÖVE2D/Lua, 45° yönlü izometrik 2,5D**. 2D sprite'lar dik billboard gibi çizilir; zemin izometrik world-space koordinat dönüşümüyle sunulur ve nesneler ayak Y/derinliğe göre sıralanır. 3D Blender sahnesini veya 3D oyun motorunu otomatik seçenek olarak önermeyin.
- Görsel referans: kullanıcı `harita_Ref.png` (27 Ekim 2026). Geniş doğal orman/çayır/taşlık vadiler, kıvrımlı akarsu, sığ nehir kıyısı, taşlık kütleler, köprü/patika, ağaçların farklı boyut ve yoğunlukları, 45° izometrik perspektif, çevresel gölgeler.
- Hedef yüksek görsel kalite ve yüksek performans; **statik hesaplanabilir zemin/dağılım/ışığı precompute edip paketlemek**, hareketli nesneleri ve oyun mantığını dinamik tutmak. Kullanıcının önceki performans çıtası: görsel özellik maliyetini yeni optimize edilmiş motorun kendi baseline'ına göre mümkün olduğunca ~%2 sınırında tutmak; gerçek ölçüm yapılmadı.
- Yeni bir oyun çalışma kolu, main'e entegrasyon, gameplay/schema değişikliği veya WFC kabulü bu görsel çalışmalar sırasında onaylanmadı.

## 2. Drive asset envanteri ve üretim sözleşmesi
**Kanonik görsel arşiv:** [Google Drive — Texture_Archive](https://drive.google.com/drive/folders/1n3nkFdX3rPluAHU5aS95Ci5nYBp8_CHe).
Terrain aileleri ayrı klasör; her birinde `Originals` ve `Optimized_128_64`:
- [Çimen/Çayır](https://drive.google.com/drive/folders/1tb4o8_VPxxbaJOl1Rw1jwflQYdb7mc6R): 36 optimize PNG; kaynak olarak 3 contact sheet + 36 yüksek çözünürlüklü kırpım.
- [Orman zemini](https://drive.google.com/drive/folders/1dW_tFeHScN1DfK8T1TQJf9-O3tS0XC4U): 36 optimize PNG + 3 orijinal contact sheet.
- [Toprak/Patika](https://drive.google.com/drive/folders/1XSBx8c9AqvP3sB_4mmKh6eelsS6Bv2qt): 31 optimize PNG + 3 orijinal sheet. Elenenler `dirtA_09,12`, `dirtB_04,12`, `dirtC_06`.
- [Kaya/Çakıl](https://drive.google.com/drive/folders/18eSIVc8PpRe_GwL93W_JqP2l7-jxjPdM): güncel Drive'da 34 optimize PNG görüldü (27 Ekim). Önceki manuel seçim 32/36 idi; ikisini otomatik elenmiş sayma; Drive güncel envanteri ile farkı uzlaştır. 3 kaynak contact sheet; manifest bulundu.
- [Nehir kıyısı/Sulak alan](https://drive.google.com/drive/folders/1cXnGRAh0Kv2MtZtnqYeVqCdSVETfDaFN): 31 optimize PNG + orijinaller, Drive üzerinden görüldü.
- [Object_Variants_v003](https://drive.google.com/drive/folders/1YqOOaeRPBSzC3THJgwlg0ZztEruRZp0w): `oak`, `conifer`, `broadleaf`, `shrub`, `boulder`, `rock_spire`, `rock_cluster`, `water_rocks`, `reeds`, `stump`, `fallen_log`, `dead_tree` ve 6 orijinal contact sheet. Örnek varyantlar şeffaf `*_128_lab64.png`. Son demo yerel `122801.png` transparan obje contact sheet'inden kesilmiş sprite'larla üretildi; bu, tüm Drive objelerinin kullanıldığını göstermez.
- **Sayı tutarsızlığı:** 27 Ekim ilk Python demosu **166** optimize texture kullandı: 36 grass + 36 forest +31 dirt +32 rock +31 wet. Daha sonra Drive kaya klasöründe **34** optimize PNG bulundu. Sonraki adım kayıpsız manifest eşleştirmesi; onaylanmamış veya doğrulanmamış 2 varyantı kendiliğinden kaldırma/ekleme.
- Üretim promptu: her aile için doğrudan yukarıdan bakılan, **3 satır × 4 sütun, eşit 12 kare, çizgisiz/aralıksız/etiketsiz** contact sheet. Üç sheet = 36 aday; aile bazında manuel seçim. **Prompta 128px / 64 renk talimatı koyma**; bunu sonradan kodla yap. Örnek aileler: grass/meadow, forest floor, dirt/path, rock/gravel, riverbank/wetland ve ileride natural mixed terrain.
- Demo işlem hattı: 1536×1152 sheet -> 12 adet 384×384 crop -> Lanczos 128×128 -> Pillow MedianCut 64 renk ve dithering kapalı. Bu demo işlem standardıdır; repo'daki `TEXTURE_PRODUCTION_GUIDE.md` içindeki ayrı **CIELAB K-means/asset acceptance** kuralının yerini otomatik almaz. Gerçek runtime import öncesi renk/alpha/lisans/manifest/hash ve performans onayı gerekli.
- İstenen `seamless` promptu dört kenarın pikselce eşleştiğine kanıt değildir; crop'ların çoğu testte matematiksel seamless çıkmadı. Koruma/edge repair ayrıca test edilmeli.

## 3. Gerçekte yapılan Python görsel prototipleri — kabul ve ret
Bu çıktılar ChatGPT oturumunun yerel PNG çıktılarıdır; **oyun build'inin parçası, repo asset'i veya Drive'a otomatik yüklenmiş varsayılmaz**. Yeni sohbette kaynağa erişilebiliyorsa yeniden doğrula.
1. **36 grass için 36 Gaussian dairesel ağırlık maske** ve tüm dokuları aynı anda karıştırma: kullanıcı reddetti; dairesel lekeler, aşırı blur ve malzeme kimliği kaybı.
2. Çok ölçekli noise ile büyük **tek baskın texture bölgeleri** + dar 4px sınır geçişi: ilk denemeden daha iyi, kullanıcı olumlu; fakat bu tek başına nihai referans görünümü değil.
3. Beş malzeme ailesiyle 2160×1440 zemin haritası ve kıvrımlı mavi/yeşil su: düz kuşbakışı çıktı, yama izleri ve taş doku deformasyonu; kullanıcı **referansla ilgisiz** buldu. `Osman_Terrain_166_Texture_Nihai_Karisim_Demo.png`.
4. **CIELAB malzeme ortalama renk tonlarını yakınlaştırma**, geniş maske/alpha blend: sınırlarda blur; kullanıcı reddetti. `Osman_Terrain_166_LAB_Renk_Benzerligi_Demo.png`.
5. **Blursuz kategorik mikro-geçiş**, her piksel tek kaynak texture + CIELAB renk düzeltmesi: ayrıntı korunur, fakat bütün sahne düz top-down; mikro yamalar tekrarlı/doğal olmayan sınırlara yol açabilir. `Osman_Terrain_166_RenkBenzerligi_Blursuz_MikroGecis.png`.
6. **2,5D sprite demo:** yerel `122801.png` atlasından PNG sprite'ları ayıklayıp transparan alfa ile yerleştirme; nehir, patika, orman, kayalar, y/depth sort. Önce üstten `Osman_Oyun_2_5D_Izometrik_Sprite_Harita_Demo.png`; sonra 2×2 dönüşümle **izometrik zemin + dik sprite** `Osman_Oyun_25D_Izometrik_Zemin_Dik_Sprite_Demo.png` (1920×1080, 475 görünür obje). İlk gerçek oyun benzeri yön; yine referans kalitesi değil.
7. **Shadow/Shader/LUT offline render:** `Osman_Oyun_25D_Shadow_Shader_LUT_Demo.png`; `Osman_Oyun_25D_FX_Once_Sonra.png`. Algoritmalar: obje siluetine dayalı yönlü + temas gölgeleri, zemin AO benzeri ışıklandırma ve hafif yerel mikro-kontrast, 33³ trilinear 3D LUT (sıcak güneş, serin gölgeler, hafif zeytin/teal), su yansıma vurguları. Bu **Python CPU ön işleme/efekt benzetimidir**; gerçek LÖVE GLSL shader, GPU maliyeti, FPS, gerçek cihaz ve CI başarısı değildir.
8. Son görsel referansa yaklaşmak için hâlâ gerekli: yükseklik/şev hissini **2,5D katman, yüksekliğe bağlı sprite/yüzey sıralama** ile vermek; gerçek nehir kıyıları/akıntı/şelale ve kıyı taşları; biyoma, su uzaklığına, eğime bağlı obje yoğunlukları; doğal patika ağı; tekrarlı texture izlerini azaltma; gölge ölçeği ve objelerin gerçek dünya ölçek tutarlılığı. Tam 3D motor yönüne dönme.

## 4. Önerilen 2,5D üretim mimarisi (henüz uygulanmadı)
- World Builder'ın kanonik topography/ecology/hydrology/biome/path verileri **source-of-truth**. Salt noise'dan kurulan rastgele piksel materyal planı yerine derlenmiş world-space biome + slope + altitude + moisture katmanları.
- Bake/build adımında 128×128 kaynak texture atlasları ve LAB özelliklerini oku; komşu malzemeleri renk benzerliği + ekoloji ile seç, önce büyük doğal tek malzeme alanları, sınırda texture özelliklerine dayalı **mikro parçalama/alpha değil id mask**. Tek pikselin malzemesini mümkün olduğunca net tut; geniş görüntü blur'u yok.
- Render yüzeyi hâlâ 2D. Dünya koordinatı -> izometrik projeksiyon 45° dönüş; gerekiyorsa z-yükseklik hissi için precomputed 2,5D displacement/terrace ve cliff-face sprite parçaları; asset'leri billboard 2D sprites. Occlusion/draw-order = ekran Y + yükseklik/ayak noktası.
- Statik zemin, statik objeler, baked ambient/shadow ve waterbed mask ayrı ön derleme; canlı oyuncu, değişen objeler, envanter, hasat, yıkım ve çarpışma dinamik. Su shader'ı yalnız gerekiyorsa küçük alanı etkiler. Efektleri otomatik entegre etme; maliyet benchmark.
- Tekrarlanan 128px tile geometrisi doğal varyasyon, phase offset ve precomputed görsel decal ile azaltılmalı; çok fazla renk harmanlama veya 36 texture'ı aynı anda sahneye bindirme yapma.
- Bu prototip kararları **tasarım hedefidir**, test edilmiş WFC/R2 uyumluluğu değildir.

## 5. Korunacak repo ve kabul kapıları
- `main`, R2, World Builder authored rules, Stage5/6 save, stüdyo, mevcut objeler, PNG'ler, backuplar, kullanıcı verileri/IndexedDB korunur; deney dallarını otomatik main'e merge etme.
- WFC/Static World deney görevini **blocked** bırak: `tasks/oyun-wfc-static-world-20261025.md` revision 22. Branch HEAD `8683ecc`; Quality [#40346953928](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/40346953928) başarılı, WFC comparably-playable [#40346953901](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/40346953901) **frame-budget başarısız**; kullanıcı bu işi tamamlanmış kabul etmedi.
- Bu oturum yalnız **görsel tasarım prototipi ve dokümantasyon**; oyun dosyalarına, CI workflow'una veya APK'ya dokunma.
- Gelecek gelişimde birinci kabul: render edilen gerçek LÖVE/Xvfb PNG gözlemi, asset/license/hash doğrulama, determinism ve komşu malzeme testleri, p50/p95/p99 frame timing; sonrasında gerçek Android cihaz dokunma/safe-area ve GPU/FPS kanıtı.

## 6. Yeni sohbeti başlatma
1. Bu dosyayı ve repo `AGENTS.md` dosyasını oku, güncel branch/HEAD ve Actions'ı yeniden doğrula. Beyin'deki ilgili görevi bul/oluştur ve gerçek geliştirmeden önce resmî IO protokolüyle `main` doğrulamasını yap.
2. Drive'da yukarıdaki 5 kategori `Optimized_128_64` ve obje arşivini yeniden say; rock 34 ile Python 32 uyuşmazlığını manifestten çöz, içerikleri gerçekten aç.
3. Kullanıcının referansını (`harita_Ref.png`) ve son 2,5D/FX çıktısını karşılaştırarak hedef odaklı bir **izometrik 2D precomputed sahne prototipi** planla; gerçek 3D oyun mimarisine veya sadece düz top-down texture blend'e dönme.
4. Görselleri **kodla üret**; GPT Image kullanma. Çıktıyı açıp görsel doğrula; kabul edilmemiş kaliteyi 'nihai' diye sunma.
