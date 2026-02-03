extends Control

##
# After‑action summary scene.
# For now this is a placeholder; clicking the return button goes back to the main menu.

@onready var return_button = $ReturnButton

func _ready() -> void:
    return_button.pressed.connect(_on_return_pressed)

    # TODO: populate summary with match statistics once those are available.

func _on_return_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
