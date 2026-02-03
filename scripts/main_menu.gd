extends Control

##
# Main menu script
# Handles start and quit button presses and transitions to the game scene.

@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button  = $VBoxContainer/QuitButton

func _ready() -> void:
    start_button.pressed.connect(_on_start_pressed)
    quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
    # Start the match by loading the Game scene
    get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_quit_pressed() -> void:
    # Exit the application
    get_tree().quit()
