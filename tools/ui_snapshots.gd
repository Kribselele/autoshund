extends SceneTree
## Drives the game screen and saves screenshots, to check the UI without clicking.
## Run with a display: godot -s tools/ui_snapshots.gd -- <output_dir>

var game: Node
var out_dir := "user://"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	var pack: Pack = game.season.player()
	pack.kibble = 30
	pack.gain_xp(6)
	pack.shop = ["teckel", "teckel", "teckel", "beagle", "carlin"]
	for i in 5:
		pack.buy(i)
	pack.place(pack.dogs[0], 0, 0)
	pack.place(pack.dogs[1], 1, 0)
	game.selected = pack.dogs[2]
	pack.roll_shop()
	await _frames(5)
	_save("shop.png")
	game._fight()
	game._battle_view.speed = 4.0
	await _frames(90)
	_save("battle.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(file_name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name))
	print("saved ", file_name)
