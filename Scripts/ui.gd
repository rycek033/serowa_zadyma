extends CanvasLayer

var score: int = 0
var score_label: Label
var moves_label: Label
var goal_label: Label
var stars_container: HBoxContainer
var star_labels: Array[Label] = []
var star_thresholds: Array[int] = [600, 1400, 2600]
var result_overlay: ColorRect
var result_panel: Panel
var result_title: Label
var result_details: Label
var result_hint: Label
var result_tween: Tween
var tutorial_panel: Panel
var tutorial_title: Label
var tutorial_body: Label
var tutorial_marker_a: Panel
var tutorial_marker_b: Panel
var hint_marker_a: Panel
var hint_marker_b: Panel
var board_origin_cached: Vector2 = Vector2.ZERO
var board_pixel_size_cached: Vector2 = Vector2.ZERO
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

	stars_container = HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_theme_constant_override("separation", 14)
	add_child(stars_container)

	for i in 3:
		var star = Label.new()
		star.text = "★"
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.add_theme_font_size_override("font_size", 36)
		stars_container.add_child(star)
		star_labels.append(star)

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
	tutorial_body.size = Vector2(332, 112)
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.add_theme_font_size_override("font_size", 20)
	tutorial_body.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	tutorial_panel.add_child(tutorial_body)

	tutorial_marker_a = _create_flash_marker(Color(1.0, 0.85, 0.25, 1.0))
	tutorial_marker_b = _create_flash_marker(Color(1.0, 0.85, 0.25, 1.0))
	add_child(tutorial_marker_a)
	add_child(tutorial_marker_b)

	hint_marker_a = _create_flash_marker(Color(0.55, 0.95, 1.0, 1.0))
	hint_marker_b = _create_flash_marker(Color(0.55, 0.95, 1.0, 1.0))
	add_child(hint_marker_a)
	add_child(hint_marker_b)

func _create_flash_marker(color: Color) -> Panel:
	var marker = Panel.new()
	marker.visible = false
	marker.size = Vector2(56, 56)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.08)
	style.border_color = color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	marker.add_theme_stylebox_override("panel", style)
	return marker

func _process(_delta: float):
	var t = Time.get_ticks_msec() * 0.001
	var pulse = 0.5 + 0.5 * sin(t * 6.0)
	var markers = [tutorial_marker_a, tutorial_marker_b, hint_marker_a, hint_marker_b]
	for marker in markers:
		if marker != null and marker.visible:
			marker.modulate.a = 0.35 + pulse * 0.6
			var s = 0.94 + pulse * 0.12
			marker.scale = Vector2(s, s)

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
	if moves_label == null or goal_label == null or result_overlay == null or tutorial_panel == null or stars_container == null:
		return

	board_origin_cached = board_origin
	board_pixel_size_cached = board_pixel_size

	score_label.position = Vector2(0, 18)
	score_label.size = Vector2(viewport_size.x, 56)

	stars_container.position = Vector2(0, 62)
	stars_container.size = Vector2(viewport_size.x, 42)

	goal_label.position = Vector2(0, 102)
	goal_label.size = Vector2(viewport_size.x, 42)

	var moves_y = viewport_size.y - 54.0
	if board_pixel_size != Vector2.ZERO:
		moves_y = board_origin.y + board_pixel_size.y + 14.0

	moves_label.position = Vector2(0, moves_y)
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
		_position_tutorial_panel()

func add_score(points: int):
	score += points
	score_label.text = "Wynik: " + str(score)
	update_star_progress()

func reset_score(new_value: int = 0):
	score = max(0, new_value)
	score_label.text = "Wynik: " + str(score)
	update_star_progress()

func set_star_thresholds(star_1: int, star_2: int, star_3: int):
	star_thresholds = [maxi(1, star_1), maxi(1, star_2), maxi(1, star_3)]
	update_star_progress()

func update_star_progress():
	if star_labels.size() < 3:
		return

	for i in 3:
		var threshold = star_thresholds[i]
		var progress = clampf(float(score) / float(threshold), 0.0, 1.0)
		var base_color = Color(0.34, 0.34, 0.38, 0.9)
		var fill_color = Color(1.0, 0.88, 0.26, 1.0)
		star_labels[i].modulate = base_color.lerp(fill_color, progress)

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
	result_hint.text = "Tapnij, aby wrócić do mapy" if win else "Tapnij, aby wrócić i spróbować ponownie"

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

func _position_tutorial_panel():
	if tutorial_panel == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 10.0

	var right_space = viewport_size.x - (board_origin_cached.x + board_pixel_size_cached.x)
	var left_space = board_origin_cached.x

	if right_space >= tutorial_panel.size.x + margin:
		tutorial_panel.position = Vector2(viewport_size.x - tutorial_panel.size.x - margin, 154)
	elif left_space >= tutorial_panel.size.x + margin:
		tutorial_panel.position = Vector2(margin, 154)
	else:
		tutorial_panel.position = Vector2((viewport_size.x - tutorial_panel.size.x) * 0.5, 154)

	tutorial_panel.position.x = clampf(tutorial_panel.position.x, margin, viewport_size.x - tutorial_panel.size.x - margin)
	tutorial_panel.position.y = clampf(tutorial_panel.position.y, margin, viewport_size.y - tutorial_panel.size.y - margin)

func _place_marker(marker: Panel, screen_pos: Vector2):
	if marker == null:
		return
	marker.position = screen_pos - marker.size * 0.5
	marker.visible = true

func show_tutorial_hint(title: String, body: String, _anchor_screen_pos: Vector2, move_a: Vector2 = Vector2(-1, -1), move_b: Vector2 = Vector2(-1, -1)):
	if tutorial_panel == null:
		return

	tutorial_title.text = title
	tutorial_body.text = body
	tutorial_panel.size = Vector2(360, 176)
	tutorial_title.size = Vector2(332, 38)
	tutorial_body.size = Vector2(332, 120)
	_position_tutorial_panel()
	tutorial_panel.visible = true

	tutorial_marker_a.visible = false
	tutorial_marker_b.visible = false
	if move_a.x >= 0 and move_b.x >= 0:
		_place_marker(tutorial_marker_a, move_a)
		_place_marker(tutorial_marker_b, move_b)

	var tween = get_tree().create_tween()
	tutorial_panel.modulate = Color(1, 1, 1, 0)
	tween.tween_property(tutorial_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

func hide_tutorial_hint():
	if tutorial_panel != null:
		tutorial_panel.visible = false
	if tutorial_marker_a != null:
		tutorial_marker_a.visible = false
	if tutorial_marker_b != null:
		tutorial_marker_b.visible = false

func is_tutorial_hint_visible() -> bool:
	return tutorial_panel != null and tutorial_panel.visible

func show_hint_move(move_a: Vector2, move_b: Vector2):
	_place_marker(hint_marker_a, move_a)
	_place_marker(hint_marker_b, move_b)

func hide_hint_move():
	if hint_marker_a != null:
		hint_marker_a.visible = false
	if hint_marker_b != null:
		hint_marker_b.visible = false

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
