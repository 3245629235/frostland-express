extends Control
## 第一章开场文字剧情。

const StoryProgressRef = preload("res://scripts/story_progress.gd")

@onready var body_label: Label = $Center/Panel/Margin/VBox/Body
@onready var next_button: Button = $Center/Panel/Margin/VBox/Next

var pages := [
	"极寒纪元第 1 天\n\n北方的风雪封锁了旧铁路。列车长，你必须让这列车动起来。",
	"锅炉已经点燃，车厢里还有最后一批幸存者。\n先熟悉列车内部，再去面对前方的威胁。",
	"教学目标\n移动一名队员，完成一次车内交互，然后按下“加速”。\n完成后返回本页继续剧情。",
]
var page_index := 0

func _ready() -> void:
	AudioManager.play_bgm("story")
	next_button.pressed.connect(_on_next_pressed)
	_update_page()

func _update_page() -> void:
	body_label.text = pages[page_index]
	next_button.text = "进入列车教学" if page_index == pages.size() - 1 else "继续"

func _on_next_pressed() -> void:
	AudioManager.play_click()
	if page_index < pages.size() - 1:
		page_index += 1
		_update_page()
		return
	StoryProgressRef.begin_level(1)
	StoryProgressRef.prepare_story_state()
	StoryProgressRef.ensure_story_train()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/travel.tscn")
