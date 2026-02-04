extends Node

##
# Minimal logger that prints to the console and forwards events to the debug overlay.

var event_log: Array = []
const MAX_LOG_EVENTS: int = 200
const TELEMETRY_PATH: String = "user://telemetry.jsonl"
const FPS_LOG_INTERVAL: float = 1.0

var log_file_path: String = ""
var print_fps: bool = false
var fps_timer: float = 0.0

func _ready() -> void:
    var args: Array = OS.get_cmdline_user_args()
    var i: int = 0
    while i < args.size():
        var arg: String = str(args[i])
        if arg == "--print-fps":
            print_fps = true
        elif arg == "--log-file" and i + 1 < args.size():
            log_file_path = str(args[i + 1])
            i += 1
        elif arg.begins_with("--log-file="):
            var parts: Array = arg.split("=", false, 1)
            if parts.size() == 2:
                log_file_path = str(parts[1])
        i += 1
    if log_file_path != "":
        var file: FileAccess = FileAccess.open(log_file_path, FileAccess.WRITE)
        if file != null:
            file.store_line("SOCOM log start")
    set_process(print_fps)

func _process(delta: float) -> void:
    if not print_fps:
        return
    fps_timer += delta
    if fps_timer >= FPS_LOG_INTERVAL:
        fps_timer = 0.0
        print("FPS: %d" % Engine.get_frames_per_second())

func log_event(text: String) -> void:
    print(text)
    event_log.append(text)
    if event_log.size() > MAX_LOG_EVENTS:
        event_log.pop_front()
    if get_tree() != null:
        get_tree().call_group("debug_overlay", "log_event", text)
    _append_log_line(text)

func dump_to_file(path: String) -> void:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return
    for entry in event_log:
        file.store_line(str(entry))

func _append_log_line(text: String) -> void:
    if log_file_path == "":
        return
    var file: FileAccess = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
    if file == null:
        return
    file.seek_end()
    file.store_line(str(text))

func log_telemetry(event_type: String, payload: Dictionary) -> void:
    var record := {
        "ts": Time.get_unix_time_from_system(),
        "event": event_type,
        "data": payload
    }
    var file: FileAccess = FileAccess.open(TELEMETRY_PATH, FileAccess.READ_WRITE)
    if file == null:
        return
    file.seek_end()
    file.store_line(JSON.stringify(record))
