extends RefCounted
class_name SettlementSystem
## 生存/剧情结算规则：只计算结果，不切换场景。

const FAILURE_LABELS := {
	"train_destroyed": "列车损毁",
	"crew_down": "全员倒下",
	"breakdown_limit": "抛锚次数达到上限",
	"battle_failed": "战斗失败",
}

static func get_survival_failure_reason(state: Dictionary) -> String:
	if float(state.get("train_health", 100.0)) <= 0.0:
		return "train_destroyed"
	var characters: Array = state.get("characters", [])
	if not characters.is_empty() and _survivor_count(characters) == 0:
		return "crew_down"
	if int(state.get("breakdown_count", 0)) >= 3:
		return "breakdown_limit"
	return ""

static func _survivor_count(characters: Array) -> int:
	var count := 0
	for character in characters:
		if float(character.get("health", 0.0)) > 0.0:
			count += 1
	return count

static func build_result(reason: String, state: Dictionary) -> Dictionary:
	var characters: Array = state.get("characters", [])
	return {
		"mode": str(state.get("game_mode", "survival")),
		"result": "defeat" if not reason.is_empty() else "victory",
		"reason": reason,
		"reason_label": FAILURE_LABELS.get(reason, "完成"),
		"survivors": _survivor_count(characters),
		"crew_count": characters.size(),
		"breakdown_count": int(state.get("breakdown_count", 0)),
		"total_distance_km": float(state.get("total_distance_km", 0.0)),
		"travel_time": float(state.get("travel_time", 0.0)),
		"train_health": float(state.get("train_health", 0.0)),
		"resources": (state.get("resources", {}) as Dictionary).duplicate(true),
	}