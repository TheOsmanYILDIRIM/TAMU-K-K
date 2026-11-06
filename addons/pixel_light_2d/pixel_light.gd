@tool
class_name PixelLight
extends RefCounted
## PixelLight 2D core: normal maps, automatic lights and occluders for 2D sprites.
## Everything is static, so the editor dock, the PLAuto node and your own scripts all use the same code.

const NORMAL_SUFFIXES := ["_n", "_normal", "_nrm"]
const LIGHT_GROUP := "pl_lights"
static var _light_tex: GradientTexture2D
static var _normal_cache := {}          # path -> Texture2D (tiled normals are cached by path + count)


# ---------------------------------------------------------------- normal maps
## Looks for a normal map next to a texture: name_n.png, name_normal.png, name_nrm.png, or a "normal" folder
## up to three levels above (the Antahonist town packs keep one normal map per sprite for every look and state:
## buildings/<look>/day/house.png -> buildings/<look>/normal/house.png or buildings/normal/house.png).
static func find_normal_path(tex_path: String) -> String:
	if tex_path == "" or not tex_path.begins_with("res://"):
		return ""
	var dir := tex_path.get_base_dir()
	var base := tex_path.get_file().get_basename()
	var ext := tex_path.get_extension()
	for s in NORMAL_SUFFIXES:
		var p := dir.path_join(base + s + "." + ext)
		if ResourceLoader.exists(p):
			return p
	var up := dir
	for i in 3:
		var p := up.path_join("normal").path_join(base + "." + ext)
		if ResourceLoader.exists(p):
			return p
		up = up.get_base_dir()
	return ""


## A normal map for `diffuse`: the file next to it if there is one, otherwise generated from the pixels.
## When the diffuse is an animation strip N frames wide and the normal map is one frame, the normal is tiled N times.
static func normal_for(diffuse: Texture2D, generate := true, strength := 2.0, bevel := 3, detail := 0.35) -> Texture2D:
	if diffuse == null:
		return null
	var path := diffuse.resource_path
	var key := "%s|%d|%d|%.2f|%d|%.2f" % [path, diffuse.get_width(), diffuse.get_height(), strength, bevel, detail]
	if path != "" and _normal_cache.has(key):
		return _normal_cache[key]
	var nrm: Texture2D = null
	var np := find_normal_path(path)
	if np != "":
		nrm = load(np)
		var k := diffuse.get_width() / maxi(1, nrm.get_width())
		if k > 1 and nrm.get_width() * k == diffuse.get_width() and nrm.get_height() == diffuse.get_height():
			nrm = _tile(nrm.get_image(), k)
	elif generate:
		nrm = ImageTexture.create_from_image(generate_normal(diffuse.get_image(), strength, bevel, detail))
	if path != "" and nrm:
		_normal_cache[key] = nrm
	return nrm


## Forget cached normal maps (after new name_n.png files were written).
static func clear_cache() -> void:
	_normal_cache.clear()


## The plain textures a node draws (Sprite2D, every frame of an AnimatedSprite2D, TextureRect), without duplicates.
static func textures_of(node: Node) -> Array:
	var out := []
	if node is Sprite2D:
		out.append(_base((node as Sprite2D).texture))
	elif node is TextureRect:
		out.append(_base((node as TextureRect).texture))
	elif node is AnimatedSprite2D and (node as AnimatedSprite2D).sprite_frames:
		var sf := (node as AnimatedSprite2D).sprite_frames
		for anim in sf.get_animation_names():
			for f in sf.get_frame_count(anim):
				var t := _base(sf.get_frame_texture(anim, f))
				if t and not out.has(t):
					out.append(t)
	return out.filter(func(t): return t != null)


## Writes a generated normal map as name_n.png next to `tex` when the texture is a file and has no normal map yet.
## Returns the new path, or "" when nothing was written. A scene that uses a file-backed normal map stays small;
## a generated one kept only in memory would be embedded into the .tscn when the scene is saved.
static func save_generated_normal(tex: Texture2D, strength := 2.0, bevel := 3, detail := 0.35) -> String:
	if tex == null:
		return ""
	var p := tex.resource_path
	if not p.begins_with("res://") or not (p.get_extension() in ["png", "webp"]) or find_normal_path(p) != "":
		return ""
	for s in NORMAL_SUFFIXES:
		if p.get_basename().ends_with(s):
			return ""
	var out := p.get_basename() + "_n.png"
	if generate_normal(tex.get_image(), strength, bevel, detail).save_png(out) != OK:
		return ""
	return out


static func _tile(img: Image, k: int) -> ImageTexture:
	if img.is_compressed():
		img.decompress()
	var out := Image.create(img.get_width() * k, img.get_height(), false, img.get_format())
	for i in k:
		out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(i * img.get_width(), 0))
	return ImageTexture.create_from_image(out)


