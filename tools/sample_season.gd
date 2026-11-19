extends SceneTree
## Plays a whole season with a bot standing in for the player and prints the standings.
## Run: godot --headless -s tools/sample_season.gd

func _init() -> void:
	var season := Season.new(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1)
	while season.alive_packs().size() > 1 and season.round_number < 60:
		season.start_round()
		Bot.play_turn(season.player(), season.round_number)
		season.play_fights()
	print("Season over after %d rounds, player out in round %d" % [season.round_number, season.player().eliminated_round])
	for pack in season.standings():
		var synergies := Synergies.active(pack.board().map(func(d): return BattleUnit.new(d.breed(), 0, 0, 0, d.level)))
		print("%-18s bowl %2d  level %d  board %s  %s" % [pack.name, pack.treat_bowl, pack.level,
			pack.board().map(func(d): return "%s*%d" % [d.breed_id, d.level]), synergies])
	quit()
