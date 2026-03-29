extends Node2D

# ============================================================================
# BOARD.GD - Main game orchestrator (2158 lines)
# 
# This file is organized as follows:
# - EXPORTS & CONSTANTS (lines 3-50)
# - STATE VARIABLES (lines 51-95)
# - LIFECYCLE (_ready, _process) (lines 96-130)
# - LEVEL LOADING (lines 131-250) → Move to BoardLevelLoader.gd
# - BOARD INITIALIZATION & SETUP (lines 251-415)
# - IDLE HINT SYSTEM (lines 416-480)
# - GRID OPERATIONS (lines 481-550) → Use BoardGridHelper.gd
# - MATCH FINDING (lines 551-650) → Move to BoardMatchFinder.gd
# - MATCH DESTRUCTION (lines 651-800) → Move to BoardMatchResolver.gd
# - INPUT HANDLING (lines 801-950) → Move to BoardInputHandler.gd
# - SWAPS & GRAVITY (lines 951-1100) → Move to BoardPhysics.gd
# - GOAL TRACKING (lines 1101-1250) → Move to BoardGoalSystem.gd
# - UTILITIES (lines 1251-2158)
# ============================================================================

@export var width: int = 8
@export var height: int = 8
@export var cell_size: int = 64
@export var min_cell_size: int = 44
@export var board_horizontal_padding: int = 24
@export var board_bottom_padding: int = 24
@export var top_ui_margin: int = 160
@export var max_initial_fill_attempts: int = 12
@export var swap_duration: float = 0.16
@export var swap_back_duration: float = 0.14
@export var collapse_step_duration: float = 0.06
@export var refill_step_duration: float = 0.06
@export var destroy_delay: float = 0.12
@export var combo_sound: AudioStream
@export var camembert_boom_sound: AudioStream
@export var chilli_whoosh_sound: AudioStream
@export var current_level_id: int = 1
@export var use_json_levels: bool = true
@export var levels_directory: String = "res://Levels"
@export var star_1_score: int = 600
@export var star_2_score: int = 1400
@export var star_3_score: int = 2600
@export var moves_limit: int = 20
@export_enum("score", "clear_color", "bring_down", "clear_ice", "clear_mold") var level_goal_type: String = "score"
@export var goal_target: int = 1800
@export_range(0, 4, 1) var goal_color_type: int = 3
@export var procedural_levels_enabled: bool = true
@export var min_moves_limit: int = 10
@export var score_goal_growth_per_level: int = 260
@export var clear_goal_growth_per_level: int = 1
@export var bring_down_growth_per_level: int = 1
@export var clear_ice_growth_per_level: int = 1
@export var clear_mold_growth_per_level: int = 1
@export var max_ice_layers: int = 2
@export var initial_mold_tiles: int = 4
@export var mold_spread_per_turn: int = 1
@export var idle_hint_delay_seconds: float = 8.0

const AUDIO_SAMPLE_RATE := 44100.0
const DEBUG_COLOR_NAMES := ["Yellow", "White", "Green", "Red", "Pink"]

var grid: Array = []
var piece_array: Array = []

var first_touch: Vector2 = Vector2(-1, -1)
var last_swap: Vector2 = Vector2(-1, -1)
var is_animating: bool = false
var is_resolving_move: bool = false
var level_finished: bool = false
var level_won: bool = false
var goal_cleanup_performed: bool = false
var goal_reached_this_level: bool = false
var cascade_depth: int = 0
var max_combo_in_move: int = 1
var moves_left: int = 0
var goal_progress: int = 0
var bring_down_targets_spawned: int = 0
var mold_spread_done_this_move: bool = false
var board_origin: Vector2 = Vector2.ZERO
var board_rest_position: Vector2
var shake_tween: Tween
var max_cell_size: int = 64
var active_base_types: int = 5
var base_moves_limit: int = 20
var base_goal_target: int = 1800
var ice_layers_grid: Array = []
var mold_grid: Array = []
var cell_active_grid: Array = []
var loaded_level_data: Dictionary = {}
var loaded_level_from_json: bool = false

var combo_player: AudioStreamPlayer
var camembert_player: AudioStreamPlayer
var chilli_player: AudioStreamPlayer
var debug_layer: CanvasLayer
var debug_panel: ColorRect
var debug_label: Label
var debug_enabled: bool = false
var debug_source_color: int = 3
var idle_hint_elapsed: float = 0.0
var hint_visible: bool = false

var base_cheese_texture = preload("res://Graphics/Cheeses/cheese.png")
var chilli_cheese_texture = preload("res://Graphics/Cheeses/chilicheese.png")
var camembert_texture = preload("res://Graphics/Cheeses/camembert.png")
var mozzarella_texture = preload("res://Graphics/Cheeses/mozarella.png")
var bring_down_placeholder_texture = preload("res://icon.svg")

var base_cheese_colors = [
	Color(0.9, 0.8, 0.3),
	Color(0.95, 0.95, 0.95),
	Color(0.7, 0.8, 0.3),
	Color(0.8, 0.4, 0.2),
	Color(0.9, 0.7, 0.8),
]

var num_total_base_types = base_cheese_colors.size()

const CHILLI_BOMB_TYPE = 98
const CAMEMBERT_BOMB_TYPE = 99
const MOZZARELLA_BOMB_TYPE = 100
const DROP_GOAL_PIECE_TYPE = 101

@onready var ui = $UI

#region === LIFECYCLE & INITIALIZATION ===

func _ready():
	randomize()
	base_moves_limit = moves_limit
	base_goal_target = goal_target
	active_base_types = num_total_base_types
	max_cell_size = cell_size
	board_rest_position = position
	setup_audio_players()
	setup_debug_menu()
	update_board_layout()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	grid = make_2d_array()
	piece_array = make_2d_array()
	cell_active_grid = make_2d_int_array(1)
	loaded_level_data = {}
	loaded_level_from_json = false
	load_selected_level_from_save()
	unlock_current_level_if_needed()
	start_level(current_level_id)
	persist_progress(false)

func _process(delta: float):
	if level_finished or is_animating or debug_enabled:
		return
	if first_touch != Vector2(-1, -1):
		return
	if ui != null and ui.has_method("is_tutorial_hint_visible") and ui.is_tutorial_hint_visible():
		return

	idle_hint_elapsed += delta
	if idle_hint_elapsed >= idle_hint_delay_seconds and not hint_visible:
		show_idle_hint()

func reset_idle_hint_timer():
	idle_hint_elapsed = 0.0
	if hint_visible and ui != null:
		ui.hide_hint_move()
	hint_visible = false

#endregion

#region === HINT SYSTEM ===

func find_hint_move() -> Array:
	for i in width:
		for j in height:
			if not is_cell_active(i, j):
				continue
			if is_locked_piece_at(i, j):
				continue
			var pos = Vector2(i, j)
			var right = Vector2(i + 1, j)
			var down = Vector2(i, j + 1)

			if is_cell_active(int(right.x), int(right.y)) and not is_locked_piece_at(int(right.x), int(right.y)) and would_swap_create_match(pos, right):
				return [pos, right]
			if is_cell_active(int(down.x), int(down.y)) and not is_locked_piece_at(int(down.x), int(down.y)) and would_swap_create_match(pos, down):
				return [pos, down]

	return []

func show_idle_hint():
	var move = find_hint_move()
	if move.size() < 2:
		return
	if ui != null:
		ui.show_hint_move(
			to_global(grid_to_local(int(move[0].x), int(move[0].y))),
			to_global(grid_to_local(int(move[1].x), int(move[1].y)))
		)
	hint_visible = true

#endregion

#region === LEVEL LOADING ===

func load_selected_level_from_save():
	var save_system = get_save_system()
	if save_system == null:
		return

	var selected = int(save_system.get_setting("selected_level", current_level_id))
	if selected <= 0:
		selected = 1

	if save_system.is_level_unlocked(selected):
		current_level_id = selected
	else:
		current_level_id = 1

func get_level_json_path(level_id: int) -> String:
	return levels_directory.path_join("level_%03d.json" % level_id)

func load_level_data_json(level_id: int) -> Dictionary:
	if not use_json_levels:
		return {}

	var path = get_level_json_path(level_id)
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Board: cannot open level file: " + path)
		return {}

	var text = file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Board: invalid level json structure in: " + path)
		return {}

	var data: Dictionary = parsed
	if not data.has("grid_width") or not data.has("grid_height"):
		push_warning("Board: level json missing grid size in: " + path)
		return {}
	if not data.has("layout"):
		push_warning("Board: level json missing layout in: " + path)
		return {}

	return data

