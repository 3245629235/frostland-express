extends Control
class_name CharacterCard

signal card_clicked
signal add_button_clicked
signal drag_started(card: Control)
signal drag_ended(card: Control)

@export var character_id: String = ""
@export var character_name: String = "未知"
@export var character_role: String = "未知"
@export var portrait_path: String = ""
@export var stars: int = 5
@export var level: int = 1
@export var health: int = 100
@export var max_health: int = 100
@export var attack: int = 50
@export var status: String = "待命"

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $BottomPanel/InfoBox/NameLabel
@onready var role_label: Label = $BottomPanel/InfoBox/RoleLabel
@onready var health_label: Label = $BottomPanel/InfoBox/HealthRow/HealthLabel
@onready var status_label: Label = $StatusLabel
@onready var add_btn: Button = $BottomPanel/InfoBox/HealthRow/AddBtn
@onready var stars_container: HBoxContainer = $BottomPanel/InfoBox/Stars

var _star_labels: Array
var _pending_data: Dictionary = {}
var _data_set: bool = false

var is_preview: bool = false

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _mouse_down: bool = false
const DRAG_THRESHOLD: float = 10.0

var selected: bool = false:
	set(value):
		selected = value
		if not is_preview:
			_update_selection_scale()

func _ready() -> void:
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.offset_bottom = -30.0
	_star_labels = [
		$BottomPanel/InfoBox/Stars/Star1,
		$BottomPanel/InfoBox/Stars/Star2,
		$BottomPanel/InfoBox/Stars/Star3,
		$BottomPanel/InfoBox/Stars/Star4,
		$BottomPanel/InfoBox/Stars/Star5,
	]
	if _data_set:
		_apply_data(_pending_data)
		_update_ui()
	if is_preview:
		mouse_filter = MOUSE_FILTER_IGNORE
		return
	add_btn.pressed.connect(_on_add_clicked)
	mouse_filter = MOUSE_FILTER_PASS
	_update_selection_scale()

func _gui_input(event: InputEvent) -> void:
	if is_preview:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mouse_down = true
		_drag_start_pos = get_global_mouse_position()
		accept_event()

func _input(event: InputEvent) -> void:
	if is_preview:
		return
	if not _mouse_down and not _is_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_down = false
		if _is_dragging:
			_is_dragging = false
			drag_ended.emit(self)
		elif get_global_rect().has_point(get_global_mouse_position()):
			card_clicked.emit()

func _process(_delta: float) -> void:
	if is_preview:
		return
	if _mouse_down and not _is_dragging:
		var mouse_pos = get_global_mouse_position()
		var horizontal_distance = abs(mouse_pos.x - _drag_start_pos.x)
		if horizontal_distance > DRAG_THRESHOLD:
			_is_dragging = true
			drag_started.emit(self)

func set_data(data: Dictionary) -> void:
	_data_set = true
	_pending_data = data.duplicate()
	if is_node_ready():
		_apply_data(data)
		_update_ui()

func _apply_data(data: Dictionary) -> void:
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
	if data.has("level"):
		level = int(data.level)
	if data.has("health"):
		health = int(data.health)
	if data.has("max_health"):
		max_health = int(data.max_health)
	if data.has("attack"):
		attack = int(data.attack)
	if data.has("status"):
		status = data.status

func _update_ui() -> void:
	if not portrait_path.is_empty():
		var tex = load(portrait_path)
		if tex:
			portrait.texture = tex
	name_label.text = character_name
	role_label.text = character_role
	health_label.text = str(health)
	status_label.text = status
	if _star_labels:
		for i in range(5):
			if i < stars:
				_star_labels[i].modulate = Color(1, 0.9, 0.2, 1)
			else:
				_star_labels[i].modulate = Color(0.4, 0.4, 0.4, 1)

func _update_selection_scale() -> void:
	if not is_node_ready():
		return
	if selected:
		pivot_offset = size * 0.5
		scale = Vector2(1.25, 1.25)
	else:
		scale = Vector2(1.0, 1.0)

func _on_add_clicked() -> void:
	add_button_clicked.emit()
