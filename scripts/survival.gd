extends Control
## 视差滚动场景 —— 雪原 + 控制台

const PARALLAX_LAYERS := [
	{ "name": "Sky",       "path": "res://assets/sprites/parallax/蓝天不动.png",   "speed": 0.0,  "y_off": 0 },
	{ "name": "FarCloud",  "path": "res://assets/sprites/parallax/远景云.png",     "speed": 0.15, "y_off": 0 },
	{ "name": "MidCloud",  "path": "res://assets/sprites/parallax/中景云.png",     "speed": 0.35, "y_off": 0 },
	{ "name": "Ground",    "path": "res://assets/sprites/parallax/雪原地.png",     "speed": 0.6,  "y_off": 215 },
	{ "name": "FrontTree", "path": "res://assets/sprites/parallax/最前景枯树.png", "speed": 1.6,  "y_off": 5 },
]

const SCROLL_SPEED_FACTOR: float = 80.0  # 视差速度 = 火车速度 × 此系数
const TRAIN_GROUND_SPEED: float = 0.6    # 列车在地面层上，拖拽时与地面共速
const TRAIN_HEIGHT_RATIO: float = 0.36
const TRAIN_BOTTOM_RATIO: float = 0.82
const TRAIN_BOTTOM_OFFSET: float = 75.0
const INERTIA_DECAY: float = 0.95        # 惯性衰减系数（每帧，越大惯性越久）

var _view_w: float = 1280.0
var _view_h: float = 720.0
var _layers: Array = []

# 列车拖拽滚动
var _train_scroll: float = 0.0
var _train_total_w: float = 0.0
var _dragging_train: bool = false
var _drag_start_mouse: float = -1.0    # -1 表示未按下
var _drag_start_scroll: float = 0.0
var _drag_threshold_passed: bool = false # 3px阈值，防止误触
var _train_inertia: float = 0.0          # 惯性速度（px/frame，地面速）
var _prev_train_scroll: float = 0.0      # 上一帧列车位置（用于计算拖拽视差）
var _no_power_timer: float = 0.0          # 无动力计时器，防止误复位

# 小人行走
var _character: TextureRect               # 小人节点
var _char_target_x: float = -1.0          # 目标 x（-1 表示无目标）
var _char_target_y: float = -1.0          # 目标 y
var _char_walk_speed: float = 200.0       # 行走速度
var _char_clicked: bool = false           # 刚点了一次（用于区分拖拽/点击）
var _char_click_pos: Vector2 = Vector2.ZERO

# UI 节点
var _speed_label: Label
var _mode_label: Label
var _btn_accel: Button
var _btn_brake: Button

func _ready() -> void:
	_view_w = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	_view_h = float(ProjectSettings.get_setting("display/window/size/viewport_height"))

	# ---- 视差层 ----
	for i in range(PARALLAX_LAYERS.size()):
		var cfg = PARALLAX_LAYERS[i]
		var container = get_node("Layer%d%s" % [i, cfg["name"]]) as Control
		if container == null:
			push_error("survival.gd: 找不到节点 Layer%d%s" % [i, cfg["name"]])
			continue

		var tex = load(cfg["path"]) as Texture2D
		if tex == null:
			push_error("survival.gd: 无法加载纹理 %s" % cfg["path"])
			continue

		var scale = _view_h / float(tex.get_height())
		var display_w = float(tex.get_width()) * scale
		var display_h = _view_h

		_spawn_tiles(container, tex, display_w, display_h, cfg["y_off"])

		_layers.append({
			"container": container,
			"tile_w": display_w,
			"speed": cfg["speed"],
		})

	# ---- 控制台 ----
	_speed_label = get_node("ControlPanel/SpeedLabel") as Label
	_mode_label = get_node("ControlPanel/ModeLabel") as Label
	_btn_accel = get_node("ControlPanel/BtnAccel") as Button
	_btn_brake = get_node("ControlPanel/BtnBrake")

	_btn_accel.pressed.connect(_on_accel_pressed)
	_btn_brake.pressed.connect(_on_brake_pressed)

	var btn_back = get_node("BtnBack") as Button
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)

	# ---- 渲染列车 ----
	# 安全刷新：确保列车运行时状态正确（补燃料、校验动力）
	GameState.refresh_train_runtime_state()
	print("[DEBUG survival._ready] refresh后 carriages=%d has_powered_loco=%s resources[fuel]=%d" % [GameState.train.get("carriages", []).size(), GameState.has_powered_locomotive(), GameState.resources.get("fuel", 0)])
	_render_train()
	_init_character()
	_update_character_position()

