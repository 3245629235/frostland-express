extends Control
## 通用胜利结算页，为 Day 5 剧情模式复用。

const StoryProgressRef = preload("res://scripts/story_progress.gd")

@onready var summary_label: Label = $Center/Panel/Margin/VBox/Summary
@onready var back_button: Button = $Center/Panel/Margin/VBox/BackButton

func _ready() -> void:
	AudioManager.play_bgm("victory")
	back_button.pressed.connect(_on_back_pressed)
	var result: Dictionary = GameState.settlement_result
	summary_label.text = "%s\n累计里程：%.1f km\n幸存者：%d/%d\n%s" % [
		str(result.get("reason_label", "任务完成")),
		float(result.get("total_distance_km", 0.0)),
		int(result.get("survivors", 0)),
		int(result.get("crew_count", 0)),
		"分支：主动追击" if str(result.get("branch", "")) == "aggressive" else "分支：保守防守",
	]

func _on_back_pressed() -> void:
	AudioManager.play_click()
	if str(GameState.settlement_result.get("mode", "survival")) == "story":
		GameState.settlement_active = false
		GameState.game_mode = "story"
		GameState.save_state()
		get_tree().change_scene_to_file("res://scenes/story_hub.tscn")
		return
	GameState.full_reset()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
