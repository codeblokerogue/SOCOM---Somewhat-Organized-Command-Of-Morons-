extends "res://scripts/unit.gd"

##
# AI unit behaviour focuses on self-preservation and local reactions while
# fireteam tactics are handled by FireteamAI. Uses SDAE inputs provided by the team.

var fear: float = 0.0
var confidence: float = 0.5
var exposure: float = 0.0
var last_allies_near: int = 0

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if get_tree().paused:
        return
    _update_self_preservation(delta)
    _apply_self_preservation()

func _update_self_preservation(delta: float) -> void:
    var hp_ratio: float = hp / max(max_hp, 1)
    var allies_near: int = _count_allies_nearby(140.0)
    var fear_delta: float = 0.0
    if recent_damage_timer < 1.5:
        fear_delta += 0.18
    if suppression > 40.0:
        fear_delta += 0.12
    if hp_ratio < 0.4:
        fear_delta += 0.18
    if cover_state == "none":
        fear_delta += 0.1
    if cover_state == "heavy":
        fear_delta -= 0.16
    if allies_near >= 2:
        fear_delta -= 0.08
    if recent_damage_timer > 3.0 and suppression < 15.0:
        fear_delta -= 0.06
    if allies_near < last_allies_near:
        fear_delta += 0.05
    last_allies_near = allies_near
    fear = clamp(fear + fear_delta * delta, 0.0, 1.0)
    confidence = clamp(1.0 - fear, 0.0, 1.0)
    exposure = 1.0 if cover_state == "none" else 0.2

func _apply_self_preservation() -> void:
    var hp_ratio: float = hp / max(max_hp, 1)
    if fear > 0.85 or (hp_ratio < 0.3 and cover_state == "none"):
        _retreat_from_enemy(140.0)
        return
    if fear > 0.65 and cover_state == "none":
        hold = true
        hold_mode = "defensive"
        attack_move = true

func _retreat_from_enemy(distance: float) -> void:
    var nearest: Node = _get_nearest_enemy()
    if nearest == null:
        return
    var dir: Vector2 = (global_position - nearest.global_position).normalized()
    target_position = global_position + dir * distance
    hold = false
    hold_mode = "off"
    attack_move = false

func _get_nearest_enemy() -> Node:
    var nearest: Node = null
    var min_dist: float = INF
    for player in get_tree().get_nodes_in_group("player_units"):
        var d: float = (player.global_position - global_position).length()
        if d < min_dist:
            min_dist = d
            nearest = player
    return nearest

func _count_allies_nearby(radius: float) -> int:
    var count: int = 0
    for ally in get_tree().get_nodes_in_group("enemy_units"):
        if ally == self:
            continue
        if ally.global_position.distance_to(global_position) <= radius:
            count += 1
    return count
