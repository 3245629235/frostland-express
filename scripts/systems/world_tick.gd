extends RefCounted
class_name WorldTick
## 世界时间推进 —— 管理消耗周期，调度物理 + 燃油系统

## 每帧调用，返回事件字典
static func tick_world(delta: float, crew_count: int, world_consume_time: float, train: Dictionary, resources: Dictionary, train_control_mode: int, is_traveling: bool) -> Dictionary:
	# 副作用：更新 world_consume_time 并返回新值
	var events = {
		"consume_steps": 0,
		"food_ok_steps": 0,
		"food_fail_steps": 0,
		"travel_completed": false,
		"world_consume_time": world_consume_time,
	}

	# 1. 列车物理
	TrainPhysics.update_physics(delta, train, train_control_mode)

	# 2. 仅旅行中且列车在动时才消耗资源（DEMO_DESIGN §2：食物/燃料随行驶结算）
	if not is_traveling or train.get("speed", 0.0) <= 0.01:
		return events

	var wt = world_consume_time + delta
	events["world_consume_time"] = wt

	while wt >= GameConfig.CONSUME_INTERVAL:
		wt -= GameConfig.CONSUME_INTERVAL
		events["consume_steps"] += 1
		events["world_consume_time"] = wt

		# 食物消耗
		var food_cost = max(crew_count, 0) * GameConfig.FOOD_PER_CHAR_PER_TICK
		var has_food = true
		if food_cost > 0:
			has_food = _consume_resource(resources, "food", food_cost)
		if has_food:
			events["food_ok_steps"] += 1
		else:
			events["food_fail_steps"] += 1

		# 燃料：先把全局燃料池补给到煤水车（25 上限缓冲），再按设计值消耗
		FuelSystem.refuel_tenders(train, resources)
		var speed_kmh: float = train.get("speed", 0.0) * 3.6
		var fuel_cost: float = GameConfig.FUEL_BASE_PER_TICK
		if speed_kmh > GameConfig.FUEL_SPEED_BONUS_KMH:
			fuel_cost *= GameConfig.FUEL_SPEED_BONUS_MULT
		FuelSystem.consume_train_fuel(train, fuel_cost)

	return events

static func _consume_resource(resources: Dictionary, type_str: String, amount: int) -> bool:
	if resources.get(type_str, 0) >= amount:
		resources[type_str] -= amount
		return true
	return false
