# Osman live-rig review — no character animation spritesheets

## Delivery versus GitHub checkout

The complete review `.love` and source ZIP supplied in the conversation contain
all approved rig data, original PNG parts, reference fixtures and engine smoke
tests. The GitHub branch currently contains the live evaluator, renderer and
plasma-test fix, but NOT the large rig-data/image bundle. A clean checkout of
this branch cannot run the new character yet. Do not merge or claim asset/CI
completion until the missing files are imported and verified.

Required: `rig.json`, `directions.json`, `display.json`, `provenance.json` and
`images/*.png` in this directory; the source bundle also includes the reference
fixture/tests and isolated smoke hook. The earlier private transfer snapshot
is retained in the existing Texture_Archive; prefer the final source ZIP from
this conversation for the complete tested revision. Do not copy expired URLs
or blindly apply an old manifest against a changed branch HEAD.

Approved input: `osman_saglak_4yon_v5.rigby`, SHA-256
`86ed6aa3e40a082b9f7b67e9074a2d3b1149facb9c785a9e44956397ab22ad92`.
The complete bundle preserves 40 bones, 24 slots, 44 authored clips and 30
original body-part PNGs (24 referenced). These are textures, not animation
frames. No external flipX: reflection and anatomical right-hand mappings are
already in the approved clips. Items are not drawn; use rigby_visual.right_hand.

The runtime continuously evaluates sparse keys, per-component Bezier curves,
bone matrices and weighted meshes. Its explicit profile is `tamu-rigby-fk/1`:
all 44 approved clips disable all 8 IK constraints. Active IK/deform/other
unsupported features are rejected, not silently ignored. This is not a general
Rigby importer. Gameplay chooses idle/walk/mine/chop; other clips are available
through the visual API, not fabricated combat or running game mechanics.

Rollback: `TAMU_USE_PLASMA=1`; original plasma code and assets remain unchanged.
No save-schema or world/physics/inventory changes. Local LÖVE 11.5/Xvfb rendering,
production scene, water, harvest and plasma rollback were exercised. This is
not Android hardware verification or successful GitHub game CI.

Reference/adapted semantics: Rigby2D pose.js blob
`07ee2d8da26a5a12df190943eb7812fbefb6c892`. The actual editor JS runtime generated
the numerical oracle. This license notice applies to runtime semantics, not
third-party rights to the user's character art.

MIT License

Copyright (c) 2026 jaisurya-dev-art

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
