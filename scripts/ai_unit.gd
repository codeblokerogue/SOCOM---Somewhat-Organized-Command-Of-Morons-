extends "res://scripts/unit.gd"

##
# Basic AI behaviour for enemy units.  In the MVP this AI simply seeks the nearest
# player unit and uses attack‑move behaviour to engage.  The full game will
# implement Sense→Decide→Act→Evaluate with tactic cards and self‑preservation.

func _physics_process(delta: float) -> void:
    # Call base class to handle movement and shooting
    ._physics_process(delta)
    # Always attack‑move
    attack_move = true
    # Periodically update target position towards nearest player
    if get_tree().paused:
        return
    if (target_position - global_position).length() < 8.0:
        var nearest: Unit = null
        var min_dist: float = INF
        for player in get_tree().get_nodes_in_group("player_units"):
            var d := (player.global_position - global_position).length()
            if d < min_dist:
                nearest = player
                min_dist = d
        if nearest != null:
            target_position = nearest.global_position
