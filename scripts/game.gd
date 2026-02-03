extends Node2D

##
# Main game logic: spawns units, handles camera controls and issues orders to selected units.

@onready var selection_handler: Node = $SelectionHandler
@onready var camera: Camera2D = $Camera2D
@onready var debug_overlay = $DebugOverlay
@onready var end_button = $HUD/EndButton

var formation_modes: Array = ["tight", "normal", "loose"]
var current_formation_index: int = 1  # start at normal
var unit_archetypes: Dictionary = {}

func _ready() -> void:
    unit_archetypes = _load_unit_archetypes()
    # Spawn initial units for testing.  In the final game this will be data-driven.
    spawn_player_units(4)
    spawn_enemy_units(4)
    debug_overlay.set_state("Game")
    end_button.pressed.connect(_on_end_pressed)
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
        if event.scancode == KEY_ESCAPE:
            _end_run()
            return
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

func _on_end_pressed() -> void:
    _end_run()

func _end_run() -> void:
    Logger.log_event("State transition: Game -> AfterAction")
    get_tree().change_scene_to_file("res://scenes/AfterAction.tscn")

func spawn_player_units(count: int) -> void:
    var scene := load("res://scenes/Unit.tscn")
    for i in range(count):
        var unit: Unit = scene.instantiate() as Unit
        _apply_unit_archetype(unit, "Rifle")
        unit.position = Vector2(150 + i * 20, 400)
        unit.add_to_group("player_units")
        add_child(unit)

func spawn_enemy_units(count: int) -> void:
    var scene := load("res://scenes/Unit.tscn")
    for i in range(count):
        var unit: Unit = scene.instantiate() as Unit
        unit.set_script(load("res://scripts/ai_unit.gd"))
        var archetype := "Support" if i % 2 == 0 else "Scout"
        _apply_unit_archetype(unit, archetype)
        unit.position = Vector2(800 + i * 20, 200)
        unit.add_to_group("enemy_units")
        # Turn on attack behaviour for AI units
        unit.attack_move = true
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

func _load_unit_archetypes() -> Dictionary:
    var path := "res://data/units.json"
    if not FileAccess.file_exists(path):
        Logger.log_event("Unit data missing: %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    var content := file.get_as_text()
    var parsed = JSON.parse_string(content)
    if typeof(parsed) != TYPE_DICTIONARY:
        Logger.log_event("Unit data invalid JSON: %s" % path)
        return {}
    return parsed

func _apply_unit_archetype(unit: Unit, archetype_name: String) -> void:
    if not unit_archetypes.has(archetype_name):
        Logger.log_event("Unknown archetype: %s" % archetype_name)
        return
    var data: Dictionary = unit_archetypes[archetype_name]
    unit.role = archetype_name
    if data.has("hp"):
        unit.max_hp = int(data["hp"])
    if data.has("speed"):
        unit.speed = float(data["speed"])
    if data.has("accuracy"):
        unit.accuracy = float(data["accuracy"])
    if data.has("suppression_resistance"):
        unit.suppression_resistance = float(data["suppression_resistance"])
    if data.has("role_tag"):
        unit.role_tag = str(data["role_tag"])
    if data.has("cost_tag"):
        unit.cost_tag = str(data["cost_tag"])
