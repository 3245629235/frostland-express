extends Control

const CHARACTER_CARD_SCENE: PackedScene = preload("res://scenes/character_card.tscn")
const EMPTY_SLOT_SCENE: PackedScene = preload("res://scenes/empty_slot.tscn")
const CHARACTER_SELECT_DIALOG_SCENE: PackedScene = preload("res://scenes/character_select_dialog.tscn")

const MAX_ECHELON_SIZE: int = 8
const SLOT_HEIGHT: float = 560.0
const DRAG_SCALE: float = 1.1

@onready var back_btn: Button = $TopBar/BackBtn
@onready var slot_grid: Control = $CenterPanel/CardScroll/CardGrid
@onready var card_scroll: ScrollContainer = $CenterPanel/CardScroll
@onready var detail_portrait: TextureRect = $RightPanel/DetailPortrait
@onready var detail_name: Label = $RightPanel/DetailName
@onready var detail_role: Label = $RightPanel/DetailRole
@onready var detail_health: Label = $RightPanel/DetailHealthRow/DetailHealth
@onready var detail_stars: HBoxContainer = $RightPanel/DetailStars
@onready var efficiency_label: Label = $RightPanel/EfficiencyLabel
@onready var confirm_btn: Button = $RightPanel/ConfirmBtn

var _detail_star_labels: Array = []

var selected_characters: Array = []
var current_echelon: int = 1
var slot_nodes: Array = []
var selected_slot: int = -1

var _card_width: float = 110.0
var _card_spacing: float = 8.0
var _drag_card: CharacterCard = null
var _drag_preview: Control = null
var _drag_index: int = -1
var _drag_insert_index: int = -1
var _target_positions: Array = []
var _drag_start_y: float = 0.0

func _ready() -> void:
	AudioManager.play_bgm("main")
	back_btn.pressed.connect(_on_back_clicked)
	confirm_btn.pressed.connect(_on_confirm_clicked)
	$LeftPanel/TeamList/Team1Btn.pressed.connect(func(): _switch_echelon(1))
	$LeftPanel/TeamList/Team2Btn.pressed.connect(func(): _switch_echelon(2))
	$LeftPanel/TeamList/Team3Btn.pressed.connect(func(): _switch_echelon(3))
	$LeftPanel/TeamList/Team4Btn.pressed.connect(func(): _switch_echelon(4))
	_detail_star_labels = [
		$RightPanel/DetailStars/Star1,
		$RightPanel/DetailStars/Star2,
		$RightPanel/DetailStars/Star3,
		$RightPanel/DetailStars/Star4,
		$RightPanel/DetailStars/Star5,
	]
	card_scroll.clip_contents = false
	# 加载已保存的编队数据（从 GameState 单例）
	_load_saved_team()
	_load_slots()
	_update_slot_display()
	_update_efficiency()
	_clear_detail()

func _process(delta: float) -> void:
	if _drag_card and _drag_preview:
		var mouse_pos = slot_grid.get_local_mouse_position()
		var scaled_w = _card_width * DRAG_SCALE
		var preview_x = mouse_pos.x - scaled_w * 0.5
		_drag_preview.position = Vector2(preview_x, 10)

		var local_mouse = slot_grid.get_local_mouse_position()
		var insert_index = int((local_mouse.x + _card_width * 0.5) / (_card_width + _card_spacing))
		insert_index = clamp(insert_index, 0, MAX_ECHELON_SIZE - 1)
		_drag_insert_index = insert_index

		for i in range(slot_nodes.size()):
			if i == _drag_index:
				continue
			var node = slot_nodes[i]
			var target_x: float
			if i < _drag_index and i < insert_index:
				target_x = i * (_card_width + _card_spacing)
			elif i > _drag_index and i > insert_index:
				target_x = i * (_card_width + _card_spacing)
			elif i < _drag_index and i >= insert_index:
				target_x = (i + 1) * (_card_width + _card_spacing)
			elif i > _drag_index and i <= insert_index:
				target_x = (i - 1) * (_card_width + _card_spacing)
			else:
				target_x = i * (_card_width + _card_spacing)
			var target = Vector2(target_x, node.position.y)
			node.position = Vector2(lerp(node.position.x, target.x, 1.0 - exp(-12.0 * delta)), node.position.y)

