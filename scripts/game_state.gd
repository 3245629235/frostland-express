extends Node
# ===== 全局游戏状态单例（Autoload）=====
# 职责：状态存取 + 持久化 + 公开 API
# 物理/燃油/世界推进 → 委托给 systems/ 下的专用类

enum ResourceType { FOOD, FUEL, MEDICINE, PARTS, AMMO_SMALL, AMMO_LARGE }

const RESOURCE_STR = {
	ResourceType.FOOD: "food",
	ResourceType.FUEL: "fuel",
	ResourceType.MEDICINE: "medicine",
	ResourceType.PARTS: "parts",
	ResourceType.AMMO_SMALL: "ammo_small",
	ResourceType.AMMO_LARGE: "ammo_large",
}

const STR_RESOURCE = {
	"food": ResourceType.FOOD,
	"fuel": ResourceType.FUEL,
	"medicine": ResourceType.MEDICINE,
	"parts": ResourceType.PARTS,
	"ammo_small": ResourceType.AMMO_SMALL,
	"ammo_large": ResourceType.AMMO_LARGE,
}

const RESOURCE_NAMES = {
	ResourceType.FOOD: "食物",
	ResourceType.FUEL: "燃料",
	ResourceType.MEDICINE: "药品",
	ResourceType.PARTS: "零件",
	ResourceType.AMMO_SMALL: "小口径弹药",
	ResourceType.AMMO_LARGE: "大口径弹药",
}

# ===== 游戏状态数据 =====
var resources: Dictionary = {}
var characters: Array = []
var train: Dictionary = {}
var morale: float = 50.0
var is_traveling: bool = false
var travel_time: float = 0.0
var world_consume_time: float = 0.0
var current_node: String = "station_start"

# 0=滑行(仅风阻), 1=加速(满出力), 2=刹车
var train_control_mode: int = 0


# ===== 初始化 =====
func _ready() -> void:
	_reset_resources()
	_reset_train()
	load_state()

func _reset_resources() -> void:
	resources = {
		"food": 1000, "fuel": 1000, "medicine": 1000,
		"parts": 1000, "ammo_small": 1000, "ammo_large": 1000,
	}

func _reset_train() -> void:
	train = {
		"health": 100.0, "max_health": 100.0, "speed": 0.0,
		"carriages": [], "locomotive_count": 0, "total_mass": 0.0,
	}


# ===== 完整重置 =====
func full_reset() -> void:
	_reset_resources()
	_reset_train()
	characters = []
	morale = 50.0
	is_traveling = false
	travel_time = 0.0
	world_consume_time = 0.0
	current_node = "station_start"
	train_control_mode = 0

func reset_resources() -> void:
	_reset_resources()


# ===== 资源操作 =====
func get_resource(type_str: String) -> int:
	return resources.get(type_str, 0)

func add_resource(type_str: String, amount: int) -> void:
	resources[type_str] = resources.get(type_str, 0) + amount

func consume_resource(type_str: String, amount: int) -> bool:
	if resources.get(type_str, 0) >= amount:
		resources[type_str] -= amount
		return true
	return false


# ===== 列车状态 =====
func set_train_health(health: float) -> void:
	train["health"] = clamp(health, 0, train["max_health"])

func damage_train(amount: float) -> void:
	set_train_health(train["health"] - amount)

func repair_train(amount: float) -> void:
	set_train_health(train["health"] + amount)

func get_train_efficiency() -> float:
	return train["health"] / train["max_health"]


# ===== 编组数据同步（由 team.gd 在保存编组时调用）=====
func update_train_composition(carriages: Array) -> void:
	var old = train["carriages"]
	train["carriages"] = carriages.duplicate(true)
	for i in range(train["carriages"].size()):
		var c = train["carriages"][i]
		var type_str = c.get("type", "")
		var vtype = VehicleTypes.STR_TYPE.get(type_str)
		if vtype == null:
			continue
		var cfg = VehicleTypes.CONFIG[vtype]
		var preserve = i < old.size() and old[i].get("type") == type_str
		if type_str == "coal_tender":
			c["fuel_left"] = old[i].get("fuel_left", cfg["coal_capacity"]) if preserve else cfg["coal_capacity"]
		else:
			c["fuel_left"] = old[i].get("fuel_left", 0.0) if preserve else 0.0
		c["health"] = old[i].get("health", cfg["durability"]) if preserve else cfg["durability"]
		if type_str == "locomotive":
			c["is_powered"] = true
		else:
			c["is_powered"] = false
	# 委托给系统类
	TrainPhysics.recalc_train_stats(train)
	FuelSystem.refuel_tenders(train, resources)
	FuelSystem.refresh_loco_power(train)

