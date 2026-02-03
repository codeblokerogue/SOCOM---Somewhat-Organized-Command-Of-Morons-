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
@export var suppression_resistance: float = 1.0
@export var role_tag: String = "rifleman"
@export var cost_tag: String = "basic"

var id: int = 0
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

func _ready() -> void:
    hp = max_hp
    target_position = global_position
    # Add to appropriate group in Game.gd
    # Visual update when selected changed
    update()

func _process(delta: float) -> void:
    # update selection visuals
    update()

func _physics_process(delta: float) -> void:
    # If holding, do not move
    if hold:
        velocity = Vector2.ZERO
    else:
        _update_movement(delta)
    # Decrease suppression over time
    if suppression > 0.0:
        suppression = max(0.0, suppression - delta * 5.0 * suppression_resistance)
    # Attack logic if attack_move or an enemy is in range
    _attack_logic(delta)

func _update_movement(delta: float) -> void:
    var target := target_position + spread_offset
    var diff: Vector2 = target - global_position
    var dist := diff.length()
    if dist > 4.0:
        var dir := diff.normalized()
        var move_speed := speed
        # Slow down when suppressed
        if suppression > 0.0:
            move_speed *= clamp(1.0 - suppression / 100.0, 0.4, 1.0)
        velocity = dir * move_speed
        position += velocity * delta
    else:
        velocity = Vector2.ZERO

func _attack_logic(delta: float) -> void:
    time_since_shot += delta
    # Only attack when attack_move is true
    if not attack_move:
        return
    # Check if ready to shoot
    if time_since_shot < rate_of_fire:
        return
    time_since_shot = 0.0
    # Find nearest enemy
    var nearest: Unit = null
    var min_dist := weapon_range
    var groups := []
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
                # LoS check can be added later
                nearest = other
                min_dist = d
    if nearest != null:
        # Hitscan: simple damage application
        nearest.take_damage(10.0, self)
        # Apply suppression to target
        nearest.suppression += 10.0
        # Log event
        _log_event("Unit %d shot Unit %d" % [id, nearest.id])

func take_damage(amount: float, source: Unit) -> void:
    hp -= amount
    _log_event("Unit %d took %.0f damage from Unit %d" % [id, amount, source.id])
    if hp <= 0.0:
        _log_event("Unit %d was killed" % id)
        queue_free()

func _draw() -> void:
    # Determine colour based on role
    var colour := Color(0.8, 0.8, 0.8)
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
        draw_circle(Vector2.ZERO, 8.0, Color(1, 1, 0), 2.0, 32)
    # Suppression bar can be drawn by DebugOverlay

func _log_event(text: String) -> void:
    # Send event to DebugOverlay via group
    get_tree().call_group("debug_overlay", "log_event", text)
