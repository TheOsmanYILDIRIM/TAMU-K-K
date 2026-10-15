# 2D İzometrik Oyun — Uygulama Yol Haritası

> **Durum:** Aşama 1–4 main üzerinde; aşağıdaki Aşama 5–9 kabul maddeleri plandır. **Tarih:** 2026-10-15.
> **Repo:** `TheOsmanYILDIRIM/oyun`; **referans HEAD:** `eb80926e77fb3d83d7a7637b22e2be1ef90eaecb`.
> **Öncelik:** Çalışan oyun sistemleri; texture/sprite üretimi sonraya bırakıldı.

## Başlangıç ilkeleri ve mimari kararı

- Hedef oyun deneyimi: **45° izometrik 2D**, organik geçişli, görünür tile-ızgarası olmayan prosedürel dünya; mobil/dikey ekran öncelikli hayatta kalma, kaynak toplama, crafting, inşa ve ileride iki oyunculu ortak dünya.
- Daha sonraki tasarım görüşmelerinde **LÖVE2D** ve **Marching Squares** tercih edildi. `main` artık LÖVE2D 2D çekirdeğiyle Aşama 1–4'ü uygular; tarihsel Godot 3D iskeleti korunmaktadır. İlk geliştirme oturumunda gerçek kaynak, deney dalları, son HEAD, çalışan testler, cihaz/paketleme olanakları ve karar belgeleri okunmalı; 2D hedefe uygun uygulama yolunun açıkça gerekçelendirilmesi gerekir.
- Önceden tamamlanmış çalışan kodu yeniden yazma. Eski yedek `backup/pre-portrait-reboot-20261011`, mevcut `main`, World Builder, Object Studio, Terrain Studio, PNG'ler, kayıtlar, IndexedDB ve kullanıcı verisi korunur.
- Placeholder şekil/renklerle işlevsellik ve testleri doğrula. **Terrain Studio'daki 18 ayrı fiziksel materyal varyantı kaydı korunur**; gerçek texture, karakter sprite'ı, animasyon ve görsel son kalite **9. aşamaya** bırakılır.
- Her aşamada önce veri/kontrat, sonra modüler sistem, sonra test ve gerçek çalışan çıktı; commit sonrası HEAD ve CI denetimi. Gerçek cihazda denenmeyen performans, APK veya iki oyuncu başarısı iddia edilmez.

## Aşama 1 — Oyun çekirdeği

**Kapsam:** Seçilen 2D motorun mevcut repo ile uyumu; oyun döngüsü, durum ve sahne yönetimi, girdiler, 45° izometrik dünya/ekran koordinat dönüşümü, ortografik görünüm ve kamera takip/kaydırma, portrait ekran oranı ve safe-area temelleri, hata/diagnostik ve otomatik smoke.

**Kabul:** Uygulama açılır, debug sahnesi görüntülenir, kamera/ekran dönüşümleri test edilir; en az bir otomatik build/smoke doğrulanır. Şu an motor geçişi ve Android çıktısı tamamlanmış değildir.

## Aşama 2 — Prosedürel dünya

**Kapsam:** Seed-tabanlı deterministik arazi; bölge/biyom verisi; Marching Squares ile organik sınırlar; komşu chunk dikiş sürekliliği; kamera çevresinde chunk yükleme/boşaltma; görünür tile tekrarını önleme. Test için düz renk/debug materyalleri kullan.

**Kabul:** Aynı seed aynı haritayı üretir; bitişik chunk sınırları kesintisizdir; kamerayla dünya genişler ve geri döndüğünde aynı yerler görülür.

## Aşama 3 — Karakter, hareket, sıralama

**Kapsam:** Oyuncu instance'ı, izometrik dokun/klavye hareketi, istenirse yol bulma, çarpışma ve engeller, katman/y-depth sıralama; başlangıçta basit placeholder karakter ve sahte yürüyüş gösterimi.

**Kabul:** Oyuncu dünya içinde kontrollü hareket eder; engellerden geçemez; ön/arka görünürlük ve farklı kamera konumlarında dünya koordinatları tutarlıdır.

## Aşama 4 — Dünya nesneleri ve toplama

**Kapsam:** Katalog temelli ağaç/kaya/kaynak noktaları; deterministik yerleşim, etkileşim menzili ve iş emri, toplama süreci, nesne durum değişikliği, envantere kaynak aktarımı.

**Kabul:** Bir ağaç/kaya bulunur, geçerli mesafeden etkileşilir, kaynak üretimi bir kez gerçekleşir ve dünya nesnesinin durumu güncellenir.

