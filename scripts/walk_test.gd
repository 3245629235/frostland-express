extends Node2D

## 点击移动测试 —— 鼠标点击走到指定位置

@export var walk_speed: float = 200.0
@export var character_texture_path: String = "res://assets/sprites/characters_walk/conductor.png"

var target_position: Vector2
var is_moving: bool = false

@onready var sprite: Sprite2D = $CharacterSprite


func _ready() -> void:
	# 加载角色纹理
	var tex = load(character_texture_path) as Texture2D
	if tex:
		sprite.texture = tex
	target_position = sprite.global_position


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 点击位置是屏幕坐标，用它作为世界坐标（简单场景无摄像机变换）
		target_position = event.position
		is_moving = true


func _process(delta: float) -> void:
	if not is_moving:
		return

	var current = sprite.global_position
	var distance = current.distance_to(target_position)

	# 到达目标（留 2px 容差）
	if distance < 2.0:
		sprite.global_position = target_position
		is_moving = false
		return

	# 朝向：根据移动方向翻转
	var direction = (target_position - current).normalized()
	sprite.flip_h = direction.x < 0

	# 移动
	sprite.global_position = current.move_toward(target_position, walk_speed * delta)
