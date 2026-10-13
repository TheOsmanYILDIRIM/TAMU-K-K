export const BIOMES = Object.freeze([
  {id:'meadow',name:'Çayır',short:'Açık, soluk otlar ve seyrek siluet',color:'#a1ad83'},
  {id:'forest',name:'Orman',short:'Yoğun örtü, gölgeli toprak, yosun',color:'#577661'},
  {id:'rocky',name:'Kayalık',short:'Aşınmış taş, açık mineral yüzeyler',color:'#888f83'}
]);
export const STAGES = Object.freeze([
  {id:'direction',name:'Yön',number:'00',description:'Obje rolünü, silueti, dünya ölçeğini ve malzeme dilini onayla.'},
  {id:'reference',name:'Referans',number:'01',description:'Tek kare stil referansı; kompozisyon değil malzeme dili belirler.'},
  {id:'creative',name:'Yaratıcı',number:'02',description:'1024×1024 gerçek transparan PNG; özgür ama oyun rolüne sadık ilk biçim.'},
  {id:'correction',name:'Düzeltme',number:'03',description:'Image A biçim/izometrik yön, Image B malzeme/stil; son kare PNG.'},
  {id:'layers',name:'Katman',number:'04',description:'Aynı kare koordinatlarda L0 taban, L1 gövde, L2 üst hacim, L3 ön örtü.'},
  {id:'maps',name:'Haritalar',number:'05',description:'Normal aydınlatma; height gerçek geometri/ileride displacement. İkisi aynı şey değil.'},
  {id:'approval',name:'Kabul',number:'06',description:'Oyun mesafesi, alpha, pivot, gölge, çarpışma ve biyom okunurluğu.'}
]);
export const SLOTS = Object.freeze([
  {id:'reference',name:'Stil referansı',stage:'reference',alpha:false,description:'Kare PNG; ortam/ışık/malzeme dili.'},
  {id:'creative',name:'Yaratıcı PNG',stage:'creative',alpha:true,description:'İzolasyon ve serbest siluet. Gerçek alpha.'},
  {id:'corrected',name:'Düzeltilmiş PNG',stage:'correction',alpha:true,description:'Kabul için esas sprite, Image A geometrisi korunmuş.'},
  {id:'base',name:'L0 • Taban',stage:'layers',alpha:true,description:'Toprak, kök, moloz, dip geçişleri.'},
  {id:'body',name:'L1 • Ana kütle',stage:'layers',alpha:true,description:'Gövde veya kaya ana kütlesi.'},
  {id:'upper',name:'L2 • Üst hacim',stage:'layers',alpha:true,description:'Yaprak taç veya taşın üst yüzeyi.'},
  {id:'front',name:'L3 • Ön örtü',stage:'layers',alpha:true,description:'Karakteri örten isteğe bağlı ön yüz.'},
  {id:'normal',name:'Normal map',stage:'maps',alpha:false,description:'Tangent-space RGB ışık tepkisi. Geometri üretmez.'},
  {id:'height',name:'Height map',stage:'maps',alpha:false,description:'Yükseklik/gri değer; ileride displacement için.'}
]);
export const STYLE = Object.freeze({
  title:'MTS · Grounded Dark Fantasy',
  target:'grounded dark-fantasy material realism; ancient, naturally weathered, somber, muted, tactile, physically believable surfaces; soft diffuse lighting, low-to-medium contrast, restrained saturation, realistic fine microdetail and controlled environmental aging',
  avoid:'No enlarged pixel-art patterns, cuboid/voxel material noise, cartoon shading, fake deep relief, wet plastic gloss, exaggerated bloom, harsh baked directional highlights, random photographic noise, oversized ornamentation or sterile stock-image finish.',
  silhouette:'Gameplay silhouette and readability at real mobile game distance outweigh extra decoration. A single isolated asset on genuine RGBA transparency in a square 1024×1024 canvas, full subject inside the safe area, consistent 45° isometric ground orientation, no terrain backdrop, text, border, checkerboard, pedestal or cast shadow baked into the asset.'
});
// Seven intentional, asset-specific production cards. No synthetic fallback prompts.
export const CATALOG = Object.freeze([
  {
    id:'T-01',name:'Yaşlı geniş yapraklı',family:'tree',species:'Broadleaf oak',symbol:'♣',color:'#658463',size:'large',height:4.6,footprint:[1.3,.8],collider:'sert engel',harvest:'odun',occluder:true,
    roles:['meadow','forest'], placement:'Tekil çayır ağacı veya orman açıklığının güçlü silueti; yolların ortasına otomatik yerleşmez.',
    forms:['Yuvarlak taç','Yana açılan','Eğik gövde','İkili taç'],surfaces:['Canlı','Yosunlu dip','Kuru','Koyu orman'],
    art:'A thick irregular old oak trunk, asymmetrical crown built from distinct medium-sized leaf masses, sparse visible branch breaks, believable root flare; crown must not resemble a perfect green ball.',
    reference:'An ancient broadleaf oak in a restrained dark-fantasy temperate world; bark fissures, quiet humidity, aged wood, deep moss in sheltered recesses and naturally subdued foliage, soft diffuse daylight.',
    correction:'Keep Image A trunk angle, root-foot anchor, asymmetrical crown silhouette and 45-degree isometric viewing direction. Image B only guides bark age, moss, foliage texture and low-saturation material relationships.',
    layer:'Preserve the exact approved oak position: L0 subtle soil/root halo; L1 bark trunk and branches; L2 separated crown leaf masses; L3 foremost low boughs only if occlusion is useful.',
    maps:'Bark grain and selective leaf clusters can react to a restrained tangent-space normal map; height should describe shallow bark/wood relief, not shift the rooted silhouette.'
  },
  {
    id:'T-02',name:'İğne yapraklı',family:'tree',species:'Fir / pine',symbol:'♠',color:'#4d6c60',size:'large',height:5.2,footprint:[.7,.6],collider:'sert engel',harvest:'odun',occluder:true,
    roles:['forest','rocky'],placement:'Dar gruplar, sırt geçişleri ve kuzey ormanı ritmi; tek boyda askeri sıra oluşturma.',
    forms:['Dar konik','Dolgun','Rüzgâr eğimli','Alt dalları seyrek'],surfaces:['Derin yeşil','Soğuk yeşil','Kuru iğneli','Koyu orman'],
    art:'Tall, slightly irregular evergreen with tiered needle branches, glimpses of a narrow woody trunk and an uneven apex; preserve distinct gaps between bough layers.',
    reference:'Cold fir needles, matte resinous bark, muted deep greens, wind-worn tips and sparse aged needles in shaded crevices; restrained realistic mineral/plant surface language.',
    correction:'Lock Image A layered bough spacing, crown taper, trunk placement and isometric orientation. Let Image B determine weathered conifer needle material only, never turn the tree into a perfect symmetrical triangle.',
    layer:'L0 fallen needles; L1 thin trunk; L2 overlapping needle tiers; L3 lower front boughs. Each exported layer stays aligned to the same 1024-square anchor.',
    maps:'Needle clusters receive subtle normal variation; bark relief may use height later. Never fake entire protruding branches with a flat normal map.'
  },
  {
    id:'T-03',name:'Genç / eğri ağaç',family:'tree',species:'Sapling / wind bent',symbol:'❧',color:'#84906a',size:'small',height:2.1,footprint:[.5,.45],collider:'yumuşak engel',harvest:'genç odun',occluder:false,
    roles:['meadow','forest','rocky'],placement:'Kenar boşlukları, rüzgâr alan taşlıklar, açıklık ve yetişkin ağaç altları.',
    forms:['Genç düz','Eğri gövde','Bodur rüzgâr','Kırık tepe'],surfaces:['Açık yaprak','Gölgeli','Kuru','Seyrek'],
    art:'One young asymmetrical sapling with a readable curved trunk, modest leaf groups, sparse irregular twigs and visible negative space; avoid miniature adult-oak proportions.',
    reference:'Wind-stressed sapling bark, flexible thin branches, small matte leaves, subtle age marks and natural restrained plant color in a weathered fantasy landscape.',
    correction:'Use Image A to preserve the bent slender stem, foliage spacing, ground contact and consistent iso direction; apply only muted plant and bark material cues from Image B.',
    layer:'L0 compact roots/pressed grass; L1 twisting young trunk; L2 light foliage; L3 optional front leaves only when needed.',
    maps:'Very low relief; a strong normal map would exaggerate tiny leaves. Prioritize clean alpha and readable stem over height complexity.'
  },
  {
    id:'R-01',name:'Küçük taş kümesi',family:'rock',species:'Loose stone cluster',symbol:'◈',color:'#8a9487',size:'small',height:.4,footprint:[.9,.65],collider:'dekoratif',harvest:'küçük taş',occluder:false,
    roles:['meadow','forest','rocky'],placement:'Patika kenarları, kaya dipleri ve açıklıklar; çarpışma alanını gereksiz artırma.',
    forms:['Üç taş','İnce taşlar','Yuvarlak küme','Dağınık kırıklar'],surfaces:['Temiz gri','Yosunlu','Tozlu','Nemli koyu'],
    art:'A natural uneven grouping of three to five grounded stones, visible top planes and irregular contact edges, varied silhouette sizes, shallow broken mineral faces.',
    reference:'Dry fractured mineral grain, quiet edge rounding, age stains, subdued stone gray, slight lichen in recesses; no huge crystals or glossy wet pebble texture.',
    correction:'Keep Image A group count, loose spacing, foreground/background stone overlap and ground footprint; Image B transfers geological microstructure rather than rearranging stones.',
    layer:'L0 fine pebbles and subtle dust contact; L1 main stones; L2 upper lit mineral surfaces; L3 only actual near-edge overlaps.',
    maps:'Normal-map shallow fractures only; height optional, small and realistic. Stones must not inflate into miniature cliffs.'
  },
  {
    id:'R-02',name:'Orta kaya',family:'rock',species:'Medium boulder',symbol:'◆',color:'#87918b',size:'medium',height:1.6,footprint:[1.1,.75],collider:'sert engel',harvest:'taş',occluder:true,
    roles:['meadow','forest','rocky'],placement:'Açıklık kenarı ve rota ayrımı; yola oturan sert engel olarak doğrulanmalı.',
    forms:['Basık','Dik kırık','İki parçalı','Çentikli'],surfaces:['Açık gri','Koyu mineral','Yosunlu','Kahvemsi'],
    art:'One squat irregular boulder with broad visible top plane, asymmetric broken side plane and physically embedded base; do not draw a rounded smooth plastic egg.',
    reference:'Worn stone volume with fine mineral stratification, sparse age fissures, muted mineral variation and lichen in shadowed seams, soft ambient light.',
    correction:'Image A dictates top/side plane boundaries, boulder mass, ground anchor and perspective; Image B dictates rock grain, believable wear, limited lichen only.',
    layer:'L0 stone grit and buried base; L1 heavy mineral block; L2 upper facet; L3 optional protruding near-face only when silhouette requires it.',
    maps:'Normal/height should respect facet boundaries; no exaggerated cliff-depth cracks on a medium boulder.'
  },
  {
    id:'R-03',name:'Büyük kırık kaya',family:'rock',species:'Landmark boulder',symbol:'⬟',color:'#76857d',size:'large',height:3.1,footprint:[1.9,1.3],collider:'sert engel / görüş kesici',harvest:'taş (ileride)',occluder:true,
    roles:['forest','rocky'],placement:'Sahne kimliği, görüş hattı ve geçit kompozisyonu; yalnız yönetmen onaylı noktalar.',
    forms:['Dev yuvarlak','Kırık blok','Yatık','İkili zirve'],surfaces:['Aşınmış','Katmanlı','Yosunlu','Soğuk koyu'],
    art:'Massive fractured two-part ancient boulder, with one broad off-center top facet, convincing weight and a partly buried base, strong readable negative-space silhouette.',
    reference:'Ancient weathered bedrock with compressed bedding lines, muted desaturated gray-brown mineral palette, softly darkened crevices and restrained lichen patches.',
    correction:'Image A preserves the monumental fractured silhouette, plane orientation and exposed top-face ratio; Image B only adds realistic geological wear and environmental age.',
    layer:'L0 scattered angular fragments/contact; L1 massive primary stone; L2 crown/top fractured plane; L3 lower front lip for occlusion when needed.',
    maps:'Large facet relief can use separate height geometry later; normals handle microfractures only and must not alter collision silhouette.'
  },
  {
    id:'R-04',name:'Kaya çıkıntısı',family:'rock',species:'Low outcrop',symbol:'⛰',color:'#727f70',size:'large',height:2.0,footprint:[2.6,1.1],collider:'arazi bariyeri',harvest:'yok',occluder:true,
    roles:['rocky','forest'],placement:'Arazinin doğal devamı; parçalı sırtlar ve kaya omuzları, geçit yönlendirme.',
    forms:['Alçak sırt','Kırık omuz','Eğimli','Basamaklı'],surfaces:['Kuru','Koyu','Yosunlu','Çakıllı'],
    art:'An elongated geological outcrop emerging from the ground, irregular partially buried stone strata, unequal rising shoulders and connected stone fractures; not a freestanding decorative pebble.',
    reference:'Layered eroded terrain rock face with subtle bedding, plausible faulting, restrained lichen and compact dust between stone planes under cool soft ambient light.',
    correction:'Image A fixes elongated footprint, partial ground emergence and near/far ridge geometry; Image B supplies weathering and stratification without replacing the outcrop with a giant cliff.',
    layer:'L0 connected mineral ground blend; L1 primary exposed strata; L2 upper fractured crest; L3 front overhang when geometry dictates.',
    maps:'Height/displacement integration must match terrain mesh seams; normal maps add facet detail but cannot sculpt outcrop silhouettes.'
  }
]);
export function assetById(id){return CATALOG.find(a=>a.id===id)??null;}
export function variantKey(assetId,formIndex,surfaceIndex){return [assetId,formIndex,surfaceIndex].join('::');}
export function slotKey(assetId,formIndex,surfaceIndex,slot){return variantKey(assetId,formIndex,surfaceIndex)+'::'+slot;}
export function stageSlots(stage){return SLOTS.filter(s=>s.stage===stage);}
