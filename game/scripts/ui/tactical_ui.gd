extends Control
class_name TacticalUI

signal combat_finished(outcome: String)

var combat_engine: CombatEngine
var game_state: GameState
var crew: Array = []
var _crew_panel_vbox: VBoxContainer
var _crew_rows: Array = []
var _player_hull_bar: ProgressBar
var _player_hull_label: Label
var _enemy_hull_bar: ProgressBar
var _enemy_hull_label: Label
var _enemy_name_label: Label
var _enemy_shield_label: Label
var _turn_log_vbox: VBoxContainer
var _turn_log_scroll: ScrollContainer
var _action_attack: Button
var _action_repair: Button
var _action_evade: Button
var _result_label: Label
var _continue_btn: Button

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root_hbox = HBoxContainer.new()
	root_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	add_child(root_hbox)
	root_hbox.add_child(_build_crew_panel())
	root_hbox.add_child(_build_center_panel())
	root_hbox.add_child(_build_enemy_panel())

func _build_crew_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title = Label.new()
	title.text = "CREW STATUS"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)
	var hull_hbox = HBoxContainer.new()
	var hl = Label.new(); hl.text = "Ship Hull:"; hl.custom_minimum_size = Vector2(70, 0)
	hull_hbox.add_child(hl)
	_player_hull_bar = ProgressBar.new()
	_player_hull_bar.min_value = 0; _player_hull_bar.max_value = 100; _player_hull_bar.value = 100
	_player_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_hbox.add_child(_player_hull_bar)
	_player_hull_label = Label.new(); _player_hull_label.text = "100"; _player_hull_label.custom_minimum_size = Vector2(34, 0)
	hull_hbox.add_child(_player_hull_label)
	vbox.add_child(hull_hbox)
	vbox.add_child(HSeparator.new())
	var crew_hdr = Label.new(); crew_hdr.text = "CREW"; crew_hdr.add_theme_font_size_override("font_size", 12)
	vbox.add_child(crew_hdr)
	_crew_panel_vbox = VBoxContainer.new()
	_crew_panel_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_crew_panel_vbox)
	return panel

func _build_crew_row(member) -> Dictionary:
	var row_root = VBoxContainer.new()
	row_root.add_theme_constant_override("separation", 2)
	var name_hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = "%s (%s)" % [member.name, member.role]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_lbl)
	var badge = Label.new(); badge.text = "OK"; badge.add_theme_font_size_override("font_size", 10)
	badge.custom_minimum_size = Vector2(64, 0)
	name_hbox.add_child(badge)
	row_root.add_child(name_hbox)
	var hp_hbox = HBoxContainer.new()
	var hp_lbl = Label.new(); hp_lbl.text = "HP"; hp_lbl.custom_minimum_size = Vector2(24, 0); hp_lbl.add_theme_font_size_override("font_size", 10); hp_hbox.add_child(hp_lbl)
	var hp_bar = ProgressBar.new(); hp_bar.min_value = 0; hp_bar.max_value = 100; hp_bar.value = member.health; hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hp_hbox.add_child(hp_bar)
	row_root.add_child(hp_hbox)
	var mo_hbox = HBoxContainer.new()
	var mo_lbl = Label.new(); mo_lbl.text = "MO"; mo_lbl.custom_minimum_size = Vector2(24, 0); mo_lbl.add_theme_font_size_override("font_size", 10); mo_hbox.add_child(mo_lbl)
	var mo_bar = ProgressBar.new(); mo_bar.min_value = 0; mo_bar.max_value = 100; mo_bar.value = member.morale; mo_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mo_hbox.add_child(mo_bar)
	row_root.add_child(mo_hbox)
	var st_hbox = HBoxContainer.new()
	var st_lbl = Label.new(); st_lbl.text = "ST"; st_lbl.custom_minimum_size = Vector2(24, 0); st_lbl.add_theme_font_size_override("font_size", 10); st_hbox.add_child(st_lbl)
	var st_bar = ProgressBar.new(); st_bar.min_value = 0; st_bar.max_value = 100; st_bar.value = member.stress; st_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; st_hbox.add_child(st_bar)
	row_root.add_child(st_hbox)
	var extras = Label.new(); extras.add_theme_font_size_override("font_size", 9); extras.text = _build_extras_text(member)
	row_root.add_child(extras)
	_crew_panel_vbox.add_child(row_root)
	if crew.find(member) < crew.size() - 1:
		_crew_panel_vbox.add_child(HSeparator.new())
	return {"root": row_root, "badge": badge, "hp_bar": hp_bar, "mo_bar": mo_bar, "st_bar": st_bar, "extras": extras, "member": member}

