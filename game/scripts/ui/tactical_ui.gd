extends Control
class_name TacticalUI

## UI controller for combat phase.
## Displays: ship subsystems, crew health/morale/stress with live status badges,
## enemy ship hull, and a pause menu.

var combat_engine: CombatEngine
var game_state: GameState
var crew: Array = []
var is_paused: bool = false

# Live crew panel — one row per crew member
var _crew_rows: Array = []

# Cached node refs
var _player_hull_bar: ProgressBar
var _player_hull_label: Label
var _enemy_hull_bar: ProgressBar
var _enemy_hull_label: Label
var _enemy_status_label: Label
var _crew_panel_vbox: VBoxContainer


func _ready() -> void:
	setup_ui_layout()
	update_display()


func setup_ui_layout() -> void:
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_hbox)
	
	# Left panel: Player ship + Crew Status
	main_hbox.add_child(_build_player_panel())
	
	# Center: Combat viewport (placeholder)
	var center_panel = PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center_label = Label.new()
	center_label.text = "[Combat Viewport]"
	center_label.add_theme_font_size_override("font_size", 18)
	center_label.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.add_child(center_label)
	main_hbox.add_child(center_panel)
	
	# Right panel: Enemy ship
	main_hbox.add_child(_build_enemy_panel())
	
	# Pause button top-right
	var pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(_on_pause_pressed)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	add_child(pause_button)


func _build_player_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "PLAYER SHIP"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	# Hull row
	var hull_hbox = HBoxContainer.new()
	var hull_lbl = Label.new()
	hull_lbl.text = "Hull:"
	hull_lbl.custom_minimum_size = Vector2(40, 0)
	hull_hbox.add_child(hull_lbl)
	_player_hull_bar = ProgressBar.new()
	_player_hull_bar.min_value = 0
	_player_hull_bar.max_value = 100
	_player_hull_bar.value = 100
	_player_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_hbox.add_child(_player_hull_bar)
	_player_hull_label = Label.new()
	_player_hull_label.text = "100"
	_player_hull_label.custom_minimum_size = Vector2(36, 0)
	hull_hbox.add_child(_player_hull_label)
	vbox.add_child(hull_hbox)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Crew section header
	var crew_title = Label.new()
	crew_title.text = "CREW"
	crew_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(crew_title)
	
	_crew_panel_vbox = VBoxContainer.new()
	_crew_panel_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_crew_panel_vbox)
	
	return panel


func _build_enemy_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "ENEMY SHIP"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	_enemy_hull_label = Label.new()
	_enemy_hull_label.name = "enemy_hull_label"
	_enemy_hull_label.text = "Hull: 100/100"
	vbox.add_child(_enemy_hull_label)
	
	_enemy_hull_bar = ProgressBar.new()
	_enemy_hull_bar.name = "enemy_hull_bar"
	_enemy_hull_bar.min_value = 0
	_enemy_hull_bar.max_value = 100
	_enemy_hull_bar.value = 100
	vbox.add_child(_enemy_hull_bar)
	
	_enemy_status_label = Label.new()
	_enemy_status_label.name = "enemy_status_label"
	_enemy_status_label.text = "Status: Active"
	vbox.add_child(_enemy_status_label)
	
	return panel


