extends SceneTree
## Day 6 数值平衡规则测试：时间压缩倍率、生存资源曲线、战斗时长校准、事件/收集数值。
## 运行：Godot --headless -s tests/day6_logic_test.gd

const BattleDataRef = preload("res://scripts/battle_data.gd")
const BattleSystemRef = preload("res://scripts/systems/battle_system.gd")
const GameConfigRef = preload("res://scripts/game_config.gd")
const EventsDataRef = preload("res://scripts/events_data.gd")

var failures := 0

func _init() -> void:
	_test_balance_constants()
	_test_survival_pacing()
	_test_battle_pacing()
	_test_event_values()

	if failures > 0:
		printerr("Day 6 规则测试失败：%d 项" % failures)
		quit(1)
	else:
		print("Day 6 规则测试通过")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[FAIL] " + message)

# ===== 1. 平衡常量 =====
func _test_balance_constants() -> void:
	_check(is_equal_approx(GameConfigRef.TIME_COMPRESSION, 3.0), "时间压缩倍率应为 3.0（现实 1 秒 = 游戏 3 秒）")
	_check(is_equal_approx(GameConfigRef.FUEL_BASE_PER_TICK, 1.0), "基础油耗应为 1.0/tick（30 分钟约 900~1350）")
	_check(is_equal_approx(GameConfigRef.FOOD_PER_CHAR_PER_TICK, 0.2), "人均食物消耗应为 0.2/tick（30 分钟约 720）")
	_check(is_equal_approx(GameConfigRef.TEMP_DELTA_MOVING, -0.25), "行驶体温变化应为 -0.25/tick")
	_check(GameConfigRef.COLLECT_FOOD_MIN >= 30.0, "站收集食物下限应 ≥30（后段补给翻盘点）")
	_check(BattleSystemRef.FIRE_INTERVAL >= 1.0, "射速应 ≤1 发/秒（触屏节奏）")

# ===== 2. 生存节奏：单程 30~60 现实分钟 + 资源曲线 =====
func _test_survival_pacing() -> void:
	# 里程速率：距离 = 速度(m/s) × TIME_COMPRESSION × ΔT
	var full_speed_ms := 100.0   # 全速（360 km/h 显示）
	var cruise_ms := 55.56       # 均速 200 km/h
	var distance_m := 420000.0   # 一圈 420 km

	var full_minutes := distance_m / (full_speed_ms * GameConfigRef.TIME_COMPRESSION) / 60.0
	var cruise_minutes := distance_m / (cruise_ms * GameConfigRef.TIME_COMPRESSION) / 60.0
	_check(full_minutes >= 20.0 and full_minutes <= 30.0, "全速一圈应约 23 分钟（实测 %.1f 分钟）" % full_minutes)
	_check(cruise_minutes >= 30.0 and cruise_minutes <= 60.0, "均速一圈应在 30~60 分钟（实测 %.1f 分钟）" % cruise_minutes)

	# 资源曲线：30 分钟 = 900 tick，4 人
	var ticks := 900
	var food_start := 1000.0
	var food_cost_per_tick := 4.0 * GameConfigRef.FOOD_PER_CHAR_PER_TICK
	var food_left := food_start - food_cost_per_tick * ticks
	_check(food_left > 0.0, "30 分钟食物应不耗尽（剩 %.0f）" % food_left)
	_check(food_left < 400.0, "30 分钟食物应形成紧张感（剩 %.0f < 400）" % food_left)

	# 体温：行驶 30 分钟跌破 30 阈值的时间应在中段（>5 分钟，<20 分钟）
	var temp_start := 90.0
	var temp_drop_per_tick := absf(GameConfigRef.TEMP_DELTA_MOVING)
	var ticks_to_threshold := (temp_start - GameConfigRef.TEMP_DAMAGE_THRESHOLD) / temp_drop_per_tick
	var minutes_to_threshold := ticks_to_threshold * GameConfigRef.CONSUME_INTERVAL / 60.0
	_check(minutes_to_threshold >= 5.0 and minutes_to_threshold <= 20.0, "体温跌破 30 应在中段（%.1f 分钟）" % minutes_to_threshold)

	# 燃料：30 分钟高速行驶（>60km/h 显示 ×1.5）不耗尽（初始 2000）
	var fuel_cost_full := GameConfigRef.FUEL_BASE_PER_TICK * GameConfigRef.FUEL_SPEED_BONUS_MULT
	var fuel_left := 2000.0 - fuel_cost_full * ticks
	_check(fuel_left >= 0.0, "30 分钟高速油耗应可撑住（剩 %.0f）" % fuel_left)

