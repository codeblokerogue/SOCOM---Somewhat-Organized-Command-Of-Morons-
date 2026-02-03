extends Control

##
# After‑action summary scene.
# For now this is a placeholder; clicking the return button goes back to the main menu.

@onready var return_button = $ReturnButton
@onready var debug_overlay = $DebugOverlay
@onready var summary_text: RichTextLabel = $SummaryText

func _ready() -> void:
    return_button.pressed.connect(_on_return_pressed)
    debug_overlay.set_state("AfterAction")
    _populate_summary()
    _maybe_finish_playtest()

func _on_return_pressed() -> void:
    Logger.log_event("State transition: AfterAction -> Menu")
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _populate_summary() -> void:
    if summary_text == null:
        return
    var summary: Dictionary = {}
    if get_tree().has_meta("match_summary"):
        summary = get_tree().get_meta("match_summary")
    var lines: Array = []
    lines.append("Result: %s" % summary.get("end_reason", "Unknown"))
    lines.append("Objective: %s" % summary.get("objective_winner", "None"))
    lines.append("Player kills: %d" % summary.get("player_kills", 0))
    lines.append("Enemy kills: %d" % summary.get("enemy_kills", 0))
    lines.append("Kills in cover: %d" % summary.get("kills_in_cover", 0))
    lines.append("Kills in open: %d" % summary.get("kills_in_open", 0))
    lines.append("XP awarded: %d" % summary.get("xp_awarded", 0))
    lines.append("Survivors (player/enemy): %d / %d" % [summary.get("survivors_player", 0), summary.get("survivors_enemy", 0)])
    lines.append("Suppression peak (player/enemy): %.0f / %.0f" % [summary.get("suppression_peak_player", 0.0), summary.get("suppression_peak_enemy", 0.0)])
    lines.append("Flank events: %d" % summary.get("flank_events", []).size())
    lines.append("Timeline events: %d" % summary.get("timeline", []).size())
    summary_text.text = "\\n".join(lines)

func _maybe_finish_playtest() -> void:
    if not _is_playtest_active():
        return
    var exit_code: int = 0
    if get_tree().has_meta("playtest_failed") and bool(get_tree().get_meta("playtest_failed")):
        exit_code = 1
    Logger.log_event("Playtest completed; exiting with code %d" % exit_code)
    call_deferred("_quit_playtest", exit_code)

func _quit_playtest(exit_code: int) -> void:
    get_tree().quit(exit_code)

func _is_playtest_active() -> bool:
    return get_tree().has_meta("playtest_active") and bool(get_tree().get_meta("playtest_active"))
