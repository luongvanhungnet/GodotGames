extends SceneTree
const Backup = preload("res://game/backup.gd")
const Reports = preload("res://game/playtest.gd")
const Records = preload("res://game/player_records.gd")
const Session = preload("res://game/run_session.gd")
const Store = preload("res://game/save_store.gd")
const Safe = preload("res://ui/safe_layout.gd")
const BackGuard = preload("res://ui/back_guard.gd")
const SAVE := "user://pocketpuzzle-data-tools-test.json"
const EXPORT := "user://pocketpuzzle-data-export-test.json"
var catalogue: Dictionary
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _cleanup() -> void:
	for path in [SAVE, EXPORT, SAVE + ".before-restore", SAVE + ".feedback"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)

func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Data tools tests timed out"); quit(1))
	catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/levels.json"))
	_cleanup()
	_test_backup()
	_test_reports()
	_test_layout()
	await _test_ui()
	_cleanup()
	if failures == 0:
		print("PASS: backup integrity, full restore validation, recovery, file errors, opt-in reports, deletion, safe areas and interruption (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _test_backup() -> void:
	var records = Records.new()
	records.record("parcel", 0, 12340, 6, 0)
	records.select_avatar("happy_mail")
	records.current().sessions.parcel = Session.snapshot("parcel", 1, "normal", "", int(catalogue.parcel[1].seed), [[2]], 4560, 1, 0, -1)
	records.record_daily("2026-11-11", "block", 1000, 7, 0)
	records.add_player("Second Pal")
	records.settings.sound = false
	var original: Dictionary = records.to_data()
	var encoded := Backup.encode(original)
	var decoded := Backup.decode(encoded, catalogue)
	_check(not decoded.has("error") and Backup.same_data(decoded.data, original) and decoded.players == 2 and decoded.sessions == 1, "Full backup preserves profiles, records, avatars, daily history, settings and legal pending games")
	_check(Backup.decode(encoded.replace("Second Pal", "Changed Pal"), catalogue).has("error"), "Integrity mismatch rejects an altered payload")
	_check(Backup.decode("{broken", catalogue).has("error") and Backup.decode("{}", catalogue).has("error"), "Malformed and unsupported files are rejected")
	var invalid: Dictionary = original.duplicate(true)
	invalid.players[0].results.parcel["0"].high_score = -5
	_check(Backup.decode(Backup.encode(invalid), catalogue).has("error"), "A valid hash cannot hide corrupt records")
	invalid = original.duplicate(true)
	invalid.players[0].sessions.parcel.actions = [[99]]
	_check(Backup.decode(Backup.encode(invalid), catalogue).has("error"), "Invalid pending moves are rejected before replacing saves")
	invalid = original.duplicate(true)
	invalid.players[0].sessions.parcel.seed = -1
	_check(Backup.decode(Backup.encode(invalid), catalogue).has("error"), "Changed-catalogue sessions cannot be restored silently")
	_check(Backup.decode("x".repeat(Backup.MAX_BYTES + 1), catalogue).has("error"), "Oversize files are rejected")
	_check(Backup.write_text(EXPORT, encoded) and not Backup.read(EXPORT, catalogue).has("error"), "Backup export and bounded file read round-trip")
	_check(Backup.read("user://does-not-exist/back.json", catalogue).has("error") and not Backup.write_text("user://does-not-exist/out.json", encoded), "Unavailable files report failure without changing saves")
	var other = Records.new()
	var previous: Dictionary = other.to_data()
	Store.save_data(SAVE, previous)
	_check(Backup.restore(SAVE, previous, original, catalogue) and Backup.same_data(Store.load_data(SAVE), original), "Confirmed restore atomically installs validated data")
	var recovery := Backup.read(SAVE + ".before-restore", catalogue)
	_check(not recovery.has("error") and Backup.same_data(recovery.data, previous), "Separate recovery copy retains the exact pre-restore save")
	Store.save_data(SAVE, original)
	_check(Backup.same_data(Backup.read(SAVE + ".before-restore", catalogue).data, previous), "Ordinary autosave does not overwrite restore recovery")
	_check(not Backup.restore(SAVE, original, invalid, catalogue) and Backup.same_data(Store.load_data(SAVE), original), "Failed validation never replaces a current save")
	_check(not Backup.restore("user://does-not-exist/save.json", original, original, catalogue), "An unwritable recovery destination stops restore before replacing anything")

func _test_reports() -> void:
	var reports = Reports.new()
	_check(reports.entries.is_empty(), "Reports start empty")
	_check(reports.submit("parcel", 1, catalogue, "normal", "", "confusing", "  Which queue?\u0001  "), "Explicit valid feedback can be submitted")
	_check(reports.entries[0].note == "Which queue?" and not reports.entries[0].has("player") and not reports.entries[0].has("score"), "Notes are cleaned without adding profile names, scores or identifiers")
	reports.submit("parcel", 1, catalogue, "normal", "", "right", "a".repeat(300))
	_check(reports.entries.size() == 1 and reports.entries[0].note.length() == 240 and reports.summary().right == 1, "Re-rating replaces a context and notes have a 240-character limit")
	_check(not reports.submit("parcel", 999, catalogue, "normal", "", "hard", "") and not reports.submit("block", 0, catalogue, "daily", "bad", "hard", "") and not reports.submit("block", 0, catalogue, "normal", "", "other", ""), "Invalid report contexts and ratings are rejected")
	for mode in ["parcel", "block"]:
		for number in range(150):
			reports.submit(mode, number, catalogue, "normal", "", "hard", "")
	_check(reports.entries.size() == Reports.MAX_REPORTS, "Local feedback storage remains bounded")
	var data: Dictionary = JSON.parse_string(JSON.stringify(reports.to_data()))
	var reloaded = Reports.new()
	reloaded.restore(data, catalogue)
	_check(reloaded.entries.size() == Reports.MAX_REPORTS, "Feedback survives JSON reload")
	data.entries[0].seed = -1
	reloaded.restore(data, catalogue)
	_check(reloaded.entries.size() == Reports.MAX_REPORTS - 1, "Stale feedback is excluded from current-catalogue reports")

func _test_layout() -> void:
	var back = BackGuard.new()
	_check(back.accept(1000) and not back.accept(1001) and not back.accept(1015) and back.accept(1200), "Paired Android Back deliveries navigate once while a later press remains accepted")
	_check(Safe.insets(Rect2i(0, 80, 1080, 2200), Vector2i(1080, 2400), Vector2(720, 1600)) == Vector4i(0, 54, 0, 80), "Cutout and navigation-bar pixels convert to logical safe-area margins")
	_check(Safe.insets(Rect2i(20, 0, 1040, 2400), Vector2i(1080, 2400), Vector2(720, 1600)).x == 14, "Side cutouts are accounted for")
	_check(Safe.insets(Rect2i(), Vector2i.ZERO, Vector2(720, 1280)) == Vector4i.ZERO, "Unavailable safe-area data falls back without negative margins")

func _test_ui() -> void:
	var scene = load("res://node_2d.tscn")
	var screen = scene.instantiate()
	screen.save_path = SAVE
	root.add_child(screen)
	_check(not screen.records.settings.playtest_feedback and screen.data_tools.reports.entries.is_empty(), "Feedback collection is off until explicitly enabled")
	screen.start_level("parcel", 1)
	screen.play_move(2, Vector2i.ZERO)
	screen.show_settings()
	screen.data_tools.show_page()
	_check(screen.screen_name == "data_tools" and screen.data_tools.return_key == "parcel", "Data tools retain return-to-puzzle context")
	screen.data_tools.show_rating()
	_check(screen.page.find_child("PlaytestNote", true, false) == null, "Off-state rating screen does not collect a note")
	screen.data_tools._enable_feedback()
	var input = screen.page.find_child("PlaytestNote", true, false)
	input.text = "The waiting spots confused me."
	screen.data_tools._submit("confusing", input)
	_check(screen.data_tools.reports.entries.size() == 1 and FileAccess.file_exists(SAVE + ".feedback"), "Explicit rating is stored locally only after submission")
	screen.data_tools._selected(EXPORT, "backup")
	# Direct callback uses a private test path and must refuse overwriting app data.
	_check(screen.data_tools.message.contains("outside"), "Export cannot overwrite live private save files")
	Backup.write_text(EXPORT, Backup.encode(screen.records.to_data()))
	var before: Dictionary = screen.records.to_data()
	screen.data_tools.preview_restore(EXPORT)
	_check(is_instance_valid(screen.data_tools.confirmation) and Backup.same_data(screen.records.to_data(), before), "Restore preview requires confirmation before mutation")
	screen._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not is_instance_valid(screen.data_tools.confirmation) and Backup.same_data(screen.records.to_data(), before) and screen.data_tools.pending.is_empty(), "Android Back cancels restore and discards the staged candidate")
	screen.data_tools.preview_restore(EXPORT)
	screen.data_tools.confirmation.confirmed.emit()
	_check(Backup.same_data(screen.records.to_data(), before) and screen.data_tools.reports.entries.size() == 1, "Confirmed restore preserves reports separately and installs the previewed data")
	screen.data_tools._clear_reports()
	screen._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(screen.data_tools.reports.entries.size() == 1, "Canceling clear keeps existing playtest notes")
	screen.data_tools._delete_reports()
	_check(screen.data_tools.reports.entries.is_empty() and Store.load_data(SAVE + ".feedback").entries.is_empty() and Store.load_data(SAVE + ".feedback.bak").entries.is_empty(), "Clear removes local feedback and the automatic feedback backup")
	screen.start_level("parcel", 1)
	screen.play_move(2, Vector2i.ZERO)
	screen._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var elapsed: int = screen.solve_clock.elapsed_ms
	screen._process(1)
	_check(screen.solve_clock.elapsed_ms == elapsed and screen.records.current().sessions.parcel.moves == 1, "Interruption preserves pending state and excludes background time")
	screen._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	screen.apply_safe_area(Rect2i(0, 40, 720, 1200), Vector2i(720, 1280))
	_check(screen._content_margin.get_theme_constant("margin_top") >= 64, "Live layout applies simulated safe-area padding")
	screen.queue_free()
	await process_frame