func _input(event: InputEvent) -> void:
	# 小人点击检测（始终处理，不受列车宽度限制）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_start_mouse = event.position.x
			_drag_start_scroll = _train_scroll
			_drag_threshold_passed = false
			_train_inertia = 0.0
		else:
			# 没有拖拽 → 这是一次点击；仅当点击落在空白处（非 UI 控件）时小人走过去
			var hovered: Control = get_viewport().gui_get_hovered_control()
			if not _dragging_train and _drag_start_mouse >= 0.0 and hovered == null:
				_char_clicked = true
				_char_click_pos = event.position
			_dragging_train = false
			_drag_start_mouse = -1.0
			_drag_threshold_passed = false
	# 列车拖拽（仅当列车比屏幕宽时）
	if _train_total_w > _view_w:
		if event is InputEventMouseMotion and _drag_start_mouse >= 0.0:
			if not _dragging_train and abs(event.position.x - _drag_start_mouse) > 3:
				_dragging_train = true
				_drag_threshold_passed = true
			if _dragging_train:
				var prev_scroll = _train_scroll
				_train_scroll = _drag_start_scroll + (event.position.x - _drag_start_mouse) * TRAIN_GROUND_SPEED
				_train_inertia = _train_scroll - prev_scroll
				_clamp_train_scroll()
				_refresh_train_sprites()

func _process(delta: float) -> void:
	# 0. 消费小人点击（_input 中设置，这里消费避免在事件处理中做复杂操作）
	if _char_clicked:
		_char_clicked = false
		_on_train_click(_char_click_pos)

	# 1. 推进世界
	var crew_count: int = GameState.characters.size() if GameState.characters != null else 0
	GameState.tick_world(delta, crew_count)

	if GameState.train_control_mode == 1 and not GameState.has_powered_locomotive():
		_no_power_timer += delta
		if _no_power_timer > 0.5:  # 延迟0.5秒，避免刚按下就被复位
			print("[DEBUG survival._process] mode=1但无动力机车！尝试refresh...")
			GameState.refresh_train_runtime_state()
			print("[DEBUG survival._process] refresh后 has_powered_loco=%s" % GameState.has_powered_locomotive())
			if not GameState.has_powered_locomotive():
				print("[DEBUG survival._process] 仍然无动力，重置mode=0")
				GameState.train_control_mode = 0
				_no_power_timer = 0.0
	else:
		_no_power_timer = 0.0

	# 2. 惯性：松手后列车继续滑动
	if not _dragging_train and abs(_train_inertia) > 0.3:
		_train_scroll += _train_inertia
		_train_inertia *= INERTIA_DECAY
		if abs(_train_inertia) < 0.3:
			_train_inertia = 0.0
		_clamp_train_scroll()
		_refresh_train_sprites()

	# 3. 拖拽视差（列车位置变化量 = 拖拽/惯性产生的位移）
	var drag_delta = _train_scroll - _prev_train_scroll
	_prev_train_scroll = _train_scroll

	# 3.5. 小人跟随列车同步移动
	if abs(drag_delta) > 0.001 and _character != null:
		_character.offset_left += drag_delta
		_character.offset_right += drag_delta
		if _char_target_x >= 0:
			_char_target_x += drag_delta

	# 4. 行驶视差
	var train_speed = GameState.get_train_speed()
	var scroll_delta = train_speed * SCROLL_SPEED_FACTOR * delta

	for layer in _layers:
		_scroll_layer(layer, scroll_delta, drag_delta)

	# 5. 更新 UI
	_update_ui()

	# 6. 小人行走
	_update_character_walk(delta)

func _spawn_tiles(container: Control, tex: Texture2D, display_w: float, display_h: float, y_off: float) -> void:
	for i in range(2):
		var sprite = TextureRect.new()
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
	var children = layer["container"].get_children()
	if children.is_empty():
		return

	var tile_w = layer["tile_w"]
	var speed_mul = layer["speed"]
	# 行驶偏移 + 拖拽视差（drag_delta 以地面速度为单位，其他层按比例缩放）
	var offset = scroll_delta * speed_mul + drag_delta * speed_mul / TRAIN_GROUND_SPEED
	var wrap_w = tile_w * 2.0

	for i in range(children.size()):
		var sprite = children[i] as Control
		if sprite == null:
			continue

		var x = sprite.offset_left + offset

		# 双向包裹（列车右→左 → 风景左→右）
		if x + tile_w < 0:
			x += wrap_w
		elif x > _view_w:
			x -= wrap_w

		sprite.offset_left = x
		sprite.offset_right = x + tile_w

