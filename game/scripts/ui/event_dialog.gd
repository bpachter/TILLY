extends Control
class_name EventDialogUI

signal choice_made(choice_idx: int)

var _title_label: Label
var _desc_label: Label
var _btn_container: VBoxContainer
var _suggestion_label: Label

func _ready() -> void:
	visible = false
	_build_layout()

func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dim overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_title_label)

	inner.add_child(HSeparator.new())

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size = Vector2(0, 40)
	inner.add_child(_desc_label)

	_suggestion_label = Label.new()
	_suggestion_label.add_theme_font_size_override("font_size", 11)
	_suggestion_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_suggestion_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_suggestion_label.visible = false
	inner.add_child(_suggestion_label)

	inner.add_child(HSeparator.new())

	_btn_container = VBoxContainer.new()
	_btn_container.add_theme_constant_override("separation", 8)
	inner.add_child(_btn_container)

func show_event(event_data: Dictionary) -> void:
	_title_label.text = event_data.get("title", "Event")
	_desc_label.text = event_data.get("description", "")

	var suggestion = event_data.get("crew_suggestion", "")
	if suggestion != "":
		_suggestion_label.text = "Crew note: " + suggestion
		_suggestion_label.visible = true
	else:
		_suggestion_label.visible = false

	for child in _btn_container.get_children():
		child.queue_free()

	var choices: Array = event_data.get("choices", [])
	for i in choices.size():
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice.get("text", "Option %d" % i)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.custom_minimum_size = Vector2(0, 44)
		var idx = i
		btn.pressed.connect(func(): _on_choice_pressed(idx))
		_btn_container.add_child(btn)

	visible = true

func _on_choice_pressed(idx: int) -> void:
	visible = false
	emit_signal("choice_made", idx)