func _build_crew_row(member) -> Dictionary:
	## Build one crew row: name, health bar, morale bar, stress indicator, status badge.
	var row_vbox = VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 2)
	
	# Name + status badge
	var name_hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = "%s (%s)" % [member.name, member.role]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_lbl)
	
	var status_badge = Label.new()
	status_badge.text = "OK"
	status_badge.add_theme_font_size_override("font_size", 10)
	status_badge.custom_minimum_size = Vector2(60, 0)
	name_hbox.add_child(status_badge)
	row_vbox.add_child(name_hbox)
	
	# Health bar
	var hp_hbox = HBoxContainer.new()
	var hp_lbl = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.custom_minimum_size = Vector2(26, 0)
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_hbox.add_child(hp_lbl)
	var hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = member.health
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_hbox.add_child(hp_bar)
	row_vbox.add_child(hp_hbox)
	
	# Morale bar
	var morale_hbox = HBoxContainer.new()
	var morale_lbl = Label.new()
	morale_lbl.text = "MO"
	morale_lbl.custom_minimum_size = Vector2(26, 0)
	morale_lbl.add_theme_font_size_override("font_size", 10)
	morale_hbox.add_child(morale_lbl)
	var morale_bar = ProgressBar.new()
	morale_bar.min_value = 0
	morale_bar.max_value = 100
	morale_bar.value = member.morale
	morale_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	morale_hbox.add_child(morale_bar)
	row_vbox.add_child(morale_hbox)
	
	# Stress bar
	var stress_hbox = HBoxContainer.new()
	var stress_lbl = Label.new()
	stress_lbl.text = "ST"
	stress_lbl.custom_minimum_size = Vector2(26, 0)
	stress_lbl.add_theme_font_size_override("font_size", 10)
	stress_hbox.add_child(stress_lbl)
	var stress_bar = ProgressBar.new()
	stress_bar.min_value = 0
	stress_bar.max_value = 100
	stress_bar.value = member.stress
	stress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stress_hbox.add_child(stress_bar)
	row_vbox.add_child(stress_hbox)
	
	# Phobia / skill badge row
	var extras_lbl = Label.new()
	extras_lbl.add_theme_font_size_override("font_size", 9)
	extras_lbl.text = _build_extras_text(member)
	row_vbox.add_child(extras_lbl)
	
	_crew_panel_vbox.add_child(row_vbox)
	if crew.find(member) < crew.size() - 1:
		_crew_panel_vbox.add_child(HSeparator.new())
	
	return {
		"root": row_vbox,
		"status_badge": status_badge,
		"hp_bar": hp_bar,
		"morale_bar": morale_bar,
		"stress_bar": stress_bar,
		"extras_lbl": extras_lbl,
		"crew_member": member
	}


func _build_extras_text(member) -> String:
	var parts: Array = []
	# Skill levels
	var primary_skill = member.get_primary_skill() if member.has_method("get_primary_skill") else ""
	if primary_skill != "":
		var lvl = member.skill_level.get(primary_skill, 0)
		var level_names = ["Novice", "Proficient", "Expert"]
		parts.append("%s: %s" % [primary_skill.capitalize(), level_names[lvl]])
	# Active phobias (abbreviated)
	if not member.phobias.is_empty():
		parts.append("⚠ %s" % ", ".join(member.phobias))
	# Ambition progress
	if not member.ambition_id.is_empty() and not member.ambition_complete:
		parts.append("Goal %d%%" % member.ambition_progress)
	elif member.ambition_complete:
		parts.append("★ Goal done")
	return " | ".join(parts)


func bind_combat(p_combat_engine: CombatEngine, p_game_state: GameState, p_crew: Array) -> void:
	combat_engine = p_combat_engine
	game_state = p_game_state
	crew = p_crew
	_rebuild_crew_panel()


func _rebuild_crew_panel() -> void:
	## Clear and rebuild crew rows from current crew array.
	for child in _crew_panel_vbox.get_children():
		child.queue_free()
	_crew_rows.clear()
	
	for member in crew:
		var row = _build_crew_row(member)
		_crew_rows.append(row)


func update_display() -> void:
	if not combat_engine:
		return
	
	var state = combat_engine.get_combat_state()
	
	# Update player hull
	var player_hull = state.get("player_hull", 0)
	if _player_hull_bar:
		_player_hull_bar.value = player_hull
	if _player_hull_label:
		_player_hull_label.text = str(player_hull)
	
	# Update enemy hull
	var enemy_hull = state.get("enemy_hull", 0)
	if _enemy_hull_bar:
		_enemy_hull_bar.value = enemy_hull
	if _enemy_hull_label:
		_enemy_hull_label.text = "Hull: %d/100" % enemy_hull
	
	# Update outcome display
	if combat_engine.is_combat_over():
		var outcome = state.get("outcome", "unknown")
		if _enemy_status_label:
			_enemy_status_label.text = "Status: %s" % outcome.to_upper()
	
	# Update crew rows
	for row in _crew_rows:
		var member = row["crew_member"]
		row["hp_bar"].value = member.health
		row["morale_bar"].value = member.morale
		row["stress_bar"].value = member.stress
		row["status_badge"].text = _get_status_badge(member)
		row["extras_lbl"].text = _build_extras_text(member)


