extends SceneTree
## Day 8 音频系统测试：BGM 程序合成完整性 + SFX 入口可用性。

const AudioManagerRef = preload("res://scripts/audio_manager.gd")

var failures := 0
var _am: Node = null

func _init() -> void:
	_am = AudioManagerRef.new()
	root.add_child(_am)
	# headless --script 下 _ready 不保证触发，手动初始化成员
	_am._fx = AudioManagerRef.AudioFxRef.new()
	_am.add_child(_am._fx)
	_am._bgm_player = AudioStreamPlayer.new()
	_am.add_child(_am._bgm_player)
	_test_bgm_synthesis()
	_test_sfx_entries()

	if failures > 0:
		printerr("Day 8 音频测试失败：%d 项" % failures)
		quit(1)
	else:
		print("Day 8 音频测试通过")
		quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("[FAIL] " + message)

func _test_bgm_synthesis() -> void:
	var expected := ["title", "main", "travel", "battle", "story", "victory", "defeat"]
	for bgm_id in expected:
		var stream: AudioStreamWAV = _am._build_bgm(bgm_id)
		_check(stream != null, "BGM %s 应可合成" % bgm_id)
		if stream == null:
			continue
		_check(stream.data.size() > 20000, "BGM %s 数据应非空（%d 字节）" % [bgm_id, stream.data.size()])
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGM %s 应循环播放" % bgm_id)
		_check(stream.loop_end > 0, "BGM %s 循环点应有效" % bgm_id)
		# 时长 = loop_end / mix_rate，应在 5~20 秒
		var duration := float(stream.loop_end) / float(stream.mix_rate)
		_check(duration >= 5.0 and duration <= 20.0, "BGM %s 时长应在 5~20 秒（%.1f 秒）" % [bgm_id, duration])
	# 播放切换（headless --script 下节点不在树内无法真正播放，合成验证已覆盖）
	if _am.is_inside_tree():
		_am.play_bgm("title")
		_am.play_bgm("travel")
		_am.play_bgm("battle")
		_am.stop_bgm()
		_check(_am._current_bgm.is_empty(), "stop_bgm 后应清空当前曲目")

func _test_sfx_entries() -> void:
	var sfx_methods := [
		"play_click", "play_back", "play_collect", "play_repair", "play_supply",
		"play_arrive", "play_event", "play_whistle", "play_brake", "play_error",
		"play_select", "play_depart", "play_shot", "play_hit", "play_alert",
		"play_victory", "play_failure", "play_wave_start",
	]
	for method in sfx_methods:
		_check(_am.has_method(method), "AudioManager 应提供 %s" % method)
		_check(_am._fx.has_method(method), "AudioFx 应提供 %s" % method)
		# headless --script 下无法真正播放（节点不在树内），方法存在性即通过
