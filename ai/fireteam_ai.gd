extends Node

class_name FireteamAI

var fireteam_id: int = -1
var units: Array = []
var current_tactic: String = "idle"
var pending_tactic: String = ""
var tactic_timer: float = 0.0
var comms_delay: float = 0.4
var comms_timer: float = 0.0
var cooldowns: Dictionary = {}
var reserve_units: Array = []
var flank_units: Array = []
var screen_units: Array = []
var last_update_time: float = 0.0

const TACTIC_DURATIONS := {
    "base_of_fire": 6.0,
    "flank_subgroup": 7.0,
    "screen": 7.0,
    "peel_back": 4.0,
    "reserve": 8.0
}

func _ready() -> void:
    add_to_group("ai_fireteams")

func setup(id: int, team_units: Array) -> void:
    fireteam_id = id
    units = team_units

func _process(delta: float) -> void:
    if get_tree().paused:
        return
    _tick(delta)

func _tick(delta: float) -> void:
    tactic_timer += delta
    _advance_cooldowns(delta)
    if pending_tactic != "":
        comms_timer += delta
        if comms_timer >= comms_delay:
            current_tactic = pending_tactic
            pending_tactic = ""
            comms_timer = 0.0
            tactic_timer = 0.0
            if current_tactic != "idle":
                cooldowns[current_tactic] = TACTIC_DURATIONS.get(current_tactic, 6.0)
            _log("Fireteam %d tactic -> %s" % [fireteam_id, current_tactic])
            _act(current_tactic)
        return
    if not _should_update():
        return
    var sense := _sense()
    var next_tactic := _decide(sense)
    if _should_switch(next_tactic, sense):
        pending_tactic = next_tactic
        comms_timer = 0.0
    else:
        _act(current_tactic)

func _sense() -> Dictionary:
    var live_units := _get_live_units()
    units = live_units
    var player_units := get_tree().get_nodes_in_group("player_units")
    var centroid := _get_centroid(units)
    var nearest_enemy := _get_nearest_enemy(centroid, player_units)
    var avg_fear := _get_average_fear(units)
    var avg_hp := _get_average_hp_ratio(units)
    var avg_suppression := _get_average_suppression(units)
    var losing := avg_hp < 0.45 or avg_fear > 0.6 or avg_suppression > 55.0
    return {
        "units": units,
        "centroid": centroid,
        "nearest_enemy": nearest_enemy,
        "enemy_count": player_units.size(),
        "avg_fear": avg_fear,
        "avg_hp": avg_hp,
        "avg_suppression": avg_suppression,
        "losing": losing
    }

func _decide(sense: Dictionary) -> String:
    if sense["nearest_enemy"] == null:
        return "idle"
    var unit_count := units.size()
    var scores := {
        "base_of_fire": 0.6,
        "flank_subgroup": 0.2,
        "screen": 0.15,
        "peel_back": 0.1,
        "reserve": 0.1
    }
    if sense["losing"]:
        scores["peel_back"] = 1.2
    if unit_count >= 3:
        scores["flank_subgroup"] += 0.25
    if unit_count >= 4:
        scores["screen"] += 0.2
        scores["reserve"] += 0.25
    for key in scores.keys():
        if cooldowns.has(key) and cooldowns[key] > 0.0:
            scores[key] = -1.0
    var best := "base_of_fire"
    var best_score := -1.0
    for key in scores.keys():
        var score := scores[key] + randf() * 0.05
        if score > best_score:
            best_score = score
            best = key
    return best

func _should_switch(next_tactic: String, sense: Dictionary) -> bool:
    if current_tactic == "idle":
        return true
    if next_tactic != current_tactic and sense["losing"] and current_tactic != "peel_back":
        return true
    var duration := TACTIC_DURATIONS.get(current_tactic, 6.0)
    if tactic_timer >= duration:
        return true
    return false

func _act(tactic: String) -> void:
    if tactic == "idle":
        return
    match tactic:
        "base_of_fire":
            _act_base_of_fire()
        "flank_subgroup":
            _act_flank_subgroup()
        "screen":
            _act_screen()
        "peel_back":
            _act_peel_back()
        "reserve":
            _act_reserve()

func _act_base_of_fire() -> void:
    for unit in units:
        unit.hold = true
        unit.hold_mode = "aggressive"
        unit.attack_move = true

