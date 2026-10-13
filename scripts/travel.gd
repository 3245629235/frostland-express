extends Node2D
## 车内第一人称视差行驶场景 v3（修复版）
## —— 恢复 survival 原版：5 层雪原视差 + 列车车厢展示 + 拖拽浏览全貌
## —— 保留 Day 2：world_tick/fuel/physics 接线、角色状态 HUD、交互点、click 输入抽象

# ===== 雪原视差层（survival 原版配置：速度倍率 + 纵向偏移）=====
const PARALLAX_LAYERS := [
	{ "name": "Sky",       "path": "res://assets/sprites/parallax/蓝天不动.png",   "speed": 0.0,  "y_off": 0 },
	{ "name": "FarCloud",  "path": "res://assets/sprites/parallax/远景云.png",     "speed": 0.15, "y_off": 0 },
	{ "name": "MidCloud",  "path": "res://assets/sprites/parallax/中景云.png",     "speed": 0.35, "y_off": 0 },
	{ "name": "Ground",    "path": "res://assets/sprites/parallax/雪原地.png",     "speed": 0.6,  "y_off": 215 },
	{ "name": "FrontTree", "path": "res://assets/sprites/parallax/最前景枯树.png", "speed": 1.6,  "y_off": 5 },
]

## 视差滚动系数：滚动速度 = 列车速度(m/s) × 此系数
const SCROLL_SPEED_FACTOR: float = 80.0
## 列车拖拽与地面视差同速系数（survival 原版）
const TRAIN_GROUND_SPEED: float = 0.6
## 机车可通行区只保留司机室（车尾端比例）；锅炉段禁止小人穿过
const LOCO_CAB_RATIO: float = 0.10
## 列车展示区域（survival 原版比例）
const TRAIN_HEIGHT_RATIO: float = 0.36
const TRAIN_BOTTOM_RATIO: float = 0.82
const TRAIN_BOTTOM_OFFSET: float = 75.0
## 地板/天花板装饰带收口：让车厢视觉更居中（用户反馈原版地板太低/天花板太高，上轮又过头）
const CEILING_TOP_OFFSET: float = 30.0
const CEILING_HEIGHT: float = 18.0
const FLOOR_BOTTOM_OFFSET: float = 66.0
const FLOOR_HEIGHT: float = 30.0
## 拖拽惯性衰减
const INERTIA_DECAY: float = 0.95
## 拖拽判定阈值（px）
const DRAG_THRESHOLD: float = 3.0
## 角色选择/初始站位的最小间距，避免历史存档位置重叠后无法点选
const CREW_MIN_SEPARATION: float = 84.0
const CREW_SPAWN_SEARCH_OFFSETS: Array = [0.0, -96.0, 96.0, -192.0, 192.0, -288.0, 288.0, -384.0, 384.0]
## 画面缩放范围/步长：只允许从原始比例放大（不能缩小到 1.0 以下）
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 1.8
const ZOOM_STEP: float = 0.1
const ZOOM_ANIM_SPEED: float = 8.0
const EVENT_DIALOG_SCENE: PackedScene = preload("res://scenes/event_dialog.tscn")
const STATION_PANEL_SCENE: PackedScene = preload("res://scenes/station_panel.tscn")
const StoryProgressRef = preload("res://scripts/story_progress.gd")

## 站点门槛（DEMO_DESIGN §3）
const STATIONS: Array = [
	{"name": "白桦林站", "km": 80.0},
	{"name": "冻湖站", "km": 180.0},
	{"name": "铁岭口", "km": 300.0},
	{"name": "极光城", "km": 420.0},
]

## 资源条显示名（DEMO_DESIGN §2.1）
const RESOURCE_NAMES := {
	"food": "食物", "fuel": "燃料", "medicine": "药品",
	"parts": "零件", "ammo_small": "小弹药", "ammo_large": "大弹药",
}

## 车厢内交互点（2.5）：train_x = 相对列车内容（车厢拼装）的 x，local_y = 相对车厢地板线的 y（全部站在地板上）
const INTERACTION_POINTS: Array = [
	{"id": "boiler", "name": "锅炉", "train_x": 950.0, "local_y": 163.0, "color": Color(0.85, 0.35, 0.2), "action": "加煤"},
	{"id": "cargo", "name": "物资箱", "train_x": 1450.0, "local_y": 163.0, "color": Color(0.55, 0.4, 0.25), "action": "收集物资"},
	{"id": "repair", "name": "维修台", "train_x": 1680.0, "local_y": 163.0, "color": Color(0.45, 0.5, 0.55), "action": "维修"},
]
const INTERACTION_RADIUS: float = 50.0

# ===== 随车角色行走图映射（默认前 4 人）=====
const CREW_WALK_TEXTURES = {
	"conductor": "res://assets/sprites/characters_walk/conductor.png",
	"laoge": "res://assets/sprites/characters_walk/laoge.png",
	"xiaoliu": "res://assets/sprites/characters_walk/xiaoliu.png",
	"xiaowang": "res://assets/sprites/characters_walk/xiaowang.png",
}
const DEFAULT_CREW_IDS: Array = ["conductor", "laoge", "xiaowang", "xiaoliu"]
const MAX_CREW: int = 4

# 行走图是绿幕素材：用 shader 把绿色背景抠掉
const CHROMA_KEY_SHADER := """
shader_type canvas_item;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.g > 0.5 && c.g > 1.4 * max(c.r, c.b)) {
		c.a = 0.0;
	}
	COLOR = c;
}
"""

# 编队偏移（相对点击点）
const CREW_FORMATION: Array = [
	Vector2(0, 0),
	Vector2(-34, 10),
	Vector2(34, 10),
	Vector2(0, 26),
]

# ===== 可调参数 =====
@export var walk_speed: float = 250.0
@export var crew_target_height: float = 93.0
@export var floor_y_range: Vector2 = Vector2(430, 640)

# ===== 视差/列车状态 =====
var _layers: Array = []                 # [{container, tile_w, speed}]
var _view_w: float = 1280.0
var _view_h: float = 720.0
var _zoom: float = 1.0
var _target_zoom: float = 1.0
var _train_scroll: float = 0.0
var _train_total_w: float = 0.0
var _train_vehicle_sizes: Array = []   # [{type, w, tex, flipped}]
var _walkable_segments: Array = []     # [[x0, x1], ...] 屏幕坐标可通行区间
var _dragging_train: bool = false
var _drag_press_active: bool = false
var _drag_start_mouse_x: float = -1.0
var _drag_start_scroll: float = 0.0
var _drag_threshold_passed: bool = false
var _train_inertia: float = 0.0
var _prev_train_scroll: float = 0.0

# ===== 小队状态 =====
var _crew: Array = []          # [{id, name, sprite, formation_offset, target, is_moving}]
var _floor_y_min: float = 430.0
var _floor_y_max: float = 640.0
var _selected_crew_index: int = -1
var _selection_indicator: Polygon2D = null

# ===== 行驶状态（2.3）=====
var _distance_km: float = 0.0
var _travel_time: float = 0.0
var _breakdown_armed: bool = false
var _event_timer: float = 0.0
var _next_event_delay: float = 16.0
var _event_dialog: EventDialog = null
var _event_seed: int = 0
var _station_panel: StationPanel = null
var _station_collecting: bool = false
var _station_collect_timer: float = 0.0

# ===== 动作状态（2.4）=====
var _is_collecting: bool = false
var _collect_timer: float = 0.0
var _action_log: String = ""

# ===== HUD =====
var _resource_bars: Dictionary = {}
var _char_rows: Array = []
var _crew_select_buttons: Dictionary = {}
var _res_panel: Control = null
var _char_panel: Control = null

