extends RefCounted
class_name VehicleTypes

# 车辆类型枚举
enum Type { LOCOMOTIVE, COAL_TENDER, PASSENGER, OPEN_CAR, TANK_CAR, SERVICE_CAR, COMBAT_CAR }

# 类型字符串映射
const TYPE_STR = {
	Type.LOCOMOTIVE: "locomotive",
	Type.COAL_TENDER: "coal_tender",
	Type.PASSENGER: "passenger",
	Type.OPEN_CAR: "open_car",
	Type.TANK_CAR: "tank_car",
	Type.SERVICE_CAR: "service_car",
	Type.COMBAT_CAR: "combat_car",
}

const STR_TYPE = {
	"locomotive": Type.LOCOMOTIVE,
	"coal_tender": Type.COAL_TENDER,
	"passenger": Type.PASSENGER,
	"open_car": Type.OPEN_CAR,
	"tank_car": Type.TANK_CAR,
	"service_car": Type.SERVICE_CAR,
	"combat_car": Type.COMBAT_CAR,
}

# 车型配置：名称、卡片路径、车辆素材路径、初始数量、性能数据
# mass           — 空车质量（吨），影响牵引计算和惯性
# drag_coefficient — 空气阻力系数（无量纲），越大阻力越大
# durability     — 车厢耐久度（血量），战斗中可能被击破
# coal_consume   — 燃煤消耗率（吨/单位时间），仅机车
# water_consume  — 水消耗率（吨/单位时间），仅机车
# fuel_consume   — 统一燃料消耗率，当前等于 coal_consume（后期内燃机车独立设置）
# tractive_power — 牵引力（千牛），仅机车
# coal_capacity  — 最大载煤量（吨），仅煤水车
# water_capacity — 最大载水量（吨），仅煤水车
# cargo_mass     — 最大载货质量（吨）
# cargo_volume   — 最大载货体积（立方米）
# crew           — 可搭载人员数量
# combat         — 战斗力贡献值
const CONFIG = {
	Type.LOCOMOTIVE: {
		"name": "机车",
		"card_path": "res://assets/sprites/vehicles/locomotive/locomotive_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/locomotive/locomotive.png",
		"initial_count": 3,
		"mass": 90,
		"drag_coefficient": 0.35,
		"durability": 100,
		"coal_consume": 0.5,
		"water_consume": 2.0,
		"fuel_consume": 0.5,
		"tractive_power": 300,
		"coal_capacity": 0,
		"water_capacity": 0,
		"cargo_mass": 0,
		"cargo_volume": 0,
		"crew": 2,
		"combat": 0,
	},
	Type.COAL_TENDER: {
		"name": "煤水车",
		"card_path": "res://assets/sprites/vehicles/coal_tender/coal_tender_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/coal_tender/coal_tender.png",
		"initial_count": 4,
		"mass": 25,
		"drag_coefficient": 0.55,
		"durability": 80,
		"coal_consume": 0.0,
		"water_consume": 0.0,
		"fuel_consume": 0.0,
		"coal_capacity": 25,
		"water_capacity": 35,
		"cargo_mass": 50,
		"cargo_volume": 55,
		"crew": 1,
		"combat": 0,
	},
	Type.PASSENGER: {
		"name": "客车",
		"card_path": "res://assets/sprites/vehicles/passenger/passenger_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/passenger/passenger.png",
		"initial_count": 2,
		"mass": 30,
		"drag_coefficient": 0.40,
		"durability": 60,
		"coal_consume": 0.0,
		"water_consume": 0.0,
		"fuel_consume": 0.0,
		"coal_capacity": 0,
		"water_capacity": 0,
		"cargo_mass": 5,
		"cargo_volume": 20,
		"crew": 6,
		"combat": 0,
	},
	Type.OPEN_CAR: {
		"name": "敞车",
		"card_path": "res://assets/sprites/vehicles/open_car/open_car_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/open_car/open_car.png",
		"initial_count": 1,
		"mass": 18,
		"drag_coefficient": 0.75,
		"durability": 50,
		"coal_consume": 0.0,
		"water_consume": 0.0,
		"fuel_consume": 0.0,
		"coal_capacity": 0,
		"water_capacity": 0,
		"cargo_mass": 70,
		"cargo_volume": 90,
		"crew": 2,
		"combat": 0,
	},
	Type.TANK_CAR: {
		"name": "罐车",
		"card_path": "res://assets/sprites/vehicles/tank_car/tank_car_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/tank_car/tank_car.png",
		"initial_count": 1,
		"mass": 20,
		"drag_coefficient": 0.45,
		"durability": 40,
		"coal_consume": 0.0,
		"water_consume": 0.0,
		"fuel_consume": 0.0,
		"coal_capacity": 0,
		"water_capacity": 0,
		"cargo_mass": 55,
		"cargo_volume": 60,
		"crew": 1,
		"combat": 0,
	},
	Type.SERVICE_CAR: {
		"name": "勤务车厢",
		"card_path": "res://assets/sprites/vehicles/service_car/service_car_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/service_car/service_car.png",
		"initial_count": 2,
		"mass": 28,
		"drag_coefficient": 0.55,
		"durability": 70,
		"coal_consume": 0.0,
		"water_consume": 0.0,
		"fuel_consume": 0.0,
		"coal_capacity": 0,
		"water_capacity": 0,
		"cargo_mass": 20,
		"cargo_volume": 45,
		"crew": 4,
		"combat": 10,
	},
	Type.COMBAT_CAR: {
		"name": "战斗车厢",
		"card_path": "res://assets/sprites/vehicles/combat_car/combat_car_card.png",
		"vehicle_path": "res://assets/sprites/vehicles/combat_car/combat_car.png",
		"initial_count": 2,
		"mass": 40,
		"drag_coefficient": 0.65,
		"durability": 90,
		"coal_consume": 0.0,
		"water_consume": 0.0,
		"fuel_consume": 0.0,
		"coal_capacity": 0,
		"water_capacity": 0,
		"cargo_mass": 8,
		"cargo_volume": 30,
		"crew": 3,
		"combat": 50,
	},
}

# 获取所有类型
static func get_all_types() -> Array:
	return CONFIG.keys()

# 根据字符串获取枚举类型
static func from_string(s: String) -> Type:
	return STR_TYPE[s]

# 转为字符串
static func enum_to_string(t: Type) -> String:
	return TYPE_STR[t]

# 获取名称
static func get_name(t: Type) -> String:
	return CONFIG[t].name

# 获取卡片路径
static func get_card_path(t: Type) -> String:
	return CONFIG[t].card_path

# 获取车辆素材路径
static func get_vehicle_path(t: Type) -> String:
	return CONFIG[t].vehicle_path

# 获取初始数量
static func get_initial_count(t: Type) -> int:
	return CONFIG[t].initial_count

# 构建初始库存字典 {类型字符串: 数量}
static func build_initial_inventory() -> Dictionary:
	var inv = {}
	for t in CONFIG.keys():
		inv[TYPE_STR[t]] = CONFIG[t].initial_count
	return inv
