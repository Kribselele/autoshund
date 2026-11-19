class_name Season
extends RefCounted
## A season: a league of 8 packs, you and 7 AI rival kennels, until one pack is left.
## Each round: income and a fresh shop, everyone builds, then the packs fight in pairs.

const RIVALS := [
	{"name": "Sausage Squad", "favourites": ["Saucisse", "Hounds"]},
	{"name": "Barkingham Palace", "favourites": ["Toys", "Soigneur"]},
	{"name": "Gardiens du Parc", "favourites": ["Gardien", "Working"]},
	{"name": "Bagarre Club", "favourites": ["Bagarreur", "Terriers"]},
	{"name": "Les Bergers", "favourites": ["Herders", "Aboyeur"]},
	{"name": "Flair & Truffe", "favourites": ["Pisteur", "Sporting"]},
	{"name": "Les Plongeurs", "favourites": ["Plongeur", "Hounds"]},
]

var rng := RandomNumberGenerator.new()
var pool: SharedPool
var packs: Array = []
var round_number := 0
## This round's fights: [{"a": Pack, "b": Pack, "result": Dictionary}].
var fights: Array = []


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	pool = SharedPool.new()
	var you := Pack.new("Your pack", pool, rng)
	you.is_human = true
	packs.append(you)
	for rival in RIVALS:
		var pack := Pack.new(rival["name"], pool, rng)
		pack.favourites = rival["favourites"]
		packs.append(pack)


func player() -> Pack:
	return packs[0]


func alive_packs() -> Array:
	return packs.filter(func(p): return p.is_alive())


func is_over() -> bool:
	return not player().is_alive() or alive_packs().size() <= 1


## Starts a round: income, free XP, a fresh shop, and the rivals' turns.
func start_round() -> void:
	round_number += 1
	for pack in alive_packs():
		pack.collect_income(round_number)
		if round_number > 1:
			pack.gain_xp(Economy.FREE_XP_PER_ROUND)
		pack.roll_shop()
	for pack in alive_packs():
		if not pack.is_human:
			Bot.play_turn(pack, round_number)


## Pairs the packs and resolves every fight. The player's fight is first in `fights`.
func play_fights() -> void:
	fights.clear()
	var others := alive_packs().filter(func(p): return not p.is_human)
	_shuffle(others)
	var order := []
	if player().is_alive():
		order.append(player())
	order.append_array(others)
	# With an odd count, the last pack has a bye this round.
	for i in range(0, order.size() - 1, 2):
		var a: Pack = order[i]
		var b: Pack = order[i + 1]
		var result := build_fight(a, b).run_to_end()
		_apply(a, b, result)
		fights.append({"a": a, "b": b, "result": result})
	for pack in packs:
		if not pack.is_alive() and pack.eliminated_round == 0:
			pack.eliminated_round = round_number


## A fresh battle between two packs (pack a is side 0). Deterministic, so it can be replayed.
func build_fight(a: Pack, b: Pack) -> BattleSim:
	var sim := BattleSim.new()
	a.add_to_battle(sim, 0)
	b.add_to_battle(sim, 1)
	return sim


## Standings: alive packs by Treat Bowl, then knocked-out packs, last out at the bottom.
func standings() -> Array:
	var list := packs.duplicate()
	list.sort_custom(func(x, y):
		if x.is_alive() != y.is_alive():
			return x.is_alive()
		if x.is_alive():
			return x.treat_bowl > y.treat_bowl
		return x.eliminated_round > y.eliminated_round)
	return list


func player_place() -> int:
	return standings().find(player()) + 1


## Treat Bowl points the loser of a fight loses: grows with the round, plus 1 per dog left standing.
func loss_damage(result: Dictionary) -> int:
	return 1 + round_number / 4 + result["survivors"] / 2


func _apply(a: Pack, b: Pack, result: Dictionary) -> void:
	var damage := loss_damage(result)
	match result["winner"]:
		0:
			a.record_result(true, 0)
			b.record_result(false, damage)
		1:
			b.record_result(true, 0)
			a.record_result(false, damage)
		_:
			a.treat_bowl = maxi(0, a.treat_bowl - 1)
			b.treat_bowl = maxi(0, b.treat_bowl - 1)


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
