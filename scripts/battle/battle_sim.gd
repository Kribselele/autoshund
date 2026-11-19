class_name BattleSim
extends RefCounted
## Deterministic auto-battle between two packs.
## Pure logic with no visuals, so it can run headless for tests and balancing.
##
## Rules (see the design plan, "Battle rules"):
## - Each side has 2 rows (0 = front, 1 = back) and 4 lanes.
## - A dog attacks the frontmost enemy in its own lane, else the closest lane.
## - A back-row dog can only be hit once the front dog of its lane is gone.
## - A long teckel spans several lanes: it hits the frontmost enemy of every lane it covers,
##   and enemies in any of those lanes can hit it.
## - All attacks ready in the same tick land at the same time, so neither side moves first.
## - After 40 s both sides get Tired and lose Fluff every second.

const LANES := 4
const ROWS := 2
const TICK := 0.1
const TIRED_AT := 40.0
const TIRED_RATIO_PER_SECOND := 0.05
const MAX_TIME := 90.0
## Treat Bowl points lost by the loser: this base plus 1 per enemy dog still standing.
const LOSS_BASE_DAMAGE := 2

const DRAW := -1

var units: Array = []
var time: float = 0.0
var finished: bool = false
var winner: int = DRAW
## Log of hits for the viewer: {"time", "attacker", "target", "damage"}.
var events: Array = []
var _started := false


## Places a dog. Returns the unit, or null if the cells are taken or off the board.
func add_dog(breed_id: String, side: int, row: int, lane: int, level: int = 1) -> BattleUnit:
	var unit := BattleUnit.new(BreedDB.get_breed(breed_id), side, row, lane, level)
	if not can_place(unit):
		return null
	units.append(unit)
	return unit


func can_place(unit: BattleUnit) -> bool:
	if unit.row < 0 or unit.row >= ROWS:
		return false
	if unit.lane < 0 or unit.lane + unit.length > LANES:
		return false
	for other in units:
		if other.side != unit.side or other.row != unit.row:
			continue
		for l in unit.lanes():
			if other.covers_lane(l):
				return false
	return true


func side_units(side: int, alive_only: bool = true) -> Array:
	return units.filter(func(u): return u.side == side and (not alive_only or u.is_alive()))


## Applies synergies once, before the first tick.
func start() -> void:
	if _started:
		return
	_started = true
	Synergies.apply(side_units(0, false))
	Synergies.apply(side_units(1, false))
	_check_end()


func step() -> void:
	if not _started:
		start()
	if finished:
		return
	time += TICK

	# Gather every attack that is ready this tick, then resolve them together.
	var attacks := []
	for unit in units:
		if not unit.is_alive():
			continue
		unit.cooldown -= TICK
		if unit.cooldown <= 0.0:
			unit.cooldown += 1.0 / unit.current_pace()
			var targets := targets_for(unit)
			if not targets.is_empty():
				attacks.append([unit, targets])
	for attack in attacks:
		var attacker: BattleUnit = attack[0]
		for target in attack[1]:
			var dealt: float = target.take_damage(attacker.bite)
			events.append({"time": time, "attacker": attacker, "target": target, "damage": dealt})

	if time >= TIRED_AT:
		for unit in units:
			if unit.is_alive():
				unit.take_damage(unit.max_fluff * TIRED_RATIO_PER_SECOND * TICK)

	_check_end()


func run_to_end() -> Dictionary:
	start()
	while not finished:
		step()
	return result()


func result() -> Dictionary:
	var survivors := 0
	if winner != DRAW:
		survivors = side_units(winner).size()
	return {
		"winner": winner,
		"time": snappedf(time, 0.1),
		"survivors": survivors,
		"loser_damage": LOSS_BASE_DAMAGE + survivors if winner != DRAW else 0,
	}


## Enemies this unit would hit right now.
func targets_for(unit: BattleUnit) -> Array:
	var enemies := side_units(1 - unit.side)
	if enemies.is_empty():
		return []
	if unit.length > 1:
		var hits := []
		for l in unit.lanes():
			var target = frontmost_in_lane(enemies, l)
			if target != null and not hits.has(target):
				hits.append(target)
		if not hits.is_empty():
			return hits
	# Own lane first, then the closest lanes, lower lane first on a tie.
	for distance in range(LANES):
		for l in [unit.lane - distance, unit.lane + unit.length - 1 + distance]:
			if l < 0 or l >= LANES:
				continue
			var target = frontmost_in_lane(enemies, l)
			if target != null:
				return [target]
	return []


func frontmost_in_lane(enemies: Array, l: int) -> BattleUnit:
	var best: BattleUnit = null
	for enemy in enemies:
		if enemy.covers_lane(l) and (best == null or enemy.row < best.row):
			best = enemy
	return best


func _check_end() -> void:
	var alive0 := side_units(0).size()
	var alive1 := side_units(1).size()
	if alive0 == 0 or alive1 == 0:
		finished = true
		if alive0 > 0:
			winner = 0
		elif alive1 > 0:
			winner = 1
		else:
			winner = DRAW
	elif time >= MAX_TIME:
		finished = true
		winner = DRAW
