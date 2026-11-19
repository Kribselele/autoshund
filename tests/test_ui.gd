extends SceneTree
## Clicks through the game screen: buy, place, bench, sell, fight, continue.
## Run: godot --headless --import && godot --headless -s tests/test_ui.gd

var _failures := 0
var _checks := 0
var game: Node


func _init() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func click(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	game._unhandled_input(event)


func _run() -> void:
	await process_frame
	var pack: Pack = game.season.player()
	pack.shop = ["beagle", "carlin", "", "", ""]
	var kibble: int = pack.kibble
	click(game._shop_rect(0).get_center())
	check(pack.dogs.size() == 1 and pack.kibble == kibble - 1, "clicking a shop card buys the dog")

	click(game._bench_rect(0).get_center())
	check(game.selected == pack.dogs[0], "clicking a bench dog selects it")
	click(game._cell_rect(0, 2).get_center())
	check(pack.dogs[0].on_board() and pack.dogs[0].lane == 2, "clicking an empty cell places the selected dog")

	click(game._shop_rect(1).get_center())
	click(game._bench_rect(0).get_center())
	click(game._cell_rect(1, 0).get_center())
	check(not pack.dogs[1].on_board() and game.message.contains("full"), "a level 1 board refuses a 2nd dog and says why")

	click(game._cell_rect(0, 2).get_center())
	click(game._bench_rect(5).get_center())
	check(not pack.dogs[0].on_board(), "a board dog goes back to an empty bench slot")

	game.selected = pack.dogs[1]
	game._sell_selected()
	check(pack.dogs.size() == 1, "Sell removes the selected dog")

	pack.place(pack.dogs[0], 0, 0)
	var round_before: int = game.season.round_number
	game._fight()
	check(game._battle_view.visible, "Fight! opens the battle")
	game._battle_view._skip()
	game._after_battle()
	check(game.season.round_number == round_before + 1 or game.season.is_over(), "Continue starts the next round")

	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