# ===== 3. 战斗节奏：关卡 2 教学必过、关卡 3 有压力但可通关、Boss 限时真实 =====
func _test_battle_pacing() -> void:
	var crew_attack := 210.0  # 全员攻击合计（60+55+50+45 量级）

	# 击杀发数标定
	var wolf_shots := ceilf(BattleDataRef.get_enemy("snow_wolf")["hp"] / crew_attack)
	var raider_shots := ceilf(BattleDataRef.get_enemy("raider")["hp"] / crew_attack)
	var boss_shots := ceilf(BattleDataRef.get_enemy("boss")["hp"] / crew_attack)
	_check(wolf_shots == 3.0, "雪狼应 3 发击杀（当前 %.0f 发）" % wolf_shots)
	_check(raider_shots == 4.0, "劫匪应 4 发击杀（当前 %.0f 发）" % raider_shots)
	_check(boss_shots <= 30.0, "Boss 应在 30 秒限时内可击杀（%.0f 发 × 1s）" % boss_shots)

	# 关卡 2 教学：总时长（出怪 + 击杀）应在 20~70 秒
	var level2_duration := _simulate_battle(BattleDataRef.get_waves(), crew_attack)
	_check(level2_duration >= 20.0 and level2_duration <= 70.0, "关卡 2 教学战斗应约 30~40 秒（实测 %.1f 秒）" % level2_duration)

	# 关卡 3 双分支：通关时长应在 40~150 秒（配合剧情过渡 → 关卡总时长 3~5 分钟）
	var safe_duration := _simulate_battle(BattleDataRef.get_waves_for_level(3, "safe"), crew_attack)
	var aggressive_duration := _simulate_battle(BattleDataRef.get_waves_for_level(3, "aggressive"), crew_attack)
	_check(safe_duration >= 40.0 and safe_duration <= 150.0, "保守分支战斗应约 1 分钟（实测 %.1f 秒）" % safe_duration)
	_check(aggressive_duration >= 40.0 and aggressive_duration <= 150.0, "主动分支战斗应约 1 分钟（实测 %.1f 秒）" % aggressive_duration)
	_check(aggressive_duration > safe_duration, "主动分支应比保守分支更难（%.1f > %.1f）" % [aggressive_duration, safe_duration])

	# Boss 限时仍生效
	var boss_state: Dictionary = BattleSystemRef.create_battle_state()
	BattleSystemRef.spawn_enemy(boss_state, "boss", 900.0)
	BattleSystemRef.advance(boss_state, 30.0, [{"health": 1000.0, "attack": 60.0}], {"health": 100.0})
	_check(BattleSystemRef.is_boss_timeout(boss_state), "Boss 出场 30 秒后仍应触发限时失败")

	# 弹药消耗：关卡 3 主动分支 ≈ 53 发，初始 100 应可支撑（含近战兜底）
	var shots_needed := _count_shots(BattleDataRef.get_waves_for_level(3, "aggressive"), crew_attack)
	_check(shots_needed <= 100, "主动分支弹药消耗应在初始 100 以内（约 %d 发）" % shots_needed)

# ===== 4. 事件/收集数值 =====
func _test_event_values() -> void:
	var e5 := EventsDataRef.get_event("E5")
	var e8 := EventsDataRef.get_event("E8")
	var e5_collect: Dictionary = e5["choices"][0]
	_check(int(e5_collect["effects"][0]["min"]) >= 30, "E5 雪地物资收集下限应 ≥30")
	var e8_fuel: Dictionary = e8["choices"][0]
	_check(int(e8_fuel["costs"]["fuel"]) == 20, "E8 燃料换药品应调整为 20 燃料")
	var e8_food: Dictionary = e8["choices"][1]
	_check(int(e8_food["costs"]["food"]) == 15, "E8 食物换弹药应调整为 15 食物")

# ===== 模拟：整场战斗（含出怪节奏），返回通关秒数 =====
func _simulate_battle(waves: Array, crew_attack: float) -> float:
	var state: Dictionary = BattleSystemRef.create_battle_state()
	var characters := [{"name": "平衡测试小队", "health": 100000.0, "max_health": 100000.0, "attack": crew_attack}]
	var resources := {"ammo_small": 500}
	var elapsed := 0.0
	var guard := 0
	for wave in waves:
		var spawned := 0
		var wave_done := false
		while not wave_done and guard < 50000:
			guard += 1
			# 出怪
			if spawned < int(wave.get("count", 0)):
				if state.get("spawn_timer", 0.0) <= 0.0:
					BattleSystemRef.spawn_enemy(state, str(wave.get("enemy", "raider")), 900.0)
					spawned += 1
					state["spawn_timer"] = float(wave.get("interval", 1.0))
			# 射击（1 发/秒节奏）
			var shot: Dictionary = BattleSystemRef.fire_at(state, 0, characters, resources)
			if not shot.get("ok", false):
				# 冷却中 → 等 0.5s；无敌人且未出完 → 等出怪
				BattleSystemRef.advance(state, 0.5, characters, {"health": 100000.0})
				state["spawn_timer"] = maxf(0.0, float(state.get("spawn_timer", 0.0)) - 0.5)
				elapsed += 0.5
				continue
			BattleSystemRef.advance(state, 0.5, characters, {"health": 100000.0})
			state["spawn_timer"] = maxf(0.0, float(state.get("spawn_timer", 0.0)) - 0.5)
			elapsed += 0.5
			# 波内敌人清空且已出完 → 下一波
			var enemies: Array = state.get("enemies", [])
			if enemies.is_empty() and spawned >= int(wave.get("count", 0)):
				wave_done = true
		if guard >= 50000:
			return 9999.0
	# 波间喘息
	elapsed += 4.0 * (waves.size() - 1)
	if str(state.get("status", "")) != "fighting":
		return 9999.0
	return elapsed

# ===== 统计需要的弹药发数（破盾只耗弹不扣血）=====
func _count_shots(waves: Array, crew_attack: float) -> int:
	var total := 0
	for wave in waves:
		for i in range(int(wave.get("count", 0))):
			var enemy_id := str(wave.get("enemy", "raider"))
			var hp := float(BattleDataRef.get_enemy(enemy_id)["hp"])
			var shots := int(ceil(hp / crew_attack))
			if enemy_id == "shield_raider":
				shots += 3  # 破盾 3 发
			total += shots
	return total
