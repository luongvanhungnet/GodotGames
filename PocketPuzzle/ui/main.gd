extends Control

const ParcelRules = preload("res://game/parcel_rules.gd")
const BlockRules = preload("res://game/block_rules.gd")
const PuzzleBoard = preload("res://ui/puzzle_board.gd")
const PlayerRecords = preload("res://game/player_records.gd")
const SolveClock = preload("res://game/solve_clock.gd")
const Look = preload("res://ui/friendly_theme.gd")
const Art = preload("res://ui/playful_art.gd")
const STAR = preload("res://assets/ui/star.svg")
const INK := Look.INK
const MUTED := Look.MUTED
const CREAM := Look.BACKGROUND
const PAPER := Look.PAPER
const CORAL := Look.ROSE
const TEAL := Look.MINT
var save_path := "user://progress.json"
var levels: Dictionary = {}
var progress: Dictionary = {"parcel": [], "block": [], "last_parcel": 0, "last_block": 0}
var records = PlayerRecords.new()
var solve_clock = SolveClock.new()
var attempt_moves := 0
var undo_count := 0
var _run_recorded := false
var _timer_tenth := -1
var _app_suspended := false
var _app_unfocused := false
var stats_label: Label
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
	theme = Theme.new()
	theme.default_font = Look.regular_font()
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
	var decorations = Art.new()
	decorations.kind = "background"
	decorations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(decorations)
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
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if what == NOTIFICATION_APPLICATION_PAUSED:
			_app_suspended = true
		else:
			_app_unfocused = true
		solve_clock.pause(Time.get_ticks_msec())
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if what == NOTIFICATION_APPLICATION_RESUMED:
			_app_suspended = false
		else:
			_app_unfocused = false
		if not _app_suspended and not _app_unfocused:
			solve_clock.resume(Time.get_ticks_msec())

func _process(_delta: float) -> void:
	if screen_name == "game" and not completion_pending:
		solve_clock.tick(Time.get_ticks_msec())
		var tenth := int(solve_clock.elapsed_ms / 100)
		if tenth != _timer_tenth:
			_timer_tenth = tenth
			_update_stats()

func _update_stats() -> void:
	if is_instance_valid(stats_label):
		stats_label.text = "%s   /   Moves %d   /   Undo %d" % [SolveClock.format_time(solve_clock.elapsed_ms), attempt_moves, undo_count]

func _level_counts() -> Dictionary:
	return {"parcel": levels.parcel.size(), "block": levels.block.size()}

func _total_levels() -> int:
	return levels.parcel.size() + levels.block.size()

func _style(color: Color, radius := 26, border := Color.TRANSPARENT) -> StyleBoxFlat:
	return Look.box(color, radius, border if border.a > 0 else Color("e9e0f2"), color.a > 0)

func _meter_style(color: Color) -> StyleBoxFlat:
	var style := Look.box(color, 8)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _art(kind: String, minimum: Vector2) -> Control:
	var art = Art.new()
	art.kind = kind
	art.custom_minimum_size = minimum
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return art

