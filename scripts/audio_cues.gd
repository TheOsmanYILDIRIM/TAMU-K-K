extends Node
# Data-driven audio ports; no synthetic stand-in audio or copyrighted tracks.
# Real licensed WAV/OGG assets can be installed under these stable cue paths.
const CUES := {
    "harvest_start": "res://audio/sfx/harvest_start.ogg",
    "harvest_complete": "res://audio/sfx/harvest_complete.ogg",
    "craft_complete": "res://audio/sfx/craft_complete.ogg",
    "hit": "res://audio/sfx/hit.ogg",
    "footstep": "res://audio/sfx/footstep.ogg"
}
const MUSIC := {"forest": "res://audio/music/forest.ogg"}
const MAX_VOICES := 8
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var cursor := 0
var cache: Dictionary = {}

func _ready() -> void:
    for name in ["TAMU_Music", "TAMU_SFX"]:
        if AudioServer.get_bus_index(name) == -1:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, name)
    for i in range(MAX_VOICES):
        var p := AudioStreamPlayer.new()
        p.bus = "TAMU_SFX"
        p.volume_db = -8.0
        add_child(p)
        players.append(p)
    music = AudioStreamPlayer.new()
    music.bus = "TAMU_Music"
    music.volume_db = -13.0
    add_child(music)

func _stream(path: String) -> AudioStream:
    if cache.has(path):
        return cache[path]
    if not ResourceLoader.exists(path):
        return null
    var result: Resource = load(path)
    if not result is AudioStream:
        return null
    cache[path] = result
    return result

func cue(id: String) -> bool:
    if not CUES.has(id) or players.is_empty():
        return false
    var stream := _stream(CUES[id])
    if stream == null:
        return false
    var player := players[cursor]
    cursor = (cursor + 1) % MAX_VOICES
    player.stop()
    player.stream = stream
    player.play()
    return true

func play_music(id: String) -> bool:
    if not MUSIC.has(id):
        return false
    var stream := _stream(MUSIC[id])
    if stream == null:
        return false
    if music.stream == stream and music.playing:
        return true
    music.stop()
    music.stream = stream
    music.play()
    return true

func stop_music() -> void:
    if music != null:
        music.stop()
