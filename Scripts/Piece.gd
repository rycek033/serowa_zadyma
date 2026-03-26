extends Node2D
class_name Piece

var type: int
var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_area_bomb: bool = false
var just_spawned_bomb: bool = false

var base_sprite: Sprite2D
var indicator_sprite: Sprite2D

func _init():
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
	base_sprite.texture = cheese_texture
	rescale_to_size(size)

func rescale_to_size(size: int):
	if base_sprite.texture == null:
		return

	var scale_factor = float(size) / base_sprite.texture.get_width()
	base_sprite.scale = Vector2(scale_factor, scale_factor)

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

func is_bomb() -> bool:
	return is_row_bomb or is_col_bomb or is_area_bomb

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
	base_sprite.visible = false
	indicator_sprite.visible = false
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free).set_delay(0.15)
