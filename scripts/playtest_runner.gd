extends Node

class_name PlaytestRunner

const MAX_RUNTIME: float = 12.0

var game: Node = null
var selection_handler: Node = null
var elapsed: float = 0.0
var step_timer: float = 0.0
var step: int = 0
var issued_move: bool = false
var issued_attack: bool = false
var issued_hold: bool = false
var move_target: Vector2 = Vector2.ZERO
var attack_target: Vector2 = Vector2.ZERO

func _ready() -> void:
    game = get_tree().get_first_node_in_group("game")
    if game == null:
        _fail("Game node not found")
        return
    selection_handler = game.get_node_or_null("SelectionHandler")
    if selection_handler == null:
        _fail("SelectionHandler missing")
        return
    var player_units: Array = get_tree().get_nodes_in_group("player_units")
    var enemy_units: Array = get_tree().get_nodes_in_group("enemy_units")
    if player_units.is_empty():
        _fail("No player units spawned")
        return
    if enemy_units.is_empty():
        _fail("No enemy units spawned")
        return
    move_target = _offset_point(_get_centroid(player_units), Vector2(160.0, 0.0))
    attack_target = _get_centroid(enemy_units)
    Logger.log_event("Playtest: automation online")

func _process(delta: float) -> void:
    elapsed += delta
    step_timer += delta
    if elapsed > MAX_RUNTIME:
        _fail("Timeout waiting for playtest completion")
        return
    match step:
        0:
            _step_select()
        1:
            _step_move_order()
        2:
            _step_attack_move()
        3:
            _step_hold()
        4:
            _step_end_run()

func _step_select() -> void:
    var player_units: Array = get_tree().get_nodes_in_group("player_units")
    var select_count: int = min(3, player_units.size())
    selection_handler.select_units(player_units.slice(0, select_count))
    if selection_handler.selection.size() < 1:
        _fail("Selection did not update")
        return
    _advance_step("Selection OK")

func _step_move_order() -> void:
    if not issued_move:
        for unit in selection_handler.selection:
            unit.issue_move_order(move_target, false)
            unit.attack_move = false
            unit.hold = false
            unit.hold_mode = "off"
        issued_move = true
        Logger.log_event("Playtest: move order issued")
        step_timer = 0.0
        return
    if step_timer < 0.3:
        return
    for unit in selection_handler.selection:
        if unit.target_position.distance_to(move_target) > 1.0:
            _fail("Move order did not update target positions")
            return
    _advance_step("Move order acknowledged")

func _step_attack_move() -> void:
    if not issued_attack:
        if attack_target == Vector2.ZERO:
            attack_target = move_target + Vector2(120.0, 0.0)
        for unit in selection_handler.selection:
            unit.issue_move_order(attack_target, false)
            unit.attack_move = true
            unit.hold = false
            unit.hold_mode = "off"
        issued_attack = true
        Logger.log_event("Playtest: attack-move order issued")
        step_timer = 0.0
        return
    if step_timer < 0.3:
        return
    for unit in selection_handler.selection:
        if not unit.attack_move:
            _fail("Attack-move flag not set")
            return
    _advance_step("Attack-move acknowledged")

func _step_hold() -> void:
    if not issued_hold:
        for unit in selection_handler.selection:
            unit.hold = true
            unit.hold_mode = "defensive"
            unit.attack_move = false
        issued_hold = true
        Logger.log_event("Playtest: hold order issued")
        step_timer = 0.0
        return
    if step_timer < 0.2:
        return
    for unit in selection_handler.selection:
        if not unit.hold:
            _fail("Hold flag not set")
            return
    _advance_step("Hold acknowledged")

func _step_end_run() -> void:
    if step_timer < 0.4:
        return
    Logger.log_event("Playtest: ending match")
    if game.has_method("_end_run"):
        game._end_run()
    else:
        _fail("Game missing _end_run")

func _advance_step(message: String) -> void:
    Logger.log_event("Playtest: %s" % message)
    step += 1
    step_timer = 0.0

func _fail(reason: String) -> void:
    Logger.log_event("Playtest failed: %s" % reason)
    if get_tree() != null:
        get_tree().set_meta("playtest_failed", true)
        get_tree().set_meta("playtest_fail_reason", reason)
        get_tree().quit(1)

func _get_centroid(units: Array) -> Vector2:
    if units.is_empty():
        return Vector2.ZERO
    var sum: Vector2 = Vector2.ZERO
    for unit in units:
        sum += unit.global_position
    return sum / float(units.size())

func _offset_point(origin: Vector2, offset: Vector2) -> Vector2:
    return origin + offset