func _update_ui() -> void:
	var speed_ms = GameState.get_train_speed()
	var speed_kmh = int(speed_ms * 3.6)
	_speed_label.text = "速度: %d km/h" % speed_kmh

	var mode = GameState.train_control_mode
	match mode:
		0: _mode_label.text = "模式: 滑行"
		1: _mode_label.text = "模式: 加速"
		2: _mode_label.text = "模式: 刹车"

func _update_character_walk(delta: float) -> void:
	if _character == null or _char_target_x < 0:
		return
	var target = Vector2(_char_target_x, _char_target_y)
	var current = Vector2(_character.offset_left, _character.offset_top)
	var dist = current.distance_to(target)
	if dist < 3.0:
		_char_target_x = -1.0
		return
	var dir = (target - current).normalized()
	_character.flip_h = dir.x < 0
	var new_pos = current.move_toward(target, _char_walk_speed * delta)
	var w = _character.offset_right - _character.offset_left
	var h = _character.offset_bottom - _character.offset_top
	_character.offset_left = new_pos.x
	_character.offset_top = new_pos.y
	_character.offset_right = new_pos.x + w
	_character.offset_bottom = new_pos.y + h

func _on_accel_pressed() -> void:
	print("[DEBUG survival._on_accel_pressed] 当前mode=%d has_powered_loco=%s carriages=%d" % [GameState.train_control_mode, GameState.has_powered_locomotive(), GameState.train.get("carriages", []).size()])
	if GameState.train_control_mode == 1:
		GameState.train_control_mode = 0
		print("[DEBUG survival._on_accel_pressed] 切换到滑行 mode=0")
	else:
		# 检查列车是否有动力
		GameState.refresh_train_runtime_state()
		if not GameState.has_powered_locomotive():
			_show_popup("无法加速", "列车没有动力！请检查：\n1. 是否编组了机车\n2. 机车旁是否有煤水车\n3. 燃料是否耗尽")
			return
		GameState.train_control_mode = 1
		print("[DEBUG survival._on_accel_pressed] 切换到加速 mode=1")

func _on_brake_pressed() -> void:
	if GameState.train_control_mode == 2:
		GameState.train_control_mode = 0
	else:
		GameState.train_control_mode = 2

