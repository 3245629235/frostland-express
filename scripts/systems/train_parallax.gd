extends RefCounted
class_name TrainParallax
## 列车编组界面的视差滚动系统

var wall_texture: Texture2D
var cf_texture: Texture2D
var wall_scaled_width: float = 0.0
var cf_scaled_width: float = 0.0

var scroll_x: float = 0.0
var target_scroll: float = 0.0
var max_scroll: float = 0.0
var momentum: float = 0.0
var train_length: float = 3.0

var is_dragging_screen: bool = false
var drag_start_mouse_x: float = 0.0
var drag_start_scroll: float = 0.0
var last_mouse_x: float = 0.0

var view_w: float = 0.0
var view_h: float = 0.0

var wall_speed_ratio: float = 0.8
var cf_speed_ratio: float = 1.0

var _wall_container: Control
var _cf_container: Control

func init(wall: Control, cf: Control, vw: float, vh: float, wal_speed: float = 0.8, cf_speed: float = 1.0) -> bool:
	_wall_container = wall
	_cf_container = cf
	view_w = vw
	view_h = vh
	wall_speed_ratio = wal_speed
	cf_speed_ratio = cf_speed

	wall_texture = load("res://assets/sprites/wall.png") as Texture2D
	cf_texture = load("res://assets/sprites/ceiling_floor.png") as Texture2D
	if wall_texture == null or cf_texture == null:
		return false

	var wall_scale: float = view_h / wall_texture.get_height()
	var cf_scale: float = view_h / cf_texture.get_height()
	wall_scaled_width = wall_texture.get_width() * wall_scale
	cf_scaled_width = cf_texture.get_width() * cf_scale
	_create_parallax_sprites(_wall_container, wall_texture, wall_scaled_width)
	_create_parallax_sprites(_cf_container, cf_texture, cf_scaled_width)
	return true

func _create_parallax_sprites(container: Control, tex: Texture2D, scaled_w: float) -> void:
	var count: int = int(ceil(view_w / scaled_w)) + 2
	for i in range(count):
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.offset_left = i * scaled_w
		t.offset_top = 0
		t.offset_right = i * scaled_w + scaled_w
		t.offset_bottom = view_h
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(t)

func process(delta: float, has_vehicles: bool) -> void:
	if not is_dragging_screen:
		momentum *= 0.92
		target_scroll += momentum
		target_scroll = clamp(target_scroll, 0, max_scroll)
		if target_scroll == 0 or target_scroll == max_scroll:
			momentum = 0

	scroll_x = lerp(scroll_x, target_scroll, 10.0 * delta)
	_update_parallax_positions()

func _update_parallax_positions() -> void:
	_update_layer_positions(_wall_container, wall_scaled_width, scroll_x * wall_speed_ratio)
	_update_layer_positions(_cf_container, cf_scaled_width, scroll_x * cf_speed_ratio)

func _update_layer_positions(container: Control, scaled_w: float, offset: float) -> void:
	var children: Array[Node] = container.get_children()
	var wrap_w = scaled_w * children.size()
	var mod_off = fmod(offset, scaled_w)
	for i in range(children.size()):
		var sp: TextureRect = children[i] as TextureRect
		if sp == null:
			continue
		var x: float = i * scaled_w - mod_off
		while x < -scaled_w:
			x += wrap_w
		while x > view_w:
			x -= wrap_w
		sp.offset_left = x
		sp.offset_right = x + scaled_w

func update_max_scroll(placed_vehicles: Array, train_start_x_ratio: float) -> void:
	if placed_vehicles.is_empty():
		max_scroll = cf_scaled_width * train_length - view_w
	else:
		var total_width = 0.0
		for v in placed_vehicles:
			total_width += v.width
		max_scroll = total_width - view_w * 0.3
	max_scroll = max(max_scroll, 0)
	if target_scroll > max_scroll:
		target_scroll = max_scroll

func handle_scroll_input(event: InputEvent, card_panel_height: float) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.y < view_h - card_panel_height:
				is_dragging_screen = true
				drag_start_mouse_x = event.position.x
				drag_start_scroll = target_scroll
				last_mouse_x = event.position.x
				momentum = 0
		else:
			is_dragging_screen = false
	elif event is InputEventMouseMotion and is_dragging_screen:
		var dx: float = event.position.x - drag_start_mouse_x
		target_scroll = clamp(drag_start_scroll - dx, 0, max_scroll)
		momentum = last_mouse_x - event.position.x
		last_mouse_x = event.position.x