# ===== 交互点弹窗 =====
var _pending_interaction: String = ""
var _pending_crew_index: int = -1  # 触发交互的成员下标；-1=整队到达后弹
var _action_popup: PanelContainer = null
var _action_title: Label = null
var _action_button: Button = null
var _interaction_points: Array = []      # [{cfg, node}]，节点在最上层绘制，随列车内容坐标移动
var _train_band_top: float = 406.0
var _carriage_strips: Array = []         # 地板/天花板装饰带 [{node, top, bottom}]
var _story_tutorial_active := false
var _story_tutorial_moved := false
var _story_tutorial_interacted := false
var _story_tutorial_panel: PanelContainer = null
var _story_tutorial_label: Label = null
var _story_tutorial_button: Button = null

@onready var _world: Node2D = $World
@onready var _train_container: Control = $World/TrainContainer
@onready var _interaction_root: Node2D = $World/InteractionRoot
@onready var _crew_root: Node2D = $World/CrewRoot
@onready var _hud_status: Label = $HUD/TopBar/StatusLabel
@onready var _hud_carriage: Label = $HUD/TopBar/CarriageLabel
@onready var _hud_accel_btn: Button = $HUD/TopBar/AccelButton
@onready var _hud_brake_btn: Button = $HUD/TopBar/BrakeButton
@onready var _hud_zoom_out_btn: Button = $HUD/TopBar/ZoomBox/ZoomOutButton
@onready var _hud_zoom_reset_btn: Button = $HUD/TopBar/ZoomBox/ZoomResetButton
@onready var _hud_zoom_in_btn: Button = $HUD/TopBar/ZoomBox/ZoomInButton
@onready var _hud_back_btn: Button = $HUD/TopBar/BackButton


func _ready() -> void:
	_view_w = get_viewport().get_visible_rect().size.x
	_view_h = get_viewport().get_visible_rect().size.y
	AudioManager.play_bgm("travel")

	_ensure_crew_state()
	_setup_parallax()

	# ===== 2.3：接入列车系统 =====
	GameState.refresh_train_runtime_state()
	GameState.start_travel()
	# 重新进入登车页从停车开始，不能因为存档里有动力机车就自动加速
	GameState.train_control_mode = 0
	GameState.train["speed"] = 0.0
	_distance_km = GameState.route_distance_km
	_travel_time = GameState.travel_time
	_event_timer = 0.0
	_event_seed = int(Time.get_ticks_msec())
	_schedule_next_event()
	if GameState.train.get("carriages", []).is_empty():
		GameState.train_control_mode = 0

	# ===== 列车展示（先渲染：决定车厢区域与滚动基准）=====
	_render_train()
	_apply_zoom()  # 地板线已知后应用缩放锚点
	_setup_carriage_strips()
	_setup_crew()
	_setup_interaction_points()

	_hud_accel_btn.pressed.connect(_on_accel_button_pressed)
	_hud_brake_btn.pressed.connect(_on_brake_button_pressed)
	_hud_zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
	_hud_zoom_reset_btn.pressed.connect(_on_zoom_reset_pressed)
	_hud_zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
	_hud_back_btn.pressed.connect(_on_back_button_pressed)
	_build_hud()
	_update_hud()
	_setup_story_tutorial()
	if GameState.at_station:
		call_deferred("_show_station_panel", GameState.next_station_index)


## 保证 GameState.characters 至少有默认 4 人（角色状态结算的载体）
func _ensure_crew_state() -> void:
	if GameState.characters == null:
		GameState.characters = []
	var existing_ids: Dictionary = {}
	for c in GameState.characters:
		if c is Dictionary and c.has("id"):
			existing_ids[str(c["id"])] = true
	for cfg in CharacterData.get_default_team():
		if GameState.characters.size() >= MAX_CREW:
			break
		var id: String = str(cfg.get("id", ""))
		if id.is_empty() or existing_ids.has(id):
			continue
		GameState.characters.append(cfg.duplicate(true))
		existing_ids[id] = true


# ===== 雪原视差（survival 原版：Control 容器 + 平铺 + y_off）=====
func _setup_parallax() -> void:
	for i in range(PARALLAX_LAYERS.size()):
		var cfg: Dictionary = PARALLAX_LAYERS[i]
		var container: Control = _world.get_node("Layer%d%s" % [i, cfg["name"]])
		var tex: Texture2D = load(cfg["path"])
		if tex == null:
			push_error("travel.gd: 无法加载纹理 %s" % cfg["path"])
			continue

		var texture_scale: float = _view_h / tex.get_height()
		var display_w: float = tex.get_width() * texture_scale
		_spawn_tiles(container, tex, display_w, _view_h, cfg["y_off"])
		_layers.append({"container": container, "tile_w": display_w, "speed": cfg["speed"]})


func _spawn_tiles(container: Control, tex: Texture2D, display_w: float, display_h: float, y_off: float) -> void:
	for i in range(2):
		var sprite := TextureRect.new()
		sprite.texture = tex
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.offset_left = float(i) * display_w
		sprite.offset_right = float(i + 1) * display_w
		sprite.offset_top = y_off
		sprite.offset_bottom = y_off + display_h
		container.add_child(sprite)


func _scroll_layer(layer: Dictionary, scroll_delta: float, drag_delta: float) -> void:
	var children: Array = layer["container"].get_children()
	if children.is_empty():
		return
	var tile_w: float = layer["tile_w"]
	var speed_mul: float = layer["speed"]
	# 行驶偏移 + 拖拽视差（drag_delta 以地面速度为单位）
	var offset: float = scroll_delta * speed_mul + drag_delta * speed_mul / TRAIN_GROUND_SPEED
	var wrap_w: float = tile_w * 2.0
	for child in children:
		var sprite := child as Control
		if sprite == null:
			continue
		var x: float = sprite.offset_left + offset
		if x + tile_w < 0:
			x += wrap_w
		elif x > _view_w:
			x -= wrap_w
		sprite.offset_left = x
		sprite.offset_right = x + tile_w


# ===== 随车小队 =====
func _setup_crew() -> void:
	var ids: Array = []
	if GameState.characters != null:
		for c in GameState.characters:
			if ids.size() >= MAX_CREW:
				break
			var id: String = str(c.get("id", ""))
			if CREW_WALK_TEXTURES.has(id) and not ids.has(id):
				ids.append(id)
	for def_id in DEFAULT_CREW_IDS:
		if ids.size() >= MAX_CREW:
			break
		if not ids.has(def_id):
			ids.append(def_id)

	var base := Vector2(_view_w / 2.0, _floor_y_min - crew_target_height * 0.5)  # 角色中心 = 地板线 - 半身高
	var chroma := _make_chroma_key_material()
	var occupied_positions: Array = []
	for i in range(ids.size()):
		var id: String = ids[i]
		var tex: Texture2D = load(CREW_WALK_TEXTURES[id])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.name = "Crew_" + id
		s.texture = tex
		s.material = chroma
		var tex_scale: float = crew_target_height / tex.get_height()
		s.scale = Vector2(tex_scale, tex_scale)
		var default_spawn: Vector2 = _clamp_to_train(base + CREW_FORMATION[i])
		var spawn: Vector2 = default_spawn
		# 跨场景保留上次登车位置，避免返回后重新聚成一堆
		if GameState.crew_positions.has(id) and GameState.crew_positions[id] is Vector2:
			var saved_pos: Vector2 = GameState.crew_positions[id]
			if GameState.crew_positions_space == "train_content_v2":
				# 新档保存的是相对列车内容的 x，重新进入时叠加当前滚动偏移
				spawn = _clamp_to_train(Vector2(_train_scroll + saved_pos.x, saved_pos.y))
			else:
				# 兼容旧档：第一次仍按原屏幕坐标读取，退出时自动升级为 v2
				spawn = _clamp_to_train(saved_pos)
		# 旧存档可能把多人保存到同一点；只修复过近位置，正常的玩家站位保持不变
		if not _is_crew_spawn_clear(spawn, occupied_positions):
			spawn = _find_clear_crew_spawn(default_spawn, occupied_positions)
		occupied_positions.append(spawn)
		s.position = spawn
		s.z_index = 10
		_crew_root.add_child(s)
		var def := CharacterData.find_by_id(id)
		_crew.append({
			"id": id,
			"name": def.get("name", id),
			"sprite": s,
			"formation_offset": CREW_FORMATION[i],
			"target": spawn,
			"is_moving": false,
		})

	# 选中指示器（黄色三角，显示在当前选中角色头顶）
	_selection_indicator = Polygon2D.new()
	_selection_indicator.name = "SelectionIndicator"
	_selection_indicator.polygon = PackedVector2Array([
		Vector2(0, -52), Vector2(18, -28), Vector2(-18, -28),
	])
	_selection_indicator.color = Color(1, 0.85, 0.2, 0.95)
	_selection_indicator.z_index = 12
	_selection_indicator.visible = false
	_crew_root.add_child(_selection_indicator)


