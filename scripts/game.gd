extends Node2D

##
# Main game logic: spawns units, handles camera controls and issues orders to selected units.

const IDGenerator = preload("res://scripts/id_generator.gd")

@onready var selection_handler: Node = $SelectionHandler
@onready var camera: Camera2D = $Camera2D
@onready var debug_overlay = $DebugOverlay
@onready var end_button = $HUD/EndButton
@onready var selection_label: Label = $HUD/SelectionPanel/SelectionLabel
@onready var objective_marker: Node2D = get_node_or_null("ObjectiveMarker")

var last_selection_summary: String = ""

var formation_modes: Array = ["tight", "normal", "loose"]
var current_formation_index: int = 1  # start at normal
var unit_archetypes: Dictionary = {}
var unit_roster: Dictionary = {}
var fireteams: Dictionary = {}
var match_stats: Dictionary = {}
var control_groups: Dictionary = {}
var hold_timer_player: float = 0.0
var hold_timer_enemy: float = 0.0
var match_over: bool = false
var playtest_active: bool = false
var playtest_runner: Node = null
const HOLD_THRESHOLD: float = 12.0
const OBJECTIVE_CONTROL_MIN: int = 1

const PLAYER_UNIT_COUNT: int = 8
const TOTAL_UNIT_TARGET: int = 80
const PLAYTEST_PLAYER_COUNT: int = 6
const PLAYTEST_TOTAL_COUNT: int = 16
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
    playtest_active = _is_playtest_active()
    unit_archetypes = _load_unit_archetypes()
    _load_campaign_state()
    _spawn_match_units()
    _apply_map_modifiers()
    _setup_fireteam_ai()
    _init_match_stats()
    debug_overlay.set_state("Game")
    end_button.pressed.connect(_on_end_pressed)
    # Log events
    for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
        Logger.log_event("Spawned Unit %d (role %s)" % [unit.id, unit.role])
    if playtest_active:
        _start_playtest_runner()

func _process(delta: float) -> void:
    _handle_camera_movement(delta)
    _update_selection_panel()
    _update_objective(delta)
    _update_suppression_stats()
    _check_victory_conditions()

func _unhandled_input(event: InputEvent) -> void:
    # Right‑click issues orders
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        var pos: Vector2 = get_global_mouse_position()
        # Determine order type based on keyboard state
        var attack_move: bool = Input.is_key_pressed(KEY_A)
        var queue: bool = event.shift_pressed
        # Issue to all selected units
        for unit in selection_handler.selection:
            unit.issue_move_order(pos, queue)
            unit.attack_move = attack_move
            unit.hold = false
            unit.hold_mode = "off"
        # Log order
        var order_name: String = "Move"
        if attack_move:
            order_name = "Attack‑move"
        Logger.log_event("%s order issued to %d units" % [order_name, selection_handler.selection.size()])
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _end_run()
            return
        if event.keycode == KEY_SPACE:
            # Pause/unpause
            get_tree().paused = not get_tree().paused
            Logger.log_event("Game paused" if get_tree().paused else "Game resumed")
        elif event.keycode == KEY_H:
            _toggle_hold_mode()
        elif event.keycode == KEY_F:
            # Cycle formation spacing
            current_formation_index = (current_formation_index + 1) % formation_modes.size()
            var mode: String = formation_modes[current_formation_index]
            # Apply spacing radius to selected units (stub)
            var spacing: float = 0.0
            var avoidance: float = 0.0
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
    if match_stats.get("end_reason", "") == "In Progress":
        match_stats["end_reason"] = "Manual end"
    _finalize_match_summary()
    _save_campaign_state()
    Logger.log_event("State transition: Game -> AfterAction")
    get_tree().change_scene_to_file("res://scenes/AfterAction.tscn")

func spawn_player_units(count: int) -> void:
    var scene: PackedScene = load("res://scenes/Unit.tscn")
    for i in range(count):
        var unit = scene.instantiate()
        unit.id = IDGenerator.next_id()
        _apply_unit_archetype(unit, "Rifle")
        _apply_persisted_data(unit)
        unit.position = Vector2(150 + i * 20, 400)
        unit.add_to_group("player_units")
        add_child(unit)
        _register_unit(unit)

