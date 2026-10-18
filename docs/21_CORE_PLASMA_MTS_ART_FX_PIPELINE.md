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

## 2026-10-18 — Sohbet nihai mutabakatı (önceki planın üzerine güncel durum)

Bu bölüm, 16 Ekim tarihli tarihsel tasarım notlarını **geçersiz kılmadan** sonraki doğrulanmış uygulamayı belirtir. Yukarıdaki “henüz oyuna entegre edilmedi” ifadeleri artık tarihsel başlangıç durumudur.

**Kullanıcı kararları ve tekrarlanabilir yöntem**
- Bilinci taşıyan metal Core ayrı, değiştirilebilir PNG olarak kalır; kristal pulse/maske shader ile çizilir. Core hiçbir FX karesine gömülmez. Tamamen rig/video ile hareket eden karaktere dönülmez.
- Başarısız deneylerden öğrenim: GPT Image geometriyi birebir korumaz; yeşil Core silüeti/magenta chroma key, tek videodan otomatik derinlik çıkarma, saf dikey aynalama ve komple plazma şeridi çizdirme, güvenilir Core-bağımsız VFX üretimi sağlamadı. Bunlar **üretim çözümü olarak seçilmedi**.
- Geometri ve katman sırasını kod belirler. GPT Image yalnız tekil, tekrar kullanılabilir brush dokuları sağlar; Photoshop benzeri stamp spacing, opacity, flow, scale/rotation jitter, stretch, scatter ve spline/yörünge deformasyonu parametriktir. Karmaşık büyük “membrane” damgaları duman/boncuk görünümü oluşturdu; daha küçük ve sık örtüşen hollow-ring + ribbon/curl/wisp karışımı görsel test sonrası kullanıcı tarafından **şimdilik yeterli** kabul edildi. Daha sonraki iyileştirmeler varlığı yeniden ürettirmeden kaynak parametrelerinde yapılabilir.
- V4 kullanıcı onaylı ayarlar (7 yörünge, 480 damga/yörünge, yarıçap 147, seed 6809 ve tüm diğer kesin değerler) yalnız `art-source/core-plasma/parametric-v1/core_plasma_settings.json` dosyasındadır; prompt özetleri yerine bu JSON kanoniktir.
- 3D izlenimi, ekran düzleminde tek sabit halka değil, farklı yönlerde 3B matematiksel yörüngelerin 2D izdüşümü ve önce/sonra örtüşme ile sağlanır. Bu gerçek GPU derinlik tamponu/3D mesh değildir. Aynı Core etrafında ön/arka plazma aynı kare indeksinde çizilir.
- Oyunda render sırası: **arka RGBA plazma spritesheet → bağımsız Core PNG + kristal shader → ön RGBA plazma spritesheet → bağımsız araç**. Y-depth, oyuncu konumu, collision, su %55 hız/%50 immersion, araçlar, kayıt ve katalog etkilenmez. Başka Core türleri aynı yerleşim/ölçek kontratıyla bu plazmayı yeniden kullanabilir; farklı Core ölçülerinde görsel hizalama ayrıca sınanmalıdır.

**Main üzerinde kanıtlanan uygulama**
- Parametrik HTML/JS üreticisi, dört gömülü fırça görseli, Python Playwright spritesheet üreticisi, kesin ayarlar, manifest ve kaynak rehberi `art-source/core-plasma/parametric-v1/` altında: main commit `1920d2542167f04c8e39746bd33512a4b0a59160`.
- Oyun paketindeki 32 kareli, 8×4 düzenli, her kare 512×512 ön/arka RGBA atlasları `game/love/assets/core_plasma_{front,back}_spritesheet_32x512.png` altındadır. LÖVE çağrı noktaları `game/love/player/core_plasma_sheet.lua` ve `core_visual.lua`; Core/maske değişmeden shader korunmuştur. Main entegrasyon commit `db1598fff9d4147754737c943bd8097b890bc43a`.
- Lua mock/sözdizimi düzeltmeleri ve screenshot callback main commit `99a8bd099797520e17b326a1624b83a83340e1c9`; doğrulama Actions [#39120557833](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/39120557833) başarı: Lua 5.4/LuaJIT, ilgili regresyonlar, gerçek LÖVE/Xvfb dört durum (nötr, stat, kazma, su); artifact `12134062458` görsel olarak incelendi. Xvfb örnek 266,32 FPS **Android FPS ölçümü değildir**.
- 32 kare döngünün uç dikişi; farklı Core silüetlerinde hizalama, mobil GPU 4096×2048 atlas limiti/VRAM/gerçek cihaz FPS **doğrulanmadı**. Bu başlıkları kapalı iş olarak gösterme. Araç hareketi, stat/skill, Stage5/6 gibi paralel oyun kararları yalnız kanonik güncel kayıtlarına göre yorumlanır; bu FX belgesi onları yeniden tanımlamaz.
- 18 Ekim sonunda güncel main üstünde başka ajanların Stage6/branch temizliği değişiklikleri vardır. `main` HEAD'i her yeni oturumda yeniden doğrula; tamamlanmış deney dallarını körlemesine geri birleştirme.
