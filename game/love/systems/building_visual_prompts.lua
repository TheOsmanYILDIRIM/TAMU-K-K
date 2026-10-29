-- Authored construction art prompts, adapted from TAMU Texture Production Guide
-- and MTS Prompt Authoring Guide. No generic prompt fallback.
-- Prompts prepare individual assets; they do not claim any PNG was produced.
local Visual=require("systems.building_visual_contract")
local Prompt={}
local STYLE="Grounded dark-fantasy material realism; ancient, naturally weathered, "..
  "somber muted tones, tactile physically credible surfaces, restrained saturation, "..
  "soft diffuse neutral illumination, low-to-medium contrast. Readable silhouette at "..
  "actual mobile game distance. No voxel/pixel-art noise, cartoon outlines, "..
  "plastic gloss, oversized ornaments, fake depth, dramatic baked highlights or glow."
local materials={
  wood="Weathered structural timber. Keep believable long grain aligned to load-bearing "..
    "beams; shallow worn joints, occasional knots, subdued warm brown-grey fibers. "..
    "Continuous board dimensions and identical edge treatment across sibling pieces.",
  stone="Aged fitted masonry. Keep plausible stone courses, finely weathered mineral grain, "..
    "subtle mortar joints and muted slate/earth grey values. Course height, stone scale "..
    "and end patterns must match adjacent wall and foundation pieces."
}
local shapes={
  foundation="One raised square 32x32-unit structural foundation. Exact square footprint "..
    "with four flat join edges, a level 4-unit slab and understated structural base. "..
    "No soil, terrain sculpting or decorative border outside the footprint.",
  floor="One thin square 32x32-unit walkable deck/slab, thickness 2 units. "..
    "Keep all four edges straight and coplanar. Continuous boards or masonry "..
    "with no standalone framing that would double in a tiled room.",
  wall="One straight 32-unit-wide, 24-unit-high wall panel, thickness 2 units. "..
    "Flush end planes, squared foundation contact and flat upper support line. "..
    "No protruding corner columns or trims that duplicate at panel joins.",
  window="One 32-unit-wide by 24-unit-high wall panel, thickness 2 units, with one "..
    "legible centered window void. Outside frame and structural edges must be "..
    "identical to the full wall of the same material. Real alpha through the opening.",
  doorway="One 32-unit-wide by 24-unit-high wall frame, thickness 2 units, with a "..
    "central walk-through opening. Equal footing and header geometry to the "..
    "same-material wall. Keep the opening visibly empty with actual alpha.",
  halfwall="One 32-unit-wide by 12-unit-high low wall with thickness 2 units. "..
    "Same end-plane and grain/course rhythm as the full wall; top line level.",
  railing="One 32-unit-long by 12-unit-high thin protective railing. "..
    "Posts remain inside the 32-unit module; end posts never double at seams. "..
    "Open spaces are real alpha, not painted dark.",
  post="One narrow 2x2-unit vertical corner post, 24 units high. Precisely centered "..
    "foot and straight vertical silhouette; align surface scale with full walls.",
  roof_flat="One 32x32-unit flat roof segment, thickness 2 units. Straight tile edges "..
    "on a common level; no independent roof border on each repeat.",
  roof_slope="One 32x32-unit sloped roof silhouette in a 12-unit maximum height envelope. "..
    "Pitch faces exactly in the requested world direction. Straight uninterrupted "..
    "side seams and a matched continuous roof-covering rhythm; no standalone ridge "..
    "or eaves that would double across neighboring tiles.",
  stairs="One 32x32-unit stair flight with 24-unit rise. Regular treads and risers; "..
    "bottom and top connection faces exactly match the assigned ground and upper "..
    "deck levels. All riser steps remain within the 32x32x24 envelope.",
  fence="One 32-unit straight fence segment, thickness 2 units, height 12 units. "..
    "Identical end-connection height and rail alignment on both ends. "..
    "Fence ends remain flush; do not duplicate corner posts.",
  fence_gate="One 32-unit-wide gate segment, height 12 units, matching the fence's "..
    "post and rail attachment heights. Show clear hinges, latch and a readable "..
    "operable gate leaf; no surrounding environment."
}
local function coords(layout)
  local a,b=layout.bottom.nw,layout.bottom.ne
  local c,d=layout.bottom.se,layout.bottom.sw
  return ("Canvas 1024x1024. Required base pivot (%d,%d). "..
    "Base footprint reference landmarks (NW %.2f,%.2f; NE %.2f,%.2f; "..
    "SE %.2f,%.2f; SW %.2f,%.2f). Preserve them without perspective drift."):format(
    Visual.pivot_x,Visual.pivot_y,a.px,a.py,b.px,b.py,c.px,c.py,d.px,d.py)
end
function Prompt.make(def,rotation,stage)
  if not def or not def.visual then return nil,"missing_visual_contract" end
  local material=materials[def.visual.material]
  local shape=shapes[def.visual.shape]
  if not material or not shape then return nil,"unauthored_piece" end
  if stage~="reference" and stage~="production" and stage~="correction" then
    return nil,"unknown_stage"
  end
  local layout=Visual.layout(def,rotation)
  local common={"Asset: "..def.id.."; variant "..layout.direction..
    " (world rotation "..rotation.." of four independently authored views).",
    shape,material,STYLE}
  if stage=="reference" then
    return table.concat({
      "STAGE 01 — CANONICAL MATERIAL REFERENCE (not a game sprite).",
      common[1],common[2],common[3],common[4],
      "One deliberately authored material-and-join study; no source geometry "..
      "changes, no view labels, no atlas, no environment or baked directional shadow."
    },"\n\n")
  end
  local joint="Image A = exact construction geometry template generated from "..
    "world-space 45-degree isometric projection. Image A controls footprint, "..
    "eight top/bottom corners, socket positions, silhouette bounds, pivot and "..
    "transparent openings. Image B = approved MTS/TAMU material/style master; "..
    "Image B controls surface character, grain/mineral detail, patina and age. "..
    "Do NOT borrow geometry from B or material/lighting from A."
  local required=coords(layout).." Source pixels are a strict guide; if the "..
    "generated image drifts, use deterministic alpha/compositing correction "..
    "rather than forgiving a mismatched socket. The four variants must use "..
    "identical world scale and the same material edge-strip design."
  local output="Output exactly ONE isolated 1024x1024 straight-RGBA transparent PNG, "..
    "one camera-locked orthographic 45-degree isometric view. No contact sheet, "..
    "poster, terrain, platform, backdrop, text, checkerboard, borders or baked "..
    "cast/contact shadows. Keep every surface within the documented module "..
    "envelope and leave all empty openings genuinely transparent."
  local hdr=stage=="production" and
    "STAGE 02 — GEOMETRY-LOCKED ISOLATED CONSTRUCTION SPRITE." or
    "STAGE 03 — COMPOSITION CORRECTION / SEAM LOCK."
  return table.concat({hdr,common[1],common[2],common[3],common[4],
    joint,required,output},"\n\n")
end
function Prompt.authored_shapes()
  local keys={}
  for k in pairs(shapes) do keys[#keys+1]=k end
  table.sort(keys)
  return keys
end
return Prompt
