extends "res://scripts/unit.gd"

##
# AI unit behaviour focuses on self-preservation and local reactions while
# fireteam tactics are handled by FireteamAI. Uses SDAE inputs provided by the team.

var fear: float = 0.0
var confidence: float = 0.5
var exposure: float = 0.0
var last_allies_near: int = 0
var reload_timer: float = 0.0
var shots_since_reload: int = 0
var last_shot_clock: float = 0.0
var peek_timer: float = 0.0
var peek_cooldown: float = 0.0
var cover_seek_cooldown: float = 0.0
var seeking_cover: bool = false
var attack_move_before_reload: bool = false
var help_call_cooldown: float = 0.0

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if get_tree().paused:
        return
    _track_weapon_state()
    _update_self_preservation(delta)
    _apply_self_preservation()
    _maybe_call_for_help(delta)
    _apply_micro_behaviors(delta)

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

func _apply_micro_behaviors(delta: float) -> void:
    _update_reload_state(delta)
    _update_open_ground_refusal()
    _update_cover_seek(delta)
    _update_cover_hugging()
    _update_peeking(delta)

func _update_reload_state(delta: float) -> void:
    if reload_timer > 0.0:
        reload_timer = max(0.0, reload_timer - delta)
        if reload_timer == 0.0:
            attack_move = attack_move_before_reload
        return
    if shots_since_reload >= 4:
        reload_timer = 1.6
        shots_since_reload = 0
        attack_move_before_reload = attack_move
        attack_move = false
        hold = true

func _update_cover_seek(delta: float) -> void:
    if cover_seek_cooldown > 0.0:
        cover_seek_cooldown = max(0.0, cover_seek_cooldown - delta)
    if seeking_cover and (cover_state != "none" or global_position.distance_to(target_position) <= 8.0):
        seeking_cover = false
        return
    if cover_state != "none":
        return
    if cover_seek_cooldown > 0.0:
        return
    if fear < 0.55 and suppression < 35.0 and recent_damage_timer > 1.2:
        return
    var cover: Node2D = _find_nearest_cover(240.0)
    if cover == null:
        return
    target_position = cover.global_position
    hold = false
    hold_mode = "off"
    attack_move = false
    seeking_cover = true
    cover_seek_cooldown = 1.5

func _update_peeking(delta: float) -> void:
    if peek_cooldown > 0.0:
        peek_cooldown = max(0.0, peek_cooldown - delta)
    if peek_timer > 0.0:
        peek_timer = max(0.0, peek_timer - delta)
        attack_move = true
        hold = true
        hold_mode = "defensive"
        return
    if cover_state == "none":
        return
    if reload_timer > 0.0:
        return
    if peek_cooldown > 0.0:
        return
    if suppression > 60.0 or fear > 0.8:
        return
    if recent_damage_timer < 0.4:
        return
    var caution: float = clamp((fear + exposure) * 0.5, 0.0, 1.0)
    peek_timer = lerp(0.45, 0.2, caution)
    peek_cooldown = lerp(1.6, 3.0, caution)

func _update_open_ground_refusal() -> void:
    if fear > 0.85:
        return
    if cover_state != "none":
        return
    if fear < 0.7 or exposure < 0.6:
        return
    if seeking_cover:
        return
    var cover: Node2D = _find_nearest_cover(260.0)
    if cover != null:
        target_position = cover.global_position
        hold = false
        hold_mode = "off"
        attack_move = false
        seeking_cover = true
        cover_seek_cooldown = 1.0
        return
    hold = true
    hold_mode = "defensive"
    attack_move = false

func _update_cover_hugging() -> void:
    if cover_state == "none":
        return
    if fear < 0.65 and exposure < 0.5:
        return
    hold = true
    hold_mode = "defensive"
    attack_move = false

func _maybe_call_for_help(delta: float) -> void:
    if help_call_cooldown > 0.0:
        help_call_cooldown = max(0.0, help_call_cooldown - delta)
        return
    var reason: String = ""
    if fear > 0.78 and exposure > 0.6:
        reason = "panic"
    elif suppression > 65.0:
        reason = "suppressed"
    if reason == "":
        return
    help_call_cooldown = 6.0
    SOCOMLog.log_telemetry("ai_help_request", {
        "unit_id": id,
        "fireteam_id": fireteam_id,
        "reason": reason,
        "fear": fear,
        "suppression": suppression,
        "exposure": exposure
    })
    get_tree().call_group("ai_fireteams", "receive_help_request", fireteam_id, id, reason, {
        "fear": fear,
        "suppression": suppression,
        "exposure": exposure
    })

func _track_weapon_state() -> void:
    if time_since_shot < last_shot_clock:
        shots_since_reload += 1
    last_shot_clock = time_since_shot

func _find_nearest_cover(radius: float) -> Node2D:
    var nearest: Node2D = null
    var best_dist: float = radius
    var best_weight: float = -1.0
    for cover in get_tree().get_nodes_in_group("cover"):
        if not (cover is Node2D):
            continue
        var dist: float = cover.global_position.distance_to(global_position)
        if dist > radius:
            continue
        var weight: float = 1.0
        if "cover_type" in cover and cover.cover_type == "heavy":
            weight = 2.0
        if weight > best_weight or (weight == best_weight and dist < best_dist):
            best_weight = weight
            best_dist = dist
            nearest = cover
    return nearest

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