func _label(text: String, font_size := 24, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 26:
		label.add_theme_font_override("font", Look.bold_font())
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size.y = 88
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", Look.bold_font())
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	button.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	button.add_theme_color_override("font_focus_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_pressed_color", PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("aaa0b8"))
	button.add_theme_stylebox_override("normal", _style(Look.PURPLE if primary else PAPER))
	button.add_theme_stylebox_override("hover", _style(Look.PURPLE.lightened(0.1) if primary else Color("f1eafb")))
	var pressed := _style(Look.PURPLE.darkened(0.1) if primary else Color("e8dcf6"))
	pressed.content_margin_top = 18
	pressed.content_margin_bottom = 10
	pressed.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", Look.box(Color("eee9f4"), 26))
	button.add_theme_stylebox_override("focus", Look.box(Color.TRANSPARENT, 26, Look.PURPLE))
	button.pressed.connect(callback)
	return button

func _clear_page() -> void:
	solve_clock.finish(Time.get_ticks_msec())
	stats_label = null
	completion_pending = false
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	board = null
	arrow_buttons.clear()
	_scroll.scroll_vertical = 0

func _header(tag: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_art("mark", Vector2(38, 40)))
	var brand := _label("PocketPuzzle", 26)
	brand.custom_minimum_size.x = 188
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(brand)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pill_style := Look.box(Color("eee5fa"), 18)
	pill_style.content_margin_top = 7
	pill_style.content_margin_bottom = 7
	pill.add_theme_stylebox_override("panel", pill_style)
	var badge := _label(tag.capitalize(), 15, Look.PURPLE)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(badge)
	row.add_child(pill)
	page.add_child(row)

func show_home() -> void:
	_clear_page()
	screen_name = "home"
	_header("A HAPPY LITTLE BREAK")
	var welcome := HBoxContainer.new()
	welcome.add_theme_constant_override("separation", 12)
	var greeting := VBoxContainer.new()
	greeting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greeting.add_child(_label("Little puzzles,\nbig smiles.", 46))
	greeting.add_child(_label("Pick a pal. Find your happy place.", 22, MUTED))
	welcome.add_child(greeting)
	welcome.add_child(_art("welcome", Vector2(138, 145)))
	page.add_child(welcome)
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 12)
	player_row.add_child(_button("Player: " + records.current().name, show_players))
	player_row.add_child(_button("Rankings", show_rankings))
	page.add_child(player_row)
	_add_game_card("parcel", "PARCEL SORT", "A bundle of joy.", "Happy mail needs a little help. Match the parcels and make room!", CORAL)
	_add_game_card("block", "BLOCK EXIT", "Give pals a way out.", "A little nudge, a happy exit. Find the matching gate for each pal.", TEAL)
	var completed: int = progress.parcel.size() + progress.block.size()
	var collection := PanelContainer.new()
	collection.add_theme_stylebox_override("panel", _style(PAPER))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	var total_score := 0
	for row in records.ranking():
		if row.id == records.active_id:
			total_score = int(row.score)
	contents.add_child(_label("YOUR HAPPY LITTLE COLLECTION", 17, Look.PURPLE))
	contents.add_child(_label("%d / %d puzzles   /   %d points" % [completed, _total_levels(), total_score], 25))
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.max_value = _total_levels()
	bar.value = completed
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _meter_style(Color("eee5f7")))
	bar.add_theme_stylebox_override("fill", _meter_style(Color("b99cdc")))
	contents.add_child(bar)
	collection.add_child(contents)
	page.add_child(collection)
	var footer := _label("A cozy little break. Offline, ad-free, and all yours.", 18, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(footer)

func _add_game_card(game_mode: String, eyebrow: String, title: String, description: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("fff0f1") if game_mode == "parcel" else Color("eaf7ef"), 30, Color("f0d7df") if game_mode == "parcel" else Color("cde7db")))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 16)
	preview.add_child(_art(game_mode, Vector2(130, 132)))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	copy.add_child(_label(eyebrow + "  /  %d puzzles" % levels[game_mode].size(), 16, accent))
	copy.add_child(_label(title, 30))
	copy.add_child(_label(description, 21, MUTED))
	preview.add_child(copy)
	contents.add_child(preview)
	var number: int = int(progress["last_" + game_mode])
	var play := _button("Let's play!   /   Level %02d   >" % (number + 1), start_level.bind(game_mode, number), true)
	play.custom_minimum_size.y = 80
	play.add_theme_stylebox_override("normal", _style(accent, 24, accent.lightened(0.15)))
	play.add_theme_stylebox_override("hover", _style(accent.lightened(0.08)))
	play.add_theme_stylebox_override("pressed", _style(accent.darkened(0.08)))
	contents.add_child(play)
	panel.add_child(contents)
	page.add_child(panel)

