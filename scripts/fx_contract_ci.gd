extends SceneTree
# Asset-independent Godot runtime parse/construct smoke, separate from full APK.
const AudioCues = preload("res://scripts/audio_cues.gd")
const Effects = preload("res://scripts/impact_effects.gd")
const Shadow = preload("res://scripts/object_shadow.gdshader")
const Authority = preload("res://scripts/r2_authority.gd")
const ShadowVolume = preload("res://scripts/shadow_volume.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var audio = AudioCues.new()
    root.add_child(audio)
    var effects = Effects.new()
    root.add_child(effects)
    var r2 = Authority.new()
    var valid: bool = Shadow is Shader and audio.players.size() == AudioCues.MAX_VOICES
    valid = valid and AudioServer.get_bus_index("TAMU_Music") >= 0
    valid = valid and AudioServer.get_bus_index("TAMU_SFX") >= 0
    valid = valid and audio.music != null and not audio.cue("not_a_cue")
    valid = valid and r2 is RefCounted and r2.records.is_empty()
    valid = valid and effects.MAX_BURSTS == 16
    valid = valid and effects.palette.has("tree") and effects.palette.has("rock")
    valid = valid and Shadow.code.contains("solar_dir") and Shadow.code.contains("solar_length")
    valid = valid and ShadowVolume.verify_contract()
    var alpha_test := Image.create(48,64,false,Image.FORMAT_RGBA8)
    alpha_test.fill(Color(0,0,0,0))
    for yy in range(4,60):
        for xx in range(16,32):
            alpha_test.set_pixel(xx,yy,Color.WHITE)
    var spans := ShadowVolume.alpha_spans(ImageTexture.create_from_image(alpha_test))
    var mass := ShadowVolume.profile("tree",Vector2(48,64),spans)
    valid = valid and spans.size()==12 and bool(mass.get("sampled_alpha",false))
    valid = valid and float(mass.get("root_inset",0.0)) >= 5.0
    if not valid:
        push_error("TAMU_FX_CONTRACT_FAILED")
        quit(40)
        return
    print("TAMU_SHADOW_ALPHA_CONTOUR_OK samples=12")
    print("TAMU_SHADOW_VOLUME_PARITY_OK orientations=5 kinds=2")
    print("TAMU_FX_CONTRACT_OK voices=8 music_bus=true sfx_bus=true shader=true")
    quit(0)
