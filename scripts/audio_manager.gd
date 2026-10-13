extends Node
## AudioManager（Day 8）——全局音频总管（Autoload）。
## 职责：
##   1. BGM：程序合成循环音乐（AudioStreamWAV LOOP_FORWARD），按场景切换
##   2. SFX：统一入口转发到 AudioFx（点击/收集/维修/到站/汽笛等）
## 全部音频运行时合成，不依赖外部音频文件。

const AudioFxRef = preload("res://scripts/audio_fx.gd")

const SAMPLE_RATE := 22050
const BGM_VOLUME_DB := -10.0
const SFX_VOLUME_DB := -4.0

var _fx: Node = null
var _bgm_player: AudioStreamPlayer = null
var _current_bgm: String = ""

func _ready() -> void:
	_fx = AudioFxRef.new()
	add_child(_fx)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.volume_db = BGM_VOLUME_DB
	add_child(_bgm_player)

# ===== BGM =====
## 切换背景音乐；同一首不重启；空 id 停止。
func play_bgm(bgm_id: String) -> void:
	if bgm_id == _current_bgm and _bgm_player.playing:
		return
	if bgm_id.is_empty():
		stop_bgm()
		return
	var stream := _build_bgm(bgm_id)
	if stream == null:
		return
	_current_bgm = bgm_id
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm = ""

