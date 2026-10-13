extends Node
class_name AudioFx
## Day 5 程序合成音效：不依赖外部音频素材。
## Day 6：主音量统一缩放 + 各音效音量分级（幅度 0.10~0.16，避免高频刺耳/低频过闷）。

var _active_players: Array = []

## 主音量（0~1，统一缩放所有程序音效）
const MASTER_VOLUME: float = 0.8

func play_shot() -> void:
	_play_wave(520.0, 0.08, 0.10, 0.0)

func play_hit() -> void:
	_play_wave(150.0, 0.12, 0.14, 1.0)

func play_wave_start() -> void:
	_play_wave(330.0, 0.16, 0.12, 0.0)
	_play_wave(495.0, 0.20, 0.10, 0.05)

func play_alert() -> void:
	_play_wave(740.0, 0.12, 0.16, 0.0)

func play_victory() -> void:
	_play_wave(392.0, 0.20, 0.13, 0.0)
	_play_wave(523.0, 0.24, 0.13, 0.12)
	_play_wave(659.0, 0.34, 0.13, 0.26)

func play_failure() -> void:
	_play_wave(260.0, 0.22, 0.13, 0.0)
	_play_wave(180.0, 0.32, 0.13, 0.16)

## ===== Day 8：通用交互音效 =====
## 按钮点击（短促高频）
func play_click() -> void:
	_play_wave(880.0, 0.05, 0.10, 0.0)
	_play_wave(1320.0, 0.04, 0.06, 0.02)

## 返回/取消（低频）
func play_back() -> void:
	_play_wave(440.0, 0.07, 0.10, 0.0)
	_play_wave(330.0, 0.09, 0.09, 0.04)

## 收集完成（上行双音，轻快）
func play_collect() -> void:
	_play_wave(660.0, 0.09, 0.11, 0.0)
	_play_wave(880.0, 0.12, 0.11, 0.08)

## 维修/修理（金属敲击）
func play_repair() -> void:
	_play_wave(320.0, 0.08, 0.13, 0.0)
	_play_wave(240.0, 0.10, 0.11, 0.05)
	_play_wave(480.0, 0.06, 0.09, 0.10)

## 补给（温和确认音）
func play_supply() -> void:
	_play_wave(523.0, 0.10, 0.11, 0.0)
	_play_wave(659.0, 0.14, 0.10, 0.07)

## 到站（钟声双音）
func play_arrive() -> void:
	_play_wave(523.0, 0.30, 0.13, 0.0)
	_play_wave(784.0, 0.36, 0.12, 0.12)

## 事件弹窗（提示音）
func play_event() -> void:
	_play_wave(740.0, 0.10, 0.13, 0.0)
	_play_wave(988.0, 0.14, 0.11, 0.06)

## 汽笛（火车特色，长音滑音）
func play_whistle() -> void:
	_play_wave(392.0, 0.55, 0.16, 0.0)
	_play_wave(466.0, 0.55, 0.14, 0.06)
	_play_wave(392.0, 0.50, 0.12, 0.14)

## 刹车（气压短促声）
func play_brake() -> void:
	_play_wave(180.0, 0.16, 0.14, 0.0)
	_play_wave(120.0, 0.22, 0.12, 0.05)

## 操作失败（低沉嘟声）
func play_error() -> void:
	_play_wave(220.0, 0.14, 0.13, 0.0)
	_play_wave(165.0, 0.18, 0.12, 0.08)

## 角色选中（短促定位音）
func play_select() -> void:
	_play_wave(1046.0, 0.05, 0.09, 0.0)

## 出发（低鸣启动）
func play_depart() -> void:
	_play_wave(196.0, 0.30, 0.13, 0.0)
	_play_wave(294.0, 0.34, 0.11, 0.10)

func _play_wave(frequency: float, duration: float, volume: float, delay: float) -> void:
	if delay > 0.0:
		var delay_timer := Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = delay
		add_child(delay_timer)
		delay_timer.timeout.connect(func():
			delay_timer.queue_free()
			_play_wave(frequency, duration, volume, 0.0)
		)
		delay_timer.start()
		return
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.25
	player.stream = stream
	player.volume_db = linear_to_db(MASTER_VOLUME)
	add_child(player)
	_active_players.append(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frame_count := int(duration * stream.mix_rate)
	for i in range(frame_count):
		if not playback.can_push_buffer(1):
			break
		var t := float(i) / stream.mix_rate
		var envelope := 1.0 - clampf(t / duration, 0.0, 1.0)
		var sample := sin(TAU * frequency * t) * envelope * volume
		if frequency > 400.0:
			sample += sin(TAU * frequency * 2.0 * t) * envelope * volume * 0.22
		playback.push_frame(Vector2(sample, sample))
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = duration + 0.3
	add_child(cleanup)
	cleanup.timeout.connect(func():
		_active_players.erase(player)
		if is_instance_valid(player):
			player.queue_free()
		cleanup.queue_free()
	)
	cleanup.start()