func _get_status_badge(member) -> String:
	if member.health <= 0:
		return "DEAD"
	if member.stress > 75:
		return "PANICKED"
	if member.morale <= 20:
		return "DESPAIR"
	if member.morale < 30:
		return "CRISIS"
	if member.health < 30:
		return "CRITICAL"
	if member.morale > 80 and member.stress < 20:
		return "EXCELLENT"
	return "OK"


func _on_pause_pressed() -> void:
	is_paused = !is_paused
	combat_engine.set_paused(is_paused)
	print("Combat %s" % ("PAUSED" if is_paused else "RESUMED"))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_pause_pressed()



func _ready() -> void:
	print("TacticalUI initializing...")
	setup_ui_layout()
	update_display()


func setup_ui_layout() -> void:
	# Root HBoxContainer for main layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_hbox)
	
	# Left panel: Subsystems (player ship)
	var left_panel = create_subsystem_panel()
	main_hbox.add_child(left_panel)
	
	# Center: Combat area (placeholder)
	var center_panel = PanelContainer.new()
	center_panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	center_panel.get_theme_stylebox("panel").bg_color = Color.BLACK
	var center_label = Label.new()
	center_label.text = "[Combat Viewport]"
	center_label.add_theme_font_size_override("font_size", 20)
	center_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_panel.add_child(center_label)
	main_hbox.add_child(center_panel)
	
	# Right panel: Enemy ship
	var right_panel = create_enemy_panel()
	main_hbox.add_child(right_panel)
	
	# Top-right: Pause button
	var pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)


func create_subsystem_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	
	var title = Label.new()
	title.text = "PLAYER SHIP"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	subsystem_status_vbox = VBoxContainer.new()
	
	# Create subsystem entries
	var subsystems = ["Engines", "Shields", "Life Support", "Sensors", "Lab", "Weapons"]
	for subsys_name in subsystems:
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = subsys_name
		label.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(label)
		
		var progress = ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 100
		progress.value = 100
		progress.custom_minimum_size = Vector2(100, 20)
		hbox.add_child(progress)
		
		subsystem_status_vbox.add_child(hbox)
	
	vbox.add_child(subsystem_status_vbox)
	panel.add_child(vbox)
	return panel


func create_enemy_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	
	var title = Label.new()
	title.text = "ENEMY SHIP"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	var hull_label = Label.new()
	hull_label.text = "Hull: 100/100"
	hull_label.name = "enemy_hull_label"
	vbox.add_child(hull_label)
	
	var hull_progress = ProgressBar.new()
	hull_progress.min_value = 0
	hull_progress.max_value = 100
	hull_progress.value = 100
	hull_progress.name = "enemy_hull_bar"
	vbox.add_child(hull_progress)
	
	var status_label = Label.new()
	status_label.text = "Status: Active"
	status_label.name = "enemy_status_label"
	vbox.add_child(status_label)
	
	panel.add_child(vbox)
	return panel


func bind_combat(p_combat_engine: CombatEngine, p_game_state: GameState, p_crew: Array) -> void:
	combat_engine = p_combat_engine
	game_state = p_game_state
	crew = p_crew


func update_display() -> void:
	if not combat_engine:
		return
	
	var state = combat_engine.get_combat_state()
	
	# Update player ship hull
	var root = get_node(".")
	if root.has_node("PanelContainer"):
		pass  # Would update here in full implementation
	
	# Update enemy ship status
	var enemy_hull_label = find_child("enemy_hull_label")
	if enemy_hull_label:
		enemy_hull_label.text = "Hull: %d/100" % state.get("enemy_hull", 0)
	
	var enemy_hull_bar = find_child("enemy_hull_bar")
	if enemy_hull_bar:
		enemy_hull_bar.value = state.get("enemy_hull", 0)
	
	# Update outcome if combat is over
	if combat_engine.is_combat_over():
		var outcome = state.get("outcome", "unknown")
		var status_label = find_child("enemy_status_label")
		if status_label:
			status_label.text = "Status: %s" % outcome.to_upper()


func _on_pause_pressed() -> void:
	is_paused = !is_paused
	combat_engine.set_paused(is_paused)
	print("Combat %s" % ("PAUSED" if is_paused else "RESUMED"))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_pause_pressed()
