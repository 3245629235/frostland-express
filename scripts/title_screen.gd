extends Control

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

@onready var start_button: TextureButton = $StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
