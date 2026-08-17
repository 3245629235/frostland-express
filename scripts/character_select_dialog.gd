extends CanvasLayer

signal character_selected(char_data: Dictionary)
signal character_removed(char_data: Dictionary)

const DEPOT_CARD_SCENE: PackedScene = preload("res://scenes/depot_card.tscn")

var all_characters: Array = []
var assigned_ids: Array = []
# 查看模式下的初始角色（只有这个角色能离队）
var view_character: Dictionary = {}
var is_view_mode: bool = false

@onready var close_btn: Button = $CharacterSelectDialog/TopBar/CloseBtn
@onready var leave_btn: Button = $CharacterSelectDialog/TopBar/LeaveBtn
@onready var card_grid: GridContainer = $CharacterSelectDialog/ScrollContainer/CharacterGrid
@onready var dialog: Control = $CharacterSelectDialog
@onready var scroll_container: ScrollContainer = $CharacterSelectDialog/ScrollContainer

func _ready() -> void:
	layer = 1000
	close_btn.pressed.connect(_on_close_clicked)
	leave_btn.pressed.connect(_on_leave_clicked)
	_refresh_view()
	_populate_grid()

func setup(characters: Array, assigned: Array) -> void:
	all_characters = characters
	assigned_ids = assigned
	is_view_mode = false
	view_character = {}
	if is_node_ready():
		_refresh_view()
		_populate_grid()

func setup_view(char_data: Dictionary, characters: Array, assigned: Array) -> void:
	all_characters = characters
	assigned_ids = assigned
	is_view_mode = true
	view_character = char_data.duplicate()
	if is_node_ready():
		_refresh_view()
		_populate_grid()

func _refresh_view() -> void:
	if is_view_mode:
		leave_btn.visible = true
	else:
		leave_btn.visible = false

func _populate_grid() -> void:
	for child in card_grid.get_children():
		child.queue_free()
	
	for char_data in all_characters:
		var card = DEPOT_CARD_SCENE.instantiate()
		card_grid.add_child(card)
		card.size = Vector2(200, 120)
		card.set_data(char_data)
		var is_assigned: bool = false
		for aid in assigned_ids:
			if char_data.has("id") and char_data.id == aid:
				is_assigned = true
				break
		if is_assigned:
			card.set_selectable(false)
		else:
			card.card_clicked.connect(_on_card_clicked)

func _on_card_clicked(char_data: Dictionary) -> void:
	character_selected.emit(char_data)
	queue_free()

func _on_leave_clicked() -> void:
	if not is_view_mode:
		return
	if view_character.is_empty():
		return
	character_removed.emit(view_character)
	queue_free()

func _on_close_clicked() -> void:
	queue_free()
