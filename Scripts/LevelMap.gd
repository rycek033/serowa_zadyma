extends Control

@export var total_levels: int = 30
@export var columns: int = 4

var title_label: Label
var subtitle_label: Label
var summary_label: Label
var grid: GridContainer

func _ready():
	total_levels = get_available_levels_count()
	build_ui()
	refresh_level_grid()

func get_available_levels_count() -> int:
	var dir = DirAccess.open("res://Levels")
	if dir == null:
		return total_levels

	var count = 0
	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if file_name.begins_with("level_") and file_name.ends_with(".json"):
			count += 1
	dir.list_dir_end()

	if count <= 0:
		return total_levels
	return count

func get_save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")

func build_ui():
	var root = VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 24
	root.offset_top = 20
	root.offset_right = -24
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	title_label = Label.new()
	title_label.text = "SEROWA ZADYMA"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
	root.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Wybierz poziom"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 30)
	root.add_child(subtitle_label)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 24)
	root.add_child(summary_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var hint = Label.new()
	hint.text = "Kliknij poziom, żeby grać. Zablokowane poziomy odblokujesz gwiazdkami."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 20)
	hint.modulate = Color(1, 1, 1, 0.8)
	root.add_child(hint)

func _stars_text(stars: int) -> String:
	var filled = ""
	for i in stars:
		filled += "★"
	var empty = ""
	for i in (3 - stars):
		empty += "☆"
	return filled + empty

func refresh_level_grid():
	if grid == null:
		return

	for child in grid.get_children():
		child.queue_free()

	var save_system = get_save_system()
	if save_system == null:
		summary_label.text = "Brak SaveSystem"
		return

	var total_stars = 0
	var unlocked_count = 0
	for level in range(1, total_levels + 1):
		if save_system.is_level_unlocked(level):
			unlocked_count += 1
		total_stars += save_system.get_level_stars(level)

	summary_label.text = "Odblokowane: " + str(unlocked_count) + "/" + str(total_levels) + " | Gwiazdki: " + str(total_stars)

	for level in range(1, total_levels + 1):
		var unlocked = save_system.is_level_unlocked(level)
		var stars = save_system.get_level_stars(level)
		var best_score = save_system.get_best_score(level)

		var button = Button.new()
		button.custom_minimum_size = Vector2(145, 108)
		button.disabled = not unlocked
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)

		if unlocked:
			button.text = "Poziom " + str(level) + "\n" + _stars_text(stars) + "\nHS: " + str(best_score)
		else:
			button.text = "Poziom " + str(level) + "\n🔒 Zablokowany"
			button.modulate = Color(1, 1, 1, 0.7)

		button.pressed.connect(_on_level_pressed.bind(level))
		grid.add_child(button)

func _on_level_pressed(level_id: int):
	var save_system = get_save_system()
	if save_system == null:
		return

	if not save_system.is_level_unlocked(level_id):
		return

	save_system.set_setting("selected_level", level_id)
	save_system.save()
	get_tree().change_scene_to_file("res://Scenes/board.tscn")
