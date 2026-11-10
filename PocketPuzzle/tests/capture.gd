extends SceneTree
## Optional GPU capture, run from PocketPuzzle:
## godot --path . --script tests/capture.gd
## Saves only app screenshots to ignored builds/. Not a headless CI test.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var screen = load("res://node_2d.tscn").instantiate()
	screen.save_path = "user://pocketpuzzle-capture-progress.json"
	screen.date_override = "2026-11-11"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(screen.save_path + suffix):
			DirAccess.remove_absolute(screen.save_path + suffix)
	root.add_child(screen)
	DirAccess.make_dir_recursive_absolute("res://builds")
	await _capture("home")
	screen.start_level("parcel", 0)
	for action in screen.levels.parcel[0].solution:
		screen.play_move(int(action), Vector2i.ZERO)
	await create_timer(0.55).timeout
	await _capture("victory")
	for game_mode in ["parcel", "block"]:
		for number in [0, screen.levels[game_mode].size() - 1]:
			screen.start_level(game_mode, number)
			await _capture("%s-%02d" % [game_mode, number + 1])
			print("LAYOUT %s: content=%s viewport=%s" % [game_mode, screen.page.size, root.get_visible_rect().size])
	screen.records.rename_current("Alex")
	screen.records.record("parcel", 0, 15300, 6, 0)
	screen.records.record("block", 0, 20400, 7, 0)
	screen.records.add_player("Mina")
	screen.records.record("parcel", 0, 12100, 6, 0)
	screen.show_rankings()
	await _capture("rankings")
	screen.show_players()
	await _capture("players")
	screen.show_levels("parcel", 0)
	await _capture("levels")
	screen.open_daily("parcel")
	await _capture("daily")
	screen.start_tutorial("parcel")
	await _capture("learn-parcel")
	screen.start_tutorial("block")
	await _capture("learn-block")
	screen.show_settings()
	await _capture("settings")
	screen._toggle_setting("reduced_motion")
	screen._toggle_setting("clear_symbols")
	await _capture("comfort-settings")
	for game_mode in ["parcel", "block"]:
		screen.start_level(game_mode, 14)
		screen.show_hint()
		await _capture("comfort-" + game_mode)
		print("COMFORT LAYOUT %s: content=%s viewport=%s" % [game_mode, screen.page.size, root.get_visible_rect().size])
	# A populated preview profile exercises every earned sticker and badge.
	for game_mode in ["parcel", "block"]:
		for number in range(150):
			screen.records.record(game_mode, number, 15000, 8, 0)
	for day in range(1, 31):
		screen.records.record_daily("2026-11-%02d" % day, "parcel", 15000, 8, 0)
	screen.records.select_avatar("bunny_mail")
	screen.show_home()
	await _capture("journey-home")
	for game_mode in ["parcel", "block"]:
		screen.show_journey(game_mode)
		await _capture("journey-" + game_mode)
		print("JOURNEY LAYOUT %s: %s" % [game_mode, screen.page.size])
	for number in range(5):
		screen.show_album(number)
		await _capture("album-%d" % number)
		print("ALBUM LAYOUT %d: %s" % [number, screen.page.size])
	screen.show_album(0, true)
	await _capture("achievements")
	# Capture the same UI with locked rewards and real next-goal guidance.
	screen.records.add_player("New Pal")
	screen.progress = screen.records.current().progress
	screen.records.record("parcel", 0, 15000, 8, 0)
	screen.records.record("parcel", 1, 15000, 8, 0)
	screen.records.record("parcel", 2, 15000, 8, 0)
	screen.show_album()
	await _capture("album-growing")
	screen.show_journey("parcel")
	await _capture("journey-growing")
	screen.show_rankings()
	await _capture("sticker-rankings")
	screen.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://pocketpuzzle-capture-progress.json" + suffix)
	quit()

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/preview-%s.png" % label)
