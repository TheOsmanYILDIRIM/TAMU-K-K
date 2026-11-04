extends CanvasLayer
signal isolation_requested(mode: String)
# Same full authored scene, one subsystem changed at a time.
const ISOLATION_MODES = ["full", "mob_visual_off", "mob_ai_off",
    "mob_all_off", "solar_off", "objects_off", "terrain_off", "player_rig_off"]
var isolation_mode := "full"
var isolation_elapsed := 0.0
var isolation_sequence := 0
var isolation_label: Label
# JSONL perf telemetry. Sampling never blocks rendering with filesystem writes.
const LIMIT := 5000
var samples: Array[Dictionary] = []
var last_sample_usec := 0
var seconds := 0.0
var p95_ms := 0.0
var p99_ms := 0.0
var panel: PanelContainer
var values: Label
var status: Label
var copy_button: Button
var count := 0
var last_record := {}
var enabled := true
var error_count := 0

func _ready() -> void:
    layer = 100
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    panel = PanelContainer.new()
    panel.position = Vector2(12, 90)
    panel.custom_minimum_size = Vector2(340, 0)
    root.add_child(panel)
    var stack := VBoxContainer.new()
    panel.add_child(stack)
    var heading := Label.new()
    heading.text = "TAMU • GODOT 4 PERFORMANCE"
    stack.add_child(heading)
    values = Label.new()
    values.text = "Collecting frames…"
    stack.add_child(values)
    var buttons := HBoxContainer.new()
    stack.add_child(buttons)
    copy_button = Button.new()
    copy_button.text = "⬇ LOG İNDİR"
    copy_button.pressed.connect(download_logs)
    buttons.add_child(copy_button)
    var clear_button := Button.new()
    clear_button.text = "SIFIRLA"
    clear_button.pressed.connect(reset_logs)
    buttons.add_child(clear_button)
    var toggle_button := Button.new()
    toggle_button.text = "GİZLE"
    toggle_button.pressed.connect(func():
        values.visible = not values.visible
        toggle_button.text = "GİZLE" if values.visible else "GÖSTER"
    )
    buttons.add_child(toggle_button)
    var iso_row := HBoxContainer.new()
    stack.add_child(iso_row)
    var iso_button := Button.new()
    iso_button.name = "IsolationCycle"
    iso_button.text = "İZOLASYON ▶"
    iso_button.pressed.connect(next_isolation_mode)
    iso_row.add_child(iso_button)
    isolation_label = Label.new()
    isolation_label.name = "IsolationMode"
    isolation_label.text = "full"
    iso_row.add_child(isolation_label)
    status = Label.new()
    status.text = "JSONL • RAM buffer"
    stack.add_child(status)

func next_isolation_mode() -> void:
    var index: int = ISOLATION_MODES.find(isolation_mode)
    isolation_requested.emit(ISOLATION_MODES[(index + 1) % ISOLATION_MODES.size()])

func set_isolation_mode(mode: String) -> void:
    if not ISOLATION_MODES.has(mode) or isolation_mode == mode:
        return
    isolation_mode = mode
    isolation_elapsed = 0.0
    isolation_sequence += 1
    if isolation_label != null:
        isolation_label.text = mode
    if status != null:
        status.text = "15 sn sabit dur; sonra diğer profil. Sonunda LOG İNDİR."
    print("TAMU_PERF_ISOLATION profile=", mode, " sequence=", isolation_sequence)

func reset_logs() -> void:
    samples.clear()
    count = 0
    p95_ms = 0
    p99_ms = 0
    status.text = "Log sıfırlandı"

func _percentile(data: Array[float], percentile: float) -> float:
    if data.is_empty():
        return 0.0
    var ordered := data.duplicate()
    ordered.sort()
    return ordered[clampi(ceili(percentile * ordered.size())-1,0,ordered.size()-1)]

