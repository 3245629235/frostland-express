extends PanelContainer
class_name EventDialog
## 生存事件面板：只负责显示和回传选项，不直接修改 GameState。

signal choice_selected(event_id: String, choice_id: String)

@onready var title_label: Label = $Margin/VBox/Title
@onready var description_label: Label = $Margin/VBox/Description
@onready var choice_box: VBoxContainer = $Margin/VBox/ChoiceBox

var _event_id: String = ""
var _resolved: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func setup(event_data: Dictionary) -> void:
	_event_id = str(event_data.get("id", ""))
	title_label.text = "%s  [%s]" % [str(event_data.get("title", "事件")), _event_id]
	description_label.text = str(event_data.get("description", ""))
	for child in choice_box.get_children():
		child.queue_free()
	for choice in event_data.get("choices", []):
		var button := Button.new()
		button.name = "Choice_" + str(choice.get("id", ""))
		button.text = str(choice.get("text", "继续"))
		button.custom_minimum_size = Vector2(420, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_choice_pressed.bind(str(choice.get("id", ""))))
		choice_box.add_child(button)
	_resolved = false
	visible = true

func _on_choice_pressed(choice_id: String) -> void:
	if _resolved:
		return
	AudioManager.play_click()
	_resolved = true
	for child in choice_box.get_children():
		if child is Button:
			(child as Button).disabled = true
	choice_selected.emit(_event_id, choice_id)
