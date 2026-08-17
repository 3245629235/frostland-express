extends Control

signal card_clicked(char_data: Dictionary)

@export var character_id: String = ""
@export var character_name: String = "未知"
@export var character_role: String = "未知"
@export var portrait_path: String = ""
@export var stars: int = 5

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $BottomPanel/InfoBox/NameLabel

var _char_data: Dictionary = {}
var _selectable: bool = true
var _star_labels: Array = []
var _data_set: bool = false

func _ready() -> void:
	_star_labels = [
		$BottomPanel/InfoBox/Stars/Star1,
		$BottomPanel/InfoBox/Stars/Star2,
		$BottomPanel/InfoBox/Stars/Star3,
		$BottomPanel/InfoBox/Stars/Star4,
		$BottomPanel/InfoBox/Stars/Star5,
	]
	# 让整个卡片可点击
	mouse_filter = MOUSE_FILTER_STOP
	if _data_set:
		_update_ui()

func _gui_input(event: InputEvent) -> void:
	if not _selectable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(_char_data)
		accept_event()

func set_data(data: Dictionary) -> void:
	_char_data = data.duplicate()
	_data_set = true
	if data.has("id"):
		character_id = data.id
	if data.has("name"):
		character_name = data.name
	if data.has("role"):
		character_role = data.role
	if data.has("portrait"):
		portrait_path = data.portrait
	if data.has("stars"):
		stars = int(data.stars)
	if is_node_ready():
		_update_ui()

func _update_ui() -> void:
	if not portrait_path.is_empty():
		var tex = load(portrait_path)
		if tex:
			portrait.texture = tex
	name_label.text = character_name
	for i in range(_star_labels.size()):
		if i < stars:
			_star_labels[i].modulate = Color(1, 0.9, 0.2, 1)
		else:
			_star_labels[i].modulate = Color(0.4, 0.4, 0.4, 1)

func set_selectable(selectable: bool) -> void:
	_selectable = selectable
	mouse_filter = MOUSE_FILTER_STOP if selectable else MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 1) if selectable else Color(0.4, 0.4, 0.4, 1)
