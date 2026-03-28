extends CanvasLayer

var score: int = 0
var score_label: Label
var moves_label: Label
var goal_label: Label
var result_overlay: ColorRect
var result_panel: Panel
var result_title: Label
var result_details: Label
var result_hint: Label
var result_tween: Tween
var tutorial_panel: Panel
var tutorial_title: Label
var tutorial_body: Label
var combo_banner_label: Label
var combo_banner_tween: Tween

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

	moves_label = Label.new()
	moves_label.add_theme_font_size_override("font_size", 32)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.text = "Ruchy: 0"
	add_child(moves_label)

	goal_label = Label.new()
	goal_label.add_theme_font_size_override("font_size", 28)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.text = "Cel: -"
	add_child(goal_label)

	_setup_level_result_popup()
	_setup_tutorial_popup()

	update_layout(get_viewport().get_visible_rect().size)

func _setup_tutorial_popup():
	tutorial_panel = Panel.new()
	tutorial_panel.visible = false
	tutorial_panel.modulate = Color(1, 1, 1, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.97, 0.82, 0.25, 0.85)
	tutorial_panel.add_theme_stylebox_override("panel", style)
	add_child(tutorial_panel)

	tutorial_title = Label.new()
	tutorial_title.position = Vector2(14, 10)
	tutorial_title.size = Vector2(292, 34)
	tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tutorial_title.add_theme_font_size_override("font_size", 24)
	tutorial_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	tutorial_panel.add_child(tutorial_title)

	tutorial_body = Label.new()
	tutorial_body.position = Vector2(14, 44)
	tutorial_body.size = Vector2(292, 74)
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.add_theme_font_size_override("font_size", 20)
	tutorial_body.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	tutorial_panel.add_child(tutorial_body)

func _setup_level_result_popup():
	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_overlay)

	result_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.07, 0.96)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.78, 0.28, 0.85)
	result_panel.add_theme_stylebox_override("panel", style)
	result_panel.size = Vector2(560, 340)
	result_panel.modulate = Color(1, 1, 1, 0.0)
	result_panel.scale = Vector2(0.9, 0.9)
	result_overlay.add_child(result_panel)

	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_title.position = Vector2(28, 26)
	result_title.size = Vector2(result_panel.size.x - 56, 110)
	result_title.add_theme_font_size_override("font_size", 50)
	result_title.add_theme_constant_override("outline_size", 10)
	result_title.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.95))
	result_panel.add_child(result_title)

	result_details = Label.new()
	result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_details.position = Vector2(28, 145)
	result_details.size = Vector2(result_panel.size.x - 56, 120)
	result_details.add_theme_font_size_override("font_size", 38)
	result_panel.add_child(result_details)

	result_hint = Label.new()
	result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_hint.position = Vector2(28, 278)
	result_hint.size = Vector2(result_panel.size.x - 56, 40)
	result_hint.add_theme_font_size_override("font_size", 22)
	result_hint.modulate = Color(1, 1, 1, 0.7)
	result_hint.text = "Dobra robota!"
	result_panel.add_child(result_hint)

func update_layout(viewport_size: Vector2, board_origin: Vector2 = Vector2.ZERO, board_pixel_size: Vector2 = Vector2.ZERO):
	if score_label == null:
		return
	if moves_label == null or goal_label == null or result_overlay == null or tutorial_panel == null:
		return

	var score_y = 24.0
	if board_pixel_size != Vector2.ZERO:
		score_y = board_origin.y + board_pixel_size.y + 18.0

	score_label.position = Vector2(0, score_y)
	score_label.size = Vector2(viewport_size.x, 56)

	goal_label.position = Vector2(0, 20)
	goal_label.size = Vector2(viewport_size.x, 42)

	moves_label.position = Vector2(0, 58)
	moves_label.size = Vector2(viewport_size.x, 42)

	result_overlay.position = Vector2.ZERO
	result_overlay.size = viewport_size

	var panel_width = clampf(viewport_size.x * 0.88, 360.0, 560.0)
	var panel_height = 340.0
	result_panel.size = Vector2(panel_width, panel_height)

	result_panel.position = Vector2(
		(viewport_size.x - result_panel.size.x) * 0.5,
		(viewport_size.y - result_panel.size.y) * 0.5
	)

	result_title.size = Vector2(result_panel.size.x - 56, 110)
	result_details.size = Vector2(result_panel.size.x - 56, 120)
	result_hint.size = Vector2(result_panel.size.x - 56, 40)

	if tutorial_panel.visible:
		tutorial_panel.position.x = clampf(tutorial_panel.position.x, 10.0, viewport_size.x - tutorial_panel.size.x - 10.0)
		tutorial_panel.position.y = clampf(tutorial_panel.position.y, 10.0, viewport_size.y - tutorial_panel.size.y - 10.0)

