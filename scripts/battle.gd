extends Node2D
## Day 4：雪狼袭击实时战斗教学关。

const BattleDataRef = preload("res://scripts/battle_data.gd")
const BattleSystemRef = preload("res://scripts/systems/battle_system.gd")
const StoryProgressRef = preload("res://scripts/story_progress.gd")
const AudioFxRef = preload("res://scripts/audio_fx.gd")
const CharacterDataRef = preload("res://scripts/character_data.gd")

const BATTLE_SCENE := "res://scenes/battle.tscn"
const VICTORY_SCENE := "res://scenes/victory.tscn"
const DEFEAT_SCENE := "res://scenes/defeat.tscn"
const WAVE_BREAK := 4.0

var battle: Dictionary = {}
var waves: Array = []
var wave_break_timer := 0.0
var next_spawn_timer := 0.0
var battle_message := "点击敌人射击，守住列车。"
var finished := false
var shape_nodes: Array = []
var level := 2
var branch := "safe"
var level_title := "关卡 2「雪狼袭击」"
var audio_fx: Node = null

@onready var arena: Node2D = $Arena
@onready var status_label: Label = $HUD/Top/Status
@onready var ammo_label: Label = $HUD/Top/Ammo
@onready var message_label: Label = $HUD/Message
@onready var crew_label: Label = $HUD/Crew
@onready var train_bar: ProgressBar = $HUD/TrainBar
@onready var back_button: Button = $HUD/Back

func _ready() -> void:
	AudioManager.play_bgm("battle")
	_ensure_crew_state()
	GameState.game_mode = "story"
	var progress := StoryProgressRef.load_progress()
	level = clampi(int(progress.get("current_level", 2)), 2, 3)
	if level < 2:
		level = 2
	branch = str(progress.get("branch", "safe"))
	if branch != "aggressive":
		branch = "safe"
	StoryProgressRef.prepare_story_state()
	level_title = BattleDataRef.get_level_title(level)
	waves = BattleDataRef.get_waves_for_level(level, branch)
	battle = BattleSystemRef.create_battle_state()
	audio_fx = AudioFxRef.new()
	add_child(audio_fx)
	back_button.pressed.connect(_on_back_pressed)
	audio_fx.play_alert()
	_update_hud()

func _ensure_crew_state() -> void:
	if GameState.characters == null:
		GameState.characters = []
	if GameState.characters.is_empty():
		GameState.characters = CharacterDataRef.get_default_team().map(func(c): return c.duplicate(true))

func _process(delta: float) -> void:
	if finished:
		return
	if _wave_complete():
		_advance_wave(delta)
	else:
		_spawn_loop(delta)
	var result := BattleSystemRef.advance(battle, delta, GameState.characters, GameState.train)
	if result.get("status", "") == "defeat":
		_finish(false, str(result.get("reason", "battle_failed")))
	_render_enemies()
	_update_hud()

func _wave_complete() -> bool:
	return int(battle.get("spawned_in_wave", 0)) >= int(waves[int(battle.get("wave_index", 0))].get("count", 0)) and (battle.get("enemies", []) as Array).is_empty()

func _advance_wave(delta: float) -> void:
	if int(battle.get("wave_index", 0)) >= waves.size() - 1:
		_finish(true, "")
		return
	wave_break_timer += delta
	if wave_break_timer >= WAVE_BREAK:
		battle["wave_index"] = int(battle.get("wave_index", 0)) + 1
		battle["spawned_in_wave"] = 0
		wave_break_timer = 0.0
		battle_message = "下一波袭击即将到来。"

func _spawn_loop(delta: float) -> void:
	var wave: Dictionary = waves[int(battle.get("wave_index", 0))]
	if int(battle.get("spawned_in_wave", 0)) >= int(wave.get("count", 0)):
		return
	next_spawn_timer -= delta
	if next_spawn_timer > 0.0:
		return
	BattleSystemRef.spawn_enemy(battle, str(wave.get("enemy", "snow_wolf")), 1120.0)
	battle["spawned_in_wave"] = int(battle.get("spawned_in_wave", 0)) + 1
	next_spawn_timer = float(wave.get("interval", 1.0))
	if audio_fx != null:
		audio_fx.play_wave_start()

func _unhandled_input(event: InputEvent) -> void:
	if finished or not event.is_action_pressed("click"):
		return
	var pos_variant: Variant = event.get("position")
	var pos: Vector2 = pos_variant if pos_variant is Vector2 else Vector2.ZERO
	var target_index := _enemy_at(pos)
	if target_index < 0:
		battle_message = "队员保持掩体位置。点击敌人进行射击。"
		return
	var result := BattleSystemRef.fire_at(battle, target_index, GameState.characters, GameState.resources)
	battle_message = str(result.get("attacker", "角色")) + ("命中，造成 %d 伤害" % int(result.get("damage", 0.0)) if result.get("ok", false) else str(result.get("message", "射击失败")))
	if result.get("ok", false) and audio_fx != null:
		audio_fx.play_shot()
	if result.get("ok", false) and result.get("shield_hits_left", 0) > 0:
		battle_message += "，护盾剩余 %d 次" % int(result.get("shield_hits_left", 0))
	elif result.get("ok", false) and result.get("shield_broken", false):
		battle_message += "，护盾已击破"
	if result.get("ok", false) and result.get("defeated", false):
		battle_message += "，目标已击倒"
		if audio_fx != null:
			audio_fx.play_hit()
	_update_hud()