## Aşama 5 — Envanter, crafting ve inşa (ilk oynanabilir kilometre taşı)

**Kapsam:** Kimlikli eşya tanımları, kapasite ve yığın kuralları, tarif çözümleme, üretim istasyonu, malzeme tüketimi, dünya üzerinde nesne yerleştirme; portrait HUD.

**Kabul:** Oyuncu ağaç toplar → odun kazanır → tahta üretir → bir yapı yerleştirir; miktarlar tutarlıdır ve yetersiz malzemeyle üretim yapılamaz. **Bu aşama sonunda geçici grafiklerle oynanabilir dikey kesit hedeflenir.**

## Aşama 6 — Kalıcı dünya

**Kapsam:** Dünya seed/versiyon, oyuncu konumu, envanter, değiştirilmiş nesne durumu ve yapıların kaydı; atomik yazım ve hata sonrası geri dönüş; migration ve kayıp-veri testleri.

**Kabul:** Kaydet/kapat/aç döngüsünde dünya değişiklikleri korunur; yarım kalan yazım önceki sağlam kaydı bozmaz. Platforma özgü yollar seçilen motor için belgelenir.

## Aşama 7 — Android ve performans

**Kapsam:** Dokunmatik hareket ve safe-area HUD; Android paketleme/CI; imza stratejisi; chunk ve çizim performansı; 320–360dp, 392–411dp, büyük yazı ve farklı portrait oranlarında ölçüm.

**Kabul:** Gerçek APK ve artifact/SHA doğrulanır; gerçek Android cihaz üzerinde giriş, FPS/bellek, boyut ve uyumluluk raporlanır. GitHub CI sonucu gerçek cihaz testi yerine geçmez.

## Aşama 8 — İki oyunculu ortak dünya

**Kapsam:** Host-authoritative oyun komutları, iki oyuncu konumu, etkileşim ve envanter tutarlılığı, tekrar/çakışma engelleme, kopma/yeniden bağlanma; önce yerel ağ testi.

**Kabul:** İki gerçek cihazda aynı dünya ve kaynak değişiklikleri eşzamanlıdır; aynı kaynak iki kez tüketilemez; ağ kopmasında veri tutarlılığı korunur.

## Aşama 9 — Görsel bütünleştirme (ertelenen texture işleri)

**Kapsam:** Terrain Studio'nun 18 fiziksel varyant promptuyla üretilen seçilmiş PNG'ler, Object Studio kaynakları, gerçek karakter sprite/animasyonları, biyom geçişleri, shader/malzeme ve görsel performans. Lisans/asset provenance kontrol edilir.

**Kabul:** Placeholder'lar onaylı gerçek varlıklarla değiştirilir; farklı varyantlar salt koyulaştırma/renk filtresi değil, yaprak biçimi, yoğunluk, organik yapı, tane veya mineral çatlağı gibi fiziksel özelliklerle görsel olarak ayrışır. Kare PNG'ler kullanım öncesi gerçek dikiş ve oyun içi ölçek testinden geçer.

## Bağımlılıklar ve devralma

1. **Hemen sonraki iş:** Güncel repo/HEAD, dal, AGENTS.md, mimari kararlar, mevcut 2D deneyleri, issue/PR ve Actions durumunu oku; 2D motor ve uygulanabilir kapsamı doğrula. Ardından Aşama 1 için minimum çalışma hattını uygula.
2. Aşama 1–3: dünya ve hareket çekirdeği. Aşama 4–5: ilk oynanabilir prototip. Aşama 6–8: dayanıklılık, mobil dağıtım ve çok oyunculu. Aşama 9: görsel üretim.
3. Tamamlandı durumu sadece test/commit/CI ve ilgili platform kanıtları varsa verilmeli. Başarısız ya da henüz çalıştırılmamış işler açık olarak raporlanmalı.
4. Avenox Beyin için görev ID/revision bu planın oluşturulduğu oturumda doğrulanmadı. Gelecek yazmalı görevde önce ilgili kayıtları ve resmî prosedürü kontrol et; mükerrer görev oluşturma.

## Bu oturumun doğrulama sınırı

Bu dosya bir **plan belgesidir**, çalışan oyun veya uygulanan motor geçişi değildir. 2026-10-15'te önceki Terrain Studio prompt değişiklikleri ve mevcut kaynaklar incelenmişti; yeni HEAD'in Actions/Pages sonuçları ayrı doğrulama gerektirir.
