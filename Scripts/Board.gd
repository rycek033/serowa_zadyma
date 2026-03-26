extends Node2D

@export var width: int = 8
@export var height: int = 8
@export var cell_size: int = 64
@export var min_cell_size: int = 44
@export var board_horizontal_padding: int = 24
@export var board_bottom_padding: int = 24
@export var top_ui_margin: int = 120
@export var swap_duration: float = 0.16
@export var swap_back_duration: float = 0.14
@export var collapse_step_duration: float = 0.06
@export var refill_step_duration: float = 0.06
@export var destroy_delay: float = 0.12
@export var combo_sound: AudioStream
@export var camembert_boom_sound: AudioStream
@export var chilli_whoosh_sound: AudioStream

const AUDIO_SAMPLE_RATE := 44100.0

var grid: Array = []
var piece_array: Array = []

var first_touch: Vector2 = Vector2(-1, -1)
var last_swap: Vector2 = Vector2(-1, -1)
var is_animating: bool = false
var is_resolving_move: bool = false
var cascade_depth: int = 0
var max_combo_in_move: int = 1
var board_origin: Vector2 = Vector2.ZERO
var board_rest_position: Vector2
var shake_tween: Tween
var max_cell_size: int = 64

var combo_player: AudioStreamPlayer
var camembert_player: AudioStreamPlayer
var chilli_player: AudioStreamPlayer

var base_cheese_texture = preload("res://Graphics/Cheeses/cheese.png")
var chilli_cheese_texture = preload("res://Graphics/Cheeses/chilicheese.png")
var camembert_texture = preload("res://Graphics/Cheeses/camembert.png")

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

@onready var ui = $UI

func _ready():
	randomize()
	max_cell_size = cell_size
	board_rest_position = position
	setup_audio_players()
	update_board_layout()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	grid = make_2d_array()
	piece_array = make_2d_array()
	spawn_cheeses()

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

func make_2d_array() -> Array:
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

func spawn_cheeses():
	for i in width:
		for j in height:
			var random_type = randi() % num_total_base_types
			while is_match_at_start(i, j, random_type):
				random_type = randi() % num_total_base_types
			grid[i][j] = random_type
			create_cheese_sprite(i, j, random_type)

func create_cheese_sprite(column: int, row: int, type: int, force_bomb_visual: String = ""):
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
	else:
		piece.setup(start_pos, type, base_cheese_texture, cell_size)
		piece.base_sprite.modulate = base_cheese_colors[type]
		piece.just_spawned_bomb = false
		
	add_child(piece)
	piece_array[column][row] = piece
	grid[column][row] = piece.type

func is_match_at_start(column: int, row: int, type: int) -> bool:
	if column >= 2:
		if grid[column - 1][row] == type and grid[column - 2][row] == type:
			return true
	if row >= 2:
		if grid[column][row - 1] == type and grid[column][row - 2] == type:
			return true
	return false

func _input(event):
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
		if is_in_grid(column, row):
			if first_touch == Vector2(-1, -1):
				first_touch = Vector2(column, row)
				if piece_array[column][row] != null:
					piece_array[column][row].base_sprite.modulate.a = 0.5
			else:
				var last_touch = Vector2(column, row)
				if piece_array[first_touch.x][first_touch.y] != null:
					piece_array[first_touch.x][first_touch.y].base_sprite.modulate.a = 1.0
				if is_adjacent(first_touch, last_touch):
					last_swap = last_touch
					swap_pieces(first_touch, last_touch)
				first_touch = Vector2(-1, -1)

func is_in_grid(column: int, row: int) -> bool:
	return column >= 0 and column < width and row >= 0 and row < height

func is_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var difference = pos1 - pos2
	return abs(difference.x) + abs(difference.y) == 1

func swap_pieces(pos1: Vector2, pos2: Vector2):
	is_animating = true
	is_resolving_move = true
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

	var swap_bomb_matches = get_swap_bomb_matches(pos1, pos2)
	if swap_bomb_matches.size() > 0:
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
		destroy_matches(remaining_matches)

func get_swap_bomb_matches(pos1: Vector2, pos2: Vector2) -> Array:
	var matches: Array = []
	for pos in [pos1, pos2]:
		var x = int(pos.x)
		var y = int(pos.y)
		if not is_in_grid(x, y):
			continue
		var piece = piece_array[x][y]
		if piece == null:
			continue
		if not piece.is_bomb() or piece.just_spawned_bomb:
			continue

		if not pos in matches:
			matches.append(pos)

		if piece.is_row_bomb:
			for k in width:
				var p = Vector2(k, y)
				if not p in matches:
					matches.append(p)

		if piece.is_col_bomb:
			for k in height:
				var p = Vector2(x, k)
				if not p in matches:
					matches.append(p)

		if piece.is_area_bomb:
			for ox in [-1, 0, 1]:
				for oy in [-1, 0, 1]:
					var p = Vector2(x + ox, y + oy)
					if is_in_grid(p.x, p.y) and not p in matches:
						matches.append(p)

	return matches