func _update_selection_indicator() -> void:
	if _selected_crew_index >= 0 and _selected_crew_index < _crew.size() and is_instance_valid(_selection_indicator):
		var sp: Sprite2D = _crew[_selected_crew_index]["sprite"]
		_selection_indicator.position = sp.position + Vector2(0, -crew_target_height * 0.5 - 6)
		_selection_indicator.visible = true
	else:
		if is_instance_valid(_selection_indicator):
			_selection_indicator.visible = false


func _is_crew_spawn_clear(candidate: Vector2, occupied_positions: Array) -> bool:
	for occupied in occupied_positions:
		if candidate.distance_to(occupied) < CREW_MIN_SEPARATION:
			return false
	return true


func _find_clear_crew_spawn(preferred: Vector2, occupied_positions: Array) -> Vector2:
	for x_offset in CREW_SPAWN_SEARCH_OFFSETS:
		var candidate := _clamp_to_train(Vector2(preferred.x + x_offset, preferred.y))
		if _is_crew_spawn_clear(candidate, occupied_positions):
			return candidate
	return _clamp_to_train(preferred)


func _set_selected_crew(index: int) -> void:
	if index >= 0 and index < _crew.size():
		_selected_crew_index = index if _selected_crew_index != index else -1
	else:
		_selected_crew_index = -1
	_update_selection_indicator()
	_update_crew_selection_ui()


func _on_crew_select_button_pressed(id: String) -> void:
	for i in range(_crew.size()):
		if str(_crew[i].get("id", "")) == id:
			_set_selected_crew(i)
			return


func _make_chroma_key_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CHROMA_KEY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## 地板/天花板装饰层：车厢区上下两条带，中间保留雪原视差；随列车内容坐标滚动
func _setup_carriage_strips() -> void:
	var band: Dictionary = _train_band()
	var defs := [
		{"name": "CeilingStrip", "top": band["top"] + CEILING_TOP_OFFSET, "bottom": band["top"] + CEILING_TOP_OFFSET + CEILING_HEIGHT, "color": Color(0.10, 0.12, 0.16, 0.7)},
		{"name": "FloorStrip", "top": band["bottom"] - FLOOR_BOTTOM_OFFSET - FLOOR_HEIGHT, "bottom": band["bottom"] - FLOOR_BOTTOM_OFFSET, "color": Color(0.08, 0.07, 0.06, 0.8)},
	]
	for d in defs:
		var poly := Polygon2D.new()
		poly.name = d["name"]
		poly.color = d["color"]
		poly.z_index = 7
		_world.add_child(poly)
		_carriage_strips.append({"node": poly, "top": d["top"], "bottom": d["bottom"]})


func _sync_carriage_strips() -> void:
	var x0: float = _train_scroll
	var x1: float = _train_scroll + _train_total_w
	for entry in _carriage_strips:
		var node = entry["node"]
		if not is_instance_valid(node):
			continue
		var top: float = entry["top"]
		var bottom: float = entry["bottom"]
		node.polygon = PackedVector2Array([
			Vector2(x0, top), Vector2(x1, top), Vector2(x1, bottom), Vector2(x0, bottom),
		])


# ===== 2.5 交互点（最上层绘制，坐标绑定列车内容）=====
func _setup_interaction_points() -> void:
	for cfg in INTERACTION_POINTS:
		var point := Node2D.new()
		point.name = "Point_" + cfg["id"]
		point.position = _interaction_screen_pos(cfg)
		_interaction_root.add_child(point)

		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(0, -34), Vector2(34, 0), Vector2(0, 34), Vector2(-34, 0),
		])
		poly.color = cfg["color"]
		point.add_child(poly)

		var label := Label.new()
		label.text = cfg["name"]
		label.position = Vector2(-30, -52)
		label.add_theme_font_size_override("font_size", 13)
		point.add_child(label)

		_interaction_points.append({"cfg": cfg, "node": point})


## 交互点在屏幕坐标系的位置（点击命中/弹窗定位用）
func _interaction_screen_pos(cfg: Dictionary) -> Vector2:
	return Vector2(_train_scroll + float(cfg["train_x"]), _train_band_top + float(cfg["local_y"]))


## 每帧把交互点钉在列车内容坐标上；滑出屏幕（列车可见区外）则隐藏
func _sync_interaction_points() -> void:
	for entry in _interaction_points:
		var cfg: Dictionary = entry["cfg"]
		var node = entry["node"]
		if not is_instance_valid(node):
			continue
		var pos: Vector2 = _interaction_screen_pos(cfg)
		node.position = pos
		node.visible = pos.x >= _local_visible_min_x() - 40.0 and pos.x <= _local_visible_max_x() + 40.0


func _show_action_popup(id: String) -> void:
	var cfg: Dictionary = {}
	for c in INTERACTION_POINTS:
		if c["id"] == id:
			cfg = c
			break
	if cfg.is_empty():
		return

	if _action_popup == null:
		_action_popup = PanelContainer.new()
		_action_popup.name = "ActionPopup"
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		_action_popup.add_child(vbox)
		_action_title = Label.new()
		_action_title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(_action_title)
		_action_button = Button.new()
		_action_button.custom_minimum_size = Vector2(160, 44)
		vbox.add_child(_action_button)
		var close_btn := Button.new()
		close_btn.text = "关闭"
		close_btn.custom_minimum_size = Vector2(160, 40)
		close_btn.pressed.connect(_hide_action_popup)
		vbox.add_child(close_btn)
		$HUD.add_child(_action_popup)

	_action_title.text = cfg["name"]
	_action_button.text = cfg["action"]
	if _action_button.pressed.is_connected(_on_action_button_pressed):
		_action_button.pressed.disconnect(_on_action_button_pressed)
	_action_button.pressed.connect(_on_action_button_pressed.bind(id))
	var popup_pos: Vector2 = _local_to_screen(_interaction_screen_pos(cfg)) + Vector2(-80, -150)
	popup_pos.x = clampf(popup_pos.x, 12, 1180)
	popup_pos.y = clampf(popup_pos.y, 12, 560)
	_action_popup.position = popup_pos
	_action_popup.visible = true


func _hide_action_popup() -> void:
	if _action_popup != null:
		_action_popup.visible = false


# ===== Day 3：随机事件 =====
func _schedule_next_event() -> void:
	_next_event_delay = randf_range(12.0, 20.0)
	_event_timer = 0.0


func _trigger_random_event() -> void:
	_event_seed += 31
	var roll := fposmod(float(_event_seed * 1103515245 + 12345), 100000.0) / 100000.0
	_trigger_event(EventSystem.pick_event_by_roll(roll))


## Debug-only / MCP 验收入口：正式运行仍由随机计时触发。
func debug_trigger_event(event_id: String) -> void:
	_trigger_event(EventsData.get_event(event_id))


