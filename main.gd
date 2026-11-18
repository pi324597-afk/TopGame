extends Node2D

const VIEW_SIZE := Vector2(1280.0, 720.0)
const FINISH_X := 15000.0
const MAX_SPEED := 760.0
const ACCELERATION := 430.0
const BRAKING := 900.0
const FRICTION := 175.0

var car_x := 150.0
var car_air_y := 0.0
var jump_velocity := 0.0
var speed := 0.0
var camera_x := 0.0
var nitro := 100.0
var coins := 0
var distance_score := 0
var game_over := false
var finished := false
var gas_pressed := false
var brake_pressed := false
var nitro_pressed := false
var jump_pressed := false
var hit_cooldown := 0.0

var buildings: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var traffic: Array[Dictionary] = []

var hud_label: Label
var coin_label: Label
var speed_label: Label
var progress_label: Label
var message_label: Label
var restart_button: Button


func _ready() -> void:
	_generate_city()
	_generate_level_items()
	_build_interface()
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		return

	var accelerating := gas_pressed or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var braking := brake_pressed or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var using_nitro := nitro_pressed or Input.is_key_pressed(KEY_SHIFT)

	if accelerating:
		speed = move_toward(speed, MAX_SPEED, ACCELERATION * delta)
	else:
		speed = move_toward(speed, 0.0, FRICTION * delta)

	if braking:
		speed = move_toward(speed, 0.0, BRAKING * delta)

	if using_nitro and nitro > 0.0 and speed > 130.0:
		speed = minf(speed + 560.0 * delta, MAX_SPEED * 1.38)
		nitro = maxf(0.0, nitro - 34.0 * delta)
	else:
		nitro = minf(100.0, nitro + 8.0 * delta)

	if (jump_pressed or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)) and car_air_y == 0.0:
		jump_velocity = -470.0

	if jump_velocity != 0.0 or car_air_y < 0.0:
		car_air_y += jump_velocity * delta
		jump_velocity += 1120.0 * delta
		if car_air_y >= 0.0:
			car_air_y = 0.0
			jump_velocity = 0.0

	if hit_cooldown > 0.0:
		hit_cooldown -= delta

	car_x += speed * delta
	camera_x = maxf(0.0, car_x - 365.0)
	distance_score = int(car_x / 10.0)

	_check_pickups()
	_check_traffic()

	if car_x >= FINISH_X:
		finished = true
		game_over = true
		_show_finish_message()

	_update_hud()
	queue_redraw()


func _generate_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72831
	for i in range(95):
		var world_x := float(i) * 250.0 - 100.0
		var building_height := rng.randf_range(90.0, 260.0)
		var building_width := rng.randf_range(90.0, 190.0)
		buildings.append({
			"x": world_x,
			"w": building_width,
			"h": building_height,
			"tone": rng.randi_range(0, 4),
			"windows": rng.randi_range(2, 5)
		})


func _generate_level_items() -> void:
	for i in range(1, 30):
		var item_x := 430.0 + float(i) * 440.0
		pickups.append({"x": item_x, "kind": "coin", "taken": false})
		if i % 4 == 0:
			pickups.append({"x": item_x + 180.0, "kind": "nitro", "taken": false})
	for i in range(1, 17):
		traffic.append({
			"x": 1050.0 + float(i) * 850.0,
			"color": [Color("#e64b3c"), Color("#f1b83b"), Color("#3c9bdb"), Color("#e8e9ed")][i % 4],
			"hit": false
		})


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	hud_label = _make_label(root, "خیابان‌باز  |  رانندگی آزاد", Vector2(28, 18), Vector2(470, 48), 27)
	coin_label = _make_label(root, "◆  ۰", Vector2(1030, 20), Vector2(210, 44), 26)
	speed_label = _make_label(root, "۰ km/h", Vector2(28, 76), Vector2(240, 42), 22)
	progress_label = _make_label(root, "مسافت: ۰ متر", Vector2(28, 118), Vector2(260, 36), 18)
	message_label = _make_label(root, "", Vector2(400, 250), Vector2(480, 100), 32)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_make_hold_button(root, "ترمز", Vector2(855, 555), Vector2(145, 125), Color("#36516f"), "brake")
	_make_hold_button(root, "گاز", Vector2(1030, 555), Vector2(190, 125), Color("#168b66"), "gas")
	_make_hold_button(root, "نیترو", Vector2(1045, 410), Vector2(165, 105), Color("#bd6a24"), "nitro")
	_make_hold_button(root, "پرش", Vector2(860, 410), Vector2(145, 105), Color("#6852a8"), "jump")

	restart_button = Button.new()
	restart_button.text = "دوباره بازی کن"
	restart_button.position = Vector2(520, 370)
	restart_button.size = Vector2(240, 68)
	restart_button.visible = false
	restart_button.add_theme_font_size_override("font_size", 25)
	restart_button.pressed.connect(_restart_game)
	root.add_child(restart_button)


