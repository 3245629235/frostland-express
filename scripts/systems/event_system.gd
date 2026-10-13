extends RefCounted
class_name EventSystem
## 事件规则：不依赖场景节点，可由 headless 测试和 Travel 共用。

const RESOURCE_NAMES := {
	"food": "食物",
	"fuel": "燃料",
	"medicine": "药品",
	"parts": "零件",
	"ammo_small": "小口径弹药",
	"ammo_large": "大口径弹药",
}

static func pick_event_by_roll(roll: float) -> Dictionary:
	var clamped_roll := clampf(roll, 0.0, 0.999999)
	var cursor := 0.0
	for event_data in EventsData.get_all():
		cursor += float(event_data.get("weight", 0)) / 100.0
		if clamped_roll < cursor:
			return event_data
	return EventsData.get_event("E8")


static func apply_choice(state: Dictionary, event_id: String, choice_id: String, random_seed: int = 0) -> Dictionary:
	var event_data := EventsData.get_event(event_id)
	if event_data.is_empty():
		return {"ok": false, "message": "未知事件: %s" % event_id}
	var choice: Dictionary = {}
	for candidate in event_data.get("choices", []):
		if str(candidate.get("id", "")) == choice_id:
			choice = candidate
			break
	if choice.is_empty():
		return {"ok": false, "message": "未知事件选项: %s/%s" % [event_id, choice_id]}

	var resources: Dictionary = state.get("resources", {})
	for resource in choice.get("costs", {}).keys():
		var cost := int(choice["costs"][resource])
		if int(resources.get(resource, 0)) < cost:
			return {"ok": false, "message": "%s 不足（需要 %d）" % [RESOURCE_NAMES.get(resource, resource), cost]}

	for resource in choice.get("costs", {}).keys():
		resources[resource] = max(0, int(resources.get(resource, 0)) - int(choice["costs"][resource]))
	state["resources"] = resources
	if random_seed == 0:
		random_seed = int(Time.get_ticks_msec())
	for effect in choice.get("effects", []):
		_apply_effect(state, effect, random_seed)
		random_seed += 17
	var history: Array = state.get("event_history", [])
	history.append({"event_id": event_id, "choice_id": choice_id, "result": choice.get("result", "")})
	state["event_history"] = history
	return {"ok": true, "message": str(choice.get("result", "")), "event_id": event_id, "choice_id": choice_id}


static func _apply_effect(state: Dictionary, effect: Dictionary, random_seed: int) -> void:
	var effect_type := str(effect.get("type", ""))
	match effect_type:
		"resource":
			_change_resource(state, str(effect.get("resource", "")), int(effect.get("amount", 0)))
		"resource_range":
			var amount := _deterministic_range(int(effect.get("min", 0)), int(effect.get("max", 0)), random_seed)
			_change_resource(state, str(effect.get("resource", "")), amount)
		"morale":
			state["morale"] = clampf(float(state.get("morale", 50.0)) + float(effect.get("amount", 0.0)), 0.0, 100.0)
		"train_health":
			var train_health := float(state.get("train_health", 100.0)) + float(effect.get("amount", 0.0))
			state["train_health"] = clampf(train_health, 0.0, float(state.get("train_max_health", 999999.0)))
		"all_temperature":
			for character in state.get("characters", []):
				character["temperature"] = clampf(float(character.get("temperature", 90.0)) + float(effect.get("amount", 0.0)), 0.0, 100.0)
		"temporary_member":
			state["temporary_member_count"] = max(0, int(state.get("temporary_member_count", 0)) + int(effect.get("amount", 0)))
		"time_delay":
			state["event_time_delay"] = float(state.get("event_time_delay", 0.0)) + float(effect.get("seconds", 0.0))
		"effect":
			var active: Dictionary = state.get("active_effects", {})
			active[str(effect.get("id", ""))] = {
				"multiplier": float(effect.get("multiplier", 1.0)),
				"remaining": maxf(0.0, float(effect.get("duration", 0.0))),
			}
			state["active_effects"] = active


static func _change_resource(state: Dictionary, resource: String, amount: int) -> void:
	if resource.is_empty():
		return
	var resources: Dictionary = state.get("resources", {})
	resources[resource] = max(0, int(resources.get(resource, 0)) + amount)
	state["resources"] = resources


static func _deterministic_range(minimum: int, maximum: int, seed: int) -> int:
	if maximum <= minimum:
		return minimum
	return minimum + absi(seed) % (maximum - minimum + 1)


static func tick_effects(active_effects: Dictionary, delta: float) -> Dictionary:
	var remaining := {}
	for effect_id in active_effects.keys():
		var effect: Dictionary = active_effects[effect_id]
		var time_left := float(effect.get("remaining", 0.0)) - delta
		if time_left > 0.0:
			var copy := effect.duplicate(true)
			copy["remaining"] = time_left
			remaining[effect_id] = copy
	return remaining


static func get_effect_multiplier(active_effects: Dictionary, effect_id: String) -> float:
	var effect: Dictionary = active_effects.get(effect_id, {})
	return float(effect.get("multiplier", 1.0)) if not effect.is_empty() else 1.0