extends Node2D

@export var radius: float = 120.0
@export var color: Color = Color(0.2, 0.8, 0.2, 0.25)

func _draw() -> void:
    draw_circle(Vector2.ZERO, radius, color)
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.2, 0.9, 0.2, 0.6), 2.0)
