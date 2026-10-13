extends RefCounted
class_name StationSystem
## 站点规则：纯函数，Travel 负责时序和 UI。

static func get_station(index: int) -> Dictionary:
	return StationData.get_station(index)

static func should_arrive(route_distance_km: float, station_index: int) -> bool:
	var station := get_station(station_index)
	return not station.is_empty() and route_distance_km >= float(station.get("km", INF))

static func next_station_index(current_index: int) -> int:
	return clampi(current_index + 1, 0, StationData.get_all().size() - 1)

static func repair_cost(station_index: int) -> int:
	var station := get_station(station_index)
	return int(station.get("repair_cost", GameConfig.REPAIR_COST_PARTS))

static func continue_from_station(station_index: int, current_lap: int) -> Dictionary:
	var last_index := StationData.get_all().size() - 1
	if station_index >= last_index:
		return {"next_station_index": 0, "route_lap": current_lap + 1, "route_distance_km": 0.0}
	var station := get_station(station_index)
	return {"next_station_index": next_station_index(station_index), "route_lap": current_lap, "route_distance_km": float(station.get("km", 0.0))}

static func collect_reward(seed: int = 0) -> Dictionary:
	var safe_seed := absi(seed) if seed != 0 else 17
	# Day 7 修复：改用 GameConfig 收集区间（原硬编码 5~15/3~10 与平衡表脱节）
	var food_t := fposmod(float(safe_seed) / 100.0, 1.0)
	var fuel_t := fposmod(float(safe_seed) * 0.618 / 100.0, 1.0)
	return {
		"food": int(lerpf(GameConfig.COLLECT_FOOD_MIN, GameConfig.COLLECT_FOOD_MAX, food_t)),
		"fuel": int(lerpf(GameConfig.COLLECT_FUEL_MIN, GameConfig.COLLECT_FUEL_MAX, fuel_t)),
	}

static func supply_result(resources: Dictionary, station_index: int) -> Dictionary:
	var station := get_station(station_index)
	var food_cost := int(station.get("supply_food_cost", 20))
	if int(resources.get("food", 0)) < food_cost:
		return {"ok": false, "message": "食物不足（需要 %d）" % food_cost}
	resources["food"] = int(resources.get("food", 0)) - food_cost
	resources["medicine"] = int(resources.get("medicine", 0)) + 5
	return {"ok": true, "message": "补给完成：药品 +5，食物 -%d" % food_cost}