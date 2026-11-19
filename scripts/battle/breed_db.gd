class_name BreedDB
extends RefCounted
## Loads the breed catalogue from data/breeds.json.
## The JSON is exported from the balance sheet; edit stats there first.

const DATA_PATH := "res://data/breeds.json"

static var _breeds: Dictionary = {}


static func all() -> Dictionary:
	if _breeds.is_empty():
		_load()
	return _breeds


static func get_breed(id: String) -> Dictionary:
	var breeds := all()
	assert(breeds.has(id), "Unknown breed: %s" % id)
	return breeds[id]


static func ids() -> Array:
	return all().keys()


static func _load() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("%s must hold an array of breeds" % DATA_PATH)
		return
	for breed in parsed:
		_breeds[breed["id"]] = breed
