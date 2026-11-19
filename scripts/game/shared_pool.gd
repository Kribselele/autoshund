class_name SharedPool
extends RefCounted
## The shared kennel: every pack buys from the same limited copies of each breed.

var counts: Dictionary = {}


func _init() -> void:
	for id in BreedDB.ids():
		var tier: int = BreedDB.get_breed(id)["tier"]
		counts[id] = Economy.POOL_COPIES[tier - 1]


## Picks a breed of the given tier, weighted by copies left. Returns "" if the tier is empty.
func draw(tier: int, rng: RandomNumberGenerator) -> String:
	var ids := []
	var total := 0
	for id in _sorted_ids():
		if BreedDB.get_breed(id)["tier"] == tier and counts[id] > 0:
			ids.append(id)
			total += counts[id]
	if total == 0:
		return ""
	var pick := rng.randi_range(1, total)
	for id in ids:
		pick -= counts[id]
		if pick <= 0:
			return id
	return ids[-1]


func take(id: String) -> bool:
	if counts.get(id, 0) <= 0:
		return false
	counts[id] -= 1
	return true


func give_back(id: String, copies: int) -> void:
	counts[id] = counts.get(id, 0) + copies


func _sorted_ids() -> Array:
	var ids := counts.keys()
	ids.sort()
	return ids
