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
	root.add_child(screen)
	DirAccess.make_dir_recursive_absolute("res://builds")
	await _capture("home")
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
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://pocketpuzzle-capture-progress.json")
	quit()

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/preview-%s.png" % label)
