extends Node2D
class_name Piece

var type: int
var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_area_bomb: bool = false
var is_color_bomb: bool = false
var just_spawned_bomb: bool = false
var source_color_type: int = -1
var is_bring_down_target: bool = false
var is_drop_goal_piece: bool = false
var ice_layers: int = 0
var is_mold: bool = false
var last_cell_size: int = 64
var saved_base_texture: Texture2D
var saved_base_modulate: Color = Color.WHITE
var mold_texture_cache: Texture2D

var outline_sprite: Sprite2D
var base_sprite: Sprite2D
var indicator_sprite: Sprite2D
var goal_marker_sprite: Sprite2D
var ice_overlay_sprite: Sprite2D

func _init():
	outline_sprite = Sprite2D.new()
	outline_sprite.visible = false
	outline_sprite.z_index = -1
	add_child(outline_sprite)

	base_sprite = Sprite2D.new()
	add_child(base_sprite)

	ice_overlay_sprite = Sprite2D.new()
	add_child(ice_overlay_sprite)
	ice_overlay_sprite.visible = false
	ice_overlay_sprite.modulate = Color(0.72, 0.88, 1.0, 0.42)
	ice_overlay_sprite.z_index = 2
	
	indicator_sprite = Sprite2D.new()
	add_child(indicator_sprite)
	indicator_sprite.visible = false
	indicator_sprite.texture = preload("res://Graphics/Cheeses/indicator.png")
	indicator_sprite.scale = Vector2(0.2, 0.2)

	goal_marker_sprite = Sprite2D.new()
	add_child(goal_marker_sprite)
	goal_marker_sprite.visible = false
	goal_marker_sprite.texture = preload("res://Graphics/Cheeses/indicator.png")
	goal_marker_sprite.modulate = Color(0.4, 0.9, 1.0, 0.95)
	goal_marker_sprite.position = Vector2(0, -16)
	goal_marker_sprite.rotation_degrees = 180

func setup(start_pos: Vector2, c_type: int, cheese_texture: Texture2D, size: int):
	position = start_pos
	type = c_type
	last_cell_size = size
	saved_base_texture = cheese_texture
	saved_base_modulate = Color.WHITE
	outline_sprite.texture = cheese_texture
	base_sprite.texture = cheese_texture
	ice_overlay_sprite.texture = cheese_texture
	rescale_to_size(size)

func rescale_to_size(size: int):
	last_cell_size = size
	if base_sprite.texture == null:
		return

	var scale_factor = float(size) / base_sprite.texture.get_width()
	base_sprite.scale = Vector2(scale_factor, scale_factor)
	outline_sprite.scale = Vector2(scale_factor * 1.18, scale_factor * 1.18)
	ice_overlay_sprite.scale = Vector2(scale_factor * 1.03, scale_factor * 1.03)

	var indicator_scale = 0.2 * (float(size) / 64.0)
	indicator_sprite.scale = Vector2(indicator_scale, indicator_scale)
	goal_marker_sprite.scale = Vector2(indicator_scale * 0.75, indicator_scale * 0.75)

func set_bring_down_target(enabled: bool):
	is_bring_down_target = enabled
	goal_marker_sprite.visible = enabled
	is_drop_goal_piece = enabled

func make_drop_goal_visual(placeholder_texture: Texture2D):
	is_bring_down_target = true
	is_drop_goal_piece = true
	just_spawned_bomb = false
	is_row_bomb = false
	is_col_bomb = false
	is_area_bomb = false
	is_color_bomb = false
	source_color_type = -1
	indicator_sprite.visible = false
	outline_sprite.visible = false
	goal_marker_sprite.visible = false

	if placeholder_texture != null:
		saved_base_texture = placeholder_texture
		base_sprite.texture = placeholder_texture

	saved_base_modulate = Color(1, 1, 1, 1)
	base_sprite.modulate = saved_base_modulate
	rescale_to_size(last_cell_size)
	update_obstacle_visuals()

func make_line_clear_visual(vertical: bool):
	indicator_sprite.visible = true
	indicator_sprite.modulate = Color(1, 1, 1, 0.7)
	if vertical:
		is_row_bomb = true
		indicator_sprite.rotation_degrees = 0
	else:
		is_col_bomb = true
		indicator_sprite.rotation_degrees = 90

