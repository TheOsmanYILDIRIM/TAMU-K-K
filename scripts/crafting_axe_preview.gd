extends TextureRect
## Source: user-provided axe PNG / RGB component mask, downsampled to 128/192 px.
## The loaded images are embedded to keep the Android selected-resource PCK self-contained.
signal region_selected(role: String)
const AXE_B64 := "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"
const MASK_B64 := "iVBORw0KGgoAAAANSUhEUgAAAMAAAADABAMAAACg8nE0AAAAGFBMVEUAAAD9VVrAXvJEwfxb4pv/hMH/vDzo6lJPX6tOAAAACHRSTlMA/Pz8/Pz8+m6i8CoAAAQ5SURBVHja1Zw9buMwEIVHpO209g2IVFsSEfYexgLpU22do+QI6RdY+ABb+AJC1C8Q6AZS61iSt4hjUb8ckjNaW00SWciX995w+BMnANd7SY15SvgDtIx5AQAQcwIkjiACg9B8AN3omLoi3+8frUEoAICEBbD5lK8AoEoZLDr/WHVmN8kPsD5/rO2VJAIEAMC7tZJCy/TdZpIIcQgAIGMeaFBn0x6JoAgupUQLWHc0kA+0TfdGTqsgskmiDfnclygBaycCiYIpAhFgnCAIMp4kUCkYJQiKjKcIdAoAog0zYGCMewCme8tmzasAIOoiIgIXetepYAZ8rbzLPb1FvRUlE8A/5Igb4LC0v1KLTtdhkQ4AFNwKTgW3RWt8Ee0BYOEMeAQ47hgV/ASA5Q/FBlh9evCA3tu6Ap7OLt9zj4NYoRpFwED7bo+hBPcqWjWfPoixrYemahUCIM+JM3gynU5VPrT5kFTNLq7eppvT3h2wMr/4GGngmkrBCtVfCeaD00gEpQegGrCoK0EHKUgdnt37KDBPn14HPZKBGVS2aVQHAaRxRPeB6UQ+VZRM1pEMK1NtEF4tjW7vPw4Sl7WMcIzgUqwflrmmDBnJVTIWQs8htwlHGy4lvHNyV0Mx5pATQFpbhmZeXUvoReAE0OMN49R5oPRRIL0e8LMotSWw9wFovIDSR4Gc7NnFiADCKhoW4ADQlgg08y5TwqBDeMB0BK1fbJZeCjRezD7UonR8Bu4JQAOkpwA0QFtWLs31J7iKUsxq5XItiB1Kcr9xgHUoOfEe51T9oxLh7NBEBFVaeLYKpENp7tmLkAKSnLPZDQWMBqAcqobPwgTRKFuMnbUt3CKosB3CSYFGRFwGrE1lUPQB+2QygEYNAn+ADBKAAIQJuILj/UCH7IBAh6yAOFCADSAK5gyU0cJSnpAvhIpDgTAIKQdAdQ5rmAZaHuAQbiTn/g5NA0TnKIIcoJqNvHcQCxw8Zw25reaW2rViBrRfyugBLQE1vQLBn0FzbTkAhkP1cksPaL/gRxCoiF/8LULtkzOGkEWrRO/8NQhmAaOAbpt4ZlRQcww0uiYrUBE8wx0xoB3BXUAIAlGkFwgdQHUdIs5g8OYzU8g1RxUpgPnKNAtrpv9n2dIr0kPAnCDsRUquYODWy1kFfQbnIj34By14ixRdRS++Dg29+9J8d9X7Vz890CkY1HQgtEgRNiJrBhkD4H6GVkHpUA9A3vwEcwQ9gJpTQc0AENQOzT6jKWqH8BtxGoBgtwjmtCiDG6wi+iKaWYHgBij6jNuAOGYfB/QIE7DkQJgLr8evTxKw/sGoj4JlY5Qmy3ikMnH/RMAVsDUJ7N1U0wOW820CAQB+z7wBoQBsW/e3N6iAG7CcWcHu9iw6tm4fGSza3WgVNW2z/vuNoVOYCo7sFu04WObMcjHpSBh497TlEeAX3NT1D7UC3ivuoMzOAAAAAElFTkSuQmCC"
var mask_image: Image
var original: Image
var bound_roles: Dictionary = {}
var catalog: RefCounted

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var base := Image.new()
    if base.load_png_from_buffer(Marshalls.base64_to_raw(AXE_B64)) != OK:
        push_error("TAMU_AXE_SOURCE_PNG_INVALID")
        return
    mask_image = Image.new()
    if mask_image.load_png_from_buffer(Marshalls.base64_to_raw(MASK_B64)) != OK:
        push_error("TAMU_AXE_MASK_INVALID")
        return
    original = base
    texture = ImageTexture.create_from_image(base)
    if catalog != null and not bound_roles.is_empty():
        apply_materials(bound_roles,catalog)

func _gui_input(event: InputEvent) -> void:
    var at := Vector2(-1,-1)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        at = event.position
    elif event is InputEventScreenTouch and event.pressed:
        at = event.position
    if at.x < 0 or mask_image == null:
        return
    var side := minf(size.x, size.y)
    if side <= 0:
        return
    var p := (at - (size-Vector2.ONE * side) * 0.5) / side
    if p.x < 0 or p.x >= 1 or p.y < 0 or p.y >= 1:
        return
    var role := role_at_uv(p)
    if role != "":
        region_selected.emit(role)
        accept_event()

func role_at_uv(uv: Vector2) -> String:
    if mask_image == null or uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1:
        return ""
    var pixel := mask_image.get_pixel(int(uv.x * mask_image.get_width()), int(uv.y * mask_image.get_height()))
    if pixel.a < 0.4:
        return ""
    var palette := {
        "edge": Color8(91,226,155), "head": Color8(253,85,90),
        "collar": Color8(255,188,60), "handle": Color8(68,193,252),
        "grip": Color8(192,94,242), "pommel": Color8(255,132,193)}
    var nearest := ""
    var distance := 1.0e9
    for key in palette:
        var c: Color = palette[key]
        var d := (pixel.r-c.r)*(pixel.r-c.r)+(pixel.g-c.g)*(pixel.g-c.g)+(pixel.b-c.b)*(pixel.b-c.b)
        if d < distance:
            distance = d
            nearest = key
    return nearest if distance < 0.09 else ""

func apply_materials(items: Dictionary, source_catalog: RefCounted) -> void:
    bound_roles = items.duplicate(true)
    catalog = source_catalog
    if original == null or mask_image == null:
        return
    var colored := original.duplicate()
    for y in range(colored.get_height()):
        for x in range(colored.get_width()):
            var uv := Vector2((x+0.5)/colored.get_width(),(y+0.5)/colored.get_height())
            var role := role_at_uv(uv)
            if not bound_roles.has(role):
                continue
            var def: Dictionary = catalog.item(str(bound_roles[role]))
            var hex := str(def.get("visual",{}).get("color",""))
            if not Color.html_is_valid(hex):
                continue
            var pigment := Color.html(hex)
            var p: Color = colored.get_pixel(x,y)
            # Preserve the authored alpha and its light/shadow; tint a selected material.
            var luminosity := clampf(p.get_luminance() * 1.6 + 0.15, 0.18, 1.0)
            colored.set_pixel(x,y, Color(lerpf(p.r,pigment.r*luminosity,0.52),
                lerpf(p.g,pigment.g*luminosity,0.52),
                lerpf(p.b,pigment.b*luminosity,0.52),p.a))
    texture = ImageTexture.create_from_image(colored)