func _make_label(parent: Control, text_value: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#ffffff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _make_hold_button(parent: Control, caption: String, pos: Vector2, size: Vector2, tint: Color, action: String) -> void:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 27)
	var normal := StyleBoxFlat.new()
	normal.bg_color = tint
	normal.corner_radius_top_left = 24
	normal.corner_radius_top_right = 24
	normal.corner_radius_bottom_left = 24
	normal.corner_radius_bottom_right = 24
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(1, 1, 1, 0.45)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.lightened(0.22)
	button.add_theme_stylebox_override("pressed", pressed)
	button.button_down.connect(func() -> void: _set_control(action, true))
	button.button_up.connect(func() -> void: _set_control(action, false))
	parent.add_child(button)


func _set_control(action: String, pressed: bool) -> void:
	match action:
		"gas":
			gas_pressed = pressed
		"brake":
			brake_pressed = pressed
		"nitro":
			nitro_pressed = pressed
		"jump":
			jump_pressed = pressed


func _update_hud() -> void:
	if is_instance_valid(speed_label):
		speed_label.text = "%d km/h" % int(speed / 4.0)
		progress_label.text = "مسافت: %d متر  |  %d%%" % [int(car_x / 10.0), int((car_x / FINISH_X) * 100.0)]
		coin_label.text = "◆  %d" % coins


func _check_pickups() -> void:
	for item in pickups:
		if item["taken"]:
			continue
		if absf(car_x - float(item["x"])) < 48.0:
			item["taken"] = true
			if item["kind"] == "coin":
				coins += 1
			else:
				nitro = minf(100.0, nitro + 38.0)


func _check_traffic() -> void:
	if hit_cooldown > 0.0 or car_air_y < -45.0:
		return
	for vehicle in traffic:
		if vehicle["hit"]:
			continue
		if absf(car_x - float(vehicle["x"])) < 66.0:
			vehicle["hit"] = true
			speed *= 0.48
			hit_cooldown = 1.4
			break


func _show_finish_message() -> void:
	message_label.text = "آفرین! مسیر رو تموم کردی"
	restart_button.visible = true


func _restart_game() -> void:
	car_x = 150.0
	car_air_y = 0.0
	jump_velocity = 0.0
	speed = 0.0
	camera_x = 0.0
	nitro = 100.0
	coins = 0
	distance_score = 0
	game_over = false
	finished = false
	hit_cooldown = 0.0
	for item in pickups:
		item["taken"] = false
	for vehicle in traffic:
		vehicle["hit"] = false
	message_label.text = ""
	restart_button.visible = false
	_update_hud()
	queue_redraw()


func _road_y(world_x: float) -> float:
	return 520.0 + sin(world_x * 0.0018) * 13.0 + sin(world_x * 0.006) * 4.0


func _draw() -> void:
	_draw_sky()
	_draw_city()
	_draw_road()
	_draw_pickups()
	_draw_traffic()
	_draw_player_car()
	_draw_finish_line()


func _draw_sky() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#172943"))
	for i in range(12):
		var t := float(i) / 12.0
		draw_rect(Rect2(0, i * 36, 1280, 37), Color(0.10 + t * 0.12, 0.18 + t * 0.10, 0.31 + t * 0.10, 1.0))
	draw_circle(Vector2(1040, 135), 54, Color("#f8c978"))
	draw_circle(Vector2(1040, 135), 68, Color(1.0, 0.78, 0.40, 0.10))
	for i in range(22):
		var sx := fposmod(float(i) * 197.0 - camera_x * 0.08, 1320.0)
		var sy := 70.0 + fposmod(float(i) * 83.0, 260.0)
		draw_circle(Vector2(sx, sy), 2.0, Color(1, 1, 1, 0.35))


func _draw_city() -> void:
	for building in buildings:
		var sx := float(building["x"]) - camera_x * 0.34
		var w := float(building["w"])
		var h := float(building["h"])
		if sx < -w or sx > 1300:
			continue
		var palette := [Color("#263a57"), Color("#2c4563"), Color("#30415b"), Color("#354b67"), Color("#24354e")]
		var base_y := 510.0 - h
		draw_rect(Rect2(sx, base_y, w, h + 12.0), palette[int(building["tone"])])
		for row in range(int(building["windows"])):
			for col in range(3):
				var wx := sx + 14.0 + float(col) * (w - 30.0) / 3.0
				var wy := base_y + 18.0 + float(row) * 31.0
				draw_rect(Rect2(wx, wy, 12, 17), Color(1.0, 0.78, 0.42, 0.58))
		draw_rect(Rect2(sx + w * 0.45, base_y - 12, 9, 12), Color("#52647c"))


func _draw_road() -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in range(43):
		var screen_x := float(i) * 32.0
		var world_x := camera_x + screen_x
		var y := _road_y(world_x)
		top.append(Vector2(screen_x, y))
		bottom.append(Vector2(screen_x, 720))
	var road := PackedVector2Array()
	for point in top:
		road.append(point)
	for i in range(bottom.size() - 1, -1, -1):
		road.append(bottom[i])
	draw_colored_polygon(road, Color("#303c4b"))
	draw_polyline(top, Color("#e6e9e7"), 7.0, true)
	for i in range(22):
		var dash_x := fposmod(float(i) * 92.0 - camera_x, 1400.0)
		var dash_y := _road_y(camera_x + dash_x) + 72.0
		draw_line(Vector2(dash_x, dash_y), Vector2(dash_x + 42.0, dash_y), Color("#e7c65d"), 5.0, true)
	draw_line(Vector2(0, 700), Vector2(1280, 700), Color("#202b39"), 5.0)


func _draw_pickups() -> void:
	for item in pickups:
		if item["taken"]:
			continue
		var sx := float(item["x"]) - camera_x
		if sx < -40.0 or sx > 1320.0:
			continue
		var sy := _road_y(float(item["x"])) - 105.0
		if item["kind"] == "coin":
			draw_circle(Vector2(sx, sy), 18.0, Color("#f7bd3d"))
			draw_circle(Vector2(sx, sy), 12.0, Color("#ffe58b"))
			draw_circle(Vector2(sx, sy), 5.0, Color("#d88a22"))
		else:
			draw_rect(Rect2(sx - 15, sy - 23, 30, 46), Color("#27c7b5"))
			draw_line(Vector2(sx - 5, sy + 12), Vector2(sx + 7, sy - 10), Color.WHITE, 5.0, true)


func _draw_traffic() -> void:
	for vehicle in traffic:
		if vehicle["hit"]:
			continue
		var sx := float(vehicle["x"]) - camera_x
		if sx < -120.0 or sx > 1400.0:
			continue
		var y := _road_y(float(vehicle["x"])) - 45.0
		_draw_car_shape(Vector2(sx, y), vehicle["color"], 0.82)


func _draw_player_car() -> void:
	var screen_x := car_x - camera_x
	var body_y := _road_y(car_x) - 63.0 + car_air_y
	_draw_car_shape(Vector2(screen_x, body_y), Color("#e64d42"), 1.0)
	if speed > 500.0:
		for i in range(4):
			draw_line(Vector2(screen_x - 82.0 - i * 13.0, body_y + 4.0 + i * 3.0), Vector2(screen_x - 48.0 - i * 13.0, body_y + 4.0 + i * 3.0), Color(1.0, 0.72, 0.32, 0.65), 3.0, true)


func _draw_car_shape(center: Vector2, paint: Color, scale_value: float) -> void:
	var s := scale_value
	var body := PackedVector2Array([
		center + Vector2(-58, 2) * s,
		center + Vector2(-45, -22) * s,
		center + Vector2(-15, -27) * s,
		center + Vector2(5, -48) * s,
		center + Vector2(38, -45) * s,
		center + Vector2(57, -17) * s,
		center + Vector2(65, 0) * s,
		center + Vector2(57, 13) * s,
		center + Vector2(-52, 13) * s
	])
	draw_colored_polygon(body, paint)
	draw_polyline(body, Color("#202a35"), 3.0 * s, true)
	var glass := PackedVector2Array([
		center + Vector2(-8, -25) * s,
		center + Vector2(8, -43) * s,
		center + Vector2(33, -40) * s,
		center + Vector2(45, -20) * s
	])
	draw_colored_polygon(glass, Color("#a9d8e8"))
	draw_line(center + Vector2(17, -42) * s, center + Vector2(12, -21) * s, Color("#526b80"), 3.0 * s)
	draw_rect(Rect2(center + Vector2(-44, -2) * s, Vector2(15, 5) * s), Color("#ffe9a3"))
	draw_rect(Rect2(center + Vector2(48, -1) * s, Vector2(10, 7) * s), Color("#ffb0a0"))
	draw_circle(center + Vector2(-34, 13) * s, 15.0 * s, Color("#121923"))
	draw_circle(center + Vector2(39, 13) * s, 15.0 * s, Color("#121923"))
	draw_circle(center + Vector2(-34, 13) * s, 7.0 * s, Color("#aab7c4"))
	draw_circle(center + Vector2(39, 13) * s, 7.0 * s, Color("#aab7c4"))


func _draw_finish_line() -> void:
	var sx := FINISH_X - camera_x
	if sx < -30.0 or sx > 1320.0:
		return
	var y := _road_y(FINISH_X)
	for row in range(8):
		for col in range(2):
			var color := Color.WHITE if (row + col) % 2 == 0 else Color("#1e2732")
			draw_rect(Rect2(sx + col * 16.0, y - 130.0 + row * 16.0, 16, 16), color)
