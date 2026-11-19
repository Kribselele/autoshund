extends SceneTree
## Headless tests for the shop, Pack Level, merging and the season.
## Run: godot --headless --import && godot --headless -s tests/test_game.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	test_pack_level_and_xp()
	test_shop_odds_respect_level()
	test_buying_and_pool()
	test_three_copies_merge()
	test_merged_teckel_grows_on_board()
	test_board_limit()
	test_selling()
	test_bury_a_bone()
	test_streak_income()
	test_season_plays_to_the_end()
	test_season_is_deterministic()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _new_pack(kibble: int = 50) -> Pack:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pack := Pack.new("Test", SharedPool.new(), rng)
	pack.kibble = kibble
	return pack


func test_pack_level_and_xp() -> void:
	var pack := _new_pack(8)
	check(pack.level == 1 and pack.xp_to_next() == 2, "a pack starts at level 1, 2 XP from level 2")
	pack.buy_xp()
	check(pack.level == 2 and pack.xp == 4 and pack.kibble == 4, "4 kibble buys 4 XP and reaches level 2")
	pack.gain_xp(76)
	check(pack.level == 8 and pack.xp_to_next() == 0, "80 XP reaches the top level, 8")
	check(not pack.buy_xp(), "no XP can be bought at the top level")


func test_shop_odds_respect_level() -> void:
	var pack := _new_pack()
	var highest := 0
	for i in 40:
		pack.roll_shop()
		for id in pack.shop:
			highest = maxi(highest, BreedDB.get_breed(id)["tier"])
	check(highest == 1, "a level 1 shop only offers tier 1 dogs")


func test_buying_and_pool() -> void:
	var pack := _new_pack(10)
	pack.shop = ["teckel", "", "", "", ""]
	var before: int = pack._pool.counts["teckel"]
	check(pack.buy(0), "buying a shop dog works")
	check(pack.kibble == 9 and pack.dogs.size() == 1, "the dog costs its tier and lands on the bench")
	check(pack._pool.counts["teckel"] == before - 1, "the copy leaves the shared kennel")
	check(pack.shop[0] == "", "the shop slot empties")


func test_three_copies_merge() -> void:
	var pack := _new_pack()
	for i in 3:
		pack.shop = ["beagle", "", "", "", ""]
		pack.buy(0)
	check(pack.dogs.size() == 1 and pack.dogs[0].level == 2, "3 copies merge into one level 2 dog")


func test_merged_teckel_grows_on_board() -> void:
	var pack := _new_pack()
	pack.level = 3
	pack.shop = ["teckel", "", "", "", ""]
	pack.buy(0)
	pack.place(pack.dogs[0], 0, 3)
	for i in 2:
		pack.shop = ["teckel", "", "", "", ""]
		pack.buy(0)
	var teckel: PackDog = pack.dogs[0]
	check(pack.dogs.size() == 1 and teckel.level == 2 and teckel.length() == 2, "the merged teckel is level 2 and 2 lanes long")
	check(teckel.on_board() and teckel.lane + teckel.length() <= BattleSim.LANES, "it stays on the board and moves to where it fits")


func test_board_limit() -> void:
	var pack := _new_pack()
	pack.shop = ["beagle", "carlin", "", "", ""]
	pack.buy(0)
	pack.buy(1)
	check(pack.place(pack.dogs[0], 0, 0), "a level 1 pack can field 1 dog")
	check(not pack.place(pack.dogs[1], 0, 1), "a level 1 pack cannot field a 2nd dog")


func test_selling() -> void:
	var pack := _new_pack(10)
	pack.shop = ["basset_hound", "", "", "", ""]
	pack.buy(0)
	var before: int = pack._pool.counts["basset_hound"]
	pack.sell(pack.dogs[0])
	check(pack.kibble == 9 and pack.dogs.is_empty(), "a tier 2 dog sells for 1 kibble")
	check(pack._pool.counts["basset_hound"] == before + 1, "the sold copy goes back to the kennel")


func test_bury_a_bone() -> void:
	var pack := _new_pack(10)
	check(pack.bury(4, 1), "4 kibble can be buried")
	check(not pack.bury(2, 1), "no more than 5 kibble can be buried at once")
	pack.collect_income(2)
	check(pack.kibble == 11, "the bone is still underground after 1 round")
	pack.collect_income(3)
	check(pack.kibble == 22, "after 2 rounds it comes back with +50%")


func test_streak_income() -> void:
	var pack := _new_pack(0)
	pack.record_result(false, 3)
	pack.record_result(false, 3)
	check(pack.streak == -2 and pack.treat_bowl == 14, "losses build a streak and cost Treat Bowl points")
	pack.collect_income(1)
	check(pack.kibble == 6, "a 2-round streak adds 1 kibble to the base 5")


func test_season_plays_to_the_end() -> void:
	var season := Season.new(42)
	var rounds := 0
	while not season.is_over() and rounds < 60:
		season.start_round()
		Bot.play_turn(season.player(), season.round_number)  # let a bot play for the human
		season.play_fights()
		rounds += 1
	check(season.is_over(), "a season ends with a winner or the player knocked out")
	check(season.player_place() >= 1 and season.player_place() <= 8, "the player gets a place from 1 to 8")


func test_season_is_deterministic() -> void:
	check(_season_summary(5) == _season_summary(5), "the same seed plays the same season")


func _season_summary(seed_value: int) -> Array:
	var season := Season.new(seed_value)
	for i in 5:
		season.start_round()
		Bot.play_turn(season.player(), season.round_number)
		season.play_fights()
	return season.packs.map(func(p): return p.treat_bowl)
