extends Node

@export var night_enabled: bool = false
@export var fog_enabled: bool = false
@export var range_multiplier: float = 0.75
@export var accuracy_multiplier: float = 0.85
@export var suppression_resistance_multiplier: float = 0.9

func apply_to_unit(unit: Node) -> void:
    if night_enabled:
        if "weapon_range" in unit:
            unit.weapon_range *= range_multiplier
        if "accuracy" in unit:
            unit.accuracy *= accuracy_multiplier
    if fog_enabled:
        if "suppression_resistance" in unit:
            unit.suppression_resistance *= suppression_resistance_multiplier
