extends Node2D

##
# Base unit script for player and AI units.
# Implements movement, simple hitscan shooting, suppression and selection visuals.

class_name Unit

@export var role: String = "Rifle"
@export var speed: float = 120.0
@export var max_hp: int = 100
@export var weapon_range: float = 350.0
@export var rate_of_fire: float = 0.5
@export var accuracy: float = 0.8
@export var damage: float = 10.0
@export var suppression_power: float = 10.0
@export var suppression_resistance: float = 1.0
@export var role_tag: String = "rifleman"
@export var cost_tag: String = "basic"

var id: int = 0
var fireteam_id: int = -1
var xp: int = 0
var rank: int = 0
var hp: float
var suppression: float = 0.0
var selected: bool = false
var target_position: Vector2
var hold: bool = false
var attack_move: bool = false
var spread_offset: Vector2 = Vector2.ZERO
var time_since_shot: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var last_move_dir: Vector2 = Vector2.ZERO
var separation_radius: float = 18.0
var avoidance_radius: float = 10.0
var separation_strength: float = 140.0
var avoidance_strength: float = 220.0
var waypoints: Array = []
var hold_mode: String = "off"
var recent_damage_timer: float = 999.0
var cover_state: String = "none"
var last_known_positions: Dictionary = {}
const LAST_KNOWN_FADE: float = 6.0

func _ready() -> void:
    hp = max_hp
    target_position = global_position
    # Add to appropriate group in Game.gd
    # Visual update when selected changed
    queue_redraw()

func _process(delta: float) -> void:
    # update selection visuals
    queue_redraw()

func _physics_process(delta: float) -> void:
    if recent_damage_timer < 999.0:
        recent_damage_timer += delta
    # If holding, do not move
    if hold:
        velocity = Vector2.ZERO
    else:
        _update_movement(delta)
    # Decrease suppression over time
    if suppression > 0.0:
        suppression = max(0.0, suppression - delta * 5.0 * suppression_resistance)
    _sense_enemies(delta)
    _update_cover_state()
    # Attack logic if attack_move or an enemy is in range
    _attack_logic(delta)

func _update_movement(delta: float) -> void:
    var target: Vector2 = target_position + spread_offset
    var diff: Vector2 = target - global_position
    var dist: float = diff.length()
    if dist > 4.0:
        var dir: Vector2 = diff.normalized()
        var move_speed: float = speed
        # Slow down when suppressed
        if suppression > 0.0:
            move_speed *= clamp(1.0 - suppression / 100.0, 0.4, 1.0)
        var desired_velocity: Vector2 = dir * move_speed
        var separation_force: Vector2 = Vector2.ZERO
        var avoidance_force: Vector2 = Vector2.ZERO
        var separation_radius_scaled: float = separation_radius
        var avoidance_radius_scaled: float = avoidance_radius
        for group_name in ["player_units", "enemy_units"]:
            for other in get_tree().get_nodes_in_group(group_name):
                if other == self:
                    continue
                var offset: Vector2 = global_position - other.global_position
                var other_dist: float = offset.length()
                if other_dist <= 0.001:
                    continue
                if other_dist < separation_radius_scaled:
                    separation_force += offset.normalized() * (1.0 - other_dist / separation_radius_scaled)
                if other_dist < avoidance_radius_scaled:
                    avoidance_force += offset.normalized() * (1.0 - other_dist / avoidance_radius_scaled)
        var steer: Vector2 = desired_velocity
        steer += separation_force * separation_strength
        steer += avoidance_force * avoidance_strength
        if steer.length() > move_speed:
            steer = steer.normalized() * move_speed
        velocity = steer
        if velocity.length() > 1.0:
            last_move_dir = velocity.normalized()
        position += velocity * delta
    else:
        velocity = Vector2.ZERO
        if waypoints.size() > 1:
            waypoints.remove_at(0)
            target_position = waypoints[0]

func _attack_logic(delta: float) -> void:
    time_since_shot += delta
    # Only attack when attack_move is true
    if not attack_move and not (hold_mode == "defensive" and recent_damage_timer <= 2.0):
        return
    # Check if ready to shoot
    if time_since_shot < rate_of_fire:
        return
    time_since_shot = 0.0
    # Find nearest enemy with LoS
    var nearest: Node = null
    var min_dist: float = weapon_range
    var groups: Array = []
    # Determine which group is the enemy
    if is_in_group("player_units"):
        groups.append("enemy_units")
    elif is_in_group("enemy_units"):
        groups.append("player_units")
    for group_name in groups:
        for other in get_tree().get_nodes_in_group(group_name):
            if other == self:
                continue
            var d: float = (other.global_position - global_position).length()
            if d < min_dist:
                if _has_line_of_sight(other.global_position, other):
                    nearest = other
                    min_dist = d
    if nearest != null:
        var base_accuracy: float = accuracy
        if suppression > 0.0:
            base_accuracy *= clamp(1.0 - suppression / 120.0, 0.4, 1.0)
        var movement_factor: float = 1.0
        if velocity.length() > 5.0:
            movement_factor = 0.75
        var distance_factor: float = clamp(1.0 - (min_dist / weapon_range) * 0.4, 0.5, 1.0)
        var cover_data: Dictionary = _get_cover_data(nearest)
        var hit_chance: float = base_accuracy * distance_factor * movement_factor * cover_data["hit_multiplier"]
        if randf() <= hit_chance:
            var final_damage: float = damage * cover_data["damage_multiplier"]
            nearest.take_damage(final_damage, self)
            Logger.log_telemetry("combat_hit", {
                "attacker_id": id,
                "target_id": nearest.id,
                "damage": final_damage,
                "distance": min_dist,
                "cover": cover_data.get("type", "none")
            })
        else:
            Logger.log_telemetry("combat_miss", {
                "attacker_id": id,
                "target_id": nearest.id,
                "distance": min_dist,
                "cover": cover_data.get("type", "none")
            })
        # Apply suppression to target
        nearest.suppression += _suppression_amount()
        Logger.log_telemetry("combat_suppression", {
            "attacker_id": id,
            "target_id": nearest.id,
            "amount": _suppression_amount()
        })
        # Log event
        _log_event("Unit %d shot Unit %d" % [id, nearest.id])