func _trigger_event(event_data: Dictionary) -> void:
	if event_data.is_empty() or _event_dialog != null or _station_panel != null or GameState.at_station:
		return
	_event_timer = 0.0
	var dialog := EVENT_DIALOG_SCENE.instantiate() as EventDialog
	if dialog == null:
		_action_log = "事件面板加载失败"
		return
	_event_dialog = dialog
	dialog.name = "EventDialog"
	dialog.choice_selected.connect(_on_event_choice_selected)
	$HUD.add_child(dialog)
	dialog.position = Vector2((_view_w - dialog.custom_minimum_size.x) * 0.5, 220.0)
	dialog.setup(event_data)
	AudioManager.play_event()


func _on_event_choice_selected(event_id: String, choice_id: String) -> void:
	var result := GameState.apply_event_choice(event_id, choice_id, _event_seed)
	if result.get("ok", false):
		_action_log = str(result.get("message", "事件已处理"))
	else:
		_action_log = str(result.get("message", "事件处理失败"))
	GameState.save_state()
	if _event_dialog != null:
		_event_dialog.queue_free()
		_event_dialog = null
	_schedule_next_event()


## ===== Day 3：站点面板与里程节点 =====
func _check_station_arrival(previous_distance: float, current_distance: float) -> void:
	if GameState.at_station:
		return
	var station_index := GameState.next_station_index
	if not StationSystem.should_arrive(current_distance, station_index):
		return
	var station := StationSystem.get_station(station_index)
	if station.is_empty():
		return
	GameState.at_station = true
	AudioManager.play_arrive()
	GameState.current_station_id = str(station.get("id", "station"))
	GameState.current_node = str(station.get("id", "station"))
	GameState.station_collected = false
	GameState.train_control_mode = 2
	GameState.train["speed"] = 0.0
	_show_station_panel(station_index)
	_action_log = "已到达 %s" % str(station.get("name", "站点"))
	GameState.save_state()


## Debug-only / MCP 验收入口：直接打开指定站点面板。
func debug_open_station(station_index: int = 0) -> void:
	GameState.next_station_index = clampi(station_index, 0, StationData.get_all().size() - 1)
	GameState.at_station = true
	GameState.train_control_mode = 0
	GameState.train["speed"] = 0.0
	_show_station_panel(GameState.next_station_index)


func _show_station_panel(station_index: int) -> void:
	if _station_panel != null:
		return
	var station := StationSystem.get_station(station_index)
	if station.is_empty():
		return
	_station_panel = STATION_PANEL_SCENE.instantiate() as StationPanel
	if _station_panel == null:
		return
	_station_panel.name = "StationPanel"
	_station_panel.action_selected.connect(_on_station_action_selected)
	$HUD.add_child(_station_panel)
	_station_panel.position = Vector2((_view_w - _station_panel.custom_minimum_size.x) * 0.5, 350.0)
	_station_panel.setup(station, station_index)


func _on_station_action_selected(action_id: String) -> void:
	if _station_panel == null or not GameState.at_station:
		return
	var station_index := GameState.next_station_index
	match action_id:
		"collect":
			if GameState.station_collected or _station_collecting:
				_station_panel.set_message("本站物资已经收集过了。")
				return
			_station_collecting = true
			_station_collect_timer = 0.0
			_station_panel.set_actions_enabled(false)
			_station_panel.set_message("正在收集物资，请稍候 5 秒。")
		"repair":
			_do_station_repair(station_index)
		"supply":
			var supply_result := StationSystem.supply_result(GameState.resources, station_index)
			_station_panel.set_message(str(supply_result.get("message", "补给失败")))
			_update_hud()
		"continue":
			_continue_from_station(station_index)


func _complete_station_collection() -> void:
	_station_collecting = false
	_station_collect_timer = 0.0
	AudioManager.play_collect()
	var reward := StationSystem.collect_reward(int(Time.get_ticks_msec()))
	GameState.add_resource("food", int(reward.get("food", 0)))
	GameState.add_resource("fuel", int(reward.get("fuel", 0)))
	GameState.station_collected = true
	if _station_panel != null:
		_station_panel.set_message("收集完成：食物 +%d，燃料 +%d" % [reward["food"], reward["fuel"]])
		_station_panel.set_actions_enabled(true)
	GameState.save_state()


func _do_station_repair(station_index: int) -> void:
	var cost := StationSystem.repair_cost(station_index)
	var hp := float(GameState.train.get("health", 100.0))
	if hp >= float(GameState.train.get("max_health", 100.0)):
		_station_panel.set_message("列车 HP 已经满了。")
		return
	if not GameState.consume_resource("parts", cost):
		_station_panel.set_message("零件不足（需要 %d）" % cost)
		return
	GameState.set_train_health(minf(hp + GameConfig.REPAIR_MINOR_AMOUNT, float(GameState.train.get("max_health", 100.0))))
	_station_panel.set_message("维修完成：列车 HP +%d，零件 -%d" % [GameConfig.REPAIR_MINOR_AMOUNT, cost])
	_update_hud()


func _continue_from_station(station_index: int) -> void:
	AudioManager.play_depart()
	var next := StationSystem.continue_from_station(station_index, GameState.route_lap)
	GameState.next_station_index = int(next.get("next_station_index", 0))
	GameState.route_lap = int(next.get("route_lap", GameState.route_lap))
	_distance_km = float(next.get("route_distance_km", 0.0))
	GameState.route_distance_km = _distance_km
	GameState.current_station_id = "station_start"
	GameState.current_node = "route_lap_%d" % GameState.route_lap
	GameState.at_station = false
	GameState.station_collected = false
	GameState.train_control_mode = 0
	_station_collecting = false
	_station_collect_timer = 0.0
	if _station_panel != null:
		_station_panel.queue_free()
		_station_panel = null
	_schedule_next_event()
	_action_log = "离开站点，前往下一站"
	GameState.save_state()


func _on_action_button_pressed(id: String) -> void:
	var actor_index: int = _pending_crew_index
	if actor_index < 0 or actor_index >= _crew.size():
		actor_index = _selected_crew_index
	var actor_id: String = _crew[actor_index]["id"] if actor_index >= 0 and actor_index < _crew.size() else ""
	var actor: Dictionary = _find_character_by_id(actor_id)
	if not actor.is_empty() and float(actor.get("stamina", 0.0)) <= 0.0:
		_action_log = "体力耗尽，无法操作交互点"
		return
	match id:
		"boiler":
			AudioManager.play_click()
			_do_refuel()
		"cargo":
			AudioManager.play_click()
			_start_collect()
		"repair":
			AudioManager.play_repair()
			_do_repair()
	_hide_action_popup()
	if _story_tutorial_active:
		_story_tutorial_interacted = true
		_update_story_tutorial()


func _setup_story_tutorial() -> void:
	var progress := StoryProgressRef.load_progress()
	_story_tutorial_active = GameState.game_mode == "story" and int(progress.get("current_level", 1)) == 1
	if not _story_tutorial_active:
		return
	_story_tutorial_panel = PanelContainer.new()
	_story_tutorial_panel.name = "StoryTutorialPanel"
	_story_tutorial_panel.position = Vector2(420, 120)
	_story_tutorial_panel.custom_minimum_size = Vector2(440, 160)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_story_tutorial_panel.add_child(box)
	var title := Label.new()
	title.text = "关卡 1「出发」教学"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_story_tutorial_label = Label.new()
	_story_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_story_tutorial_label)
	_story_tutorial_button = Button.new()
	_story_tutorial_button.text = "前往关卡 2"
	_story_tutorial_button.custom_minimum_size = Vector2(0, 44)
	_story_tutorial_button.visible = false
	_story_tutorial_button.pressed.connect(_finish_story_tutorial)
	box.add_child(_story_tutorial_button)
	$HUD.add_child(_story_tutorial_panel)
	_update_story_tutorial()


