extends SceneTree
## Day 3 规则测试入口：按切片逐步扩展。

var failures: int = 0

func _init() -> void:
	_test_event_catalog_contract()
	if failures > 0:
		printerr("Day 3 规则测试失败：%d 项" % failures)
		quit(1)
	else:
		print("Day 3 规则测试通过")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[FAIL] " + message)

func _test_event_catalog_contract() -> void:
	var events: Array = EventsData.get_all()
	_check(events.size() == 8, "事件目录应包含 8 个事件")
	_check(EventsData.total_weight() == 100, "事件权重总和应为 100")
	_check(EventsData.validate_catalog().get("valid", false), "事件目录结构应通过校验")
	_check(EventSystem.pick_event_by_roll(0.0).get("id", "") == "E1", "滚动值 0 应命中 E1")
	_check(EventSystem.pick_event_by_roll(0.99).get("id", "") == "E8", "滚动值 0.99 应命中 E8")

	var state := {
		"resources": {"food": 100, "fuel": 100, "medicine": 10, "parts": 20, "ammo_small": 10, "ammo_large": 5},
		"morale": 50.0,
		"train_health": 100.0,
		"characters": [{"temperature": 90.0, "health": 100.0}],
		"active_effects": {},
		"temporary_member_count": 0,
		"event_history": [],
	}
	var result: Dictionary = EventSystem.apply_choice(state, "E3", "repair")
	_check(result.get("ok", false), "E3 repair 选项应可执行")
	_check(state["resources"]["parts"] == 10, "E3 repair 应消耗 10 零件")
	_check(float(state["train_health"]) > 100.0, "E3 repair 应返回维修结果")

	var effect_state := {"active_effects": {"fuel_multiplier": {"multiplier": 1.5, "remaining": 2.0}}}
	var effect_result := EventSystem.apply_choice(effect_state, "E1", "slow", 42)
	_check(effect_result.get("ok", false), "E1 slow 选项应可执行")
	_check(is_equal_approx(EventSystem.get_effect_multiplier(effect_state["active_effects"], "fuel_multiplier"), 1.5), "燃料倍率应生效")
	_check(EventSystem.tick_effects(effect_state["active_effects"], 10.1).is_empty(), "临时效果到期后应移除")

	var stations: Array = StationData.get_all()
	_check(stations.size() == 4, "站点目录应包含 4 个站点")
	_check(StationSystem.should_arrive(79.9, 0) == false, "未到 80 km 时不应到达白桦林站")
	_check(StationSystem.should_arrive(80.0, 0), "到达 80 km 时应触发白桦林站")
	_check(StationSystem.get_station(2).get("repair_cost", 0) == 5, "铁岭口维修费用应为 5 零件")
	var middle_stop := StationSystem.continue_from_station(0, 0)
	_check(middle_stop.get("next_station_index", -1) == 1, "白桦林站后应前往冻湖站")
	_check(is_equal_approx(float(middle_stop.get("route_distance_km", -1.0)), 80.0), "中间站离站后应保留当前路线里程")
	var loop := StationSystem.continue_from_station(3, 0)
	_check(loop.get("next_station_index", -1) == 0, "极光城后应回到白桦林站")
	_check(loop.get("route_lap", -1) == 1, "极光城后圈数应增加")
	_check(is_equal_approx(float(loop.get("route_distance_km", -1.0)), 0.0), "极光城后路线里程应归零")

	var breakdown_state := {"breakdown_count": 3, "train_health": 100.0, "characters": [{"health": 100.0}]}
	_check(SettlementSystem.get_survival_failure_reason(breakdown_state) == "breakdown_limit", "抛锚 3 次应失败")
	var train_failure := {"breakdown_count": 0, "train_health": 0.0, "characters": [{"health": 100.0}]}
	_check(SettlementSystem.get_survival_failure_reason(train_failure) == "train_destroyed", "列车 HP 为 0 应失败")
	var crew_failure := {"breakdown_count": 0, "train_health": 100.0, "characters": [{"health": 0.0}, {"health": 0.0}]}
	_check(SettlementSystem.get_survival_failure_reason(crew_failure) == "crew_down", "全员倒下应失败")
	var summary := SettlementSystem.build_result("breakdown_limit", {"breakdown_count": 3, "total_distance_km": 123.4, "travel_time": 45.0, "train_health": 80.0, "characters": [{"health": 100.0}, {"health": 0.0}]})
	_check(summary.get("survivors", -1) == 1, "结算应统计幸存者数量")
