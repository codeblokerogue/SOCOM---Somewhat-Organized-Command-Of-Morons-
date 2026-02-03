extends StaticBody2D

class_name Cover

@export var cover_type: String = "light"
@export var cover_radius: float = 32.0
@export var size: Vector2 = Vector2(60, 20)

func _ready() -> void:
    add_to_group("cover")
    add_to_group("los_blockers")
    var shape_node := get_node_or_null("CollisionShape2D")
    if shape_node != null and shape_node.shape is RectangleShape2D:
        shape_node.shape.size = size
    queue_redraw()

func _draw() -> void:
    var colour := Color(0.5, 0.7, 0.5)
    if cover_type == "heavy":
        colour = Color(0.4, 0.4, 0.7)
    draw_rect(Rect2(-size * 0.5, size), colour, true)
