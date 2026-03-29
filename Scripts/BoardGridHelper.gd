extends Node
class_name BoardGridHelper

# Grid utility functions extracted from Board.gd for clarity

static func is_in_grid(column: int, row: int, width: int, height: int) -> bool:
	return column >= 0 and column < width and row >= 0 and row < height

static func is_cell_active(column: int, row: int, cell_active_grid: Array, width: int, height: int) -> bool:
	if not is_in_grid(column, row, width, height):
		return false
	if cell_active_grid.is_empty():
		return true
	if cell_active_grid.size() <= column or cell_active_grid[column].size() <= row:
		return false
	return int(cell_active_grid[column][row]) > 0

static func is_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var difference = pos1 - pos2
	return abs(difference.x) + abs(difference.y) == 1

static func make_2d_array(width: int, height: int) -> Array:
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

static func make_2d_int_array(width: int, height: int, default_value: int = 0) -> Array:
	var array: Array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(default_value)
	return array

static func get_cell_match_color(column: int, row: int, piece_array: Array, grid: Array, num_total_base_types: int) -> int:
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

static func get_piece_color_type(piece: Piece, num_total_base_types: int) -> int:
	if piece == null:
		return -1
	if piece.type >= 0 and piece.type < num_total_base_types:
		return piece.type
	if piece.source_color_type >= 0 and piece.source_color_type < num_total_base_types:
		return piece.source_color_type
	return -1

static func add_cell_unique(cells: Array, pos: Vector2):
	var x = int(pos.x)
	var y = int(pos.y)
	var p = Vector2(x, y)
	if not p in cells:
		cells.append(p)

static func append_row_to_cells(row: int, cells: Array, width: int):
	for k in width:
		add_cell_unique(cells, Vector2(k, row))

static func append_col_to_cells(column: int, cells: Array, height: int):
	for k in height:
		add_cell_unique(cells, Vector2(column, k))

static func append_area_to_cells(center: Vector2, radius: int, cells: Array, width: int, height: int):
	var cx = int(center.x)
	var cy = int(center.y)
	for ox in range(-radius, radius + 1):
		for oy in range(-radius, radius + 1):
			add_cell_unique(cells, Vector2(cx + ox, cy + oy))

static func append_all_board_to_cells(cells: Array, width: int, height: int):
	for i in width:
		for j in height:
			add_cell_unique(cells, Vector2(i, j))

static func append_thick_cross_to_cells(center: Vector2, thickness: int, cells: Array, width: int, height: int):
	var cx = int(center.x)
	var cy = int(center.y)
	var half = int(thickness / 2)

	for dy in range(-half, half + 1):
		append_row_to_cells(cy + dy, cells, width)

	for dx in range(-half, half + 1):
		append_col_to_cells(cx + dx, cells, height)

static func get_cells_by_color(color_type: int, piece_array: Array, width: int, height: int, num_total_base_types: int) -> Array:
	var out: Array = []
	for i in width:
		for j in height:
			var piece: Piece = piece_array[i][j]
			if piece == null:
				continue
			if get_piece_color_type(piece, num_total_base_types) == color_type:
				out.append(Vector2(i, j))
	return out