func spawn_enemy_units(count: int) -> void:
    var scene: PackedScene = load("res://scenes/Unit.tscn")
    var fireteam_index: int = 0
    var fireteam_size: int = 0
    for i in range(count):
        var unit = scene.instantiate()
        unit.set_script(load("res://scripts/ai_unit.gd"))
        unit.id = IDGenerator.next_id()
        var archetype: String = "Support" if i % 2 == 0 else "Scout"
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
    var fireteam_scene: Script = load("res://ai/fireteam_ai.gd")
    for key in fireteams.keys():
        var team_node: Node = fireteam_scene.new()
        add_child(team_node)
        team_node.setup(int(key), fireteams[key])

func _handle_camera_movement(delta: float) -> void:
    # Camera panning with WASD keys + edge scrolling
    var move_vector: Vector2 = Vector2.ZERO
    if Input.is_key_pressed(KEY_W):
        move_vector.y -= 1
    if Input.is_key_pressed(KEY_S):
        move_vector.y += 1
    if Input.is_key_pressed(KEY_A):
        move_vector.x -= 1
    if Input.is_key_pressed(KEY_D):
        move_vector.x += 1
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
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
    var new_zoom: float = clamp(camera.zoom.x + delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
    camera.zoom = Vector2(new_zoom, new_zoom)
    _clamp_camera_to_bounds()

func _clamp_camera_to_bounds() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var half_view: Vector2 = viewport_size * 0.5 * camera.zoom
    var min_pos: Vector2 = MAP_BOUNDS.position + half_view
    var max_pos: Vector2 = MAP_BOUNDS.position + MAP_BOUNDS.size - half_view
    if min_pos.x > max_pos.x:
        camera.position.x = MAP_BOUNDS.position.x + MAP_BOUNDS.size.x * 0.5
    else:
        camera.position.x = clamp(camera.position.x, min_pos.x, max_pos.x)
    if min_pos.y > max_pos.y:
        camera.position.y = MAP_BOUNDS.position.y + MAP_BOUNDS.size.y * 0.5
    else:
        camera.position.y = clamp(camera.position.y, min_pos.y, max_pos.y)

func _spawn_match_units() -> void:
    var player_count: int = clamp(PLAYER_UNIT_COUNT, 4, 80)
    var total_target: int = clamp(TOTAL_UNIT_TARGET, 80, 200)
    if playtest_active:
        player_count = PLAYTEST_PLAYER_COUNT
        total_target = PLAYTEST_TOTAL_COUNT
    var enemy_count: int = max(total_target - player_count, 0)
    spawn_player_units(player_count)
    spawn_enemy_units(enemy_count)

func _apply_map_modifiers() -> void:
    var modifier_node: Node = get_node_or_null("MapModifiers")
    if modifier_node == null:
        return
    if not modifier_node.has_method("apply_to_unit"):
        return
    for unit in get_tree().get_nodes_in_group("player_units") + get_tree().get_nodes_in_group("enemy_units"):
        modifier_node.apply_to_unit(unit)

func _load_unit_archetypes() -> Dictionary:
    var path: String = "res://data/units.json"
    if not FileAccess.file_exists(path):
        Logger.log_event("Unit data missing: %s" % path)
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    var content: String = file.get_as_text()
    var parsed = JSON.parse_string(content)
    if typeof(parsed) != TYPE_DICTIONARY:
        Logger.log_event("Unit data invalid JSON: %s" % path)
        return {}
    return parsed

func _apply_unit_archetype(unit: Node, archetype_name: String) -> void:
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

func _register_unit(unit: Node) -> void:
    if unit_roster.has(unit.id):
        return
    unit_roster[unit.id] = {
        "id": unit.id,
        "xp": unit.xp,
        "rank": unit.rank
    }

func _apply_persisted_data(unit: Node) -> void:
    if unit_roster.has(unit.id):
        var data: Dictionary = unit_roster[unit.id]
        unit.xp = data.get("xp", 0)
        unit.rank = data.get("rank", 0)

func _update_selection_panel() -> void:
    if selection_label == null:
        return
    var selected: Array = selection_handler.selection
    var role_counts: Dictionary = {}
    for unit in selected:
        var role_name: String = unit.role
        role_counts[role_name] = role_counts.get(role_name, 0) + 1
    var parts: Array = []
    var roles: Array = role_counts.keys()
    roles.sort()
    for role in roles:
        parts.append("%s x%d" % [role, role_counts[role]])
    var summary: String = "Selection: %d" % selected.size()
    if parts.size() > 0:
        summary += " (" + ", ".join(parts) + ")"
    if summary != last_selection_summary:
        selection_label.text = summary
        last_selection_summary = summary

func _toggle_hold_mode() -> void:
    var cycle: Array = ["off", "defensive", "aggressive"]
    for unit in selection_handler.selection:
        var index: int = cycle.find(unit.hold_mode)
        if index == -1:
            index = 0
        var next_index: int = (index + 1) % cycle.size()
        unit.hold_mode = cycle[next_index]
        unit.hold = unit.hold_mode != "off"
        unit.attack_move = unit.hold_mode == "aggressive"
        if unit.hold:
            unit.waypoints = []
            unit.target_position = unit.global_position
    var mode_label: String = "off"
    if selection_handler.selection.size() > 0:
        mode_label = selection_handler.selection[0].hold_mode
    Logger.log_event("Hold mode set to %s" % mode_label)

func _handle_control_group_input(_event: InputEvent) -> void:
    return

func is_line_of_sight(from_pos: Vector2, to_pos: Vector2, target: Node2D = null) -> bool:
    var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
    var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
    params.exclude = [target] if target != null else []
    params.collision_mask = 1
    var result: Dictionary = space_state.intersect_ray(params)
    if result.is_empty():
        return true
    var collider = result.get("collider")
    if collider != null and collider.is_in_group("cover") and target != null:
        var cover = collider
        if "cover_radius" in cover:
            if cover.global_position.distance_to(target.global_position) <= cover.cover_radius:
                return true
    return false

func get_cover_state(target: Node, source_pos: Vector2) -> Dictionary:
    var best_type: String = "none"
    var best_weight: float = 0.0
    for cover in get_tree().get_nodes_in_group("cover"):
        if not (cover is Node2D):
            continue
        if not ("cover_radius" in cover):
            continue
        var dist_to_target: float = cover.global_position.distance_to(target.global_position)
        if dist_to_target > cover.cover_radius:
            continue
        var to_source: Vector2 = (source_pos - target.global_position).normalized()
        var to_cover: Vector2 = (cover.global_position - target.global_position).normalized()
        var facing: float = to_source.dot(to_cover)
        if facing < 0.4:
            continue
        if source_pos.distance_to(cover.global_position) >= source_pos.distance_to(target.global_position):
            continue
        var cover_type: String = cover.cover_type if "cover_type" in cover else "light"
        var weight: float = 1.0 if cover_type == "heavy" else 0.5
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

func _init_match_stats() -> void:
    match_stats = {
        "player_kills": 0,
        "enemy_kills": 0,
        "kills_in_cover": 0,
        "kills_in_open": 0,
        "xp_awarded": 0,
        "objective_winner": "None",
        "end_reason": "In Progress",
        "survivors_player": 0,
        "survivors_enemy": 0
    }
    hold_timer_player = 0.0
    hold_timer_enemy = 0.0

func _update_objective(delta: float) -> void:
    if match_over:
        return
    if objective_marker == null:
        return
    var radius: float = 120.0
    if "radius" in objective_marker:
        radius = objective_marker.radius
    var marker_pos: Vector2 = objective_marker.global_position
    var player_count: int = _count_units_in_radius("player_units", marker_pos, radius)
    var enemy_count: int = _count_units_in_radius("enemy_units", marker_pos, radius)
    if player_count >= OBJECTIVE_CONTROL_MIN and enemy_count == 0:
        hold_timer_player += delta
        hold_timer_enemy = max(0.0, hold_timer_enemy - delta)
    elif enemy_count >= OBJECTIVE_CONTROL_MIN and player_count == 0:
        hold_timer_enemy += delta
        hold_timer_player = max(0.0, hold_timer_player - delta)
    else:
        hold_timer_player = max(0.0, hold_timer_player - delta * 0.5)
        hold_timer_enemy = max(0.0, hold_timer_enemy - delta * 0.5)
    if hold_timer_player >= HOLD_THRESHOLD:
        match_stats["objective_winner"] = "Player"
        match_stats["end_reason"] = "Objective held"
        _end_run()
    elif hold_timer_enemy >= HOLD_THRESHOLD:
        match_stats["objective_winner"] = "Enemy"
        match_stats["end_reason"] = "Objective lost"
        _end_run()

func _check_victory_conditions() -> void:
    if match_over:
        return
    var player_units: Array = get_tree().get_nodes_in_group("player_units")
    var enemy_units: Array = get_tree().get_nodes_in_group("enemy_units")
    if player_units.is_empty():
        match_stats["end_reason"] = "Defeat"
        _end_run()
    elif enemy_units.is_empty():
        match_stats["end_reason"] = "Victory"
        _end_run()

func record_kill(cover_state: String, source: Node) -> void:
    if source != null and source.is_in_group("player_units"):
        match_stats["player_kills"] += 1
    elif source != null and source.is_in_group("enemy_units"):
        match_stats["enemy_kills"] += 1
    if cover_state == "none":
        match_stats["kills_in_open"] += 1
    else:
        match_stats["kills_in_cover"] += 1

func award_xp(unit: Node, amount: int) -> void:
    if unit == null:
        return
    unit.xp += amount
    match_stats["xp_awarded"] += amount
    Logger.log_event("Unit %d gained %d XP" % [unit.id, amount])
    if unit_roster.has(unit.id):
        unit_roster[unit.id]["xp"] = unit.xp
        unit_roster[unit.id]["rank"] = unit.rank

func _finalize_match_summary() -> void:
    match_stats["survivors_player"] = get_tree().get_nodes_in_group("player_units").size()
    match_stats["survivors_enemy"] = get_tree().get_nodes_in_group("enemy_units").size()
    if match_stats.get("end_reason", "") == "In Progress":
        match_stats["end_reason"] = "Unknown"
    get_tree().set_meta("match_summary", match_stats)
    Logger.dump_to_file("user://match_log.txt")

func _load_campaign_state() -> void:
    var path: String = "user://campaign.json"
    if not FileAccess.file_exists(path):
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var units: Array = parsed.get("units", [])
    if typeof(units) != TYPE_ARRAY:
        return
    for entry in units:
        if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
            unit_roster[entry["id"]] = {
                "id": entry.get("id", 0),
                "xp": entry.get("xp", 0),
                "rank": entry.get("rank", 0)
            }

func _save_campaign_state() -> void:
    _sync_roster_from_units()
    var data: Dictionary = {
        "units": unit_roster.values()
    }
    var file: FileAccess = FileAccess.open("user://campaign.json", FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(data, "  "))

func _sync_roster_from_units() -> void:
    for unit in get_tree().get_nodes_in_group("player_units"):
        if not unit_roster.has(unit.id):
            unit_roster[unit.id] = {
                "id": unit.id,
                "xp": unit.xp,
                "rank": unit.rank
            }
        else:
            unit_roster[unit.id]["xp"] = unit.xp
            unit_roster[unit.id]["rank"] = unit.rank

func _count_units_in_radius(group_name: String, origin: Vector2, radius: float) -> int:
    var count: int = 0
    var radius_sq: float = radius * radius
    for unit in get_tree().get_nodes_in_group(group_name):
        if unit.global_position.distance_squared_to(origin) <= radius_sq:
            count += 1
    return count

func _is_playtest_active() -> bool:
    return get_tree().has_meta("playtest_active") and bool(get_tree().get_meta("playtest_active"))

func _start_playtest_runner() -> void:
    if playtest_runner != null:
        return
    var runner: Node = preload("res://scripts/playtest_runner.gd").new()
    playtest_runner = runner
    add_child(runner)