func show_levels(game_mode: String, page_number: int = -1) -> void:
	_clear_page()
	screen_name = "levels"
	mode = game_mode
	_header("CHOOSE YOUR PUZZLE")
	page.add_child(_label("Parcel Sort" if mode == "parcel" else "Block Exit", 46))
	var count: int = levels[mode].size()
	var current_page := clampi(int(level_index / 30) if page_number < 0 else page_number, 0, int((count - 1) / 30))
	page.add_child(_label("%d little adventures. Collect a star for every solve!" % count, 22, MUTED))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in range(current_page * 30, mini(current_page * 30 + 30, count)):
		var done: bool = progress[mode].has(i)
		var button := _button("%02d" % (i + 1), start_level.bind(mode, i))
		button.add_theme_stylebox_override("normal", _style(Color("def0e5") if done else PAPER, 24, Color("b8d8c7") if done else Color("e9e0f2")))
		if done:
			button.icon = STAR
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 22)
		button.custom_minimum_size = Vector2(100, 94)
		grid.add_child(button)
	page.add_child(grid)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	var previous := _button("< Previous", show_levels.bind(mode, current_page - 1))
	previous.disabled = current_page == 0
	navigation.add_child(previous)
	var next := _button("Next >", show_levels.bind(mode, current_page + 1))
	next.disabled = (current_page + 1) * 30 >= count
	navigation.add_child(next)
	page.add_child(navigation)
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
	attempt_moves = 0
	undo_count = 0
	_run_recorded = false
	_timer_tenth = -1
	_header("PARCEL SORT" if mode == "parcel" else "BLOCK EXIT")
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	var home_button := _button("< Home", show_home)
	home_button.custom_minimum_size.x = 130
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav.add_child(home_button)
	nav.add_child(_button("LEVEL %02d / %d" % [level_index + 1, levels[mode].size()], show_levels.bind(mode)))
	page.add_child(nav)
	page.add_child(_label("Let's send a little happiness!" if mode == "parcel" else "A little nudge. A happy exit.", 30))
	page.add_child(_label("Tap a queue to send a parcel. Extras wait for their turn." if mode == "parcel" else "Tap a pal, then swipe or use the arrows. Find its matching gate!", 22, MUTED))
	stats_label = _label("", 22, INK)
	page.add_child(stats_label)
	delivery_label = _label("", 20, TEAL)
	page.add_child(delivery_label)
	meter = ProgressBar.new()
	meter.custom_minimum_size.y = 8
	meter.show_percentage = false
	meter.add_theme_stylebox_override("background", _meter_style(Color("e9e0f3")))
	meter.add_theme_stylebox_override("fill", _meter_style(Color("b89bd8")))
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
	status_label = _label("Take your time, puzzle pal. You've got this!", 21, MUTED)
	status_label.custom_minimum_size.y = 42
	page.add_child(status_label)
	solve_clock.start(Time.get_ticks_msec())
	if _app_suspended or _app_unfocused:
		solve_clock.pause(Time.get_ticks_msec())
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
		status_label.text = "A little crowded! Try a matching parcel, or undo." if mode == "parcel" else "Oops, a cozy squeeze! Try another way to the matching gate."
		return
	attempt_moves += 1
	board.celebrate_move()
	if mode == "parcel":
		var count: int = rules.delivered - before
		status_label.text = "Lovely! %d parcels delivered." % count if count > 0 else "Cozy for now. Keep a waiting spot free!"
		if rules.stuck():
			status_label.text = "All spots are full. Undo and try a fresh little order."
	else:
		status_label.text = "Hooray! One happy pal is home." if rules.remaining() < before else "A little closer! Let's find that happy exit."
	_refresh()
	if rules.won():
		solve_clock.finish(Time.get_ticks_msec())
		_update_stats()
		completion_pending = true
		var current_board = board
		await get_tree().create_timer(0.4).timeout
		if screen_name == "game" and board == current_board and completion_pending:
			show_result()

func undo_move() -> void:
	if screen_name != "game" or completion_pending:
		return
	if rules.undo():
		undo_count += 1
		status_label.text = "A tiny rewind. A fresh possibility!"
		board.queue_redraw()
		_refresh()

func _refresh() -> void:
	var best: Dictionary = records.best(mode, level_index)
	var high: int = int(best.get("high_score", 0))
	if mode == "parcel":
		delivery_label.text = "%d / %d delivered   /   HIGH SCORE %d" % [rules.delivered, rules.route.size(), high]
		meter.max_value = rules.route.size()
		meter.value = rules.delivered
	else:
		delivery_label.text = "%d blocks to go   /   HIGH SCORE %d" % [rules.remaining(), high]
		meter.max_value = rules.pieces.size()
		meter.value = rules.pieces.size() - rules.remaining()
	undo_button.disabled = rules.history.is_empty()
	_update_stats()
	_update_arrows()

func _update_arrows() -> void:
	if mode != "block" or board == null:
		return
	var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	for i in range(arrow_buttons.size()):
		arrow_buttons[i].disabled = not rules.can_move(board.selected, directions[i])

