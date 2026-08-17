extends RefCounted
class_name FuelSystem
## 燃油系统 — 补给、消耗、机车动力校验

## 从全局燃料池给煤水车补燃料
static func refuel_tenders(train: Dictionary, resources: Dictionary) -> void:
	for c in train["carriages"]:
		if c["type"] != "coal_tender":
			continue
		var coal_cap = VehicleTypes.CONFIG[VehicleTypes.STR_TYPE["coal_tender"]]["coal_capacity"]
		if c.get("fuel_left", 0.0) < coal_cap:
			var refill = min(coal_cap - c["fuel_left"], float(resources.get("fuel", 0)))
			if refill > 0:
				c["fuel_left"] = c.get("fuel_left", 0.0) + refill
				resources["fuel"] -= int(ceil(refill))

## 消耗燃料（由 tick_world 周期性调用）
## fuel_amount：本周期总消耗（DEMO_DESIGN §2.2：基础 3/2s，速度>60km/h ×1.5），
## 平均分摊给每台有动力机车，从其连挂的煤水车扣除；煤水车不足则该机车失去动力。
static func consume_train_fuel(train: Dictionary, fuel_amount: float) -> void:
	var powered_locos: Array = []
	for i in range(train["carriages"].size()):
		var c = train["carriages"][i]
		if c["type"] == "locomotive" and c.get("is_powered", false):
			powered_locos.append(i)
	if powered_locos.is_empty():
		return

	var per_loco: float = fuel_amount / powered_locos.size()
	for loco_idx in powered_locos:
		var c = train["carriages"][loco_idx]
		var tender_idx = _find_coal_tender(loco_idx, c.get("flipped", false), train)
		if tender_idx < 0:
			c["is_powered"] = false
			continue
		var tender = train["carriages"][tender_idx]
		if tender["fuel_left"] >= per_loco:
			tender["fuel_left"] -= per_loco
		else:
			tender["fuel_left"] = 0.0
			c["is_powered"] = false

## 刷新所有机车的动力状态
static func refresh_loco_power(train: Dictionary) -> void:
	for i in range(train["carriages"].size()):
		var c = train["carriages"][i]
		if c["type"] != "locomotive":
			continue
		var tender_idx = _find_coal_tender(i, c.get("flipped", false), train)
		c["is_powered"] = tender_idx >= 0

# ===== 内部辅助 =====

static func _find_coal_tender(loco_idx: int, flipped: bool, train: Dictionary) -> int:
	var carriages = train["carriages"]
	if train.get("locomotive_count", 0) <= 1:
		var left_idx = _scan_tender_direction(loco_idx, -1, carriages)
		var right_idx = _scan_tender_direction(loco_idx, 1, carriages)
		if left_idx < 0:
			return right_idx
		if right_idx < 0:
			return left_idx
		var left_dist = abs(left_idx - loco_idx)
		var right_dist = abs(right_idx - loco_idx)
		return left_idx if left_dist <= right_dist else right_idx
	if flipped:
		return _scan_tender_direction(loco_idx, -1, carriages)
	else:
		return _scan_tender_direction(loco_idx, 1, carriages)

static func _scan_tender_direction(start_idx: int, step: int, carriages: Array) -> int:
	var j = start_idx + step
	while j >= 0 and j < carriages.size():
		var c = carriages[j]
		if c["type"] == "locomotive" or _is_cargo_type(c["type"]):
			break
		if c["type"] == "coal_tender" and c.get("fuel_left", 0.0) > 0:
			return j
		j += step
	return -1

static func _is_cargo_type(type_str: String) -> bool:
	return type_str == "passenger" or type_str == "open_car" or type_str == "tank_car" or type_str == "service_car" or type_str == "combat_car"