func _act_flank_subgroup() -> void:
    if flank_units.is_empty():
        flank_units = _pick_subset(units, max(1, int(units.size() / 3.0)))
    var target := _get_enemy_position()
    if target == null:
        return
    var direction := _side_direction(target)
    for unit in flank_units:
        unit.hold = false
        unit.hold_mode = "off"
        unit.attack_move = true
        unit.issue_move_order(target + direction * 160.0, false)

func _act_screen() -> void:
    if screen_units.is_empty():
        screen_units = _pick_subset(units, 1)
    var target := _get_enemy_position()
    if target == null:
        return
    var direction := _side_direction(target)
    for unit in screen_units:
        unit.hold = false
        unit.hold_mode = "aggressive"
        unit.attack_move = true
        unit.issue_move_order(target + direction * 220.0, false)

func _act_peel_back() -> void:
    var target := _get_enemy_position()
    if target == null:
        return
    for unit in units:
        var dir := (unit.global_position - target).normalized()
        unit.hold = false
        unit.hold_mode = "off"
        unit.attack_move = false
        unit.issue_move_order(unit.global_position + dir * 180.0, false)

func _act_reserve() -> void:
    if reserve_units.is_empty():
        reserve_units = _pick_subset(units, max(1, int(units.size() / 4.0)))
    var target := _get_enemy_position()
    if target == null:
        return
    var away := _side_direction(target) * -1.0
    for unit in units:
        if reserve_units.has(unit):
            unit.hold = true
            unit.hold_mode = "defensive"
            unit.attack_move = false
            unit.target_position = unit.global_position + away * 120.0
        else:
            unit.hold = true
            unit.hold_mode = "aggressive"
            unit.attack_move = true

func _pick_subset(pool: Array, count: int) -> Array:
    var copy := pool.duplicate()
    copy.shuffle()
    return copy.slice(0, min(count, copy.size()))

func _get_enemy_position() -> Vector2:
    var players := get_tree().get_nodes_in_group("player_units")
    if players.is_empty():
        return Vector2.ZERO
    var centroid := _get_centroid(players)
    return centroid

func _side_direction(target: Vector2) -> Vector2:
    var centroid := _get_centroid(units)
    var to_enemy := (target - centroid).normalized()
    var side := Vector2(-to_enemy.y, to_enemy.x)
    if fireteam_id % 2 == 0:
        side = -side
    return side

func _get_live_units() -> Array:
    var live := []
    for unit in units:
        if is_instance_valid(unit):
            live.append(unit)
    return live

func _get_centroid(list: Array) -> Vector2:
    if list.is_empty():
        return Vector2.ZERO
    var sum := Vector2.ZERO
    for unit in list:
        sum += unit.global_position
    return sum / float(list.size())

func _get_nearest_enemy(origin: Vector2, players: Array) -> Unit:
    var nearest: Unit = null
    var min_dist := INF
    for player in players:
        var d := player.global_position.distance_to(origin)
        if d < min_dist:
            min_dist = d
            nearest = player
    return nearest

func _get_average_fear(list: Array) -> float:
    if list.is_empty():
        return 0.0
    var total := 0.0
    for unit in list:
        if "fear" in unit:
            total += unit.fear
    return total / float(list.size())

func _get_average_hp_ratio(list: Array) -> float:
    if list.is_empty():
        return 1.0
    var total := 0.0
    for unit in list:
        total += unit.hp / max(unit.max_hp, 1)
    return total / float(list.size())

func _get_average_suppression(list: Array) -> float:
    if list.is_empty():
        return 0.0
    var total := 0.0
    for unit in list:
        total += unit.suppression
    return total / float(list.size())

func _advance_cooldowns(delta: float) -> void:
    for key in cooldowns.keys():
        cooldowns[key] = max(0.0, cooldowns[key] - delta)

func _should_update() -> bool:
    var game := get_tree().get_first_node_in_group("game")
    if game == null:
        return true
    var camera := game.get_node_or_null("Camera2D")
    if camera == null:
        return true
    var centroid := _get_centroid(units)
    var dist := centroid.distance_to(camera.global_position)
    var interval := 0.2
    if dist > 900.0:
        interval = 0.7
    elif dist > 600.0:
        interval = 0.45
    var now := Time.get_ticks_msec() / 1000.0
    if now - last_update_time < interval:
        return false
    last_update_time = now
    return true

func _log(message: String) -> void:
    Logger.log_event(message)
