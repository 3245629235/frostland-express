extends Control
## 关卡之间的文字过渡和分支选择。

const StoryProgressRef = preload("res://scripts/story_progress.gd")
const AudioFxRef = preload("res://scripts/audio_fx.gd")

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var body_label: Label = $Center/Panel/Margin/VBox/Body
@onready var safe_button: Button = $Center/Panel/Margin/VBox/Safe
@onready var aggressive_button: Button = $Center/Panel/Margin/VBox/Aggressive
@onready var continue_button: Button = $Center/Panel/Margin/VBox/Continue
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back

var mode := "after_level_2"
var audio_fx: Node

func _ready() -> void:
	AudioManager.play_bgm("story")
	safe_button.pressed.connect(_on_safe_pressed)
	aggressive_button.pressed.connect(_on_aggressive_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)
	audio_fx = AudioFxRef.new()
	add_child(audio_fx)
	var progress := StoryProgressRef.load_progress()
	if int(progress.get("completed_level", 0)) >= 3:
		mode = "chapter_complete"
	_update_ui()

func _update_ui() -> void:
	if mode == "chapter_complete":
		title_label.text = "第一章完成"
		body_label.text = "列车抵达极光城。\n\n你们暂时甩开了追兵，但真正的旅程才刚刚开始。"
		safe_button.visible = false
		aggressive_button.visible = false
		continue_button.text = "返回剧情目录"
		return
	title_label.text = "关卡 2 完成"
	body_label.text = "雪狼群退入风雪。远处的山口出现火光，劫匪正在封锁铁路。\n\n选择下一步策略："
	safe_button.visible = true
	aggressive_button.visible = true
	continue_button.visible = false

func _choose_branch(branch: String) -> void:
	AudioManager.play_click()
	StoryProgressRef.set_branch(branch)
	StoryProgressRef.begin_level(3)
	StoryProgressRef.prepare_story_state()
	StoryProgressRef.ensure_story_train()
	GameState.save_state()
	audio_fx.play_alert()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_safe_pressed() -> void:
	_choose_branch("safe")

func _on_aggressive_pressed() -> void:
	_choose_branch("aggressive")

func _on_continue_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/story_hub.tscn")

func _on_back_pressed() -> void:
	AudioManager.play_back()
	get_tree().change_scene_to_file("res://scenes/story_hub.tscn")
