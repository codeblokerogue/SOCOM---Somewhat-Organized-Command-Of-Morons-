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
        if event.keycode == KEY_F1:
            visible_overlay = not visible_overlay
            queue_redraw()
        elif event.keycode == KEY_F2:
            show_nav_paths = not show_nav_paths
            queue_redraw()
        elif event.keycode == KEY_F3:
            show_cover_edges = not show_cover_edges
            queue_redraw()
        elif event.keycode == KEY_F4:
            show_los = not show_los
            queue_redraw()
        elif event.keycode == KEY_F5:
            show_suppression_heat = not show_suppression_heat
            queue_redraw()
        elif event.keycode == KEY_F6:
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
    var font: Font = get_theme_default_font()
    var font_size: int = get_theme_default_font_size()
    draw_string(font, Vector2(10, y_offset), "State: %s" % current_state, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 0.4))
    y_offset += line_height
    var game: Node = get_tree().get_first_node_in_group("game")
    if game != null:
        var objective_marker: Node2D = game.get_node_or_null("ObjectiveMarker")
        if objective_marker != null:
            var radius: float = 120.0
            if "radius" in objective_marker:
                radius = objective_marker.radius
            var marker_pos: Vector2 = objective_marker.global_position
            var player_count: int = 0
            var enemy_count: int = 0
            if game.has_method("_count_units_in_radius"):
                player_count = game._count_units_in_radius("player_units", marker_pos, radius)
                enemy_count = game._count_units_in_radius("enemy_units", marker_pos, radius)
            var hold_player_value = game.get("hold_timer_player")
            var hold_enemy_value = game.get("hold_timer_enemy")
            var hold_threshold_value = game.get("HOLD_THRESHOLD")
            var hold_player: float = hold_player_value if hold_player_value != null else 0.0
            var hold_enemy: float = hold_enemy_value if hold_enemy_value != null else 0.0
            var hold_threshold: float = hold_threshold_value if hold_threshold_value != null else 12.0
            var objective_line: String = "Objective: P%d E%d | Hold %.1f/%.0f %.1f/%.0f" % [
                player_count,
                enemy_count,
                hold_player,
                hold_threshold,
                hold_enemy,
                hold_threshold
            ]
            draw_string(font, Vector2(10, y_offset), objective_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.9, 0.6))
            y_offset += line_height
    for line in event_log:
        draw_string(font, Vector2(10, y_offset), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
        y_offset += line_height
    var viewport: Viewport = get_viewport()
    var canvas_xform: Transform2D = viewport.get_canvas_transform()
    if game != null:
        var selection_handler: Node = game.get_node_or_null("SelectionHandler")
        if selection_handler != null:
            var mouse_world: Vector2 = game.get_global_mouse_position()
            var mouse_screen: Vector2 = canvas_xform * mouse_world
            for unit in selection_handler.selection:
                var start_screen: Vector2 = canvas_xform * unit.global_position
                var has_los: bool = game.is_line_of_sight(unit.global_position, mouse_world, null)
                var line_col: Color = Color(0.2, 1.0, 0.2, 0.7) if has_los else Color(1.0, 0.2, 0.2, 0.7)
                draw_line(start_screen, mouse_screen, line_col, 1.0)
    if show_nav_paths:
        _draw_nav_paths(canvas_xform)
    if show_cover_edges:
        _draw_cover_edges(canvas_xform)
    if show_suppression_heat:
        _draw_suppression_heat(canvas_xform)
    if show_ai_tactics:
        _draw_ai_tactics(canvas_xform)
    for unit in get_tree().get_nodes_in_group("player_units"):
        for entry in unit.last_known_positions.values():
            var age: float = entry["age"]
            var pos: Vector2 = entry["pos"]
            var fade_time: float = unit.LAST_KNOWN_FADE if "LAST_KNOWN_FADE" in unit else 6.0
            var alpha: float = clamp(1.0 - (age / fade_time), 0.0, 1.0)
            var screen_pos: Vector2 = canvas_xform * pos
            draw_circle(screen_pos, 4.0, Color(1.0, 1.0, 1.0, alpha))

func _draw_nav_paths(canvas_xform: Transform2D) -> void:
    for unit in get_tree().get_nodes_in_group("player_units"):
        var points: Array = []
        points.append(unit.global_position)
        if "waypoints" in unit and unit.waypoints.size() > 0:
            for wp in unit.waypoints:
                points.append(wp)
        elif "target_position" in unit:
            points.append(unit.target_position)
        if points.size() < 2:
            continue
        for i in range(points.size() - 1):
            var start_screen: Vector2 = canvas_xform * points[i]
            var end_screen: Vector2 = canvas_xform * points[i + 1]
            draw_line(start_screen, end_screen, Color(0.4, 0.8, 1.0, 0.6), 1.0)

func _draw_cover_edges(canvas_xform: Transform2D) -> void:
    for cover in get_tree().get_nodes_in_group("cover"):
        if not ("size" in cover):
            continue
        var size: Vector2 = cover.size
        var top_left: Vector2 = canvas_xform * (cover.global_position - size * 0.5)
        var bottom_right: Vector2 = canvas_xform * (cover.global_position + size * 0.5)
        var rect := Rect2(top_left, bottom_right - top_left)
        var colour := Color(0.3, 0.9, 0.6, 0.6)
        if "cover_type" in cover and cover.cover_type == "heavy":
            colour = Color(0.3, 0.5, 1.0, 0.6)
        draw_rect(rect, colour, false, 2.0)

func _draw_suppression_heat(canvas_xform: Transform2D) -> void:
    for group_name in ["player_units", "enemy_units"]:
        for unit in get_tree().get_nodes_in_group(group_name):
            if not ("suppression" in unit):
                continue
            var level: float = clamp(unit.suppression / 100.0, 0.0, 1.0)
            if level <= 0.01:
                continue
            var radius: float = 10.0 + level * 16.0
            var alpha: float = 0.15 + level * 0.5
            var screen_pos: Vector2 = canvas_xform * unit.global_position
            draw_circle(screen_pos, radius, Color(1.0, 0.3, 0.2, alpha))

func _draw_ai_tactics(canvas_xform: Transform2D) -> void:
    var font: Font = get_theme_default_font()
    var font_size: int = get_theme_default_font_size()
    for team in get_tree().get_nodes_in_group("ai_fireteams"):
        if not ("units" in team):
            continue
        var units: Array = team.units
        if units.is_empty():
            continue
        var sum: Vector2 = Vector2.ZERO
        var count: int = 0
        for unit in units:
            if is_instance_valid(unit):
                sum += unit.global_position
                count += 1
        if count == 0:
            continue
        var centroid: Vector2 = sum / float(count)
        var screen_pos: Vector2 = canvas_xform * centroid
        var intent: String = team.commander_intent.get("goal", "hold") if "commander_intent" in team else "hold"
        var label: String = "AI %d: %s (%s)" % [team.fireteam_id, team.current_tactic, intent]
        draw_string(font, screen_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.8, 0.4))
