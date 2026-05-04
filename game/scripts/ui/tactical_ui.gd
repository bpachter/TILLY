extends Control
class_name TacticalUI

## UI controller for combat phase.
## Displays: ship subsystems, crew positions, power state, pause menu.

var combat_engine: CombatEngine
var game_state: GameState
var crew: Array = []
var is_paused: bool = false

# UI element refs
var subsystem_status_vbox: VBoxContainer
var crew_roster_vbox: VBoxContainer
var power_bar: ProgressBar
var pause_menu: PanelContainer


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