func _update_story_tutorial() -> void:
	if not _story_tutorial_active or _story_tutorial_label == null:
		return
	var move_mark := "完成" if _story_tutorial_moved else "待完成"
	var interact_mark := "完成" if _story_tutorial_interacted else "待完成"
	var accel_mark := "完成" if GameState.train_control_mode == 1 else "待完成"
	_story_tutorial_label.text = "点击空白区域让一名队员移动：%s\n完成一次车内交互：%s\n按下“加速”让列车启动：%s" % [move_mark, interact_mark, accel_mark]
	var complete := _story_tutorial_moved and _story_tutorial_interacted and GameState.train_control_mode == 1
	_story_tutorial_button.visible = complete
	if complete:
		_story_tutorial_label.text += "\n教学完成，可以进入下一关。"


func _finish_story_tutorial() -> void:
	if not (_story_tutorial_moved and _story_tutorial_interacted and GameState.train_control_mode == 1):
		return
	StoryProgressRef.complete_level(1)
	GameState.stop_travel()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


# ===== 输入：统一「click」动作 + 列车拖拽浏览 =====
func _unhandled_input(event: InputEvent) -> void:
	if _event_dialog != null or _station_panel != null:
		return
	# 鼠标滚轮缩放（世界内容）
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_zoom_in_pressed()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_zoom_out_pressed()
			return

	var pos_variant: Variant = event.get("position")
	var pos: Vector2 = pos_variant if pos_variant is Vector2 else Vector2.ZERO
	# 屏幕坐标 → 世界局部坐标（画面缩放后内部逻辑仍用局部坐标）
	var local: Vector2 = _screen_to_local(pos)

	if event.is_action_pressed("click"):
		_on_click_pressed(local)
	elif event.is_action_released("click"):
		_on_click_released(local)
	elif event is InputEventMouseMotion and _drag_press_active:
		_handle_drag_motion(local.x)


func _on_click_pressed(pos: Vector2) -> void:
	_drag_press_active = true
	_drag_start_mouse_x = pos.x
	_drag_start_scroll = _train_scroll
	_drag_threshold_passed = false
	_dragging_train = false
	_train_inertia = 0.0


func _on_click_released(pos: Vector2) -> void:
	# 没拖拽 → 这是一次点击：小队走过去（点击交互点则弹操作按钮）
	if _drag_press_active and not _dragging_train:
		_command_move(pos)
	_drag_press_active = false
	_dragging_train = false
	_drag_start_mouse_x = -1.0
	_drag_threshold_passed = false


func _handle_drag_motion(mouse_x: float) -> void:
	if not _drag_press_active or _drag_start_mouse_x < 0.0:
		return
	# 仅当列车比屏幕宽时才能拖拽浏览全貌
	if _train_total_w <= _view_w:
		return
	if not _dragging_train and abs(mouse_x - _drag_start_mouse_x) > DRAG_THRESHOLD:
		_dragging_train = true
		_drag_threshold_passed = true
	if _dragging_train:
		var prev_scroll: float = _train_scroll
		_train_scroll = _drag_start_scroll + (mouse_x - _drag_start_mouse_x) * TRAIN_GROUND_SPEED
		_train_inertia = _train_scroll - prev_scroll
		_clamp_train_scroll()
		_refresh_train_sprites()


func _command_move(point: Vector2) -> void:
	_pending_interaction = ""
	_pending_crew_index = -1
	_hide_action_popup()

	# 点选/取消选中角色：点击某个小人（40px 内）只切换选择，不移动、不打断其他人当前移动
	var best_i: int = -1
	var best_d: float = 40.0
	for i in range(_crew.size()):
		var d: float = point.distance_to(_crew[i]["sprite"].position)
		if d < best_d:
			best_d = d
			best_i = i
	if best_i >= 0:
		_set_selected_crew(best_i)
		return

	# 点击交互点附近 → 记住目标交互点，到达后弹操作按钮
	var hit_id: String = ""
	for entry in _interaction_points:
		var cfg: Dictionary = entry["cfg"]
		if point.distance_to(_interaction_screen_pos(cfg)) <= INTERACTION_RADIUS:
			hit_id = cfg["id"]
			break

	var target: Vector2 = _clamp_to_train(point)
	if _story_tutorial_active:
		_story_tutorial_moved = true
		_update_story_tutorial()

	if _selected_crew_index >= 0 and _selected_crew_index < _crew.size():
		# 只给当前选中的角色下达独立目标（其他人继续各自移动）
		var member: Dictionary = _crew[_selected_crew_index]
		member["target"] = target
		member["is_moving"] = true
		if hit_id != "":
			_pending_interaction = hit_id
			_pending_crew_index = _selected_crew_index
	else:
		# 未选中：自动把控制权交给距离目标最近的小人，禁止空白点击触发集群移动
		var nearest_i: int = _nearest_crew_index(target)
		if nearest_i < 0:
			return
		_set_selected_crew(nearest_i)
		var nearest_member: Dictionary = _crew[nearest_i]
		nearest_member["target"] = target
		nearest_member["is_moving"] = true
		if hit_id != "":
			_pending_interaction = hit_id
			_pending_crew_index = nearest_i


func _nearest_crew_index(point: Vector2) -> int:
	var best_i: int = -1
	var best_distance: float = INF
	for i in range(_crew.size()):
		var sprite: Sprite2D = _crew[i]["sprite"]
		var distance: float = point.distance_to(sprite.position)
		if distance < best_distance:
			best_distance = distance
			best_i = i
	return best_i


## 把目标点钳制到列车内部可通行区：x 在「列车内容 ∩ 屏幕可见（局部）」内再吸附到最近可通行段，y 固定地板线
func _clamp_to_train(p: Vector2) -> Vector2:
	var margin: float = 60.0
	var min_x: float = maxf(_train_scroll + margin, _local_visible_min_x())
	var max_x: float = minf(_train_scroll + _train_total_w - margin, _local_visible_max_x())
	if max_x < min_x:
		min_x = _local_visible_min_x()
		max_x = _local_visible_max_x()
	var visible_x: float = clampf(p.x, min_x, max_x)
	return Vector2(
		_nearest_walkable_x(visible_x),
		_floor_y_min - crew_target_height * 0.5,
	)


