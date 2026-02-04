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

const TACTIC_CATALOGUE := {
    "base_of_fire": {
        "triggers": {"enemy_visible": true, "intent": ["hold", "fix"]},
        "requirements": {"min_units": 1},
        "act_plan": "_act_base_of_fire",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.2,
        "risk_bias": 0.2,
        "time_cost": 0.35,
        "cooldown": 6.0
    },
    "flank_subgroup": {
        "triggers": {"enemy_visible": true, "intent": ["probe", "hold"]},
        "requirements": {"min_units": 3},
        "act_plan": "_act_flank_subgroup",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.4,
        "risk_bias": 0.55,
        "time_cost": 0.7,
        "cooldown": 7.0
    },
    "screen": {
        "triggers": {"enemy_visible": true, "intent": ["probe", "hold"]},
        "requirements": {"min_units": 4},
        "act_plan": "_act_screen",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.3,
        "risk_bias": 0.45,
        "time_cost": 0.6,
        "cooldown": 7.0
    },
    "peel_back": {
        "triggers": {"enemy_visible": true, "intent": ["disengage"]},
        "requirements": {"min_units": 1},
        "act_plan": "_act_peel_back",
        "success_conditions": {"stabilized": true, "duration": true},
        "abort_conditions": {"not_losing": true},
        "gain_bias": 0.5,
        "risk_bias": 0.1,
        "time_cost": 0.25,
        "cooldown": 4.0
    },
    "reserve": {
        "triggers": {"enemy_visible": true, "intent": ["hold", "fix"]},
        "requirements": {"min_units": 4},
        "act_plan": "_act_reserve",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.25,
        "risk_bias": 0.2,
        "time_cost": 0.45,
        "cooldown": 8.0
    },
    "probe_and_pull": {
        "triggers": {"enemy_visible": true, "intent": ["probe"]},
        "requirements": {"min_units": 3},
        "act_plan": "_act_probe_and_pull",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.35,
        "risk_bias": 0.5,
        "time_cost": 0.55,
        "cooldown": 6.0
    },
    "recon_by_fire": {
        "triggers": {"enemy_visible": true, "intent": ["probe", "hold"]},
        "requirements": {"min_units": 2},
        "act_plan": "_act_recon_by_fire",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.25,
        "risk_bias": 0.3,
        "time_cost": 0.4,
        "cooldown": 6.0
    },
    "fix_and_shift": {
        "triggers": {"enemy_visible": true, "intent": ["fix"]},
        "requirements": {"min_units": 4},
        "act_plan": "_act_fix_and_shift",
        "success_conditions": {"not_losing": true, "min_avg_hp": 0.5, "min_avg_hp_after_duration": true},
        "abort_conditions": {"losing": true},
        "gain_bias": 0.45,
        "risk_bias": 0.5,
        "time_cost": 0.65,
        "cooldown": 7.0
    }
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
                cooldowns[current_tactic] = _get_tactic_cooldown(current_tactic)
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
    var max_suppression: float = _get_max_suppression(units)
    var heavy_suppression: bool = avg_suppression > 65.0 or max_suppression > 80.0
    var heavy_losses: bool = avg_hp < 0.35 or units.size() <= 2
    var enemy_flank: bool = _detect_enemy_flank(centroid, player_units)
    var losing: bool = avg_hp < 0.45 or avg_fear > 0.6 or avg_suppression > 55.0
    Logger.log_telemetry("ai_sense", {
        "fireteam_id": fireteam_id,
        "unit_count": units.size(),
        "enemy_count": player_units.size(),
        "avg_fear": avg_fear,
        "avg_hp": avg_hp,
        "avg_suppression": avg_suppression,
        "max_suppression": max_suppression,
        "heavy_suppression": heavy_suppression,
        "heavy_losses": heavy_losses,
        "enemy_flank": enemy_flank,
        "losing": losing
    })
    if enemy_flank:
        Logger.log_telemetry("ai_enemy_flank_detected", {
            "fireteam_id": fireteam_id,
            "enemy_count": player_units.size(),
            "centroid": centroid
        })
    return {
        "units": units,
        "centroid": centroid,
        "nearest_enemy": nearest_enemy,
        "enemy_count": player_units.size(),
        "avg_fear": avg_fear,
        "avg_hp": avg_hp,
        "avg_suppression": avg_suppression,
        "max_suppression": max_suppression,
        "heavy_suppression": heavy_suppression,
        "heavy_losses": heavy_losses,
        "enemy_flank": enemy_flank,
        "losing": losing
    }

func _decide(sense: Dictionary) -> String:
    if sense["nearest_enemy"] == null:
        return "idle"
    var scores: Dictionary = {
        "base_of_fire": 0.0,
        "flank_subgroup": 0.0,
        "screen": 0.0,
        "peel_back": 0.0,
        "reserve": 0.0,
        "probe_and_pull": 0.0,
        "recon_by_fire": 0.0,
        "fix_and_shift": 0.0
    }
    var scoring_breakdown: Dictionary = {}
    for key in scores.keys():
        if not _tactic_is_available(key, sense):
            scores[key] = -1.0
            continue
        if cooldowns.has(key) and cooldowns[key] > 0.0:
            scores[key] = -1.0
            continue
        var score_data: Dictionary = _score_tactic(key, sense)
        var final_score: float = score_data.get("final", 0.0)
        scores[key] = final_score
        scoring_breakdown[key] = score_data
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
        "score_breakdown": scoring_breakdown,
        "choice": best
    })
    return best

