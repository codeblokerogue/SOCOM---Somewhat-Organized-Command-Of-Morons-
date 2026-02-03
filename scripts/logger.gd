extends Node

##
# Minimal logger that prints to the console and forwards events to the debug overlay.

func log_event(text: String) -> void:
    print(text)
    if get_tree() != null:
        get_tree().call_group("debug_overlay", "log_event", text)
