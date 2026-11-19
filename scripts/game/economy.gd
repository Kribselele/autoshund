class_name Economy
extends RefCounted
## Economy numbers from the design plan ("Economy" and "Pack Level and tiers").
## Starting values to tune with the balance sheet.

const BASE_INCOME := 5
const FREE_XP_PER_ROUND := 2
const XP_PRICE := 4
const XP_PER_PURCHASE := 4
const REROLL_PRICE := 1
const SHOP_SIZE := 5
const BENCH_SIZE := 8
const MAX_LEVEL := 8
const START_TREAT_BOWL := 20

## Total XP needed to reach each Pack Level (index 0 = level 1).
const XP_TO_REACH := [0, 2, 6, 10, 20, 36, 56, 80]

## Shop odds in percent for tiers 1..5, per Pack Level (index 0 = level 1).
const SHOP_ODDS := [
	[100, 0, 0, 0, 0],
	[100, 0, 0, 0, 0],
	[75, 25, 0, 0, 0],
	[55, 30, 15, 0, 0],
	[40, 33, 22, 5, 0],
	[25, 35, 30, 9, 1],
	[19, 30, 35, 14, 2],
	[15, 20, 35, 25, 5],
]

## Copies of each breed in the shared kennel, by tier (index 0 = tier 1).
const POOL_COPIES := [18, 15, 12, 10, 8]

## Bury a bone: up to this much kibble, back with +50% after 2 rounds.
const BURY_MAX := 5
const BURY_ROUNDS := 2
const BURY_RETURN := 1.5


## Extra kibble for a win or loss streak of 2-3, 4-5 or 6+ rounds.
static func streak_bonus(streak: int) -> int:
	var length := absi(streak)
	if length >= 6:
		return 3
	if length >= 4:
		return 2
	if length >= 2:
		return 1
	return 0


## Number of copies a dog of this level is made of.
static func copies_for_level(level: int) -> int:
	return int(pow(3, level - 1))


## Kibble back when selling: the copies' cost minus 1, at least 1.
static func sell_value(tier: int, level: int) -> int:
	return maxi(1, tier * copies_for_level(level) - 1)