func _enemy_at(pos: Vector2) -> int:
	var enemies: Array = battle.get("enemies", [])
	for i in range(enemies.size()):
		if pos.distance_to(Vector2(float(enemies[i].get("x", 0.0)), 360.0)) <= 58.0:
			return i
	return -1

func _render_enemies() -> void:
	for node in shape_nodes:
		if is_instance_valid(node):
			node.queue_free()
	shape_nodes.clear()
	for enemy in battle.get("enemies", []):
		var x := float(enemy.get("x", 0.0))
		var enemy_type := str(enemy.get("type", "snow_wolf"))
		var body := Polygon2D.new()
		body.polygon = _enemy_polygon(enemy_type)
		body.position = Vector2(x, 360.0)
		body.color = BattleDataRef.get_enemy(enemy_type).get("color", Color.WHITE)
		arena.add_child(body)
		shape_nodes.append(body)
		var name_label := Label.new()
		name_label.position = Vector2(x - 42.0, 252.0)
		name_label.size = Vector2(84.0, 28.0)
		name_label.text = str(enemy.get("name", enemy_type))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		arena.add_child(name_label)
		shape_nodes.append(name_label)
		var hp := ProgressBar.new()
		hp.position = Vector2(x - 38.0, 300.0)
		hp.size = Vector2(76, 10)
		hp.max_value = float(enemy.get("max_hp", 1.0))
		hp.value = float(enemy.get("hp", 0.0))
		hp.show_percentage = false
		arena.add_child(hp)
		shape_nodes.append(hp)

func _update_hud() -> void:
	var wave_index := int(battle.get("wave_index", 0))
	var total := waves.size()
	status_label.text = "%s    波次 %d/%d    敌人 %d" % [level_title, wave_index + 1, total, (battle.get("enemies", []) as Array).size()]
	ammo_label.text = "小口径弹药：%d    击倒：%d    射击冷却：%.1f 秒" % [GameState.get_resource("ammo_small"), int(battle.get("defeated", 0)), float(battle.get("fire_timer", 0.0))]
	if level == 3:
		var boss_time := float(battle.get("boss_elapsed", 0.0)) if bool(battle.get("boss_started", false)) else 0.0
		var boss_text := "Boss 限时：%.1f 秒" % maxf(0.0, BattleSystemRef.BOSS_TIME_LIMIT - boss_time) if bool(battle.get("boss_started", false)) else "Boss 尚未出现"
		ammo_label.text += "    " + boss_text
	message_label.text = battle_message
	train_bar.value = float(GameState.train.get("health", 0.0))
	var crew_parts: Array = []
	for character in GameState.characters:
		crew_parts.append("%s HP %d/%d" % [character.get("name", "队员"), int(character.get("health", 0.0)), int(character.get("max_health", 100.0))])
	crew_label.text = "    ".join(crew_parts)

func _finish(victory: bool, reason: String) -> void:
	if finished:
		return
	finished = true
	GameState.settlement_active = true
	GameState.settlement_result = SettlementSystem.build_result(reason, {"game_mode": "story", "train_health": GameState.train.get("health", 0.0), "characters": GameState.characters, "total_distance_km": 0.0})
	GameState.settlement_result["level"] = level
	GameState.settlement_result["branch"] = branch
	if victory:
		GameState.settlement_result["reason_label"] = "匪徒已击退" if level == 3 else "雪狼袭击已击退"
		GameState.add_resource("food", 30)
		GameState.add_resource("ammo_small", 30)
		GameState.morale = clampf(GameState.morale + 5.0, 0.0, 100.0)
		StoryProgressRef.complete_level(level)
		GameState.settlement_active = false
		if audio_fx != null:
			audio_fx.play_victory()
		if level < 3:
			GameState.save_state()
			get_tree().change_scene_to_file("res://scenes/story_transition.tscn")
			return
		GameState.settlement_active = true
		GameState.settlement_result["reason_label"] = "第一章完成：抵达极光城"
		GameState.save_state()
		get_tree().change_scene_to_file(VICTORY_SCENE)
		return
	if audio_fx != null:
		audio_fx.play_failure()
	StoryProgressRef.record_attempt(level)
	GameState.settlement_result["reason_label"] = "Boss 未能在 30 秒内击败" if reason == "boss_timeout" else "战斗失败"
	GameState.save_state()
	get_tree().change_scene_to_file(DEFEAT_SCENE)

func _on_back_pressed() -> void:
	GameState.settlement_active = false
	GameState.game_mode = "survival"
	get_tree().change_scene_to_file("res://scenes/story_hub.tscn")

func _enemy_polygon(enemy_type: String) -> PackedVector2Array:
	match enemy_type:
		"raider":
			return PackedVector2Array([Vector2(-18, 36), Vector2(-18, 4), Vector2(-10, -18), Vector2(-18, -34), Vector2(0, -46), Vector2(18, -34), Vector2(10, -18), Vector2(18, 4), Vector2(18, 36)])
		"shield_raider":
			return PackedVector2Array([Vector2(-32, 38), Vector2(-30, -22), Vector2(-12, -44), Vector2(12, -44), Vector2(30, -22), Vector2(32, 38)])
		"boss":
			return PackedVector2Array([Vector2(-44, 42), Vector2(-40, -12), Vector2(-28, -42), Vector2(-12, -54), Vector2(0, -44), Vector2(12, -54), Vector2(28, -42), Vector2(40, -12), Vector2(44, 42)])
		_:
			return PackedVector2Array([Vector2(-28, 35), Vector2(-18, -12), Vector2(0, -38), Vector2(20, -12), Vector2(28, 35)])