func configure_level_difficulty(level_id: int):
	if not procedural_levels_enabled:
		active_base_types = num_total_base_types
		return

	active_base_types = clampi(3 + int(floor((level_id - 1) / 4.0)), 3, num_total_base_types)
	if level_id <= 2:
		active_base_types = maxi(active_base_types, 4)

	# Co kilka poziomów losujemy inny typ celu.
	if level_id <= 2:
		level_goal_type = "score"
	elif level_id <= 5:
		level_goal_type = "clear_color" if randf() < 0.45 else "score"
	else:
		var roll = randf()
		if roll < 0.16:
			level_goal_type = "bring_down"
		elif roll < 0.36:
			level_goal_type = "clear_ice"
		elif roll < 0.56:
			level_goal_type = "clear_mold"
		elif roll < 0.78:
			level_goal_type = "clear_color"
		else:
			level_goal_type = "score"

	moves_limit = maxi(min_moves_limit, base_moves_limit - int(floor((level_id - 1) / 2.0)))

	if level_goal_type == "score":
		goal_target = base_goal_target + (level_id - 1) * score_goal_growth_per_level + randi_range(-120, 180)
	elif level_goal_type == "clear_color":
		goal_color_type = randi() % active_base_types
		goal_target = 10 + (level_id - 1) * clear_goal_growth_per_level + randi_range(0, 4)
	elif level_goal_type == "bring_down":
		goal_target = 2 + int(floor((level_id - 1) / 4.0)) * bring_down_growth_per_level
	elif level_goal_type == "clear_ice":
		goal_target = 8 + (level_id - 1) * clear_ice_growth_per_level + randi_range(0, 4)
	else:
		goal_target = 7 + (level_id - 1) * clear_mold_growth_per_level + randi_range(0, 3)

	debug_source_color = clampi(debug_source_color, 0, active_base_types - 1)
	refresh_debug_menu_text()

func apply_loaded_level_config(level_data: Dictionary):
	width = maxi(3, int(level_data.get("grid_width", width)))
	height = maxi(3, int(level_data.get("grid_height", height)))

	if level_data.has("moves"):
		moves_limit = maxi(1, int(level_data.get("moves", moves_limit)))

	var goal_data = level_data.get("goal", {})
	if typeof(goal_data) == TYPE_DICTIONARY:
		var goal_type = str(goal_data.get("type", level_goal_type))
		if ["score", "clear_color", "bring_down", "clear_ice", "clear_mold"].has(goal_type):
			level_goal_type = goal_type
		goal_target = maxi(1, int(goal_data.get("target", goal_target)))
		goal_color_type = clampi(int(goal_data.get("color", goal_color_type)), 0, num_total_base_types - 1)

	if level_data.has("active_colors"):
		active_base_types = clampi(int(level_data.get("active_colors", active_base_types)), 3, num_total_base_types)
	else:
		active_base_types = num_total_base_types

	if level_data.has("stars"):
		var stars = level_data.get("stars", [])
		if typeof(stars) == TYPE_ARRAY and stars.size() >= 3:
			star_1_score = int(stars[0])
			star_2_score = int(stars[1])
			star_3_score = int(stars[2])

	debug_source_color = clampi(debug_source_color, 0, active_base_types - 1)
	update_board_layout()

func build_board_from_loaded_level(level_data: Dictionary):
	clear_board_state()
	cell_active_grid = make_2d_int_array(1)
	ice_layers_grid = make_2d_int_array(0)
	mold_grid = make_2d_int_array(0)

	var layout = level_data.get("layout", [])
	if typeof(layout) != TYPE_ARRAY:
		initial_fill_board()
		return

	for row in range(0, mini(height, layout.size())):
		var row_data = layout[row]
		if typeof(row_data) != TYPE_ARRAY:
			continue
		for column in range(0, mini(width, row_data.size())):
			var code = int(row_data[column])
			if code == 0:
				cell_active_grid[column][row] = 0
				grid[column][row] = null
				piece_array[column][row] = null
				continue

			cell_active_grid[column][row] = 1
			var base_type = get_random_base_type(column, row, true)
			var force_visual = ""
			var ice_layers = 0
			var mold_enabled = false

			if code >= 10 and code < 10 + num_total_base_types:
				base_type = code - 10
			elif code == 2:
				ice_layers = 1
			elif code == 3:
				ice_layers = mini(max_ice_layers, 2)
			elif code == 4:
				mold_enabled = true
			elif code == 98:
				force_visual = "row_bomb" if randf() < 0.5 else "col_bomb"
			elif code == 99:
				force_visual = "area_bomb"
			elif code == 100:
				force_visual = "color_bomb"

			if force_visual == "":
				create_cheese_sprite(column, row, base_type)
			else:
				create_cheese_sprite(column, row, base_type, force_visual, base_type)

			if piece_array[column][row] != null:
				piece_array[column][row].set_ice_layers(ice_layers)
				piece_array[column][row].set_mold(mold_enabled)
			ice_layers_grid[column][row] = ice_layers
			mold_grid[column][row] = 1 if mold_enabled else 0

	for i in width:
		for j in height:
			if cell_active_grid[i][j] <= 0:
				continue
			if piece_array[i][j] == null:
				var fallback_type = get_random_base_type(i, j, true)
				create_cheese_sprite(i, j, fallback_type)

	refresh_all_piece_obstacle_tints()
	update_goal_ui()

func maybe_show_json_level_tutorial(level_data: Dictionary):
	if ui == null:
		return
	if typeof(level_data) != TYPE_DICTIONARY:
		return

	var tutorial_data = level_data.get("tutorial", {})
	if typeof(tutorial_data) != TYPE_DICTIONARY:
		return

	var tutorial_id = str(tutorial_data.get("id", "level_%03d" % current_level_id))
	if tutorial_id == "":
		tutorial_id = "level_%03d" % current_level_id

	var save_system = get_save_system()
	if save_system != null and save_system.has_seen_tutorial(tutorial_id):
		return

	var title = str(tutorial_data.get("title", "Tutorial"))
	var body = str(tutorial_data.get("body", ""))
	if body == "":
		return

	var board_center = board_origin + Vector2(width * cell_size * 0.5, height * cell_size * 0.5)
	ui.show_tutorial_hint(title, body, to_global(board_center))

	if save_system != null:
		save_system.mark_tutorial_seen(tutorial_id)
		save_system.save()

func start_level(level_id: int):
	current_level_id = maxi(1, level_id)
	loaded_level_data = load_level_data_json(current_level_id)
	loaded_level_from_json = not loaded_level_data.is_empty()

	if loaded_level_from_json:
		apply_loaded_level_config(loaded_level_data)
	else:
		configure_level_difficulty(current_level_id)
		cell_active_grid = make_2d_int_array(1)
		update_board_layout()

	setup_level_session()
	if loaded_level_from_json:
		build_board_from_loaded_level(loaded_level_data)
		if not has_possible_moves():
			initial_fill_board(true)
	else:
		clear_board_state()
		initial_fill_board()
		ensure_board_has_possible_moves()
		maybe_prepare_tutorial_level()
		setup_level_obstacles()
	setup_bring_down_targets()
	if loaded_level_from_json:
		maybe_show_json_level_tutorial(loaded_level_data)
	arm_all_bombs()

	var analytics = get_analytics()
	if analytics != null:
		analytics.track_event("level_start", {
			"level_id": current_level_id,
			"goal_type": level_goal_type,
			"goal_target": goal_target,
			"moves_limit": moves_limit,
			"active_colors": active_base_types,
		})

func set_base_piece(column: int, row: int, color_type: int):
	if not is_in_grid(column, row):
		return
	var clamped = clampi(color_type, 0, active_base_types - 1)
	create_cheese_sprite(column, row, clamped)

func apply_chilli_tutorial_pattern() -> Vector2:
	# One move away from 4-in-line (swap (3,4) with (3,3)).
	set_base_piece(0, 3, 2)
	set_base_piece(1, 3, 3)
	set_base_piece(2, 3, 3)
	set_base_piece(3, 3, 0)
	set_base_piece(4, 3, 3)
	set_base_piece(5, 3, 1)
	set_base_piece(3, 2, 1)
	set_base_piece(3, 4, 3)
	return grid_to_local(3, 3)

func apply_camembert_tutorial_pattern() -> Vector2:
	# One move away from T/L (swap (4,4) with (3,4)).
	set_base_piece(1, 3, 0)
	set_base_piece(2, 3, 2)
	set_base_piece(3, 3, 2)
	set_base_piece(4, 3, 2)
	set_base_piece(5, 3, 1)
	set_base_piece(3, 2, 2)
	set_base_piece(3, 4, 0)
	set_base_piece(4, 4, 2)
	return grid_to_local(3, 3)

func maybe_prepare_tutorial_level():
	if ui == null:
		return

	var save_system = get_save_system()
	if save_system == null:
		ui.hide_tutorial_hint()
		return

	var tutorial_id = ""
	if current_level_id == 1 and not save_system.has_seen_tutorial("chilli"):
		tutorial_id = "chilli"
	elif current_level_id == 2 and not save_system.has_seen_tutorial("camembert"):
		tutorial_id = "camembert"

	if tutorial_id == "":
		ui.hide_tutorial_hint()
		return

	var anchor = Vector2.ZERO
	var attempts = 0
	while attempts < 6:
		if attempts > 0:
			initial_fill_board()

		if tutorial_id == "chilli":
			anchor = apply_chilli_tutorial_pattern()
		else:
			anchor = apply_camembert_tutorial_pattern()

		if find_matches().size() == 0 and has_possible_moves():
			break

		attempts += 1

	if tutorial_id == "chilli":
		var move_a = to_global(grid_to_local(3, 4))
		var move_b = to_global(grid_to_local(3, 3))
		ui.show_tutorial_hint(
			"Tutorial: Ogniste Chilli",
			"Ułóż 4 sery w linii, aby stworzyć Chilli Cheese. Spróbuj swapnąć środkowe pola!",
			to_global(anchor),
			move_a,
			move_b
		)
	else:
		var move_a2 = to_global(grid_to_local(4, 4))
		var move_b2 = to_global(grid_to_local(3, 4))
		ui.show_tutorial_hint(
			"Tutorial: Camembert",
			"Zrób kształt L lub T z jednego koloru, aby stworzyć wybuchowego Camemberta.",
			to_global(anchor),
			move_a2,
			move_b2
		)

	save_system.mark_tutorial_seen(tutorial_id)
	save_system.save()

