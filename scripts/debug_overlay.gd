extends Control

##
# A simple overlay that logs and displays game events and optionally suppression bars.
# Press F1 to toggle the overlay visibility.  Additional overlays (nav paths,
# cover edges, LoS rays, AI state) can be added incrementally.

var visible_overlay: bool = true
var event_log: Array = []
var current_state: String = "Unknown"
const MAX_EVENTS: int = 20

func _ready() -> void:
    # Add to a group so other scripts can send log events
    add_to_group("debug_overlay")
    set_process(false)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.scancode == KEY_F1:
            visible_overlay = not visible_overlay
            queue_redraw()

func log_event(text: String) -> void:
    event_log.append(text)
    if event_log.size() > MAX_EVENTS:
        event_log.pop_front()
    queue_redraw()

func set_state(state: String) -> void:
    current_state = state
    queue_redraw()

func _draw() -> void:
    if not visible_overlay:
        return
    var y_offset: float = 10.0
    var line_height: float = 14.0
    var font := get_theme_default_font()
    var font_size := get_theme_default_font_size()
    draw_string(font, Vector2(10, y_offset), "State: %s" % current_state, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 0.4))
    y_offset += line_height
    for line in event_log:
        draw_string(font, Vector2(10, y_offset), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
        y_offset += line_height
    # Optionally draw suppression bars for all units
    for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
        # Convert world position to screen space via camera
        var world_pos: Vector2 = unit.global_position
        var viewport := get_viewport()
        var cam := viewport.get_camera_2d()
        if cam == null:
            continue
        var screen_pos: Vector2 = cam.to_screen(world_pos)
        var bar_width: float = 30.0
        var bar_height: float = 4.0
        var pct: float = clamp(unit.suppression / 100.0, 0.0, 1.0)
        var rect := Rect2(screen_pos + Vector2(-bar_width / 2.0, -28.0), Vector2(bar_width, bar_height))
        draw_rect(rect, Color(0.2, 0.2, 0.2, 0.7), true)
        draw_rect(Rect2(rect.position, Vector2(bar_width * pct, bar_height)), Color(1.0, 0.0, 0.0, 0.9), true)
