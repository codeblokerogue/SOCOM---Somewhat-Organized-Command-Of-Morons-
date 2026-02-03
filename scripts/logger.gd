extends Node

##
# Minimal logger that prints to the console and forwards events to the debug overlay.

var event_log: Array = []
const MAX_LOG_EVENTS: int = 200

func log_event(text: String) -> void:
    print(text)
    event_log.append(text)
    if event_log.size() > MAX_LOG_EVENTS:
        event_log.pop_front()
    if get_tree() != null:
        get_tree().call_group("debug_overlay", "log_event", text)

func dump_to_file(path: String) -> void:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return
    for entry in event_log:
        file.store_line(str(entry))
