extends Node

const SAVE_VERSION := 1
const SAVE_PATH := "user://serowa_zadyma.save"

var data: Dictionary = {}

func _ready():
	load_save()

func _make_default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"unlocked_levels": [1],
		"stars_per_level": {},
		"best_score_per_level": {},
		"tutorial_seen": {
			"chilli": false,
			"camembert": false,
		},
		"settings": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"vibration": true,
			"consent_analytics": true,
			"consent_ads": false,
			"analytics_enabled": true,
		},
	}

func load_save() -> void:
	data = _make_default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		save()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveSystem: Could not open save file for reading, using defaults.")
		return

	var raw = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: Save file corrupted or invalid JSON, resetting to defaults.")
		save()
		return

	_merge_with_defaults(parsed)

func _merge_with_defaults(parsed: Dictionary) -> void:
	var defaults = _make_default_data()
	data["save_version"] = int(parsed.get("save_version", defaults["save_version"]))
	data["unlocked_levels"] = parsed.get("unlocked_levels", defaults["unlocked_levels"])
	data["stars_per_level"] = parsed.get("stars_per_level", defaults["stars_per_level"])
	data["best_score_per_level"] = parsed.get("best_score_per_level", defaults["best_score_per_level"])
	data["tutorial_seen"] = defaults["tutorial_seen"].duplicate(true)
	data["settings"] = defaults["settings"].duplicate(true)

	if parsed.has("tutorial_seen") and parsed["tutorial_seen"] is Dictionary:
		for key in parsed["tutorial_seen"].keys():
			data["tutorial_seen"][key] = parsed["tutorial_seen"][key]

	if parsed.has("settings") and parsed["settings"] is Dictionary:
		for key in parsed["settings"].keys():
			data["settings"][key] = parsed["settings"][key]

	if not (data["unlocked_levels"] is Array):
		data["unlocked_levels"] = [1]
	if not (data["stars_per_level"] is Dictionary):
		data["stars_per_level"] = {}
	if not (data["best_score_per_level"] is Dictionary):
		data["best_score_per_level"] = {}

	if not is_level_unlocked(1):
		unlock_level(1)

func save() -> bool:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: Could not open save file for writing.")
		return false

	file.store_string(JSON.stringify(data))
	file.close()
	return true

func reset_save() -> void:
	data = _make_default_data()
	save()

func is_level_unlocked(level_id: int) -> bool:
	return level_id in data.get("unlocked_levels", [])

func unlock_level(level_id: int) -> void:
	var unlocked: Array = data.get("unlocked_levels", [])
	if not level_id in unlocked:
		unlocked.append(level_id)
		unlocked.sort()
		data["unlocked_levels"] = unlocked

func get_level_stars(level_id: int) -> int:
	var stars_map: Dictionary = data.get("stars_per_level", {})
	return int(stars_map.get(str(level_id), 0))

func set_level_stars(level_id: int, stars: int) -> void:
	var clamped_stars = clampi(stars, 0, 3)
	var key = str(level_id)
	var stars_map: Dictionary = data.get("stars_per_level", {})
	var current = int(stars_map.get(key, 0))
	if clamped_stars > current:
		stars_map[key] = clamped_stars
		data["stars_per_level"] = stars_map

func get_best_score(level_id: int) -> int:
	var best_map: Dictionary = data.get("best_score_per_level", {})
	return int(best_map.get(str(level_id), 0))

func set_best_score(level_id: int, score: int) -> void:
	var key = str(level_id)
	var best_map: Dictionary = data.get("best_score_per_level", {})
	var current = int(best_map.get(key, 0))
	if score > current:
		best_map[key] = score
		data["best_score_per_level"] = best_map

func has_seen_tutorial(tutorial_id: String) -> bool:
	var seen_map: Dictionary = data.get("tutorial_seen", {})
	return bool(seen_map.get(tutorial_id, false))

func mark_tutorial_seen(tutorial_id: String) -> void:
	var seen_map: Dictionary = data.get("tutorial_seen", {})
	seen_map[tutorial_id] = true
	data["tutorial_seen"] = seen_map

func get_setting(key: String, default_value = null):
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, default_value)

func set_setting(key: String, value) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings

func get_data_snapshot() -> Dictionary:
	return data.duplicate(true)
