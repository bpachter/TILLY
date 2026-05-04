extends Control
class_name RunResultUI

## End-of-run screen showing outcome and stats.
## Emits play_again when player wants another run.

signal play_again

var _tilly_game: TillyGame
var _result: String

func _init(p_tilly_game: TillyGame, p_result: String) -> void:
	_tilly_game = p_tilly_game
	_result = p_result

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()

func _build_layout() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Outcome title
	var result_lbl = Label.new()
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 64)
	match _result:
		"victory":
			result_lbl.text = "VICTORY"
			result_lbl.add_theme_color_override("font_color", Color.GOLD)
		"defeat":
			result_lbl.text = "DEFEAT"
			result_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		"stranded":
			result_lbl.text = "STRANDED"
			result_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.1))
		_:
			result_lbl.text = _result.to_upper()
			result_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(result_lbl)

	vbox.add_child(HSeparator.new())

	# Stats
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(stats_vbox)

	if _tilly_game:
		var gs = _tilly_game.game_state
		_add_stat(stats_vbox, "Turns survived", str(gs.turn_number))
		_add_stat(stats_vbox, "Destinations visited", "%d / 8" % gs.visited_destinations.size())

		# Crew surviving
		var living = 0
		var total = _tilly_game.crew.size()
		for member in _tilly_game.crew:
			if member.health > 0:
				living += 1
		_add_stat(stats_vbox, "Crew surviving", "%d / %d" % [living, total])

		# Ambitions fulfilled
		var fulfilled = 0
		for member in _tilly_game.crew:
			if member.ambition_complete:
				fulfilled += 1
		_add_stat(stats_vbox, "Ambitions fulfilled", str(fulfilled))

		# Resources remaining
		_add_stat(stats_vbox, "Fuel remaining", str(gs.get_resource("fuel")))
		_add_stat(stats_vbox, "Scrap remaining", str(gs.get_resource("scrap")))

	vbox.add_child(HSeparator.new())

	var again_btn = Button.new()
	again_btn.text = "PLAY AGAIN"
	again_btn.custom_minimum_size = Vector2(220, 60)
	again_btn.add_theme_font_size_override("font_size", 20)
	again_btn.pressed.connect(func(): emit_signal("play_again"))
	vbox.add_child(again_btn)


func _add_stat(parent: VBoxContainer, label: String, value: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	parent.add_child(hbox)

	var key = Label.new()
	key.text = label + ":"
	key.add_theme_font_size_override("font_size", 16)
	key.custom_minimum_size = Vector2(260, 0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(key)

	var val = Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(val)
