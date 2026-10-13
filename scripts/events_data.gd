extends RefCounted
class_name EventsData
## Day 3 生存事件目录：事件规则只读，执行交给 EventSystem。

const EVENTS: Array = [
	{
		"id": "E1",
		"title": "暴风雪",
		"description": "暴风雪横扫铁路，能见度正在迅速下降。",
		"weight": 20,
		"choices": [
			{"id": "slow", "text": "减速行驶", "effects": [
				{"type": "effect", "id": "speed_multiplier", "multiplier": 0.65, "duration": 10.0},
				{"type": "effect", "id": "fuel_multiplier", "multiplier": 1.5, "duration": 10.0},
			], "result": "减速穿过暴风雪，油耗暂时增加。"},
			{"id": "stop", "text": "停车避让", "effects": [
				{"type": "time_delay", "seconds": 15.0},
			], "result": "停车避让，额外耗时 15 秒。"},
		],
	},
	{
		"id": "E2",
		"title": "可疑动静",
		"description": "雪幕后传来不明脚步声，车厢外似乎有东西跟随。",
		"weight": 18,
		"choices": [
			{"id": "alert", "text": "保持警惕", "effects": [
				{"type": "effect", "id": "enemy_threat_multiplier", "multiplier": 1.5, "duration": 60.0},
			], "result": "全员提高警戒，未来一段时间更容易遭遇袭击。"},
			{"id": "ignore", "text": "无视动静", "effects": [], "result": "你决定继续赶路。"},
		],
	},
	{
		"id": "E3",
		"title": "机械故障",
		"description": "锅炉附近传来刺耳的金属摩擦声，列车状态正在恶化。",
		"weight": 14,
		"choices": [
			{"id": "repair", "text": "用零件维修", "costs": {"parts": 10}, "effects": [
				{"type": "train_health", "amount": 12.0},
			], "result": "消耗零件完成临时维修，列车 HP +12。"},
			{"id": "endure", "text": "硬撑过去", "effects": [
				{"type": "train_health", "amount": -12.0},
			], "result": "故障继续扩大，列车 HP -12。"},
		],
	},
	{
		"id": "E4",
		"title": "幸存者求救",
		"description": "雪地里有人挥动信号灯，向列车发出求救。",
		"weight": 12,
		"choices": [
			{"id": "shelter", "text": "收留幸存者", "effects": [
				{"type": "temporary_member", "amount": 1},
				{"type": "morale", "amount": 10.0},
			], "result": "幸存者加入队伍，士气提高，但食物消耗增加。"},
			{"id": "reject", "text": "拒绝请求", "effects": [
				{"type": "morale", "amount": -8.0},
			], "result": "列车没有停下，队伍士气下降。"},
		],
	},
	{
		"id": "E5",
		"title": "雪地物资",
		"description": "前方雪坡露出补给箱的边角，停车或许能收集到物资。",
		"weight": 12,
		"choices": [
			{"id": "collect", "text": "停车收集", "effects": [
				{"type": "resource_range", "resource": "food", "min": 30, "max": 60},
				{"type": "time_delay", "seconds": 8.0},
			], "result": "收集到一批食物，额外耗时 8 秒。"},
			{"id": "ignore", "text": "无视物资", "effects": [], "result": "列车没有偏离路线。"},
		],
	},
	{
		"id": "E6",
		"title": "寒流",
		"description": "异常寒流穿透车厢，队员的体温正在快速下降。",
		"weight": 10,
		"choices": [
			{"id": "medicine", "text": "全员用药", "costs": {"medicine": 3}, "effects": [
				{"type": "all_temperature", "amount": 5.0},
			], "result": "消耗 3 份药品稳定体温。"},
			{"id": "endure", "text": "硬扛寒流", "effects": [
				{"type": "all_temperature", "amount": -10.0},
			], "result": "队员体温下降 10 点。"},
		],
	},
	{
		"id": "E7",
		"title": "蒸汽泄漏",
		"description": "蒸汽从车厢连接处喷出，继续高速行驶会加重损坏。",
		"weight": 8,
		"choices": [
			{"id": "repair", "text": "立即维修", "costs": {"parts": 5}, "effects": [
				{"type": "effect", "id": "speed_multiplier", "multiplier": 0.8, "duration": 5.0},
			], "result": "消耗 5 个零件处理泄漏，速度暂时受限。"},
			{"id": "ignore", "text": "继续行驶", "effects": [
				{"type": "effect", "id": "fuel_multiplier", "multiplier": 1.3, "duration": 10.0},
			], "result": "忽略泄漏，短时间内油耗增加。"},
		],
	},
	{
		"id": "E8",
		"title": "神秘商人",
		"description": "一名商人驾驶雪橇靠近列车，提出了几笔交换。",
		"weight": 6,
		"choices": [
			{"id": "fuel_medicine", "text": "20 燃料换 15 药品", "costs": {"fuel": 20}, "effects": [
				{"type": "resource", "resource": "medicine", "amount": 15},
			], "result": "交易完成：燃料 -20，药品 +15。"},
			{"id": "food_ammo", "text": "15 食物换 30 弹药", "costs": {"food": 15}, "effects": [
				{"type": "resource", "resource": "ammo_small", "amount": 30},
			], "result": "交易完成：食物 -15，小口径弹药 +30。"},
			{"id": "decline", "text": "不交易", "effects": [], "result": "你谢绝了交易。"},
		],
	},
]


static func get_all() -> Array:
	return EVENTS.duplicate(true)


static func get_event(event_id: String) -> Dictionary:
	for event_data in EVENTS:
		if str(event_data.get("id", "")) == event_id:
			return event_data.duplicate(true)
	return {}


static func total_weight() -> int:
	var total := 0
	for event_data in EVENTS:
		total += int(event_data.get("weight", 0))
	return total


static func validate_catalog() -> Dictionary:
	var ids: Dictionary = {}
	var errors: Array = []
	for event_data in EVENTS:
		var event_id := str(event_data.get("id", ""))
		if event_id.is_empty() or ids.has(event_id):
			errors.append("事件 ID 缺失或重复: %s" % event_id)
		ids[event_id] = true
		if int(event_data.get("weight", 0)) <= 0:
			errors.append("事件权重无效: %s" % event_id)
		if not (event_data.get("choices", []) is Array) or event_data["choices"].is_empty():
			errors.append("事件没有选项: %s" % event_id)
	return {"valid": errors.is_empty() and total_weight() == 100 and ids.size() == 8, "errors": errors}