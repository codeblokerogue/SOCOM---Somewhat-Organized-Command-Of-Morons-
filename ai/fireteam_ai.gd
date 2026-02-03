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
var commander_intent: Dictionary = {"goal": "hold", "confidence": 0.5}
var last_evaluation: Dictionary = {}

const TACTIC_DURATIONS := {
    "base_of_fire": 6.0,
    "flank_subgroup": 7.0,
    "screen": 7.0,
    "peel_back": 4.0,
    "reserve": 8.0,
    "probe_and_pull": 6.0,
    "recon_by_fire": 6.0,
    "fix_and_shift": 7.0
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
            _record_timeline_event("Fireteam tactic: %s" % current_tactic)
            Logger.log_telemetry("ai_tactic_selected", {
                "fireteam_id": fireteam_id,
                "tactic": current_tactic,
                "unit_count": units.size()
            })
            _act(current_tactic)
            _evaluate(_sense())
        return
    if not _should_update():
        return
    var sense: Dictionary = _sense()
    var next_tactic: String = _decide(sense)
    if _should_switch(next_tactic, sense):
        pending_tactic = next_tactic
        comms_timer = 0.0
        Logger.log_telemetry("ai_tactic_pending", {
            "fireteam_id": fireteam_id,
            "tactic": next_tactic,
            "reason": "switch",
            "avg_fear": sense.get("avg_fear", 0.0),
            "avg_hp": sense.get("avg_hp", 1.0),
            "avg_suppression": sense.get("avg_suppression", 0.0)
        })
    else:
        _act(current_tactic)
    _evaluate(sense)

func _sense() -> Dictionary:
    var live_units: Array = _get_live_units()
    units = live_units
    var player_units: Array = get_tree().get_nodes_in_group("player_units")
    var centroid: Vector2 = _get_centroid(units)
    var nearest_enemy: Node = _get_nearest_enemy(centroid, player_units)
    var avg_fear: float = _get_average_fear(units)
    var avg_hp: float = _get_average_hp_ratio(units)
    var avg_suppression: float = _get_average_suppression(units)
    var losing: bool = avg_hp < 0.45 or avg_fear > 0.6 or avg_suppression > 55.0
    Logger.log_telemetry("ai_sense", {
        "fireteam_id": fireteam_id,
        "unit_count": units.size(),
        "enemy_count": player_units.size(),
        "avg_fear": avg_fear,
        "avg_hp": avg_hp,
        "avg_suppression": avg_suppression,
        "losing": losing
    })
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
    var unit_count: int = units.size()
    var scores: Dictionary = {
        "base_of_fire": 0.6,
        "flank_subgroup": 0.2,
        "screen": 0.15,
        "peel_back": 0.1,
        "reserve": 0.1,
        "probe_and_pull": 0.15,
        "recon_by_fire": 0.1,
        "fix_and_shift": 0.12
    }
    match commander_intent.get("goal", "hold"):
        "probe":
            scores["flank_subgroup"] += 0.35
            scores["screen"] += 0.1
        "fix":
            scores["base_of_fire"] += 0.3
        "disengage":
            scores["peel_back"] += 0.5
        _:
            scores["reserve"] += 0.1
    if sense["losing"]:
        scores["peel_back"] = 1.2
        scores["probe_and_pull"] -= 0.1
        scores["fix_and_shift"] -= 0.1
    if unit_count >= 3:
        scores["flank_subgroup"] += 0.25
        scores["probe_and_pull"] += 0.15
    if unit_count >= 4:
        scores["screen"] += 0.2
        scores["reserve"] += 0.25
        scores["fix_and_shift"] += 0.25
    for key in scores.keys():
        if cooldowns.has(key) and cooldowns[key] > 0.0:
            scores[key] = -1.0
    var best: String = "base_of_fire"
    var best_score: float = -1.0
    for key in scores.keys():
        var score: float = scores[key] + randf() * 0.05
        if score > best_score:
            best_score = score
            best = key
    Logger.log_telemetry("ai_decide", {
        "fireteam_id": fireteam_id,
        "intent": commander_intent.get("goal", "hold"),
        "scores": scores,
        "choice": best
    })
    return best

func _should_switch(next_tactic: String, sense: Dictionary) -> bool:
    if current_tactic == "idle":
        return true
    if next_tactic != current_tactic and sense["losing"] and current_tactic != "peel_back":
        return true
    var duration: float = TACTIC_DURATIONS.get(current_tactic, 6.0)
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
        "probe_and_pull":
            _act_probe_and_pull()
        "recon_by_fire":
            _act_recon_by_fire()
        "fix_and_shift":
            _act_fix_and_shift()

func _evaluate(sense: Dictionary) -> void:
    var new_goal: String = commander_intent.get("goal", "hold")
    if sense.get("losing", false):
        new_goal = "disengage"
    elif sense.get("avg_suppression", 0.0) > 40.0:
        new_goal = "fix"
    elif sense.get("avg_fear", 0.0) < 0.4 and sense.get("avg_hp", 1.0) > 0.7:
        new_goal = "probe"
    else:
        new_goal = "hold"
    if new_goal != commander_intent.get("goal", "hold"):
        commander_intent["goal"] = new_goal
        Logger.log_telemetry("ai_intent_changed", {
            "fireteam_id": fireteam_id,
            "intent": new_goal
        })
        _log("Fireteam %d intent -> %s" % [fireteam_id, new_goal])
        _record_timeline_event("Fireteam intent: %s" % new_goal)
    var duration: float = TACTIC_DURATIONS.get(current_tactic, 6.0)
    var success: bool = not sense.get("losing", false)
    if tactic_timer >= duration:
        success = success and sense.get("avg_hp", 1.0) > 0.5
    var evaluation: Dictionary = {
        "fireteam_id": fireteam_id,
        "tactic": current_tactic,
        "intent": commander_intent.get("goal", "hold"),
        "success": success,
        "avg_fear": sense.get("avg_fear", 0.0),
        "avg_hp": sense.get("avg_hp", 1.0),
        "avg_suppression": sense.get("avg_suppression", 0.0)
    }
    last_evaluation = evaluation
    Logger.log_telemetry("ai_evaluate", evaluation)

func _evaluate(sense: Dictionary) -> void:
    var new_goal: String = commander_intent.get("goal", "hold")
    if sense.get("losing", false):
        new_goal = "disengage"
    elif sense.get("avg_suppression", 0.0) > 40.0:
        new_goal = "fix"
    elif sense.get("avg_fear", 0.0) < 0.4 and sense.get("avg_hp", 1.0) > 0.7:
        new_goal = "probe"
    else:
        new_goal = "hold"
    if new_goal != commander_intent.get("goal", "hold"):
        commander_intent["goal"] = new_goal
        Logger.log_telemetry("ai_intent_changed", {
            "fireteam_id": fireteam_id,
            "intent": new_goal
        })
        _log("Fireteam %d intent -> %s" % [fireteam_id, new_goal])
        _record_timeline_event("Fireteam intent: %s" % new_goal)
    var duration: float = TACTIC_DURATIONS.get(current_tactic, 6.0)
    var success: bool = not sense.get("losing", false)
    if tactic_timer >= duration:
        success = success and sense.get("avg_hp", 1.0) > 0.5
    var evaluation: Dictionary = {
        "fireteam_id": fireteam_id,
        "tactic": current_tactic,
        "intent": commander_intent.get("goal", "hold"),
        "success": success,
        "avg_fear": sense.get("avg_fear", 0.0),
        "avg_hp": sense.get("avg_hp", 1.0),
        "avg_suppression": sense.get("avg_suppression", 0.0)
    }
    last_evaluation = evaluation
    Logger.log_telemetry("ai_evaluate", evaluation)

func _act_base_of_fire() -> void:
    for unit in units:
        unit.hold = true
        unit.hold_mode = "aggressive"
        unit.attack_move = true

func _act_flank_subgroup() -> void:
    if flank_units.is_empty():
        flank_units = _pick_subset(units, max(1, int(units.size() / 3.0)))
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    var direction: Vector2 = _side_direction(target)
    for unit in flank_units:
        unit.hold = false
        unit.hold_mode = "off"
        unit.attack_move = true
        unit.issue_move_order(target + direction * 160.0, false)

func _act_screen() -> void:
    if screen_units.is_empty():
        screen_units = _pick_subset(units, 1)
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    var direction: Vector2 = _side_direction(target)
    for unit in screen_units:
        unit.hold = false
        unit.hold_mode = "aggressive"
        unit.attack_move = true
        unit.issue_move_order(target + direction * 220.0, false)

func _act_peel_back() -> void:
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    for unit in units:
        var dir: Vector2 = (unit.global_position - target).normalized()
        unit.hold = false
        unit.hold_mode = "off"
        unit.attack_move = false
        unit.issue_move_order(unit.global_position + dir * 180.0, false)

func _act_reserve() -> void:
    if reserve_units.is_empty():
        reserve_units = _pick_subset(units, max(1, int(units.size() / 4.0)))
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    var away: Vector2 = _side_direction(target) * -1.0
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

func _act_probe_and_pull() -> void:
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    var probe_units: Array = _pick_subset(units, max(1, int(units.size() / 3.0)))
    var direction: Vector2 = _side_direction(target)
    for unit in units:
        if probe_units.has(unit):
            unit.hold = false
            unit.hold_mode = "off"
            unit.attack_move = true
            unit.issue_move_order(target + direction * 120.0, false)
        else:
            unit.hold = true
            unit.hold_mode = "defensive"
            unit.attack_move = false

func _act_recon_by_fire() -> void:
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    for unit in units:
        unit.hold = true
        unit.hold_mode = "aggressive"
        unit.attack_move = true
        unit.target_position = unit.global_position

func _act_fix_and_shift() -> void:
    var target: Vector2 = _get_enemy_position()
    if target == null:
        return
    if flank_units.is_empty():
        flank_units = _pick_subset(units, max(1, int(units.size() / 2.0)))
    var direction: Vector2 = _side_direction(target)
    for unit in units:
        if flank_units.has(unit):
            unit.hold = false
            unit.hold_mode = "off"
            unit.attack_move = true
            unit.issue_move_order(target + direction * 180.0, false)
        else:
            unit.hold = true
            unit.hold_mode = "aggressive"
            unit.attack_move = true

func _pick_subset(pool: Array, count: int) -> Array:
    var copy: Array = pool.duplicate()
    copy.shuffle()
    return copy.slice(0, min(count, copy.size()))

func _get_enemy_position() -> Vector2:
    var players: Array = get_tree().get_nodes_in_group("player_units")
    if players.is_empty():
        return Vector2.ZERO
    var centroid: Vector2 = _get_centroid(players)
    return centroid

func _side_direction(target: Vector2) -> Vector2:
    var centroid: Vector2 = _get_centroid(units)
    var to_enemy: Vector2 = (target - centroid).normalized()
    var side: Vector2 = Vector2(-to_enemy.y, to_enemy.x)
    if fireteam_id % 2 == 0:
        side = -side
    return side

func _get_live_units() -> Array:
    var live: Array = []
    for unit in units:
        if is_instance_valid(unit):
            live.append(unit)
    return live

func _get_centroid(list: Array) -> Vector2:
    if list.is_empty():
        return Vector2.ZERO
    var sum: Vector2 = Vector2.ZERO
    for unit in list:
        sum += unit.global_position
    return sum / float(list.size())

func _get_nearest_enemy(origin: Vector2, players: Array) -> Node:
    var nearest: Node = null
    var min_dist: float = INF
    for player in players:
        var d: float = player.global_position.distance_to(origin)
        if d < min_dist:
            min_dist = d
            nearest = player
    return nearest

func _get_average_fear(list: Array) -> float:
    if list.is_empty():
        return 0.0
    var total: float = 0.0
    for unit in list:
        if "fear" in unit:
            total += unit.fear
    return total / float(list.size())

func _get_average_hp_ratio(list: Array) -> float:
    if list.is_empty():
        return 1.0
    var total: float = 0.0
    for unit in list:
        total += unit.hp / max(unit.max_hp, 1)
    return total / float(list.size())

func _get_average_suppression(list: Array) -> float:
    if list.is_empty():
        return 0.0
    var total: float = 0.0
    for unit in list:
        total += unit.suppression
    return total / float(list.size())

func _advance_cooldowns(delta: float) -> void:
    for key in cooldowns.keys():
        cooldowns[key] = max(0.0, cooldowns[key] - delta)

func _should_update() -> bool:
    var game: Node = get_tree().get_first_node_in_group("game")
    if game == null:
        return true
    var camera: Camera2D = game.get_node_or_null("Camera2D")
    if camera == null:
        return true
    var centroid: Vector2 = _get_centroid(units)
    var dist: float = centroid.distance_to(camera.global_position)
    var interval: float = 0.2
    if dist > 900.0:
        interval = 0.7
    elif dist > 600.0:
        interval = 0.45
    var now: float = Time.get_ticks_msec() / 1000.0
    if now - last_update_time < interval:
        return false
    last_update_time = now
    return true

func _log(message: String) -> void:
    Logger.log_event(message)

func _record_timeline_event(label: String) -> void:
    var game: Node = get_tree().get_first_node_in_group("game")
    if game != null and game.has_method("_record_timeline_event"):
        game._record_timeline_event(label, {"fireteam_id": fireteam_id})