func _on_back_pressed() -> void:
	GameState.save_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _show_popup(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.size = Vector2(400, 150)
	add_child(dialog)
	dialog.popup_centered()

# ===== 小人系统 =====
func _init_character() -> void:
	if _character != null:
		return
	_character = TextureRect.new()
	var tex: Texture2D = load("res://assets/sprites/characters_walk/conductor.png")
	if tex:
		_character.texture = tex
	_character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character.z_index = 100  # 确保在列车图层上方
	# 绿幕抠图：把素材的 chroma-key 绿色背景变为透明
	_apply_green_key_shader()
	add_child(_character)

func _apply_green_key_shader() -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// 检测高饱和绿色像素 → 透明
	if (c.g > 0.35 && c.g > c.r * 1.4 && c.g > c.b * 1.4) {
		COLOR = vec4(0.0);
	} else {
		COLOR = c;
	}
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_character.material = mat

func _update_character_position() -> void:
	if _character == null:
		return
	# 列车区域（固定常量，一次计算）
	var train_height = _view_h * TRAIN_HEIGHT_RATIO
	var train_bottom = _view_h * TRAIN_BOTTOM_RATIO + TRAIN_BOTTOM_OFFSET
	var train_top = train_bottom - train_height
	var train_center_y = (train_top + train_bottom) / 2.0
	# 纹理尺寸（容错：加载失败用默认值）
	var tex_w = float(_character.texture.get_width()) if _character.texture else 2048.0
	var tex_h = float(_character.texture.get_height()) if _character.texture else 2048.0
	# 缩放：让 TextureRect 显示尺寸约为列车高度的 1.2 倍
	var s = train_height * 1.2 / max(tex_w, tex_h)
	_character.scale = Vector2(s, s)
	var dw = tex_w * s
	var dh = tex_h * s
	# 定位：TextureRect 居中于列车区域
	_character.offset_left = (_view_w - dw) / 2.0
	_character.offset_top = train_center_y - dh / 2.0
	_character.offset_right = _character.offset_left + dw
	_character.offset_bottom = _character.offset_top + dh
	# 初始目标设为当前位置
	_char_target_x = -1.0
	_char_target_y = _character.offset_top
func _on_train_click(screen_pos: Vector2) -> void:
	# 限制在列车车厢区域内
	var train_height = _view_h * TRAIN_HEIGHT_RATIO
	var train_bottom = _view_h * TRAIN_BOTTOM_RATIO + TRAIN_BOTTOM_OFFSET
	var train_top = train_bottom - train_height
	_char_target_x = clamp(screen_pos.x, 50.0, _view_w - 50.0)
	_char_target_y = clamp(screen_pos.y, train_top + 20.0, train_bottom - 20.0)

# ===== 列车渲染 ====="
func _render_train() -> void:
	var container = get_node("TrainContainer") as Control
	if container == null:
		return

	var carriages = GameState.train.get("carriages", [])
	print("[DEBUG survival._render_train] carriages数量=%d has_powered_loco=%s" % [carriages.size(), GameState.has_powered_locomotive()])
	for c in carriages:
		print("[DEBUG survival._render_train]   type=%s fuel_left=%s is_powered=%s" % [c.get("type","?"), c.get("fuel_left","N/A"), c.get("is_powered","N/A")])
	if carriages.is_empty():
		container.visible = false
		return

	container.visible = true
	var train_height = _view_h * TRAIN_HEIGHT_RATIO
	var train_bottom = _view_h * TRAIN_BOTTOM_RATIO + TRAIN_BOTTOM_OFFSET
	var train_top = train_bottom - train_height

	# 把容器缩小到只覆盖列车区域，不干扰按钮
	container.offset_top = train_top
	container.offset_bottom = train_bottom
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 计算每节车厢的缩放宽度
	var vehicle_sizes: Array = []
	_train_total_w = 0.0
	for c in carriages:
		var vtype = VehicleTypes.STR_TYPE.get(c["type"])
		if vtype == null:
			continue
		var path = VehicleTypes.CONFIG[vtype]["vehicle_path"]
		var tex = load(path) as Texture2D
		if tex == null:
			continue
		var scale = train_height / float(tex.get_height())
		var w = float(tex.get_width()) * scale
		vehicle_sizes.append({"tex": tex, "w": w, "flipped": c.get("flipped", false)})
		_train_total_w += w

	if vehicle_sizes.is_empty():
		return

	_train_scroll = (_view_w - _train_total_w) / 2.0
	_prev_train_scroll = _train_scroll
	_apply_train_positions(container, vehicle_sizes, 0.0, train_height)

func _apply_train_positions(container: Control, vehicle_sizes: Array, top_y: float, bottom_y: float) -> void:
	# 清除旧精灵
	for child in container.get_children():
		child.queue_free()

	var current_x = _train_scroll
	for v in vehicle_sizes:
		var sprite = TextureRect.new()
		sprite.texture = v["tex"]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.flip_h = v["flipped"]
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

		sprite.offset_left = current_x
		sprite.offset_right = current_x + v["w"]
		sprite.offset_top = top_y
		sprite.offset_bottom = bottom_y

		container.add_child(sprite)
		current_x += v["w"]

func _clamp_train_scroll() -> void:
	if _train_total_w <= _view_w:
		_train_scroll = (_view_w - _train_total_w) / 2.0
	else:
		# 极值时列车两端在屏幕中央
		_train_scroll = clamp(_train_scroll, _view_w / 2.0 - _train_total_w, _view_w / 2.0)

func _refresh_train_sprites() -> void:
	var container = get_node("TrainContainer") as Control
	if container == null:
		return
	var carriages = GameState.train.get("carriages", [])
	if carriages.is_empty():
		return
	var train_height = container.offset_bottom - container.offset_top

	var vehicle_sizes: Array = []
	for c in carriages:
		var vtype = VehicleTypes.STR_TYPE.get(c["type"])
		if vtype == null:
			continue
		var path = VehicleTypes.CONFIG[vtype]["vehicle_path"]
		var tex = load(path) as Texture2D
		if tex == null:
			continue
		var scale = train_height / float(tex.get_height())
		var w = float(tex.get_width()) * scale
		vehicle_sizes.append({"tex": tex, "w": w, "flipped": c.get("flipped", false)})

	_apply_train_positions(container, vehicle_sizes, 0.0, train_height)
