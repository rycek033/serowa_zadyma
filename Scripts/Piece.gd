extends Node2D
class_name Piece

var type: int
var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_area_bomb: bool = false
var is_color_bomb: bool = false
var just_spawned_bomb: bool = false
var source_color_type: int = -1

var outline_sprite: Sprite2D
var base_sprite: Sprite2D
var indicator_sprite: Sprite2D

func _init():
	outline_sprite = Sprite2D.new()
	outline_sprite.visible = false
	outline_sprite.z_index = -1
	add_child(outline_sprite)

	base_sprite = Sprite2D.new()
	add_child(base_sprite)
	
	indicator_sprite = Sprite2D.new()
	add_child(indicator_sprite)
	indicator_sprite.visible = false
	indicator_sprite.texture = preload("res://Graphics/Cheeses/indicator.png")
	indicator_sprite.scale = Vector2(0.2, 0.2)

func setup(start_pos: Vector2, c_type: int, cheese_texture: Texture2D, size: int):
	position = start_pos
	type = c_type
	outline_sprite.texture = cheese_texture
	base_sprite.texture = cheese_texture
	rescale_to_size(size)

func rescale_to_size(size: int):
	if base_sprite.texture == null:
		return

	var scale_factor = float(size) / base_sprite.texture.get_width()
	base_sprite.scale = Vector2(scale_factor, scale_factor)
	outline_sprite.scale = Vector2(scale_factor * 1.18, scale_factor * 1.18)

	var indicator_scale = 0.2 * (float(size) / 64.0)
	indicator_sprite.scale = Vector2(indicator_scale, indicator_scale)

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
	indicator_sprite.visible = false
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free).set_delay(0.15)