func _score_tactic(tactic: String, sense: Dictionary) -> Dictionary:
    var data: Dictionary = _get_tactic_data(tactic)
    var intent: String = commander_intent.get("goal", "hold")
    var triggers: Dictionary = data.get("triggers", {})
    var requirements: Dictionary = data.get("requirements", {})
    var min_units: int = requirements.get("min_units", 1)
    var unit_count: int = units.size()
    var gain: float = data.get("gain_bias", 0.2)
    var risk: float = data.get("risk_bias", 0.2)
    var time_cost: float = data.get("time_cost", 0.5)
    if triggers.has("intent"):
        var intent_trigger = triggers.get("intent")
        if intent_trigger is Array and intent_trigger.has(intent):
            gain += 0.25
        elif intent_trigger is String and intent_trigger == intent:
            gain += 0.25
    if intent == "disengage" and tactic == "peel_back":
        gain += 0.45
    if sense.get("losing", false) and tactic == "peel_back":
        gain += 0.3
    if sense.get("enemy_flank", false) and (tactic == "screen" or tactic == "base_of_fire"):
        gain += 0.2
    risk += clamp(sense.get("avg_suppression", 0.0) / 100.0, 0.0, 1.0) * 0.4
    risk += clamp(1.0 - sense.get("avg_hp", 1.0), 0.0, 1.0) * 0.3
    if sense.get("heavy_suppression", false):
        risk += 0.25
    if sense.get("heavy_losses", false):
        risk += 0.25
    if sense.get("enemy_flank", false):
        risk += 0.2
    if tactic == "peel_back":
        risk -= 0.2
    if tactic == "reserve":
        risk -= 0.1
    var feasibility: float = clamp(float(unit_count) / float(max(min_units, 1)), 0.0, 1.0)
    if unit_count < min_units:
        feasibility *= 0.2
    var urgency: float = 0.0
    if sense.get("losing", false) or sense.get("heavy_suppression", false) or sense.get("heavy_losses", false):
        urgency = 0.2
    var time_score: float = clamp(1.0 - time_cost - (time_cost * urgency), 0.0, 1.0)
    var final_score: float = gain + feasibility + time_score - risk
    return {
        "gain": gain,
        "risk": risk,
        "feasibility": feasibility,
        "time": time_score,
        "final": final_score
    }

func _should_switch(next_tactic: String, sense: Dictionary) -> bool:
    if current_tactic == "idle":
        return true
    if sense.get("heavy_suppression", false) or sense.get("heavy_losses", false) or sense.get("enemy_flank", false):
        Logger.log_telemetry("ai_tactic_abort", {
            "fireteam_id": fireteam_id,
            "tactic": current_tactic,
            "reason": "pressure",
            "heavy_suppression": sense.get("heavy_suppression", false),
            "heavy_losses": sense.get("heavy_losses", false),
            "enemy_flank": sense.get("enemy_flank", false)
        })
        return true
    if _tactic_should_abort(current_tactic, sense):
        return true
    var duration: float = _get_tactic_cooldown(current_tactic)
    if tactic_timer >= duration:
        return true
    return false

