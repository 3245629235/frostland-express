extends Control
## 第一章剧情目录。

const StoryProgressRef = preload("res://scripts/story_progress.gd")
const AudioFxRef = preload("res://scripts/audio_fx.gd")

@onready var progress_label: Label = $Center/Panel/Margin/VBox/Progress
@onready var level1_button: Button = $Center/Panel/Margin/VBox/Level1
@onready var level2_button: Button = $Center/Panel/Margin/VBox/Level2
@onready var level3_button: Button = $Center/Panel/Margin/VBox/Level3
@onready var reset_button: Button = $Center/Panel/Margin/VBox/Reset
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back

func _ready() -> void:
	AudioManager.play_bgm("story")
	level1_button.pressed.connect(_on_level1_pressed)
	level2_button.pressed.connect(_on_level2_pressed)
	level3_button.pressed.connect(_on_level3_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	var audio := AudioFxRef.new()
	add_child(audio)
	audio.play_alert()
	_update_ui()

func _update_ui() -> void:
	var progress := StoryProgressRef.load_progress()
	var unlocked := int(progress.get("unlocked_level", 1))
	var completed := int(progress.get("completed_level", 0))
	var branch := str(progress.get("branch", ""))
	var branch_text := "未选择"
	if branch == "safe":
		branch_text = "保守防守"
	elif branch == "aggressive":
		branch_text = "主动追击"
	progress_label.text = "已解锁：第 %d 关\n已完成：第 %d 关\n上次分支：%s" % [unlocked, completed, branch_text]
	level1_button.text = "关卡 1：出发（教学）"
	level2_button.text = "关卡 2：雪狼袭击" + ("（已完成）" if completed >= 2 else "")
	level3_button.text = "关卡 3：劫匪关卡" + ("（已完成）" if completed >= 3 else "")
	level2_button.disabled = unlocked < 2
	level3_button.disabled = unlocked < 3

func _start_story_state(level: int) -> void:
	StoryProgressRef.begin_level(level)
	StoryProgressRef.prepare_story_state()
	StoryProgressRef.ensure_story_train()
	GameState.game_mode = "story"
	GameState.save_state()

func _on_level1_pressed() -> void:
	AudioManager.play_click()
	_start_story_state(1)
	get_tree().change_scene_to_file("res://scenes/story_intro.tscn")

func _on_level2_pressed() -> void:
	_start_story_state(2)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_level3_pressed() -> void:
	_start_story_state(3)
	var progress := StoryProgressRef.load_progress()
	if str(progress.get("branch", "")) not in ["safe", "aggressive"]:
		StoryProgressRef.set_branch("safe")
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_reset_pressed() -> void:
	StoryProgressRef.reset_progress()
	_update_ui()

func _on_back_pressed() -> void:
	GameState.game_mode = "survival"
	GameState.settlement_active = false
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
