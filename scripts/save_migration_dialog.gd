extends Control
class_name SaveMigrationDialog
## 旧版/异常存档处理面板：用户明确选择前不允许继续覆盖存档。

signal decision(continue_compatible: bool)

@onready var reason_label: Label = $Center/Panel/Margin/VBox/Reason
@onready var backup_label: Label = $Center/Panel/Margin/VBox/Backup
@onready var continue_button: Button = $Center/Panel/Margin/VBox/Actions/ContinueButton
@onready var reset_button: Button = $Center/Panel/Margin/VBox/Actions/ResetButton

var _resolved: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

func setup(reason: String, backup_path: String) -> void:
	reason_label.text = reason
	backup_label.text = "原存档已备份：%s" % backup_path
	_resolved = false
	visible = true

func _on_continue_pressed() -> void:
	_resolve(true)

func _on_reset_pressed() -> void:
	_resolve(false)

func _resolve(continue_compatible: bool) -> void:
	if _resolved:
		return
	_resolved = true
	continue_button.disabled = true
	reset_button.disabled = true
	decision.emit(continue_compatible)
