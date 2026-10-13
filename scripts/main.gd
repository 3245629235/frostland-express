extends Control

const SAVE_MIGRATION_DIALOG_SCENE: PackedScene = preload("res://scenes/save_migration_dialog.tscn")

var portrait_textures: Array[Texture2D] = []
var current_portrait_index: int = 0
var is_dragging: bool = false
var drag_start_x: float = 0.0
var drag_threshold: float = 50.0
var has_swiped: bool = false

@onready var conductor: TextureRect = $Conductor
@onready var team_button: Button = $TeamButton
@onready var board_button: Button = $BoardButton
@onready var team_select_button: Button = $TeamSelectButton
@onready var food_label: Label = $ResourcePanel/ResourceGrid/Food/FoodBox/FoodLabel
@onready var fuel_label: Label = $ResourcePanel/ResourceGrid/Fuel/FuelBox/FuelLabel
@onready var fuel_rate_label: Label = $ResourcePanel/ResourceGrid/Fuel/FuelBox/FuelRate
@onready var medicine_label: Label = $ResourcePanel/ResourceGrid/Medicine/MedicineBox/MedicineLabel
@onready var parts_label: Label = $ResourcePanel/ResourceGrid/Parts/PartsBox/PartsLabel
@onready var train_warning: Label = $TrainWarning

@onready var add_food_btn: Button = $DebugPanel/DebugGrid/FoodButtons/AddFoodBtn
@onready var add_food_amt: LineEdit = $DebugPanel/DebugGrid/FoodButtons/AddFoodAmt
@onready var add_fuel_btn: Button = $DebugPanel/DebugGrid/FuelButtons/AddFuelBtn
@onready var add_fuel_amt: LineEdit = $DebugPanel/DebugGrid/FuelButtons/AddFuelAmt
@onready var add_medicine_btn: Button = $DebugPanel/DebugGrid/MedicineButtons/AddMedicineBtn
@onready var add_medicine_amt: LineEdit = $DebugPanel/DebugGrid/MedicineButtons/AddMedicineAmt
@onready var add_parts_btn: Button = $DebugPanel/DebugGrid/PartsButtons/AddPartsBtn
@onready var add_parts_amt: LineEdit = $DebugPanel/DebugGrid/PartsButtons/AddPartsAmt
@onready var reset_btn: Button = $DebugPanel/DebugGrid/ResetBtn
@onready var debug_log: Label = $DebugPanel/DebugGrid/DebugLog

func _ready() -> void:
	# 主界面不是旅行场景：清除旧档遗留的旅行标记，避免后台继续消耗资源
	GameState.stop_travel()
	AudioManager.play_bgm("main")
	_load_portraits()
	_update_portrait()
	team_button.pressed.connect(_on_team_button_pressed)
	board_button.pressed.connect(_on_board_button_pressed)
	team_select_button.pressed.connect(_on_team_select_button_pressed)

	add_food_btn.pressed.connect(_on_add_food_pressed)
	add_fuel_btn.pressed.connect(_on_add_fuel_pressed)
	add_medicine_btn.pressed.connect(_on_add_medicine_pressed)
	add_parts_btn.pressed.connect(_on_add_parts_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)

	_update_resource_ui()
	if GameState.has_pending_migration():
		call_deferred("_show_save_migration_dialog")

func _process(delta: float) -> void:
	if GameState.has_pending_migration():
		return
	GameState.tick_world(delta, _get_world_character_count())
	_update_resource_ui()
	if train_warning:
		train_warning.visible = (GameState.train_control_mode == 1)

func _get_world_character_count() -> int:
	return GameState.characters.size() if GameState.characters != null else 0

func _update_resource_ui() -> void:
	var fuel_rate_display = GameState.get_train_fuel_consumption()
	var speed = GameState.get_train_speed()
	var speed_kmh = int(speed * 3.6)

	food_label.text = str(GameState.get_resource("food"))
	fuel_label.text = str(GameState.get_resource("fuel"))
	fuel_rate_label.text = "油耗 %.2f/s" % fuel_rate_display
	medicine_label.text = str(GameState.get_resource("medicine"))
	parts_label.text = str(GameState.get_resource("parts"))

func _on_team_button_pressed() -> void:
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/team.tscn")