func _build_extras_text(member) -> String:
	var parts: Array = []
	if member.has_method("get_primary_skill"):
		var sk = member.get_primary_skill()
		if sk != "":
			var lvl_names = ["Novice", "Proficient", "Expert"]
			parts.append("%s: %s" % [sk.capitalize(), lvl_names[member.skill_level.get(sk, 0)]])
	if not member.phobias.is_empty():
		parts.append("! " + ", ".join(member.phobias))
	if not member.ambition_id.is_empty():
		if member.ambition_complete: parts.append("* Goal done")
		else: parts.append("Goal %d%%" % member.ambition_progress)
	return " | ".join(parts)

func _get_status_badge(member) -> String:
	if member.health <= 0:  return "DEAD"
	if member.stress > 75:  return "PANICKED"
	if member.morale <= 20: return "DESPAIR"
	if member.health < 30:  return "CRITICAL"
	if member.morale > 80 and member.stress < 20: return "EXCELLENT"
	return "OK"

func _rebuild_crew_rows() -> void:
	for child in _crew_panel_vbox.get_children():
		child.queue_free()
	_crew_rows.clear()
	for member in crew:
		_crew_rows.append(_build_crew_row(member))

func _build_center_panel() -> VBoxContainer:
	var outer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	outer.add_child(margin)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)
	var title = Label.new(); title.text = "-- COMBAT --"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 22)
	inner.add_child(title)
	_turn_log_scroll = ScrollContainer.new()
	_turn_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_turn_log_scroll.custom_minimum_size = Vector2(0, 300)
	inner.add_child(_turn_log_scroll)
	_turn_log_vbox = VBoxContainer.new()
	_turn_log_vbox.add_theme_constant_override("separation", 3)
	_turn_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_log_scroll.add_child(_turn_log_vbox)
	_result_label = Label.new(); _result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _result_label.add_theme_font_size_override("font_size", 26); _result_label.visible = false
	inner.add_child(_result_label)
	var action_lbl = Label.new(); action_lbl.text = "Choose your action:"; action_lbl.add_theme_font_size_override("font_size", 13)
	inner.add_child(action_lbl)
	var btn_hbox = HBoxContainer.new(); btn_hbox.add_theme_constant_override("separation", 12)
	inner.add_child(btn_hbox)
	_action_attack = Button.new(); _action_attack.text = "ATTACK\nDeal damage"; _action_attack.custom_minimum_size = Vector2(150, 60); _action_attack.pressed.connect(_on_attack_pressed)
	btn_hbox.add_child(_action_attack)
	_action_repair = Button.new(); _action_repair.text = "REPAIR\nRestore hull"; _action_repair.custom_minimum_size = Vector2(150, 60); _action_repair.pressed.connect(_on_repair_pressed)
	btn_hbox.add_child(_action_repair)
	_action_evade = Button.new(); _action_evade.text = "EVADE\nReduce next hit"; _action_evade.custom_minimum_size = Vector2(150, 60); _action_evade.pressed.connect(_on_evade_pressed)
	btn_hbox.add_child(_action_evade)
	_continue_btn = Button.new(); _continue_btn.text = "CONTINUE"; _continue_btn.custom_minimum_size = Vector2(200, 50); _continue_btn.visible = false; _continue_btn.pressed.connect(_on_continue_pressed)
	inner.add_child(_continue_btn)
	return outer

func _build_enemy_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); panel.add_child(vbox)
	var title = Label.new(); title.text = "ENEMY SHIP"; title.add_theme_font_size_override("font_size", 15); vbox.add_child(title)
	_enemy_name_label = Label.new(); _enemy_name_label.text = "Unknown"; _enemy_name_label.add_theme_font_size_override("font_size", 12); vbox.add_child(_enemy_name_label)
	var hull_hbox = HBoxContainer.new()
	var elbl = Label.new(); elbl.text = "Hull:"; elbl.custom_minimum_size = Vector2(40, 0); hull_hbox.add_child(elbl)
	_enemy_hull_bar = ProgressBar.new(); _enemy_hull_bar.min_value = 0; _enemy_hull_bar.max_value = 100; _enemy_hull_bar.value = 100; _enemy_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hull_hbox.add_child(_enemy_hull_bar)
	_enemy_hull_label = Label.new(); _enemy_hull_label.text = "100"; _enemy_hull_label.custom_minimum_size = Vector2(34, 0); hull_hbox.add_child(_enemy_hull_label)
	vbox.add_child(hull_hbox)
	_enemy_shield_label = Label.new(); _enemy_shield_label.text = ""; _enemy_shield_label.add_theme_font_size_override("font_size", 11); vbox.add_child(_enemy_shield_label)
	return panel

