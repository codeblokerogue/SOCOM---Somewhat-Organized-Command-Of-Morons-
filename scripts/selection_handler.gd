extends Node2D

##
# Handles RTS‑style selection via drag boxes.  Maintains the current selection and updates unit selection state.

var selecting: bool = false
var start_pos: Vector2
var current_rect: Rect2 = Rect2()
var selection: Array = []

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                # Begin drag selection
                selecting = true
                start_pos = event.position
                current_rect = Rect2(start_pos, Vector2.ZERO)
            else:
                # Finish drag selection
                selecting = false
                var rect := current_rect.abs()
                var new_selection: Array = []
                for unit in get_tree().get_nodes_in_group("player_units"):
                    if rect.has_point(unit.get_global_position()):
                        new_selection.append(unit)
                if Input.is_key_pressed(KEY_SHIFT):
                    # Add to existing selection
                    for u in new_selection:
                        if not selection.has(u):
                            selection.append(u)
                else:
                    # Clear previous selection
                    for u in selection:
                        u.selected = false
                    selection = new_selection
                # Update unit selection state
                for u in selection:
                    u.selected = true
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            # Right‑click orders are handled in Game.gd
            pass
    elif event is InputEventMouseMotion and selecting:
        current_rect.size = event.position - start_pos
        # Update drawing
        queue_redraw()

func _draw() -> void:
    if selecting:
        var rect := current_rect
        var fill_col := Color(0.1, 0.7, 1.0, 0.25)
        var border_col := Color(0.1, 0.7, 1.0, 0.8)
        draw_rect(rect, fill_col, true)
        draw_rect(rect, border_col, false, 1.0)