func get_bring_down_candidate_cells() -> Array:
	var candidates: Array = []
	var max_row = maxi(0, int(floor(height * 0.5)))
	for i in width:
		for j in range(0, max_row):
			var piece: Piece = piece_array[i][j]
			if piece == null:
				continue
			if piece.is_obstacle_locked():
				continue
			if piece.is_bomb():
				continue
			candidates.append(Vector2(i, j))
	return candidates

func setup_bring_down_targets():
	bring_down_targets_spawned = 0
	if level_goal_type != "bring_down":
		return

	var candidates = get_bring_down_candidate_cells()
	candidates.shuffle()
	var amount = mini(goal_target, candidates.size())

	for idx in range(0, amount):
		var p: Vector2 = candidates[idx]
		var x = int(p.x)
		var y = int(p.y)
		create_cheese_sprite(x, y, DROP_GOAL_PIECE_TYPE, "drop_goal")
		bring_down_targets_spawned += 1

	goal_target = maxi(goal_target, bring_down_targets_spawned)
	update_goal_ui()

func setup_level_session():
	level_finished = false
	level_won = false
	goal_cleanup_performed = false
	goal_reached_this_level = false
	moves_left = moves_limit
	goal_progress = 0
	bring_down_targets_spawned = 0
	mold_spread_done_this_move = false
	is_animating = false
	is_resolving_move = false
	first_touch = Vector2(-1, -1)
	last_swap = Vector2(-1, -1)
	cascade_depth = 0
	max_combo_in_move = 1
	reset_idle_hint_timer()

	if ui != null:
		ui.reset_score(0)
		ui.hide_level_result()
		ui.hide_tutorial_hint()
		ui.hide_hint_move()
		ui.set_star_thresholds(star_1_score, star_2_score, star_3_score)
		ui.set_moves_left(moves_left)
		ui.set_goal_text(get_goal_status_text())

func setup_debug_menu():
	debug_layer = CanvasLayer.new()
	debug_layer.layer = 99
	add_child(debug_layer)

	debug_panel = ColorRect.new()
	debug_panel.color = Color(0.05, 0.05, 0.05, 0.82)
	debug_panel.position = Vector2(10, 10)
	debug_panel.size = Vector2(500, 200)
	debug_layer.add_child(debug_panel)

	debug_label = Label.new()
	debug_label.position = Vector2(14, 12)
	debug_label.size = Vector2(472, 180)
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	debug_panel.add_child(debug_label)

	debug_layer.visible = false
	refresh_debug_menu_text()

func refresh_debug_menu_text():
	if debug_label == null:
		return

	var color_name = DEBUG_COLOR_NAMES[debug_source_color]
	debug_label.text = "DEBUG MENU (F3)\n" \
		+ "Level: " + str(current_level_id) + " | Active colors: " + str(active_base_types) + "\n" \
		+ "F4: Spawn random base at mouse\n" \
		+ "1: Spawn Chilli (bound color) at mouse\n" \
		+ "2: Spawn Camembert at mouse\n" \
		+ "3: Spawn Mozzarella at mouse\n" \
		+ "Q / E: Change bomb source color (current: " + color_name + ")\n" \
		+ "F5: Clean initial fill (no start matches)\n" \
		+ "F6: Arm all bombs\n" \
		+ "F7: Reset progresu"

func reset_progress_and_restart_level():
	var save_system = get_save_system()
	if save_system == null:
		return

	save_system.reset_save()
	save_system.set_setting("selected_level", 1)
	save_system.save()

	current_level_id = 1
	start_level(1)
	persist_progress(false)

func get_mouse_grid_cell() -> Vector2:
	var mouse_pos = get_viewport().get_mouse_position()
	var local_pos = mouse_pos - board_origin
	if local_pos.x < 0 or local_pos.y < 0:
		return Vector2(-1, -1)
	if local_pos.x >= width * cell_size or local_pos.y >= height * cell_size:
		return Vector2(-1, -1)

	return Vector2(int(local_pos.x / cell_size), int(local_pos.y / cell_size))

func spawn_debug_piece(mode: String):
	var cell = get_mouse_grid_cell()
	if cell.x < 0:
		return

	if mode == "random":
		var random_type = randi() % active_base_types
		create_cheese_sprite(int(cell.x), int(cell.y), random_type)
	elif mode == "chilli":
		create_cheese_sprite(int(cell.x), int(cell.y), CHILLI_BOMB_TYPE, "row_bomb", debug_source_color)
	elif mode == "camembert":
		create_cheese_sprite(int(cell.x), int(cell.y), CAMEMBERT_BOMB_TYPE, "area_bomb", debug_source_color)
	elif mode == "mozzarella":
		create_cheese_sprite(int(cell.x), int(cell.y), MOZZARELLA_BOMB_TYPE, "color_bomb", debug_source_color)

func get_save_system() -> Node:
	return get_node_or_null("/root/SaveSystem")

func get_analytics() -> Node:
	return get_node_or_null("/root/AnalyticsManager")

func get_ads_manager() -> Node:
	return get_node_or_null("/root/AdsManager")

func unlock_current_level_if_needed():
	var save_system = get_save_system()
	if save_system == null:
		return
	save_system.unlock_level(current_level_id)
	save_system.save()

func get_stars_for_score(score: int) -> int:
	if score >= star_3_score:
		return 3
	if score >= star_2_score:
		return 2
	if score >= star_1_score:
		return 1
	return 0

func get_goal_status_text() -> String:
	if level_goal_type == "clear_color":
		var color_name = DEBUG_COLOR_NAMES[goal_color_type]
		var done = " ✅" if goal_progress >= goal_target else ""
		return "Poziom " + str(current_level_id) + " | Cel: Usuń " + str(goal_progress) + "/" + str(goal_target) + " (" + color_name + ")" + done
	if level_goal_type == "bring_down":
		var done_drop = " ✅" if goal_progress >= goal_target else ""
		return "Poziom " + str(current_level_id) + " | Cel: Zrzuć sery " + str(goal_progress) + "/" + str(goal_target) + done_drop
	if level_goal_type == "clear_ice":
		var done_ice = " ✅" if goal_progress >= goal_target else ""
		return "Poziom " + str(current_level_id) + " | Cel: Rozbij lód " + str(goal_progress) + "/" + str(goal_target) + done_ice
	if level_goal_type == "clear_mold":
		var done_mold = " ✅" if goal_progress >= goal_target else ""
		return "Poziom " + str(current_level_id) + " | Cel: Oczyść pleśń " + str(goal_progress) + "/" + str(goal_target) + done_mold

	var current_score = ui.score if ui != null else 0
	var done_score = " ✅" if current_score >= goal_target else ""
	return "Poziom " + str(current_level_id) + " | Cel: Wynik " + str(current_score) + "/" + str(goal_target) + done_score

func collect_remaining_armed_specials() -> Array:
	var out: Array = []
	for i in width:
		for j in height:
			var piece: Piece = piece_array[i][j]
			if piece == null:
				continue
			if piece.is_bomb() and not piece.just_spawned_bomb:
				out.append(Vector2(i, j))
	return out

func get_random_base_cells() -> Array:
	var out: Array = []
	for i in width:
		for j in height:
			var piece: Piece = piece_array[i][j]
			if piece == null:
				continue
			if piece.is_bomb():
				continue
			out.append(Vector2(i, j))
	out.shuffle()
	return out

func spawn_endgame_special_at(cell: Vector2):
	var x = int(cell.x)
	var y = int(cell.y)
	var piece: Piece = piece_array[x][y]
	if piece == null:
		return

	var source_color = get_piece_color_type(piece)
	if source_color < 0:
		source_color = randi() % active_base_types

	var roll = randi() % 100
	if roll < 80:
		var mode = "row_bomb" if randi() % 2 == 0 else "col_bomb"
		create_cheese_sprite(x, y, CHILLI_BOMB_TYPE, mode, source_color)
	else:
		create_cheese_sprite(x, y, CAMEMBERT_BOMB_TYPE, "area_bomb", source_color)

	var spawned: Piece = piece_array[x][y]
	if spawned != null:
		spawned.arm_bomb()

func trigger_goal_finish_bonus() -> bool:
	if goal_cleanup_performed:
		return false
	if not is_goal_completed():
		return false
	if not goal_reached_this_level:
		goal_reached_this_level = true
		persist_progress(true)

	goal_cleanup_performed = true
	var remaining_moves = moves_left
	moves_left = 0
	if ui != null:
		ui.set_moves_left(0)

	var random_cells = get_random_base_cells()
	var bombs_to_trigger: Array = collect_remaining_armed_specials()
	var convert_count = mini(remaining_moves, random_cells.size())

	for i in range(0, convert_count):
		spawn_endgame_special_at(random_cells[i])
		add_cell_unique(bombs_to_trigger, random_cells[i])

	if ui != null:
		ui.show_event_text("FINAŁ! BONUS ZA RUCHY", get_viewport_rect().size * 0.5 + Vector2(-145, -10), Color(1.0, 0.9, 0.3))

	if bombs_to_trigger.size() > 0:
		destroy_matches(bombs_to_trigger)
		return true

	return false

