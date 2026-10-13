extends RefCounted
class_name BattleSystem
## Day 4 战斗规则：不依赖场景节点，可由 headless 测试和战斗场景共用。

const BattleDataRef = preload("res://scripts/battle_data.gd")

const FIRE_INTERVAL := 1.0
const BOSS_TIME_LIMIT := 30.0
const MELEE_MULTIPLIER := 0.3
const BREAKTHROUGH_X := 120.0
const CREW_DAMAGE_RATIO := 0.5

static func create_battle_state() -> Dictionary:
	return {
		"wave_index": 0,
		"spawned_in_wave": 0,
		"spawn_timer": 0.0,
		"break_timer": 0.0,
		"fire_timer": 0.0,
		"elapsed": 0.0,
		"boss_started": false,
		"boss_elapsed": 0.0,
		"enemies": [],
		"shots": 0,
		"hits": 0,
		"defeated": 0,
		"status": "fighting",
	}

static func spawn_enemy(state: Dictionary, enemy_id: String, start_x: float = 1160.0) -> Dictionary:
	var cfg := BattleDataRef.get_enemy(enemy_id)
	if cfg.is_empty():
		return {}
	var enemy := {
		"id": "%s_%d" % [enemy_id, int(state.get("spawned_in_wave", 0)) + int(state.get("defeated", 0))],
		"type": enemy_id,
		"name": cfg["name"],
		"hp": float(cfg["hp"]),
		"max_hp": float(cfg["hp"]),
		"x": start_x,
		"speed": float(cfg["speed"]),
		"damage": float(cfg["damage"]),
		"shield_hits": 3 if enemy_id == "shield_raider" else 0,
	}
	var enemies: Array = state.get("enemies", [])
	enemies.append(enemy)
	state["enemies"] = enemies
	if enemy_id == "boss":
		state["boss_started"] = true
		state["boss_elapsed"] = 0.0
	return enemy

static func fire_at(state: Dictionary, target_index: int, characters: Array, resources: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "fighting":
		return {"ok": false, "message": "战斗已经结束"}
	var enemies: Array = state.get("enemies", [])
	if target_index < 0 or target_index >= enemies.size():
		return {"ok": false, "message": "没有命中目标"}
	var target: Dictionary = enemies[target_index]
	var attack_power := _total_attack(characters)
	if attack_power <= 0.0:
		return {"ok": false, "message": "没有可行动角色"}
	if float(state.get("fire_timer", 0.0)) > 0.0:
		return {"ok": false, "message": "射击准备中"}
	var ammo_type := "ammo_small"
	var ammo_available := int(resources.get(ammo_type, 0))
	var damage := attack_power
	if ammo_available > 0:
		resources[ammo_type] = ammo_available - 1
	else:
		damage *= MELEE_MULTIPLIER
	state["fire_timer"] = FIRE_INTERVAL
	state["shots"] = int(state.get("shots", 0)) + 1
	var shield_hits := int(target.get("shield_hits", 0))
	var shield_broken := false
	if shield_hits > 0:
		target["shield_hits"] = shield_hits - 1
		damage = 0.0
		shield_broken = int(target["shield_hits"]) == 0
	else:
		target["hp"] = maxf(0.0, float(target.get("hp", 0.0)) - damage)
	state["hits"] = int(state.get("hits", 0)) + 1
	if float(target.get("hp", 0.0)) <= 0.0:
		enemies.remove_at(target_index)
		state["defeated"] = int(state.get("defeated", 0)) + 1
	else:
		enemies[target_index] = target
	state["enemies"] = enemies
	return {"ok": true, "damage": damage, "defeated": float(target.get("hp", 0.0)) <= 0.0, "shield_broken": shield_broken, "shield_hits_left": int(target.get("shield_hits", 0)), "ammo_type": ammo_type, "attacker": "全员集火"}

static func advance(state: Dictionary, delta: float, characters: Array, train: Dictionary) -> Dictionary:
	if str(state.get("status", "")) != "fighting":
		return {"status": state.get("status", "")}
	var enemies: Array = state.get("enemies", [])
	state["elapsed"] = float(state.get("elapsed", 0.0)) + delta
	state["fire_timer"] = maxf(0.0, float(state.get("fire_timer", 0.0)) - delta)
	if bool(state.get("boss_started", false)):
		state["boss_elapsed"] = float(state.get("boss_elapsed", 0.0)) + delta
	var crew_damage := 0.0
	var train_damage := 0.0
	for enemy in enemies:
		enemy["x"] = float(enemy.get("x", 0.0)) - float(enemy.get("speed", 0.0)) * delta
		if float(enemy["x"]) <= BREAKTHROUGH_X:
			crew_damage += float(enemy.get("damage", 0.0)) * CREW_DAMAGE_RATIO
		if float(enemy["x"]) <= 0.0:
			train_damage += float(enemy.get("damage", 0.0))
			enemy["x"] = 10000.0
	for character in characters:
		if crew_damage > 0.0 and float(character.get("health", 0.0)) > 0.0:
			character["health"] = clampf(float(character.get("health", 0.0)) - crew_damage * delta, 0.0, float(character.get("max_health", 100.0)))
	if train_damage > 0.0:
		train["health"] = maxf(0.0, float(train.get("health", 100.0)) - train_damage)
	var remaining: Array = []
	for enemy in enemies:
		if float(enemy.get("x", 0.0)) < 9000.0:
			remaining.append(enemy)
	state["enemies"] = remaining
	if remaining.size() > 0 and _all_down(characters):
		state["status"] = "defeat"
		return {"status": "defeat", "reason": "crew_down"}
	if remaining.size() > 0 and float(train.get("health", 100.0)) <= 0.0:
		state["status"] = "defeat"
		return {"status": "defeat", "reason": "train_destroyed"}
	if is_boss_timeout(state) and remaining.size() > 0:
		state["status"] = "defeat"
		return {"status": "defeat", "reason": "boss_timeout"}
	return {"status": "fighting", "crew_damage": crew_damage, "train_damage": train_damage}

static func is_boss_timeout(state: Dictionary) -> bool:
	return bool(state.get("boss_started", false)) and float(state.get("boss_elapsed", 0.0)) >= BOSS_TIME_LIMIT

static func _total_attack(characters: Array) -> float:
	var total := 0.0
	for character in characters:
		if float(character.get("health", 0.0)) > 0.0:
			total += float(character.get("attack", 0.0))
	return total

static func _all_down(characters: Array) -> bool:
	if characters.is_empty():
		return false
	for character in characters:
		if float(character.get("health", 0.0)) > 0.0:
			return false
	return true