func find_matches() -> Array:
	var matched = []
	for i in width:
		for j in height:
			if grid[i][j] != null:
				var color = grid[i][j]
				if i > 0 and i < width - 1:
					if grid[i-1][j] == color and grid[i+1][j] == color:
						if not Vector2(i-1, j) in matched: matched.append(Vector2(i-1, j))
						if not Vector2(i, j) in matched: matched.append(Vector2(i, j))
						if not Vector2(i+1, j) in matched: matched.append(Vector2(i+1, j))
				if j > 0 and j < height - 1:
					if grid[i][j-1] == color and grid[i][j+1] == color:
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
	
	for cell in matches:
		if horizontal_groups[cell.y].size() >= 3 and vertical_groups[cell.x].size() >= 3:
			create_cheese_sprite(cell.x, cell.y, CAMEMBERT_BOMB_TYPE, "area_bomb")
			final_matches.erase(cell)
			return final_matches 

	for y in horizontal_groups.keys():
		if horizontal_groups[y].size() >= 4:
			var target = bomb_pos if bomb_pos in horizontal_groups[y] else horizontal_groups[y][0]
			create_cheese_sprite(target.x, target.y, CHILLI_BOMB_TYPE, "row_bomb")
			final_matches.erase(target)
			return final_matches

	for x in vertical_groups.keys():
		if vertical_groups[x].size() >= 4:
			var target = bomb_pos if bomb_pos in vertical_groups[x] else vertical_groups[x][0]
			create_cheese_sprite(target.x, target.y, CHILLI_BOMB_TYPE, "col_bomb")
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
			
			if piece != null and (piece.is_row_bomb or piece.is_col_bomb or piece.is_area_bomb):
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
					elif bomb.is_row_bomb or bomb.is_col_bomb:
						spawn_cheese_particles(bomb.position, Color(1.0, 0.58, 0.2), 65, 420.0)
						play_audio(chilli_player, "chilli")
						ui.show_event_text("WHOOSH!", to_global(bomb.position) + Vector2(-16, -12), Color(1.0, 0.8, 0.2))

					if bomb.is_row_bomb:
						for k in width:
							var p = Vector2(k, y)
							if not p in matches: matches.append(p)
					if bomb.is_col_bomb:
						for k in height:
							var p = Vector2(x, k)
							if not p in matches: matches.append(p)
					if bomb.is_area_bomb:
						for ox in [-1, 0, 1]:
							for oy in [-1, 0, 1]:
								var p = Vector2(x + ox, y + oy)
								if is_in_grid(p.x, p.y) and not p in matches:
									matches.append(p)

	var center = get_matches_center(matches)
	if combo_multiplier >= 2:
		play_audio(combo_player, "combo")
		ui.show_combo(combo_multiplier, to_global(center) + Vector2(-30, -20))

	ui.add_score(matches.size() * 10 * combo_multiplier)
	
	for cell in matches:
		var x = int(cell.x)
		var y = int(cell.y)
		if piece_array[x][y] != null:
			var p = piece_array[x][y]
			var particle_color = p.base_sprite.modulate
			if p.is_area_bomb:
				particle_color = Color(1.0, 0.8, 0.35)
			elif p.is_row_bomb or p.is_col_bomb:
				particle_color = Color(1.0, 0.58, 0.2)
			spawn_cheese_particles(p.position, particle_color, 20, 230.0)

			piece_array[x][y].destroy()
			piece_array[x][y] = null
			grid[x][y] = null
			
	await get_tree().create_timer(destroy_delay).timeout
	collapse_columns()

func collapse_columns():
	var has_collapsed = false
	var max_duration := 0.0
	
	for i in width:
		for j in range(height - 1, -1, -1):
			if grid[i][j] == null:
				for k in range(j - 1, -1, -1):
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
		
	refill_columns()

func refill_columns():
	var max_duration := 0.0
	
	for i in width:
		for j in range(height - 1, -1, -1):
			if grid[i][j] == null:
				var random_type = randi() % num_total_base_types
				grid[i][j] = random_type
				
				var piece = Piece.new()
				var target_pos = grid_to_local(i, j)
				var x_pos = target_pos.x
				var target_y_pos = target_pos.y
				var start_y_pos = target_y_pos - (height * cell_size) 
				
				piece.setup(Vector2(x_pos, start_y_pos), random_type, base_cheese_texture, cell_size)
				piece.base_sprite.modulate = base_cheese_colors[random_type]
				add_child(piece)
				piece_array[i][j] = piece
				
				var cells_fallen = float(target_y_pos - start_y_pos) / cell_size
				var duration = refill_step_duration * cells_fallen
				piece.move(Vector2(x_pos, target_y_pos), duration)
				max_duration = maxf(max_duration, duration)
				
	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout
		
	var new_matches = find_matches()
	if new_matches.size() > 0:
		var remaining_matches = check_for_bombs(new_matches)
		destroy_matches(remaining_matches)
	else:
		if is_resolving_move and max_combo_in_move >= 3:
			var board_center = board_origin + Vector2(width * cell_size * 0.5, height * cell_size * 0.5)
			ui.show_combo_result(max_combo_in_move, to_global(board_center))
		arm_all_bombs()
		is_resolving_move = false
		cascade_depth = 0
		max_combo_in_move = 1
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