func record(delta: float, terrain_chunks: int, available_chunks: int, objects: int, vertices: int, actor_position: Vector2, streaming_usec: int, rig_usec: int, mode: String, mob_usec: int = 0) -> void:
    if not enabled:
        return
    count += 1
    var frame_ms := delta * 1000.0
    var record_entry := {
        "schema": "tamu.perf.godot.v1",
        "engine": "godot4",
        "frame": count,
        "elapsed_ms": roundf(seconds*1000.0),
        "frame_ms": snappedf(frame_ms,0.001),
        "fps_delta": snappedf(1.0/maxf(delta,0.000001),0.01),
        "fps_engine": Engine.get_frames_per_second(),
        "streaming_main_ms": snappedf(streaming_usec/1000.0,0.001),
        "rig_main_ms": snappedf(rig_usec/1000.0,0.001),
        # MobWorld has process_priority=10; one-frame lag versus main._process.
        "mob_cpu_ms_previous_frame": snappedf(float(mob_usec)/1000.0,0.001),
        "chunks_loaded": terrain_chunks,
        "chunks_available": available_chunks,
        "objects_total": objects,
        "vertices_loaded": vertices,
        "actor_x": snappedf(actor_position.x,0.01),
        "actor_y": snappedf(actor_position.y,0.01),
        "scenario": mode,
        "isolation_profile": isolation_mode,
        "isolation_sequence": isolation_sequence,
        "isolation_elapsed_ms": snappedf(isolation_elapsed * 1000.0, 1.0),
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
        "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
        "note": "frame_ms uses delta; does not measure GPU latency"
    }
    last_record = record_entry
    samples.append(record_entry)
    if samples.size() > LIMIT:
        samples.pop_front()
    seconds += delta
    isolation_elapsed += delta
    if count % 30 == 0:
        var frames: Array[float] = []
        # Keep all 5000 export entries; sort only 120 recent samples for HUD.
        for entry in samples.slice(maxi(0, samples.size() - 120)):
            frames.append(float(entry["frame_ms"]))
        p95_ms = _percentile(frames,0.95)
        p99_ms = _percentile(frames,0.99)
        var sum := 0.0
        for x in frames:
            sum += x
        var mean := sum / maxf(1.0,frames.size())
        values.text = "FPS: %d | ΔFrame: %.2f ms\nMean: %.2f | P95: %.2f | P99: %.2f ms\nStream main: %.2f | Rig main: %.2f ms\nChunks: %d/%d | Objects: %d\nDraw calls: %d | Vertices: %d\nRAM static: %.1f MiB | Frames: %d" % [
            Engine.get_frames_per_second(),frame_ms,mean,p95_ms,p99_ms,
            streaming_usec/1000.0,rig_usec/1000.0,terrain_chunks,available_chunks,
            objects,int(record_entry["draw_calls"]),vertices,
            float(record_entry["static_memory_bytes"])/1048576.0,samples.size()
        ]

func build_jsonl() -> String:
    var lines := PackedStringArray()
    for entry in samples:
        lines.append(JSON.stringify(entry))
    return "\n".join(lines)

func copy_logs() -> void:
    var payload := build_jsonl()
    DisplayServer.clipboard_set(payload)
    status.text = "Kopyalandı: %d kare / %d karakter" % [samples.size(),payload.length()]
    print("TAMU_PERF_LOG_COPY_OK frames=",samples.size(), " bytes=",payload.to_utf8_buffer().size())

func download_logs() -> void:
    if samples.is_empty():
        status.text = "Kaydedilecek log yok"
        return
    if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
        # Desktop CI and platforms without a native SAF picker retain a file.
        var fallback := "user://tamu-performance-%d.jsonl" % Time.get_unix_time_from_system()
        if _write_jsonl(fallback):
            status.text = "Kaydedildi: " + ProjectSettings.globalize_path(fallback)
        return
    var filename := "tamu-godot-perf-%d.jsonl" % Time.get_unix_time_from_system()
    var result := DisplayServer.file_dialog_show(
        "Performans kayıtlarını kaydet", "Download", filename, false,
        DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
        PackedStringArray(["*.jsonl;JSON Lines;application/x-ndjson"]),
        _on_log_destination_selected
    )
    if result != OK:
        status.text = "Dosya seçici açılamadı: %d" % result

func _on_log_destination_selected(accepted: bool, paths: PackedStringArray, _filter_index: int) -> void:
    if not accepted or paths.is_empty():
        status.text = "İndirme iptal edildi"
        return
    if _write_jsonl(paths[0]):
        status.text = "Downloads: %d kare kaydedildi" % samples.size()

func _write_jsonl(path: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        status.text = "Kayıt açılamadı: %d" % FileAccess.get_open_error()
        return false
    file.store_string(build_jsonl() + "\n")
    file.flush()
    file.close()
    print("TAMU_PERF_DOWNLOAD_OK frames=",samples.size())
    return true

func test_gate() -> bool:
    if samples.size() < 30:
        return false
    for row in samples:
        if row["schema"] != "tamu.perf.godot.v1" or not row.has("streaming_main_ms"):
            return false
    var records := build_jsonl().split("\n", false)
    if records.size() != samples.size():
        return false
    var first = JSON.parse_string(records[0])
    if first is not Dictionary or first.get("schema") != "tamu.perf.godot.v1":
        return false
    var lines := PackedStringArray()
    for row in samples:
        lines.append(JSON.stringify(row))
    var exported := "\n".join(lines)
    if exported.split("\n").size() != samples.size():
        return false
    for line in exported.split("\n"):
        var decoded = JSON.parse_string(line)
        if decoded is not Dictionary or decoded.get("schema","") != "tamu.perf.godot.v1":
            return false
    copy_logs()
    var internal_path := "user://tamu-perf-ci.jsonl"
    if not _write_jsonl(internal_path):
        return false
    var saved := FileAccess.get_file_as_string(internal_path)
    if saved.split("\n",false).size() != samples.size():
        return false
    print("TAMU_PERF_DOWNLOAD_FILE_GATE_OK rows=",samples.size())
    if not status.text.begins_with("Kopyalandı:"):
        return false
    print("TAMU_PERF_COPY_BUTTON_GATE_OK rows=", samples.size())
    print("TAMU_PERF_JSONL_EXPORT_OK lines=", samples.size())
    print("TAMU_PERF_HUD_GATE_OK frames=",samples.size()," p95=",p95_ms," p99=",p99_ms)
    print("TAMU_PERF_JSONL_EXPORT_OK rows=", records.size())
    return true
