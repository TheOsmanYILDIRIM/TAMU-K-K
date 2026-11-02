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
    if not valid:
        push_error("TAMU_FX_CONTRACT_FAILED")
        quit(40)
        return
    print("TAMU_SHADOW_VOLUME_PARITY_OK orientations=5 kinds=2")
    print("TAMU_FX_CONTRACT_OK voices=8 music_bus=true sfx_bus=true shader=true")
    quit(0)