func bind_combat(p_combat_engine: CombatEngine, p_game_state: GameState, p_crew: Array) -> void:
	combat_engine = p_combat_engine
	game_state = p_game_state
	crew = p_crew
	_rebuild_crew_rows()
	_update_enemy_info()
	_log_line("=== COMBAT BEGIN ===")
	_log_line("Your hull: %d  |  Enemy hull: %d" % [combat_engine.combat_state.get("player_hull", 100), combat_engine.combat_state.get("enemy_hull", 30)])

func update_display() -> void:
	if not combat_engine: return
	var state = combat_engine.combat_state
	var ph = state.get("player_hull", 100)
	_player_hull_bar.value = ph; _player_hull_label.text = str(ph)
	var eh = state.get("enemy_hull", 30)
	var eh_max = combat_engine.enemy_template.get("hull", 30)
	_enemy_hull_bar.max_value = eh_max; _enemy_hull_bar.value = eh; _enemy_hull_label.text = "%d/%d" % [eh, eh_max]
	_enemy_shield_label.text = "[ SHIELDED ]" if state.get("enemy_shielded", false) else ""
	for row in _crew_rows:
		var m = row["member"]
		row["hp_bar"].value = m.health; row["mo_bar"].value = m.morale; row["st_bar"].value = m.stress
		row["badge"].text = _get_status_badge(m); row["extras"].text = _build_extras_text(m)

func _on_attack_pressed() -> void: _do_turn("attack_weapons")
func _on_repair_pressed() -> void: _do_turn("repair")
func _on_evade_pressed() -> void:  _do_turn("evade")

func _do_turn(player_action: String) -> void:
	if not combat_engine or combat_engine.is_combat_over(): return
	_set_actions_enabled(false)
	var result = combat_engine.advance_turn(player_action)
	var player_dmg = result.get("last_player_damage", 0)
	var player_heal = result.get("last_player_heal", 0)
	var enemy_dmg = result.get("last_enemy_damage", 0)
	var enemy_act = result.get("last_enemy_action", "?")
	var p_str := ""
	if player_action == "attack_weapons": p_str = "You attacked for %d dmg" % player_dmg
	elif player_action == "repair": p_str = "You repaired %d hull" % player_heal
	elif player_action == "evade": p_str = "You evaded (next hit reduced)"
	var e_str = "%s: %d dmg to you" % [enemy_act, enemy_dmg] if enemy_dmg > 0 else enemy_act
	_log_line("Turn %d: %s | Enemy: %s" % [result.get("tick", 0), p_str, e_str])
	_log_line("  Hull: yours %d  |  enemy %d" % [result.get("player_hull", 0), result.get("enemy_hull", 0)])
	update_display()
	if combat_engine.is_combat_over(): _show_result(result.get("outcome", "ongoing"))
	else: _set_actions_enabled(true)

func _update_enemy_info() -> void:
	if not combat_engine or combat_engine.enemy_template.is_empty(): return
	var faction = combat_engine.enemy_template.get("faction", "unknown")
	var eid = combat_engine.enemy_template.get("id", "?")
	_enemy_name_label.text = "%s
[%s]" % [eid.replace("_", " ").capitalize(), faction]
	var eh = combat_engine.enemy_template.get("hull", 30)
	_enemy_hull_bar.max_value = eh; _enemy_hull_bar.value = eh; _enemy_hull_label.text = "%d/%d" % [eh, eh]

func _log_line(text: String) -> void:
	var lbl = Label.new(); lbl.text = text; lbl.add_theme_font_size_override("font_size", 11); lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_turn_log_vbox.add_child(lbl)
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(_turn_log_scroll): _turn_log_scroll.scroll_vertical = 999999)

func _show_result(outcome: String) -> void:
	_set_actions_enabled(false)
	match outcome:
		"victory": _result_label.text = "VICTORY"; _result_label.add_theme_color_override("font_color", Color.GOLD)
		"defeat":  _result_label.text = "DEFEAT";  _result_label.add_theme_color_override("font_color", Color.RED)
		_:         _result_label.text = outcome.to_upper()
	_result_label.visible = true
	_continue_btn.visible = true
	_log_line("=== COMBAT OVER: %s ===" % outcome.to_upper())

func _set_actions_enabled(enabled: bool) -> void:
	_action_attack.disabled = not enabled
	_action_repair.disabled = not enabled
	_action_evade.disabled = not enabled

func _on_continue_pressed() -> void:
	emit_signal("combat_finished", combat_engine.combat_state.get("outcome", "ongoing"))
