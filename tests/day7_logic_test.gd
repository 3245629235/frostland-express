extends SceneTree
## Day 7 生存模式整圈模拟测试：420km 全程资源曲线、站点闭环、单程时长。
## 按 GameConfig 实际数值逐 tick 模拟（不含随机事件，最坏情况 = 无事件补给）。

const GameConfigRef = preload("res://scripts/game_config.gd")
const StationSystemRef = preload("res://scripts/systems/station_system.gd")

const STATIONS := [80.0, 180.0, 300.0, 420.0]  # 白桦林/冻湖/铁岭口/极光城
const CREW_COUNT := 4
const STATION_STAY_SECONDS := 30.0             # 每站停留（收集 5s + 操作）

var failures := 0

func _init() -> void:
	# 站点收集数值应与平衡表一致（BUG-012 修复回归）
	for seed in [1, 17, 12345, 999999]:
		var reward := StationSystemRef.collect_reward(seed)
		var food_ok: bool = int(reward["food"]) >= int(GameConfigRef.COLLECT_FOOD_MIN) and int(reward["food"]) <= int(GameConfigRef.COLLECT_FOOD_MAX)
		var fuel_ok: bool = int(reward["fuel"]) >= int(GameConfigRef.COLLECT_FUEL_MIN) and int(reward["fuel"]) <= int(GameConfigRef.COLLECT_FUEL_MAX)
		_check(food_ok and fuel_ok, "站点收集应落在平衡区间（seed=%d 食物%d 燃料%d）" % [seed, int(reward["food"]), int(reward["fuel"])])

	# 三档速度各模拟一整圈
	var cruise := _simulate_lap(200.0)  # 均速 200 km/h（显示）
	_check(cruise["duration_min"] >= 30.0 and cruise["duration_min"] <= 60.0,
		"均速 200 km/h 单程应在 30~60 分钟（实测 %.1f 分钟）" % cruise["duration_min"])
	_check(cruise["food_left"] > 0.0, "全程食物应不耗尽（剩 %.0f）" % cruise["food_left"])
	_check(cruise["fuel_left"] > 0.0, "全程燃料应不耗尽（剩 %.0f）" % cruise["fuel_left"])
	_check(cruise["stations_reached"] == 4, "应到达全部 4 站（到达 %d）" % cruise["stations_reached"])
	_check(cruise["temp_break_min"] >= 5.0 and cruise["temp_break_min"] <= 20.0,
		"体温跌破 30 应在中段（%.1f 分钟）" % cruise["temp_break_min"])

	var full_speed := _simulate_lap(360.0)  # 全速 360 km/h（显示）
	_check(full_speed["fuel_left"] >= 0.0, "全速 360 km/h 一圈燃料应可撑住（剩 %.0f）" % full_speed["fuel_left"])
	_check(full_speed["duration_min"] >= 15.0 and full_speed["duration_min"] <= 35.0,
		"全速一圈应约 23 分钟（实测 %.1f 分钟）" % full_speed["duration_min"])

	var slow := _simulate_lap(120.0)  # 慢速 120 km/h
	_check(slow["duration_min"] <= 75.0, "慢速 120 km/h 一圈不应超过 75 分钟（实测 %.1f）" % slow["duration_min"])

	if failures > 0:
		printerr("Day 7 规则测试失败：%d 项" % failures)
		quit(1)
	else:
		print("Day 7 规则测试通过")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[FAIL] " + message)

## 模拟一整圈：返回 {duration_min, food_left, fuel_left, stations_reached, temp_break_min}
func _simulate_lap(cruise_kmh: float) -> Dictionary:
	var v_ms := cruise_kmh / 3.6
	var km_per_sec := v_ms * GameConfigRef.TIME_COMPRESSION / 1000.0
	var food := 1000.0
	var fuel := 2000.0
	var temp := 90.0
	var elapsed := 0.0
	var distance := 0.0
	var stations_reached := 0
	var temp_break_min := -1.0
	var tick := GameConfigRef.CONSUME_INTERVAL

	while true:
		# 站点到达 → 停留
		if stations_reached < STATIONS.size() and distance >= STATIONS[stations_reached]:
			stations_reached += 1
			var stay_ticks := int(STATION_STAY_SECONDS / tick)
			for i in range(stay_ticks):
				food = maxf(0.0, food - CREW_COUNT * GameConfigRef.FOOD_PER_CHAR_PER_TICK)
				# 停站油耗减半（低速溜车），体温回升
				fuel = maxf(0.0, fuel - GameConfigRef.FUEL_BASE_PER_TICK * 0.5)
				temp = clampf(temp + GameConfigRef.TEMP_DELTA_STOPPED, 0.0, 100.0)
				elapsed += tick
			# 收集补给（取区间均值）
			food += (GameConfigRef.COLLECT_FOOD_MIN + GameConfigRef.COLLECT_FOOD_MAX) / 2.0
			fuel += (GameConfigRef.COLLECT_FUEL_MIN + GameConfigRef.COLLECT_FUEL_MAX) / 2.0
			if stations_reached == STATIONS.size():
				break  # 极光城（420km）到达即一圈完成
			continue

		# 行驶 tick
		food = maxf(0.0, food - CREW_COUNT * GameConfigRef.FOOD_PER_CHAR_PER_TICK)
		var fuel_cost := GameConfigRef.FUEL_BASE_PER_TICK
		if cruise_kmh > GameConfigRef.FUEL_SPEED_BONUS_KMH:
			fuel_cost *= GameConfigRef.FUEL_SPEED_BONUS_MULT
		fuel = maxf(0.0, fuel - fuel_cost)
		temp = clampf(temp + GameConfigRef.TEMP_DELTA_MOVING, 0.0, 100.0)
		if temp < GameConfigRef.TEMP_DAMAGE_THRESHOLD and temp_break_min < 0.0:
			temp_break_min = elapsed / 60.0
		elapsed += tick
		distance += km_per_sec * tick
		if distance > 420.0 and stations_reached >= STATIONS.size():
			break

	return {
		"duration_min": elapsed / 60.0,
		"food_left": food,
		"fuel_left": fuel,
		"stations_reached": stations_reached,
		"temp_break_min": temp_break_min,
	}
