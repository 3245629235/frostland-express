extends SceneTree
## Day 5 剧情与关卡规则测试入口。

const StoryProgressRef = preload("res://scripts/story_progress.gd")
const BattleDataRef = preload("res://scripts/battle_data.gd")
const BattleSystemRef = preload("res://scripts/systems/battle_system.gd")

var failures := 0
var test_path := "user://day5_progress_test.json"

func _init() -> void:
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var progress := StoryProgressRef.reset_progress(test_path)
	_check(progress.get("current_level", 0) == 1, "新剧情进度应从第 1 关开始")
	_check(progress.get("unlocked_level", 0) == 1, "新剧情只应解锁第 1 关")
	_check(StoryProgressRef.begin_level(2, test_path).get("current_level", 0) == 1, "未解锁关卡不能直接开始")
	progress = StoryProgressRef.complete_level(1, test_path)
	_check(progress.get("completed_level", 0) == 1, "完成第 1 关应记录进度")
	_check(progress.get("unlocked_level", 0) == 2, "完成第 1 关应解锁第 2 关")
	progress = StoryProgressRef.begin_level(2, test_path)
	_check(progress.get("current_level", 0) == 2, "第 2 关解锁后应可开始")
	progress = StoryProgressRef.set_branch("aggressive", test_path)
	_check(progress.get("branch", "") == "aggressive", "主动追击分支应保存")
	progress = StoryProgressRef.complete_level(2, test_path)
	_check(progress.get("unlocked_level", 0) == 3, "完成第 2 关应解锁第 3 关")
	progress = StoryProgressRef.record_attempt(3, test_path)
	_check(int(progress["attempts"]["3"]) == 1, "第 3 关失败/重试次数应记录")
	progress = StoryProgressRef.complete_level(3, test_path)
	_check(bool(progress.get("chapter_completed", false)), "完成第 3 关应标记第一章完成")
	_check(StoryProgressRef.validate_progress(progress).get("valid", false), "剧情进度结构应通过校验")

	var safe_waves := BattleDataRef.get_waves_for_level(3, "safe")
	var aggressive_waves := BattleDataRef.get_waves_for_level(3, "aggressive")
	_check(safe_waves.size() == 3, "保守分支应有 3 波")
	_check(aggressive_waves.size() == 3, "主动分支应有 3 波")
	_check(int(aggressive_waves[0]["count"]) > int(safe_waves[0]["count"]), "主动分支第一波敌人应更多")
	_check(str(safe_waves[2]["enemy"]) == "boss", "第三波应为匪首 Boss")

	var state: Dictionary = BattleSystemRef.create_battle_state()
	var chars := [{"name": "测试射手", "health": 100.0, "max_health": 100.0, "attack": 60.0}]
	var resources := {"ammo_small": 5}
	BattleSystemRef.spawn_enemy(state, "raider", 900.0)
	var shot: Dictionary = BattleSystemRef.fire_at(state, 0, chars, resources)
	_check(shot.get("ok", false), "剧情战斗首次射击应成功")
	_check(resources["ammo_small"] == 4, "剧情战斗射击应消耗弹药")
	BattleSystemRef.spawn_enemy(state, "shield_raider", 900.0)
	var blocked: Dictionary = BattleSystemRef.fire_at(state, 0, chars, resources)
	_check(not blocked.get("ok", false), "射速限制期间第二次射击应被阻止")
	BattleSystemRef.advance(state, 1.0, chars, {"health": 100.0})
	var second: Dictionary = BattleSystemRef.fire_at(state, 0, chars, resources)
	_check(second.get("ok", false), "射击冷却结束后应可再次射击")

	var boss_state: Dictionary = BattleSystemRef.create_battle_state()
	boss_state["elapsed"] = 35.0
	_check(not BattleSystemRef.is_boss_timeout(boss_state), "Boss 未出现前不应触发 Boss 限时")
	BattleSystemRef.spawn_enemy(boss_state, "boss", 900.0)
	_check(bool(boss_state.get("boss_started", false)), "Boss 出场后应开始 Boss 计时")
	var boss_chars := [{"name": "Boss 测试射手", "health": 1000.0, "max_health": 1000.0, "attack": 60.0}]
	BattleSystemRef.advance(boss_state, 29.9, boss_chars, {"health": 100.0})
	_check(not BattleSystemRef.is_boss_timeout(boss_state), "Boss 出场未满 30 秒不应失败")
	BattleSystemRef.advance(boss_state, 0.2, boss_chars, {"health": 100.0})
	_check(BattleSystemRef.is_boss_timeout(boss_state), "Boss 出场 30 秒后应触发限时失败")

	var kill_state: Dictionary = BattleSystemRef.create_battle_state()
	BattleSystemRef.spawn_enemy(kill_state, "boss", 900.0)
	var kill_chars := [{"name": "提前击杀射手", "health": 1000.0, "max_health": 1000.0, "attack": 60.0}]
	BattleSystemRef.advance(kill_state, 0.5, kill_chars, {"health": 100.0})
	var boss_shot: Dictionary = BattleSystemRef.fire_at(kill_state, 0, kill_chars, {"ammo_small": 10})
	_check(boss_shot.get("ok", false), "Boss 出场后应可正常射击")
	_check(not BattleSystemRef.is_boss_timeout(kill_state), "提前攻击 Boss 不应立即超时")

	var shield_state: Dictionary = BattleSystemRef.create_battle_state()
	BattleSystemRef.spawn_enemy(shield_state, "shield_raider", 900.0)
	var shield_resources := {"ammo_small": 100}
	var shield_chars := [{"name": "破盾射手", "health": 1000.0, "max_health": 1000.0, "attack": 60.0}]
	for shield_index in range(3):
		var shield_shot: Dictionary = BattleSystemRef.fire_at(shield_state, 0, shield_chars, shield_resources)
		_check(shield_shot.get("ok", false), "持盾劫匪第 %d 次破盾射击应成功" % (shield_index + 1))
		_check(int(shield_shot.get("shield_hits_left", -1)) == 2 - shield_index, "持盾劫匪护盾次数应递减")
		BattleSystemRef.advance(shield_state, 1.0, shield_chars, {"health": 1000.0})
	var shield_damage: Dictionary = BattleSystemRef.fire_at(shield_state, 0, shield_chars, shield_resources)
	_check(shield_damage.get("ok", false), "护盾击破后应进入正常伤害阶段")
	_check(float(shield_damage.get("damage", 0.0)) > 0.0, "护盾击破后射击应造成伤害")
	# Day 6：持盾劫匪 HP 1200，破盾后还需多发射击（攻击 60 → 20 发）
	var shield_guard := 0
	var shield_finish: Dictionary = {}
	while shield_guard < 40 and not bool(shield_finish.get("defeated", false)):
		shield_guard += 1
		BattleSystemRef.advance(shield_state, 1.0, shield_chars, {"health": 1000.0})
		shield_finish = BattleSystemRef.fire_at(shield_state, 0, shield_chars, shield_resources)
	_check(bool(shield_finish.get("defeated", false)), "护盾击破后持续射击应击倒持盾劫匪（%d 发）" % shield_guard)

	_check(_simulate_branch("safe"), "保守分支完整三波应可通关")
	_check(_simulate_branch("aggressive"), "主动分支完整三波应可通关")

	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures > 0:
		printerr("Day 5 规则测试失败：%d 项" % failures)
		quit(1)
	else:
		print("Day 5 规则测试通过")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[FAIL] " + message)

func _simulate_branch(branch: String) -> bool:
	var state: Dictionary = BattleSystemRef.create_battle_state()
	var characters := [{"name": "模拟小队", "health": 10000.0, "max_health": 10000.0, "attack": 300.0}]
	var resources := {"ammo_small": 1000}
	var total_defeated := 0
	var expected_defeated := 0
	for wave in BattleDataRef.get_waves_for_level(3, branch):
		expected_defeated += int(wave.get("count", 0))
		for spawn_index in range(int(wave.get("count", 0))):
			BattleSystemRef.spawn_enemy(state, str(wave.get("enemy", "raider")), 900.0)
			var guard := 0
			while not (state.get("enemies", []) as Array).is_empty() and guard < 200:
				var result: Dictionary = BattleSystemRef.fire_at(state, 0, characters, resources)
				if not result.get("ok", false):
					BattleSystemRef.advance(state, 1.0, characters, {"health": 10000.0})
					guard += 1
					continue
				BattleSystemRef.advance(state, 1.0, characters, {"health": 10000.0})
				guard += 1
			if guard >= 200:
				return false
			total_defeated += 1
	return total_defeated == expected_defeated and (state.get("enemies", []) as Array).is_empty() and str(state.get("status", "")) == "fighting"
