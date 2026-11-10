extends SceneTree
const Daily = preload("res://game/daily_puzzle.gd")
const Session = preload("res://game/run_session.gd")
const Store = preload("res://game/save_store.gd")
const Records = preload("res://game/player_records.gd")
const Feedback = preload("res://ui/feedback.gd")
const Lesson = preload("res://game/tutorial.gd")
const TEST_SAVE := "user://pocketpuzzle-daily-joy-test.json"
var failures := 0
var checks := 0
var levels: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _cleanup(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Daily Joy tests timed out"); quit(1))
	levels = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/levels.json"))
	_test_daily()
	_test_sessions()
	_test_store()
	_test_sound()
	await _test_ui()
	if failures == 0:
		print("PASS: Daily Joy, tutorials, sound settings, validated resume, backups, profile isolation, and midnight rollover (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _test_daily() -> void:
	_check(Daily.valid_date("2028-02-29") and not Daily.valid_date("2026-02-29") and not Daily.valid_date("2026-+1-01") and not Daily.valid_date("bad"), "Strict local-date validation")
	for mode in ["parcel", "block"]:
		var index: int = Daily.level_for("2026-11-11", mode, 150)
		_check(index >= 0 and index < 150 and index == Daily.level_for("2026-11-11", mode, 300), "Daily schedule is stable when catalogue expands")
	_check(Daily.level_for("2026-11-11", "parcel", 150) != Daily.level_for("2026-11-12", "parcel", 150), "Daily puzzle changes on the next date")
	var records = Records.new()
	records.record_daily("2026-11-11", "parcel", 12000, 8, 0)
	records.record_daily("2026-11-11", "parcel", 15000, 10, 1)
	_check(records.best_daily("2026-11-11", "parcel").solves == 2 and records.ranking()[0].score == 0, "Daily replays keep personal bests without affecting regular rankings")
	var first: String = records.active_id
	records.current().sessions.parcel = {"version": 1, "mode": "parcel", "kind": "normal", "actions": []}
	records.add_player("Second")
	_check(records.best_daily("2026-11-11", "parcel").is_empty() and records.current().sessions.is_empty(), "Daily records and unfinished games are private to each local profile")
	records.select_player(first)
	records.settings.sound = false
	records.current().tutorials.parcel = true
	var copy = Records.new()
	copy.restore(JSON.parse_string(JSON.stringify(records.to_data())), {"parcel": 150, "block": 150})
	_check(copy.best_daily("2026-11-11", "parcel").solves == 2 and not copy.settings.sound and copy.current().tutorials.parcel, "Daily records, preferences and lessons persist")
	for month in range(1, 5):
		for day in range(1, 29):
			records.record_daily("2027-%02d-%02d" % [month, day], "block", 1000, 7, 0)
	_check(records.current().daily_results.size() == 90 and not records.current().daily_results.has("2027-01-01") and records.current().daily_results.has("2027-04-28"), "Daily history retains the newest 90 dates")

func _test_sessions() -> void:
	var data: Dictionary = Session.snapshot("parcel", 1, "normal", "", int(levels.parcel[1].seed), [[1], [0]], 12340, 3, 1, -1)
	var restored := Session.restore(JSON.parse_string(JSON.stringify(data)), levels)
	_check(not restored.is_empty() and restored.rules.waiting == [1] and restored.rules.delivered == 1 and restored.moves == 3 and restored.undos == 1 and restored.elapsed_ms == 12340, "Parcel save restores waiting parcels and exact counters")
	_check(restored.rules.undo() and restored.rules.waiting.is_empty(), "Undo history survives restoration")
	var invalid := data.duplicate(true)
	invalid.moves = 0
	_check(Session.restore(invalid, levels).is_empty(), "Reject inconsistent move and undo counters")
	invalid = data.duplicate(true)
	invalid.actions = [[8], [0]]
	_check(Session.restore(invalid, levels).is_empty(), "Reject invalid queue indices")
	invalid = data.duplicate(true)
	invalid.seed = -10
	_check(Session.restore(invalid, levels).is_empty(), "Reject a session for a changed level")
	var block: Dictionary = Session.snapshot("block", 0, "normal", "", int(levels.block[0].seed), [[0, 0, 1], [0, 0, 1]], 5000, 2, 0, 0)
	restored = Session.restore(block, levels)
	_check(not restored.is_empty() and restored.rules.pieces[0].y == 2 and restored.selected == 0 and restored.rules.undo() and restored.rules.pieces[0].y == 1, "Block geometry, selection and undo survive restoration")
	block.actions = [[0, 1, 1], [0, 0, 1]]
	_check(Session.restore(block, levels).is_empty(), "Reject illegal block directions")
	var winning: Array = []
	for action in levels.parcel[0].solution:
		winning.append([action])
	_check(Session.restore(Session.snapshot("parcel", 0, "normal", "", int(levels.parcel[0].seed), winning, 1000, 6, 0, -1), levels).is_empty(), "Completed games cannot be resumed or scored twice")
	var daily_index: int = Daily.level_for("2026-11-11", "parcel", 150)
	data = Session.snapshot("parcel", daily_index, "daily", "2026-11-11", int(levels.parcel[daily_index].seed), [], 0, 0, 0, -1)
	_check(not Session.restore(data, levels).is_empty(), "A daily session validates against its date")
	data.day = "bad"
	_check(Session.restore(data, levels).is_empty(), "Reject malformed daily dates")

func _test_store() -> void:
	var path := TEST_SAVE + ".store"
	_cleanup(path)
	_check(Store.save_data(path, {"generation": 1}) and Store.save_data(path, {"generation": 2}), "Save can atomically replace an existing file")
	_check(Store.load_data(path).get("generation") == 2, "Latest save loads")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{interrupted")
	file.close()
	_check(Store.load_data(path).get("generation") == 1, "An interrupted primary save recovers its backup")
	_check(Store.save_data(path, {"generation": 3}) and Store.load_data(path).get("generation") == 3, "Saving recovers after a corrupt primary file")
	_cleanup(path)

func _test_sound() -> void:
	var sound := Feedback.tone([523.25, 659.25], 0.1)
	var loudest := 0
	for i in range(0, sound.data.size(), 2):
		loudest = maxi(loudest, absi(sound.data.decode_s16(i)))
	_check(sound.mix_rate == 22050 and sound.format == AudioStreamWAV.FORMAT_16_BITS and not sound.stereo and loudest > 0 and loudest < 16000 and sound.data.decode_s16(0) == 0, "Chimes are bounded, non-silent PCM with a soft attack")

func _test_ui() -> void:
	_cleanup(TEST_SAVE)
	var scene = load("res://node_2d.tscn")
	var screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	screen.date_override = "2026-11-11"
	root.add_child(screen)
	screen.records.settings.sound = false
	screen.feedback.configure(screen.records.settings)
	screen.open_game("parcel")
	_check(screen.run_kind == "tutorial", "First-time players receive a guided lesson")
	screen.play_move(0, Vector2i.ZERO)
	_check(screen.attempt_moves == 0, "Tutorial safely guides an incorrect first tap")
	for action in Lesson.PARCEL_PATH:
		screen.play_move(action, Vector2i.ZERO)
	await create_timer(0.5).timeout
	_check(screen.records.current().tutorials.parcel and screen.progress.parcel.is_empty() and screen.records.ranking()[0].score == 0, "Parcel tutorial teaches waiting without awarding ranked points")
	screen.start_tutorial("block")
	screen.board.selected = 0
	screen._update_arrows()
	_check(not screen.arrow_buttons[2].disabled and screen.arrow_buttons[0].disabled, "Block lesson enables the guided arrow")
	for action in levels.block[0].solution:
		screen.play_move(int(action[0]), Vector2i(int(action[1]), int(action[2])))
	await create_timer(0.5).timeout
	_check(screen.records.current().tutorials.block and screen.progress.block.is_empty(), "Block tutorial stays unranked")
	screen.start_level("parcel", 1)
	screen.play_move(1, Vector2i.ZERO)
	screen.play_move(0, Vector2i.ZERO)
	screen.play_move(0, Vector2i.ZERO)
	screen.undo_move()
	screen.solve_clock.elapsed_ms = 12340
	screen._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var saved_time: int = screen.records.current().sessions.parcel.elapsed_ms
	screen.show_home()
	screen.queue_free()
	await process_frame
	screen = scene.instantiate()
	screen.save_path = TEST_SAVE
	screen.date_override = "2026-11-11"
	root.add_child(screen)
	screen._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	screen.open_game("parcel")
	_check(screen.rules.waiting == [1] and screen.attempt_moves == 3 and screen.undo_count == 1 and screen.solve_clock.elapsed_ms == saved_time, "Full app reload preserves the unfinished board and active solve time")
	screen.show_settings()
	screen._toggle_setting("sound")
	_check(screen._settings_return == "parcel" and screen.records.settings.sound, "Settings toggles retain the return-to-game target")
	screen.resume_saved("parcel")
	_check(screen.attempt_moves == 3 and screen.rules.waiting == [1], "Returning from settings resumes the same attempt")
	screen._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	screen.open_daily("parcel")
	var daily_index: int = screen.level_index
	for action in levels.parcel[daily_index].solution:
		screen.play_move(int(action), Vector2i.ZERO)
	await create_timer(0.5).timeout
	_check(not screen.records.best_daily("2026-11-11", "parcel").is_empty() and screen.records.ranking()[0].score == 0 and screen.records.current().sessions.has("parcel"), "Daily win preserves regular progress and its unfinished attempt")
	screen.date_override = "2026-11-12"
	screen.open_daily("parcel")
	screen.play_move(int(levels.parcel[screen.level_index].solution[0]), Vector2i.ZERO)
	screen.show_home()
	screen.date_override = "2026-11-11"
	screen.open_daily("parcel")
	_check(screen.run_date == "2026-11-11" and screen.level_index == daily_index and screen.attempt_moves == 0, "An old-date daily session does not replace today's puzzle")
	screen.resume_saved("parcel")
	for lane in [0, 1, 2, 2]:
		screen.play_move(lane, Vector2i.ZERO)
	_check(screen.records.best("parcel", 1).fewest_moves == 7 and not screen.records.current().sessions.has("parcel"), "Winning commits records and removes the pending save before the animation")
	screen.show_home()
	await create_timer(0.5).timeout
	_check(screen.screen_name == "home" and screen.records.best("parcel", 1).solves == 1, "Leaving during victory does not lose or duplicate the result")
	screen.queue_free()
	await process_frame
	_cleanup(TEST_SAVE)
