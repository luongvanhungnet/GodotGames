extends SceneTree
const Look = preload("res://ui/friendly_theme.gd")
const Art = preload("res://ui/playful_art.gd")
const SAVE := "user://pocketpuzzle-store-capture.json"

func _initialize() -> void:
	call_deferred("_run")

func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".feedback", ".feedback.bak", ".feedback.tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute("res://docs/store/screenshots")
	DisplayServer.window_set_size(Vector2i(720, 1520))
	var screen = load("res://node_2d.tscn").instantiate()
	screen.save_path = SAVE
	screen.date_override = "2026-11-11"
	root.add_child(screen)
	screen.records.rename_current("Puzzle Pal")
	for mode in ["parcel", "block"]:
		for level in range(5 if mode == "parcel" else 3):
			screen.records.record(mode, level, 15000, 8, 0)
			screen.progress[mode].append(level)
	screen.records.select_avatar("bunny_mail")
	screen.show_home()
	await _capture("res://docs/store/screenshots/01-home.png")
	for mode in ["parcel", "block"]:
		screen.start_level(mode, 14)
		screen.solve_clock.pause(Time.get_ticks_msec())
		await _capture("res://docs/store/screenshots/02-parcel.png" if mode == "parcel" else "res://docs/store/screenshots/03-block.png")
	screen.show_journey("parcel")
	await _capture("res://docs/store/screenshots/04-journey.png")
	screen.show_album()
	await _capture("res://docs/store/screenshots/05-stickers.png")
	screen.queue_free()
	await process_frame
	_cleanup()
	DisplayServer.window_set_size(Vector2i(1024, 500))
	# Disable project stretching for an exact promotional-art canvas.
	root.content_scale_size = Vector2i(1024, 500)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Look.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var decor = Art.new()
	decor.kind = "background"
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(decor)
	for item in [["PocketPuzzle", Vector2(58, 76), 68, Look.PURPLE], ["Little puzzles, big smiles.", Vector2(60, 178), 34, Look.INK], ["300 offline puzzles", Vector2(60, 260), 32, Look.MINT], ["Parcel Sort + Block Exit", Vector2(60, 311), 27, Look.MUTED]]:
		var label := Label.new()
		label.text = item[0]
		label.position = item[1]
		label.add_theme_font_override("font", Look.bold_font())
		label.add_theme_font_size_override("font_size", item[2])
		label.add_theme_color_override("font_color", item[3])
		canvas.add_child(label)
	var pals = Art.new()
	pals.kind = "victory"
	pals.reduced_motion = true
	pals.position = Vector2(650, 100)
	pals.size = Vector2(320, 275)
	canvas.add_child(pals)
	await _capture("res://docs/store/feature-graphic.png")
	var icon := Image.new()
	icon.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"))
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon.save_png("res://docs/store/icon-512.png")
	print("Prepared 5 phone screenshots, a 1024x500 feature graphic, and a 512x512 icon using a fictional demo profile.")
	quit()
