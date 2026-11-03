PIXELLIGHT 2D - normal maps, lights and day / night for pixel art in Godot 4
by Antahonist - https://antahonist.itch.io
Godot 4.3 or newer (tested on 4.7). GDScript only, no C#, no shaders to set up.

WHAT IT DOES
- Normal maps, automatically. For every Sprite2D / AnimatedSprite2D / TextureRect it looks for a normal map
  next to the texture (name_n.png, name_normal.png, name_nrm.png, or a "normal" folder near the texture).
  If there is none, it GENERATES one from the sprite (bevel from the silhouette + detail from brightness).
  Animation strips (AtlasTexture frames) work too: a one-frame normal map is tiled across the strip.
- Lights from glowing pixels. Windows, lamps, torches, crystals: bright, saturated pixels become
  PointLight2D nodes with a soft flicker, in their own colour. If the sprite has a night version
  (same name in a "night" folder instead of "day", or name_night.png / name_emit.png) it is used, and
  the plugin compares it with the day version so lit-up snow or white walls are NOT mistaken for lights.
- Shadow occluders. LightOccluder2D polygons from the sprite's alpha: the whole silhouette or only the
  base (the bottom N rows of the visible art - best for isometric buildings).
- Day / night. One PLDayNight node: a sun (DirectionalLight2D) that crosses the sky so normal-mapped
  sprites change their shading, a sky tint (CanvasModulate), and every PixelLight light fading on one
  by one at dusk and off at dawn. AnimatedSprite2D nodes in the group "pl_day_night" switch between
  their "day" and "night" animations. Signals: hour_changed, nightfall, daybreak.

INSTALL
1. Copy addons/pixel_light_2d into your project's addons folder.
2. Project > Project Settings > Plugins > enable "PixelLight 2D".
3. A "PixelLight" dock appears on the right.

USE IT - THREE WAYS
A) Editor dock: select sprites in the scene tree, press
   "Add normal maps" / "Add lights from glowing pixels" / "Add shadow occluder" / "Add day / night cycle".
   When a texture has no normal map yet, "Add normal maps" saves the generated one as name_n.png next to
   it and the scene only references that file (1.0.1 - before, it was embedded in the .tscn and made scenes
   huge). Untick "Save generated maps as name_n.png files" to keep them in memory instead.
   "Save generated normal maps" writes name_n.png for textures selected in the FileSystem dock,
   so you can touch them up in Aseprite and keep them in version control.
   PLDayNight drives ONE CanvasModulate: it uses the one already in your scene (or the one you assign to its
   exported "tint" / "sun" properties, also settable from C#) and creates its own only if the scene has none (1.0.2).
B) No editor step: add a PLAuto node as a child of any sprite. At runtime it applies normals, lights and
   (optionally) an occluder. Every option is in the inspector.
C) From code (class PixelLight, all static):
     PixelLight.apply_normals($Sprite2D)                       # find or generate
     PixelLight.add_lights($House, night_image, $House.offset)  # returns the PointLight2D nodes
     PixelLight.add_occluder($House, image, $House.offset, "base", 16)
     var n := PixelLight.generate_normal(image, 2.0, 3, 0.35)  # strength, bevel px, detail 0..1
     var lights := PixelLight.find_lights(night_image, 0.72, 0.22, 6, 2, day_image)

NORMAL MAP CONVENTION
Godot / OpenGL: red = right, green = UP, blue = towards the camera. Maps from Laigter, SpriteIlluminator
and Blender (OpenGL setting) work as-is. If yours look lit from below, flip the green channel.

TIPS
- The light model is multiplicative: a sprite that is already painted dark at night has little colour
  left for a torch to reveal. For the strongest effect use the DAY art + PLDayNight darkness + lights
  (the demo shows both: baked night sprites by default, --daysprites for day art at night).
- A low light (PointLight2D.height 10-30) gives long, dramatic shading on the normal maps; a high one
  lights everything evenly. The same goes for PLDayNight.sun_height.
- Lights are in the group "pl_lights". Lights without a PLFlicker child just fade.

DEMO (PixelLight2D_Godot4 project)
An isometric town at real time of day, with normal maps rendered from 3D for every building.
  Mouse = torch   N = normal maps on / off   T = torch on / off   SPACE = pause the clock   [ ] = time -/+ 1 h
Command line (after --): --hour=21 --still --daysprites --nonormals --notorch --speed=30 (seconds per day)

DEMO ART
The buildings in the demo come from our pixel town packs. They are included ONLY to try the plugin:
do not use them in a game or redistribute them - get the full packs here:
  Neon City       https://antahonist.itch.io/neon-city-cyberpunk-pixel-building-kit
  Soviet City     https://antahonist.itch.io/soviet-city-isometric-pixel-buildings
  Spooky Town     https://antahonist.itch.io/spooky-town-draculas-castle-pixel-buildings
  Arcane Quarter  https://antahonist.itch.io/arcane-quarter-magic-town-pixel-buildings
  Edo Town        https://antahonist.itch.io/edo-town-feudal-japan-pixel-buildings
  Winter Village  https://antahonist.itch.io/winter-village-christmas-town-pixel-buildings

LICENSE
Plugin code (addons/pixel_light_2d): MIT - use it anywhere, commercial or not. See LICENSE.txt.
Demo art: see above.

Something missing, or a sprite where the auto lights are wrong? Tell me on the itch page.
If PixelLight helped your game, a rating on itch helps a lot.
