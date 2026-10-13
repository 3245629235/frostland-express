extends RefCounted
class_name StationData
## Day 3 生存站点目录。

const STATIONS: Array = [
	{"id": "birch_forest", "name": "白桦林站", "km": 80.0, "forced": true, "repair_cost": 10, "supply_food_cost": 20},
	{"id": "frozen_lake", "name": "冻湖站", "km": 180.0, "forced": false, "repair_cost": 10, "supply_food_cost": 20},
	{"id": "iron_pass", "name": "铁岭口", "km": 300.0, "forced": false, "repair_cost": 5, "supply_food_cost": 20},
	{"id": "aurora_city", "name": "极光城", "km": 420.0, "forced": false, "repair_cost": 10, "supply_food_cost": 20, "turnaround": true},
]

static func get_all() -> Array:
	return STATIONS.duplicate(true)

static func get_station(index: int) -> Dictionary:
	if index < 0 or index >= STATIONS.size():
		return {}
	return STATIONS[index].duplicate(true)

static func get_station_by_id(station_id: String) -> Dictionary:
	for station in STATIONS:
		if str(station.get("id", "")) == station_id:
			return station.duplicate(true)
	return {}