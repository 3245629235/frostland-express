extends RefCounted
class_name TrainSave
## 列车编组同步 —— 唯一真相源为 GameState，不再写独立文件

## 保存：序列化 placed_vehicles → 同步到 GameState
static func save_train(placed_vehicles: Array, player_inventory: Dictionary, vehicle_data: Dictionary) -> void:
	var carriages: Array = []
	for v in placed_vehicles:
		carriages.append({"type": v.type, "flipped": v.flipped})
	GameState.update_train_composition(carriages)
	GameState.save_state()

## 加载：从 GameState 恢复 placed_vehicles（重建 node），从初始总量反推 inventory
static func load_train_save(placed_vehicles: Array, player_inventory: Dictionary, vehicle_data: Dictionary, placed_vehicles_node: Control, on_vehicle_gui_input: Callable) -> bool:
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