func process_bring_down_deliveries() -> bool:
	if level_goal_type != "bring_down":
		return false

	var row = height - 1
	var delivered: Array = []

	for i in width:
		var piece: Piece = piece_array[i][row]
		if piece != null and piece.is_bring_down_target:
			delivered.append(Vector2(i, row))

	if delivered.size() == 0:
		return false

	for cell in delivered:
		var x = int(cell.x)
		var y = int(cell.y)
		var piece: Piece = piece_array[x][y]
		if piece == null:
			continue

		goal_progress += 1
		if ui != null:
			ui.show_event_text("DOSTAWA!", to_global(piece.position) + Vector2(-18, -16), Color(0.55, 1.0, 0.95))

		piece.destroy()
		piece_array[x][y] = null
		grid[x][y] = null

	update_goal_ui()
	return true

func update_goal_ui():
	if ui != null:
		ui.set_goal_text(get_goal_status_text())

func consume_move():
	moves_left = maxi(0, moves_left - 1)
	if ui != null:
		ui.set_moves_left(moves_left)
		ui.hide_tutorial_hint()
		ui.hide_hint_move()
	hint_visible = false

func is_goal_completed() -> bool:
	if level_goal_type == "clear_color":
		return goal_progress >= goal_target
	if level_goal_type == "bring_down":
		return goal_progress >= goal_target
	if level_goal_type == "clear_ice":
		return goal_progress >= goal_target
	if level_goal_type == "clear_mold":
		return goal_progress >= goal_target

	var current_score = ui.score if ui != null else 0
	return current_score >= goal_target

func finish_level(win: bool):
	level_finished = true
	level_won = win
	arm_all_bombs()
	is_resolving_move = false
	cascade_depth = 0
	max_combo_in_move = 1
	is_animating = false

	var final_score = ui.score if ui != null else 0
	var stars = get_stars_for_score(final_score)
	persist_progress(win)

	var analytics = get_analytics()
	if analytics != null:
		analytics.track_event("level_end", {
			"level_id": current_level_id,
			"win": win,
			"score": final_score,
			"stars": stars,
			"moves_left": moves_left,
			"goal_type": level_goal_type,
		})

	if win:
		var ads = get_ads_manager()
		if ads != null:
			ads.maybe_show_interstitial("level_complete", current_level_id)

	if ui != null:
		ui.show_level_result(win, stars, final_score)

func on_level_result_acknowledged():
	if not level_finished:
		return
	get_tree().change_scene_to_file("res://Scenes/level_map.tscn")

func persist_progress(level_completed: bool):
	var save_system = get_save_system()
	if save_system == null:
		return

	var score_value = ui.score if ui != null else 0
	var stars = get_stars_for_score(score_value)

	save_system.unlock_level(current_level_id)
	save_system.set_best_score(current_level_id, score_value)
	save_system.set_level_stars(current_level_id, stars)

	if level_completed:
		save_system.unlock_level(current_level_id + 1)

	save_system.save()

func _on_viewport_size_changed():
	update_board_layout()

func update_board_layout():
	var viewport_size = get_viewport_rect().size
	var available_width = maxf(1.0, viewport_size.x - board_horizontal_padding * 2.0)
	var available_height = maxf(1.0, viewport_size.y - top_ui_margin - board_bottom_padding)
	var fit_by_width = int(floor(available_width / float(width)))
	var fit_by_height = int(floor(available_height / float(height)))
	var fitted_size = mini(fit_by_width, fit_by_height)
	cell_size = maxi(min_cell_size, mini(max_cell_size, fitted_size))

	var board_pixel_size = Vector2(width * cell_size, height * cell_size)
	var x = (viewport_size.x - board_pixel_size.x) * 0.5
	var centered_y = (viewport_size.y - board_pixel_size.y) * 0.5
	var y = maxi(top_ui_margin, int(centered_y))
	board_origin = Vector2(x, y)

	if ui != null and ui.has_method("update_layout"):
		ui.update_layout(viewport_size, board_origin, board_pixel_size)

	reposition_existing_pieces()

func reposition_existing_pieces():
	for i in width:
		for j in height:
			if piece_array.size() > i and piece_array[i].size() > j and piece_array[i][j] != null:
				piece_array[i][j].rescale_to_size(cell_size)
				piece_array[i][j].position = grid_to_local(i, j)

func grid_to_local(column: int, row: int) -> Vector2:
	return board_origin + Vector2(column * cell_size + cell_size * 0.5, row * cell_size + cell_size * 0.5)

func setup_audio_players():
	combo_player = AudioStreamPlayer.new()
	combo_player.stream = combo_sound if combo_sound != null else make_generator_stream()
	add_child(combo_player)

	camembert_player = AudioStreamPlayer.new()
	camembert_player.stream = camembert_boom_sound if camembert_boom_sound != null else make_generator_stream()
	add_child(camembert_player)

	chilli_player = AudioStreamPlayer.new()
	chilli_player.stream = chilli_whoosh_sound if chilli_whoosh_sound != null else make_generator_stream()
	add_child(chilli_player)

func make_generator_stream() -> AudioStreamGenerator:
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.buffer_length = 0.3
	return stream

func play_audio(player: AudioStreamPlayer, event_name: String = ""):
	if player != null and player.stream != null:
		player.stop()
		player.play()
		if player.stream is AudioStreamGenerator:
			generate_fallback_sound(player, event_name)

func generate_fallback_sound(player: AudioStreamPlayer, event_name: String):
	var playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var duration := 0.18
	if event_name == "camembert":
		duration = 0.32
	elif event_name == "chilli":
		duration = 0.22

	var frame_count = int(duration * AUDIO_SAMPLE_RATE)
	for i in frame_count:
		var t = float(i) / AUDIO_SAMPLE_RATE
		var sample := 0.0

		if event_name == "combo":
			var freq = 780.0 if t < duration * 0.5 else 1040.0
			sample = sin(TAU * freq * t) * 0.18
		elif event_name == "camembert":
			var boom_freq = lerpf(180.0, 55.0, t / duration)
			var boom = sin(TAU * boom_freq * t) * 0.28
			var noise = (randf() * 2.0 - 1.0) * 0.12
			sample = (boom + noise) * (1.0 - (t / duration))
		elif event_name == "chilli":
			var hiss = (randf() * 2.0 - 1.0) * 0.16
			var tone = sin(TAU * lerpf(900.0, 350.0, t / duration) * t) * 0.08
			sample = (hiss + tone) * (1.0 - (t / duration))
		else:
			sample = sin(TAU * 660.0 * t) * 0.14

		playback.push_frame(Vector2(sample, sample))

func spawn_cheeses():
	initial_fill_board()

func initial_fill_board(keep_obstacles: bool = false):
	var attempt = 0
	while attempt < max_initial_fill_attempts:
		clear_board_state(not keep_obstacles)
		for i in width:
			for j in height:
				if not is_cell_active(i, j):
					grid[i][j] = null
					piece_array[i][j] = null
					continue
				var random_type = get_random_base_type(i, j, true)
				grid[i][j] = random_type
				create_cheese_sprite(i, j, random_type)

		if find_matches().size() == 0:
			return

		attempt += 1

	push_warning("Board: could not generate fully clean initial board after retries.")

func clear_board_state(reset_obstacles: bool = true):
	for i in width:
		for j in height:
			if piece_array.size() > i and piece_array[i].size() > j:
				if piece_array[i][j] != null:
					piece_array[i][j].queue_free()

	grid = make_2d_array()
	piece_array = make_2d_array()
	if reset_obstacles:
		cell_active_grid = make_2d_int_array(1)
		ice_layers_grid = make_2d_int_array(0)
		mold_grid = make_2d_int_array(0)

func collect_all_cells() -> Array:
	var out: Array = []
	for i in width:
		for j in height:
			if not is_cell_active(i, j):
				continue
			out.append(Vector2(i, j))
	return out

func setup_level_obstacles():
	ice_layers_grid = make_2d_int_array(0)
	mold_grid = make_2d_int_array(0)

	if level_goal_type == "clear_ice":
		setup_ice_obstacles()
	elif level_goal_type == "clear_mold":
		setup_mold_obstacles()

	refresh_all_piece_obstacle_tints()
	update_goal_ui()

func setup_ice_obstacles():
	var total_capacity = width * height * maxi(1, max_ice_layers)
	var requested_layers = clampi(goal_target, 1, total_capacity)
	var cells = collect_all_cells()
	cells.shuffle()

	var remaining = requested_layers
	for cell in cells:
		if remaining <= 0:
			break
		var x = int(cell.x)
		var y = int(cell.y)
		ice_layers_grid[x][y] = 1
		if piece_array[x][y] != null:
			piece_array[x][y].set_ice_layers(1)
		remaining -= 1

	var safety = 0
	while remaining > 0 and safety < total_capacity * 4:
		safety += 1
		var random_cell: Vector2 = cells[randi() % cells.size()]
		var rx = int(random_cell.x)
		var ry = int(random_cell.y)
		if ice_layers_grid[rx][ry] >= max_ice_layers:
			continue
		ice_layers_grid[rx][ry] += 1
		if piece_array[rx][ry] != null:
			piece_array[rx][ry].set_ice_layers(int(ice_layers_grid[rx][ry]))
		remaining -= 1

	goal_target = requested_layers - remaining

func setup_mold_obstacles():
	var cells = collect_all_cells()
	cells.shuffle()
	var seed_count = mini(cells.size(), maxi(initial_mold_tiles, int(ceil(goal_target * 0.6))))

	for idx in range(0, seed_count):
		var cell: Vector2 = cells[idx]
		var x = int(cell.x)
		var y = int(cell.y)
		mold_grid[x][y] = 1
		if piece_array[x][y] != null:
			piece_array[x][y].set_mold(true)

	goal_target = maxi(goal_target, seed_count)

