class_name Synergies
extends RefCounted
## Counts group and job synergies for one side and applies their battle-start effects.
## A synergy counts distinct breeds, so copies of the same dog count once.
## Each teckel breed counts as 2 Hounds.

const THRESHOLDS := {
	"Hounds": [2, 4, 6],
	"Terriers": [2, 4, 6],
	"Herders": [2, 4, 6],
	"Toys": [2, 4, 6],
	"Sporting": [2, 4, 6],
	"Working": [2, 4, 6],
	"Saucisse": [2, 3],
	"Gardien": [2, 4],
	"Bagarreur": [2, 4],
	"Pisteur": [2, 4],
	"Plongeur": [2, 4],
	"Aboyeur": [2, 4],
	"Soigneur": [2, 4],
}

## Bonus per reached step. Synergies not listed here are counted but have no effect yet.
const TERRIERS_PACE := [0.2, 0.4, 0.7]
const WORKING_FLUFF := [0.2, 0.4, 0.7]
const SAUCISSE_FLUFF_PER_LANE := [0.10, 0.25]
const GARDIEN_SHIELD := [0.10, 0.25]
const BAGARREUR_BITE := [0.20, 0.45]


## Returns {trait_name: count} for the given units.
static func count(units: Array) -> Dictionary:
	var seen := {}
	var counts := {}
	for unit in units:
		var breed: Dictionary = unit.breed
		if seen.has(breed["id"]):
			continue
		seen[breed["id"]] = true
		for group in breed["groups"]:
			var amount := 2 if (group == "Hounds" and breed.get("long", false)) else 1
			counts[group] = counts.get(group, 0) + amount
		for job in breed["jobs"]:
			counts[job] = counts.get(job, 0) + 1
	return counts


## Returns how many steps of a synergy are active (0 = none).
static func level_reached(trait_name: String, amount: int) -> int:
	var steps: Array = THRESHOLDS.get(trait_name, [])
	var reached := 0
	for threshold in steps:
		if amount >= threshold:
			reached += 1
	return reached


## Returns the active synergies as {trait_name: level}, highest first.
static func active(units: Array) -> Dictionary:
	var result := {}
	var counts := count(units)
	for trait_name in counts:
		var reached := level_reached(trait_name, counts[trait_name])
		if reached > 0:
			result[trait_name] = reached
	return result


## Applies battle-start effects to one side's units.
static func apply(units: Array) -> void:
	var levels := active(units)
	for unit in units:
		if levels.has("Working") and unit.has_trait("Working"):
			_scale_fluff(unit, 1.0 + WORKING_FLUFF[levels["Working"] - 1])
		if levels.has("Saucisse") and unit.has_trait("Saucisse"):
			_scale_fluff(unit, 1.0 + SAUCISSE_FLUFF_PER_LANE[levels["Saucisse"] - 1] * unit.length)
		if levels.has("Bagarreur") and unit.has_trait("Bagarreur"):
			unit.bite *= 1.0 + BAGARREUR_BITE[levels["Bagarreur"] - 1]
		if levels.has("Terriers") and unit.has_trait("Terriers"):
			unit.low_fluff_pace_bonus = TERRIERS_PACE[levels["Terriers"] - 1]
	# Gardien shields every ally, so it goes last, on the final Fluff values.
	if levels.has("Gardien"):
		var ratio: float = GARDIEN_SHIELD[levels["Gardien"] - 1]
		for unit in units:
			unit.shield += unit.max_fluff * ratio


static func _scale_fluff(unit: BattleUnit, factor: float) -> void:
	unit.max_fluff *= factor
	unit.fluff = unit.max_fluff
