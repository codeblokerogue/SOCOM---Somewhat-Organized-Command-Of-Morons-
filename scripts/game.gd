extends Node2D

##
# Main game logic: spawns units, handles camera controls and issues orders to selected units.

@onready var selection_handler: Node = $SelectionHandler
@onready var camera: Camera2D = $Camera2D
@onready var debug_overlay = $DebugOverlay
@onready var end_button = $HUD/EndButton
@onready var selection_label: Label = $HUD/SelectionPanel/SelectionLabel
@onready var objective_marker: Node2D = $ObjectiveMarker

var last_selection_summary: String = ""

var formation_modes: Array = ["tight", "normal", "loose"]
var current_formation_index: int = 1  # start at normal
var unit_archetypes: Dictionary = {}
var unit_roster: Dictionary = {}
var fireteams: Dictionary = {}
var match_stats: Dictionary = {}
var hold_timer_player: float = 0.0
var hold_timer_enemy: float = 0.0
var match_over: bool = false
const HOLD_THRESHOLD: float = 12.0
const OBJECTIVE_CONTROL_MIN: int = 1

const PLAYER_UNIT_COUNT: int = 8
const TOTAL_UNIT_TARGET: int = 80
const FIRETEAM_MIN_SIZE: int = 2
const FIRETEAM_MAX_SIZE: int = 6
const CAMERA_SPEED: float = 300.0
const CAMERA_EDGE_MARGIN: float = 24.0
const CAMERA_ZOOM_MIN: float = 0.6
const CAMERA_ZOOM_MAX: float = 1.6
const CAMERA_ZOOM_STEP: float = 0.1
const MAP_BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2(1600, 900))

func _ready() -> void:
    add_to_group("game")
    unit_archetypes = _load_unit_archetypes()
    _load_campaign_state()
    _spawn_match_units()
    _setup_fireteam_ai()
    _init_match_stats()
    debug_overlay.set_state("Game")
    end_button.pressed.connect(_on_end_pressed)
    # Log events
    for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
        Logger.log_event("Spawned Unit %d (role %s)" % [unit.id, unit.role])

func _process(delta: float) -> void:
    _handle_camera_movement(delta)
    _update_selection_panel()
    _update_objective(delta)
    _check_victory_conditions()

func _unhandled_input(event: InputEvent) -> void:
    # Right‑click issues orders
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        var pos := get_global_mouse_position()
        # Determine order type based on keyboard state
        var attack_move := Input.is_key_pressed(KEY_A)
        var queue := event.shift_pressed
        # Issue to all selected units
        for unit in selection_handler.selection:
            unit.issue_move_order(pos, queue)
            unit.attack_move = attack_move
            unit.hold = false
            unit.hold_mode = "off"
        # Log order
        var order_name := "Move"
        if attack_move:
            order_name = "Attack‑move"
        Logger.log_event("%s order issued to %d units" % [order_name, selection_handler.selection.size()])
    elif event is InputEventKey and event.pressed:
        if event.scancode == KEY_ESCAPE:
            _end_run()
            return
        if event.scancode == KEY_SPACE:
            # Pause/unpause
            get_tree().paused = not get_tree().paused
            Logger.log_event("Game paused" if get_tree().paused else "Game resumed")
        elif event.scancode == KEY_H:
            _toggle_hold_mode()
        elif event.scancode == KEY_F:
            # Cycle formation spacing
            current_formation_index = (current_formation_index + 1) % formation_modes.size()
            var mode := formation_modes[current_formation_index]
            # Apply spacing radius to selected units (stub)
            var spacing := 0.0
            var avoidance := 0.0
            match mode:
                "tight":
                    spacing = 12.0
                    avoidance = 8.0
                "normal":
                    spacing = 18.0
                    avoidance = 10.0
                "loose":
                    spacing = 28.0
                    avoidance = 16.0
            for i in range(selection_handler.selection.size()):
                var unit = selection_handler.selection[i]
                unit.separation_radius = spacing
                unit.avoidance_radius = avoidance
                # assign radial offset around target to spread units
                var angle = float(i) / max(selection_handler.selection.size(), 1) * TAU
                unit.spread_offset = Vector2(cos(angle), sin(angle)) * spacing
            Logger.log_event("Formation mode set to %s" % mode)
        else:
            _handle_control_group_input(event)
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _adjust_camera_zoom(-CAMERA_ZOOM_STEP)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _adjust_camera_zoom(CAMERA_ZOOM_STEP)

