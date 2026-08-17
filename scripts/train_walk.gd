extends Node2D
## 火车内点击移动 —— 视差背景滚动 + 小人走位

# ===== 视差层配置 =====
const PARALLAX_LAYERS = [
	{ "path": "res://assets/sprites/parallax/蓝天不动.png", "speed": 0.0 },
	{ "path": "res://assets/sprites/parallax/远景云.png", "speed": 0.12 },
	{ "path": "res://assets/sprites/parallax/中景云.png", "speed": 0.28 },
	{ "path": "res://assets/sprites/parallax/雪原地.png", "speed": 0.50 },
	{ "path": "res://assets/sprites/parallax/最前景枯树.png", "speed": 1.40 },
]

# ===== 可调参数 =====
@export var train_visual_speed: float = 100.0    # 背景滚动速度（模拟火车前进）
@export var walk_speed: float = 250.0             # 小人移动速度
@export var character_texture_path: String = "res://assets/sprites/characters_walk/conductor.png"
@export var show_train_interior: bool = true      # 是否显示车厢内饰

# ===== 内部状态 =====
var _layer_states: Array = []    # [{sprites: [Sprite2D, Sprite2D], tex_w: float, speed: float}]
var _scroll: float = 0.0

# 小人移动
var _target_pos: Vector2 = Vector2.ZERO
var _is_moving: bool = false

@onready var _bg_root: Node2D = $BackgroundRoot
@onready var _character: Sprite2D = $Character


func _ready() -> void:
	_setup_parallax()
	_setup_character()
	_target_pos = _character.global_position


func _setup_parallax() -> void:
	var view_h = get_viewport().get_visible_rect().size.y
	for cfg in PARALLAX_LAYERS:
		var tex: Texture2D = load(cfg["path"])
		if tex == null:
			continue
		# 缩放到填满屏幕高度
		var scale_y: float = view_h / tex.get_height()
		var display_w: float = tex.get_width() * scale_y

		# 每层放 2 个 sprite 并排，实现无限循环
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

		_layer_states.append({
			"sprites": sprites,
			"tex_w": display_w,
			"speed": cfg["speed"],
		})

	# 车厢内饰 overlay（可选）
	if show_train_interior:
		var interior_scale: float = 1.0
		if _layer_states.size() > 0:
			interior_scale = _layer_states[0]["sprites"][0].scale.x
		_add_interior(interior_scale)


func _add_interior(scale_y: float) -> void:
	var wall: Texture2D = load("res://assets/sprites/wall.png")
	var cf: Texture2D = load("res://assets/sprites/ceiling_floor.png")
	var view_w = get_viewport().get_visible_rect().size.x

	# 地板/天花板 在最前方
	if cf:
		var s := Sprite2D.new()
		s.texture = cf
		s.scale = Vector2(scale_y, scale_y)
		s.centered = false
		s.z_index = 5
		s.position.y = 0
		_bg_root.add_child(s)
		# 第二块 tile
		var cf_w = cf.get_width() * scale_y
		var s2 := Sprite2D.new()
		s2.texture = cf
		s2.scale = Vector2(scale_y, scale_y)
		s2.centered = false
		s2.z_index = 5
		s2.position = Vector2(cf_w, 0)
		_bg_root.add_child(s2)
		# 记录到层状态以同步滚动
		_layer_states.append({"sprites": [s, s2], "tex_w": cf_w, "speed": 1.0})


func _setup_character() -> void:
	var tex: Texture2D = load(character_texture_path)
	if tex:
		_character.texture = tex


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_target_pos = event.position
		_is_moving = true


func _process(delta: float) -> void:
	# 1. 视差背景无限滚动
	_scroll += train_visual_speed * delta
	for state in _layer_states:
		var sprites: Array = state["sprites"]
		var w: float = state["tex_w"]
		var s: float = state["speed"]
		for i in range(sprites.size()):
			var sprite: Sprite2D = sprites[i]
			var base_x: float = i * w
			var offset: float = fmod(_scroll * s, w * sprites.size())
			var x: float = base_x - offset
			# 无限循环：当 sprite 完全滑出左侧，跳转到右侧
			if x + w < -10:
				x += w * sprites.size()
			sprite.position.x = x

	# 2. 小人移动
	if not _is_moving:
		return

	var pos: Vector2 = _character.global_position
	var dist: float = pos.distance_to(_target_pos)
	if dist < 4.0:
		_character.global_position = _target_pos
		_is_moving = false
		return

	var dir: Vector2 = (_target_pos - pos).normalized()
	_character.flip_h = dir.x < 0
	_character.global_position = pos.move_toward(_target_pos, walk_speed * delta)