func take_damage(amount: float, source: Node) -> void:
    hp -= amount
    recent_damage_timer = 0.0
    _log_event("Unit %d took %.0f damage from Unit %d" % [id, amount, source.id])
    if hp <= 0.0:
        var game: Node = _get_game()
        if game != null:
            game.record_kill(cover_state, source)
            game.award_xp(source, 10)
            game.record_flank_event(source, self)
        Logger.log_telemetry("combat_kill", {
            "attacker_id": source.id,
            "target_id": id,
            "cover": cover_state
        })
        _log_event("Unit %d was killed" % id)
        queue_free()

func _draw() -> void:
    # Determine colour based on role
    var colour: Color = Color(0.8, 0.8, 0.8)
    match role:
        "Scout":
            colour = Color(0.3, 0.9, 0.3)
        "Support":
            colour = Color(0.9, 0.3, 0.3)
        _:
            pass
    draw_circle(Vector2.ZERO, 6.0, colour)
    # Draw selection outline
    if selected:
        draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 32, Color(1, 1, 0), 2.0)
    _draw_suppression_bar()
    _draw_cover_indicator()

func _log_event(text: String) -> void:
    # Send event to DebugOverlay via group
    get_tree().call_group("debug_overlay", "log_event", text)

func issue_move_order(destination: Vector2, queue: bool) -> void:
    if not queue:
        waypoints = [destination]
    elif waypoints.size() < 2:
        waypoints.append(destination)
    if waypoints.size() > 0:
        target_position = waypoints[0]

func _suppression_amount() -> float:
    return suppression_power

func _draw_suppression_bar() -> void:
    var bar_width: float = 26.0
    var bar_height: float = 4.0
    var pct: float = clamp(suppression / 100.0, 0.0, 1.0)
    var rect: Rect2 = Rect2(Vector2(-bar_width / 2.0, -22.0), Vector2(bar_width, bar_height))
    draw_rect(rect, Color(0.2, 0.2, 0.2, 0.7), true)
    draw_rect(Rect2(rect.position, Vector2(bar_width * pct, bar_height)), Color(1.0, 0.1, 0.1, 0.9), true)

func _draw_cover_indicator() -> void:
    if cover_state == "none":
        return
    var colour: Color = Color(0.6, 0.8, 1.0)
    if cover_state == "heavy":
        colour = Color(0.2, 0.5, 1.0)
    draw_rect(Rect2(Vector2(-5, -30), Vector2(10, 4)), colour, true)

func _sense_enemies(delta: float) -> void:
    var keys: Array = last_known_positions.keys()
    for key in keys:
        last_known_positions[key]["age"] += delta
        if last_known_positions[key]["age"] >= LAST_KNOWN_FADE:
            last_known_positions.erase(key)
    var groups: Array = []
    if is_in_group("player_units"):
        groups.append("enemy_units")
    elif is_in_group("enemy_units"):
        groups.append("player_units")
    for group_name in groups:
        for other in get_tree().get_nodes_in_group(group_name):
            if other == self:
                continue
            var d: float = (other.global_position - global_position).length()
            if d <= weapon_range and _has_line_of_sight(other.global_position, other):
                last_known_positions[other.id] = {"pos": other.global_position, "age": 0.0}

func _update_cover_state() -> void:
    var nearest: Node = _get_nearest_enemy()
    if nearest == null:
        cover_state = "none"
        return
    var cover_data: Dictionary = _get_cover_data(nearest)
    cover_state = cover_data["type"]

func _get_nearest_enemy() -> Node:
    var groups: Array = []
    if is_in_group("player_units"):
        groups.append("enemy_units")
    elif is_in_group("enemy_units"):
        groups.append("player_units")
    var nearest: Node = null
    var min_dist: float = 999999.0
    for group_name in groups:
        for other in get_tree().get_nodes_in_group(group_name):
            if other == self:
                continue
            var d: float = (other.global_position - global_position).length()
            if d < min_dist:
                min_dist = d
                nearest = other
    return nearest

func _get_cover_data(target: Node) -> Dictionary:
    var game: Node = _get_game()
    if game != null:
        return game.get_cover_state(target, global_position)
    return {"type": "none", "hit_multiplier": 1.0, "damage_multiplier": 1.0}

func _has_line_of_sight(to_pos: Vector2, target: Node2D) -> bool:
    var game: Node = _get_game()
    if game != null:
        return game.is_line_of_sight(global_position, to_pos, target)
    return true

func _get_game() -> Node:
    return get_tree().get_first_node_in_group("game")
