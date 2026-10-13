extends Control
## 生存模式失败结算页。

const StoryProgressRef = preload("res://scripts/story_progress.gd")

@onready var reason_label: Label = $Center/Panel/Margin/VBox/Reason
@onready var stats_label: Label = $Center/Panel/Margin/VBox/Stats
@onready var restart_button: Button = $Center/Panel/Margin/VBox/RestartButton
@onready var title_button: Button = $Center/Panel/Margin/VBox/TitleButton

func _ready() -> void:
	AudioManager.play_bgm("defeat")
	restart_button.pressed.connect(_on_restart_pressed)
	title_button.pressed.connect(_on_title_pressed)
	var result: Dictionary = GameState.settlement_result
	var is_story := str(result.get("mode", "survival")) == "story"
	reason_label.text = ("剧情失败：%s" if is_story else "失败原因：%s") % str(result.get("reason_label", "未知原因"))
	stats_label.text = "累计里程：%.1f km\n用时：%.1f 秒\n抛锚次数：%d\n幸存者：%d/%d\n列车 HP：%.0f" % [
		float(result.get("total_distance_km", 0.0)),
		float(result.get("travel_time", 0.0)),
		int(result.get("breakdown_count", 0)),
		int(result.get("survivors", 0)),
		int(result.get("crew_count", 0)),
		float(result.get("train_health", 0.0)),
	]

func _on_restart_pressed() -> void:
	AudioManager.play_click()
	if str(GameState.settlement_result.get("mode", "survival")) == "story":
		var level := clampi(int(GameState.settlement_result.get("level", 2)), 2, 3)
		StoryProgressRef.begin_level(level)
		StoryProgressRef.prepare_story_state()
		StoryProgressRef.ensure_story_train()
		GameState.settlement_active = false
		GameState.save_state()
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	GameState.full_reset()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_title_pressed() -> void:
	AudioManager.play_back()
	if str(GameState.settlement_result.get("mode", "survival")) == "story":
		GameState.settlement_active = false
		GameState.game_mode = "story"
		get_tree().change_scene_to_file("res://scenes/story_hub.tscn")
		return
	GameState.full_reset()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
