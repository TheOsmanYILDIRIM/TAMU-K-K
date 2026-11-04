extends RefCounted
# PixelLight 2D 1.0.2 adapter for authored TAMU AtlasTexture objects.
# Opt-in only until Android draw-call/FPS acceptance. Never mutate canonical atlases.
const PixelLightCore = preload("res://addons/pixel_light_2d/pixel_light.gd")
const WorldProjection = preload("res://scripts/world_projection.gd")
const MAX_OBJECTS := 4
const MAX_DISTANCE := 460.0

static func install(items: Array[Dictionary], layer: Node2D, actor_world: Vector2) -> Dictionary:
    if layer == null:
        return {}
    var candidates: Array[Dictionary] = []
    for item in items:
        if str(item.get("kind", "")) not in ["tree", "rock"] or not item.has("silhouette"):
            continue
        var sprite: Sprite2D = item.get("sprite")
        if sprite == null or not sprite.texture is AtlasTexture:
            continue
        var distance := (item["position"] as Vector2).distance_to(actor_world)
        if distance <= MAX_DISTANCE:
            candidates.append({"item": item, "distance": distance})
    candidates.sort_custom(func(a, b): return float(a["distance"]) < float(b["distance"]))
    var atlas_images := {}
    var baked := {}
    var count := 0
    var occluders := 0
    for candidate in candidates:
        if count >= MAX_OBJECTS:
            break
        var item: Dictionary = candidate["item"]
        var sprite: Sprite2D = item["sprite"]
        var atlas: AtlasTexture = sprite.texture
        var base: Texture2D = atlas.atlas
        if base == null:
            continue
        var key := "%s/%s" % [str(base.resource_path), str(atlas.region)]
        if not baked.has(key):
            if not atlas_images.has(base):
                atlas_images[base] = base.get_image()
            var source_image: Image = atlas_images[base]
            if source_image == null or source_image.is_empty():
                continue
            var rect := Rect2i(atlas.region)
            var region_image := source_image.get_region(rect)
            if region_image.is_empty():
                continue
            # Build a bounded preview normal map, never the full 4096px atlas.
            var sample := region_image.duplicate()
            if maxi(sample.get_width(), sample.get_height()) > 128:
                sample.resize(128, 128, Image.INTERPOLATE_BILINEAR)
            var normal := PixelLightCore.generate_normal(sample, 1.2, 2, 0.20)
            var canvas := CanvasTexture.new()
            canvas.diffuse_texture = ImageTexture.create_from_image(region_image)
            canvas.normal_texture = ImageTexture.create_from_image(normal)
            baked[key] = {"texture": canvas, "image": region_image}
        var baked_record: Dictionary = baked[key]
        var image: Image = baked_record["image"]
        sprite.texture = baked_record["texture"]
        # Keep existing sprite offset, size and alpha selection. Occluder comes
        # from the lowest source pixels; only one sampled light may cast it.
        var origin := sprite.offset - Vector2(image.get_size()) * 0.5
        var built: int = PixelLightCore.add_occluder(sprite, image, origin, "base", 12)
        if built == 0:
            continue
        occluders += built
        # Existing solar alpha silhouette is replaced only for this object
        # while the opt-in PixelLight scene is active. No double-casting.
        var old_shadow: Sprite2D = item["silhouette"]
        old_shadow.set_meta("tamu_pixellight_replaced_shadow", true)
        old_shadow.visible = false
        count += 1
    if count == 0:
        return {"count": 0, "occluders": 0}
    var light := PointLight2D.new()
    light.name = "TAMUPixelLightSample"
    light.texture = PixelLightCore.light_texture()
    light.texture_scale = 5.0
    light.energy = 0.70
    light.shadow_enabled = true
    light.position = WorldProjection.to_screen(actor_world) + Vector2(0, -45)
    layer.add_child(light)
    print("TAMU_PIXELLIGHT_WORLD_ACTIVE objects=", count, " occluders=", occluders, " lights=1")
    return {"count": count, "occluders": occluders, "light": light}