func _load_slots() -> void:
	for node in slot_grid.get_children():
		node.queue_free()
	slot_nodes.clear()
	_target_positions.clear()

	for i in range(MAX_ECHELON_SIZE):
		var slot = EMPTY_SLOT_SCENE.instantiate()
		slot_grid.add_child(slot)
		slot.position = Vector2(i * (_card_width + _card_spacing), 10)
		slot.size = Vector2(_card_width, SLOT_HEIGHT)
		slot.add_clicked.connect(func(idx = i): _on_slot_add_clicked(idx))
		slot_nodes.append(slot)
		_target_positions.append(Vector2(i * (_card_width + _card_spacing), 10))

	var grid_width = MAX_ECHELON_SIZE * (_card_width + _card_spacing) - _card_spacing + 20
	slot_grid.custom_minimum_size = Vector2(grid_width, SLOT_HEIGHT + 40)

func _update_slot_display() -> void:
	var echelon_chars = _get_echelon_characters(current_echelon)

	for i in range(MAX_ECHELON_SIZE):
		var target_pos = Vector2(i * (_card_width + _card_spacing), 10)
		var old_node = slot_nodes[i]

		if i < echelon_chars.size() and echelon_chars[i] != null:
			if not (old_node is CharacterCard):
				old_node.queue_free()
				var card = CHARACTER_CARD_SCENE.instantiate()
				slot_grid.add_child(card)
				card.position = target_pos
				card.size = Vector2(_card_width, SLOT_HEIGHT)
				card.set_data(echelon_chars[i])
				card.card_clicked.connect(func(idx = i): _on_card_clicked(idx))
				card.add_button_clicked.connect(func(idx = i): _on_remove_clicked(idx))
				card.drag_started.connect(func(c): _on_drag_started(c))
				card.drag_ended.connect(func(c): _on_drag_ended(c))
				slot_nodes[i] = card
			else:
				old_node.position = target_pos
				old_node.set_data(echelon_chars[i])
		else:
			if old_node is CharacterCard:
				old_node.queue_free()
				var slot = EMPTY_SLOT_SCENE.instantiate()
				slot_grid.add_child(slot)
				slot.position = target_pos
				slot.size = Vector2(_card_width, SLOT_HEIGHT)
				slot.add_clicked.connect(func(idx = i): _on_slot_add_clicked(idx))
				slot_nodes[i] = slot
			else:
				old_node.position = target_pos

func _get_echelon_characters(echelon: int) -> Array:
	if echelon < 1 or echelon > 4:
		return []
	var result: Array = []
	for i in range(MAX_ECHELON_SIZE):
		result.append(null)
	for c in selected_characters:
		if c.has("echelon") and c.echelon == echelon and c.has("slot_index"):
			var idx = int(c.slot_index)
			if idx >= 0 and idx < MAX_ECHELON_SIZE:
				result[idx] = c
	return result

func _switch_echelon(echelon: int) -> void:
	current_echelon = echelon
	selected_slot = -1
	_clear_detail()
	_update_slot_display()
	_update_efficiency()

func _on_slot_add_clicked(index: int) -> void:
	selected_slot = index
	_open_character_dialog()

func _open_character_dialog() -> void:
	var assigned: Array = []
	for c in selected_characters:
		if c.has("id"):
			assigned.append(c.id)

	var dialog = CHARACTER_SELECT_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(dialog)
	dialog.setup(CharacterData.ALL_CHARACTERS, assigned)
	dialog.character_selected.connect(_on_character_selected)

func _open_character_dialog_view(char_data: Dictionary) -> void:
	var assigned: Array = []
	for c in selected_characters:
		if c.has("id"):
			assigned.append(c.id)

	var dialog = CHARACTER_SELECT_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(dialog)
	dialog.setup_view(char_data, CharacterData.ALL_CHARACTERS, assigned)
	dialog.character_selected.connect(_on_character_selected)
	dialog.character_removed.connect(_on_character_removed)