func clear_mold_at(column: int, row: int) -> bool:
	if not is_cell_active(column, row):
		return false
	var piece: Piece = piece_array[column][row]
	if piece == null or not piece.is_mold:
		return false
	var result: Dictionary = piece.take_damage()
	if bool(result.get("mold_removed", false)):
		mold_grid[column][row] = 0
		ice_layers_grid[column][row] = piece.ice_layers
		refresh_piece_obstacle_tint(column, row)
		return true
	refresh_piece_obstacle_tint(column, row)
	return false

func chip_ice_at(column: int, row: int) -> bool:
	if not is_cell_active(column, row):
		return false
	var piece: Piece = piece_array[column][row]
	if piece == null or piece.ice_layers <= 0:
		return false
	var before_layers = piece.ice_layers
	var result: Dictionary = piece.take_damage()
	if int(result.get("ice_removed", 0)) <= 0:
		return false
	ice_layers_grid[column][row] = piece.ice_layers
	if before_layers > 0 and piece.ice_layers <= 0:
		piece.just_spawned_bomb = false
	refresh_piece_obstacle_tint(column, row)
	return true

func damage_obstacle_at(column: int, row: int) -> bool:
	if not is_cell_active(column, row):
		return false
	var piece: Piece = piece_array[column][row]
	if piece == null or not piece.is_obstacle_locked():
		return false

	var result: Dictionary = piece.take_damage()
	if not bool(result.get("changed", false)):
		return false

	var removed_ice = int(result.get("ice_removed", 0))
	var removed_mold = bool(result.get("mold_removed", false))

	if level_goal_type == "clear_ice" and removed_ice > 0:
		goal_progress += removed_ice
	if level_goal_type == "clear_mold" and removed_mold:
		goal_progress += 1

	ice_layers_grid[column][row] = piece.ice_layers
	mold_grid[column][row] = 1 if piece.is_mold else 0

	if removed_mold:
		spawn_cheese_particles(piece.position, Color(0.56, 0.85, 0.5), 14, 180.0)
	if removed_ice > 0:
		spawn_cheese_particles(piece.position, Color(0.74, 0.9, 1.0), 12, 180.0)

	refresh_piece_obstacle_tint(column, row)
	return true

func spread_mold_once():
	if level_goal_type != "clear_mold":
		return
	if mold_spread_per_turn <= 0:
		return

	var candidates: Array = []
	for i in width:
		for j in height:
			if not is_cell_active(i, j):
				continue
			var piece: Piece = piece_array[i][j]
			if piece == null or not piece.is_mold:
				continue
			var neighbors = [Vector2(i + 1, j), Vector2(i - 1, j), Vector2(i, j + 1), Vector2(i, j - 1)]
			for n in neighbors:
				var nx = int(n.x)
				var ny = int(n.y)
				if not is_cell_active(nx, ny):
					continue
				var target_piece: Piece = piece_array[nx][ny]
				if target_piece == null:
					continue
				if target_piece.is_mold:
					continue
				if target_piece.is_obstacle_locked() and not target_piece.is_mold:
					continue
				if target_piece.is_bomb():
					continue
				add_cell_unique(candidates, Vector2(nx, ny))

	if candidates.size() == 0:
		return

	candidates.shuffle()
	var spread_count = mini(mold_spread_per_turn, candidates.size())
	for idx in range(0, spread_count):
		var c: Vector2 = candidates[idx]
		var cx = int(c.x)
		var cy = int(c.y)
		mold_grid[cx][cy] = 1
		if piece_array[cx][cy] != null:
			piece_array[cx][cy].set_mold(true)
		refresh_piece_obstacle_tint(cx, cy)

	if ui != null:
		ui.show_event_text("PLEŚŃ ROŚNIE!", get_viewport_rect().size * 0.5 + Vector2(-90, -10), Color(0.58, 0.9, 0.52))

func refresh_piece_obstacle_tint(column: int, row: int):
	if not is_cell_active(column, row):
		return
	var piece: Piece = piece_array[column][row]
	if piece == null:
		return

	if ice_layers_grid.size() > column and ice_layers_grid[column].size() > row:
		piece.set_ice_layers(int(ice_layers_grid[column][row]))
	if mold_grid.size() > column and mold_grid[column].size() > row:
		piece.set_mold(int(mold_grid[column][row]) > 0)

func refresh_all_piece_obstacle_tints():
	for i in width:
		for j in height:
			refresh_piece_obstacle_tint(i, j)

func get_random_base_type(column: int, row: int, avoid_start_matches: bool) -> int:
	var random_type = randi() % active_base_types
	if not avoid_start_matches:
		return random_type

	var attempts = 0
	while is_match_at_start(column, row, random_type) and attempts < 10:
		random_type = randi() % active_base_types
		attempts += 1
	return random_type

func create_cheese_sprite(column: int, row: int, type: int, force_bomb_visual: String = "", source_color_type: int = -1):
	if piece_array[column][row] != null:
		piece_array[column][row].queue_free()
		piece_array[column][row] = null
		
	var piece = Piece.new()
	var start_pos = grid_to_local(column, row)
	
	if force_bomb_visual == "row_bomb" or force_bomb_visual == "col_bomb":
		piece.setup(start_pos, CHILLI_BOMB_TYPE, chilli_cheese_texture, cell_size)
		piece.make_line_clear_visual(force_bomb_visual == "row_bomb")
		piece.just_spawned_bomb = true
	elif force_bomb_visual == "area_bomb":
		piece.setup(start_pos, CAMEMBERT_BOMB_TYPE, camembert_texture, cell_size)
		piece.make_area_bomb_visual()
		piece.just_spawned_bomb = true
	elif force_bomb_visual == "color_bomb":
		piece.setup(start_pos, MOZZARELLA_BOMB_TYPE, mozzarella_texture, cell_size)
		piece.make_color_bomb_visual()
		piece.just_spawned_bomb = true
	elif force_bomb_visual == "drop_goal":
		piece.setup(start_pos, DROP_GOAL_PIECE_TYPE, bring_down_placeholder_texture, cell_size)
		piece.make_drop_goal_visual(bring_down_placeholder_texture)
		piece.just_spawned_bomb = false
	else:
		piece.setup(start_pos, type, base_cheese_texture, cell_size)
		piece.set_base_color(base_cheese_colors[type])
		piece.just_spawned_bomb = false

	if source_color_type >= 0 and source_color_type < num_total_base_types:
		piece.set_source_color(source_color_type, base_cheese_colors[source_color_type])
		
	add_child(piece)
	piece_array[column][row] = piece
	grid[column][row] = piece.type
	refresh_piece_obstacle_tint(column, row)

func get_piece_color_type(piece: Piece) -> int:
	if piece == null:
		return -1
	if piece.type >= 0 and piece.type < num_total_base_types:
		return piece.type
	if piece.source_color_type >= 0 and piece.source_color_type < num_total_base_types:
		return piece.source_color_type
	return -1

func is_match_at_start(column: int, row: int, type: int) -> bool:
	if column >= 2:
		if grid[column - 1][row] == type and grid[column - 2][row] == type:
			return true
	if row >= 2:
		if grid[column][row - 1] == type and grid[column][row - 2] == type:
			return true
	return false

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		reset_idle_hint_timer()
	if event is InputEventKey and event.pressed and not event.echo:
		reset_idle_hint_timer()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://Scenes/level_map.tscn")
			return

		if event.keycode == KEY_F3:
			debug_enabled = not debug_enabled
			if debug_layer != null:
				debug_layer.visible = debug_enabled
			refresh_debug_menu_text()
			return

		if debug_enabled:
			if event.keycode == KEY_Q:
				debug_source_color = (debug_source_color - 1 + active_base_types) % active_base_types
				refresh_debug_menu_text()
				return
			if event.keycode == KEY_E:
				debug_source_color = (debug_source_color + 1) % active_base_types
				refresh_debug_menu_text()
				return
			if event.keycode == KEY_1:
				spawn_debug_piece("chilli")
				return
			if event.keycode == KEY_2:
				spawn_debug_piece("camembert")
				return
			if event.keycode == KEY_3:
				spawn_debug_piece("mozzarella")
				return
			if event.keycode == KEY_F4:
				spawn_debug_piece("random")
				return
			if event.keycode == KEY_F5:
				if not is_animating:
					initial_fill_board(true)
					arm_all_bombs()
				return
			if event.keycode == KEY_F6:
				arm_all_bombs()
				return
			if event.keycode == KEY_F7:
				reset_progress_and_restart_level()
				return

	if level_finished:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
				on_level_result_acknowledged()
				return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			on_level_result_acknowledged()
			return
		return

	if is_animating:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = event.position - board_origin
		if local_pos.x < 0 or local_pos.y < 0:
			return
		if local_pos.x >= width * cell_size or local_pos.y >= height * cell_size:
			return
		var column = int(local_pos.x / cell_size)
		var row = int(local_pos.y / cell_size)
		if is_cell_active(column, row):
			if is_locked_piece_at(column, row):
				first_touch = Vector2(-1, -1)
				return
			if first_touch == Vector2(-1, -1):
				first_touch = Vector2(column, row)
				if piece_array[column][row] != null:
					piece_array[column][row].base_sprite.modulate.a = 0.5
			else:
				var last_touch = Vector2(column, row)
				if is_locked_piece_at(int(first_touch.x), int(first_touch.y)) or is_locked_piece_at(int(last_touch.x), int(last_touch.y)):
					if piece_array[first_touch.x][first_touch.y] != null:
						piece_array[first_touch.x][first_touch.y].base_sprite.modulate.a = 1.0
					first_touch = Vector2(-1, -1)
					return
				if piece_array[first_touch.x][first_touch.y] != null:
					piece_array[first_touch.x][first_touch.y].base_sprite.modulate.a = 1.0
				if is_adjacent(first_touch, last_touch):
					last_swap = last_touch
					swap_pieces(first_touch, last_touch)
				first_touch = Vector2(-1, -1)

