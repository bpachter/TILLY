extends Node2D
## SceneManager: owns TillyGame (persistent), swaps interactive UI screens.

var tilly_game: TillyGame
var _current_screen: Control = null
var _ui_layer: CanvasLayer

func _ready() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	tilly_game = TillyGame.new()
	add_child(tilly_game)
	await get_tree().process_frame
	_show_main_menu()

func _show_main_menu() -> void:
	var menu = MainMenuUI.new(tilly_game)
	menu.start_game.connect(_on_game_started)
	_swap(menu)

func _on_game_started() -> void:
	tilly_game.start_new_game()
	_show_navigation_map()

func _show_navigation_map() -> void:
	var map = NavigationMapUI.new(tilly_game)
	map.combat_requested.connect(_on_combat_requested)
	map.run_ended.connect(_on_run_ended)
	_swap(map)

func _on_combat_requested() -> void:
	var tactical = TacticalUI.new()
	tactical.bind_combat(tilly_game.combat_engine, tilly_game.game_state, tilly_game.crew)
	tactical.combat_finished.connect(_on_combat_finished)
	_swap(tactical)

func _on_combat_finished(outcome: String) -> void:
	tilly_game.check_post_combat_crew_deaths()
	var result = tilly_game.check_run_state()
	if result != "ongoing":
		_show_run_result(result)
	else:
		_show_navigation_map()

func _on_run_ended(result: String) -> void:
	_show_run_result(result)

func _show_run_result(result: String) -> void:
	var end_screen = RunResultUI.new(tilly_game, result)
	end_screen.play_again.connect(_on_play_again)
	_swap(end_screen)

func _on_play_again() -> void:
	tilly_game.initialize()
	_show_main_menu()

func _swap(new_screen: Control) -> void:
	if _current_screen and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = new_screen
	_ui_layer.add_child(new_screen)