func _on_board_button_pressed() -> void:
	if GameState.has_pending_migration():
		return
	var carriages = GameState.train.get("carriages", [])
	# BUG-001 兜底：GameState 为空但旧版 train_save.json 有编组时自动迁移
	if carriages.is_empty() and TrainSave.migrate_legacy_train_save():
		carriages = GameState.train.get("carriages", [])
		print("[DEBUG main._on_board_button_pressed] 旧档 train_save.json 已迁移并同步 GameState")
	print("[DEBUG main._on_board_button_pressed] carriages=%d has_powered_loco=%s" % [carriages.size(), GameState.has_powered_locomotive()])
	for c in carriages:
		print("[DEBUG main._on_board_button_pressed]   type=%s fuel_left=%s is_powered=%s" % [c.get("type","?"), c.get("fuel_left","N/A"), c.get("is_powered","N/A")])
	if carriages.is_empty():
		_show_popup("请先编组", "请先前往编组界面配置列车后再登车。")
		return
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/travel.tscn")

func _on_team_select_button_pressed() -> void:
	if GameState.has_pending_migration():
		return
	AudioManager.play_click()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/team_select.tscn")

func _show_popup(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.size = Vector2(400, 150)
	add_child(dialog)
	dialog.popup_centered()


func _show_save_migration_dialog() -> void:
	var dialog := SAVE_MIGRATION_DIALOG_SCENE.instantiate() as SaveMigrationDialog
	if dialog == null:
		return
	dialog.name = "SaveMigrationDialog"
	add_child(dialog)
	dialog.decision.connect(_on_save_migration_decision.bind(dialog))
	dialog.setup(GameState.migration_reason, GameState.migration_backup_path)


func _on_save_migration_decision(continue_compatible: bool, dialog: SaveMigrationDialog) -> void:
	GameState.accept_migration(continue_compatible)
	if is_instance_valid(dialog):
		dialog.queue_free()
	_update_resource_ui()

func _load_portraits() -> void:
	var paths := [
		"res://assets/sprites/conductor.png",
		"res://assets/sprites/wanggang.png",
		"res://assets/sprites/characters/老葛/老葛常服.png",
		"res://assets/sprites/characters/小刘/小刘常服.png",
	]
	for path in paths:
		var tex := load(path) as Texture2D
		if tex != null:
			portrait_textures.append(tex)

func _update_portrait() -> void:
	if portrait_textures.is_empty():
		return
	current_portrait_index = wrapi(current_portrait_index, 0, portrait_textures.size())
	conductor.texture = portrait_textures[current_portrait_index]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_point_in_conductor(event.position):
					is_dragging = true
					drag_start_x = event.position.x
					has_swiped = false
			else:
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging and not has_swiped:
		var drag_distance: float = event.position.x - drag_start_x
		if abs(drag_distance) > drag_threshold:
			if drag_distance < 0:
				_next_portrait()
			else:
				_prev_portrait()
			has_swiped = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_RIGHT:
			_next_portrait()
		elif event.keycode == KEY_LEFT:
			_prev_portrait()
		elif event.keycode == KEY_F3:
			var panel: Panel = $DebugPanel
			panel.visible = not panel.visible

func _is_point_in_conductor(point: Vector2) -> bool:
	var rect: Rect2 = conductor.get_global_rect()
	return rect.has_point(point)

func _next_portrait() -> void:
	current_portrait_index += 1
	_update_portrait()

func _prev_portrait() -> void:
	current_portrait_index -= 1
	_update_portrait()

func _exit_tree() -> void:
	GameState.save_state()

func _on_add_food_pressed() -> void:
	var amt = int(add_food_amt.text)
	GameState.add_resource("food", amt)
	_update_resource_ui()
	debug_log.text = "调试日志:\n+%d 食物" % amt

func _on_add_fuel_pressed() -> void:
	var amt = int(add_fuel_amt.text)
	GameState.add_resource("fuel", amt)
	_update_resource_ui()
	debug_log.text = "调试日志:\n+%d 燃料" % amt

func _on_add_medicine_pressed() -> void:
	var amt = int(add_medicine_amt.text)
	GameState.add_resource("medicine", amt)
	_update_resource_ui()
	debug_log.text = "调试日志:\n+%d 药品" % amt

func _on_add_parts_pressed() -> void:
	var amt = int(add_parts_amt.text)
	GameState.add_resource("parts", amt)
	_update_resource_ui()
	debug_log.text = "调试日志:\n+%d 零件" % amt

func _on_reset_pressed() -> void:
	GameState.reset_resources()
	_update_resource_ui()
	debug_log.text = "调试日志:\n所有资源已重置为1000"