func is_in_grid(column: int, row: int) -> bool:
	return BoardGridHelper.is_in_grid(column, row, width, height)

func is_cell_active(column: int, row: int) -> bool:
	return BoardGridHelper.is_cell_active(column, row, cell_active_grid, width, height)

func is_locked_piece_at(column: int, row: int) -> bool:
	if not is_cell_active(column, row):
		return false
	var piece: Piece = piece_array[column][row]
	if piece == null:
		return false
	return piece.is_obstacle_locked() or piece.is_bring_down_target

func is_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	return BoardGridHelper.is_adjacent(pos1, pos2)

func make_2d_array() -> Array:
	return BoardGridHelper.make_2d_array(width, height)

func make_2d_int_array(default_value: int = 0) -> Array:
	return BoardGridHelper.make_2d_int_array(width, height, default_value)

func would_swap_trigger_bomb(pos1: Vector2, pos2: Vector2) -> bool:
	var p1: Piece = piece_array[int(pos1.x)][int(pos1.y)]
	var p2: Piece = piece_array[int(pos2.x)][int(pos2.y)]
	if p1 == null or p2 == null:
		return false
	if p1.is_obstacle_locked() or p2.is_obstacle_locked():
		return false

	for pair in [[p1, p2], [p2, p1]]:
		var bomb: Piece = pair[0]
		var other: Piece = pair[1]
		if not bomb.is_bomb() or bomb.just_spawned_bomb:
			continue

		if bomb.is_color_bomb:
			return true

		if bomb.is_area_bomb:
			return true

		if bomb.is_row_bomb or bomb.is_col_bomb:
			if bomb.source_color_type < 0:
				return true
			var other_color = get_piece_color_type(other)
			if other_color == bomb.source_color_type:
				return true

	return false

func would_swap_create_match(pos1: Vector2, pos2: Vector2) -> bool:
	if would_swap_trigger_bomb(pos1, pos2):
		return true

	var x1 = int(pos1.x)
	var y1 = int(pos1.y)
	var x2 = int(pos2.x)
	var y2 = int(pos2.y)

	if piece_array[x1][y1] == null or piece_array[x2][y2] == null:
		return false
	if piece_array[x1][y1].is_obstacle_locked() or piece_array[x2][y2].is_obstacle_locked():
		return false

	var temp_grid = grid[x1][y1]
	grid[x1][y1] = grid[x2][y2]
	grid[x2][y2] = temp_grid

	var temp_piece = piece_array[x1][y1]
	piece_array[x1][y1] = piece_array[x2][y2]
	piece_array[x2][y2] = temp_piece

	var has_match = find_matches().size() > 0

	temp_grid = grid[x1][y1]
	grid[x1][y1] = grid[x2][y2]
	grid[x2][y2] = temp_grid

	temp_piece = piece_array[x1][y1]
	piece_array[x1][y1] = piece_array[x2][y2]
	piece_array[x2][y2] = temp_piece

	return has_match

func has_possible_moves() -> bool:
	for i in width:
		for j in height:
			if not is_cell_active(i, j):
				continue
			if is_locked_piece_at(i, j):
				continue
			var pos = Vector2(i, j)
			var right = Vector2(i + 1, j)
			var down = Vector2(i, j + 1)

			if is_cell_active(int(right.x), int(right.y)) and not is_locked_piece_at(int(right.x), int(right.y)) and would_swap_create_match(pos, right):
				return true

			if is_cell_active(int(down.x), int(down.y)) and not is_locked_piece_at(int(down.x), int(down.y)) and would_swap_create_match(pos, down):
				return true

	return false

func ensure_board_has_possible_moves():
	var attempts = 0
	while not has_possible_moves() and attempts < max_initial_fill_attempts:
		initial_fill_board(true)
		attempts += 1

func reshuffle_if_no_moves():
	if has_possible_moves():
		return

	if ui != null:
		ui.show_event_text("Brak ruchów! Tasuję...", get_viewport_rect().size * 0.5 + Vector2(-110, -10), Color(1.0, 0.85, 0.35))

	var attempts = 0
	while not has_possible_moves() and attempts < max_initial_fill_attempts:
		initial_fill_board(true)
		attempts += 1

	arm_all_bombs()

func swap_pieces(pos1: Vector2, pos2: Vector2):
	if is_locked_piece_at(int(pos1.x), int(pos1.y)) or is_locked_piece_at(int(pos2.x), int(pos2.y)):
		is_animating = false
		is_resolving_move = false
		return

	is_animating = true
	is_resolving_move = true
	mold_spread_done_this_move = false
	cascade_depth = 0
	max_combo_in_move = 1
	var temp_type = grid[pos1.x][pos1.y]
	grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y]
	grid[pos2.x][pos2.y] = temp_type
	
	var sprite1 = piece_array[pos1.x][pos1.y]
	var sprite2 = piece_array[pos2.x][pos2.y]
	piece_array[pos1.x][pos1.y] = sprite2
	piece_array[pos2.x][pos2.y] = sprite1
	
	var tween1 = sprite1.move(sprite2.position, swap_duration)
	sprite2.move(sprite1.position, swap_duration)
	await tween1.finished

	var special_pair_matches = resolve_special_pair_combo(pos1, pos2)
	if special_pair_matches.size() > 0:
		consume_move()
		destroy_matches(special_pair_matches)
		return

	var swap_bomb_matches = get_swap_bomb_matches(pos1, pos2)
	if swap_bomb_matches.size() > 0:
		consume_move()
		destroy_matches(swap_bomb_matches)
		return
	
	var matches = find_matches()
	if matches.size() == 0:
		temp_type = grid[pos1.x][pos1.y]
		grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y]
		grid[pos2.x][pos2.y] = temp_type
		piece_array[pos1.x][pos1.y] = sprite1
		piece_array[pos2.x][pos2.y] = sprite2
		var tween_back = sprite1.move(sprite2.position, swap_back_duration)
		sprite2.move(sprite1.position, swap_back_duration)
		await tween_back.finished
		is_resolving_move = false
		cascade_depth = 0
		max_combo_in_move = 1
		is_animating = false
	else:
		var remaining_matches = check_for_bombs(matches)
		consume_move()
		destroy_matches(remaining_matches)

func add_cell_unique(cells: Array, pos: Vector2):
	var x = int(pos.x)
	var y = int(pos.y)
	if not is_in_grid(x, y):
		return
	var p = Vector2(x, y)
	if not p in cells:
		cells.append(p)

func append_row_to_cells(row: int, cells: Array):
	for k in width:
		add_cell_unique(cells, Vector2(k, row))

func append_col_to_cells(column: int, cells: Array):
	for k in height:
		add_cell_unique(cells, Vector2(column, k))

func append_area_to_cells(center: Vector2, radius: int, cells: Array):
	var cx = int(center.x)
	var cy = int(center.y)
	for ox in range(-radius, radius + 1):
		for oy in range(-radius, radius + 1):
			add_cell_unique(cells, Vector2(cx + ox, cy + oy))

func append_thick_cross_to_cells(center: Vector2, thickness: int, cells: Array):
	var cx = int(center.x)
	var cy = int(center.y)
	var half = int(thickness / 2)

	for dy in range(-half, half + 1):
		append_row_to_cells(cy + dy, cells)

	for dx in range(-half, half + 1):
		append_col_to_cells(cx + dx, cells)

func append_all_board_to_cells(cells: Array):
	for i in width:
		for j in height:
			add_cell_unique(cells, Vector2(i, j))

func get_cells_by_color(color_type: int) -> Array:
	var out: Array = []
	for i in width:
		for j in height:
			var piece: Piece = piece_array[i][j]
			if piece == null:
				continue
			if get_piece_color_type(piece) == color_type:
				out.append(Vector2(i, j))
	return out

