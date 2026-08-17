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
## 列车展示区域（survival 原版比例）
const TRAIN_HEIGHT_RATIO: float = 0.36
const TRAIN_BOTTOM_RATIO: float = 0.82
const TRAIN_BOTTOM_OFFSET: float = 75.0
## 拖拽惯性衰减
const INERTIA_DECAY: float = 0.95
## 拖拽判定阈值（px）
const DRAG_THRESHOLD: float = 3.0

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

## 车厢内交互点（2.5）：位于列车地板带上
const INTERACTION_POINTS: Array = [
	{"id": "boiler", "name": "锅炉", "pos": Vector2(300, 600), "color": Color(0.85, 0.35, 0.2), "action": "加煤"},
	{"id": "cargo", "name": "物资箱", "pos": Vector2(640, 615), "color": Color(0.55, 0.4, 0.25), "action": "收集物资"},
	{"id": "repair", "name": "维修台", "pos": Vector2(980, 600), "color": Color(0.45, 0.5, 0.55), "action": "维修"},
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
@export var crew_target_height: float = 180.0
@export var floor_y_range: Vector2 = Vector2(430, 640)

# ===== 视差/列车状态 =====
var _layers: Array = []                 # [{container, tile_w, speed}]
var _view_w: float = 1280.0
var _view_h: float = 720.0
var _train_scroll: float = 0.0
var _train_total_w: float = 0.0
var _dragging_train: bool = false
var _drag_press_active: bool = false
var _drag_start_mouse_x: float = -1.0
var _drag_start_scroll: float = 0.0
var _drag_threshold_passed: bool = false
var _train_inertia: float = 0.0
var _prev_train_scroll: float = 0.0

# ===== 小队状态 =====
var _crew: Array = []          # [{id, name, sprite, formation_offset}]
var _target_pos: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _floor_y_min: float = 430.0
var _floor_y_max: float = 640.0

# ===== 行驶状态（2.3）=====
var _distance_km: float = 0.0
var _travel_time: float = 0.0
var _breakdown_armed: bool = false

# ===== 动作状态（2.4）=====
var _is_collecting: bool = false
var _collect_timer: float = 0.0
var _action_log: String = ""

# ===== HUD =====
var _resource_bars: Dictionary = {}
var _char_rows: Array = []
var _res_panel: Control = null
var _char_panel: Control = null

# ===== 交互点弹窗 =====
var _pending_interaction: String = ""
var _action_popup: PanelContainer = null
var _action_title: Label = null
var _action_button: Button = null

@onready var _train_container: Control = $TrainContainer
@onready var _interaction_root: Node2D = $InteractionRoot
@onready var _crew_root: Node2D = $CrewRoot
@onready var _hud_status: Label = $HUD/TopBar/StatusLabel
@onready var _hud_carriage: Label = $HUD/TopBar/CarriageLabel
@onready var _hud_accel_btn: Button = $HUD/TopBar/AccelButton
@onready var _hud_back_btn: Button = $HUD/TopBar/BackButton


func _ready() -> void:
	_view_w = get_viewport().get_visible_rect().size.x
	_view_h = get_viewport().get_visible_rect().size.y

	_ensure_crew_state()
	_setup_parallax()
	_setup_crew()
	_setup_interaction_points()
	_target_pos = _crew[0]["sprite"].global_position if not _crew.is_empty() else Vector2(640, 520)

	# ===== 2.3：接入列车系统 =====
	GameState.refresh_train_runtime_state()
	GameState.is_traveling = true
	GameState.travel_time = 0.0
	_distance_km = 0.0
	_travel_time = 0.0
	if GameState.train.get("carriages", []).is_empty():
		GameState.train_control_mode = 0
	elif GameState.has_powered_locomotive():
		GameState.train_control_mode = 1
		_breakdown_armed = true
	else:
		GameState.train_control_mode = 0

	# ===== 列车展示 =====
	_render_train()

	_hud_accel_btn.pressed.connect(_on_accel_button_pressed)
	_hud_back_btn.pressed.connect(_on_back_button_pressed)
	_build_hud()
	_update_hud()


## 保证 GameState.characters 至少有默认 4 人（角色状态结算的载体）
func _ensure_crew_state() -> void:
	if GameState.characters == null or GameState.characters.is_empty():
		GameState.characters = []
		for cfg in CharacterData.get_default_team():
			GameState.characters.append(cfg.duplicate(true))


# ===== 雪原视差（survival 原版：Control 容器 + 平铺 + y_off）=====
func _setup_parallax() -> void:
	for i in range(PARALLAX_LAYERS.size()):
		var cfg: Dictionary = PARALLAX_LAYERS[i]
		var container: Control = get_node("Layer%d%s" % [i, cfg["name"]])
		var tex: Texture2D = load(cfg["path"])
		if tex == null:
			push_error("travel.gd: 无法加载纹理 %s" % cfg["path"])
			continue

		var scale: float = _view_h / tex.get_height()
		var display_w: float = tex.get_width() * scale
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

	var band: Dictionary = _train_band()
	var base := Vector2(_view_w / 2.0, (band["top"] + band["bottom"]) / 2.0 - 30)
	var chroma := _make_chroma_key_material()
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
		s.position = base + CREW_FORMATION[i]
		s.z_index = 10
		_crew_root.add_child(s)
		var def := CharacterData.find_by_id(id)
		_crew.append({
			"id": id,
			"name": def.get("name", id),
			"sprite": s,
			"formation_offset": CREW_FORMATION[i],
		})


func _make_chroma_key_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CHROMA_KEY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


# ===== 2.5 交互点 =====
func _setup_interaction_points() -> void:
	for cfg in INTERACTION_POINTS:
		var point := Node2D.new()
		point.name = "Point_" + cfg["id"]
		point.position = cfg["pos"]
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
	var popup_pos: Vector2 = cfg["pos"] + Vector2(-80, -150)
	popup_pos.x = clampf(popup_pos.x, 12, 1180)
	popup_pos.y = clampf(popup_pos.y, 12, 560)
	_action_popup.position = popup_pos
	_action_popup.visible = true


func _hide_action_popup() -> void:
	if _action_popup != null:
		_action_popup.visible = false


func _on_action_button_pressed(id: String) -> void:
	var leader_id: String = _crew[0]["id"] if not _crew.is_empty() else ""
	var leader: Dictionary = _find_character_by_id(leader_id)
	if not leader.is_empty() and float(leader.get("stamina", 0.0)) <= 0.0:
		_action_log = "体力耗尽，无法操作交互点"
		return
	match id:
		"boiler":
			_do_refuel()
		"cargo":
			_start_collect()
		"repair":
			_do_repair()
	_hide_action_popup()


# ===== 输入：统一「click」动作 + 列车拖拽浏览 =====
func _unhandled_input(event: InputEvent) -> void:
	var pos_variant: Variant = event.get("position")
	var pos: Vector2 = pos_variant if pos_variant is Vector2 else Vector2.ZERO

	if event.is_action_pressed("click"):
		_on_click_pressed(pos)
	elif event.is_action_released("click"):
		_on_click_released(pos)
	elif event is InputEventMouseMotion and _drag_press_active:
		_handle_drag_motion(pos.x)


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
	_hide_action_popup()
	for cfg in INTERACTION_POINTS:
		if point.distance_to(cfg["pos"]) <= INTERACTION_RADIUS:
			_pending_interaction = cfg["id"]
			break
	var p := Vector2(
		clampf(point.x, 40, _view_w - 40),
		clampf(point.y, _floor_y_min, _floor_y_max),
	)
	_target_pos = p
	_is_moving = true


# ===== 主循环 =====
func _process(delta: float) -> void:
	# 1. 世界推进
	var crew_count: int = _crew.size() if not _crew.is_empty() else (GameState.characters.size() if GameState.characters != null else 0)
	GameState.tick_world(delta, crew_count)

	var train_speed: float = GameState.get_train_speed()
	_travel_time += delta
	GameState.travel_time = _travel_time
	_distance_km += train_speed * delta / 1000.0

	# 2. 拖拽惯性
	if not _dragging_train and abs(_train_inertia) > 0.3:
		_train_scroll += _train_inertia
		_train_inertia *= INERTIA_DECAY
		if abs(_train_inertia) < 0.3:
			_train_inertia = 0.0
		_clamp_train_scroll()
		_refresh_train_sprites()

	# 3. 拖拽视差量（同步给所有视差层与小队）
	var drag_delta: float = _train_scroll - _prev_train_scroll
	_prev_train_scroll = _train_scroll

	var scroll_delta: float = train_speed * SCROLL_SPEED_FACTOR * delta
	for layer in _layers:
		_scroll_layer(layer, scroll_delta, drag_delta)

	# 小队跟随列车拖拽同步移动
	if abs(drag_delta) > 0.001:
		for member in _crew:
			(member["sprite"] as Sprite2D).position.x += drag_delta
		_target_pos.x += drag_delta

	# 4. 抛锚检测 + 收集进度 + HUD
	_check_breakdown()
	if _is_collecting:
		_collect_timer += delta
		if _collect_timer >= GameConfig.COLLECT_DURATION:
			_complete_collection()
	_update_hud()

	# 5. 编队移动
	if not _is_moving:
		return

	var all_arrived := true
	for member in _crew:
		var sprite: Sprite2D = member["sprite"]
		var target: Vector2 = _target_pos + member["formation_offset"]
		var pos: Vector2 = sprite.global_position
		var dist: float = pos.distance_to(target)
		if dist < 4.0:
			sprite.global_position = target
			continue
		all_arrived = false
		var dir: Vector2 = (target - pos).normalized()
		sprite.flip_h = dir.x < 0
		sprite.global_position = pos.move_toward(target, walk_speed * delta)

	if all_arrived:
		_is_moving = false
		if _pending_interaction != "":
			_show_action_popup(_pending_interaction)


# ===== 列车展示（survival 原版：车厢精灵渲染 + 裁剪 + 拖拽）=====
func _train_band() -> Dictionary:
	var train_height: float = _view_h * TRAIN_HEIGHT_RATIO
	var train_bottom: float = _view_h * TRAIN_BOTTOM_RATIO + TRAIN_BOTTOM_OFFSET
	return {"top": train_bottom - train_height, "bottom": train_bottom, "height": train_height}


func _render_train() -> void:
	var carriages: Array = GameState.train.get("carriages", [])
	if carriages.is_empty():
		_train_container.visible = false
		return

	_train_container.visible = true
	var band: Dictionary = _train_band()
	_train_container.offset_top = band["top"]
	_train_container.offset_bottom = band["bottom"]
	_train_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_floor_y_min = band["top"] + 20.0
	_floor_y_max = band["bottom"] - 30.0

	var vehicle_sizes: Array = []
	_train_total_w = 0.0
	for c in carriages:
		var vtype = VehicleTypes.STR_TYPE.get(str(c.get("type", "")))
		if vtype == null:
			continue
		var path: String = VehicleTypes.CONFIG[vtype]["vehicle_path"]
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var scale: float = band["height"] / tex.get_height()
		var w: float = tex.get_width() * scale
		vehicle_sizes.append({"tex": tex, "w": w, "flipped": bool(c.get("flipped", false))})
		_train_total_w += w

	if vehicle_sizes.is_empty():
		return

	_train_scroll = (_view_w - _train_total_w) / 2.0
	_prev_train_scroll = _train_scroll
	_apply_train_positions(vehicle_sizes, band["height"])


func _apply_train_positions(vehicle_sizes: Array, train_height: float) -> void:
	for child in _train_container.get_children():
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
	var carriages: Array = GameState.train.get("carriages", [])
	if carriages.is_empty():
		return
	var band: Dictionary = _train_band()
	var vehicle_sizes: Array = []
	for c in carriages:
		var vtype = VehicleTypes.STR_TYPE.get(str(c.get("type", "")))
		if vtype == null:
			continue
		var path: String = VehicleTypes.CONFIG[vtype]["vehicle_path"]
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var scale: float = band["height"] / tex.get_height()
		var w: float = tex.get_width() * scale
		vehicle_sizes.append({"tex": tex, "w": w, "flipped": bool(c.get("flipped", false))})
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
	_hud_carriage.text = _carriage_composition_text()
	_hud_accel_btn.text = "制动/滑行" if GameState.train_control_mode == 1 else "加速"
	_update_resource_bars()
	_update_character_rows()


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
	if GameState.train.get("carriages", []).is_empty():
		return "下一站: --"
	for st in STATIONS:
		if _distance_km < float(st["km"]):
			return "下一站: %s (余 %.0f km)" % [st["name"], float(st["km"]) - _distance_km]
	return "极光城折返点"


func _build_hud() -> void:
	_res_panel = GridContainer.new()
	_res_panel.name = "ResourcePanel"
	_res_panel.columns = 3
	_res_panel.position = Vector2(12, 172)
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
	_char_panel.position = Vector2(12, 300)
	_char_panel.custom_minimum_size = Vector2(390, 0)
	_char_panel.add_theme_constant_override("separation", 4)
	$HUD.add_child(_char_panel)

	for member in _crew:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_label := Label.new()
		name_label.text = str(member.get("name", "?"))
		name_label.custom_minimum_size = Vector2(56, 20)
		name_label.add_theme_font_size_override("font_size", 13)
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(120, 14)
		hp_bar.max_value = 100.0
		hp_bar.show_percentage = false
		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(190, 20)
		status_label.add_theme_font_size_override("font_size", 11)
		row.add_child(name_label)
		row.add_child(hp_bar)
		row.add_child(status_label)
		_char_panel.add_child(row)
		_char_rows.append({"id": str(member.get("id", "")), "hp_bar": hp_bar, "status_label": status_label})


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
		return
	GameState.refresh_train_runtime_state()
	if not GameState.has_powered_locomotive():
		print("[DEBUG travel._on_accel_button_pressed] 无动力机车：需要机车+煤水车+燃料")
		_action_log = "无动力：需要机车+煤水车+燃料"
		return
	GameState.train_control_mode = 1
	_breakdown_armed = true


func _on_back_button_pressed() -> void:
	GameState.is_traveling = false
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
