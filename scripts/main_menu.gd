extends Control

##
# Main menu script
# Handles start and quit button presses and transitions to the game scene.

@onready var start_button = $VBoxContainer/StartButton
@onready var start_map2_button = $VBoxContainer/StartMap2Button
@onready var roster_button = $VBoxContainer/RosterButton
@onready var quit_button  = $VBoxContainer/QuitButton
@onready var debug_overlay = $DebugOverlay

func _ready() -> void:
    start_button.pressed.connect(_on_start_pressed)
    start_map2_button.pressed.connect(_on_start_map2_pressed)
    roster_button.pressed.connect(_on_roster_pressed)
    quit_button.pressed.connect(_on_quit_pressed)
    debug_overlay.set_state("Menu")

func _on_start_pressed() -> void:
    # Start the match by loading the Game scene
    Logger.log_event("State transition: Menu -> Game")
    get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_start_map2_pressed() -> void:
    Logger.log_event("State transition: Menu -> GameMap2")
    get_tree().change_scene_to_file("res://scenes/GameMap2.tscn")

func _on_roster_pressed() -> void:
    Logger.log_event("State transition: Menu -> Roster")
    get_tree().change_scene_to_file("res://scenes/Roster.tscn")

func _on_quit_pressed() -> void:
    # Exit the application
    get_tree().quit()
