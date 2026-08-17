extends Control

# ===== 可在编辑器中调整的参数 =====
@export var wall_speed_ratio: float = 0.8
@export var cf_speed_ratio: float = 1.0
@export var rail_y_ratio: float = 0.85
@export var vehicle_height_ratio: float = 0.36
@export var card_panel_height: float = 200.0
@export var card_size: Vector2 = Vector2(140, 140)
@export var train_start_x_ratio: float = 0.1

# 兼容旧导出变量（从配置表读取，保留导出参数用于自定义覆盖）
@export var initial_locomotive_count: int = 3
@export var initial_coal_tender_count: int = 4
@export var initial_passenger_count: int = 2

# ===== 节点引用 =====
@onready var back_button: Button = $BackButton
@onready var debug_label: Label = $DebugLabel
@onready var wall_container: Control = $WallContainer
@onready var cf_container: Control = $CeilingFloorContainer
@onready var build_menu: MenuButton = $BuildMenu
@onready var card_panel: Panel = $CardPanel
@onready var card_title: Label = $CardPanel/CardTitle
@onready var card_container: HBoxContainer = $CardPanel/CardContainer
@onready var clear_all_button: Button = $CardPanel/ClearAllButton
@onready var placed_vehicles_node: Control = $RailArea/PlacedVehicles
@onready var drag_preview: TextureRect = $DragPreview

# ===== 常量 =====
const TYPE_LOCO = "locomotive"
const TYPE_COAL = "coal_tender"
const TYPE_PASSENGER = "passenger"
const TYPE_OPEN = "open_car"
const TYPE_TANK = "tank_car"
const TYPE_SERVICE = "service_car"
const TYPE_COMBAT = "combat_car"

# 构建菜单配置
const MENU_ITEMS = [
	{"name": "机车", "type": TYPE_LOCO},
	{"name": "煤水车", "type": TYPE_COAL},
	{"name": "特殊机车", "type": null},
	{"name": "货车", "submenu": [
		{"name": "敞车", "type": TYPE_OPEN},
		{"name": "罐车", "type": TYPE_TANK},
	]},
	{"name": "客车", "type": TYPE_PASSENGER},
	{"name": "勤务车厢", "type": TYPE_SERVICE},
	{"name": "战斗车厢", "type": TYPE_COMBAT},
]

# ===== 系统组件 =====
var parallax: TrainParallax

# ===== 车辆数据 =====
var vehicle_data: Dictionary = {}
var player_inventory: Dictionary = {}
var current_card_type: String = ""
var placed_vehicles: Array = []

# ===== 拖动状态 =====
var drag_mode: int = 0
var drag_card_type: String = ""
var drag_vehicle_index: int = -1
var has_dragged: bool = false

# ===== 布局缓存 =====
var rail_y: float = 0.0
var vehicle_target_height: float = 0.0


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	clear_all_button.pressed.connect(_on_clear_all_pressed)
	_setup_build_menu()

	# 初始化视口尺寸和布局
	var view_w = get_viewport().get_visible_rect().size.x
	var view_h = get_viewport().get_visible_rect().size.y
	rail_y = view_h * rail_y_ratio
	vehicle_target_height = view_h * vehicle_height_ratio
	card_panel.offset_top = -card_panel_height

	# 初始化车辆数据
	_init_vehicle_data()

	# 初始化视差滚动系统
	parallax = TrainParallax.new()
	if not parallax.init(wall_container, cf_container, view_w, view_h, wall_speed_ratio, cf_speed_ratio):
		_show_popup("错误", "视差图片加载失败！")
		return

	# 加载保存的编组
	TrainSave.load_train_save(placed_vehicles, player_inventory, vehicle_data, placed_vehicles_node, _on_vehicle_gui_input)
	_refresh_flips()
	_rearrange_vehicles()

	# 初始化拖动预览
	drag_preview.visible = false
	_update_debug_label()


