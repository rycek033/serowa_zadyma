extends CanvasLayer

var score: int = 0
var score_label: Label

func _spawn_floating_text(text: String, pos: Vector2, color: Color, size: int = 36):
	var label = Label.new()
	label.text = text
	label.position = pos
	label.modulate = color
	label.add_theme_font_size_override("font_size", size)
	add_child(label)

	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", pos + Vector2(0, -55), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	await tween.finished
	label.queue_free()

func _ready():
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.text = "Wynik: 0"
	add_child(score_label)
	update_layout(get_viewport().get_visible_rect().size)

func update_layout(viewport_size: Vector2, board_origin: Vector2 = Vector2.ZERO, board_pixel_size: Vector2 = Vector2.ZERO):
	if score_label == null:
		return

	var score_y = 24.0
	if board_pixel_size != Vector2.ZERO:
		score_y = board_origin.y + board_pixel_size.y + 18.0

	score_label.position = Vector2(0, score_y)
	score_label.size = Vector2(viewport_size.x, 56)

func add_score(points: int):
	score += points
	score_label.text = "Wynik: " + str(score)

func show_combo(multiplier: int, pos: Vector2):
	if multiplier < 2:
		return
	_spawn_floating_text("x" + str(multiplier), pos, Color(1.0, 0.9, 0.25), 40)

func show_combo_result(multiplier: int, pos: Vector2):
	if multiplier < 3:
		return

	var text = "BOOM!"
	var color = Color(1.0, 0.65, 0.2)

	if multiplier >= 5:
		text = "SEROWA ZADYMA!"
		color = Color(1.0, 0.35, 0.15)
	elif multiplier >= 4:
		text = "CHEESE FRENZY!"
		color = Color(1.0, 0.45, 0.15)

	_spawn_centered_combo_banner(text, color)

func _spawn_centered_combo_banner(text: String, color: Color):
	var viewport_size = get_viewport().get_visible_rect().size
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, viewport_size.y * 0.42)
	label.size = Vector2(viewport_size.x, 120)
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.add_theme_font_size_override("font_size", 76)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(label)

	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.65).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished
	label.queue_free()

func show_event_text(text: String, pos: Vector2, color: Color = Color(1.0, 0.7, 0.2)):
	_spawn_floating_text(text, pos, color, 32)
