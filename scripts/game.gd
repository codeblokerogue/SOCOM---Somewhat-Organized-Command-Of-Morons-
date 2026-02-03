extends Node2D

##
# Main game logic: spawns units, handles camera controls and issues orders to selected units.

@onready var selection_handler: Node = $SelectionHandler
@onready var camera: Camera2D = $Camera2D

var formation_modes: Array = ["tight", "normal", "loose"]
var current_formation_index: int = 1  # start at normal

func _ready() -> void:
    # Spawn initial units for testing.  In the final game this will be data-driven.
    spawn_player_units(4)
    spawn_enemy_units(4)
    # Log events
    for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
        Logger.log_event("Spawned Unit %d (role %s)" % [unit.id, unit.role])

func _process(delta: float) -> void:
    _handle_camera_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
    # Right‑click issues orders
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        var pos := get_global_mouse_position()
        # Determine order type based on keyboard state
        var attack_move := Input.is_key_pressed(KEY_A)
        var hold := Input.is_key_pressed(KEY_H)
        # Issue to all selected units
        for unit in selection_handler.selection:
            unit.target_position = pos
            unit.attack_move = attack_move
            unit.hold = hold
            # Reset spread offset; will be set when formation modes implemented
            unit.spread_offset = Vector2.ZERO
        # Log order
        var order_name := "Move"
        if attack_move:
            order_name = "Attack‑move"
        elif hold:
            order_name = "Hold"
        Logger.log_event("%s order issued to %d units" % [order_name, selection_handler.selection.size()])
    elif event is InputEventKey and event.pressed:
        if event.scancode == KEY_SPACE:
            # Pause/unpause
            get_tree().paused = not get_tree().paused
            Logger.log_event("Game paused" if get_tree().paused else "Game resumed")
        elif event.scancode == KEY_F:
            # Cycle formation spacing
            current_formation_index = (current_formation_index + 1) % formation_modes.size()
            var mode := formation_modes[current_formation_index]
            # Apply spacing radius to selected units (stub)
            var spacing := 0.0
            match mode:
                "tight":
                    spacing = 0.0
                "normal":
                    spacing = 16.0
                "loose":
                    spacing = 32.0
            for i in range(selection_handler.selection.size()):
                var unit = selection_handler.selection[i]
                # assign radial offset around target to spread units
                var angle = float(i) / max(selection_handler.selection.size(), 1) * TAU
                unit.spread_offset = Vector2(cos(angle), sin(angle)) * spacing
            Logger.log_event("Formation mode set to %s" % mode)

func spawn_player_units(count: int) -> void:
    var scene := load("res://scenes/Unit.tscn")
    for i in range(count):
        var unit: Unit = scene.instantiate() as Unit
        unit.role = "Rifle"
        unit.position = Vector2(150 + i * 20, 400)
        unit.add_to_group("player_units")
        add_child(unit)

func spawn_enemy_units(count: int) -> void:
    var scene := load("res://scenes/Unit.tscn")
    for i in range(count):
        var unit: Unit = scene.instantiate() as Unit
        unit.role = "Support" if i % 2 == 0 else "Scout"
        unit.position = Vector2(800 + i * 20, 200)
        unit.add_to_group("enemy_units")
        # Turn on attack behaviour for AI units
        unit.attack_move = true
        # Override script with AI behaviour script
        unit.set_script(load("res://scripts/ai_unit.gd"))
        add_child(unit)

func _handle_camera_movement(delta: float) -> void:
    # Simple camera panning with WASD keys
    var move_vector := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        move_vector.y -= 1
    if Input.is_key_pressed(KEY_S):
        move_vector.y += 1
    if Input.is_key_pressed(KEY_A):
        move_vector.x -= 1
    if Input.is_key_pressed(KEY_D):
        move_vector.x += 1
    if move_vector != Vector2.ZERO:
        move_vector = move_vector.normalized()
        camera.position += move_vector * 300.0 * delta
    # Zoom with mouse wheel handled by default (in editor) or can be bound here
