class_name BattleUnit
extends RefCounted
## One dog on the battle board.
## The board is 2 rows (0 = front, 1 = back) by 4 lanes per side.
## A long dog (teckel) spans `length` lanes of its row, starting at `lane`.

## Stat multiplier for level 1, 2 and 3 (3 copies merge into the next level).
const LEVEL_MULT := [1.0, 1.8, 3.2]

var breed: Dictionary
var side: int
var row: int
var lane: int
var level: int
var length: int = 1

var max_fluff: float
var fluff: float
var shield: float = 0.0
var bite: float
var pace: float
## Extra Pace (as a ratio) granted while under half Fluff, e.g. by the Terriers synergy.
var low_fluff_pace_bonus: float = 0.0
var cooldown: float


func _init(p_breed: Dictionary, p_side: int, p_row: int, p_lane: int, p_level: int = 1) -> void:
	breed = p_breed
	side = p_side
	row = p_row
	lane = p_lane
	level = clampi(p_level, 1, 3)
	if breed.get("long", false):
		length = level
	var mult: float = LEVEL_MULT[level - 1]
	max_fluff = breed["fluff"] * mult
	fluff = max_fluff
	bite = breed["bite"] * mult
	pace = breed["pace"]
	cooldown = 1.0 / pace


func id() -> String:
	return breed["id"]


func display_name() -> String:
	return breed["name"]


func is_alive() -> bool:
	return fluff > 0.0


func lanes() -> Array:
	return range(lane, lane + length)


func covers_lane(l: int) -> bool:
	return l >= lane and l < lane + length


func current_pace() -> float:
	if low_fluff_pace_bonus > 0.0 and fluff < max_fluff * 0.5:
		return pace * (1.0 + low_fluff_pace_bonus)
	return pace


## Applies damage, shield first. Returns the damage actually taken by shield + Fluff.
func take_damage(amount: float) -> float:
	var taken := 0.0
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		taken += absorbed
	var hit := minf(fluff, amount)
	fluff -= hit
	return taken + hit


func has_trait(trait_name: String) -> bool:
	return trait_name in breed["groups"] or trait_name in breed["jobs"]