# ===== 初始化 =====
func _init_vehicle_data() -> void:
	for t in VehicleTypes.get_all_types():
		var type_str = VehicleTypes.enum_to_string(t)
		var cfg = VehicleTypes.CONFIG[t]
		var init_count = cfg.initial_count
		if type_str == TYPE_LOCO:
			init_count = initial_locomotive_count
		elif type_str == TYPE_COAL:
			init_count = initial_coal_tender_count
		elif type_str == TYPE_PASSENGER:
			init_count = initial_passenger_count

		vehicle_data[type_str] = {
			"name": cfg.name,
			"card_path": cfg.card_path,
			"vehicle_path": cfg.vehicle_path,
			"initial_count": init_count,
			"card_tex": null,
			"vehicle_tex": null,
			"scaled_width": 0.0,
		}
		player_inventory[type_str] = init_count

	for type_str in vehicle_data.keys():
		var d = vehicle_data[type_str]
		var ct = load(d.card_path) as Texture2D
		var vt = load(d.vehicle_path) as Texture2D
		if ct != null:
			d.card_tex = ct
		if vt != null:
			d.vehicle_tex = vt
			var scale_factor: float = vehicle_target_height / vt.get_height()
			d.scaled_width = vt.get_width() * scale_factor


# ===== 主循环 =====
func _process(delta: float) -> void:
	parallax.process(delta, not placed_vehicles.is_empty())
	if not placed_vehicles.is_empty():
		_rearrange_vehicles()


# ===== 输入处理 =====
func _input(event: InputEvent) -> void:
	if drag_mode != 0:
		_handle_drag_input(event)
		return
	parallax.handle_scroll_input(event, card_panel_height)


func _handle_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if has_dragged:
				if drag_mode == 1:
					_try_place_vehicle(event.position)
				elif drag_mode == 2:
					_try_recycle_vehicle(event.position)
			_end_drag()
	elif event is InputEventMouseMotion:
		has_dragged = true
		var mouse_pos = event.position
		drag_preview.position = mouse_pos - drag_preview.size / 2
		_update_drag_preview_texture(mouse_pos.y)


func _update_drag_preview_texture(mouse_y: float) -> void:
	var panel_top = parallax.view_h - card_panel_height
	var show_card = mouse_y > panel_top
	var d = vehicle_data.get(drag_card_type)
	if d == null:
		return

	if show_card:
		if drag_preview.texture != d.card_tex:
			drag_preview.texture = d.card_tex
			drag_preview.size = card_size
	else:
		if drag_preview.texture != d.vehicle_tex:
			drag_preview.texture = d.vehicle_tex
			drag_preview.size = _get_vehicle_preview_size(drag_card_type)


func _get_vehicle_preview_size(type: String) -> Vector2:
	var d = vehicle_data.get(type)
	if d == null or d.vehicle_tex == null:
		return card_size
	var vt: Texture2D = d.vehicle_tex
	var vscale: float = vehicle_target_height / vt.get_height()
	return Vector2(vt.get_width() * vscale, vehicle_target_height)


func _start_card_drag(type: String, global_pos: Vector2) -> void:
	drag_mode = 1
	drag_card_type = type
	drag_vehicle_index = -1
	has_dragged = false
	var d = vehicle_data.get(type)
	drag_preview.texture = d.card_tex if d else null
	drag_preview.size = card_size
	drag_preview.position = global_pos - card_size / 2
	drag_preview.visible = true


func _start_vehicle_drag(index: int, global_pos: Vector2) -> void:
	if index < 0 or index >= placed_vehicles.size():
		return
	var v = placed_vehicles[index]
	drag_mode = 2
	drag_card_type = v.type
	drag_vehicle_index = index
	has_dragged = false
	drag_preview.texture = vehicle_data[v.type].vehicle_tex
	drag_preview.size = Vector2(v.width, vehicle_target_height)
	drag_preview.position = global_pos - Vector2(v.width / 2, vehicle_target_height / 2)
	drag_preview.visible = true
	v.node.visible = false


func _end_drag() -> void:
	if drag_mode == 2 and not has_dragged and drag_vehicle_index >= 0 and drag_vehicle_index < placed_vehicles.size():
		placed_vehicles[drag_vehicle_index].node.visible = true
	drag_mode = 0
	drag_card_type = ""
	drag_vehicle_index = -1
	has_dragged = false
	drag_preview.visible = false


# ===== 构建菜单 =====
func _setup_build_menu() -> void:
	var popup: PopupMenu = build_menu.get_popup()
	popup.clear()
	for i in range(MENU_ITEMS.size()):
		var item = MENU_ITEMS[i]
		if item.has("submenu"):
			var submenu = PopupMenu.new()
			submenu.name = "freight_submenu"
			for j in range(item.submenu.size()):
				submenu.add_item(item.submenu[j].name, j)
			submenu.index_pressed.connect(_on_submenu_selected.bind(i))
			popup.add_child(submenu)
			popup.add_submenu_item(item.name, submenu.name, i)
		else:
			popup.add_item(item.name, i)
	popup.index_pressed.connect(_on_build_menu_selected)


