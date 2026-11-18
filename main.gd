extends Node2D

# خیابان‌باز — نسخه کاملِ قابل‌بازی 1.0
# همه گرافیک‌ها به‌صورت برداری و داخل خود Godot رسم می‌شوند.

const W := 1280.0
const H := 720.0
const SAVE_PATH := "user://street_rush_save.cfg"
const STAGES := [
	{"name":"خیابان‌های قدیمی","city":"OLD TOWN","length":6500.0,"goal":8,"reward":180,"traffic":7,"color":Color("#f0a65b")},
	{"name":"بلوار ساحلی","city":"COAST ROAD","length":7200.0,"goal":10,"reward":220,"traffic":9,"color":Color("#50c4d4")},
	{"name":"منطقه صنعتی","city":"INDUSTRIAL","length":7800.0,"goal":12,"reward":260,"traffic":11,"color":Color("#e17b55")},
	{"name":"بزرگراه شبانه","city":"NIGHT HIGHWAY","length":8500.0,"goal":14,"reward":310,"traffic":13,"color":Color("#8e8be8")},
	{"name":"مرکز شهر","city":"DOWNTOWN","length":9200.0,"goal":16,"reward":360,"traffic":15,"color":Color("#e8b65e")},
	{"name":"جاده کوهستانی","city":"MOUNTAIN PASS","length":10000.0,"goal":18,"reward":420,"traffic":17,"color":Color("#75bd86")},
	{"name":"اتوبان بارانی","city":"RAIN EXPRESS","length":11000.0,"goal":20,"reward":500,"traffic":19,"color":Color("#6ca9d9")},
	{"name":"مسابقه نهایی","city":"GRAND FINALE","length":12500.0,"goal":22,"reward":700,"traffic":22,"color":Color("#e17ab0")}
]
const CARS := [
	{"name":"شهاب","desc":"سبک و چابک؛ انتخاب شروع","price":0,"speed":1.0,"nitro":1.0,"color":Color("#ef5148")},
	{"name":"آذرخش","desc":"شتاب بیشتر در مسیر مستقیم","price":450,"speed":1.12,"nitro":0.95,"color":Color("#39a9e8")},
	{"name":"گرگ شب","desc":"تعادل عالی برای مسابقه","price":850,"speed":1.08,"nitro":1.18,"color":Color("#a78be8")},
	{"name":"بولدوزر","desc":"سنگین و قدرتمند","price":1250,"speed":1.2,"nitro":1.08,"color":Color("#e5a63d")},
	{"name":"فانتوم","desc":"سریع‌ترین خودروی گاراژ","price":1900,"speed":1.32,"nitro":1.25,"color":Color("#55c58b")}
]
const ROAD_Y := 535.0
const MAX_SPEED := 720.0
const ACCEL := 390.0
const BRAKE := 850.0
const FRICTION := 145.0

var screen := "menu"
var selected_stage := 0
var selected_car := 0
var owned_cars: Array = [true, false, false, false, false]
var unlocked_stage := 0
var wallet := 350
var best_distance := 0
var total_wins := 0
var sound_on := true
var upgrade_engine := 0
var upgrade_nitro := 0

var world_x := 0.0
var speed := 0.0
var nitro := 100.0
var race_coins := 0
var stage_progress := 0.0
var player_y := 0.0
var jump_v := 0.0
var damage := 0
var elapsed := 0.0
var hit_flash := 0.0
var gas_down := false
var brake_down := false
var nitro_down := false
var jump_down := false
var paused := false
var race_done := false
var traffic: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var clouds: Array[Dictionary] = []

var ui_layer: CanvasLayer
var ui_root: Control
var game_ui: Control
var screen_ui: Control
var speed_value: Label
var coin_value: Label
var progress_value: Label
var nitro_bar: ProgressBar
var damage_bar: ProgressBar
var toast_label: Label
var hold_buttons: Array[Button] = []