func _act(tactic: String) -> void:
    if tactic == "idle":
        return
    var plan: String = _get_tactic_data(tactic).get("act_plan", "")
    if plan != "" and has_method(plan):
        call(plan)

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
    var success: bool = _tactic_success(current_tactic, sense)
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

func _get_tactic_data(tactic: String) -> Dictionary:
    return TACTIC_CATALOGUE.get(tactic, {})

func _get_tactic_cooldown(tactic: String) -> float:
    return _get_tactic_data(tactic).get("cooldown", 6.0)

func _tactic_is_available(tactic: String, sense: Dictionary) -> bool:
    return _tactic_meets_requirements(tactic, sense) and _tactic_is_triggered(tactic, sense)

func _tactic_meets_requirements(tactic: String, sense: Dictionary) -> bool:
    var requirements: Dictionary = _get_tactic_data(tactic).get("requirements", {})
    var min_units: int = requirements.get("min_units", 1)
    if units.size() < min_units:
        return false
    if requirements.get("enemy_visible", false) and sense.get("nearest_enemy") == null:
        return false
    return true

func _tactic_is_triggered(tactic: String, sense: Dictionary) -> bool:
    var triggers: Dictionary = _get_tactic_data(tactic).get("triggers", {})
    if triggers.get("enemy_visible", false) and sense.get("nearest_enemy") == null:
        return false
    if triggers.has("intent"):
        var intent_trigger = triggers.get("intent")
        var current_intent: String = commander_intent.get("goal", "hold")
        if intent_trigger is Array and not intent_trigger.has(current_intent):
            return false
        if intent_trigger is String and intent_trigger != current_intent:
            return false
    return true

func _tactic_success(tactic: String, sense: Dictionary) -> bool:
    var success_conditions: Dictionary = _get_tactic_data(tactic).get("success_conditions", {})
    var success: bool = true
    if success_conditions.get("not_losing", false):
        success = success and not sense.get("losing", false)
    if success_conditions.get("stabilized", false):
        success = success and not sense.get("losing", false)
    if success_conditions.has("min_avg_hp"):
        if success_conditions.get("min_avg_hp_after_duration", false):
            if tactic_timer >= _get_tactic_cooldown(tactic):
                success = success and sense.get("avg_hp", 1.0) >= success_conditions.get("min_avg_hp", 0.0)
        else:
            success = success and sense.get("avg_hp", 1.0) >= success_conditions.get("min_avg_hp", 0.0)
    if success_conditions.get("duration", false):
        success = success and tactic_timer >= _get_tactic_cooldown(tactic)
    return success

func _tactic_should_abort(tactic: String, sense: Dictionary) -> bool:
    var abort_conditions: Dictionary = _get_tactic_data(tactic).get("abort_conditions", {})
    if abort_conditions.get("losing", false) and sense.get("losing", false):
        return true
    if abort_conditions.get("not_losing", false) and not sense.get("losing", false):
        return true
    return false

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

func _get_max_suppression(list: Array) -> float:
    var max_value: float = 0.0
    for unit in list:
        max_value = max(max_value, unit.suppression)
    return max_value

func _detect_enemy_flank(centroid: Vector2, enemies: Array) -> bool:
    if enemies.size() < 2:
        return false
    var nearest: Node = _get_nearest_enemy(centroid, enemies)
    if nearest == null:
        return false
    var forward: Vector2 = (nearest.global_position - centroid).normalized()
    var flank_hits: int = 0
    for enemy in enemies:
        var to_enemy: Vector2 = enemy.global_position - centroid
        if to_enemy.length() > 280.0:
            continue
        var angle: float = abs(forward.angle_to(to_enemy.normalized()))
        if angle > 1.1:
            flank_hits += 1
    return flank_hits >= 1

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

func receive_help_request(team_id: int, unit_id: int, reason: String, metrics: Dictionary) -> void:
    if team_id != fireteam_id:
        return
    Logger.log_telemetry("ai_help_received", {
        "fireteam_id": fireteam_id,
        "unit_id": unit_id,
        "reason": reason,
        "metrics": metrics
    })
    _log("Fireteam %d help request from Unit %d (%s)" % [fireteam_id, unit_id, reason])
    _record_timeline_event("Help request: %s" % reason)
    if reason == "panic" and commander_intent.get("goal", "hold") != "disengage":
        commander_intent["goal"] = "disengage"
    elif reason == "suppressed" and commander_intent.get("goal", "hold") == "hold":
        commander_intent["goal"] = "fix"
