import {STYLE} from './catalog.js';
const words={
  meadow:'Meadow context: natural dry/green foliage restraint, open sightlines, little ground clutter.',
  forest:'Forest context: slightly darker aged moisture cues, moss in sheltered parts, grouped silhouettes but no baked environment.',
  rocky:'Rocky context: cool mineral dust, sparse tough growth, restrained wear and wind exposure.'
};
// One targeted isolation prompt per object AND output layer; never redraw all layers together.
const LAYER_DETAILS={
'T-01':[
'Extract only the low root flare contact, flattened soil, restrained pressed grasses and small leaf litter around this ancient broadleaf oak. Exclude upright trunk wood, branches and every canopy leaf.',
'Extract only the aged thick trunk, visible root wood and exposed major branch skeleton of this oak. Preserve the bark and moss appearance from the corrected master. Remove all crown leaf masses, soil halo and cast shadows.',
'Extract only the overhead and rear crown clusters of this asymmetrical old oak, leaving its original gaps and branch breaks transparent. Exclude near-facing occluding foliage, trunk and ground.',
'Extract only the nearest low hanging boughs and foreground leaf clusters of this oak that need to overlap the player. Exclude rear canopy, trunk and ground; if no separable front foliage exists, leave transparent.'
],
'T-02':[
'Extract only fallen needle litter and compact root contact at the foot of the conifer; exclude trunk and all needle branches.',
'Extract only the narrow resinous wood trunk and exposed main branch axes beneath the needles. Exclude green needle masses and ground debris.',
'Extract only far and upper tiered conifer needle masses while preserving irregular negative spaces between tiers. Exclude trunk and the lowest near-facing branches.',
'Extract only lower near-facing drooping needle boughs that may overlap a player. Exclude the back tiers and trunk; preserve an empty layer if none is unambiguously identifiable.'
],
'T-03':[
'Extract only compact root contact, pressed grass and minimal soil at the sapling base; do not include the slender stem or leaves.',
'Extract only the curved young stem and structurally visible sparse twigs, preserving bends. Exclude leaves and ground.',
'Extract only upper and rear small leaf groups; preserve negative space and exclude stem and front-most leaf clusters.',
'Extract only the near-facing leaves or thin twigs that would occlude a player. If not clearly separable, output transparent pixels rather than inventing extra foliage.'
],
'R-01':[
'Extract only fine grit, dust contact and tiny loose fragments beneath the stone cluster, excluding all standing stones.',
'Extract only the principal lower stone bodies of this 3–5 stone group while retaining their original spatial overlap and stone count. Exclude upper-facing facets and loose ground grit.',
'Extract only existing upper-facing mineral facets on the clustered stones with correct rear/near overlap. Do not add new stones or invent highlighted faces.',
'Extract only genuinely foreground small stone lips or edges that obscure the lower shapes. If no distinct foreground lip exists, output transparent pixels.'
],
'R-02':[
'Extract only buried-contact grit and restrained dust at the medium boulder footprint; exclude its large solid rock body.',
'Extract only the main heavy lower and side mineral mass, original crack layout and embedded shape. Exclude separable top facet and ground grit.',
'Extract only the actual visible upper facet and upper broken plane from the finished boulder, preserving exact polygon angles and mineral texture. Do not invent extra faces.',
'Extract only the near-facing projecting stone lip where it actually exists and can obscure a player. Keep fully transparent when no discrete lip exists.'
],
'R-03':[
'Extract only angular fallen shards, dust and burial contact around this landmark boulder; exclude main monolith volume.',
'Extract only the monumental lower rock masses and exposed side planes, keeping two-part weight and original structural fractures. Exclude separable upper face and debris.',
'Extract only the large off-center crest/top fractured plane, with its approved strata and worn edges; do not invent new cracks or peaks.',
'Extract only the existing front-projecting low rock lip that can overlap the player. Do not fabricate an overhang from shadow or contrast.'
],
'R-04':[
'Extract only the terrain-connected stone dust, contact strata and scattered grit joining this outcrop to its ground. Exclude rising rock volumes.',
'Extract only the long embedded primary strata and lower shoulder rock, preserving the original grounded footprint and its continuous body.',
'Extract only the raised fractured crest and upper existing stone strata. Maintain true near/far ridge alignment; do not turn it into a freestanding cliff.',
'Extract only the actual near-facing rock overhang/front edge usable as an occlusion layer; output transparent if none exists.'
]
};
export const LAYER_PROMPT_SLOTS=Object.freeze(['base','body','upper','front']);
export function promptFor(asset,stage,form,surface,biome,layer='body'){
  if(!asset||!asset.art) return null;
  const shape=asset.forms[form],finish=asset.surfaces[surface];
  if(!shape||!finish||!words[biome]) return null;
  const specific=`Object ${asset.id}, ${asset.name} (${asset.species}). Chosen form: ${shape}. Chosen surface: ${finish}. ${words[biome]}`;
  const visual=`Art direction: ${STYLE.target}. ${STYLE.avoid}`;
  if(stage==='reference')return [
    'STAGE 01 — STYLE / WORLD REFERENCE (IMAGE B).',specific,asset.reference,visual,
    'One square material/world mood study; not the production game sprite. Describe material character and environmental age. Do not instruct a specific UV atlas, crop or replacement of Image A composition.'
  ].join('\n\n');
  if(stage==='creative')return [
    'STAGE 02 — CREATIVE ISOLATED ASSET (NO SOURCE IMAGE REQUIRED).',specific,asset.art,visual,STYLE.silhouette,
    'Allow a strong creative form concept, do not upscale any pixel source. No decorative scene, text or cast shadow. Output PNG RGBA, 1024×1024 square.'
  ].join('\n\n');
  if(stage==='correction')return [
    'STAGE 03 — COMPOSITION-LOCKED A+B PRODUCTION.',specific,
    'Image A = approved creative design / structural source. Use Image A ONLY for the silhouette footprint, body proportions, canvas placement, pivot, alpha boundary logic and 45° isometric ground orientation. Image B = approved MATERIAL AND STYLE MASTER. The finished asset must derive its dominant artistic identity, surface design, material richness, age, tones and shape styling from Image B.',
    "CRITICAL: Do not imitate Image A surface appearance, internal texture, leaf clusters, bark grain, stone fractures or original artistic finish. Image A is NOT the style source. The result must look like Image B's object language placed into Image A's structural slot, NOT like Image A with minor polish.",
    asset.correction,visual,STYLE.silhouette,
    'Preserve the composition, object type, broad silhouette and negative alpha space from Image A without inheriting its surface aesthetic. Do not copy the background or scene framing from Image B. Output exactly one isolated 1024×1024 square RGBA PNG with REAL transparent background, no pedestal, scene, border, labels, checkerboard or baked cast shadow.'
  ].join('\n\n');
  if(stage==='layers'){
    const slotIndex=LAYER_PROMPT_SLOTS.indexOf(layer),instructions=LAYER_DETAILS[asset.id];
    if(slotIndex===-1||!instructions?.[slotIndex])return null;
    const labels=['L0 — CONTACT / GROUND','L1 — STRUCTURAL BODY','L2 — UPPER / BACK VOLUME','L3 — FOREGROUND OCCLUSION'];
    return [
      'STAGE 04 — INDIVIDUAL LAYER EXTRACTION — '+labels[slotIndex]+'. OUTPUT THIS ONE LAYER ONLY.',specific,
      'Image A is the APPROVED final corrected 1024×1024 object. It is the sole authoritative source of the pixels, silhouette, position and material look. This is an extraction task, NOT a new creative asset. Never substitute the earlier creative draft or style reference.',
      instructions[slotIndex],visual,
      'Produce exactly ONE 1024×1024 RGBA PNG corresponding ONLY to '+labels[slotIndex]+'. Keep the same canvas coordinates, pivot, scale and angle as Image A. Never recenter, crop, rotate, resize or add a camera/background. Pixels outside the extracted part must be truly transparent, not checkerboard or colored matte. No ground plane, shadow, new material, invented geometry, smoothing or retouching. Do not draw other layers as context. Keep shared boundary pixels assigned to one layer rather than duplicated. Preserve source details whenever unambiguously identifiable; if a region cannot be separated with confidence, leave it transparent and flag for manual review rather than hallucinating a missing part.',
      'COMPOSITING CHECK: L0 + L1 + L2 + L3 must reconstruct the approved master without gaps, double-opacity seams or misregistration. A generated PNG is NOT automatically proof of pixel-perfect extraction; compare aligned layers and the approved master before acceptance.'
    ].join('\n\n');
  }
  if(stage==='maps')return [
    'STAGE 05 — PHYSICALLY PLAUSIBLE MATERIAL MAPS.',specific,
    'Image A = approved corrected/color asset. Export separately aligned 1024×1024 tangent-space normal RGB and grayscale height data when relevant.',asset.maps,
    'Normal encodes surface lighting detail only. Height can drive mesh deformation or displacement in a later pipeline and must not invent geometry inconsistent with the object. Maintain silhouette, anchor, physical scale and UV registration. Avoid baked shadows/highlights.'
  ].join('\n\n');
  return null;
}
export function stageGuide(stage,asset){
  const text={
    direction:`${asset.id} · ${asset.species}\nSiluet: ${asset.art}\nZemindeki rol: ${asset.placement}\nFiziksel ayak izi: ${asset.footprint[0]} × ${asset.footprint[1]} birim. Çarpışma: ${asset.collider}.`,
    approval:'Kabul etmeden önce: 45° kamerada siluet ve ölçek, gerçek PNG alpha, 1:1 kare, pivot/ayak izi, dinamik gölge, çarpışma, biyom uyumu ve oyun ölçeğinde okunurluğu gözle kontrol et. Eksik normal/height haritası ancak planlı ve açıkça bekleyen iş olarak işaretlenebilir.'
  };
  return text[stage]??null;
}
