class_name PackDog
extends RefCounted
## A dog the player owns, on the bench or on the board.

var breed_id: String
var level: int = 1
## Board position, or row = -1 when the dog is on the bench.
var row: int = -1
var lane: int = -1


func _init(p_breed_id: String, p_level: int = 1) -> void:
	breed_id = p_breed_id
	level = p_level


func breed() -> Dictionary:
	return BreedDB.get_breed(breed_id)


func tier() -> int:
	return breed()["tier"]


## Lanes this dog spans on the board: a teckel grows 1 lane per level.
func length() -> int:
	return level if breed().get("long", false) else 1


func on_board() -> bool:
	return row >= 0
