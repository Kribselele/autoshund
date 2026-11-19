extends SceneTree
## Headless tests for the battle rules.
## Run: godot --headless --import && godot --headless -s tests/test_battle.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	test_breeds_load()
	test_long_teckel_takes_lanes()
	test_long_teckel_hits_every_lane()
	test_back_row_is_protected()
	test_closest_lane_fallback()
	test_synergy_counts()
	test_synergy_effects()
	test_battle_is_deterministic()
	test_battle_always_ends()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func test_breeds_load() -> void:
	check(BreedDB.ids().size() == 35, "35 breeds load from data/breeds.json")
	check(BreedDB.get_breed("berger_belge_malinois")["tier"] == 4, "Malinois is tier 4")


func test_long_teckel_takes_lanes() -> void:
	var sim := BattleSim.new()
	var teckel := sim.add_dog("teckel", 0, 0, 1, 2)
	check(teckel != null and teckel.length == 2, "a level 2 teckel spans 2 lanes")
	check(sim.add_dog("beagle", 0, 0, 2) == null, "no dog can stand on a lane the teckel covers")
	check(sim.add_dog("beagle", 0, 1, 2) != null, "the back row behind the teckel stays free")
	check(sim.add_dog("teckel", 0, 0, 3, 3) == null, "a level 3 teckel cannot hang off the board")


func test_long_teckel_hits_every_lane() -> void:
	var sim := BattleSim.new()
	var teckel := sim.add_dog("teckel", 0, 0, 0, 3)
	var a := sim.add_dog("chihuahua", 1, 0, 0)
	var b := sim.add_dog("chihuahua", 1, 0, 2)
	sim.add_dog("chihuahua", 1, 0, 3)
	var targets := sim.targets_for(teckel)
	check(targets.size() == 2 and targets.has(a) and targets.has(b), "a level 3 teckel hits the front dog of lanes 0, 1 and 2")


func test_back_row_is_protected() -> void:
	var sim := BattleSim.new()
	var jack := sim.add_dog("jack_russell", 0, 0, 1)
	var front := sim.add_dog("basset_hound", 1, 0, 1)
	sim.add_dog("carlin", 1, 1, 1)
	check(sim.targets_for(jack) == [front], "the front dog shields the back dog of its lane")


func test_closest_lane_fallback() -> void:
	var sim := BattleSim.new()
	var jack := sim.add_dog("jack_russell", 0, 0, 0)
	var far := sim.add_dog("carlin", 1, 1, 3)
	check(sim.targets_for(jack) == [far], "with its lane empty, a dog goes for the closest lane")


func test_synergy_counts() -> void:
	var sim := BattleSim.new()
	sim.add_dog("teckel", 0, 0, 0)
	sim.add_dog("teckel_a_poil_dur", 0, 0, 1)
	sim.add_dog("teckel", 0, 1, 0)
	var counts := Synergies.count(sim.side_units(0))
	check(counts["Hounds"] == 4, "two teckel breeds count as 4 Hounds; a copy does not count again")
	check(counts["Saucisse"] == 2, "two teckel breeds give 2 Saucisse")
	check(Synergies.level_reached("Hounds", 4) == 2, "4 Hounds reach the second step")


func test_synergy_effects() -> void:
	var sim := BattleSim.new()
	var malinois := sim.add_dog("berger_belge_malinois", 0, 0, 0)
	sim.add_dog("jack_russell", 0, 0, 1)
	var base_bite := malinois.bite
	sim.add_dog("chihuahua", 1, 0, 0)
	sim.start()
	check(is_equal_approx(malinois.bite, base_bite * 1.2), "2 Bagarreurs give Bagarreurs +20% Bite")


func test_battle_is_deterministic() -> void:
	check(_sample_battle().run_to_end() == _sample_battle().run_to_end(), "the same packs always give the same result")


func test_battle_always_ends() -> void:
	var sim := _sample_battle()
	var result := sim.run_to_end()
	check(sim.finished and result["time"] <= BattleSim.MAX_TIME, "a battle ends within the time limit")


func _sample_battle() -> BattleSim:
	var sim := BattleSim.new()
	sim.add_dog("teckel", 0, 0, 0, 2)
	sim.add_dog("jack_russell", 0, 0, 2)
	sim.add_dog("basset_hound", 0, 0, 3)
	sim.add_dog("beagle", 0, 1, 1)
	sim.add_dog("welsh_corgi", 1, 0, 0)
	sim.add_dog("scottish_terrier", 1, 0, 1)
	sim.add_dog("chihuahua", 1, 0, 2)
	sim.add_dog("carlin", 1, 1, 2)
	return sim
