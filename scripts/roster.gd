extends Control

@onready var back_button = $BackButton
@onready var roster_text: RichTextLabel = $RosterText
@onready var debug_overlay = $DebugOverlay

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    debug_overlay.set_state("Roster")
    _load_roster()

func _on_back_pressed() -> void:
    Logger.log_event("State transition: Roster -> Menu")
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _load_roster() -> void:
    if roster_text == null:
        return
    var path := "user://campaign.json"
    var lines: Array = []
    if FileAccess.file_exists(path):
        var file := FileAccess.open(path, FileAccess.READ)
        if file != null:
            var parsed = JSON.parse_string(file.get_as_text())
            if typeof(parsed) == TYPE_DICTIONARY:
                var units := parsed.get("units", [])
                for entry in units:
                    if typeof(entry) == TYPE_DICTIONARY:
                        var unit_id := entry.get("id", "?")
                        var xp := entry.get("xp", 0)
                        var rank := entry.get("rank", 0)
                        lines.append("Unit %s | XP %d | Rank %d" % [unit_id, xp, rank])
    if lines.is_empty():
        lines.append("No roster data available.")
    roster_text.text = "\n".join(lines)