func _on_build_menu_selected(index: int) -> void:
	var item = MENU_ITEMS[index]
	if item.has("submenu"):
		return
	if item.type == null:
		debug_label.text = item.name + " (暂未实现)"
		return
	_show_cards(item.type)
	debug_label.text = "已展示: " + item.name + "卡片，拖动到铁轨放置"


func _on_submenu_selected(sub_index: int, parent_index: int) -> void:
	var item = MENU_ITEMS[parent_index].submenu[sub_index]
	if item.type == null:
		debug_label.text = item.name + " (暂未实现)"
		return
	_show_cards(item.type)
	debug_label.text = "已展示: " + item.name + "卡片，拖动到铁轨放置"


# ===== 卡片展示 =====
func _show_cards(type: String) -> void:
	current_card_type = type
	for child in card_container.get_children():
		child.queue_free()

	var d = vehicle_data.get(type)
	if d == null or d.card_tex == null:
		card_title.text = "卡片加载失败"
		return

	var count: int = player_inventory.get(type, 0)
	if count == 0:
		card_title.text = "没有" + d.name + "卡片"
		return

	card_title.text = d.name + "卡片 x" + str(count) + " (拖动到铁轨上放置)"

	for i in range(count):
		var card := TextureRect.new()
		card.texture = d.card_tex
		card.custom_minimum_size = card_size
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.gui_input.connect(_on_card_gui_input.bind(type))
		card_container.add_child(card)