# ===== 主循环 =====
func _process(delta: float) -> void:
	# 0. 缩放非线性动画（平滑趋近目标缩放）
	if absf(_target_zoom - _zoom) > 0.001:
		_zoom = lerp(_zoom, _target_zoom, 1.0 - exp(-ZOOM_ANIM_SPEED * delta))
		if absf(_target_zoom - _zoom) < 0.001:
			_zoom = _target_zoom
		_apply_zoom()

	# 1. 事件/站点面板打开时暂停世界推进，避免操作期间继续消耗资源。
	if _event_dialog != null:
		_update_hud()
		return
	if _station_panel != null:
		if _station_collecting:
			_station_collect_timer += delta
			_station_panel.set_collect_progress(_station_collect_timer / GameConfig.STATION_COLLECT_DURATION)
			if _station_collect_timer >= GameConfig.STATION_COLLECT_DURATION:
				_complete_station_collection()
		_update_hud()
		return

	# 2. 世界推进
	var crew_count: int = _crew.size() if not _crew.is_empty() else (GameState.characters.size() if GameState.characters != null else 0)
	if _story_tutorial_active:
		# 教学保留真实加速/刹车物理，但冻结资源与角色状态消耗。
		var tutorial_resources := GameState.resources.duplicate(true)
		var tutorial_characters := GameState.characters.duplicate(true)
		GameState.tick_world(delta, crew_count)
		GameState.resources = tutorial_resources
		GameState.characters = tutorial_characters
		GameState.world_consume_time = 0.0
	else:
		GameState.tick_world(delta, crew_count)
	var train_speed: float = GameState.get_train_speed()
	if GameState.is_traveling:
		_travel_time += delta
	GameState.travel_time = _travel_time
	if train_speed > 0.01:
		# Day 6：里程按游戏内时间折算（现实 1 秒 = 游戏 TIME_COMPRESSION 秒），
		# 使 420km 单程在 30~60 现实分钟内完成（全速约 23 分钟、均速约 42 分钟/圈）。
		var distance_delta := train_speed * GameConfig.TIME_COMPRESSION * delta / 1000.0
		_distance_km += distance_delta
		GameState.route_distance_km = _distance_km
		GameState.total_distance_km += distance_delta
		_check_station_arrival(_distance_km - distance_delta, _distance_km)

	# 行驶中的随机事件；事件面板或站点面板打开时不触发。
	if not _story_tutorial_active and GameState.is_traveling and not GameState.at_station and _event_dialog == null and _station_panel == null and train_speed > 0.01:
		_event_timer += delta
		if _event_timer >= _next_event_delay:
			_trigger_random_event()

	# 3. 拖拽惯性
	if not _dragging_train and abs(_train_inertia) > 0.3:
		_train_scroll += _train_inertia
		_train_inertia *= INERTIA_DECAY
		if abs(_train_inertia) < 0.3:
			_train_inertia = 0.0
		_clamp_train_scroll()
		_refresh_train_sprites()

	# 4. 拖拽视差量（同步给所有视差层与小队）
	var drag_delta: float = _train_scroll - _prev_train_scroll
	_prev_train_scroll = _train_scroll

	var scroll_delta: float = train_speed * SCROLL_SPEED_FACTOR * delta
	for layer in _layers:
		_scroll_layer(layer, scroll_delta, drag_delta)

	# 交互点/地板天花板钉在列车内容坐标；小队跟随列车拖拽等量位移。
	_sync_interaction_points()
	_sync_carriage_strips()
	if abs(drag_delta) > 0.001:
		for member in _crew:
			(member["sprite"] as Sprite2D).position.x += drag_delta
			member["target"].x += drag_delta
		_update_selection_indicator()

	# 5. 抛锚检测 + 收集进度 + HUD
	_check_breakdown()
	if _is_collecting:
		_collect_timer += delta
		if _collect_timer >= GameConfig.COLLECT_DURATION:
			_complete_collection()
	_check_survival_settlement()
	_update_hud()

	# 6. 每个小人独立移动（各自目标互不干扰；A 移动时点选 B 不会打断 A）
	for i in range(_crew.size()):
		var member: Dictionary = _crew[i]
		if not member["is_moving"]:
			continue
		var sprite: Sprite2D = member["sprite"]
		var target: Vector2 = member["target"]
		var pos: Vector2 = sprite.global_position
		var dist: float = pos.distance_to(target)
		if dist < 4.0:
			sprite.global_position = target
			member["is_moving"] = false
			if _pending_crew_index == i and _pending_interaction != "":
				_show_action_popup(_pending_interaction)
				_pending_interaction = ""
				_pending_crew_index = -1
		else:
			var dir: Vector2 = (target - pos).normalized()
			sprite.flip_h = dir.x < 0
			sprite.global_position = _move_toward_eased(pos, target, delta)

	# 整队模式（无选中）的交互：所有人到齐后弹窗
	if _pending_crew_index == -1 and _pending_interaction != "":
		var all_done := true
		for m in _crew:
			if m["is_moving"]:
				all_done = false
				break
		if all_done:
			_show_action_popup(_pending_interaction)
			_pending_interaction = ""
			_pending_crew_index = -1

	_update_selection_indicator()


## 非线性移动：接近目标时按剩余距离减速（缓出）
func _move_toward_eased(pos: Vector2, target: Vector2, delta: float) -> Vector2:
	var dist: float = pos.distance_to(target)
	if dist <= 0.01:
		return target
	var factor: float = clampf(dist / 120.0, 0.15, 1.0)
	var step: float = walk_speed * factor * delta
	if step >= dist:
		return target
	return pos + (target - pos).normalized() * step


# ===== 列车展示（survival 原版：车厢精灵渲染 + 裁剪 + 拖拽）=====
func _train_band() -> Dictionary:
	var train_height: float = _view_h * TRAIN_HEIGHT_RATIO
	var train_bottom: float = _view_h * TRAIN_BOTTOM_RATIO + TRAIN_BOTTOM_OFFSET
	return {"top": train_bottom - train_height, "bottom": train_bottom, "height": train_height}


# ===== 画面缩放（世界缩放，HUD 固定）=====
func _apply_zoom() -> void:
	if _world == null:
		return
	# 锚点：水平仍以屏幕中心为基准；垂直以地板线为基准（缩放时地板保持不动）
	_world.position = Vector2(_view_w * 0.5, _floor_y_min) * (1.0 - _zoom)
	_world.scale = Vector2(_zoom, _zoom)


func _screen_to_local(p: Vector2) -> Vector2:
	return _world.to_local(p) if _world != null else p


func _local_to_screen(p: Vector2) -> Vector2:
	return _world.to_global(p) if _world != null else p


func _local_visible_min_x() -> float:
	return _view_w * 0.5 - _view_w / (2.0 * _zoom)


func _local_visible_max_x() -> float:
	return _view_w * 0.5 + _view_w / (2.0 * _zoom)


func _on_zoom_in_pressed() -> void:
	_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func _on_zoom_out_pressed() -> void:
	_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func _on_zoom_reset_pressed() -> void:
	_target_zoom = 1.0


func _render_train() -> void:
	var carriages: Array = GameState.train.get("carriages", [])
	if carriages.is_empty():
		_train_container.visible = false
		return

	_train_container.visible = true
	var band: Dictionary = _train_band()
	_train_band_top = band["top"]
	# Control 挂在 Node2D 下时锚点不会拉伸，必须显式设置四边，否则 clip 宽度为 0 会把车厢全部裁掉
	_train_container.offset_left = 0.0
	_train_container.offset_right = _view_w
	_train_container.offset_top = band["top"]
	_train_container.offset_bottom = band["bottom"]
	_train_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 小人只能在地板线上水平行走（当前无梯子，禁止垂直移动）；脚线 = 地板条上沿
	_floor_y_min = band["bottom"] - FLOOR_BOTTOM_OFFSET - FLOOR_HEIGHT
	_floor_y_max = _floor_y_min

	var vehicle_sizes: Array = _compute_vehicle_sizes()
	if vehicle_sizes.is_empty():
		return

	_train_vehicle_sizes = vehicle_sizes
	_train_total_w = 0.0
	for v in vehicle_sizes:
		_train_total_w += v["w"]

	_train_scroll = (_view_w - _train_total_w) / 2.0
	_rebuild_walkable_segments()
	_prev_train_scroll = _train_scroll
	_apply_train_positions(vehicle_sizes, band["height"])


## 统一计算各车厢精灵尺寸（含类型，供可通行区间使用）
func _compute_vehicle_sizes() -> Array:
	var band: Dictionary = _train_band()
	var carriages: Array = GameState.train.get("carriages", [])
	var sizes: Array = []
	for c in carriages:
		var type_str: String = str(c.get("type", ""))
		var vtype = VehicleTypes.STR_TYPE.get(type_str)
		if vtype == null:
			continue
		var tex: Texture2D = load(VehicleTypes.CONFIG[vtype]["vehicle_path"])
		if tex == null:
			continue
		var texture_scale: float = band["height"] / tex.get_height()
		sizes.append({
			"type": type_str,
			"tex": tex,
			"w": tex.get_width() * texture_scale,
			"flipped": bool(c.get("flipped", false)),
		})
	return sizes


