extends Node

var consent_ads: bool = false
var interstitial_every_levels: int = 2
var min_seconds_between_ads: int = 45

var levels_since_last_interstitial: int = 0
var last_ad_unix_time: int = 0

func _ready():
	refresh_settings()

func get_save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")

func get_analytics() -> Node:
	return get_node_or_null("/root/AnalyticsManager")

func refresh_settings():
	var save_system = get_save_system()
	if save_system == null:
		return
	consent_ads = bool(save_system.get_setting("consent_ads", false))

func set_consent(ads_allowed: bool):
	consent_ads = ads_allowed
	var save_system = get_save_system()
	if save_system != null:
		save_system.set_setting("consent_ads", ads_allowed)
		save_system.save()

func maybe_show_interstitial(trigger: String, level_id: int):
	if not consent_ads:
		return false

	levels_since_last_interstitial += 1
	if levels_since_last_interstitial < interstitial_every_levels:
		return false

	var now = Time.get_unix_time_from_system()
	if now - last_ad_unix_time < min_seconds_between_ads:
		return false

	levels_since_last_interstitial = 0
	last_ad_unix_time = now

	var analytics = get_analytics()
	if analytics != null:
		analytics.track_event("ad_interstitial_show", {
			"trigger": trigger,
			"level_id": level_id,
		})

	# Placeholder: this is where native SDK call should go (AdMob/other).
	print("[AdsManager] Interstitial placeholder shown. trigger=", trigger, " level=", level_id)
	return true

func show_rewarded(trigger: String) -> bool:
	if not consent_ads:
		return false

	var analytics = get_analytics()
	if analytics != null:
		analytics.track_event("ad_rewarded_show", {
			"trigger": trigger,
		})

	# Placeholder for rewarded ad SDK integration.
	print("[AdsManager] Rewarded placeholder shown. trigger=", trigger)
	return true
