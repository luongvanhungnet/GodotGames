extends Control

const ParcelRules = preload("res://game/parcel_rules.gd")
const BlockRules = preload("res://game/block_rules.gd")
const PuzzleBoard = preload("res://ui/puzzle_board.gd")
const INK := Color("203d43")
const MUTED := Color("778783")
const CREAM := Color("f5f2e9")
const PAPER := Color("fffdf7")
const CORAL := Color("ec7159")
const TEAL := Color("368d80")
var save_path := "user://progress.json"
var levels: Dictionary = {}
var progress: Dictionary = {"parcel": [], "block": [], "last_parcel": 0, "last_block": 0}
var mode := "parcel"
var level_index := 0
var rules
var board
var page: VBoxContainer
var status_label: Label
var delivery_label: Label
var meter: ProgressBar
var undo_button: Button
var arrow_buttons: Array[Button] = []
var screen_name := "home"
var completion_pending := false
var _scroll: ScrollContainer

func _ready() -> void:
	var file := FileAccess.open("res://assets/data/levels.json", FileAccess.READ)
	if file == null:
		push_error("Missing level data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("parcel") or not parsed.has("block"):
		push_error("Invalid level data")
		return
	levels = parsed
	_load_progress()
	var background := ColorRect.new()
	background.name = "Background"
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(margin)
	page = VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	get_tree().auto_accept_quit = false
	show_home()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen_name == "home":
			get_tree().quit()
		else:
			show_home()

func _style(color: Color, radius := 20, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(2)
	return style

func _label(text: String, font_size := 24, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 88
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	button.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("a6afa6"))
	button.add_theme_stylebox_override("normal", _style(INK if primary else PAPER))
	button.add_theme_stylebox_override("hover", _style(INK.lightened(0.1) if primary else Color("e9eddf")))
	button.add_theme_stylebox_override("pressed", _style(TEAL if primary else Color("d8e4d4")))
	button.add_theme_stylebox_override("disabled", _style(Color("e9e9df")))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 20, TEAL))
	button.pressed.connect(callback)
	return button

func _clear_page() -> void:
	completion_pending = false
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	board = null
	arrow_buttons.clear()
	_scroll.scroll_vertical = 0

func _header(tag: String) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label("POCKET / PUZZLE", 20))
	var badge := _label(tag, 17, TEAL)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(badge)
	page.add_child(row)
	var line := HSeparator.new()
	line.modulate = Color("cbd3c4")
	page.add_child(line)

func show_home() -> void:
	_clear_page()
	screen_name = "home"
	_header("THE PLAYTEST COLLECTION")
	page.add_child(_label("A little order.\nA lot of satisfaction.", 49))
	page.add_child(_label("Two pocket-sized puzzles. Find your favorite.", 23, MUTED))
	_add_game_card("parcel", "01 / PARCEL SORT", "Make every delivery.", "Send parcels in the right order. Keep the waiting area clear.", CORAL)
	_add_game_card("block", "02 / BLOCK EXIT", "Find a way through.", "Slide each block through its matching gate. One move at a time.", TEAL)
	var completed: int = progress.parcel.size() + progress.block.size()
	var collection := PanelContainer.new()
	collection.add_theme_stylebox_override("panel", _style(PAPER))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	contents.add_child(_label("YOUR LITTLE COLLECTION", 18, MUTED))
	contents.add_child(_label("%d / 60 puzzles complete" % completed, 29))
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.max_value = 60
	bar.value = completed
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("e7eadd"), 5))
	bar.add_theme_stylebox_override("fill", _style(TEAL, 5))
	contents.add_child(bar)
	collection.add_child(contents)
	page.add_child(collection)
	page.add_child(_label("OFFLINE PLAY  /  NO ADS  /  NO PURCHASES", 17, MUTED))

func _add_game_card(game_mode: String, eyebrow: String, title: String, description: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PAPER, 26))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	contents.add_child(_label(eyebrow, 18, accent))
	contents.add_child(_label(title, 34))
	contents.add_child(_label(description, 23, MUTED))
	var number: int = int(progress["last_" + game_mode])
	var play := _button("Play level %02d   >" % (number + 1), start_level.bind(game_mode, number), true)
	play.add_theme_stylebox_override("normal", _style(accent))
	contents.add_child(play)
	panel.add_child(contents)
	page.add_child(panel)

func show_levels(game_mode: String) -> void:
	_clear_page()
	screen_name = "levels"
	mode = game_mode
	_header("CHOOSE YOUR PUZZLE")
	page.add_child(_label("Parcel Sort" if mode == "parcel" else "Block Exit", 46))
	page.add_child(_label("All 30 levels are open. Completed puzzles have a dot.", 23, MUTED))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in range(30):
		var done: bool = progress[mode].has(i)
		var button := _button("%02d%s" % [i + 1, " ." if done else ""], start_level.bind(mode, i), done)
		button.custom_minimum_size = Vector2(100, 94)
		grid.add_child(button)
	page.add_child(grid)
	page.add_child(_button("Back to collection", show_home))