## Normal map from a sprite's own pixels: a bevel from the silhouette (distance to the edge, up to `bevel` px)
## plus a little relief from brightness (`detail`). Edges outward, flat inside: reads well on pixel art.
static func generate_normal(src: Image, strength := 2.0, bevel := 3, detail := 0.35) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var dist := PackedInt32Array()
	dist.resize(n)
	var queue := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			if img.get_pixel(x, y).a < 0.5:
				dist[i] = 0
				queue.append(i)
			else:
				dist[i] = 1 << 20
	for y in h:                                                 # the image border counts as outside
		for x in [0, w - 1]:
			var i: int = y * w + x
			if dist[i] > 1:
				dist[i] = 1
				queue.append(i)
	for x in w:
		for y in [0, h - 1]:
			var i: int = y * w + x
			if dist[i] > 1:
				dist[i] = 1
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var y := i / w
		var d := dist[i] + 1
		for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + o[0]
			var ny: int = y + o[1]
			if nx >= 0 and ny >= 0 and nx < w and ny < h:
				var j := ny * w + nx
				if dist[j] > d:
					dist[j] = d
					queue.append(j)
	var height := PackedFloat32Array()
	height.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				height[i] = 0.0
			else:
				var b := clampf(float(dist[i]) / maxf(1.0, float(bevel)), 0.0, 1.0)
				height[i] = b * (1.0 - detail) + c.get_luminance() * detail
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			if img.get_pixel(x, y).a < 0.5:
				out.set_pixel(x, y, Color(0.5, 0.5, 1.0, 0.0))
				continue
			var hl := height[y * w + maxi(0, x - 1)]
			var hr := height[y * w + mini(w - 1, x + 1)]
			var hu := height[maxi(0, y - 1) * w + x]
			var hd := height[mini(h - 1, y + 1) * w + x]
			var v := Vector3((hl - hr) * strength, (hd - hu) * strength, 1.0).normalized()   # y up (OpenGL / Godot 2D)
			out.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5, 1.0))
	return out


## Wraps a texture so it carries a normal map (works as a Sprite2D texture, inside SpriteFrames and as an atlas).
static func lit_texture(diffuse: Texture2D, normal: Texture2D) -> Texture2D:
	if diffuse == null or normal == null:
		return diffuse
	if diffuse is CanvasTexture:
		(diffuse as CanvasTexture).normal_texture = normal
		return diffuse
	var ct := CanvasTexture.new()
	ct.diffuse_texture = diffuse
	ct.normal_texture = normal
	return ct


static func _base(t: Texture2D) -> Texture2D:
	if t is CanvasTexture:
		return (t as CanvasTexture).diffuse_texture
	if t is AtlasTexture:
		return _base((t as AtlasTexture).atlas)
	return t


## Adds normal maps to a Sprite2D, AnimatedSprite2D (every frame of every animation) or TextureRect.
## Returns how many textures got a normal map.
static func apply_normals(node: Node, generate := true, strength := 2.0, bevel := 3, detail := 0.35) -> int:
	var count := 0
	if node is Sprite2D:
		var s := node as Sprite2D
		var nrm := normal_for(_base(s.texture), generate, strength, bevel, detail)
		if nrm:
			s.texture = lit_texture(_base(s.texture), nrm)
			count += 1
	elif node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames == null:
			return 0
		var sf := a.sprite_frames.duplicate() as SpriteFrames
		for anim in sf.get_animation_names():
			for f in sf.get_frame_count(anim):
				var t := sf.get_frame_texture(anim, f)
				if t is AtlasTexture:
					var at := t as AtlasTexture
					var src := _base(at.atlas)
					var lit := AtlasTexture.new()                          # the strip itself carries the (tiled) normal map
					lit.atlas = lit_texture(src, normal_for(src, generate, strength, bevel, detail))
					lit.region = at.region
					lit.margin = at.margin
					lit.filter_clip = at.filter_clip
					sf.set_frame(anim, f, lit, sf.get_frame_duration(anim, f))
				else:
					var nrm := normal_for(_base(t), generate, strength, bevel, detail)
					sf.set_frame(anim, f, lit_texture(_base(t), nrm), sf.get_frame_duration(anim, f))
				count += 1
		a.sprite_frames = sf
	elif node is TextureRect:
		var r := node as TextureRect
		var nrm := normal_for(_base(r.texture), generate, strength, bevel, detail)
		if nrm:
			r.texture = lit_texture(_base(r.texture), nrm)
			count += 1
	return count


