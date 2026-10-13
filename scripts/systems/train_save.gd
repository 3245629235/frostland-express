extends RefCounted
class_name TrainSave
## 列车编组同步 —— 唯一真相源为 GameState，不再写独立文件

## 旧版编组存档（BUG-001 修复前的历史文件）
const LEGACY_SAVE_PATH := "user://train_save.json"
const LEGACY_SAVE_BAK := "user://train_save.json.legacy_bak"


## 兜底迁移：GameState 无编组数据时，从旧版 train_save.json 恢复。
## 迁移成功后旧文件备份为 .legacy_bak 并移除原文件，避免重复迁移。
## 返回 true 表示本次执行了迁移。
static func migrate_legacy_train_save() -> bool:
	if not GameState.train.get("carriages", []).is_empty():
		return false
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return false

	var file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if data == null or not (data is Dictionary):
		return false
	var placed: Array = data.get("placed_vehicles", [])
	if placed.is_empty():
		return false

	# 旧格式只有 type/flipped；fuel/health/is_powered 由 update_train_composition 按配置补齐
	var carriages: Array = []
	for v in placed:
		if v is Dictionary and v.has("type"):
			carriages.append({
				"type": str(v["type"]),
				"flipped": bool(v.get("flipped", false)),
			})

	GameState.update_train_composition(carriages)
	GameState.save_state()

	# 备份旧文件后删除，防止下次启动重复迁移
	var bak := FileAccess.open(LEGACY_SAVE_BAK, FileAccess.WRITE)
	if bak != null:
		bak.store_string(content)
		bak.close()
	var abs_path := ProjectSettings.globalize_path(LEGACY_SAVE_PATH)
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(abs_path)
	return true

## 保存：序列化 placed_vehicles → 同步到 GameState
static func save_train(placed_vehicles: Array, _player_inventory: Dictionary, _vehicle_data: Dictionary) -> void:
	var carriages: Array = []
	for v in placed_vehicles:
		carriages.append({"type": v.type, "flipped": v.flipped})
	GameState.update_train_composition(carriages)
	GameState.save_state()

## 加载：从 GameState 恢复 placed_vehicles（重建 node），从初始总量反推 inventory
static func load_train_save(placed_vehicles: Array, player_inventory: Dictionary, vehicle_data: Dictionary, placed_vehicles_node: Control, on_vehicle_gui_input: Callable) -> bool:
	migrate_legacy_train_save()
	var carriages = GameState.train.get("carriages", [])
	if carriages.is_empty():
		return false

	# 从 GameState 恢复已放置车辆（重建 TextureRect node）
	for v_data in carriages:
		var vtype = v_data.type
		if not vehicle_data.has(vtype):
			continue
		var d = vehicle_data[vtype]
		var v_node := TextureRect.new()
		v_node.texture = d.vehicle_tex
		v_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v_node.stretch_mode = TextureRect.STRETCH_SCALE
		v_node.mouse_filter = Control.MOUSE_FILTER_STOP
		v_node.gui_input.connect(on_vehicle_gui_input.bind(v_node))
		placed_vehicles_node.add_child(v_node)
		placed_vehicles.append({
			"type": vtype,
			"width": d.scaled_width,
			"flipped": v_data.get("flipped", false),
			"node": v_node,
		})

	# 从初始总量反推 inventory（不再独立存储）
	for type_str in vehicle_data.keys():
		var placed_count = 0
		for v in placed_vehicles:
			if v.type == type_str:
				placed_count += 1
		player_inventory[type_str] = vehicle_data[type_str].initial_count - placed_count

	return true