func _ready() -> void:
	_load_save()
	_make_background_data()
	_build_ui()
	_show_menu()
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	if screen == "race" and not paused and not race_done:
		_update_race(delta)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "race" and not paused:
			_pause_race()
		else:
			_show_menu()

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	wallet = int(cfg.get_value("career", "wallet", 350))
	unlocked_stage = clampi(int(cfg.get_value("career", "unlocked_stage", 0)), 0, STAGES.size() - 1)
	best_distance = int(cfg.get_value("career", "best_distance", 0))
	total_wins = int(cfg.get_value("career", "total_wins", 0))
	owned_cars = cfg.get_value("garage", "owned", [true, false, false, false, false])
	selected_car = clampi(int(cfg.get_value("garage", "selected", 0)), 0, CARS.size() - 1)
	upgrade_engine = clampi(int(cfg.get_value("garage", "engine", 0)), 0, 3)
	upgrade_nitro = clampi(int(cfg.get_value("garage", "nitro", 0)), 0, 3)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "wallet", wallet)
	cfg.set_value("career", "unlocked_stage", unlocked_stage)
	cfg.set_value("career", "best_distance", best_distance)
	cfg.set_value("career", "total_wins", total_wins)
	cfg.set_value("garage", "owned", owned_cars)
	cfg.set_value("garage", "selected", selected_car)
	cfg.set_value("garage", "engine", upgrade_engine)
	cfg.set_value("garage", "nitro", upgrade_nitro)
	cfg.save(SAVE_PATH)

func _make_background_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 492817
	for i in range(70):
		buildings.append({"x": float(i) * 190.0, "w": rng.randf_range(85.0, 165.0), "h": rng.randf_range(100.0, 310.0), "tone": rng.randi_range(0, 5), "lights": rng.randi_range(2, 5)})
	for i in range(9):
		clouds.append({"x": rng.randf_range(0.0, W), "y": rng.randf_range(55.0, 220.0), "s": rng.randf_range(0.65, 1.5)})

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

func _clear_ui() -> void:
	for child in ui_root.get_children():
		child.queue_free()
	hold_buttons.clear()
	screen_ui = null
	game_ui = null

func _panel(parent: Control, rect: Rect2, color := Color("#111d31"), alpha := 0.94) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.15)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func _label(parent: Control, value: String, rect: Rect2, size := 24, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var l := Label.new()
	l.text = value
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l

func _button(parent: Control, caption: String, rect: Rect2, callback: Callable, tint := Color("#287e91"), font_size := 23) -> Button:
	var b := Button.new()
	b.text = caption
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = tint
	normal.corner_radius_top_left = 15
	normal.corner_radius_top_right = 15
	normal.corner_radius_bottom_left = 15
	normal.corner_radius_bottom_right = 15
	normal.border_width_bottom = 3
	normal.border_color = tint.darkened(0.35)
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.13)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.12)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _show_menu() -> void:
	screen = "menu"
	paused = false
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)
	screen_ui = root
	_label(root, "خیابان‌باز", Rect2(650, 92, 540, 90), 66, Color("#ffffff"))
	_label(root, "STREET RUSH  •  رانندگی، رقابت، پیشرفت", Rect2(650, 175, 540, 45), 21, Color("#70d5df"))
	_panel(root, Rect2(700, 265, 470, 365), Color("#101c30"), 0.9)
	_button(root, "شروع مسابقه", Rect2(755, 300, 360, 68), _show_stage_select, Color("#159b78"), 27)
	_button(root, "گاراژ و ارتقای ماشین", Rect2(755, 385, 360, 62), _show_garage, Color("#286f9e"), 24)
	_button(root, "آمار راننده", Rect2(755, 463, 170, 58), _show_stats, Color("#6653a4"), 21)
	_button(root, "تنظیمات", Rect2(945, 463, 170, 58), _show_settings, Color("#465a75"), 21)
	_label(root, "اعتبار: %d  ◆" % wallet, Rect2(770, 545, 330, 42), 23, Color("#ffd36c"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, "۸ مرحله مسابقه  •  ۵ ماشین  •  ارتقا و ذخیره خودکار", Rect2(90, 620, 1100, 38), 18, Color("#b7c6d9"), HORIZONTAL_ALIGNMENT_CENTER)
	queue_redraw()

func _show_stage_select() -> void:
	screen = "stages"
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)
	screen_ui = root
	_label(root, "انتخاب مسابقه", Rect2(700, 48, 480, 64), 42)
	_label(root, "مرحله‌های بازشده: %d از %d" % [unlocked_stage + 1, STAGES.size()], Rect2(700, 112, 480, 36), 18, Color("#83d6d1"))
	for i in range(STAGES.size()):
		var col := i % 4
		var row := int(i / 4)
		var x := 90.0 + col * 285.0
		var y := 205.0 + row * 190.0
		var data: Dictionary = STAGES[i]
		var unlocked := i <= unlocked_stage
		_panel(root, Rect2(x, y, 250, 150), Color("#152842") if unlocked else Color("#111722"), 0.96)
		_label(root, "مرحله %02d" % (i + 1), Rect2(x + 12, y + 8, 220, 30), 17, Color("#7dd5dc"), HORIZONTAL_ALIGNMENT_CENTER)
		_label(root, str(data["name"]), Rect2(x + 12, y + 42, 220, 38), 22, Color.WHITE if unlocked else Color("#718096"), HORIZONTAL_ALIGNMENT_CENTER)
		_label(root, "%d متر  •  جایزه %d" % [int(data["length"] / 10.0), int(data["reward"])], Rect2(x + 10, y + 82, 230, 26), 15, Color("#bdc9d8"), HORIZONTAL_ALIGNMENT_CENTER)
		if unlocked:
			_button(root, "ورود", Rect2(x + 48, y + 112, 154, 32), _choose_stage.bind(i), Color("#177e75"), 16)
		else:
			_label(root, "🔒 قفل", Rect2(x + 65, y + 112, 120, 30), 17, Color("#8792a3"), HORIZONTAL_ALIGNMENT_CENTER)
	_button(root, "بازگشت", Rect2(70, 55, 150, 48), _show_menu, Color("#465a75"), 19)