func start_level(game_mode: String, number: int) -> void:
	_clear_page()
	screen_name = "game"
	mode = game_mode
	level_index = clampi(number, 0, levels[mode].size() - 1)
	progress["last_" + mode] = level_index
	_save_progress()
	rules = ParcelRules.new() if mode == "parcel" else BlockRules.new()
	rules.setup(levels[mode][level_index])
	_header("PARCEL SORT" if mode == "parcel" else "BLOCK EXIT")
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	var home_button := _button("< Home", show_home)
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav.add_child(home_button)
	nav.add_child(_button("LEVEL %02d / 30" % (level_index + 1), show_levels.bind(mode)))
	page.add_child(nav)
	page.add_child(_label("Make room for the right delivery." if mode == "parcel" else "Every color has a way out.", 30))
	page.add_child(_label("Tap a queue. Matching parcels deliver automatically; others wait." if mode == "parcel" else "Tap a block, then swipe or use the arrows. Match its symbol to a gate.", 23, MUTED))
	delivery_label = _label("", 21, TEAL)
	page.add_child(delivery_label)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 8
	meter.show_percentage = false
	meter.add_theme_stylebox_override("background", _style(Color("dfe4d7"), 4))
	meter.add_theme_stylebox_override("fill", _style(TEAL, 4))
	page.add_child(meter)
	board = PuzzleBoard.new()
	board.name = "PuzzleBoard"
	board.mode = mode
	board.rules = rules
	board.custom_minimum_size.y = 610 if mode == "parcel" else 540
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.played.connect(play_move)
	board.selection_changed.connect(_update_arrows)
	page.add_child(board)
	if mode == "block":
		var arrows := HBoxContainer.new()
		arrows.add_theme_constant_override("separation", 12)
		var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
		var names := ["<", "^", "v", ">"]
		for i in range(4):
			var button := _button(names[i], _arrow_move.bind(directions[i]), true)
			button.tooltip_text = ["Move left", "Move up", "Move down", "Move right"][i]
			arrow_buttons.append(button)
			arrows.add_child(button)
		page.add_child(arrows)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	undo_button = _button("Undo", undo_move)
	actions.add_child(undo_button)
	actions.add_child(_button("Restart", start_level.bind(mode, level_index)))
	page.add_child(actions)
	status_label = _label("No rush. Every puzzle has a solution.", 21, MUTED)
	status_label.custom_minimum_size.y = 42
	page.add_child(status_label)
	_refresh()

func _arrow_move(direction: Vector2i) -> void:
	if board != null:
		play_move(board.selected, direction)

func play_move(index: int, direction: Vector2i) -> void:
	if screen_name != "game" or completion_pending:
		return
	var before: int = rules.delivered if mode == "parcel" else rules.remaining()
	var accepted: bool = rules.send(index) if mode == "parcel" else rules.move_piece(index, direction)
	if not accepted:
		status_label.text = "No room. Deliver a matching parcel or undo." if mode == "parcel" else "That way is blocked. Try a clear path to the matching gate."
		return
	board.celebrate_move()
	if mode == "parcel":
		var count: int = rules.delivered - before
		status_label.text = "%d delivered. Nice work!" % count if count > 0 else "Parked for later. Keep a waiting slot free."
		if rules.stuck():
			status_label.text = "Waiting area full. Undo a move or restart to try a new order."
	else:
		status_label.text = "A perfect fit. Block delivered!" if rules.remaining() < before else "Keep going. Clear a path to the gate."
	_refresh()
	if rules.won():
		completion_pending = true
		var current_board = board
		await get_tree().create_timer(0.4).timeout
		if screen_name == "game" and board == current_board and completion_pending:
			show_result()

func undo_move() -> void:
	if screen_name != "game" or completion_pending:
		return
	if rules.undo():
		status_label.text = "One step back. A fresh possibility."
		board.queue_redraw()
		_refresh()

func _refresh() -> void:
	if mode == "parcel":
		delivery_label.text = "%d / %d delivered   /   %d moves" % [rules.delivered, rules.route.size(), rules.moves]
		meter.max_value = rules.route.size()
		meter.value = rules.delivered
	else:
		delivery_label.text = "%d blocks to go   /   %d moves" % [rules.remaining(), rules.moves]
		meter.max_value = rules.pieces.size()
		meter.value = rules.pieces.size() - rules.remaining()
	undo_button.disabled = rules.history.is_empty()
	_update_arrows()

func _update_arrows() -> void:
	if mode != "block" or board == null:
		return
	var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	for i in range(arrow_buttons.size()):
		arrow_buttons[i].disabled = not rules.can_move(board.selected, directions[i])

func show_result() -> void:
	var move_count: int = rules.moves
	if not progress[mode].has(level_index):
		progress[mode].append(level_index)
	progress["last_" + mode] = mini(level_index + 1, 29)
	_save_progress()
	_clear_page()
	screen_name = "result"
	_header("A LITTLE VICTORY")
	var space := Control.new()
	space.custom_minimum_size.y = 80
	page.add_child(space)
	page.add_child(_label("Perfectly\nin its place.", 64, TEAL))
	page.add_child(_label("Level %02d complete in %d moves." % [level_index + 1, move_count], 28))
	page.add_child(_label("%d / 60 puzzles in your collection." % (progress.parcel.size() + progress.block.size()), 24, MUTED))
	page.add_child(_button("Next puzzle   >" if level_index < 29 else "Back to collection", start_level.bind(mode, level_index + 1) if level_index < 29 else show_home, true))
	page.add_child(_button("Try the other game", start_level.bind("block" if mode == "parcel" else "parcel", 0)))
	page.add_child(_button("Choose a level", show_levels.bind(mode)))
	page.add_child(_button("Home", show_home))

func _load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var saved: Variant = JSON.parse_string(file.get_as_text())
	if not saved is Dictionary:
		return
	for game_mode in ["parcel", "block"]:
		if saved.get(game_mode) is Array:
			for number in saved[game_mode]:
				if (number is float or number is int) and float(number) == floorf(float(number)) and int(number) >= 0 and int(number) < 30 and not progress[game_mode].has(int(number)):
					progress[game_mode].append(int(number))
		var last: Variant = saved.get("last_" + game_mode, 0)
		if last is float or last is int:
			progress["last_" + game_mode] = clampi(int(last), 0, 29)

func _save_progress() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(progress))
	else:
		push_warning("Local progress could not be saved")