func show_result() -> void:
	if screen_name != "game" or not rules.won() or _run_recorded:
		return
	_run_recorded = true
	solve_clock.finish(Time.get_ticks_msec())
	var result: Dictionary = records.record(mode, level_index, solve_clock.elapsed_ms, attempt_moves, undo_count)
	if not progress[mode].has(level_index):
		progress[mode].append(level_index)
	progress["last_" + mode] = mini(level_index + 1, levels[mode].size() - 1)
	_save_progress()
	_clear_page()
	screen_name = "result"
	_header("A LITTLE VICTORY")
	page.add_child(_art("victory", Vector2(0, 145)))
	var cheer := _label("You did it, puzzle pal!", 42, Look.PURPLE)
	cheer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(cheer)
	var score_card := PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", _style(Color("eee5fa"), 28, Color("d8c7ed")))
	var score_label := _label("%d points%s" % [result.score, "   /   A new best!" if result.new_high else ""], 30, Look.PURPLE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_card.add_child(score_label)
	page.add_child(score_card)
	page.add_child(_label("Solved in %s   /   Moves %d   /   Undo %d" % [SolveClock.format_time(solve_clock.elapsed_ms), attempt_moves, undo_count], 23))
	page.add_child(_label("Level best: %d points\nFastest: %s   /   Fewest moves: %d\nTimes solved: %d" % [result.best.high_score, SolveClock.format_time(int(result.best.best_time_ms)), result.best.fewest_moves, result.best.solves], 23, MUTED))
	page.add_child(_label("%d / %d puzzles in your collection." % [progress.parcel.size() + progress.block.size(), _total_levels()], 22, MUTED))
	page.add_child(_button("One more little puzzle   >" if level_index < levels[mode].size() - 1 else "Back to collection", start_level.bind(mode, level_index + 1) if level_index < levels[mode].size() - 1 else show_home, true))
	page.add_child(_button("Say hello to the other game", start_level.bind("block" if mode == "parcel" else "parcel", 0)))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	options.add_child(_button("Pick a level", show_levels.bind(mode)))
	options.add_child(_button("Rankings", show_rankings))
	page.add_child(options)
	page.add_child(_button("Back to our happy place", show_home))

func show_players() -> void:
	_clear_page()
	screen_name = "players"
	_header("PLAYERS ON THIS DEVICE")
	page.add_child(_label("Hello, puzzle pal!", 44))
	page.add_child(_label("Up to 8 local players. Each has their own progress and records.", 23, MUTED))
	var name_input := LineEdit.new()
	name_input.name = "PlayerName"
	name_input.placeholder_text = "Player name"
	name_input.max_length = 18
	name_input.custom_minimum_size.y = 88
	name_input.add_theme_font_size_override("font_size", 28)
	name_input.add_theme_color_override("font_color", INK)
	name_input.add_theme_color_override("font_placeholder_color", MUTED)
	name_input.add_theme_stylebox_override("normal", _style(PAPER))
	name_input.add_theme_stylebox_override("focus", _style(PAPER, 26, Look.PURPLE))
	page.add_child(name_input)
	var message := _label("Choose a player, or enter a name above.", 21, MUTED)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.add_child(_button("Add player", _add_player.bind(name_input, message), true))
	actions.add_child(_button("Rename current", _rename_player.bind(name_input, message)))
	page.add_child(actions)
	page.add_child(message)
	for player in records.players:
		page.add_child(_button(("Selected: " if player.id == records.active_id else "Play as: ") + player.name, _select_player.bind(player.id), player.id == records.active_id))
	page.add_child(_button("Back to collection", show_home))

func _add_player(input: LineEdit, message: Label) -> void:
	if records.add_player(input.text).is_empty():
		message.text = "Use a unique name (1-18 characters). Up to 8 players can be saved."
		return
	progress = records.current().progress
	_save_progress()
	show_home()

func _rename_player(input: LineEdit, message: Label) -> void:
	if not records.rename_current(input.text):
		message.text = "Choose a unique name with 1-18 characters."
		return
	_save_progress()
	show_players()

func _select_player(id: String) -> void:
	if records.select_player(id):
		progress = records.current().progress
		_save_progress()
		show_home()

func show_rankings(game_mode: String = "all") -> void:
	_clear_page()
	screen_name = "rankings"
	_header("LOCAL PLAYER RANKINGS")
	page.add_child(_label("Our little hall of happy.", 40))
	page.add_child(_label("Best score per level counts once. Ties use levels solved, then total best times.", 22, MUTED))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 12)
	for key in ["all", "parcel", "block"]:
		filters.add_child(_button({"all": "All games", "parcel": "Parcel", "block": "Block"}[key], show_rankings.bind(key), key == game_mode))
	page.add_child(filters)
	for row in records.ranking(game_mode):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("f0e8fb") if row.id == records.active_id else PAPER, 28, Color("c7b0e1") if row.id == records.active_id else Color("e7dfee")))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)
		var avatar = _art("avatar", Vector2(74, 74))
		avatar.variant = int(row.rank) - 1
		line.add_child(avatar)
		var contents := VBoxContainer.new()
		contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var place := "#%d" % row.rank if row.completed > 0 else "--"
		contents.add_child(_label("%s   %s%s" % [place, row.name, "  (you)" if row.id == records.active_id else ""], 27))
		contents.add_child(_label("%d points   /   Levels scored: %d" % [row.score, row.completed], 22, Look.PURPLE))
		contents.add_child(_label("Total best times: " + SolveClock.format_time(int(row.time_ms)), 20, MUTED))
		line.add_child(contents)
		panel.add_child(line)
		page.add_child(panel)
	page.add_child(_label("Rankings are saved on this phone. Scores reward speed and efficient moves; undo has a penalty.", 21, MUTED))
	page.add_child(_button("Switch player", show_players))
	page.add_child(_button("Back to collection", show_home))

func _load_progress() -> void:
	var saved: Variant = {}
	if not FileAccess.file_exists(save_path):
		records.restore({}, _level_counts())
	else:
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			saved = JSON.parse_string(file.get_as_text())
		records.restore(saved if saved is Dictionary else {}, _level_counts())
	progress = records.current().progress

func _save_progress() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(records.to_data()))
	else:
		push_warning("Local progress could not be saved")
