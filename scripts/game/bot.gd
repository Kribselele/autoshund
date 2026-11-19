class_name Bot
extends RefCounted
## Plays a shop phase for an AI rival kennel.
## Simple on purpose: level on a schedule, buy favourites and pairs, then fill the board.

## Pack Level the bot aims for, by round.
const LEVEL_PLAN := [1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 7, 8]
const FRONT_JOBS := ["Gardien", "Saucisse", "Bagarreur"]


static func play_turn(pack: Pack, round_number: int) -> void:
	var target_level: int = LEVEL_PLAN[mini(round_number, LEVEL_PLAN.size()) - 1]
	while pack.level < target_level and pack.buy_xp():
		pass
	# Buy what we want; reroll once or twice when rich.
	var rerolls := 2 if pack.kibble >= 10 else 0
	while true:
		_buy_wanted(pack)
		if rerolls > 0 and pack.kibble > 6:
			rerolls -= 1
			pack.reroll()
		else:
			break
	# Bury spare kibble now and then.
	if pack.kibble >= 3 and pack.buried_total() == 0 and round_number % 3 == 0:
		pack.bury(mini(pack.kibble - 1, Economy.BURY_MAX), round_number)
	_sell_extra_bench(pack)
	arrange_board(pack)


static func _buy_wanted(pack: Pack) -> void:
	for slot in Economy.SHOP_SIZE:
		var id: String = pack.shop[slot]
		if id == "":
			continue
		var breed := BreedDB.get_breed(id)
		var owned := pack.dogs.filter(func(d): return d.breed_id == id).size()
		var liked := false
		for t in breed["groups"] + breed["jobs"]:
			if t in pack.favourites:
				liked = true
		var room := pack.dogs.size() < pack.board_limit() + 2
		if liked or owned > 0 or room:
			pack.buy(slot)


static func _sell_extra_bench(pack: Pack) -> void:
	while pack.bench().size() > 4:
		var weakest: PackDog = null
		for dog in pack.bench():
			if weakest == null or dog.tier() * dog.level < weakest.tier() * weakest.level:
				weakest = dog
		pack.sell(weakest)


## Puts the strongest dogs on the board: tanks and long teckels in front.
static func arrange_board(pack: Pack) -> void:
	for dog in pack.board():
		dog.row = -1
		dog.lane = -1
	var ranked := pack.dogs.duplicate()
	ranked.sort_custom(func(a, b): return a.tier() * a.level * 10 + a.length() > b.tier() * b.level * 10 + b.length())
	var chosen := ranked.slice(0, pack.board_limit())
	var front := chosen.filter(func(d): return _is_front(d))
	var back := chosen.filter(func(d): return not _is_front(d))
	for dog in front + back:
		var preferred := 0 if dog in front else 1
		if not _place_first_free(pack, dog, preferred):
			_place_first_free(pack, dog, 1 - preferred)


static func _is_front(dog: PackDog) -> bool:
	for job in dog.breed()["jobs"]:
		if job in FRONT_JOBS:
			return true
	return false


static func _place_first_free(pack: Pack, dog: PackDog, row: int) -> bool:
	for lane in BattleSim.LANES:
		if pack.place(dog, row, lane):
			return true
	return false