func _choose_stage(index: int) -> void:
	selected_stage = index
	_start_race()

func _show_garage() -> void:
	screen = "garage"
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)
	screen_ui = root
	_label(root, "گاراژ", Rect2(760, 35, 400, 62), 44)
	_label(root, "اعتبار: %d ◆" % wallet, Rect2(780, 98, 360, 36), 21, Color("#ffd36c"))
	_panel(root, Rect2(690, 160, 500, 440), Color("#14253d"), 0.95)
	var car: Dictionary = CARS[selected_car]
	_label(root, str(car["name"]), Rect2(750, 185, 380, 45), 34, Color("#ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, str(car["desc"]), Rect2(745, 230, 390, 35), 18, Color("#a8c1d4"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, "سرعت پایه: %d%%" % int(float(car["speed"]) * 100.0), Rect2(760, 480, 350, 30), 19, Color("#d7e4f1"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, "نیترو: %d%%" % int(float(car["nitro"]) * 100.0), Rect2(760, 512, 350, 30), 19, Color("#65d5d0"), HORIZONTAL_ALIGNMENT_CENTER)
	_button(root, "◀", Rect2(710, 340, 70, 58), _cycle_car.bind(-1), Color("#465a75"), 26)
	_button(root, "▶", Rect2(1100, 340, 70, 58), _cycle_car.bind(1), Color("#465a75"), 26)
	var owned := bool(owned_cars[selected_car])
	if owned:
		_button(root, "انتخاب این ماشین", Rect2(780, 555, 320, 48), _select_car, Color("#168b68"), 19)
	else:
		_button(root, "خرید  %d ◆" % int(car["price"]), Rect2(780, 555, 320, 48), _buy_car, Color("#b8792d"), 19)
	_panel(root, Rect2(80, 175, 530, 400), Color("#101d30"), 0.93)
	_label(root, "کارگاه ارتقا", Rect2(130, 195, 430, 48), 29, Color("#ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(root, "موتور  •  سطح %d از ۳" % upgrade_engine, Rect2(140, 270, 410, 34), 21)
	_label(root, "نیترو  •  سطح %d از ۳" % upgrade_nitro, Rect2(140, 355, 410, 34), 21)
	_button(root, "ارتقای موتور  %d ◆" % (250 + upgrade_engine * 200), Rect2(165, 310, 340, 42), _upgrade_engine, Color("#286f9e"), 18)
	_button(root, "ارتقای نیترو  %d ◆" % (220 + upgrade_nitro * 180), Rect2(165, 395, 340, 42), _upgrade_nitro, Color("#6653a4"), 18)
	_label(root, "هر ارتقا در مسابقه بعدی ذخیره می‌شود.", Rect2(125, 465, 440, 35), 16, Color("#a8b8cb"), HORIZONTAL_ALIGNMENT_CENTER)
	_button(root, "بازگشت", Rect2(70, 55, 150, 48), _show_menu, Color("#465a75"), 19)
	queue_redraw()

func _cycle_car(direction: int) -> void:
	selected_car = posmod(selected_car + direction, CARS.size())
	_show_garage()

func _buy_car() -> void:
	var car: Dictionary = CARS[selected_car]
	var price := int(car["price"])
	if wallet < price:
		_toast("اعتبار کافی نیست!")
		return
	wallet -= price
	owned_cars[selected_car] = true
	_save()
	_show_garage()

func _select_car() -> void:
	if not bool(owned_cars[selected_car]):
		return
	_save()
	_toast("ماشین انتخاب شد")
	_show_garage()

func _upgrade_engine() -> void:
	if upgrade_engine >= 3:
		_toast("موتور به آخرین سطح رسیده")
		return
	var cost := 250 + upgrade_engine * 200
	if wallet < cost:
		_toast("اعتبار کافی نیست!")
		return
	wallet -= cost
	upgrade_engine += 1
	_save()
	_show_garage()

func _upgrade_nitro() -> void:
	if upgrade_nitro >= 3:
		_toast("نیترو به آخرین سطح رسیده")
		return
	var cost := 220 + upgrade_nitro * 180
	if wallet < cost:
		_toast("اعتبار کافی نیست!")
		return
	wallet -= cost
	upgrade_nitro += 1
	_save()
	_show_garage()

func _show_stats() -> void:
	screen = "stats"
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)
	_label(root, "کارنامه راننده", Rect2(690, 100, 500, 65), 44)
	_panel(root, Rect2(350, 220, 600, 340), Color("#14253d"), 0.95)
	_label(root, "مسابقه‌های تمام‌شده: %d" % total_wins, Rect2(420, 270, 460, 48), 25)
	_label(root, "بهترین مسافت: %d متر" % best_distance, Rect2(420, 340, 460, 48), 25)
	_label(root, "مرحله‌های بازشده: %d" % (unlocked_stage + 1), Rect2(420, 410, 460, 48), 25)
	_label(root, "ماشین‌های خریداری‌شده: %d از ۵" % owned_cars.count(true), Rect2(420, 480, 460, 48), 22, Color("#75d5c8"))
	_button(root, "بازگشت", Rect2(70, 55, 150, 48), _show_menu, Color("#465a75"), 19)

func _show_settings() -> void:
	screen = "settings"
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)
	_label(root, "تنظیمات", Rect2(700, 120, 450, 65), 44)
	_panel(root, Rect2(360, 230, 560, 280), Color("#14253d"), 0.95)
	_label(root, "صدا و موسیقی", Rect2(480, 270, 320, 45), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_button(root, "صدا: روشن" if sound_on else "صدا: خاموش", Rect2(490, 340, 300, 62), _toggle_sound, Color("#286f9e"), 22)
	_label(root, "نسخه ۱.۰  •  خیابان‌باز", Rect2(480, 425, 320, 35), 17, Color("#a9bbcf"), HORIZONTAL_ALIGNMENT_CENTER)
	_button(root, "بازگشت", Rect2(70, 55, 150, 48), _show_menu, Color("#465a75"), 19)

func _toggle_sound() -> void:
	sound_on = not sound_on
	_show_settings()

func _toast(message: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = message
		toast_label.visible = true

func _start_race() -> void:
	screen = "race"
	paused = false
	race_done = false
	world_x = 0.0
	speed = 0.0
	nitro = 100.0
	race_coins = 0
	stage_progress = 0.0
	player_y = 0.0
	jump_v = 0.0
	damage = 0
	hit_flash = 0.0
	gas_down = false
	brake_down = false
	nitro_down = false
	jump_down = false
	traffic.clear()
	pickups.clear()
	particles.clear()
	var data: Dictionary = STAGES[selected_stage]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917 + selected_stage * 137
	for i in range(int(data["traffic"])):
		var tx := 720.0 + float(i) * (float(data["length"]) / float(data["traffic"])) + rng.randf_range(0, 300)
		traffic.append({"x": tx, "lane": rng.randf_range(-10.0, 28.0), "color": [Color("#f1b83b"), Color("#45a8d9"), Color("#e7e9ef"), Color("#8e78c8"), Color("#4fc39a")][i % 5], "passed": false})
	for i in range(int(data["goal"]) + 10):
		var px := 500.0 + float(i) * (float(data["length"]) / float(data["goal"] + 8))
		pickups.append({"x": px, "taken": false, "kind": "coin" if i % 4 != 3 else "nitro"})
	_build_race_ui()
	queue_redraw()

func _build_race_ui() -> void:
	_clear_ui()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(root)
	game_ui = root
	var data: Dictionary = STAGES[selected_stage]
	_panel(root, Rect2(22, 18, 400, 112), Color("#101c30"), 0.78)
	_label(root, str(data["name"]), Rect2(45, 25, 340, 34), 21)
	speed_value = _label(root, "۰ km/h", Rect2(45, 62, 170, 48), 30, Color("#ffffff"))
	coin_value = _label(root, "◆ ۰", Rect2(230, 67, 150, 40), 22, Color("#ffd36c"))
	_panel(root, Rect2(450, 24, 390, 70), Color("#101c30"), 0.78)
	progress_value = _label(root, "۰٪", Rect2(470, 28, 90, 34), 19, Color("#ffffff"))
	var progress := ProgressBar.new()
	progress.position = Vector2(555, 38)
	progress.size = Vector2(255, 18)
	progress.max_value = 100
	progress.value = 0
	progress.show_percentage = false
	root.add_child(progress)
	nitro_bar = ProgressBar.new()
	nitro_bar.position = Vector2(30, 145)
	nitro_bar.size = Vector2(220, 17)
	nitro_bar.max_value = 100
	nitro_bar.value = 100
	nitro_bar.show_percentage = false
	root.add_child(nitro_bar)
	_label(root, "نیترو", Rect2(260, 137, 90, 32), 16, Color("#71e2e0"))
	damage_bar = ProgressBar.new()
	damage_bar.position = Vector2(30, 174)
	damage_bar.size = Vector2(220, 14)
	damage_bar.max_value = 100
	damage_bar.value = 0
	damage_bar.show_percentage = false
	root.add_child(damage_bar)
	_label(root, "آسیب", Rect2(260, 166, 90, 30), 15, Color("#f18a7b"))
	_button(root, "Ⅱ", Rect2(1160, 24, 82, 66), _pause_race, Color("#465a75"), 30)
	_make_hold(root, "ترمز", Rect2(835, 560, 130, 115), Color("#405a79"), "brake")
	_make_hold(root, "گاز", Rect2(1100, 545, 150, 130), Color("#159b78"), "gas")
	_make_hold(root, "نیترو", Rect2(1000, 435, 140, 82), Color("#b8792d"), "nitro")
	_make_hold(root, "پرش", Rect2(840, 435, 130, 82), Color("#6653a4"), "jump")
	# درصد پیشرفت در نوار مستقل با مقدار مستقیم به‌روزرسانی می‌شود.
	progress.set_meta("race_progress", true)
	toast_label = _label(root, "", Rect2(410, 125, 460, 50), 20, Color("#ffe28b"), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.visible = false
	_update_race_hud()

func _make_hold(parent: Control, caption: String, rect: Rect2, tint: Color, action: String) -> void:
	var b := _button(parent, caption, rect, func() -> void: pass, tint, 22)
	b.button_down.connect(func() -> void: _set_drive(action, true))
	b.button_up.connect(func() -> void: _set_drive(action, false))
	b.mouse_exited.connect(func() -> void: _set_drive(action, false))
	hold_buttons.append(b)

func _set_drive(action: String, value: bool) -> void:
	match action:
		"gas": gas_down = value
		"brake": brake_down = value
		"nitro": nitro_down = value
		"jump": jump_down = value

func _update_race(delta: float) -> void:
	var gas := gas_down or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var brake := brake_down or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var boost := nitro_down or Input.is_key_pressed(KEY_SHIFT)
	if gas:
		speed = move_toward(speed, _max_car_speed(), (ACCEL + upgrade_engine * 45.0) * delta)
	else:
		speed = move_toward(speed, 0.0, FRICTION * delta)
	if brake:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	if boost and nitro > 0.5 and speed > 100.0:
		speed = minf(speed + 520.0 * delta, _max_car_speed() * 1.42)
		nitro = maxf(0.0, nitro - (28.0 / float(CARS[selected_car]["nitro"]) / (1.0 + upgrade_nitro * 0.12)) * delta)
	else:
		nitro = minf(100.0, nitro + 6.5 * delta)
	if (jump_down or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)) and player_y >= -0.1:
		jump_v = -440.0
	if player_y < 0.0 or jump_v < 0.0:
		player_y += jump_v * delta
		jump_v += 1050.0 * delta
		if player_y >= 0.0:
			player_y = 0.0
			jump_v = 0.0
	world_x += speed * delta
	stage_progress = clampf(world_x / float(STAGES[selected_stage]["length"]), 0.0, 1.0)
	if hit_flash > 0.0:
		hit_flash -= delta
	_update_traffic()
	_update_pickups()
	_update_particles(delta)
	if world_x >= float(STAGES[selected_stage]["length"]):
		_finish_race(true)
	_update_race_hud()

func _max_car_speed() -> float:
	return MAX_SPEED * float(CARS[selected_car]["speed"]) * (1.0 + upgrade_engine * 0.055)

func _update_traffic() -> void:
	for vehicle in traffic:
		if bool(vehicle["passed"]):
			continue
		var gap: float = float(vehicle["x"]) - world_x
		if gap < -85.0:
			vehicle["passed"] = true
			continue
		if gap > 0.0 and gap < 78.0 and absf(player_y) < 42.0:
			vehicle["passed"] = true
			speed *= 0.38
			damage = mini(100, damage + 24)
			hit_flash = 0.28
			_spawn_burst(Vector2(365, ROAD_Y - 40), Color("#ff9a52"), 12)
			_toast("تصادف! مراقب ماشین‌های جلویی باش")
			if damage >= 100:
				_finish_race(false)
			break

func _update_pickups() -> void:
	for item in pickups:
		if bool(item["taken"]):
			continue
		var gap: float = absf(float(item["x"]) - world_x)
		if gap < 54.0:
			item["taken"] = true
			if str(item["kind"]) == "coin":
				race_coins += 1
				_spawn_burst(Vector2(365, ROAD_Y - 100), Color("#ffd15b"), 7)
			else:
				nitro = minf(100.0, nitro + 32.0)
				_spawn_burst(Vector2(365, ROAD_Y - 100), Color("#5ce2d4"), 9)

func _spawn_burst(at: Vector2, tint: Color, amount: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(amount):
		var angle := rng.randf_range(0.0, TAU)
		var velocity := Vector2(cos(angle), sin(angle)) * rng.randf_range(45.0, 180.0)
		particles.append({"p": at, "v": velocity, "life": rng.randf_range(0.25, 0.55), "max": 0.55, "color": tint})

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
		else:
			particles[i] = p

func _update_race_hud() -> void:
	if not is_instance_valid(speed_value):
		return
	speed_value.text = "%d km/h" % int(speed / 4.0)
	coin_value.text = "◆ %d" % race_coins
	progress_value.text = "%d%%" % int(stage_progress * 100.0)
	nitro_bar.value = nitro
	damage_bar.value = damage
	for child in game_ui.get_children():
		if child is ProgressBar and child.has_meta("race_progress"):
			child.value = stage_progress * 100.0

func _pause_race() -> void:
	if screen != "race" or race_done:
		return
	paused = true
	var overlay := Control.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.add_child(overlay)
	_panel(overlay, Rect2(390, 175, 500, 370), Color("#101b30"), 0.97)
	_label(overlay, "توقف مسابقه", Rect2(450, 205, 380, 65), 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_button(overlay, "ادامه", Rect2(490, 295, 300, 55), _resume_race, Color("#159b78"), 22)
	_button(overlay, "شروع دوباره", Rect2(490, 365, 300, 48), _restart_current, Color("#286f9e"), 19)
	_button(overlay, "خروج به منو", Rect2(490, 428, 300, 48), _show_menu, Color("#7b5261"), 19)

func _resume_race() -> void:
	paused = false
	if is_instance_valid(game_ui.get_node_or_null("PauseOverlay")):
		game_ui.get_node("PauseOverlay").queue_free()

func _restart_current() -> void:
	_start_race()

func _finish_race(won: bool) -> void:
	if race_done:
		return
	race_done = true
	paused = true
	var reward := 0
	if won:
		total_wins += 1
		unlocked_stage = mini(STAGES.size() - 1, maxi(unlocked_stage, selected_stage + 1))
		reward = int(STAGES[selected_stage]["reward"]) + race_coins * 8
	else:
		reward = race_coins * 5
	wallet += reward
	best_distance = maxi(best_distance, int(world_x / 10.0))
	_save()
	var overlay := Control.new()
	overlay.name = "ResultOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.add_child(overlay)
	_panel(overlay, Rect2(350, 145, 580, 430), Color("#101b30"), 0.98)
	_label(overlay, "پیروزی!" if won else "ماشین آسیب جدی دید", Rect2(405, 175, 470, 70), 38, Color("#ffd36c") if won else Color("#ff998d"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay, "مسافت: %d متر" % int(world_x / 10.0), Rect2(430, 265, 420, 40), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay, "سکه‌های جمع‌شده: %d" % race_coins, Rect2(430, 310, 420, 38), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay, "پاداش: %d اعتبار" % reward, Rect2(430, 355, 420, 42), 25, Color("#ffd36c"), HORIZONTAL_ALIGNMENT_CENTER)
	_button(overlay, "مرحله بعد" if won and selected_stage < STAGES.size() - 1 else "تلاش دوباره", Rect2(420, 435, 205, 55), _result_primary, Color("#159b78"), 19)
	_button(overlay, "منوی اصلی", Rect2(650, 435, 205, 55), _show_menu, Color("#465a75"), 19)

func _result_primary() -> void:
	if selected_stage < STAGES.size() - 1 and selected_stage < unlocked_stage:
		selected_stage += 1
	_start_race()

func _draw() -> void:
	_draw_world_background()
	if screen == "race":
		_draw_race_world()
	elif screen == "garage":
		_draw_garage_car()
	else:
		_draw_menu_car()
	if hit_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.2, 0.12, hit_flash * 0.35))

func _draw_world_background() -> void:
	var night := screen == "race" and selected_stage in [3, 6, 7]
	var top := Color("#101b35") if night else Color("#24506c")
	var bottom := Color("#d18c68") if not night else Color("#27385d")
	draw_rect(Rect2(0, 0, W, H), top)
	for i in range(14):
		var t := float(i) / 14.0
		draw_rect(Rect2(0, i * 34, W, 35), top.lerp(bottom, t * 0.72))
	var sun_color := Color("#ffcc7c") if not night else Color("#d4d9ef")
	draw_circle(Vector2(190, 165), 57, sun_color)
	draw_circle(Vector2(190, 165), 76, Color(sun_color.r, sun_color.g, sun_color.b, 0.12))
	for cloud in clouds:
		var cx := fposmod(float(cloud["x"]) - (world_x * 0.035 if screen == "race" else elapsed * 8.0), W + 200.0) - 100.0
		var cy := float(cloud["y"])
		var s := float(cloud["s"])
		var cloud_color := Color(0.84, 0.9, 0.95, 0.2)
		draw_circle(Vector2(cx, cy), 23 * s, cloud_color)
		draw_circle(Vector2(cx + 25 * s, cy - 9 * s), 28 * s, cloud_color)
		draw_circle(Vector2(cx + 51 * s, cy), 20 * s, cloud_color)
	var parallax := world_x * 0.23 if screen == "race" else elapsed * 12.0
	for b in buildings:
		var bx := fposmod(float(b["x"]) - parallax, W + 260.0) - 130.0
		var bw := float(b["w"])
		var bh := float(b["h"]) * 0.76
		var palette := [Color("#29465d"), Color("#34546a"), Color("#3b5265"), Color("#2b4059"), Color("#40596c"), Color("#304a60")]
		var base := 495.0
		draw_rect(Rect2(bx, base - bh, bw, bh), palette[int(b["tone"])])
		draw_rect(Rect2(bx + bw * 0.45, base - bh - 18, 9, 18), Color("#718394"))
		for row in range(int(b["lights"])):
			for col in range(3):
				var wx := bx + 13 + col * (bw - 25) / 3
				var wy := base - bh + 18 + row * 35
				var lit := (int(b["tone"]) + row + col) % 3 != 0
				draw_rect(Rect2(wx, wy, 11, 16), Color("#ffd58a") if lit else Color("#182b3d"))
	draw_rect(Rect2(0, 485, W, 235), Color("#1a2937"))
	draw_rect(Rect2(0, 506, W, 9), Color("#c7b99b", 0.7))

func _draw_race_world() -> void:
	var road_points := PackedVector2Array()
	for i in range(42):
		var sx := float(i) * 32.0
		var wx := world_x + sx
		var curve := sin(wx * 0.0014) * 11.0 + sin(wx * 0.004) * 4.0
		road_points.append(Vector2(sx, ROAD_Y + curve))
	var polygon := PackedVector2Array(road_points)
	polygon.append(Vector2(W, H))
	polygon.append(Vector2(0, H))
	draw_colored_polygon(polygon, Color("#303c4c"))
	draw_polyline(road_points, Color("#e8e9e4"), 7.0, true)
	for i in range(18):
		var dx := fposmod(float(i) * 105.0 - world_x, W + 110.0) - 30.0
		var dy := ROAD_Y + sin((world_x + dx) * 0.0014) * 11.0 + 82.0
		draw_line(Vector2(dx, dy), Vector2(dx + 48, dy), Color("#f1d16c"), 5.0, true)
	draw_rect(Rect2(0, 694, W, 26), Color("#18232f"))
	for i in range(22):
		var x := fposmod(float(i) * 70.0 - world_x * 0.7, W + 70.0)
		draw_rect(Rect2(x, 502, 28, 7), Color("#e8c66d"))
	for item in pickups:
		if bool(item["taken"]):
			continue
		var sx := 365.0 + float(item["x"]) - world_x
		if sx < -50 or sx > W + 50:
			continue
		var sy := ROAD_Y - 105.0 + sin(elapsed * 4.0 + sx * 0.02) * 5.0
		if str(item["kind"]) == "coin":
			draw_circle(Vector2(sx, sy), 19, Color("#c67c28"))
			draw_circle(Vector2(sx, sy), 15, Color("#ffd45e"))
			draw_circle(Vector2(sx, sy), 7, Color("#fff0ad"))
		else:
			draw_rect(Rect2(sx - 15, sy - 22, 30, 44), Color("#29bfb2"))
			draw_line(Vector2(sx - 5, sy + 10), Vector2(sx + 7, sy - 10), Color.WHITE, 5, true)
	for vehicle in traffic:
		if bool(vehicle["passed"]):
			continue
		var sx := 365.0 + float(vehicle["x"]) - world_x
		if sx < -140 or sx > W + 140:
			continue
		var sy := ROAD_Y - 42.0 + float(vehicle["lane"])
		_draw_car(Vector2(sx, sy), vehicle["color"], 0.82, 0.0)
	_draw_car(Vector2(365, ROAD_Y - 54.0 + player_y), CARS[selected_car]["color"], 1.0, elapsed * speed * 0.012)
	for p in particles:
		var c: Color = p["color"]
		c.a = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		draw_circle(p["p"], 4.0, c)
	if speed > 420:
		for i in range(5):
			var streak_y := ROAD_Y - 40.0 + i * 13.0
			draw_line(Vector2(260 - i * 9, streak_y), Vector2(315 - i * 9, streak_y), Color(1, 0.8, 0.45, 0.35), 2.0)

func _draw_car(center: Vector2, paint: Color, scale_value: float, wheel_phase: float) -> void:
	var s := scale_value
	# دماغ ماشین سمت راست است؛ چراغ جلو راست و چراغ عقب چپ قرار دارد.
	var body := PackedVector2Array([
		center + Vector2(-62, 2) * s, center + Vector2(-49, -23) * s,
		center + Vector2(-20, -28) * s, center + Vector2(2, -49) * s,
		center + Vector2(37, -47) * s, center + Vector2(56, -20) * s,
		center + Vector2(68, -5) * s, center + Vector2(62, 13) * s,
		center + Vector2(-55, 13) * s
	])
	draw_colored_polygon(body, paint)
	draw_polyline(body, Color("#111a25"), 3.0 * s, true)
	var glass := PackedVector2Array([center + Vector2(-8, -29) * s, center + Vector2(8, -45) * s, center + Vector2(33, -43) * s, center + Vector2(48, -21) * s])
	draw_colored_polygon(glass, Color("#a9dce9"))
	draw_polyline(glass, Color("#25394b"), 2.0 * s, true)
	draw_line(center + Vector2(17, -43) * s, center + Vector2(13, -21) * s, Color("#526b80"), 2.5 * s)
	draw_rect(Rect2(center + Vector2(52, -8) * s, Vector2(12, 8) * s), Color("#fff1b2"))
	draw_rect(Rect2(center + Vector2(-61, -5) * s, Vector2(10, 9) * s), Color("#ff665e"))
	draw_rect(Rect2(center + Vector2(-24, -3) * s, Vector2(20, 4) * s), paint.lightened(0.3))
	for wx in [-36.0, 40.0]:
		var wheel := center + Vector2(wx, 13) * s
		draw_circle(wheel, 16.0 * s, Color("#101720"))
		draw_circle(wheel, 10.0 * s, Color("#697b89"))
		draw_circle(wheel, 5.0 * s, Color("#d0d9df"))
		for spoke in range(4):
			var a := wheel_phase + spoke * PI / 2.0
			draw_line(wheel, wheel + Vector2(cos(a), sin(a)) * 8.0 * s, Color("#273746"), 2.0 * s)

func _draw_menu_car() -> void:
	_draw_car(Vector2(390, 520 + sin(elapsed * 2.0) * 5.0), Color("#e64f46"), 2.0, elapsed * 2.5)
	draw_circle(Vector2(390, 550), 120, Color(0.2, 0.65, 0.8, 0.07))
	for i in range(8):
		var x := 70.0 + i * 72.0
		draw_line(Vector2(x, 580), Vector2(x + 45, 580), Color(1, 1, 1, 0.12), 3.0)

func _draw_garage_car() -> void:
	var car: Dictionary = CARS[selected_car]
	_draw_car(Vector2(940, 415), car["color"], 2.25, elapsed * 2.0)
	draw_circle(Vector2(940, 440), 145, Color(0.2, 0.65, 0.8, 0.08))
	draw_rect(Rect2(735, 500, 410, 4), Color("#6b8298", 0.5))
	draw_rect(Rect2(785, 507, 310, 3), Color("#6b8298", 0.25))