## 可通行区间：普通车厢整节可走；机车只允许司机室（未翻转=右端 33%，翻转=左端 33%），锅炉段禁止过人
func _rebuild_walkable_segments() -> void:
	_walkable_segments.clear()
	var x: float = _train_scroll
	for v in _train_vehicle_sizes:
		var w: float = v["w"]
		if v["type"] == "locomotive":
			if bool(v["flipped"]):
				_walkable_segments.append([x, x + w * LOCO_CAB_RATIO])
			else:
				_walkable_segments.append([x + w * (1.0 - LOCO_CAB_RATIO), x + w])
		else:
			_walkable_segments.append([x, x + w])
		x += w


## 返回离 target_x 最近的可通行 x（只考虑屏幕内可见的可通行段，世界局部坐标）
func _nearest_walkable_x(target_x: float) -> float:
	if _walkable_segments.is_empty():
		return target_x
	var visible_min: float = _local_visible_min_x()
	var visible_max: float = _local_visible_max_x()
	var best_x: float = target_x
	var best_dist: float = INF
	for seg in _walkable_segments:
		var lo: float = maxf(seg[0], visible_min)
		var hi: float = minf(seg[1], visible_max)
		if lo > hi:
			continue  # 该段当前完全在屏幕外，不吸附
		if target_x >= lo and target_x <= hi:
			return target_x
		var dist: float = 0.0
		if target_x < lo:
			dist = lo - target_x
		else:
			dist = target_x - hi
		if dist < best_dist:
			best_dist = dist
			best_x = clampf(target_x, lo, hi)
	if best_dist == INF:
		return clampf(target_x, visible_min, visible_max)
	return best_x


func _apply_train_positions(vehicle_sizes: Array, train_height: float) -> void:
	# 只清车厢精灵（TextureRect），保留 InteractionRoot 等挂载在列车容器内的节点
	for child in _train_container.get_children():
		if child is TextureRect:
			child.queue_free()

	var current_x: float = _train_scroll
	for v in vehicle_sizes:
		var sprite := TextureRect.new()
		sprite.texture = v["tex"]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.flip_h = v["flipped"]
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.offset_left = current_x
		sprite.offset_right = current_x + v["w"]
		sprite.offset_top = 0.0
		sprite.offset_bottom = train_height
		_train_container.add_child(sprite)
		current_x += v["w"]


func _clamp_train_scroll() -> void:
	if _train_total_w <= _view_w:
		_train_scroll = (_view_w - _train_total_w) / 2.0
	else:
		_train_scroll = clamp(_train_scroll, _view_w / 2.0 - _train_total_w, _view_w / 2.0)


func _refresh_train_sprites() -> void:
	if GameState.train.get("carriages", []).is_empty():
		return
	var band: Dictionary = _train_band()
	var vehicle_sizes: Array = _compute_vehicle_sizes()
	if vehicle_sizes.is_empty():
		return
	_train_vehicle_sizes = vehicle_sizes
	_train_total_w = 0.0
	for v in vehicle_sizes:
		_train_total_w += v["w"]
	_rebuild_walkable_segments()
	_apply_train_positions(vehicle_sizes, band["height"])


# ===== 2.3 行驶系统：抛锚 / HUD / 控制 =====
func _check_breakdown() -> void:
	if not GameState.is_traveling:
		return
	var has_power: bool = GameState.has_powered_locomotive()
	if has_power:
		_breakdown_armed = true
		return
	if _breakdown_armed and GameState.get_train_speed() <= 0.05:
		_breakdown_armed = false
		GameState.breakdown_count += 1
		GameState.train_control_mode = 0
		GameState.save_state()
		print("[DEBUG travel._check_breakdown] 燃料耗尽抛锚！breakdown_count=%d" % GameState.breakdown_count)


func _check_survival_settlement() -> void:
	if GameState.settlement_active or not GameState.is_traveling:
		return
	var state := {
		"game_mode": GameState.game_mode,
		"breakdown_count": GameState.breakdown_count,
		"train_health": float(GameState.train.get("health", 100.0)),
		"characters": GameState.characters,
		"total_distance_km": GameState.total_distance_km,
		"travel_time": GameState.travel_time,
		"resources": GameState.resources,
	}
	var reason := SettlementSystem.get_survival_failure_reason(state)
	if reason.is_empty():
		return
	GameState.settlement_active = true
	GameState.settlement_result = SettlementSystem.build_result(reason, state)
	GameState.stop_travel()
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/defeat.tscn")


## Debug-only / MCP 验收入口：注入三类生存失败边界。
func debug_trigger_settlement(reason: String) -> void:
	GameState.is_traveling = true
	match reason:
		"breakdown_limit":
			GameState.breakdown_count = 3
		"train_destroyed":
			GameState.train["health"] = 0.0
		"crew_down":
			for character in GameState.characters:
				character["health"] = 0.0
	_check_survival_settlement()


func _update_hud() -> void:
	var speed_kmh: int = int(GameState.get_train_speed() * 3.6)
	var mode_names: Dictionary = {0: "滑行", 1: "加速", 2: "刹车"}
	var fuel: int = GameState.get_resource("fuel")
	var power: String = "有" if GameState.has_powered_locomotive() else "无"
	var next_station: String = _next_station_text()
	_hud_status.text = "速度 %d km/h | 里程 %.1f km | 燃料 %d | 动力 %s | 抛锚 %d | %s | %s" % [
		speed_kmh, _distance_km, fuel, power, GameState.breakdown_count,
		mode_names.get(GameState.train_control_mode, "?"), next_station]
	if _action_log != "":
		_hud_status.text += "\n" + _action_log
	var control_text := "自动选最近"
	if _selected_crew_index >= 0 and _selected_crew_index < _crew.size():
		control_text = str(_crew[_selected_crew_index].get("name", "当前角色"))
	_hud_carriage.text = "%s | 当前控制：%s" % [_carriage_composition_text(), control_text]
	_hud_accel_btn.text = "滑行" if GameState.train_control_mode == 1 else "加速"
	_hud_brake_btn.text = "松开刹车" if GameState.train_control_mode == 2 else "刹车"
	_update_resource_bars()
	_update_character_rows()
	_update_crew_selection_ui()


func _carriage_composition_text() -> String:
	var type_names: Dictionary = {
		"locomotive": "机车", "coal_tender": "煤水车", "passenger": "客车",
		"open_car": "敞车", "tank_car": "罐车", "service_car": "勤务", "combat_car": "战斗",
	}
	var carriages: Array = GameState.train.get("carriages", [])
	if carriages.is_empty():
		return "编组: 无（请先到编组界面配置列车）"
	var names: Array = []
	for c in carriages:
		names.append(str(type_names.get(str(c.get("type", "?")), "?")))
	return "编组(%d节): %s" % [carriages.size(), " ".join(names)]


func _next_station_text() -> String:
	if GameState.train.get("carriages", []).is_empty() or GameState.at_station:
		return "下一站: --"
	var station := StationSystem.get_station(GameState.next_station_index)
	if station.is_empty():
		return "下一站: --"
	return "下一站: %s (余 %.0f km)" % [station["name"], float(station["km"]) - _distance_km]


