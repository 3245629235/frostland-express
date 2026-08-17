extends RefCounted
class_name CharacterData

# ===== 统一角色数据源 =====
# 合并 team_select.ALL_CHARACTERS 与 survival.INITIAL_CHARACTERS 的字段
# 所有场景从此处引用，避免数据定义重复

const ALL_CHARACTERS: Array = [
	{
		"id": "conductor",
		"name": "列车长",
		"role": "全能",
		"portrait": "res://assets/sprites/characters/101/列车长常服新.png",
		"stars": 5,
		"level": 1,
		"health": 100,
		"max_health": 100,
		"attack": 60,
		"stamina": 100,
		"max_stamina": 100,
		"hunger": 50,
		"temperature": 90,
		"morale": 70,
		"status": "待命",
		"traits": "PDW专精, 全能指挥",
	},
	{
		"id": "laoge",
		"name": "老葛",
		"role": "司机",
		"portrait": "res://assets/sprites/characters/老葛/老葛常服.png",
		"stars": 4,
		"level": 1,
		"health": 110,
		"max_health": 110,
		"attack": 55,
		"stamina": 120,
		"max_stamina": 120,
		"hunger": 50,
		"temperature": 90,
		"morale": 60,
		"status": "待命",
		"traits": "猎枪专精, 驾驶专精",
	},
	{
		"id": "xiaowang",
		"name": "小王",
		"role": "警卫",
		"portrait": "res://assets/sprites/characters/王刚/王刚常服.png",
		"stars": 5,
		"level": 1,
		"health": 120,
		"max_health": 120,
		"attack": 75,
		"stamina": 110,
		"max_stamina": 110,
		"hunger": 50,
		"temperature": 90,
		"morale": 65,
		"status": "待命",
		"traits": "武器大师",
	},
	{
		"id": "xiaoliu",
		"name": "小刘",
		"role": "医疗",
		"portrait": "res://assets/sprites/characters/小刘/小刘常服.png",
		"stars": 4,
		"level": 1,
		"health": 90,
		"max_health": 90,
		"attack": 45,
		"stamina": 95,
		"max_stamina": 95,
		"hunger": 50,
		"temperature": 90,
		"morale": 65,
		"status": "待命",
		"traits": "PDW专精, 医护专精",
	},
	{
		"id": "lisi",
		"name": "李四",
		"role": "工程师",
		"portrait": "res://assets/sprites/characters/小刘/小刘常服.png",
		"stars": 4,
		"level": 1,
		"health": 100,
		"max_health": 100,
		"attack": 50,
		"stamina": 100,
		"max_stamina": 100,
		"hunger": 50,
		"temperature": 90,
		"morale": 60,
		"status": "待命",
		"traits": "维修专精, 爆破专精",
	},
	{
		"id": "zhangsan",
		"name": "张三",
		"role": "侦察",
		"portrait": "res://assets/sprites/characters/王刚/王刚常服.png",
		"stars": 3,
		"level": 1,
		"health": 85,
		"max_health": 85,
		"attack": 65,
		"stamina": 120,
		"max_stamina": 120,
		"hunger": 50,
		"temperature": 90,
		"morale": 60,
		"status": "待命",
		"traits": "潜行专精, 狙击专精",
	},
	{
		"id": "wangwu",
		"name": "王五",
		"role": "厨师",
		"portrait": "res://assets/sprites/characters/老葛/老葛常服.png",
		"stars": 3,
		"level": 1,
		"health": 80,
		"max_health": 80,
		"attack": 40,
		"stamina": 90,
		"max_stamina": 90,
		"hunger": 50,
		"temperature": 90,
		"morale": 60,
		"status": "待命",
		"traits": "烹饪专精, 采集专精",
	},
	{
		"id": "zhaoliu",
		"name": "赵六",
		"role": "通讯兵",
		"portrait": "res://assets/sprites/characters/小刘/小刘常服.png",
		"stars": 3,
		"level": 1,
		"health": 75,
		"max_health": 75,
		"attack": 50,
		"stamina": 100,
		"max_stamina": 100,
		"hunger": 50,
		"temperature": 90,
		"morale": 60,
		"status": "待命",
		"traits": "通讯专精, 破解专精",
	},
]

# 获取默认队员（前4人）
static func get_default_team() -> Array:
	return ALL_CHARACTERS.slice(0, 4)

# 根据 id 查找角色定义
static func find_by_id(id: String) -> Dictionary:
	for c in ALL_CHARACTERS:
		if c.id == id:
			return c.duplicate(true)
	return {}

# 获取所有已定义的角色 id 列表
static func get_all_ids() -> Array:
	var ids: Array = []
	for c in ALL_CHARACTERS:
		ids.append(c.id)
	return ids