## 曲目定义：bpm + 声部（track），每个音符 [midi, 拍数]。
func _build_bgm(bgm_id: String) -> AudioStreamWAV:
	var bpm := 80.0
	var tracks: Array = []
	match bgm_id:
		"title":
			bpm = 72.0
			tracks = [
				{"wave": "sine", "vol": 0.30, "notes": [[45, 4], [45, 2], [45, 2], [48, 4], [45, 4], [43, 4], [45, 4]]},  # A2 低音
				{"wave": "sine", "vol": 0.16, "notes": [[57, 1], [60, 1], [64, 1], [60, 1], [64, 1], [67, 1], [64, 1], [60, 1], [57, 1], [60, 1], [64, 1], [69, 1], [67, 1], [64, 1], [60, 1], [57, 1]]},  # A 小调琶音
			]
		"main":
			bpm = 92.0
			tracks = [
				{"wave": "sine", "vol": 0.28, "notes": [[48, 4], [48, 2], [48, 2], [52, 4], [48, 4], [43, 4], [45, 4]]},
				{"wave": "triangle", "vol": 0.15, "notes": [[60, 1], [64, 1], [67, 1], [64, 1], [72, 1], [67, 1], [64, 1], [60, 1], [62, 1], [65, 1], [69, 1], [65, 1], [60, 1], [64, 1], [67, 1], [64, 1]]},
			]
		"travel":
			bpm = 108.0
			tracks = [
				{"wave": "sine", "vol": 0.30, "notes": [[40, 1], [40, 1], [40, 1], [40, 1], [40, 1], [40, 1], [40, 1], [40, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1]]},  # E2 八分低音推进
				{"wave": "triangle", "vol": 0.14, "notes": [[52, 2], [55, 2], [59, 2], [55, 2], [52, 2], [55, 2], [59, 2], [64, 2]]},  # 五度动机
			]
		"battle":
			bpm = 138.0
			tracks = [
				{"wave": "sine", "vol": 0.34, "notes": [[38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [38, 1], [36, 1], [36, 1], [36, 1], [36, 1], [36, 1], [36, 1], [36, 1], [36, 1]]},  # D2 快速低音
				{"wave": "square", "vol": 0.10, "notes": [[50, 2], [53, 2], [57, 2], [53, 2], [50, 2], [53, 2], [57, 2], [60, 2]]},  # 紧张动机
			]
		"story":
			bpm = 80.0
			tracks = [
				{"wave": "sine", "vol": 0.28, "notes": [[43, 4], [43, 2], [43, 2], [47, 4], [43, 4], [41, 4], [43, 4]]},  # G2
				{"wave": "triangle", "vol": 0.14, "notes": [[55, 2], [59, 2], [62, 2], [59, 2], [55, 2], [62, 2], [64, 2], [67, 2]]},
			]
		"victory":
			bpm = 120.0
			tracks = [
				{"wave": "sine", "vol": 0.28, "notes": [[48, 2], [48, 2], [48, 2], [48, 2], [45, 2], [45, 2], [43, 2], [43, 2]]},
				{"wave": "triangle", "vol": 0.16, "notes": [[60, 1], [64, 1], [67, 1], [72, 1], [67, 1], [72, 1], [76, 2], [69, 1], [72, 1], [76, 1], [79, 2], [77, 2]]},  # C 大调上行
			]
		"defeat":
			bpm = 58.0
			tracks = [
				{"wave": "sine", "vol": 0.30, "notes": [[45, 4], [43, 4], [41, 4], [38, 4]]},  # A2 慢速下行
				{"wave": "sine", "vol": 0.13, "notes": [[57, 2], [55, 2], [52, 2], [50, 2], [48, 2], [45, 2], [43, 4]]},  # 下行旋律
			]
		_:
			return null
	return _synthesize_bgm(tracks, bpm)

## 合成循环 BGM：多声部叠加 → 归一化 → PCM16 WAV（LOOP_FORWARD）
func _synthesize_bgm(tracks: Array, bpm: float) -> AudioStreamWAV:
	var beat_seconds := 60.0 / bpm
	var total_beats := 0.0
	for track in tracks:
		var beats := 0.0
		for note in track["notes"]:
			beats += float(note[1])
		total_beats = maxf(total_beats, beats)
	var total_seconds := total_beats * beat_seconds
	var frame_count := int(total_seconds * SAMPLE_RATE)
	var mix := PackedFloat32Array()
	mix.resize(frame_count)

	for track in tracks:
		var wave := str(track.get("wave", "sine"))
		var vol := float(track.get("vol", 0.15))
		var t := 0.0
		for note in track["notes"]:
			var midi := int(note[0])
			var beats := float(note[1])
			var freq := 440.0 * pow(2.0, (midi - 69) / 12.0)
			var duration := beats * beat_seconds
			var start_frame := int(t * SAMPLE_RATE)
			var end_frame := mini(frame_count, start_frame + int(duration * SAMPLE_RATE))
			for i in range(start_frame, end_frame):
				var tt := float(i - start_frame) / SAMPLE_RATE
				var envelope := _note_envelope(tt, duration)
				var sample := _wave_sample(wave, freq, tt) * envelope * vol
				mix[i] += sample
			t += beats * beat_seconds

	# 归一化防削波
	var peak := 0.0
	for s in mix:
		peak = maxf(peak, absf(s))
	if peak > 0.95:
		var scale := 0.95 / peak
		for i in range(mix.size()):
			mix[i] *= scale

	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in range(frame_count):
		var v := int(clampf(mix[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frame_count
	return wav

func _note_envelope(t: float, duration: float) -> float:
	# 快起音 + 指数衰减 + 尾部收束
	var attack := 0.012
	var env := 1.0
	if t < attack:
		env = t / attack
	var release := 0.18
	if duration - t < release:
		env *= (duration - t) / release
	return maxf(env, 0.0)

func _wave_sample(wave: String, freq: float, t: float) -> float:
	var phase := fposmod(freq * t, 1.0)
	match wave:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(phase - 0.5) - 1.0
		_:
			# 正弦 + 二次谐波（温暖感）
			return sin(TAU * phase) + 0.22 * sin(TAU * 2.0 * phase)

# ===== SFX 转发 =====
func play_shot() -> void: _fx.play_shot()
func play_hit() -> void: _fx.play_hit()
func play_wave_start() -> void: _fx.play_wave_start()
func play_alert() -> void: _fx.play_alert()
func play_victory() -> void: _fx.play_victory()
func play_failure() -> void: _fx.play_failure()
func play_click() -> void: _fx.play_click()
func play_back() -> void: _fx.play_back()
func play_collect() -> void: _fx.play_collect()
func play_repair() -> void: _fx.play_repair()
func play_supply() -> void: _fx.play_supply()
func play_arrive() -> void: _fx.play_arrive()
func play_event() -> void: _fx.play_event()
func play_whistle() -> void: _fx.play_whistle()
func play_brake() -> void: _fx.play_brake()
func play_error() -> void: _fx.play_error()
func play_select() -> void: _fx.play_select()
func play_depart() -> void: _fx.play_depart()

## 便捷：切换 BGM 时同时播放场景音效
func switch_scene(bgm_id: String, sfx_id: String = "click") -> void:
	play_bgm(bgm_id)
	if not sfx_id.is_empty():
		call("play_" + sfx_id)