func _build_hud() -> void:
	_res_panel = GridContainer.new()
	_res_panel.name = "ResourcePanel"
	_res_panel.columns = 3
	_res_panel.position = Vector2(880, 12)
	_res_panel.add_theme_constant_override("h_separation", 8)
	_res_panel.add_theme_constant_override("v_separation", 4)
	$HUD.add_child(_res_panel)

	for key in RESOURCE_NAMES.keys():
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(126, 46)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(126, 14)
		bar.max_value = 1000
		bar.show_percentage = false
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(bar)
		vbox.add_child(label)
		_res_panel.add_child(vbox)
		_resource_bars[key] = {"bar": bar, "label": label}

	_char_panel = VBoxContainer.new()
	_char_panel.name = "CharacterPanel"
	_char_panel.position = Vector2(880, 120)
	_char_panel.custom_minimum_size = Vector2(390, 0)
	_char_panel.add_theme_constant_override("separation", 4)
	$HUD.add_child(_char_panel)

	for member in _crew:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var crew_id := str(member.get("id", ""))
		var select_button := Button.new()
		select_button.text = str(member.get("name", "?"))
		select_button.custom_minimum_size = Vector2(56, 22)
		select_button.toggle_mode = true
		select_button.focus_mode = Control.FOCUS_NONE
		select_button.tooltip_text = "选择控制：%s" % str(member.get("name", "?"))
		select_button.pressed.connect(_on_crew_select_button_pressed.bind(crew_id))
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(120, 14)
		hp_bar.max_value = 100.0
		hp_bar.show_percentage = false
		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(190, 20)
		status_label.add_theme_font_size_override("font_size", 11)
		row.add_child(select_button)
		row.add_child(hp_bar)
		row.add_child(status_label)
		_char_panel.add_child(row)
		_char_rows.append({"id": crew_id, "hp_bar": hp_bar, "status_label": status_label})
		_crew_select_buttons[crew_id] = select_button
	_update_crew_selection_ui()


func _update_crew_selection_ui() -> void:
	for i in range(_crew.size()):
		var id := str(_crew[i].get("id", ""))
		var select_button = _crew_select_buttons.get(id)
		if select_button is Button:
			(select_button as Button).button_pressed = i == _selected_crew_index


func _update_resource_bars() -> void:
	for key in _resource_bars.keys():
		var entry: Dictionary = _resource_bars[key]
		var val: int = GameState.get_resource(key)
		(entry["bar"] as ProgressBar).value = val
		(entry["label"] as Label).text = "%s %d" % [RESOURCE_NAMES.get(key, key), val]


func _update_character_rows() -> void:
	for row in _char_rows:
		var c: Dictionary = _find_character_by_id(row["id"])
		if c.is_empty():
			c = CharacterData.find_by_id(row["id"])
		if c.is_empty():
			continue
		(row["hp_bar"] as ProgressBar).max_value = float(c.get("max_health", 100.0))
		(row["hp_bar"] as ProgressBar).value = float(c.get("health", 0.0))
		(row["status_label"] as Label).text = "HP %d/%d | 饥饿%d 体温%d 体力%d" % [
			int(c.get("health", 0.0)), int(c.get("max_health", 100.0)),
			int(c.get("hunger", 50.0)), int(c.get("temperature", 90.0)),
			int(c.get("stamina", 100.0))]


func _find_character_by_id(id: String) -> Dictionary:
	for c in GameState.characters:
		if str(c.get("id", "")) == id:
			return c
	return {}


func _on_accel_button_pressed() -> void:
	if GameState.train_control_mode == 1:
		GameState.train_control_mode = 0
		AudioManager.play_brake()
		return
	GameState.refresh_train_runtime_state()
	if not GameState.has_powered_locomotive():
		print("[DEBUG travel._on_accel_button_pressed] 无动力机车：需要机车+煤水车+燃料")
		_action_log = "无动力：需要机车+煤水车+燃料"
		return
	GameState.train_control_mode = 1
	AudioManager.play_whistle()
	_breakdown_armed = true
	if _story_tutorial_active:
		_update_story_tutorial()


func _on_brake_button_pressed() -> void:
	if GameState.train_control_mode == 2:
		GameState.train_control_mode = 0
	else:
		GameState.train_control_mode = 2
	AudioManager.play_brake()


func _on_back_button_pressed() -> void:
	AudioManager.play_back()
	_save_crew_positions()
	GameState.stop_travel()
	GameState.save_state()
	if GameState.game_mode == "story":
		get_tree().change_scene_to_file("res://scenes/story_hub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _save_crew_positions() -> void:
	GameState.crew_positions.clear()
	for member in _crew:
		var screen_pos: Vector2 = member["sprite"].position
		# 只保存角色相对列车内容的位置，避免下一次列车重新居中后整体偏移
		GameState.crew_positions[member["id"]] = Vector2(screen_pos.x - _train_scroll, screen_pos.y)
	GameState.crew_positions_space = "train_content_v2"


func _exit_tree() -> void:
	_save_crew_positions()
	GameState.save_state()


# ===== 2.4 收集 / 维修 / 加煤 =====
func _start_collect() -> void:
	if _is_collecting:
		return
	_is_collecting = true
	_collect_timer = 0.0
	_action_log = "正在收集物资…（%.0f 秒）" % GameConfig.COLLECT_DURATION


func _complete_collection() -> void:
	_is_collecting = false
	_collect_timer = 0.0
	AudioManager.play_collect()
	var food_gain: int = int(randf_range(GameConfig.COLLECT_FOOD_MIN, GameConfig.COLLECT_FOOD_MAX))
	var fuel_gain: int = int(randf_range(GameConfig.COLLECT_FUEL_MIN, GameConfig.COLLECT_FUEL_MAX))
	GameState.add_resource("food", food_gain)
	GameState.add_resource("fuel", fuel_gain)
	_action_log = "收集完成：食物 +%d，燃料 +%d" % [food_gain, fuel_gain]


func _do_repair() -> void:
	var hp: float = GameState.train["health"]
	var stopped: bool = GameState.get_train_speed() <= 0.01
	if hp >= GameConfig.REPAIR_FULL_THRESHOLD:
		if not GameState.consume_resource("parts", GameConfig.REPAIR_COST_PARTS):
			_action_log = "零件不足（需要 %d）" % GameConfig.REPAIR_COST_PARTS
			return
		GameState.set_train_health(GameState.train["max_health"])
		_action_log = "维修完成：列车 HP 已修满"
	elif hp >= GameConfig.REPAIR_MINOR_THRESHOLD:
		if not GameState.consume_resource("parts", GameConfig.REPAIR_COST_PARTS):
			_action_log = "零件不足（需要 %d）" % GameConfig.REPAIR_COST_PARTS
			return
		GameState.set_train_health(minf(hp + GameConfig.REPAIR_MINOR_AMOUNT, GameConfig.REPAIR_MINOR_CAP))
		_action_log = "维修完成：列车 HP +%d" % GameConfig.REPAIR_MINOR_AMOUNT
	elif hp >= GameConfig.REPAIR_SEVERE_THRESHOLD:
		if not stopped:
			_action_log = "列车受损较重（25~49），需停靠后维修"
			return
		if not GameState.consume_resource("parts", GameConfig.REPAIR_COST_PARTS):
			_action_log = "零件不足（需要 %d）" % GameConfig.REPAIR_COST_PARTS
			return
		GameState.set_train_health(hp + GameConfig.REPAIR_SEVERE_AMOUNT)
		_action_log = "维修完成：停靠维修 HP +%d" % GameConfig.REPAIR_SEVERE_AMOUNT
	else:
		_action_log = "列车损坏过重（<25%），无法维修"


func _do_refuel() -> void:
	var carriages: Array = GameState.train.get("carriages", [])
	if carriages.is_empty():
		_action_log = "没有车厢，无需加煤"
		return
	var available: int = GameState.get_resource("fuel")
	if available <= 0:
		_action_log = "燃料储备为 0，无法加煤"
		return
	var used := 0
	var vtype = VehicleTypes.STR_TYPE.get("coal_tender")
	var cap: float = VehicleTypes.CONFIG[vtype]["coal_capacity"] if vtype != null else 25.0
	for c in carriages:
		if c.get("type", "") != "coal_tender":
			continue
		var cur: float = float(c.get("fuel_left", 0.0))
		var need: float = cap - cur
		if need <= 0 or available - used <= 0:
			continue
		var take: int = int(minf(need, float(available - used)))
		c["fuel_left"] = cur + take
		used += take
	if used <= 0:
		_action_log = "煤水车燃料已满"
		return
	GameState.consume_resource("fuel", used)
	GameState.refresh_train_runtime_state()
	_action_log = "加煤完成：燃料 -%d，机车动力已刷新" % used
