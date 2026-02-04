extends Control

@onready var back_button = $BackButton
@onready var roster_text: RichTextLabel = $RosterText
@onready var roster_list: ItemList = $RosterList
@onready var assign_button = $AssignButton
@onready var unassign_button = $UnassignButton
@onready var replace_button = $ReplaceButton
@onready var debug_overlay = $DebugOverlay

var roster_entries: Array = []

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    assign_button.pressed.connect(_on_assign_pressed)
    unassign_button.pressed.connect(_on_unassign_pressed)
    replace_button.pressed.connect(_on_replace_pressed)
    debug_overlay.set_state("Roster")
    _load_roster()

func _on_back_pressed() -> void:
    GameLog.log_event("State transition: Roster -> Menu")
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _load_roster() -> void:
    if roster_text == null:
        return
    var path: String = "user://campaign.json"
    var lines: Array = []
    roster_entries = []
    if FileAccess.file_exists(path):
        var file: FileAccess = FileAccess.open(path, FileAccess.READ)
        if file != null:
            var parsed = JSON.parse_string(file.get_as_text())
            if typeof(parsed) == TYPE_DICTIONARY:
                var units: Array = parsed.get("units", [])
                for entry in units:
                    if typeof(entry) == TYPE_DICTIONARY:
                        roster_entries.append(entry)
    _refresh_roster(lines)

func _refresh_roster(lines: Array) -> void:
    if roster_list != null:
        roster_list.clear()
        for entry in roster_entries:
            var unit_id: String = str(entry.get("id", "?"))
            var xp: int = entry.get("xp", 0)
            var rank: int = entry.get("rank", 0)
            var assigned: bool = bool(entry.get("assigned", true))
            var status_value: String = str(entry.get("status", "Active"))
            var acc_bonus: float = rank * 0.02
            var sup_bonus: float = rank * 0.05
            var status: String = status_value if status_value != "Active" else ("Assigned" if assigned else "Reserve")
            var label: String = "Unit %s | XP %d | Rank %d | %s | +Acc %.0f%% | +SupRes %.0f%%" % [
                unit_id,
                xp,
                rank,
                status,
                acc_bonus * 100.0,
                sup_bonus * 100.0
            ]
            roster_list.add_item(label)
            roster_list.set_item_metadata(roster_list.get_item_count() - 1, unit_id)
    if lines.is_empty() and roster_entries.is_empty():
        lines.append("No roster data available.")
    else:
        var assigned_count: int = 0
        for entry in roster_entries:
            if bool(entry.get("assigned", true)):
                assigned_count += 1
        lines.append("Assigned to mission: %d / %d" % [assigned_count, roster_entries.size()])
    roster_text.text = "\n".join(lines)

func _on_assign_pressed() -> void:
    _set_assignment_state(true)

func _on_unassign_pressed() -> void:
    _set_assignment_state(false)

func _set_assignment_state(state: bool) -> void:
    if roster_list == null:
        return
    var selected: PackedInt32Array = roster_list.get_selected_items()
    if selected.is_empty():
        return
    for index in selected:
        if index >= 0 and index < roster_entries.size():
            if str(roster_entries[index].get("status", "Active")) == "Active":
                roster_entries[index]["assigned"] = state
    _save_roster()
    _refresh_roster([])

func _on_replace_pressed() -> void:
    if roster_list == null:
        return
    var selected: PackedInt32Array = roster_list.get_selected_items()
    if selected.is_empty():
        return
    var created: bool = false
    for index in selected:
        if index < 0 or index >= roster_entries.size():
            continue
        var status_value: String = str(roster_entries[index].get("status", "Active"))
        if status_value == "Active":
            continue
        var new_id: int = _next_roster_id()
        roster_entries.append({
            "id": new_id,
            "xp": 0,
            "rank": 0,
            "assigned": true,
            "status": "Active"
        })
        created = true
    if created:
        _save_roster()
        _refresh_roster([])

func _next_roster_id() -> int:
    var max_id: int = 0
    for entry in roster_entries:
        var entry_id: int = int(entry.get("id", 0))
        max_id = max(max_id, entry_id)
    return max_id + 1

func _save_roster() -> void:
    var path: String = "user://campaign.json"
    var data: Dictionary = {
        "units": roster_entries
    }
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(data, "  "))
