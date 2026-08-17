extends Node

func _ready() -> void:
	print("=== 数据流测试开始 ===")
	print("1. 当前GameState.train.carriages数量: %d" % GameState.train.get("carriages", []).size())
	print("2. has_powered_locomotive: %s" % GameState.has_powered_locomotive())
	print("3. resources.fuel: %d" % GameState.resources.get("fuel", 0))
	
	# 模拟编组界面保存的列车数据
	var test_carriages = [
		{"type": "locomotive", "flipped": false},
		{"type": "coal_tender", "flipped": false},
	]
	
	print("\n4. 调用 update_train_composition 模拟编组保存...")
	GameState.update_train_composition(test_carriages)
	
	print("\n5. 更新后 has_powered_locomotive: %s" % GameState.has_powered_locomotive())
	print("6. 更新后 carriages数量: %d" % GameState.train.get("carriages", []).size())
	for c in GameState.train.get("carriages", []):
		print("   type=%s fuel_left=%s is_powered=%s" % [c.get("type","?"), c.get("fuel_left","N/A"), c.get("is_powered","N/A")])
	
	# 测试加速模式
	print("\n7. 测试加速模式...")
	GameState.train_control_mode = 1
	print("   train_control_mode = %d" % GameState.train_control_mode)
	print("   has_powered_locomotive = %s" % GameState.has_powered_locomotive())
	
	if GameState.train_control_mode == 1 and not GameState.has_powered_locomotive():
		print("   进入无动力检查...")
		GameState.refresh_train_runtime_state()
		if not GameState.has_powered_locomotive():
			GameState.train_control_mode = 0
			print("   FAIL: 仍然无动力，重置为滑行")
		else:
			print("   OK: refresh后恢复动力")
	else:
		print("   OK: 加速模式正常")
	
	print("   最终 train_control_mode = %d" % GameState.train_control_mode)
	print("=== 数据流测试结束 ===")
	get_tree().quit()