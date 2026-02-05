extends Node2D

##
# Handles RTS‑style selection via drag boxes.  Maintains the current selection and updates unit selection state.

var selecting: bool = false
var start_screen_pos: Vector2
var start_world_pos: Vector2
var current_world_pos: Vector2
var current_rect: Rect2 = Rect2()
var selection: Array = []
var last_clicked_unit: Node2D = null

const DRAG_THRESHOLD: float = 6.0
const CLICK_RADIUS: float = 12.0

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                # Begin drag selection
                selecting = true
                start_screen_pos = event.position
                start_world_pos = _screen_to_world(event.position)
                current_world_pos = start_world_pos
                current_rect = Rect2(start_world_pos, Vector2.ZERO)
            else:
                # Finish drag selection
                selecting = false
                var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)
                var drag_distance: float = start_screen_pos.distance_to(event.position)
                if drag_distance <= DRAG_THRESHOLD:
                    _handle_click_selection(_screen_to_world(event.position), is_shift, event.double_click)
                else:
                    _handle_box_selection(is_shift)
                queue_redraw()
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            # Right‑click orders are handled in Game.gd
            pass
    elif event is InputEventMouseMotion and selecting:
        current_world_pos = _screen_to_world(event.position)
        current_rect = Rect2(start_world_pos, current_world_pos - start_world_pos)
        # Update drawing
        queue_redraw()

func _draw() -> void:
    if selecting:
        var rect: Rect2 = current_rect
        var fill_col: Color = Color(0.1, 0.7, 1.0, 0.25)
        var border_col: Color = Color(0.1, 0.7, 1.0, 0.8)
        draw_rect(rect, fill_col, true)
        draw_rect(rect, border_col, false, 1.0)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
    return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _handle_click_selection(world_pos: Vector2, add_to_selection: bool, is_double_click: bool) -> void:
    var selected_unit: Node2D = _get_unit_at_point(world_pos)
    if not add_to_selection:
        _clear_selection()
    if selected_unit != null:
        if is_double_click:
            _select_units_by_role(selected_unit.role, add_to_selection)
        else:
            if not selection.has(selected_unit):
                selection.append(selected_unit)
            selected_unit.selected = true
        last_clicked_unit = selected_unit

func _handle_box_selection(add_to_selection: bool) -> void:
    var rect: Rect2 = current_rect.abs()
    var new_selection: Array = []
    for unit in get_tree().get_nodes_in_group("player_units"):
        if rect.has_point(unit.get_global_position()):
            new_selection.append(unit)
    if add_to_selection:
        for u in new_selection:
            if not selection.has(u):
                selection.append(u)
                u.selected = true
    else:
        _clear_selection()
        selection = new_selection
        for u in selection:
            u.selected = true

func _clear_selection() -> void:
    for u in selection:
        u.selected = false
    selection.clear()

func _get_unit_at_point(world_pos: Vector2) -> Node2D:
    var closest: Node2D = null
    var closest_dist: float = CLICK_RADIUS
    for unit in get_tree().get_nodes_in_group("player_units"):
        var dist: float = unit.get_global_position().distance_to(world_pos)
        if dist <= closest_dist:
            closest = unit
            closest_dist = dist
    return closest

func select_units(units: Array, add_to_selection: bool = false) -> void:
    if not add_to_selection:
        _clear_selection()
    for unit in units:
        if not selection.has(unit):
            selection.append(unit)
        unit.selected = true

func _select_units_by_role(role_name: String, add_to_selection: bool) -> void:
    var matching: Array = []
    for unit in get_tree().get_nodes_in_group("player_units"):
        if unit.role == role_name:
            matching.append(unit)
    select_units(matching, add_to_selection)
