extends RefCounted
class_name TrainPhysics
## 列车物理引擎 —— 纯计算，不持有状态

## 重新计算列车统计（机车数量、总质量）
static func recalc_train_stats(train: Dictionary) -> void:
	var loco_count = 0
	var total_mass = 0.0
	for c in train["carriages"]:
		var type_str = c.get("type", "")
		var vtype = VehicleTypes.STR_TYPE.get(type_str)
		if vtype != null:
			total_mass += VehicleTypes.CONFIG[vtype].get("mass", 0)
			if type_str == "locomotive":
				loco_count += 1
	train["locomotive_count"] = loco_count
	train["total_mass"] = total_mass

## 每帧更新列车速度（mode: 0=滑行, 1=加速, 2=刹车）
static func update_physics(delta: float, train: Dictionary, mode: int = 0) -> void:
	var carriages = train.get("carriages", [])
	if carriages.is_empty():
		train["speed"] = 0.0
		return

	var speed = train.get("speed", 0.0)
	if speed == null:
		speed = 0.0

	# ---- 刹车模式 ----
	if mode == 2 and speed > 0.0:
		speed -= GameConfig.BRAKE_DECEL * delta
		if speed < 0.0:
			speed = 0.0
		train["speed"] = speed
		return

	# ---- 牵引力（仅加速模式） ----
	var f_tract = 0.0
	if mode == 1:
		for c in carriages:
			if c["type"] == "locomotive" and c.get("is_powered", false):
				f_tract += VehicleTypes.CONFIG[VehicleTypes.STR_TYPE["locomotive"]]["tractive_power"]

	var total_drag = 0.0
	var total_mass = 0.0
	for c in carriages:
		var vtype = VehicleTypes.STR_TYPE.get(c["type"])
		if vtype != null:
			total_drag += VehicleTypes.CONFIG[vtype]["drag_coefficient"]
			total_mass += VehicleTypes.CONFIG[vtype]["mass"]

	var f_aero = total_drag * GameConfig.AERO_FACTOR * speed * speed
	var f_net = f_tract - f_aero

	# 静止判断
	if f_net <= 0 and speed <= 0.01:
		train["speed"] = 0.0
		return

	var a = f_net / total_mass
	speed += a * delta

	if speed < 0:
		speed = 0.0
	train["speed"] = speed
