extends Node
## Local save slots (FR-20, FR-21). Each slot is user://save_<n>.json.
## The gameplay data inside "state" gets filled in once the restaurant exists.

const SLOT_COUNT := 3
const SAVE_VERSION := 1

## Slot the current game is using (-1 = none).
var current_slot := -1


func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func has_any_save() -> bool:
	for i in SLOT_COUNT:
		if has_save(i):
			return true
	return false


## Small summary for the Load Game screen, or {} if the slot is empty/broken.
func read_meta(slot: int) -> Dictionary:
	var data := _read(slot)
	return data.get("meta", {})


func most_recent_slot() -> int:
	var best := -1
	var best_time := -1
	for i in SLOT_COUNT:
		var meta := read_meta(i)
		if meta.is_empty():
			continue
		var t := int(meta.get("saved_at", 0))
		if t > best_time:
			best_time = t
			best = i
	return best


func first_empty_slot() -> int:
	for i in SLOT_COUNT:
		if not has_save(i):
			return i
	return -1


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


## Writes to a temp file first so a crash mid-save can't corrupt a valid save (NFR-03).
func save_game(slot: int, state: Dictionary, meta: Dictionary) -> bool:
	meta["saved_at"] = int(Time.get_unix_time_from_system())
	var data := {"version": SAVE_VERSION, "meta": meta, "state": state}
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, slot_path(slot)) != OK:
		DirAccess.remove_absolute(slot_path(slot))
		DirAccess.rename_absolute(tmp, slot_path(slot))
	current_slot = slot
	return true


func load_state(slot: int) -> Dictionary:
	current_slot = slot
	return _read(slot).get("state", {})


func _read(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
