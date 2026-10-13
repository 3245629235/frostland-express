extends PanelContainer
class_name StationPanel
## 站点面板：显示站点操作并把动作交给 Travel 执行。

signal action_selected(action_id: String)

@onready var title_label: Label = $Margin/VBox/Title
@onready var info_label: Label = $Margin/VBox/Info
@onready var message_label: Label = $Margin/VBox/Message
@onready var progress_bar: ProgressBar = $Margin/VBox/Progress
@onready var action_box: HBoxContainer = $Margin/VBox/Actions
@onready var collect_button: Button = $Margin/VBox/Actions/CollectButton
@onready var repair_button: Button = $Margin/VBox/Actions/RepairButton
@onready var supply_button: Button = $Margin/VBox/Actions/SupplyButton
@onready var continue_button: Button = $Margin/VBox/Actions/ContinueButton

var _station_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	collect_button.pressed.connect(func():
		AudioManager.play_click()
		action_selected.emit("collect"))
	repair_button.pressed.connect(func():
		AudioManager.play_click()
		action_selected.emit("repair"))
	supply_button.pressed.connect(func():
		AudioManager.play_click()
		action_selected.emit("supply"))
	continue_button.pressed.connect(func():
		AudioManager.play_click()
		action_selected.emit("continue"))

func setup(station: Dictionary, station_index: int) -> void:
	_station_index = station_index
	title_label.text = "%s  ·  到站" % str(station.get("name", "站点"))
	info_label.text = "第 %d 站 | 里程 %.0f km | %s" % [station_index + 1, float(station.get("km", 0.0)), "本站必须停留" if station.get("forced", false) else "可选择继续"]
	repair_button.text = "维修（%d 零件）" % int(station.get("repair_cost", 10))
	message_label.text = "列车已停稳，可以进行补给和维修。"
	progress_bar.visible = false
	set_actions_enabled(true)

func set_message(message: String) -> void:
	message_label.text = message

func set_collect_progress(progress: float) -> void:
	progress_bar.visible = true
	progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	progress_bar.tooltip_text = "收集进度 %.0f%%" % (progress * 100.0)

func set_actions_enabled(enabled: bool) -> void:
	collect_button.disabled = not enabled
	repair_button.disabled = not enabled
	supply_button.disabled = not enabled
	continue_button.disabled = not enabled
