extends Control
class_name NavigationMapUI

## Interactive navigation screen.
## Player clicks destination nodes to travel. Rolls for encounters and events.
## Emits combat_requested or run_ended when appropriate.

signal combat_requested
signal run_ended(result: String)

var tilly_game: TillyGame

const HUD_HEIGHT: int = 70
const CREW_PANEL_WIDTH: int = 300
const NODE_RADIUS: float = 28.0

const DEST_POSITIONS: Dictionary = {
	"earth":       Vector2(160, 560),
	"mars_colony": Vector2(400, 500),
	"europa":      Vector2(640, 360),
	"enceladus":   Vector2(620, 680),
	"ganymede":    Vector2(880, 500),
	"titan":       Vector2(1100, 330),
	"ceres":       Vector2(1110, 680),
	"pluto":       Vector2(1380, 500)
}

const DEST_LABELS: Dictionary = {
	"earth":       "Earth",
	"mars_colony": "Mars\nColony",
	"europa":      "Europa",
	"enceladus":   "Enceladus",
	"ganymede":    "Ganymede",
	"titan":       "Titan",
	"ceres":       "Ceres",
	"pluto":       "Pluto"
}

var _dest_buttons: Dictionary = {}
var _map_canvas: Control
var _hud_labels: Dictionary = {}
var _crew_status_vbox: VBoxContainer
var _status_label: Label
var _event_dialog: EventDialogUI


# Inner class for drawing connection lines between destinations.
class MapCanvas extends Control:
	var connections: Array = []

	func add_connection(a: Vector2, b: Vector2) -> void:
		connections.append({"from": a, "to": b})
		queue_redraw()

	func _draw() -> void:
		for conn in connections:
			draw_line(conn["from"], conn["to"], Color(0.4, 0.4, 0.6, 0.8), 2.0)


func _init(p_tilly_game: TillyGame) -> void:
	tilly_game = p_tilly_game

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_display()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# HUD bar (top)
	var hud = PanelContainer.new()
	hud.position = Vector2(0, 0)
	hud.size = Vector2(1920, HUD_HEIGHT)
	add_child(hud)

	var hud_hbox = HBoxContainer.new()
	hud_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_hbox.add_theme_constant_override("separation", 30)
	hud.add_child(hud_hbox)

	var hud_margin = MarginContainer.new()
	for side in ["left", "right"]:
		hud_margin.add_theme_constant_override("margin_" + side, 20)
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_hbox.add_child(hud_margin)

	var hud_inner = HBoxContainer.new()
	hud_inner.add_theme_constant_override("separation", 40)
	hud_margin.add_child(hud_inner)

	for key in ["turn", "fuel", "hull", "scrap"]:
		var lbl = Label.new()
		lbl.text = key.capitalize() + ": --"
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hud_inner.add_child(lbl)
		_hud_labels[key] = lbl

	# Map area (left of crew panel, below HUD)
	var map_width = 1920 - CREW_PANEL_WIDTH
	var map_height = 1080 - HUD_HEIGHT

	_map_canvas = MapCanvas.new()
	_map_canvas.position = Vector2(0, HUD_HEIGHT)
	_map_canvas.size = Vector2(map_width, map_height)
	add_child(_map_canvas)

	# Load connections from destinations contract and draw lines
	_build_map_connections()

	# Destination buttons
	for dest_id in DEST_POSITIONS.keys():
		var pos: Vector2 = DEST_POSITIONS[dest_id]
		var btn = Button.new()
		btn.text = DEST_LABELS.get(dest_id, dest_id)
		btn.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		# Center the button on its position
		btn.position = Vector2(0, HUD_HEIGHT) + pos - Vector2(NODE_RADIUS, NODE_RADIUS)
		btn.size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		var capture_id = dest_id
		btn.pressed.connect(func(): _on_dest_clicked(capture_id))
		add_child(btn)
		_dest_buttons[dest_id] = btn

	# Crew panel (right side)
	var crew_panel = PanelContainer.new()
	crew_panel.position = Vector2(1920 - CREW_PANEL_WIDTH, HUD_HEIGHT)
	crew_panel.size = Vector2(CREW_PANEL_WIDTH, map_height)
	add_child(crew_panel)

	var crew_vbox = VBoxContainer.new()
	crew_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	crew_vbox.add_theme_constant_override("separation", 6)
	crew_panel.add_child(crew_vbox)

	var crew_title = Label.new()
	crew_title.text = "CREW"
	crew_title.add_theme_font_size_override("font_size", 15)
	crew_vbox.add_child(crew_title)

	crew_vbox.add_child(HSeparator.new())

	_crew_status_vbox = VBoxContainer.new()
	_crew_status_vbox.add_theme_constant_override("separation", 8)
	crew_vbox.add_child(_crew_status_vbox)

	# Status bar (bottom)
	_status_label = Label.new()
	_status_label.text = "Ready to depart."
	_status_label.position = Vector2(20, 1080 - 30)
	_status_label.size = Vector2(1200, 26)
	_status_label.add_theme_font_size_override("font_size", 13)
	add_child(_status_label)

	# EventDialog overlay (child of this screen)
	_event_dialog = EventDialogUI.new()
	add_child(_event_dialog)