## Removes normal maps again (back to the plain textures).
static func remove_normals(node: Node) -> void:
	if node is Sprite2D:
		(node as Sprite2D).texture = _base((node as Sprite2D).texture)
	elif node is AnimatedSprite2D and (node as AnimatedSprite2D).sprite_frames:
		var sf := (node as AnimatedSprite2D).sprite_frames.duplicate() as SpriteFrames
		for anim in sf.get_animation_names():
			for f in sf.get_frame_count(anim):
				var t := sf.get_frame_texture(anim, f)
				if t is AtlasTexture:
					var at := AtlasTexture.new()
					at.atlas = _base((t as AtlasTexture).atlas)
					at.region = (t as AtlasTexture).region
					sf.set_frame(anim, f, at, sf.get_frame_duration(anim, f))
				else:
					sf.set_frame(anim, f, _base(t), sf.get_frame_duration(anim, f))
		(node as AnimatedSprite2D).sprite_frames = sf


# ---------------------------------------------------------------- automatic lights
## Finds the light sources in an image: bright, saturated pixels (windows, lamps, fires, neon) grouped into blobs.
## Returns [{pos: Vector2 (pixels), color: Color, size: int}], blobs closer than `merge_px` are merged.
static func find_lights(src: Image, min_value := 0.72, min_sat := 0.22, merge_px := 6.0, min_size := 2, reference: Image = null) -> Array:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	var ref: Image = null                                         # day version: a light is what the night tint can't explain
	var tint := Color(1, 1, 1)
	if reference and reference.get_size() == img.get_size():
		ref = reference.duplicate() as Image
		if ref.is_compressed():
			ref.decompress()
		tint = _night_tint(img, ref)
	var w := img.get_width()
	var h := img.get_height()
	var hot := PackedByteArray()
	hot.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.v >= min_value and (c.s >= min_sat or c.v > 0.97):
				if ref == null:
					hot[y * w + x] = 1
				else:
					var d := ref.get_pixel(x, y)
					var ex := maxf(c.r - d.r * tint.r, maxf(c.g - d.g * tint.g, c.b - d.b * tint.b))
					if ex > 0.22:
						hot[y * w + x] = 1
	var blobs := []
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if hot[start] == 0 or seen[start] == 1:
			continue
		var stack := [start]
		seen[start] = 1
		var sx := 0.0
		var sy := 0.0
		var col := Color(0, 0, 0, 0)
		var cnt := 0
		while stack.size() > 0:
			var i: int = stack.pop_back()
			var x := i % w
			var y := i / w
			sx += x
			sy += y
			col += img.get_pixel(x, y)
			cnt += 1
			for oy in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					var nx: int = x + ox
					var ny: int = y + oy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						var j := ny * w + nx
						if hot[j] == 1 and seen[j] == 0:
							seen[j] = 1
							stack.append(j)
		blobs.append({"pos": Vector2(sx / cnt, sy / cnt), "color": col / cnt, "size": cnt})
	var merged := true
	while merged:                                               # merge blobs that sit close together
		merged = false
		for a in blobs.size():
			for b in range(a + 1, blobs.size()):
				if blobs[a].pos.distance_to(blobs[b].pos) <= merge_px:
					var A: Dictionary = blobs[a]
					var B: Dictionary = blobs[b]
					var t: float = A.size + B.size
					A.pos = (A.pos * A.size + B.pos * B.size) / t
					A.color = (A.color * A.size + B.color * B.size) / t
					A.size = int(t)
					blobs.remove_at(b)
					merged = true
					break
			if merged:
				break
	return blobs.filter(func(b): return b.size >= min_size)


## Median night/day ratio per channel over the whole sprite: most pixels are not lights, so this is the night tint.
static func _night_tint(night: Image, day: Image) -> Color:
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var b := PackedFloat32Array()
	for y in range(0, night.get_height(), 2):
		for x in range(0, night.get_width(), 2):
			var n := night.get_pixel(x, y)
			var d := day.get_pixel(x, y)
			if n.a > 0.5 and d.a > 0.5 and d.v > 0.15:
				r.append(n.r / maxf(d.r, 0.04))
				g.append(n.g / maxf(d.g, 0.04))
				b.append(n.b / maxf(d.b, 0.04))
	if r.size() < 8:
		return Color(1, 1, 1)
	r.sort()
	g.sort()
	b.sort()
	var m := r.size() / 2
	return Color(minf(r[m], 1.5), minf(g[m], 1.5), minf(b[m], 1.5))


static func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_light_tex = GradientTexture2D.new()
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(1.0, 0.5)
		_light_tex.width = 128
		_light_tex.height = 128
	return _light_tex


