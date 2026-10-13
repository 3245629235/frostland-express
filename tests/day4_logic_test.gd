extends SceneTree
## Day 4 规则测试入口。

const BattleDataRef = preload("res://scripts/battle_data.gd")
const BattleSystemRef = preload("res://scripts/systems/battle_system.gd")

var failures := 0

func _init() -> void:
	_check(BattleDataRef.validate().get("valid", false), "战斗目录配置应通过校验")
	var state: Dictionary = BattleSystemRef.create_battle_state()
	var chars := [{"name": "测试射手", "health": 100.0, "max_health": 100.0, "attack": 60.0}]
	var resources := {"ammo_small": 10}
	BattleSystemRef.spawn_enemy(state, "snow_wolf", 500.0)
	var shot: Dictionary = BattleSystemRef.fire_at(state, 0, chars, resources)
	_check(shot.get("ok", false), "点击敌人应成功射击")
	_check(resources["ammo_small"] == 9, "每次射击应消耗 1 发小口径弹药")
	# Day 6：雪狼 HP 600，60 攻击需 10 发（1 发/秒）；弹药耗尽后近战 18/发仍应可击倒
	_check((state["enemies"] as Array).size() == 1, "60 攻击力一枪不应击倒 600 HP 雪狼（Day 6 平衡）")
	var wolf_guard := 0
	while not (state["enemies"] as Array).is_empty() and wolf_guard < 60:
		wolf_guard += 1
		BattleSystemRef.advance(state, 1.0, chars, {"health": 100.0})
		BattleSystemRef.fire_at(state, 0, chars, resources)
	_check((state["enemies"] as Array).is_empty(), "持续射击应最终击倒雪狼（%d 发）" % wolf_guard)
	_check(int(state["defeated"]) == 1, "击倒数应递增")
	BattleSystemRef.spawn_enemy(state, "snow_wolf", 100.0)
	var advance: Dictionary = BattleSystemRef.advance(state, 1.0, chars, {"health": 100.0})
	_check(advance.get("status", "") == "fighting", "角色存活时战斗不应失败")
	_check(chars[0]["health"] < 100.0, "敌人推进到角色区域应造成伤害")
	if failures > 0:
		printerr("Day 4 规则测试失败：%d 项" % failures)
		quit(1)
	else:
		print("Day 4 规则测试通过")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[FAIL] " + message)
