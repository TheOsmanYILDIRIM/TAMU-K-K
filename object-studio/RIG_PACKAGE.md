# Mineclonie Character Rig Studio — .mrig v1

This is an additive, offline-first rig package and patch layer for `src/character-rig.html`.
It preserves the existing manual reference/prompt and PNG tools and uses a **separate**
IndexedDB database, `MineclonieCharacterPackagesV1` (`packages` store). Old Object,
Terrain, Animation, World Builder and preexisting Rig Studio records are untouched.

## Packaging and import

`src/rig-package.js` creates and validates self-contained ZIP **STORE** files (`.mrig`).
All content is inside the file; no CDN, binary dependency or external API is required.
The ZIP reader accepts stored ZIP entries only (no deflate), rejects unexpected paths,
ZIP CRC failures, duplicate entries, oversized files and unknown schemas. PNG signatures,
IHDR dimensions and CRC are checked, then the browser actually decodes all 12 images
before the new character is installed. A failure leaves the previous document active.

Required package paths:

```
manifest.json
metadata.json
rig/skeleton.json
rig/meshes.json
rig/pivots.json
rig/depth.json
animations/idle.json
animations/walk.json
animations/chop.json
sprites/front/{head,torso,armL,armR,legL,legR}.png
sprites/back/{head,torso,armL,armR,legL,legR}.png
```

`manifest.json` contains `format: "mineclonie-character-rig"`, `schemaVersion: 1`,
`characterId`, `revision`, `viewMode: "two-plus-mirror"` and creation metadata.
Anatomical L/R identifiers never change during mirror rendering. `meshes.json` holds
per-view, per-part grid dimensions, per-vertex weights and bend scale.
`animations/*.json` are data-driven clip durations, loop flags and parameters.
The renderer applies parent-node relative transforms, local joints, clip motion,
Z ordering and weighted mesh tessellation; absence of animations or images fails validation.

## Atomic patches

Paste JSON into **Rig / Animasyon Güncellemesi Uygula**, choose **Önizleme / Doğrula**
and then **Güncellemeyi Uygula**. One revision is advanced per patch. Before apply, the
entire prior document is snapshotted in the separate IndexedDB store; the patch is
constructed on a clone and fully validated before the store's single write transaction.
**Geri Al** restores the previous document. Re-applying an identical revision is rejected.

```json
{
  "format": "mineclonie-rig-patch",
  "schemaVersion": 1,
  "characterId": "mineclonie-human-001",
  "baseRevision": 1,
  "targetRevision": 2,
  "operations": [
    {"op":"setAnimationParameters","name":"walk","values":{"stepX":6.7,"footLift":10.2,"armSwing":0.105}}
  ]
}
```

Supported operations: `replaceAnimation`, `updateAnimation`, `setNode` (node transform,
not parent reassignment), `setPivot`, `setMesh`, `setWeights`, `setDepthOrder`,
`setAnimationParameters`, and `replaceSprite` (PNG base64 data). For all view-specific
ops, `view` is `front` or `back`; for sprite/pivot/mesh ops, `part` is one of the six
anatomical IDs. `replaceSprite` accepts `pngBase64`. Updates merge only listed fields,
except named `replace*` operations which replace that designated resource.

The standard gallery has four views (`front`, `frontMirror`, `back`, `backMirror`) and
three clips (`idle`, `walk`, `chop`). This is a parameter-driven six-piece 2D puppet;
a fully articulated elbow/knee IK rig or exact planted-foot simulation requires
additional geometry and a more advanced animation solver.

## Testing and deployment

`npm run verify` runs Node tests and publishes `dist/character-rig.html` together
with `dist/rig-package.js` and `dist/rig-workspace.js`. GitHub Pages Actions copies
all dist files to `/oyun/object-studio/`. No changes to the LÖVE2D game or to
other studios' persistence are required.