extends Control
class_name MainMenuUI

signal start_game

var _tilly_game: TillyGame

func _init(p_tilly_game: TillyGame) -> void:
	_tilly_game = p_tilly_game

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()

func _build_layout() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title = Label.new()
	title.text = "TILLY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Deep Space Crew Simulation"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var seed_label = Label.new()
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	if _tilly_game and _tilly_game.rng:
		seed_label.text = "Seed: %d" % _tilly_game.rng.seed
	else:
		seed_label.text = "Seed: ---"
	vbox.add_child(seed_label)

	var start_btn = Button.new()
	start_btn.text = "BEGIN RUN"
	start_btn.custom_minimum_size = Vector2(220, 60)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(func(): emit_signal("start_game"))
	vbox.add_child(start_btn)

	var version = Label.new()
	version.text = "v0.7 -- Alpha"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(version)