func _build_map_connections() -> void:
	if not tilly_game:
		return
	var dests_contract = tilly_game.contract_loader.get_contract("destinations")
	var seen: Dictionary = {}
	for dest in dests_contract.get("destinations", []):
		var from_id = dest.get("id", "")
		if from_id not in DEST_POSITIONS:
			continue
		for neighbor_id in dest.get("neighbors", []):
			if neighbor_id not in DEST_POSITIONS:
				continue
			var edge_key = [from_id, neighbor_id]
			edge_key.sort()
			var key_str = edge_key[0] + "-" + edge_key[1]
			if key_str in seen:
				continue
			seen[key_str] = true
			_map_canvas.add_connection(DEST_POSITIONS[from_id], DEST_POSITIONS[neighbor_id])


func _refresh_display() -> void:
	if not tilly_game:
		return
	var gs = tilly_game.game_state

	# HUD
	_hud_labels["turn"].text = "Turn: %d" % gs.turn_number
	_hud_labels["fuel"].text = "Fuel: %d" % gs.get_resource("fuel")
	_hud_labels["hull"].text = "Hull: %d" % gs.get_resource("hull")
	_hud_labels["scrap"].text = "Scrap: %d" % gs.get_resource("scrap")

	# Destination button colors
	var current = gs.current_destination
	var neighbors = tilly_game.get_destination_neighbors(current)
	for dest_id in _dest_buttons.keys():
		var btn: Button = _dest_buttons[dest_id]
		if dest_id == current:
			btn.add_theme_color_override("font_color", Color.CYAN)
		elif dest_id in gs.visited_destinations:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif dest_id in neighbors:
			btn.add_theme_color_override("font_color", Color.GREEN)
		else:
			btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

	# Status label
	var loc_name = DEST_LABELS.get(current, current)
	_status_label.text = "Location: %s  |  Turn %d" % [loc_name, gs.turn_number]

	# Crew panel
	_refresh_crew_panel()


func _refresh_crew_panel() -> void:
	for child in _crew_status_vbox.get_children():
		child.queue_free()

	for member in tilly_game.crew:
		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var name_hbox = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = "%s (%s)" % [member.name, member.role]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_hbox.add_child(name_lbl)
		row.add_child(name_hbox)

		# Morale / Stress compact display
		var stat_lbl = Label.new()
		stat_lbl.add_theme_font_size_override("font_size", 10)
		stat_lbl.text = "HP:%d  MO:%d  ST:%d" % [member.health, member.morale, member.stress]
		row.add_child(stat_lbl)

		if not member.phobias.is_empty():
			var ph_lbl = Label.new()
			ph_lbl.add_theme_font_size_override("font_size", 9)
			ph_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
			ph_lbl.text = "Phobia: " + ", ".join(member.phobias)
			row.add_child(ph_lbl)

		_crew_status_vbox.add_child(row)
		_crew_status_vbox.add_child(HSeparator.new())


func _on_dest_clicked(dest_id: String) -> void:
	var gs = tilly_game.game_state
	var current = gs.current_destination

	# Guard: neighbor check
	var neighbors = tilly_game.get_destination_neighbors(current)
	if dest_id not in neighbors:
		_status_label.text = "Cannot travel to %s from here." % DEST_LABELS.get(dest_id, dest_id)
		return

	# Guard: fuel
	var fuel = gs.get_resource("fuel")
	if fuel < 15:
		_status_label.text = "Not enough fuel! (need 15)"
		return

	# Disable buttons during processing
	_set_buttons_enabled(false)

	# Travel
	tilly_game.travel_to_destination(dest_id)
	_refresh_display()

	# Check game over after travel
	var result = tilly_game.check_run_state()
	if result != "ongoing":
		run_ended.emit(result)
		return

	# Roll for combat encounter
	var enc_chance = tilly_game.get_encounter_chance(dest_id)
	if tilly_game.rng.next_float() < enc_chance:
		_status_label.text = "HOSTILE CONTACT! Entering combat..."
		tilly_game.start_combat_encounter()
		tilly_game.apply_stress_shock(25)
		combat_requested.emit()
		return

	# Roll for event (70% chance when no combat)
	if tilly_game.rng.next_float() < 0.70:
		var event_data = tilly_game.pick_random_event()
		if not event_data.is_empty():
			_event_dialog.show_event(event_data)
			var choice_idx = await _event_dialog.choice_made
			tilly_game.apply_event_choice(event_data, choice_idx)
			_refresh_display()

	# Advance crew time (morale/stress/therapy ticks)
	tilly_game.advance_crew_time()
	_refresh_display()

	# Re-check game over after time advancement
	result = tilly_game.check_run_state()
	if result != "ongoing":
		run_ended.emit(result)
		return

	_set_buttons_enabled(true)
	_status_label.text = "Arrived at %s." % DEST_LABELS.get(dest_id, dest_id)


func _set_buttons_enabled(enabled: bool) -> void:
	for btn in _dest_buttons.values():
		btn.disabled = not enabled