func _on_end_pressed() -> void:
    _end_run()

func _end_run() -> void:
    if match_over:
        return
    match_over = true
    _finalize_match_summary()
    _save_campaign_state()
    Logger.log_event("State transition: Game -> AfterAction")
    get_tree().change_scene_to_file("res://scenes/AfterAction.tscn")

func spawn_player_units(count: int) -> void:
    var scene := load("res://scenes/Unit.tscn")
    for i in range(count):
        var unit: Unit = scene.instantiate() as Unit
        unit.id = IDGenerator.next_id()
        _apply_unit_archetype(unit, "Rifle")
        _apply_persisted_data(unit)
        unit.position = Vector2(150 + i * 20, 400)
        unit.add_to_group("player_units")
        add_child(unit)
        _register_unit(unit)

func spawn_enemy_units(count: int) -> void:
    var scene := load("res://scenes/Unit.tscn")
    var fireteam_index := 0
    var fireteam_size := 0
    for i in range(count):
        var unit: Unit = scene.instantiate() as Unit
        unit.id = IDGenerator.next_id()
        unit.set_script(load("res://scripts/ai_unit.gd"))
        var archetype := "Support" if i % 2 == 0 else "Scout"
        _apply_unit_archetype(unit, archetype)
        _apply_persisted_data(unit)
        unit.position = Vector2(800 + i * 20, 200)
        unit.add_to_group("enemy_units")
        unit.fireteam_id = fireteam_index
        if fireteam_size == 0:
            fireteam_size = FIRETEAM_MIN_SIZE + (fireteam_index % (FIRETEAM_MAX_SIZE - FIRETEAM_MIN_SIZE + 1))
            fireteams[fireteam_index] = []
        unit.add_to_group("fireteam_%d" % fireteam_index)
        # Turn on attack behaviour for AI units
        unit.attack_move = true
        add_child(unit)
        _register_unit(unit)
        fireteams[fireteam_index].append(unit)
        fireteam_size -= 1
        if fireteam_size <= 0:
            fireteam_index += 1

func _setup_fireteam_ai() -> void:
    var fireteam_scene := load("res://ai/fireteam_ai.gd")
    for key in fireteams.keys():
        var team_node := fireteam_scene.new()
        add_child(team_node)
        team_node.setup(int(key), fireteams[key])

func _handle_camera_movement(delta: float) -> void:
    # Camera panning with WASD keys + edge scrolling
    var move_vector := Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        move_vector.y -= 1
    if Input.is_key_pressed(KEY_S):
        move_vector.y += 1
    if Input.is_key_pressed(KEY_A):
        move_vector.x -= 1
    if Input.is_key_pressed(KEY_D):
        move_vector.x += 1
    var viewport_size := get_viewport().get_visible_rect().size
    var mouse_pos := get_viewport().get_mouse_position()
    if mouse_pos.x <= CAMERA_EDGE_MARGIN:
        move_vector.x -= 1
    elif mouse_pos.x >= viewport_size.x - CAMERA_EDGE_MARGIN:
        move_vector.x += 1
    if mouse_pos.y <= CAMERA_EDGE_MARGIN:
        move_vector.y -= 1
    elif mouse_pos.y >= viewport_size.y - CAMERA_EDGE_MARGIN:
        move_vector.y += 1
    if move_vector != Vector2.ZERO:
        move_vector = move_vector.normalized()
        camera.position += move_vector * CAMERA_SPEED * delta
    _clamp_camera_to_bounds()