func resolve_special_pair_combo(pos1: Vector2, pos2: Vector2) -> Array:
	var x1 = int(pos1.x)
	var y1 = int(pos1.y)
	var x2 = int(pos2.x)
	var y2 = int(pos2.y)

	if not is_in_grid(x1, y1) or not is_in_grid(x2, y2):
		return []

	var p1: Piece = piece_array[x1][y1]
	var p2: Piece = piece_array[x2][y2]
	if p1 == null or p2 == null:
		return []
	if not p1.is_bomb() or not p2.is_bomb():
		return []
	if p1.just_spawned_bomb or p2.just_spawned_bomb:
		return []

	var center = pos2
	var matches: Array = []
	add_cell_unique(matches, pos1)
	add_cell_unique(matches, pos2)

	var p1_line = p1.is_row_bomb or p1.is_col_bomb
	var p2_line = p2.is_row_bomb or p2.is_col_bomb

	if p1.is_color_bomb and p2.is_color_bomb:
		append_all_board_to_cells(matches)
		ui.show_event_text("NUKE!", to_global(grid_to_local(int(center.x), int(center.y))) + Vector2(-20, -10), Color(1.0, 0.95, 0.55))
		return matches

	if p1.is_color_bomb or p2.is_color_bomb:
		var other: Piece = p2 if p1.is_color_bomb else p1
		var target_color = other.source_color_type
		if target_color < 0:
			return []

		var targets = get_cells_by_color(target_color)
		if other.is_area_bomb:
			for cell in targets:
				append_area_to_cells(cell, 1, matches)
			ui.show_event_text("CAMEMBERT STORM!", to_global(grid_to_local(int(center.x), int(center.y))) + Vector2(-65, -12), Color(1.0, 0.82, 0.35))
		elif p2_line or p1_line:
			for cell in targets:
				if randi() % 2 == 0:
					append_row_to_cells(int(cell.y), matches)
				else:
					append_col_to_cells(int(cell.x), matches)
			ui.show_event_text("CHILLI STORM!", to_global(grid_to_local(int(center.x), int(center.y))) + Vector2(-50, -12), Color(1.0, 0.72, 0.25))
		else:
			return []

		return matches

	if p1_line and p2_line:
		append_row_to_cells(int(center.y), matches)
		append_col_to_cells(int(center.x), matches)
		ui.show_event_text("MEGA CROSS!", to_global(grid_to_local(int(center.x), int(center.y))) + Vector2(-45, -12), Color(1.0, 0.8, 0.25))
		return matches

	if p1.is_area_bomb and p2.is_area_bomb:
		append_area_to_cells(center, 2, matches)
		ui.show_event_text("MEGA BOOM!", to_global(grid_to_local(int(center.x), int(center.y))) + Vector2(-40, -12), Color(1.0, 0.72, 0.22))
		return matches

	if (p1_line and p2.is_area_bomb) or (p2_line and p1.is_area_bomb):
		append_thick_cross_to_cells(center, 3, matches)
		ui.show_event_text("GRUBY LASER!", to_global(grid_to_local(int(center.x), int(center.y))) + Vector2(-45, -12), Color(1.0, 0.78, 0.28))
		return matches

	return []

func get_swap_bomb_matches(pos1: Vector2, pos2: Vector2) -> Array:
	var matches: Array = []

	for side in [0, 1]:
		var pos = pos1 if side == 0 else pos2
		var other_pos = pos2 if side == 0 else pos1

		var x = int(pos.x)
		var y = int(pos.y)
		if not is_in_grid(x, y):
			continue

		var piece: Piece = piece_array[x][y]
		if piece == null or not piece.is_bomb() or piece.just_spawned_bomb:
			continue

		var other_piece: Piece = piece_array[int(other_pos.x)][int(other_pos.y)]
		var other_color = get_piece_color_type(other_piece)

		if piece.is_color_bomb:
			if other_color < 0:
				continue

			if not pos in matches:
				matches.append(pos)

			for i in width:
				for j in height:
					var target_piece: Piece = piece_array[i][j]
					if target_piece == null:
						continue
					if get_piece_color_type(target_piece) == other_color:
						var color_pos = Vector2(i, j)
						if not color_pos in matches:
							matches.append(color_pos)
			continue

		if (piece.is_row_bomb or piece.is_col_bomb) and piece.source_color_type >= 0:
			if other_color != piece.source_color_type:
				continue

		if not pos in matches:
			matches.append(pos)

		if piece.is_row_bomb:
			for k in width:
				var p = Vector2(k, y)
				if is_cell_active(int(p.x), int(p.y)) and not p in matches:
					matches.append(p)

		if piece.is_col_bomb:
			for k in height:
				var p = Vector2(x, k)
				if is_cell_active(int(p.x), int(p.y)) and not p in matches:
					matches.append(p)

		if piece.is_area_bomb:
			for ox in [-1, 0, 1]:
				for oy in [-1, 0, 1]:
					var p = Vector2(x + ox, y + oy)
					if is_cell_active(int(p.x), int(p.y)) and not p in matches:
						matches.append(p)

	return matches

func get_cell_match_color(column: int, row: int) -> int:
	if not is_cell_active(column, row):
		return -1

	var piece: Piece = piece_array[column][row]
	if piece == null:
		return -1
	if piece.is_obstacle_locked():
		return -1

	if piece.type >= 0 and piece.type < num_total_base_types:
		return piece.type

	if (piece.is_row_bomb or piece.is_col_bomb) and not piece.just_spawned_bomb:
		if piece.source_color_type >= 0 and piece.source_color_type < num_total_base_types:
			return piece.source_color_type

	return -1

func is_base_piece_at(column: int, row: int) -> bool:
	if not is_in_grid(column, row):
		return false
	var piece: Piece = piece_array[column][row]
	if piece == null:
		return false
	return piece.type >= 0 and piece.type < num_total_base_types

func group_contains_special(group: Array) -> bool:
	for cell in group:
		if not is_base_piece_at(int(cell.x), int(cell.y)):
			return true
	return false

func find_matches() -> Array:
	var matched = []
	for i in width:
		for j in height:
			var color = get_cell_match_color(i, j)
			if color < 0:
				continue

			if i > 0 and i < width - 1:
				if get_cell_match_color(i - 1, j) == color and get_cell_match_color(i + 1, j) == color:
					if not Vector2(i-1, j) in matched: matched.append(Vector2(i-1, j))
					if not Vector2(i, j) in matched: matched.append(Vector2(i, j))
					if not Vector2(i+1, j) in matched: matched.append(Vector2(i+1, j))

			if j > 0 and j < height - 1:
				if get_cell_match_color(i, j - 1) == color and get_cell_match_color(i, j + 1) == color:
					if not Vector2(i, j-1) in matched: matched.append(Vector2(i, j-1))
					if not Vector2(i, j) in matched: matched.append(Vector2(i, j))
					if not Vector2(i, j+1) in matched: matched.append(Vector2(i, j+1))
	return matched

func check_for_bombs(matches: Array) -> Array:
	var final_matches = matches.duplicate()
	var horizontal_groups = {}
	var vertical_groups = {}
	
	for cell in matches:
		if not horizontal_groups.has(cell.y): horizontal_groups[cell.y] = []
		horizontal_groups[cell.y].append(cell)
		if not vertical_groups.has(cell.x): vertical_groups[cell.x] = []
		vertical_groups[cell.x].append(cell)

	var bomb_pos = last_swap

	for y in horizontal_groups.keys():
		if horizontal_groups[y].size() == 5:
			if group_contains_special(horizontal_groups[y]):
				continue
			var target = bomb_pos if bomb_pos in horizontal_groups[y] else horizontal_groups[y][0]
			var source_color = get_cell_match_color(int(target.x), int(target.y))
			create_cheese_sprite(int(target.x), int(target.y), MOZZARELLA_BOMB_TYPE, "color_bomb", source_color)
			final_matches.erase(target)
			return final_matches

	for x in vertical_groups.keys():
		if vertical_groups[x].size() == 5:
			if group_contains_special(vertical_groups[x]):
				continue
			var target = bomb_pos if bomb_pos in vertical_groups[x] else vertical_groups[x][0]
			var source_color = get_cell_match_color(int(target.x), int(target.y))
			create_cheese_sprite(int(target.x), int(target.y), MOZZARELLA_BOMB_TYPE, "color_bomb", source_color)
			final_matches.erase(target)
			return final_matches
	
	for cell in matches:
		if horizontal_groups[cell.y].size() >= 3 and vertical_groups[cell.x].size() >= 3:
			if group_contains_special(horizontal_groups[cell.y]) or group_contains_special(vertical_groups[cell.x]):
				continue
			var source_color = get_cell_match_color(int(cell.x), int(cell.y))
			create_cheese_sprite(int(cell.x), int(cell.y), CAMEMBERT_BOMB_TYPE, "area_bomb", source_color)
			final_matches.erase(cell)
			return final_matches 

	for y in horizontal_groups.keys():
		if horizontal_groups[y].size() >= 4:
			if group_contains_special(horizontal_groups[y]):
				continue
			var target = bomb_pos if bomb_pos in horizontal_groups[y] else horizontal_groups[y][0]
			var source_color = get_cell_match_color(int(target.x), int(target.y))
			create_cheese_sprite(int(target.x), int(target.y), CHILLI_BOMB_TYPE, "row_bomb", source_color)
			final_matches.erase(target)
			return final_matches

	for x in vertical_groups.keys():
		if vertical_groups[x].size() >= 4:
			if group_contains_special(vertical_groups[x]):
				continue
			var target = bomb_pos if bomb_pos in vertical_groups[x] else vertical_groups[x][0]
			var source_color = get_cell_match_color(int(target.x), int(target.y))
			create_cheese_sprite(int(target.x), int(target.y), CHILLI_BOMB_TYPE, "col_bomb", source_color)
			final_matches.erase(target)
			return final_matches
				
	return final_matches