func _on_character_removed(char_data: Dictionary) -> void:
	if selected_slot < 0:
		return
	var remove_idx = -1
	for i in range(selected_characters.size()):
		var c = selected_characters[i]
		if c.has("echelon") and c.echelon == current_echelon and c.has("slot_index") and c.slot_index == selected_slot:
			remove_idx = i
			break
	if remove_idx < 0:
		for i in range(selected_characters.size()):
			var c = selected_characters[i]
			if c.has("echelon") and c.echelon == current_echelon and c.has("id") and char_data.has("id") and c.id == char_data.id:
				remove_idx = i
				break
	if remove_idx >= 0:
		selected_characters.remove_at(remove_idx)
	_reorder_echelon_slots(current_echelon)
	selected_slot = -1
	_clear_detail()
	_update_slot_display()
	_update_efficiency()
	_save_team()

func _reorder_echelon_slots(echelon: int) -> void:
	var echelon_chars: Array = []
	var to_remove: Array = []
	for i in range(selected_characters.size()):
		var c = selected_characters[i]
		if c.has("echelon") and c.echelon == echelon:
			echelon_chars.append(c)
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		selected_characters.remove_at(to_remove[i])
	echelon_chars.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	for i in range(echelon_chars.size()):
		echelon_chars[i]["slot_index"] = i
		selected_characters.append(echelon_chars[i])

func _on_character_selected(char_data: Dictionary) -> void:
	if selected_slot < 0:
		return
	var new_char = char_data.duplicate()
	new_char["echelon"] = current_echelon

	var echelon_chars = _get_echelon_characters(current_echelon)
	var has_any: bool = false
	for c in echelon_chars:
		if c != null:
			has_any = true
			break
	if not has_any:
		new_char["slot_index"] = 0
	else:
		new_char["slot_index"] = selected_slot

	var existing_idx = -1
	for i in range(selected_characters.size()):
		var c = selected_characters[i]
		if c.has("echelon") and c.echelon == current_echelon and c.has("slot_index") and c.slot_index == selected_slot:
			existing_idx = i
			break

	if existing_idx >= 0:
		selected_characters.remove_at(existing_idx)

	selected_characters.append(new_char)
	selected_slot = -1
	_update_slot_display()
	_update_efficiency()
	_save_team()

func _on_card_clicked(index: int) -> void:
	selected_slot = index
	var echelon_chars = _get_echelon_characters(current_echelon)
	if index < echelon_chars.size() and echelon_chars[index] != null:
		_open_character_dialog_view(echelon_chars[index])

func _on_remove_clicked(index: int) -> void:
	var remove_idx = -1
	for i in range(selected_characters.size()):
		var c = selected_characters[i]
		if c.has("echelon") and c.echelon == current_echelon and c.has("slot_index") and c.slot_index == index:
			remove_idx = i
			break
	if remove_idx >= 0:
		selected_characters.remove_at(remove_idx)
	selected_slot = -1
	_clear_detail()
	_update_slot_display()
	_update_efficiency()
	_save_team()

func _show_detail(char_data: Dictionary) -> void:
	if char_data.has("portrait") and not char_data.portrait.is_empty():
		var tex = load(char_data.portrait)
		if tex:
			detail_portrait.texture = tex
	detail_name.text = char_data.get("name", "未知")
	detail_role.text = char_data.get("role", "")
	detail_health.text = str(char_data.get("health", 0))
	var stars = char_data.get("stars", 0)
	for i in range(5):
		if i < stars:
			_detail_star_labels[i].add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		else:
			_detail_star_labels[i].add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))

func _clear_detail() -> void:
	detail_portrait.texture = null
	detail_name.text = "选择一个角色"
	detail_role.text = ""
	detail_health.text = "100"
	for i in range(5):
		_detail_star_labels[i].add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))

func _update_efficiency() -> void:
	var total = 0
	var echelon_chars = _get_echelon_characters(current_echelon)
	for c in echelon_chars:
		if c != null and c.has("attack"):
			total += int(c.attack)
	efficiency_label.text = "全队作战效能: %d" % total