func _adjust_camera_zoom(delta: float) -> void:
    var new_zoom := clamp(camera.zoom.x + delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
    camera.zoom = Vector2(new_zoom, new_zoom)
    _clamp_camera_to_bounds()

func _clamp_camera_to_bounds() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var half_view := viewport_size * 0.5 * camera.zoom
    var min_pos := MAP_BOUNDS.position + half_view
    var max_pos := MAP_BOUNDS.position + MAP_BOUNDS.size - half_view
    if min_pos.x > max_pos.x:
        camera.position.x = MAP_BOUNDS.position.x + MAP_BOUNDS.size.x * 0.5
    else:
        camera.position.x = clamp(camera.position.x, min_pos.x, max_pos.x)
    if min_pos.y > max_pos.y:
        camera.position.y = MAP_BOUNDS.position.y + MAP_BOUNDS.size.y * 0.5
    else:
        camera.position.y = clamp(camera.position.y, min_pos.y, max_pos.y)

func _spawn_match_units() -> void:
    var player_count := clamp(PLAYER_UNIT_COUNT, 4, 80)
    var total_target := clamp(TOTAL_UNIT_TARGET, 80, 200)
    var enemy_count := max(total_target - player_count, 0)
    spawn_player_units(player_count)
    spawn_enemy_units(enemy_count)

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
    if data.has("weapon_range"):
        unit.weapon_range = float(data["weapon_range"])
    if data.has("rate_of_fire"):
        unit.rate_of_fire = float(data["rate_of_fire"])
    if data.has("damage"):
        unit.damage = float(data["damage"])
    if data.has("suppression_power"):
        unit.suppression_power = float(data["suppression_power"])
    if data.has("suppression_resistance"):
        unit.suppression_resistance = float(data["suppression_resistance"])
    if data.has("role_tag"):
        unit.role_tag = str(data["role_tag"])
    if data.has("cost_tag"):
        unit.cost_tag = str(data["cost_tag"])

func _register_unit(unit: Unit) -> void:
    if unit_roster.has(unit.id):
        return
    unit_roster[unit.id] = {
        "id": unit.id,
        "xp": unit.xp,
        "rank": unit.rank
    }

func _update_selection_panel() -> void:
    if selection_label == null:
        return
    var selected: Array = selection_handler.selection
    var role_counts: Dictionary = {}
    for unit in selected:
        var role_name: String = unit.role
        role_counts[role_name] = role_counts.get(role_name, 0) + 1
    var parts: Array = []
    var roles := role_counts.keys()
    roles.sort()
    for role in roles:
        parts.append("%s x%d" % [role, role_counts[role]])
    var summary := "Selection: %d" % selected.size()
    if parts.size() > 0:
        summary += " (" + ", ".join(parts) + ")"
    if summary != last_selection_summary:
        selection_label.text = summary
        last_selection_summary = summary

func _toggle_hold_mode() -> void:
    var cycle := ["off", "defensive", "aggressive"]
    for unit in selection_handler.selection:
        var index := cycle.find(unit.hold_mode)
        if index == -1:
            index = 0
        var next_index := (index + 1) % cycle.size()
        unit.hold_mode = cycle[next_index]
        unit.hold = unit.hold_mode != "off"
        unit.attack_move = unit.hold_mode == "aggressive"
        if unit.hold:
            unit.waypoints = []
            unit.target_position = unit.global_position
    var mode_label := "off"
    if selection_handler.selection.size() > 0:
        mode_label = selection_handler.selection[0].hold_mode
    Logger.log_event("Hold mode set to %s" % mode_label)

func is_line_of_sight(from_pos: Vector2, to_pos: Vector2, target: Node2D = null) -> bool:
    var space_state := get_world_2d().direct_space_state
    var params := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
    params.exclude = target != null ? [target] : []
    params.collision_mask = 1
    var result := space_state.intersect_ray(params)
    if result.is_empty():
        return true
    var collider := result.get("collider")
    if collider != null and collider.is_in_group("cover") and target != null:
        var cover := collider
        if "cover_radius" in cover:
            if cover.global_position.distance_to(target.global_position) <= cover.cover_radius:
                return true
    return false

func get_cover_state(target: Unit, source_pos: Vector2) -> Dictionary:
    var best_type := "none"
    var best_weight := 0.0
    for cover in get_tree().get_nodes_in_group("cover"):
        if not (cover is Node2D):
            continue
        if not ("cover_radius" in cover):
            continue
        var dist_to_target := cover.global_position.distance_to(target.global_position)
        if dist_to_target > cover.cover_radius:
            continue
        var to_source := (source_pos - target.global_position).normalized()
        var to_cover := (cover.global_position - target.global_position).normalized()
        var facing := to_source.dot(to_cover)
        if facing < 0.4:
            continue
        if source_pos.distance_to(cover.global_position) >= source_pos.distance_to(target.global_position):
            continue
        var cover_type := cover.cover_type if "cover_type" in cover else "light"
        var weight := 1.0 if cover_type == "heavy" else 0.5
        if weight > best_weight:
            best_weight = weight
            best_type = cover_type
    match best_type:
        "heavy":
            return {
                "type": "heavy",
                "hit_multiplier": 0.5,
                "damage_multiplier": 0.7
            }
        "light":
            return {
                "type": "light",
                "hit_multiplier": 0.75,
                "damage_multiplier": 0.85
            }
        _:
            return {
                "type": "none",
                "hit_multiplier": 1.0,
                "damage_multiplier": 1.0
            }