func make_area_bomb_visual():
	is_area_bomb = true

func make_color_bomb_visual():
	is_color_bomb = true
	indicator_sprite.visible = true
	indicator_sprite.rotation_degrees = 45
	indicator_sprite.modulate = Color(1, 1, 1, 0.75)

func set_base_color(color: Color):
	saved_base_modulate = color
	if not is_mold:
		base_sprite.modulate = color
	update_obstacle_visuals()

func set_source_color(color_type: int, color: Color):
	source_color_type = color_type

	if is_row_bomb or is_col_bomb:
		outline_sprite.visible = true
		outline_sprite.modulate = Color(color.r, color.g, color.b, 0.95)
		indicator_sprite.modulate = Color(1, 1, 1, 0.95)
		base_sprite.modulate = Color(1, 1, 1, 1)
	elif is_area_bomb:
		outline_sprite.visible = false
		base_sprite.modulate = Color(1, 1, 1, 1).lerp(color, 0.45)
	elif is_color_bomb:
		outline_sprite.visible = false
		base_sprite.modulate = Color(1, 1, 1, 1).lerp(color, 0.55)
		indicator_sprite.modulate = Color(color.r, color.g, color.b, 0.8)

	saved_base_modulate = base_sprite.modulate
	update_obstacle_visuals()

func set_ice_layers(layers: int):
	ice_layers = maxi(0, layers)
	update_obstacle_visuals()

func set_mold(enabled: bool):
	if enabled == is_mold:
		update_obstacle_visuals()
		return

	is_mold = enabled
	if is_mold:
		saved_base_texture = base_sprite.texture
		saved_base_modulate = base_sprite.modulate
	else:
		if saved_base_texture != null:
			base_sprite.texture = saved_base_texture
		base_sprite.modulate = saved_base_modulate

	update_obstacle_visuals()

func is_obstacle_locked() -> bool:
	return ice_layers > 0 or is_mold

func take_damage(amount: int = 1) -> Dictionary:
	var result := {
		"changed": false,
		"ice_removed": 0,
		"mold_removed": false,
	}

	if is_mold:
		set_mold(false)
		result["changed"] = true
		result["mold_removed"] = true
		return result

	if ice_layers > 0:
		var before = ice_layers
		set_ice_layers(maxi(0, ice_layers - maxi(1, amount)))
		var removed = before - ice_layers
		if removed > 0:
			result["changed"] = true
			result["ice_removed"] = removed

	return result

func update_obstacle_visuals():
	if is_mold:
		if mold_texture_cache == null:
			mold_texture_cache = load("res://Graphics/Cheeses/mold.png") as Texture2D
		if mold_texture_cache != null:
			base_sprite.texture = mold_texture_cache
			base_sprite.modulate = Color(1, 1, 1, 1)
		else:
			if saved_base_texture != null:
				base_sprite.texture = saved_base_texture
			base_sprite.modulate = saved_base_modulate.lerp(Color(0.46, 0.72, 0.36), 0.55)
		rescale_to_size(last_cell_size)
	else:
		if saved_base_texture != null:
			base_sprite.texture = saved_base_texture
		base_sprite.modulate = saved_base_modulate

	if ice_overlay_sprite != null:
		ice_overlay_sprite.visible = ice_layers > 0
		if ice_layers > 0:
			ice_overlay_sprite.texture = saved_base_texture if saved_base_texture != null else base_sprite.texture
			var alpha = clampf(0.25 + float(ice_layers) * 0.2, 0.28, 0.72)
			ice_overlay_sprite.modulate = Color(0.72, 0.88, 1.0, alpha)

func is_bomb() -> bool:
	return is_row_bomb or is_col_bomb or is_area_bomb or is_color_bomb

func arm_bomb():
	just_spawned_bomb = false

func pulse():
	var tween = get_tree().create_tween()
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 1.3, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", original_scale * 0.9, 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", original_scale, 0.1).set_trans(Tween.TRANS_SINE)
	return tween

func move(target_pos: Vector2, duration: float) -> Tween:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func destroy():
	outline_sprite.visible = false
	base_sprite.visible = false
	ice_overlay_sprite.visible = false
	indicator_sprite.visible = false
	goal_marker_sprite.visible = false
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free).set_delay(0.15)
