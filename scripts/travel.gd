extends Node2D
## 车内第一人称视差行驶场景（Day 2.2）
## —— 5 层视差滚动 + 车厢内饰 + 随车小队点击行走（编队）
## 后续接入：world_tick / fuel_system / train_physics（2.3）、生存数值与 HUD（2.4）、交互点（2.5）

# ===== 视差层配置（后景 4 层 + 前景枯树）=====
const PARALLAX_LAYERS = [
	{ "path": "res://assets/sprites/parallax/蓝天不动.png", "speed": 0.0 },
	{ "path": "res://assets/sprites/parallax/远景云.png", "speed": 0.12 },
	{ "path": "res://assets/sprites/parallax/中景云.png", "speed": 0.28 },
	{ "path": "res://assets/sprites/parallax/雪原地.png", "speed": 0.50 },
	{ "path": "res://assets/sprites/parallax/最前景枯树.png", "speed": 1.40 },
]

## 视差滚动系数：滚动速度 = 列车速度(m/s) × 此系数
const SCROLL_SPEED_FACTOR: float = 80.0

## 站点门槛（DEMO_DESIGN §3；Day 3 站点系统完整接入）
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

## 车厢内交互点（2.5）：位置 + 颜色 + 动作
const INTERACTION_POINTS: Array = [
	{"id": "boiler", "name": "锅炉", "pos": Vector2(290, 545), "color": Color(0.85, 0.35, 0.2), "action": "加煤"},
	{"id": "cargo", "name": "物资箱", "pos": Vector2(640, 565), "color": Color(0.55, 0.4, 0.25), "action": "收集物资"},
	{"id": "repair", "name": "维修台", "pos": Vector2(990, 545), "color": Color(0.45, 0.5, 0.55), "action": "维修"},
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
	// 绿幕判定：绿色通道显著高于红蓝（g>0.5 且 g > 1.4*max(r,b)）
	if (c.g > 0.5 && c.g > 1.4 * max(c.r, c.b)) {
		c.a = 0.0;
	}
	COLOR = c;
}
"""

# 编队偏移（相对点击点）：车长居中，其余两侧/后方
const CREW_FORMATION: Array = [
	Vector2(0, 0),
	Vector2(-34, 10),
	Vector2(34, 10),
	Vector2(0, 26),
]

# ===== 可调参数 =====
@export var train_visual_speed: float = 100.0   # 背景滚动速度（2.3 起由 train_physics 接管）
@export var walk_speed: float = 250.0            # 小人移动速度
@export var crew_target_height: float = 180.0    # 角色在画面中的目标高度（绿幕素材原始尺寸很大）
@export var show_train_interior: bool = true     # 是否显示车厢内饰
@export var floor_y_range: Vector2 = Vector2(360, 600)  # 可点击行走的纵向范围（地板带）

# ===== 内部状态 =====
var _layer_states: Array = []  # [{sprites:[Sprite2D,Sprite2D], tex_w:float, speed:float}]
var _scroll: float = 0.0
var _crew: Array = []          # [{id, name, sprite, formation_offset}]
var _target_pos: Vector2 = Vector2.ZERO
var _is_moving: bool = false

# ===== 行驶状态（2.3 接入 systems/）=====
var _distance_km: float = 0.0          # 本程累计里程
var _travel_time: float = 0.0          # 本程累计行驶时间
var _breakdown_armed: bool = false     # 抛锚判定使能（有动力加速中才计数）

# ===== 动作状态（2.4 收集/维修）=====
var _is_collecting: bool = false
var _collect_timer: float = 0.0
var _action_log: String = ""           # 动作结果播报（显示在状态栏）

# ===== HUD（2.4 资源条/角色状态）=====
var _resource_bars: Dictionary = {}    # key -> {bar: ProgressBar, label: Label}
var _char_rows: Array = []             # [{id, hp_bar, status_label}]
var _res_panel: Control = null
var _char_panel: Control = null

# ===== 交互点（2.5）=====
var _pending_interaction: String = ""  # 到达后要弹出的交互点 id
var _action_popup: PanelContainer = null
var _action_title: Label = null
var _action_button: Button = null

@onready var _bg_root: Node2D = $BackgroundRoot
@onready var _interior_root: Node2D = $InteriorRoot
@onready var _interaction_root: Node2D = $InteractionRoot
@onready var _crew_root: Node2D = $CrewRoot
@onready var _hud_status: Label = $HUD/TopBar/StatusLabel
@onready var _hud_carriage: Label = $HUD/TopBar/CarriageLabel
@onready var _hud_accel_btn: Button = $HUD/TopBar/AccelButton
@onready var _hud_back_btn: Button = $HUD/TopBar/BackButton


func _ready() -> void:
	_ensure_crew_state()
	_setup_parallax()
	_setup_interior()
	_setup_crew()
	_setup_interaction_points()
	_setup_carriage_dividers()
	_target_pos = _crew[0]["sprite"].global_position if not _crew.is_empty() else Vector2(400, 520)

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


# ===== 视差背景 =====
func _setup_parallax() -> void:
	var view_h = get_viewport().get_visible_rect().size.y
	for cfg in PARALLAX_LAYERS:
		var tex: Texture2D = load(cfg["path"])
		if tex == null:
			continue
		var scale_y: float = view_h / tex.get_height()
		var display_w: float = tex.get_width() * scale_y

		var sprites: Array = []
		for i in range(2):
			var s := Sprite2D.new()
			s.texture = tex
			s.scale = Vector2(scale_y, scale_y)
			s.position.x = i * display_w
			s.centered = false
			s.z_index = -10
			_bg_root.add_child(s)
			sprites.append(s)

		_layer_states.append({"sprites": sprites, "tex_w": display_w, "speed": cfg["speed"]})


# ===== 车厢内饰（墙面 + 天花板/地板，与列车同步滚动）=====
func _setup_interior() -> void:
	if not show_train_interior:
		return
	var view_h = get_viewport().get_visible_rect().size.y
	var wall: Texture2D = load("res://assets/sprites/wall.png")
	var cf: Texture2D = load("res://assets/sprites/ceiling_floor.png")

	if wall:
		var scale_y: float = view_h / wall.get_height()
		var w: float = wall.get_width() * scale_y
		var sprites: Array = []
		for i in range(2):
			var s := Sprite2D.new()
			s.texture = wall
			s.scale = Vector2(scale_y, scale_y)
			s.position.x = i * w
			s.centered = false
			_interior_root.add_child(s)
			sprites.append(s)
		_layer_states.append({"sprites": sprites, "tex_w": w, "speed": 1.0})

	if cf:
		var scale_y: float = view_h / cf.get_height()
		var w: float = cf.get_width() * scale_y
		var sprites: Array = []
		for i in range(2):
			var s := Sprite2D.new()
			s.texture = cf
			s.scale = Vector2(scale_y, scale_y)
			s.position.x = i * w
			s.centered = false
			_interior_root.add_child(s)
			sprites.append(s)
		_layer_states.append({"sprites": sprites, "tex_w": w, "speed": 1.0})


# ===== 随车小队 =====
func _setup_crew() -> void:
	# 优先用 GameState 随车成员；不足 4 人用默认角色补齐
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

	# 出生编队：排在车中央地板带上
	var base := Vector2(640, 520)
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


## 编组数据影响车内展示：每节车厢之间画一道隔断，并在 HUD 显示编组构成（2.6）
func _setup_carriage_dividers() -> void:
	var carriages: Array = GameState.train.get("carriages", [])
	if carriages.size() <= 1:
		return
	var view_w: float = get_viewport().get_visible_rect().size.x
	for i in range(1, carriages.size()):
		var x: float = view_w * float(i) / carriages.size()
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(x - 3, 400), Vector2(x + 3, 400),
			Vector2(x + 3, 620), Vector2(x - 3, 620),
		])
		poly.color = Color(0.12, 0.09, 0.06, 0.75)
		_interior_root.add_child(poly)


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
	# 体力 0 不可操作交互点（DEMO_DESIGN §2.3）
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


# ===== 输入：点击地面 → 编队移动 =====
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_command_move(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_command_move(event.position)


func _command_move(point: Vector2) -> void:
	# 点击交互点附近 → 记住目标交互点，到达后弹操作按钮
	_pending_interaction = ""
	_hide_action_popup()
	for cfg in INTERACTION_POINTS:
		if point.distance_to(cfg["pos"]) <= INTERACTION_RADIUS:
			_pending_interaction = cfg["id"]
			break
	var p := Vector2(
		clampf(point.x, 40, get_viewport().get_visible_rect().size.x - 40),
		clampf(point.y, floor_y_range.x, floor_y_range.y),
	)
	_target_pos = p
	_is_moving = true


# ===== 主循环 =====
func _process(delta: float) -> void:
	# 1. 世界推进：物理/食物/燃料系统（2.3）
	var crew_count: int = _crew.size() if not _crew.is_empty() else (GameState.characters.size() if GameState.characters != null else 0)
	GameState.tick_world(delta, crew_count)

	var train_speed: float = GameState.get_train_speed()
	_travel_time += delta
	GameState.travel_time = _travel_time
	_distance_km += train_speed * delta / 1000.0

	# 2. 视差滚动由真实车速驱动（无编组时退回演示速度）
	var scroll_speed: float = train_speed * SCROLL_SPEED_FACTOR
	if GameState.train.get("carriages", []).is_empty():
		scroll_speed = train_visual_speed
	_scroll += scroll_speed * delta
	for state in _layer_states:
		var sprites: Array = state["sprites"]
		var w: float = state["tex_w"]
		var s: float = state["speed"]
		for i in range(sprites.size()):
			var sprite: Sprite2D = sprites[i]
			var base_x: float = i * w
			var x: float = base_x - fmod(_scroll * s, w * sprites.size())
			if x + w < -10:
				x += w * sprites.size()
			sprite.position.x = x

	# 3. 抛锚检测 + 收集进度 + HUD
	_check_breakdown()
	if _is_collecting:
		_collect_timer += delta
		if _collect_timer >= GameConfig.COLLECT_DURATION:
			_complete_collection()
	_update_hud()

	# 4. 编队移动
	if not _is_moving:
		return

	# 编队整体移动：每人朝各自目标点走
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


# ===== 2.3 行驶系统：抛锚 / HUD / 控制 =====
func _check_breakdown() -> void:
	if not GameState.is_traveling:
		return
	var has_power: bool = GameState.has_powered_locomotive()
	if has_power:
		_breakdown_armed = true
		return
	# 失去动力且列车完全停下 → 记一次抛锚（生存模式 3 次失败）
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
	# ---- 资源条（2×? 网格）----
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

	# ---- 角色状态行 ----
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
		_hud_status.text += "  ⚠无动力(需机车+煤水车+燃料)"
		return
	GameState.train_control_mode = 1
	_breakdown_armed = true


func _on_back_button_pressed() -> void:
	GameState.is_traveling = false
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ===== 2.4 收集 / 维修 / 加煤（2.5 由交互点按钮调用）=====
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


## 维修（DEMO_DESIGN §2.4）：≥90 修满；50~89 行驶/停靠 +20 上限90；25~49 仅停靠 +10；<25 不可修
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


## 锅炉加煤：全局燃料池 → 煤水车（逐个补满，上限25）
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
