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

@onready var _bg_root: Node2D = $BackgroundRoot
@onready var _interior_root: Node2D = $InteriorRoot
@onready var _crew_root: Node2D = $CrewRoot


func _ready() -> void:
	_setup_parallax()
	_setup_interior()
	_setup_crew()
	_target_pos = _crew[0]["sprite"].global_position if not _crew.is_empty() else Vector2(400, 520)


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


# ===== 输入：点击地面 → 编队移动 =====
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_command_move(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_command_move(event.position)


func _command_move(point: Vector2) -> void:
	var p := Vector2(
		clampf(point.x, 40, get_viewport().get_visible_rect().size.x - 40),
		clampf(point.y, floor_y_range.x, floor_y_range.y),
	)
	_target_pos = p
	_is_moving = true


# ===== 主循环 =====
func _process(delta: float) -> void:
	_scroll += train_visual_speed * delta
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
