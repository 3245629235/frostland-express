extends RefCounted
class_name BattleData
## Day 4 战斗数据：敌人和波次均为只读配置。

const ENEMIES := {
	# Day 6 平衡：队伍火力 = 全员攻击合计（约 210/发），射速 1 发/秒。
	# 雪狼 600 = 3 发（教学关必过，9 只 ≈ 30 秒）；劫匪 800 = 4 发；持盾 1200 = 6 发 + 3 次破盾；
	# 匪首 3600 ≈ 16 发 ≈ 17 秒 → 30 秒限时内熟练可过、新手易超时（第二关可输）。
	"snow_wolf": {"name": "雪狼", "hp": 600.0, "speed": 42.0, "damage": 5.0, "color": Color(0.86, 0.93, 1.0)},
	"raider": {"name": "劫匪", "hp": 800.0, "speed": 30.0, "damage": 10.0, "color": Color(0.82, 0.28, 0.22)},
	"shield_raider": {"name": "持盾劫匪", "hp": 1200.0, "speed": 18.0, "damage": 15.0, "color": Color(0.45, 0.50, 0.58)},
	"boss": {"name": "匪首", "hp": 3600.0, "speed": 12.0, "damage": 20.0, "color": Color(0.80, 0.55, 0.16)},
}

const WAVES := [
	{"enemy": "snow_wolf", "count": 4, "interval": 2.0},
	{"enemy": "snow_wolf", "count": 3, "interval": 1.6},
]

const STORY_RAIDER_WAVES := {
	"safe": [
		{"enemy": "raider", "count": 3, "interval": 2.5},
		{"enemy": "shield_raider", "count": 1, "interval": 3.5},
		{"enemy": "boss", "count": 1, "interval": 3.0},
	],
	"aggressive": [
		{"enemy": "raider", "count": 4, "interval": 1.8},
		{"enemy": "shield_raider", "count": 2, "interval": 2.5},
		{"enemy": "boss", "count": 1, "interval": 2.2},
	],
}

static func get_enemy(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, {}).duplicate(true)

static func get_waves() -> Array:
	return WAVES.duplicate(true)

static func get_waves_for_level(level: int, branch: String = "") -> Array:
	if level == 3:
		var selected_branch := "aggressive" if branch == "aggressive" else "safe"
		return STORY_RAIDER_WAVES[selected_branch].duplicate(true)
	return get_waves()

static func get_level_title(level: int) -> String:
	match level:
		2:
			return "关卡 2「雪狼袭击」"
		3:
			return "关卡 3「劫匪关卡」"
		_:
			return "实时战斗"

static func validate() -> Dictionary:
	var errors: Array = []
	for enemy_id in ["snow_wolf", "raider", "shield_raider", "boss"]:
		var enemy: Dictionary = get_enemy(enemy_id)
		if enemy.is_empty() or float(enemy.get("hp", 0.0)) <= 0.0 or float(enemy.get("speed", 0.0)) <= 0.0:
			errors.append("敌人配置无效: %s" % enemy_id)
	var waves := get_waves_for_level(3, "aggressive")
	if waves.size() < 2:
		errors.append("波次不足")
	if get_waves_for_level(3, "safe").size() != 3 or get_waves_for_level(3, "aggressive").size() != 3:
		errors.append("劫匪关卡波次无效")
	return {"valid": errors.is_empty(), "errors": errors}