func _on_drag_started(card: CharacterCard) -> void:
	var echelon_chars = _get_echelon_characters(current_echelon)
	_drag_index = -1
	for i in range(slot_nodes.size()):
		if slot_nodes[i] == card:
			_drag_index = i
			break
	if _drag_index < 0:
		return
	if echelon_chars[_drag_index] == null:
		return

	_drag_card = card
	_drag_insert_index = _drag_index
	_drag_start_y = card.get_global_position().y
	card.selected = true
	card.visible = false

	var char_data = echelon_chars[_drag_index]
	_drag_preview = _create_drag_preview(char_data)
	slot_grid.add_child(_drag_preview)
	_drag_preview.size = Vector2(_card_width, SLOT_HEIGHT)
	_drag_preview.pivot_offset = Vector2(_card_width * 0.5, SLOT_HEIGHT * 0.5)
	_drag_preview.scale = Vector2(DRAG_SCALE, DRAG_SCALE)
	var mouse_pos = slot_grid.get_local_mouse_position()
	var scaled_w = _card_width * DRAG_SCALE
	var preview_x = mouse_pos.x - scaled_w * 0.5
	_drag_preview.position = Vector2(preview_x, 10)

func _create_drag_preview(char_data: Dictionary) -> Control:
	var preview = CHARACTER_CARD_SCENE.instantiate()
	preview.is_preview = true
	preview.set_data(char_data)
	preview.size = Vector2(_card_width, SLOT_HEIGHT)
	preview.z_index = 100
	preview.modulate = Color(1, 1, 1, 1)
	preview.mouse_filter = MOUSE_FILTER_IGNORE
	return preview

func _on_drag_ended(_card: CharacterCard) -> void:
	if not _drag_card or _drag_index < 0:
		return

	var mouse_pos = slot_grid.get_local_mouse_position()
	var target_index = int((mouse_pos.x + _card_width * 0.5) / (_card_width + _card_spacing))
	target_index = clamp(target_index, 0, MAX_ECHELON_SIZE - 1)

	if target_index != _drag_index:
		_move_slot(_drag_index, target_index)

	_drag_card.selected = false
	_drag_card.visible = true

	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null
	_drag_card = null
	_drag_index = -1
	_drag_insert_index = -1

	_load_slots()
	_update_slot_display()
	_update_efficiency()
	_save_team()

func _show_no_captain_warning() -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "第 %d 编队没有队长，请先配置!" % current_echelon
	dialog.ok_button_text = "确认"
	dialog.title = "提示"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _move_slot(from_idx: int, to_idx: int) -> void:
	var slots: Array = []
	for i in range(MAX_ECHELON_SIZE):
		slots.append(null)

	for i in range(selected_characters.size()):
		var c = selected_characters[i]
		if c.has("echelon") and c.echelon == current_echelon and c.has("slot_index"):
			var idx = c.slot_index
			if idx >= 0 and idx < MAX_ECHELON_SIZE:
				slots[idx] = c

	var moved_char = slots[from_idx]

	if from_idx < to_idx:
		for i in range(from_idx, to_idx):
			slots[i] = slots[i + 1]
	else:
		for i in range(from_idx, to_idx, -1):
			slots[i] = slots[i - 1]

	slots[to_idx] = moved_char

	for i in range(MAX_ECHELON_SIZE):
		if slots[i] != null:
			for j in range(selected_characters.size()):
				if selected_characters[j].has("id") and selected_characters[j].id == slots[i].id:
					selected_characters[j]["slot_index"] = i
					break

func _load_saved_team() -> void:
	# GameState 是 Autoload 单例，已在 _ready() 时完成 load_state()
	for saved in GameState.characters:
		if not (saved is Dictionary):
			continue
		if not saved.has("id"):
			continue
		var base: Dictionary = CharacterData.find_by_id(saved.id)
		if base.is_empty():
			continue
		var merged: Dictionary = base.duplicate()
		merged["echelon"] = int(saved.get("echelon", 1))
		merged["slot_index"] = int(saved.get("slot_index", 0))
		selected_characters.append(merged)

func _save_team() -> void:
	GameState.characters = selected_characters.duplicate(true)
	GameState.save_state()

func _on_back_clicked() -> void:
	AudioManager.play_back()
	var echelon_chars = _get_echelon_characters(current_echelon)
	if echelon_chars.size() == 0 or echelon_chars[0] == null:
		_show_no_captain_warning()
		return
	_save_team()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_confirm_clicked() -> void:
	AudioManager.play_click()
	_save_team()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