func _on_card_gui_input(event: InputEvent, type: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_card_drag(type, event.global_position)
		else:
			if drag_mode == 1 and has_dragged:
				_try_place_vehicle(event.global_position)
			_end_drag()


# ===== 车辆放置 =====
func _show_popup(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.size = Vector2(400, 150)
	add_child(dialog)
	dialog.popup_centered()


func _try_place_vehicle(mouse_pos: Vector2) -> void:
	var type = drag_card_type
	if type == "" or not vehicle_data.has(type):
		return

	if mouse_pos.y > parallax.view_h - card_panel_height:
		return

	var insert_index = _calc_insert_index(mouse_pos.x)
	var error_msg = TrainPlacement.check_placement_rules(type, insert_index, placed_vehicles, player_inventory)
	if error_msg != "":
		_show_popup("连挂失败", error_msg)
		return

	_place_vehicle_at(type, insert_index)
	TrainSave.save_train(placed_vehicles, player_inventory, vehicle_data)

	var msg = vehicle_data[type].name + "放置成功! 列车长度:" + str(placed_vehicles.size())
	if TrainPlacement.has_unpowered_locomotives(placed_vehicles):
		msg += "\n(警告: 有机车没有动力)"
	_show_popup("放置成功", msg)


func _place_vehicle_at(type: String, insert_index: int) -> void:
	var d = vehicle_data[type]
	var v_width = d.scaled_width

	var v_node := TextureRect.new()
	v_node.texture = d.vehicle_tex
	v_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_node.stretch_mode = TextureRect.STRETCH_SCALE
	v_node.flip_h = false
	v_node.mouse_filter = Control.MOUSE_FILTER_STOP
	v_node.gui_input.connect(_on_vehicle_gui_input.bind(v_node))
	placed_vehicles_node.add_child(v_node)

	placed_vehicles.insert(insert_index, {
		"type": type,
		"width": v_width,
		"flipped": false,
		"node": v_node,
	})

	player_inventory[type] -= 1
	_rearrange_vehicles()
	_refresh_flips()

	if current_card_type != "":
		_show_cards(current_card_type)


func _refresh_flips() -> void:
	var left_loco_idx = -1
	var right_loco_idx = -1

	for i in range(placed_vehicles.size()):
		if placed_vehicles[i].type == TYPE_LOCO:
			if left_loco_idx < 0:
				left_loco_idx = i
			right_loco_idx = i

	for i in range(placed_vehicles.size()):
		var v = placed_vehicles[i]
		if v.type == TYPE_LOCO:
			v.flipped = (i == placed_vehicles.size() - 1 and i != 0)
		elif v.type == TYPE_COAL:
			if left_loco_idx == right_loco_idx:
				v.flipped = false
			elif right_loco_idx >= 0 and i == right_loco_idx - 1:
				v.flipped = true
			elif left_loco_idx >= 0 and i == left_loco_idx + 1:
				v.flipped = false
			elif left_loco_idx >= 0 and right_loco_idx >= 0:
				var dist_to_left = i - left_loco_idx
				var dist_to_right = right_loco_idx - i
				v.flipped = dist_to_right <= dist_to_left
			else:
				v.flipped = false
		elif TrainPlacement.is_cargo_type(v.type):
			v.flipped = false
		v.node.flip_h = v.flipped


func _on_vehicle_gui_input(event: InputEvent, node: TextureRect) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(placed_vehicles.size()):
			if placed_vehicles[i].node == node:
				_start_vehicle_drag(i, event.global_position)
				break


func _try_recycle_vehicle(mouse_pos: Vector2) -> void:
	if drag_vehicle_index < 0 or drag_vehicle_index >= placed_vehicles.size():
		return

	var panel_top = parallax.view_h - card_panel_height
	if mouse_pos.y < panel_top:
		placed_vehicles[drag_vehicle_index].node.visible = true
		return

	var type = drag_card_type
	var v = placed_vehicles[drag_vehicle_index]

	var error_msg = TrainPlacement.check_recycle_rules(drag_vehicle_index, placed_vehicles)
	if error_msg != "":
		placed_vehicles[drag_vehicle_index].node.visible = true
		_show_popup("回收失败", error_msg)
		return

	v.node.queue_free()
	placed_vehicles.remove_at(drag_vehicle_index)
	player_inventory[type] += 1

	_refresh_flips()
	_rearrange_vehicles()
	TrainSave.save_train(placed_vehicles, player_inventory, vehicle_data)

	if current_card_type != "":
		_show_cards(current_card_type)

	var recycle_msg = vehicle_data[type].name + "已回收"
	if TrainPlacement.has_unpowered_locomotives(placed_vehicles):
		recycle_msg += "\n(警告: 有机车没有动力)"
	_show_popup("回收成功", recycle_msg)


func _calc_insert_index(mouse_x: float) -> int:
	if placed_vehicles.is_empty():
		return 0

	var start_x = parallax.view_w * train_start_x_ratio - parallax.scroll_x
	var current_x = start_x

	for i in range(placed_vehicles.size()):
		var v = placed_vehicles[i]
		var mid_x = current_x + v.width / 2

		if mouse_x < mid_x:
			return i

		current_x += v.width

	return placed_vehicles.size()


func _rearrange_vehicles() -> void:
	parallax.update_max_scroll(placed_vehicles, train_start_x_ratio)
	var start_x = parallax.view_w * train_start_x_ratio - parallax.scroll_x
	var current_x = start_x
	for v in placed_vehicles:
		v.node.size = Vector2(v.width, vehicle_target_height)
		v.node.position = Vector2(current_x, rail_y - vehicle_target_height)
		current_x += v.width


# ===== 一键清除 =====
func _on_clear_all_pressed() -> void:
	if placed_vehicles.is_empty():
		_show_popup("提示", "列车上没有车辆")
		return

	for v in placed_vehicles:
		v.node.queue_free()
		player_inventory[v.type] += 1

	placed_vehicles.clear()
	parallax.scroll_x = 0
	parallax.target_scroll = 0
	parallax.update_max_scroll(placed_vehicles, train_start_x_ratio)

	if current_card_type != "":
		_show_cards(current_card_type)

	TrainSave.save_train(placed_vehicles, player_inventory, vehicle_data)
	_show_popup("清除成功", "已清除所有车辆")


# ===== 调试信息 =====
func _update_debug_label() -> void:
	var inv_str = "库存:"
	for type_str in player_inventory.keys():
		inv_str += " " + vehicle_data[type_str].name + str(player_inventory[type_str])
	debug_label.text = inv_str + " | 已放置:" + str(placed_vehicles.size())


func _on_back_pressed() -> void:
	TrainSave.save_train(placed_vehicles, player_inventory, vehicle_data)

	var loco_count = TrainPlacement.count_type(TYPE_LOCO, placed_vehicles)
	var coal_count = TrainPlacement.count_type(TYPE_COAL, placed_vehicles)
	if loco_count > 0 and coal_count < loco_count:
		_show_popup("列车无法运行", "机车需要煤水车提供燃料和水")
		return

	get_tree().change_scene_to_file("res://scenes/main.tscn")
