extends Control

signal add_clicked

@onready var add_btn: Button = $CenterBox/AddBtn
@onready var hint_label: Label = $CenterBox/HintLabel

func _ready() -> void:
	add_btn.pressed.connect(_on_add_clicked)

func _on_add_clicked() -> void:
	add_clicked.emit()
