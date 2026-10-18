# Core / Plasma — MTS görsel varlık ve ortak FX üretim planı

> 2026-10-16 · durum: tasarım/üretim iş akışı, oyun entegrasyonu değil.
> Repo: TheOsmanYILDIRIM/oyun. Kaynak main: 388452c964c40c50e81fb42d58f8e100de4dcc85.
> Beyin yeni görev isteği: core-plasma-art-20261016-chat; hedef görev ID oyun-core-plasma-art-assets-20261016. **Kanonik main task revision/status henüz teyit edilmeden kayıt başarılı varsayılmaz.**
> Önceki oyun-core-plasma-avatar-20261016 rev2 done yeniden açılmaz.

## Korunacak kanon
- Oyuncu insansı/rig/golem değildir: metal bilinç çekirdeği + kontrol edilen plazma. Core'un sabit tek SE 45 derece izometrik görsel yönü; dünya 2:1 projeksiyon. Kamera dönüşü yok.
- MTS Grounded Dark Fantasy (nesnel kanon object-studio/src/catalog.js STYLE): aged/weathered, somber, muted, tactile physically believable dark-fantasy materials, soft diffuse illumination, low-mid contrast, restrained saturation and realistic microdetail. Avoid pixel/voxel noise, cartoon shading, fake deep relief, plastic, excessive glow, ornaments.
- Kullanıcı tarafından GPT Image A ile oluşturulan **121222.png** metal Core ana görsel referansı: yaşlandırılmış metal paneller, bronz çerçeve, merkezde cam/mavi kristal, ön metal bar. Dosya bu sohbet ekidir; repoya henüz ithal edilmedi, blob/PNG entegrasyonu iddia edilmez. 1254x1254 RGBA olarak önceki inceleme; yeniden dosya kontrolü gerekir.
- Metal Core ana PNG sabit. Ayrı idle/move key PNG üretmek gereksiz. Idle bob ve kristal enerjisi shader/parametrik; hareket dünya koordinatlarıyla.
- Balta/kazma/kılıç her biri ayrı tek fiziksel PNG, rigid sprite; vuruş, kavis, açı, konum ve geri toparlanma matematiksel. Balta/kazma ayrı poz sprite'ları, insan rig'i veya temel saldırı için Veo videosu gerekli değil.
- FX modelden bağımsız ve tekrar kullanılabilir: swing, strike, impact, craft, build, plasma orbit/ribbon/ambient ve su. Aynı FX farklı axe/pickaxe modelinde kullanılabilir, tool renderından ayrıdır.
- GPT Image statik particle/ribbon/FX referansları üretir. Gerekli organik/deformasyonlu efektler için onaylı başlangıç/son karelerden **Veo 3/3.1 koşullu** kısa video çıkar; video gameplay runtime'ına girmez. Gerçek video elde edilirse matting, timing, atlas, metadata, loop ve bellek/perf testleri ardından sprite olarak kullanılabilir. Veo erişimi/çıktısı şu an kanıtlanmış değildir.
- Matematiksel parçacık/yörünge sistemi 3B sanal konumdan 45° 2B ekrana projeksiyon, core geometry/mask destekli ön/arka örtüşme, az sayıda kıvılcım ve bounded draw calls. Sabit front/back PNG tek başına gerçek dönme örtüşmesini çözmez.
- Stat listesi/palet/level eşikleri ve özel yetenekler kanonik olarak açık; geçici turkuaz/mor referans nihai stat ataması değildir.

## Crystal shader mask — paralel iş A
- Orijinal 121222.png sabit referans. GPT Image'ın ilk siyah-beyaz **121229.png** çıktısı kristal şeklinin ve metal örtüşmesinin hatalı olması, yeniden çizim/ölçü uyumsuzluğu nedeniyle doğrudan kabul edilmedi. Önceki rapor: 1536x1536 RGB / orijinal 1254x1254 RGBA; yerelde tekrar doğrula.
- Yeni GPT Image A isteği: **orijinal Core'un yalnızca görünür kristal yüzeyini #FF00FF magenta flat color ile işaretle**. Metal köprü/bar, çerçeve, dış shell, oluklar, yan mavi boşluklar değişmez. Bu bir editing/semantic-ID yardımcı görseli, shader maskesi değil; sadece tek kristal.
- Çıktıda piksel koordinatı veya saf RGB garanti edilemez. Bu işaretlemeyi semantik kılavuz olarak kullan; orijinal fotoğrafın boyutuna kaydetme/kesme/bozma yapma. Orijinal PNG ile koordinat kaydı (geometric alignment), renk toleransı, segment temizleme, binary quantization, koruyucu metal occlusion, piksel karşılaştırması ve overlay doğrulaması; başarısızsa manuel/algoritmik maskeleme. Gerçek shader maskesi 1254x1254, exact black (0,0,0) white (255,255,255), alpha seçiminde bilinçli tutarlılık.
- İleride enerji olukları maskesi ayrı olacak. Metal shell ID ile karıştırılmaz.

## Parallel workstreams / sonraki sohbetler
A. Crystal mask: magenta recolor sonucu bekleniyor; geldiğinde tam hizalı binary maske ve overlay üret, sayısal test raporu oluştur. Asıl görüntüye dokunma.
B. Shared FX: GPT Image A ile yalnız **tek FX türü** (önce plasma ribbon/particle veya shared swing) için onaylı master, sonra Veo storyboard. Gövde ve araç görsellerini FX içine bake etme. Craft/build, sword, axe, pickaxe varyantları tek atlas ailesini yeniden kullansın.
C. Tool mathematics: sabit görüntüden açı + kavis + anchor + depth + curve ve impact event tasarımı; mevcut player/core_visual.lua ve renderer.lua okunsun; özellikle Y-depth, collider/foot, water speed 55%, immersion 50%, Stage5/Stage6 korunmalı. Yapılacaksa güncel `AGENTS.md` dal seçimi kuralına göre uygun dalda ilerle; var olan LÖVE screenshot/test/CI kanıtını tekrar kullan, değişiklik için gerçekten gereken kontrolleri toplu çalıştır. İzin/onay olmadan main'e birleştirme.
D. Veo/video-to-sprite (FX onayından sonra): tutarlı kamera ve kaynaktan start/end kare, repeatable loops; temporal continuity ve alpha matting; atlas frame metadata action/duration/pivot/anchor/foot-depth/waterline, RAM/VRAM and draw-call kontrolü. Gerçek video yoksa yalnız storyboard.
E. Static tool source: bir axe, bir pickaxe ve opsiyonel sword ayrı 1024 square true-alpha PNG; MTS materyal, tool tek rijit sprite, hiçbir baked swing. Bu görseller henüz üretilmedi.

## Somut teslim / acceptance
- Plan ve kaynak kanonu uygun dalda doğrulanmış Git commit ile mevcut olmalı; sırf bu belge için yeni deney dalı açma.
- Yeni Beyin görev kaydı yalnız resmî beyin-io v2 status/result + vault main task rev ile doğrulanır; aksi halde pending_unverified.
- Her PNG için kaynak, boyut, alpha, hash, anchor, uyumluluk, görsel kontrol ve asıl dosyanın mevcudiyeti doğrulanmadan üretildi yazma.
- Video/spritesheet, shader ve sahne testi yoksa yapılmış gibi bildirme.
- Main/backup, fizik, su, Stage5/6 save, World Builder, Terrain Studio 18 varyant, Object Studio, eski 2D rig, IndexedDB ve kişisel kullanıcı verileri korunur.
