extends RefCounted
class_name WorldTick
## 世界时间推进 —— 管理消耗周期，调度物理 + 燃油系统

## 每帧调用，返回事件字典
static func tick_world(delta: float, crew_count: int, world_consume_time: float, train: Dictionary, resources: Dictionary, train_control_mode: int, is_traveling: bool, active_effects: Dictionary = {}) -> Dictionary:
	# 副作用：更新 world_consume_time 并返回新值
	var events = {
		"consume_steps": 0,
		"moving_steps": 0,
		"idle_steps": 0,
		"food_ok_steps": 0,
		"food_fail_steps": 0,
		"travel_completed": false,
		"world_consume_time": world_consume_time,
	}

	# 1. 列车物理
	var speed_multiplier := EventSystem.get_effect_multiplier(active_effects, "speed_multiplier")
	TrainPhysics.update_physics(delta, train, train_control_mode, speed_multiplier)

	# 2. 非旅行状态（主界面溜车）不结算消耗
	if not is_traveling:
		return events

	# 3. 每 CONSUME_INTERVAL 结算一次（行驶或停靠都会推进角色状态）
	var wt = world_consume_time + delta
	events["world_consume_time"] = wt

	while wt >= GameConfig.CONSUME_INTERVAL:
		wt -= GameConfig.CONSUME_INTERVAL
		events["world_consume_time"] = wt
		events["consume_steps"] += 1

		var moving: bool = train.get("speed", 0.0) > 0.01
		if moving:
			events["moving_steps"] += 1
		else:
			events["idle_steps"] += 1

		# 食物：每 tick 角色数×单耗（Day 6 起为浮点，全程）
		var food_cost: float = max(crew_count, 0) * GameConfig.FOOD_PER_CHAR_PER_TICK
		var has_food = true
		if food_cost > 0:
			has_food = _consume_resource(resources, "food", food_cost)
		if has_food:
			events["food_ok_steps"] += 1
		else:
			events["food_fail_steps"] += 1

		# 燃料：仅行驶时（速度>0），先补给煤水车缓冲再按设计值消耗
		if moving:
			FuelSystem.refuel_tenders(train, resources)
			var speed_kmh: float = train.get("speed", 0.0) * 3.6
			var fuel_cost: float = GameConfig.FUEL_BASE_PER_TICK
			if speed_kmh > GameConfig.FUEL_SPEED_BONUS_KMH:
				fuel_cost *= GameConfig.FUEL_SPEED_BONUS_MULT
			fuel_cost *= EventSystem.get_effect_multiplier(active_effects, "fuel_multiplier")
			FuelSystem.consume_train_fuel(train, fuel_cost)

	return events

static func _consume_resource(resources: Dictionary, type_str: String, amount: float) -> bool:
	if resources.get(type_str, 0) >= amount:
		resources[type_str] = maxf(0.0, float(resources.get(type_str, 0)) - amount)
		return true
	return false
