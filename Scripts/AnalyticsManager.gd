extends Node

const LOG_PATH := "user://analytics_events.log"

var enabled: bool = true
var consent_analytics: bool = true

func _ready():
	refresh_settings()
	track_event("app_start", {
		"platform": OS.get_name(),
		"engine": Engine.get_version_info().get("string", "unknown"),
	})

func get_save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")

func refresh_settings():
	var save_system = get_save_system()
	if save_system == null:
		return
	enabled = bool(save_system.get_setting("analytics_enabled", true))
	consent_analytics = bool(save_system.get_setting("consent_analytics", true))

func set_consent(analytics_allowed: bool):
	consent_analytics = analytics_allowed
	var save_system = get_save_system()
	if save_system != null:
		save_system.set_setting("consent_analytics", analytics_allowed)
		save_system.save()

func track_event(event_name: String, params: Dictionary = {}):
	if not enabled or not consent_analytics:
		return

	var payload = {
		"ts": Time.get_unix_time_from_system(),
		"event": event_name,
		"params": params,
	}

	var file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()