func refresh_train_runtime_state() -> void:
	TrainPhysics.recalc_train_stats(train)
	FuelSystem.refuel_tenders(train, resources)
	FuelSystem.refresh_loco_power(train)


# ===== 旅行控制 =====
func start_travel() -> void:
	is_traveling = true
	travel_time = 0.0
	world_consume_time = 0.0

func stop_travel() -> void:
	is_traveling = false
	world_consume_time = 0.0


# ===== 世界推进（每帧）=====
func tick_world(delta: float, crew_count: int = 0) -> Dictionary:
	var result = WorldTick.tick_world(delta, crew_count, world_consume_time, train, resources, train_control_mode)
	world_consume_time = result["world_consume_time"]
	return result


# ===== 查询接口 =====
func get_train_speed() -> float:
	var s = train.get("speed", 0.0)
	return s if s != null else 0.0

func has_powered_locomotive() -> bool:
	for c in train["carriages"]:
		if c["type"] == "locomotive" and c.get("is_powered", false):
			return true
	return false

func get_train_fuel_consumption() -> float:
	var total = 0.0
	for c in train["carriages"]:
		if c["type"] == "locomotive" and c.get("is_powered", false):
			total += VehicleTypes.CONFIG[VehicleTypes.STR_TYPE["locomotive"]]["fuel_consume"]
	return total

func get_train_mass_burden() -> float:
	var loco_count = train.get("locomotive_count", 0)
	var total_mass = train.get("total_mass", 0.0)
	if loco_count <= 0:
		return 1.0
	return max(total_mass / (loco_count * 100.0), 1.0)

func get_loco_power_status() -> Array:
	var status: Array = []
	for c in train["carriages"]:
		if c["type"] == "locomotive":
			status.append(c.get("is_powered", false))
	return status

func get_tender_fuel_levels() -> Array:
	var levels: Array = []
	for c in train["carriages"]:
		if c["type"] == "coal_tender":
			var fuel = c.get("fuel_left", 0.0)
			var vtype = VehicleTypes.STR_TYPE.get("coal_tender")
			var cap = 0.0
			if vtype != null:
				cap = VehicleTypes.CONFIG[vtype]["coal_capacity"]
			levels.append({"fuel": fuel, "capacity": cap})
	return levels


# ===== 保存/加载 =====
func save_state() -> void:
	var save_data = {
		"resources": resources,
		"characters": characters,
		"train": train,
		"morale": morale,
		"is_traveling": is_traveling,
		"travel_time": travel_time,
		"world_consume_time": world_consume_time,
		"current_node": current_node,
	}
	var file = FileAccess.open("user://game_state.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_state() -> bool:
	if not FileAccess.file_exists("user://game_state.json"):
		return false
	var file = FileAccess.open("user://game_state.json", FileAccess.READ)
	if not file:
		return false
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if data == null:
		return false
	if data.has("resources"):
		resources = data["resources"]
	if data.has("characters"):
		characters = data["characters"]
	if data.has("train"):
		train = data["train"]
	if data.has("morale"):
		morale = float(data["morale"])
	if data.has("is_traveling"):
		is_traveling = bool(data["is_traveling"])
	if data.has("travel_time"):
		travel_time = float(data["travel_time"])
	if data.has("world_consume_time"):
		world_consume_time = float(data["world_consume_time"])
	if data.has("current_node"):
		current_node = data["current_node"]
	refresh_train_runtime_state()
	return true

func _exit_tree() -> void:
	save_state()


# ===== 旅行消耗计算 =====
func calculate_travel_consumption(duration: float) -> Dictionary:
	return {
		"food": int(duration * 2),
		"fuel": int(duration * 3),
	}

func apply_travel_consumption(consumption: Dictionary) -> bool:
	for key in consumption.keys():
		if not consume_resource(key, consumption[key]):
			return false
	return true
