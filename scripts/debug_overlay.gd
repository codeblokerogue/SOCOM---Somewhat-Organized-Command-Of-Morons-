extends Control

##
# A simple overlay that logs and displays game events and optionally suppression bars.
# Press F1 to toggle the overlay visibility.  Additional overlays (nav paths,
# cover edges, LoS rays, AI state) can be added incrementally.

var visible_overlay: bool = true
var event_log: Array = []
var current_state: String = "Unknown"
const MAX_EVENTS: int = 20
var show_nav_paths: bool = false
var show_cover_edges: bool = false
var show_los: bool = true
var show_suppression_heat: bool = false
var show_ai_tactics: bool = false

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
        elif event.scancode == KEY_F2:
            show_nav_paths = not show_nav_paths
            queue_redraw()
        elif event.scancode == KEY_F3:
            show_cover_edges = not show_cover_edges
            queue_redraw()
        elif event.scancode == KEY_F4:
            show_los = not show_los
            queue_redraw()
        elif event.scancode == KEY_F5:
            show_suppression_heat = not show_suppression_heat
            queue_redraw()
        elif event.scancode == KEY_F6:
            show_ai_tactics = not show_ai_tactics
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
    var viewport := get_viewport()
    var cam := viewport.get_camera_2d()
    if cam == null:
        return
    if show_cover_edges:
        for cover in get_tree().get_nodes_in_group("cover"):
            var radius: float = cover.cover_radius if "cover_radius" in cover else 30.0
            var screen_pos: Vector2 = cam.to_screen(cover.global_position)
            draw_circle(screen_pos, radius, Color(0.3, 0.8, 0.9, 0.2))
    if show_nav_paths:
        for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
            var start: Vector2 = cam.to_screen(unit.global_position)
            var end: Vector2 = cam.to_screen(unit.target_position)
            draw_line(start, end, Color(0.9, 0.9, 0.2, 0.6), 1.0)
            if unit.waypoints.size() > 1:
                for i in range(unit.waypoints.size() - 1):
                    var a: Vector2 = cam.to_screen(unit.waypoints[i])
                    var b: Vector2 = cam.to_screen(unit.waypoints[i + 1])
                    draw_line(a, b, Color(0.9, 0.7, 0.2, 0.5), 1.0)
    var game := get_tree().get_first_node_in_group("game")
    if game != null and show_los:
        var selection_handler := game.get_node_or_null("SelectionHandler")
        if selection_handler != null:
            var mouse_world: Vector2 = game.get_global_mouse_position()
            var mouse_screen: Vector2 = cam.to_screen(mouse_world)
            for unit in selection_handler.selection:
                var start_screen: Vector2 = cam.to_screen(unit.global_position)
                var has_los: bool = game.is_line_of_sight(unit.global_position, mouse_world, null)
                var line_col := Color(0.2, 1.0, 0.2, 0.7) if has_los else Color(1.0, 0.2, 0.2, 0.7)
                draw_line(start_screen, mouse_screen, line_col, 1.0)
    if show_los:
        for unit in get_tree().get_nodes_in_group("player_units"):
            for entry in unit.last_known_positions.values():
                var age: float = entry["age"]
                var pos: Vector2 = entry["pos"]
                var fade_time: float = unit.LAST_KNOWN_FADE if "LAST_KNOWN_FADE" in unit else 6.0
                var alpha: float = clamp(1.0 - (age / fade_time), 0.0, 1.0)
                var screen_pos: Vector2 = cam.to_screen(pos)
                draw_circle(screen_pos, 4.0, Color(1.0, 1.0, 1.0, alpha))
    if show_suppression_heat:
        for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
            var pct: float = clamp(unit.suppression / 100.0, 0.0, 1.0)
            if pct <= 0.01:
                continue
            var screen_pos: Vector2 = cam.to_screen(unit.global_position)
            draw_circle(screen_pos, 16.0 + pct * 12.0, Color(1.0, 0.2, 0.2, 0.2 + pct * 0.3))
    if show_ai_tactics:
        var tactics_y: float = y_offset + 10.0
        var width: float = viewport.get_visible_rect().size.x
        for team in get_tree().get_nodes_in_group("ai_fireteams"):
            if "fireteam_id" in team:
                var label := "FT %d: %s" % [team.fireteam_id, team.current_tactic]
                draw_string(font, Vector2(width - 220, tactics_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.9, 1.0))
                tactics_y += line_height