## Adds PointLight2D children where `emission` (a lit / night version of the sprite, or the sprite itself) glows.
## `origin` = where pixel (0, 0) of the image sits in the node's local space. Returns the new lights.
static func add_lights(node: Node2D, emission: Image, origin: Vector2, scale_px := 1.0, energy := 0.9, radius := 0.35,
		height := 24.0, flicker := true, owner: Node = null, reference: Image = null) -> Array:
	var made := []
	for b in find_lights(emission, 0.72, 0.22, 6.0, 2, reference):
		var l := PointLight2D.new()
		l.name = "PLLight%d" % made.size()
		l.texture = light_texture()
		l.position = origin + b.pos * scale_px
		var c: Color = b.color
		l.color = Color(c.r, c.g, c.b).lightened(0.15)
		l.energy = energy * clampf(sqrt(float(b.size)) / 3.0, 0.5, 2.0)
		l.texture_scale = radius * clampf(sqrt(float(b.size)) / 2.0, 0.6, 2.5)
		l.height = height
		l.add_to_group(LIGHT_GROUP, true)
		if flicker:
			var fl := PLFlicker.new()
			fl.name = "Flicker"
			l.add_child(fl)
		node.add_child(l)
		if owner:
			l.owner = owner
			for ch in l.get_children():
				ch.owner = owner
		made.append(l)
	return made


# ---------------------------------------------------------------- occluders (2D shadows)
## LightOccluder2D polygons from the sprite's alpha. mode "silhouette" = the whole shape, "base" = only the bottom
## `base_px` rows (isometric buildings: shadows from the footprint, not from the roof).
static func occluder_polygons(src: Image, mode := "silhouette", base_px := 16, epsilon := 1.5) -> Array:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	if mode == "base":                                   # the lowest base_px rows of the visible art, not of the canvas
		var used := img.get_used_rect()
		var cut := maxi(0, used.end.y - base_px)
		for y in cut:
			for x in img.get_width():
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.5)
	return bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), epsilon)


static func add_occluder(node: Node2D, src: Image, origin: Vector2, mode := "silhouette", base_px := 16, owner: Node = null) -> int:
	var polys := occluder_polygons(src, mode, base_px)
	for k in polys.size():
		var o := LightOccluder2D.new()
		o.name = "PLOccluder%d" % k
		var op := OccluderPolygon2D.new()
		var pts := PackedVector2Array()
		for p in polys[k]:
			pts.append(p + origin)
		op.polygon = pts
		o.occluder = op
		node.add_child(o)
		if owner:
			o.owner = owner
	return polys.size()


# ---------------------------------------------------------------- one call for a sprite node
## The image a sprite shows (frame 0 of the first animation for AnimatedSprite2D) and where its pixel (0,0) sits.
static func sprite_image(node: Node) -> Dictionary:
	var tex: Texture2D = null
	var origin := Vector2.ZERO
	if node is Sprite2D:
		var s := node as Sprite2D
		tex = _base(s.texture)
		if tex == null:
			return {}
		var fw := tex.get_width() / maxi(1, s.hframes)
		var fh := tex.get_height() / maxi(1, s.vframes)
		origin = s.offset - (Vector2(fw, fh) / 2.0 if s.centered else Vector2.ZERO)
		var img := tex.get_image()
		if s.hframes > 1 or s.vframes > 1:
			img = img.get_region(Rect2i(0, 0, fw, fh))
		return {"image": img, "origin": origin, "path": tex.resource_path}
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames == null:
			return {}
		var anim := a.animation if a.sprite_frames.has_animation(a.animation) else a.sprite_frames.get_animation_names()[0]
		var t := a.sprite_frames.get_frame_texture(anim, 0)
		var img: Image
		var path := ""
		if t is AtlasTexture:
			var at := t as AtlasTexture
			img = _base(at.atlas).get_image().get_region(Rect2i(at.region))
			path = _base(at.atlas).resource_path
		else:
			img = _base(t).get_image()
			path = _base(t).resource_path
		origin = a.offset - (Vector2(img.get_size()) / 2.0 if a.centered else Vector2.ZERO)
		return {"image": img, "origin": origin, "path": path}
	return {}


## A lit version of a sprite file, if there is one: .../day/x.png -> .../night/x.png, or x_night.png / x_emit.png.
static func emission_image(path: String) -> Image:
	if path == "":
		return null
	var cands := [path.replace("/day/", "/night/"), path.get_basename() + "_night." + path.get_extension(),
		path.get_basename() + "_emit." + path.get_extension()]
	for c in cands:
		if c != path and ResourceLoader.exists(c):
			var t: Texture2D = load(c)
			var img := t.get_image()
			if img.is_compressed():
				img.decompress()
			return img
	return null