func destroy_matches(matches: Array):
	if matches.size() == 0:
		return

	cascade_depth += 1
	var combo_multiplier = maxi(1, cascade_depth)
	max_combo_in_move = maxi(max_combo_in_move, combo_multiplier)
	var processed_bombs = []
	var bombs_found = true
	
	while bombs_found:
		bombs_found = false
		var current_bombs_to_pulse = []
		
		for cell in matches:
			var x = int(cell.x)
			var y = int(cell.y)
			var piece = piece_array[x][y]
			
			if piece != null and (piece.is_row_bomb or piece.is_col_bomb or piece.is_area_bomb or piece.is_color_bomb):
				if piece.just_spawned_bomb:
					continue
				if not piece in processed_bombs:
					current_bombs_to_pulse.append(piece)
					processed_bombs.append(piece)
					bombs_found = true
		
		if current_bombs_to_pulse.size() > 0:
			var last_pulse: Tween
			for bomb in current_bombs_to_pulse:
				last_pulse = bomb.pulse()
			
			if last_pulse:
				await last_pulse.finished
			
			for bomb in current_bombs_to_pulse:
				var x = -1
				var y = -1
				for i in width:
					for j in height:
						if piece_array[i][j] == bomb:
							x = i
							y = j
				
				if x != -1:
					if bomb.is_area_bomb:
						spawn_cheese_particles(bomb.position, Color(1.0, 0.78, 0.35), 90, 480.0)
						play_audio(camembert_player, "camembert")
						trigger_camembert_shake()
						ui.show_event_text("BOOM!", to_global(bomb.position) + Vector2(-10, -10), Color(1.0, 0.55, 0.1))
					elif bomb.is_color_bomb:
						spawn_cheese_particles(bomb.position, Color(1.0, 0.9, 0.45), 120, 540.0)
						play_audio(camembert_player, "camembert")
						ui.show_event_text("MOZZARELLA!", to_global(bomb.position) + Vector2(-42, -14), Color(1.0, 0.9, 0.4))
					elif bomb.is_row_bomb or bomb.is_col_bomb:
						spawn_cheese_particles(bomb.position, Color(1.0, 0.58, 0.2), 65, 420.0)
						play_audio(chilli_player, "chilli")
						ui.show_event_text("WHOOSH!", to_global(bomb.position) + Vector2(-16, -12), Color(1.0, 0.8, 0.2))

					if bomb.is_row_bomb:
						for k in width:
							var p = Vector2(k, y)
							if is_cell_active(int(p.x), int(p.y)) and not p in matches:
								matches.append(p)
					if bomb.is_col_bomb:
						for k in height:
							var p = Vector2(x, k)
							if is_cell_active(int(p.x), int(p.y)) and not p in matches:
								matches.append(p)
					if bomb.is_area_bomb:
						for ox in [-1, 0, 1]:
							for oy in [-1, 0, 1]:
								var p = Vector2(x + ox, y + oy)
								if is_cell_active(int(p.x), int(p.y)) and not p in matches:
									matches.append(p)

	var center = get_matches_center(matches)
	if combo_multiplier >= 2:
		play_audio(combo_player, "combo")
		ui.show_combo(combo_multiplier, to_global(center) + Vector2(-30, -20))
		if combo_multiplier >= 4:
			var save_system = get_save_system()
			if save_system != null:
				save_system.mark_tutorial_seen("chilli")
		if combo_multiplier >= 5:
			var save_system_2 = get_save_system()
			if save_system_2 != null:
				save_system_2.mark_tutorial_seen("camembert")

	ui.add_score(matches.size() * 10 * combo_multiplier)
	update_goal_ui()
	var destroyed_cells: Array = []
	
	for cell in matches:
		var x = int(cell.x)
		var y = int(cell.y)
		if damage_obstacle_at(x, y):
			continue

		if piece_array[x][y] != null:
			var p = piece_array[x][y]
			if p.is_bring_down_target:
				continue
			if level_goal_type == "clear_color" and get_piece_color_type(p) == goal_color_type:
				goal_progress += 1
			var particle_color = p.base_sprite.modulate
			if p.is_area_bomb:
				particle_color = Color(1.0, 0.8, 0.35)
			elif p.is_row_bomb or p.is_col_bomb:
				particle_color = Color(1.0, 0.58, 0.2)
			spawn_cheese_particles(p.position, particle_color, 20, 230.0)

			piece_array[x][y].destroy()
			piece_array[x][y] = null
			grid[x][y] = null
			destroyed_cells.append(Vector2(x, y))

	for destroyed in destroyed_cells:
		var dx = int(destroyed.x)
		var dy = int(destroyed.y)
		var neighbors = [
			Vector2(dx + 1, dy),
			Vector2(dx - 1, dy),
			Vector2(dx, dy + 1),
			Vector2(dx, dy - 1),
		]
		for n in neighbors:
			damage_obstacle_at(int(n.x), int(n.y))

	update_goal_ui()
			
	await get_tree().create_timer(destroy_delay).timeout
	collapse_columns()

func collapse_columns():
	var has_collapsed = false
	var max_duration := 0.0
	
	for i in width:
		for j in range(height - 1, -1, -1):
			if not is_cell_active(i, j):
				continue
			if grid[i][j] == null:
				for k in range(j - 1, -1, -1):
					if not is_cell_active(i, k):
						continue
					if grid[i][k] == null:
						continue
					var source_piece: Piece = piece_array[i][k]
					if source_piece != null and source_piece.is_obstacle_locked():
						break
					if grid[i][k] != null:
						grid[i][j] = grid[i][k]
						piece_array[i][j] = piece_array[i][k]
						grid[i][k] = null
						piece_array[i][k] = null
						
						var sprite = piece_array[i][j]
						var new_pos = grid_to_local(i, j)
						var duration = collapse_step_duration * (j - k)
						sprite.move(new_pos, duration)
						max_duration = maxf(max_duration, duration)
						has_collapsed = true
						break
						
	if has_collapsed and max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout

	refresh_all_piece_obstacle_tints()
		
	refill_columns()

func refill_columns():
	var max_duration := 0.0
	
	for i in width:
		for j in range(height - 1, -1, -1):
			if not is_cell_active(i, j):
				continue
			if grid[i][j] == null:
				# Avoid placing same colors adjacent to prevent confusion at board start
				var random_type = get_random_base_type(i, j, true)
				grid[i][j] = random_type
				
				var piece = Piece.new()
				var target_pos = grid_to_local(i, j)
				var x_pos = target_pos.x
				var target_y_pos = target_pos.y
				var start_y_pos = target_y_pos - (height * cell_size) 
				
				piece.setup(Vector2(x_pos, start_y_pos), random_type, base_cheese_texture, cell_size)
				piece.set_base_color(base_cheese_colors[random_type])
				add_child(piece)
				piece_array[i][j] = piece
				
				var cells_fallen = float(target_y_pos - start_y_pos) / cell_size
				var duration = refill_step_duration * cells_fallen
				piece.move(Vector2(x_pos, target_y_pos), duration)
				max_duration = maxf(max_duration, duration)
				
	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout

	refresh_all_piece_obstacle_tints()
		
	var new_matches = find_matches()
	if new_matches.size() > 0:
		var remaining_matches = check_for_bombs(new_matches)
		destroy_matches(remaining_matches)
	else:
		if is_resolving_move and level_goal_type == "clear_mold" and not mold_spread_done_this_move and not is_goal_completed():
			spread_mold_once()
			mold_spread_done_this_move = true
			update_goal_ui()

		if trigger_goal_finish_bonus():
			return

		if process_bring_down_deliveries():
			await get_tree().create_timer(destroy_delay).timeout
			collapse_columns()
			return

		if moves_left > 0 and not is_goal_completed():
			reshuffle_if_no_moves()

		if is_resolving_move and max_combo_in_move >= 3:
			var board_center = board_origin + Vector2(width * cell_size * 0.5, height * cell_size * 0.5)
			ui.show_combo_result(max_combo_in_move, to_global(board_center))

		if is_resolving_move and moves_left <= 0:
			finish_level(is_goal_completed())
			return

		arm_all_bombs()
		is_resolving_move = false
		cascade_depth = 0
		max_combo_in_move = 1
		persist_progress(false)
		is_animating = false

func arm_all_bombs():
	for i in width:
		for j in height:
			var piece = piece_array[i][j]
			if piece != null and piece.is_bomb() and piece.just_spawned_bomb:
				piece.arm_bomb()

func get_matches_center(matches: Array) -> Vector2:
	if matches.size() == 0:
		return board_origin + Vector2(width * cell_size * 0.5, height * cell_size * 0.5)

	var sum = Vector2.ZERO
	for cell in matches:
		sum += grid_to_local(int(cell.x), int(cell.y))
	return sum / float(matches.size())

func spawn_cheese_particles(world_pos: Vector2, color: Color, amount: int = 32, velocity: float = 260.0):
	var particles = GPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.55
	particles.local_coords = false
	particles.global_position = to_global(world_pos)
	particles.texture = base_cheese_texture

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, 850, 0)
	material.initial_velocity_min = velocity * 0.55
	material.initial_velocity_max = velocity
	material.scale_min = 0.06
	material.scale_max = 0.16
	material.color = color
	particles.process_material = material

	add_child(particles)
	particles.emitting = true
	if particles.has_signal("finished"):
		particles.finished.connect(particles.queue_free)

func trigger_camembert_shake():
	if shake_tween != null:
		shake_tween.kill()

	position = board_rest_position
	shake_tween = get_tree().create_tween()
	shake_tween.tween_property(self, "position", board_rest_position + Vector2(5, -3), 0.03)
	shake_tween.tween_property(self, "position", board_rest_position + Vector2(-5, 3), 0.03)
	shake_tween.tween_property(self, "position", board_rest_position + Vector2(4, 2), 0.03)
	shake_tween.tween_property(self, "position", board_rest_position + Vector2(-3, -2), 0.03)
	shake_tween.tween_property(self, "position", board_rest_position, 0.05)