func add_score(points: int):
	score += points
	score_label.text = "Wynik: " + str(score)

func reset_score(new_value: int = 0):
	score = max(0, new_value)
	score_label.text = "Wynik: " + str(score)

func set_moves_left(value: int):
	moves_label.text = "Ruchy: " + str(maxi(0, value))

func set_goal_text(text: String):
	goal_label.text = text

func show_level_result(win: bool, stars: int, final_score: int):
	if result_overlay == null or result_panel == null:
		return
	if result_tween != null:
		result_tween.kill()

	var header = "POZIOM UKOŃCZONY!" if win else "KONIEC RUCHÓW"
	var color = Color(1.0, 0.9, 0.35) if win else Color(1.0, 0.45, 0.35)

	result_title.text = header
	result_title.modulate = color
	result_details.text = "Gwiazdki: " + str(stars) + "\nWynik: " + str(final_score)
	result_hint.text = "Tapnij, aby kontynuować" if win else "Spróbuj ponownie"

	result_overlay.visible = true
	result_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	result_panel.modulate = Color(1, 1, 1, 0.0)
	result_panel.scale = Vector2(0.9, 0.9)

	result_tween = get_tree().create_tween()
	result_tween.set_parallel(true)
	result_tween.tween_property(result_overlay, "color:a", 0.62, 0.2).set_trans(Tween.TRANS_SINE)
	result_tween.tween_property(result_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	result_tween.tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_level_result():
	if result_tween != null:
		result_tween.kill()
		result_tween = null
	if result_overlay != null:
		result_overlay.visible = false

func show_tutorial_hint(title: String, body: String, anchor_screen_pos: Vector2):
	if tutorial_panel == null:
		return

	tutorial_title.text = title
	tutorial_body.text = body
	tutorial_panel.size = Vector2(320, 126)
	tutorial_panel.position = anchor_screen_pos + Vector2(-160, -150)
	var viewport_size = get_viewport().get_visible_rect().size
	tutorial_panel.position.x = clampf(tutorial_panel.position.x, 10.0, viewport_size.x - tutorial_panel.size.x - 10.0)
	tutorial_panel.position.y = clampf(tutorial_panel.position.y, 10.0, viewport_size.y - tutorial_panel.size.y - 10.0)
	tutorial_panel.visible = true

	var tween = get_tree().create_tween()
	tutorial_panel.modulate = Color(1, 1, 1, 0)
	tween.tween_property(tutorial_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

func hide_tutorial_hint():
	if tutorial_panel != null:
		tutorial_panel.visible = false

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
	if combo_banner_tween != null:
		combo_banner_tween.kill()

	if combo_banner_label != null and is_instance_valid(combo_banner_label):
		combo_banner_label.queue_free()

	combo_banner_label = Label.new()
	combo_banner_label.text = text
	combo_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_banner_label.position = Vector2(0, viewport_size.y * 0.42)
	combo_banner_label.size = Vector2(viewport_size.x, 120)
	combo_banner_label.modulate = Color(color.r, color.g, color.b, 0.0)
	combo_banner_label.add_theme_font_size_override("font_size", 76)
	combo_banner_label.add_theme_constant_override("outline_size", 12)
	combo_banner_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
	combo_banner_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	combo_banner_label.add_theme_constant_override("shadow_offset_x", 3)
	combo_banner_label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(combo_banner_label)

	combo_banner_tween = get_tree().create_tween()
	combo_banner_tween.tween_property(combo_banner_label, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE)
	combo_banner_tween.tween_interval(0.55)
	combo_banner_tween.tween_property(combo_banner_label, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	await combo_banner_tween.finished

	if combo_banner_label != null and is_instance_valid(combo_banner_label):
		combo_banner_label.queue_free()
	combo_banner_label = null
	combo_banner_tween = null

func show_event_text(text: String, pos: Vector2, color: Color = Color(1.0, 0.7, 0.2)):
	_spawn_floating_text(text, pos, color, 32)
