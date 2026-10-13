import {STYLE} from './catalog.js';
const words={
  meadow:'Meadow context: natural dry/green foliage restraint, open sightlines, little ground clutter.',
  forest:'Forest context: slightly darker aged moisture cues, moss in sheltered parts, grouped silhouettes but no baked environment.',
  rocky:'Rocky context: cool mineral dust, sparse tough growth, restrained wear and wind exposure.'
};
export function promptFor(asset,stage,form,surface,biome){
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
  if(stage==='layers')return [
    'STAGE 04 — LOSSLESS ALIGNED LAYER EXTRACTION.',specific,
    'Image A = approved final corrected PNG. Separate it into co-registered RGBA layers while preserving the full Image A composition and external alpha silhouette.',asset.layer,
    'Each output exactly 1024×1024, identical orientation/anchor, no recropping or rescaling. Transparent outside its own pixels; no matte or checkerboard. No newly invented geometry. Shadows remain runtime-controlled and separate.'
  ].join('\n\n');
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
