# Mixamo four-view character projection — Blender audit (2026-10-14)

## Scope and isolation
Repository: `TheOsmanYILDIRIM/oyun`, experimental branch
`experiment/blender-camera-reference-20261011`.
`main` and `backup/pre-portrait-reboot-20261011` were not written.
The task is a **technical feasibility prototype**, not a visually accepted
character asset or a deployable game sprite.

Input illustration: user-uploaded 1254×1254 RGBA four-angle peasant sheet,
SHA-256 `4686eacb9a2d11be4893b450cb73c02dd8b8a4abd564fabe34c91e3fad36d42c`.
The Actions runner currently receives a **lossy 320×320 cyan-key WebP proxy**,
SHA-256 `26e14b356e0f4a705eb10e69a574a7c812f80a57d60e26446e9d689f3441260c`.
This is lower quality than the original and may introduce colour fringe. It is
not evidence that the full-resolution texture was transferred.

Animation/mesh source: pinned `Walking.fbx`, 1,839,568 bytes, SHA-256
`c33a3c2606afe7e7ec208ebb5dee26f28eaf1ad2f62cd7a187560cd1a252413f`,
retrieved unchanged from repository commit `18fdb06e194a757b356de0668c7cd2246db80ece`.

## Actual execution evidence
- V1: commit `2c3912953ac90dbde7042e75554badea3f300cca`;
  [Actions #38614828013](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/38614828013).
  Workflow passed and rendered 8 genuine SE walking frames, but inspection
  showed a heavily fragmented, robot-like projected image.
- V2: commit `fc739fa6802944f61bf195f3e8a33de6bcff6ee7`;
  [Blender Actions #38620132974](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/38620132974),
  [quality #38620133002](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/38620133002),
  both completed successfully.
  Corrected the source front-left/front-right view association and replaced
  one repeatedly-mutated projection camera with four **separately evaluated
  camera objects**. Genuine four-way material face assignment is confirmed.
- [Download the V2 render artifact (while retained by Actions)](https://github.com/TheOsmanYILDIRIM/oyun/actions/runs/38620132974/artifacts/11921751648):
  eight actual `SE_00.png` … `SE_07.png` images, contact sheet, 4-angle
  albedo and transparent references, diagnostics JSON, and editable
  `fourview_projected.blend`. Its retention period is 10 days.

Technical validation:
- Blender 4.0.2 imported one 65-bone Mixamo armature and two skinned meshes;
  both retained their armature modifiers.
- Imported Walking action has 32 frames (1–32); evaluated render frames
  `[1, 5, 9, 13, 17, 21, 25, 29]` from the **real** skinned animation.
- Eight 512×512 PNGs contain nonempty alpha, and the post-render proof sheet
  and JSON diagnostics were uploaded successfully.
- First V1 output was misleadingly SE-dominated (~84% of faces assigned SE);
  V2 assigns all four directions as distinct projectors.

## V2 quantitative projection diagnostics
Values below describe **face material transitions and reference alpha
support**, not visually invisible seams or an SSIM / image similarity score.

| Skinned object | Tri/face count | 4-view boundary edges / internal shared edges | Boundary ratio | Faces without matching reference alpha |
|---|---:|---:|---:|---:|
| `Beta_Joints` | 11,120 | 3,086 / 21,540 | 14.327% | 2,616 (23.525%) |
| `Beta_Surface` | 14,222 | 4,510 / 28,358 | 15.904% | 3,645 (25.629%) |

Note: V1 had artificially lower face-boundary ratios (3.33% / 4.98%)
because it largely reused one projection direction. Directly interpreting
that difference as a visual improvement or regression would be incorrect.

## Visual audit (actual SE contact sheet and image-to-source comparison)
**Visual acceptance: FAILED**, despite green CI.

1. **Silhouette:** the Mixamo Beta mannequin has a rounded head, mechanical
   joint shapes, close-fitting limb volumes, and no physically modeled hair,
   loose tunic hem or leather boots. Texture alone cannot change these.
2. **Dikiş / seams:** abrupt material transitions and duplicated painted
   features are visible at torso/limb boundaries; roughly 14–16% of internal
   mesh edges join different view materials in V2.
3. **Deformation:** source clothing and anatomy do not follow leg swing
   coherently. Brown trouser/boot regions break up into cyan/green and
   white strips; inside-leg and hip surfaces are not supplied by coherent
   3D textures. These artefacts are visible across the sampled frames.
4. **Four-view consistency:** source images describe different 3D surfaces
   only indirectly and lack UV correspondence/depth calibration. Four
   independent projections now exist, but painting different faces from
   overlapping perspective images cannot guarantee seamless clothing.
5. **Motion:** original Walking animation actually plays on the original
   armature. This confirms rigging/animation transport, **not** accepted
   character appearance or foot-ground contact quality. Ground-contact
   frames/foot slip have not been measured.

## Technical decision and proposed next step
**Result:** static/animated four-camera texture projection is technically
feasible, but **not visually acceptable for this specific character on
the Mixamo Beta mesh without shape changes or better target geometry**.
Do not ship, auto-promote to `main`, or represent this as a finished
character. Do not extrapolate from the limited 8 sampled SE frames to
all-angle/all-frame visual acceptance.

Next experiment (separate authorisation / same open Avenox task):
prefer a human/clothed base whose head, sleeves, tunic and boots roughly match
the illustration, plus semantic body-region UV masks and a true full-resolution
RGBA source. Alternatively, for the 45° fixed-angle 2D game, use a
2.5D layered deformable rig driven by Mixamo bone motion; it can preserve
the illustrated outer contour but requires joint/occlusion and foot-slip
validation. No method has been proven successful yet.
