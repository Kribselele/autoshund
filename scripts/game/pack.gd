class_name Pack
extends RefCounted
## One player's pack in a season: kibble, Pack Level, Treat Bowl, dogs and shop.
## Used for the human player and for the AI rival kennels alike.

var name: String
var is_human := false
## Traits an AI rival prefers to buy; empty for the human.
var favourites: Array = []

var kibble := 0
var xp := 0
var level := 1
var treat_bowl := Economy.START_TREAT_BOWL
## Positive for a win streak, negative for a loss streak.
var streak := 0
var dogs: Array = []
var shop: Array = []
## Buried bones: [{"amount": int, "due_round": int}].
var bones: Array = []
var eliminated_round := 0

var _pool: SharedPool
var _rng: RandomNumberGenerator


func _init(p_name: String, pool: SharedPool, rng: RandomNumberGenerator) -> void:
	name = p_name
	_pool = pool
	_rng = rng
	shop.resize(Economy.SHOP_SIZE)
	shop.fill("")


func is_alive() -> bool:
	return treat_bowl > 0


# --- Dogs -------------------------------------------------------------------

func bench() -> Array:
	return dogs.filter(func(d): return not d.on_board())


func board() -> Array:
	return dogs.filter(func(d): return d.on_board())


func board_limit() -> int:
	return level


func bench_full() -> bool:
	return bench().size() >= Economy.BENCH_SIZE


## True if the dog fits at row/lane, ignoring the dog itself.
func fits(dog: PackDog, row: int, lane: int) -> bool:
	if row < 0 or row >= BattleSim.ROWS or lane < 0 or lane + dog.length() > BattleSim.LANES:
		return false
	for other in board():
		if other == dog or other.row != row:
			continue
		for l in range(lane, lane + dog.length()):
			if l >= other.lane and l < other.lane + other.length():
				return false
	return true


## Puts a dog on the board. Fails if the cells are taken or the board is full.
func place(dog: PackDog, row: int, lane: int) -> bool:
	if not fits(dog, row, lane):
		return false
	if not dog.on_board() and board().size() >= board_limit():
		return false
	dog.row = row
	dog.lane = lane
	return true


func to_bench(dog: PackDog) -> bool:
	if not dog.on_board():
		return true
	if bench_full():
		return false
	dog.row = -1
	dog.lane = -1
	return true


## Dog covering a board cell, or null.
func dog_at(row: int, lane: int) -> PackDog:
	for dog in board():
		if dog.row == row and lane >= dog.lane and lane < dog.lane + dog.length():
			return dog
	return null


# --- Shop -------------------------------------------------------------------

func roll_shop() -> void:
	var odds: Array = Economy.SHOP_ODDS[level - 1]
	for i in Economy.SHOP_SIZE:
		var roll := _rng.randi_range(1, 100)
		var tier := 1
		var acc := 0
		for t in odds.size():
			acc += odds[t]
			if roll <= acc:
				tier = t + 1
				break
		var id := _pool.draw(tier, _rng)
		if id == "":
			id = _pool.draw(1, _rng)
		shop[i] = id


func reroll() -> bool:
	if kibble < Economy.REROLL_PRICE:
		return false
	kibble -= Economy.REROLL_PRICE
	roll_shop()
	return true


## Buys the dog in a shop slot. Merges 3 copies into the next level.
func buy(slot: int) -> bool:
	var id: String = shop[slot]
	if id == "":
		return false
	var cost: int = BreedDB.get_breed(id)["tier"]
	if kibble < cost:
		return false
	# A full bench still accepts a dog that completes a merge.
	if bench_full() and _count_copies(id, 1) < 2:
		return false
	if not _pool.take(id):
		return false
	kibble -= cost
	shop[slot] = ""
	dogs.append(PackDog.new(id))
	_merge(id, 1)
	return true


func sell(dog: PackDog) -> void:
	kibble += Economy.sell_value(dog.tier(), dog.level)
	_pool.give_back(dog.breed_id, Economy.copies_for_level(dog.level))
	dogs.erase(dog)


func buy_xp() -> bool:
	if kibble < Economy.XP_PRICE or level >= Economy.MAX_LEVEL:
		return false
	kibble -= Economy.XP_PRICE
	gain_xp(Economy.XP_PER_PURCHASE)
	return true


func gain_xp(amount: int) -> void:
	xp += amount
	while level < Economy.MAX_LEVEL and xp >= Economy.XP_TO_REACH[level]:
		level += 1


## XP still missing for the next Pack Level, or 0 at the top.
func xp_to_next() -> int:
	if level >= Economy.MAX_LEVEL:
		return 0
	return Economy.XP_TO_REACH[level] - xp


func bury(amount: int, current_round: int) -> bool:
	if amount <= 0 or amount > kibble or buried_total() + amount > Economy.BURY_MAX:
		return false
	kibble -= amount
	bones.append({"amount": amount, "due_round": current_round + Economy.BURY_ROUNDS})
	return true


func buried_total() -> int:
	var total := 0
	for bone in bones:
		total += bone["amount"]
	return total


## Start-of-round income: base, streak bonus and bones that are ready.
func collect_income(current_round: int) -> int:
	var income := Economy.BASE_INCOME + Economy.streak_bonus(streak)
	for bone in bones.duplicate():
		if bone["due_round"] <= current_round:
			income += int(floor(bone["amount"] * Economy.BURY_RETURN))
			bones.erase(bone)
	kibble += income
	return income


func record_result(won: bool, damage: int) -> void:
	if won:
		streak = streak + 1 if streak > 0 else 1
	else:
		streak = streak - 1 if streak < 0 else -1
		treat_bowl = maxi(0, treat_bowl - damage)


## Adds this pack's board to a battle on the given side.
func add_to_battle(sim: BattleSim, side: int) -> void:
	for dog in board():
		sim.add_dog(dog.breed_id, side, dog.row, dog.lane, dog.level)


# --- Merging ----------------------------------------------------------------

func _count_copies(id: String, at_level: int) -> int:
	return dogs.filter(func(d): return d.breed_id == id and d.level == at_level).size()


func _merge(id: String, at_level: int) -> void:
	if at_level >= 3:
		return
	var same := dogs.filter(func(d): return d.breed_id == id and d.level == at_level)
	if same.size() < 3:
		return
	# Keep the copy that stands on the board, if any, so the dog stays in place.
	same.sort_custom(func(a, b): return a.on_board() and not b.on_board())
	var keeper: PackDog = same[0]
	for i in range(1, 3):
		dogs.erase(same[i])
	keeper.level = at_level + 1
	# A teckel grows longer: find room for it, or send it to the bench.
	if keeper.on_board() and not fits(keeper, keeper.row, keeper.lane):
		var moved := false
		for row in BattleSim.ROWS:
			for lane in BattleSim.LANES:
				if fits(keeper, row, lane):
					keeper.row = row
					keeper.lane = lane
					moved = true
					break
			if moved:
				break
		if not moved:
			keeper.row = -1
			keeper.lane = -1
	_merge(id, at_level + 1)
