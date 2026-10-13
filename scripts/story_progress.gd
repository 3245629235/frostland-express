extends RefCounted
class_name StoryProgress
## 第一章剧情进度：独立于生存存档，写入 user://story_progress.json。

const SAVE_VERSION := 1
const SAVE_PATH := "user://story_progress.json"
const CharacterDataRef = preload("res://scripts/character_data.gd")

static func default_progress() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"chapter": 1,
		"current_level": 1,
		"unlocked_level": 1,
		"completed_level": 0,
		"branch": "",
		"attempts": {"1": 0, "2": 0, "3": 0},
		"chapter_completed": false,
	}

static func load_progress(path: String = SAVE_PATH) -> Dictionary:
	var progress := default_progress()
	if not FileAccess.file_exists(path):
		return progress
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return progress
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		progress.merge(data, true)
	progress["version"] = SAVE_VERSION
	progress["current_level"] = clampi(int(progress.get("current_level", 1)), 1, 3)
	progress["unlocked_level"] = clampi(int(progress.get("unlocked_level", 1)), 1, 3)
	progress["completed_level"] = clampi(int(progress.get("completed_level", 0)), 0, 3)
	if not (progress.get("attempts", {}) is Dictionary):
		progress["attempts"] = {"1": 0, "2": 0, "3": 0}
	return progress

static func save_progress(progress: Dictionary, path: String = SAVE_PATH) -> void:
	var normalized := default_progress()
	normalized.merge(progress, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(normalized))
		file.close()

static func reset_progress(path: String = SAVE_PATH) -> Dictionary:
	var progress := default_progress()
	save_progress(progress, path)
	return progress

static func begin_level(level: int, path: String = SAVE_PATH) -> Dictionary:
	var progress := load_progress(path)
	var target := clampi(level, 1, 3)
	if target > int(progress.get("unlocked_level", 1)):
		return progress
	progress["current_level"] = target
	save_progress(progress, path)
	return progress

static func complete_level(level: int, path: String = SAVE_PATH) -> Dictionary:
	var progress := load_progress(path)
	var completed := clampi(level, 1, 3)
	progress["completed_level"] = maxi(int(progress.get("completed_level", 0)), completed)
	progress["unlocked_level"] = mini(3, maxi(int(progress.get("unlocked_level", 1)), completed + 1))
	progress["current_level"] = mini(3, completed + 1)
	if completed >= 3:
		progress["chapter_completed"] = true
	save_progress(progress, path)
	return progress

static func set_branch(branch: String, path: String = SAVE_PATH) -> Dictionary:
	var progress := load_progress(path)
	if branch == "safe" or branch == "aggressive":
		progress["branch"] = branch
		save_progress(progress, path)
	return progress

static func record_attempt(level: int, path: String = SAVE_PATH) -> Dictionary:
	var progress := load_progress(path)
	var attempts: Dictionary = progress.get("attempts", {})
	var key := str(clampi(level, 1, 3))
	attempts[key] = int(attempts.get(key, 0)) + 1
	progress["attempts"] = attempts
	progress["current_level"] = clampi(level, 1, 3)
	save_progress(progress, path)
	return progress

static func validate_progress(progress: Dictionary) -> Dictionary:
	var errors: Array = []
	if int(progress.get("version", 0)) != SAVE_VERSION:
		errors.append("进度版本无效")
	if int(progress.get("unlocked_level", 0)) < int(progress.get("completed_level", 0)):
		errors.append("解锁关卡不能低于已完成关卡")
	if str(progress.get("branch", "")) not in ["", "safe", "aggressive"]:
		errors.append("剧情分支无效")
	return {"valid": errors.is_empty(), "errors": errors}

static func prepare_story_state() -> void:
	var game_state = _get_game_state()
	if game_state == null:
		return
	game_state.game_mode = "story"
	game_state.stop_travel()
	game_state.settlement_active = false
	game_state.settlement_result = {}
	game_state.train["health"] = float(game_state.train.get("max_health", 100.0))
	if game_state.characters == null or game_state.characters.is_empty():
		game_state.characters = []
		for character in CharacterDataRef.get_default_team():
			game_state.characters.append(character.duplicate(true))
	for character in game_state.characters:
		character["health"] = float(character.get("max_health", 100.0))
	if game_state.get_resource("ammo_small") < 100:
		game_state.resources["ammo_small"] = 100
	if game_state.get_resource("food") < 100:
		game_state.resources["food"] = 100
	if game_state.get_resource("fuel") < 100:
		game_state.resources["fuel"] = 100

static func ensure_story_train() -> void:
	var game_state = _get_game_state()
	if game_state == null:
		return
	if not game_state.train.get("carriages", []).is_empty():
		return
	var carriages: Array = [
		{"type": "locomotive", "flipped": false},
		{"type": "coal_tender", "flipped": false},
		{"type": "passenger", "flipped": false},
		{"type": "combat_car", "flipped": false},
	]
	game_state.update_train_composition(carriages)
	game_state.add_resource("fuel", 100)

static func _get_game_state():
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")
