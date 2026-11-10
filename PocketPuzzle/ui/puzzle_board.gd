extends Control
## Mouse events are synthesized from touch, avoiding duplicate Android taps.
signal played(index: int, direction: Vector2i)
signal selection_changed
const COLORS := [Color("ec7159"), Color("5b91cd"), Color("368d80"), Color("d5a341")]
const INK := Color("203d43")
const MUTED := Color("778783")
const PAPER := Color("fffdf7")
const LANE := Color("ebe9df")
var mode := "parcel"
var rules
var selected := -1
var press_position := Vector2.ZERO
var flash := 0.0
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func celebrate_move() -> void:
	flash = 1.0
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()
	if flash <= 0.0:
		set_process(false)

func _box(rect: Rect2, color: Color, radius: int = 18, border := Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(3)
	draw_style_box(style, rect)

func _text(value: String, point: Vector2, font_size: int, color: Color = INK, centered := false) -> void:
	if centered:
		point.x -= _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _symbol(center: Vector2, index: int, extent: float, tint := Color.WHITE) -> void:
	match index:
		0:
			draw_circle(center, extent * 0.63, tint)
		1:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -extent), center + Vector2(extent, extent * 0.7), center + Vector2(-extent, extent * 0.7)]), tint)
		2:
			draw_rect(Rect2(center - Vector2.ONE * extent * 0.65, Vector2.ONE * extent * 1.3), tint)
		3:
			draw_line(center - Vector2(extent, 0), center + Vector2(extent, 0), tint, extent * 0.45, true)
			draw_line(center - Vector2(0, extent), center + Vector2(0, extent), tint, extent * 0.45, true)

func _parcel(rect: Rect2, index: int, active := false) -> void:
	_box(Rect2(rect.position + Vector2(0, 5), rect.size), COLORS[index].darkened(0.16), 12)
	_box(rect, COLORS[index].lightened(flash * 0.15 if active else 0.0), 12)
	draw_line(Vector2(rect.get_center().x, rect.position.y + 3), Vector2(rect.get_center().x, rect.end.y - 3), Color(1, 1, 1, 0.17), 13)
	_symbol(rect.get_center(), index, minf(rect.size.y * 0.23, 15.0))

func _grid_rect() -> Rect2:
	var side := minf(size.x - 48.0, size.y - 60.0)
	return Rect2(Vector2((size.x - side) / 2.0, 30.0), Vector2.ONE * side)

func _draw() -> void:
	if rules == null:
		return
	if _font == null:
		_font = ThemeDB.fallback_font
	if mode == "parcel":
		_draw_parcel()
	else:
		_draw_block()

func _draw_parcel() -> void:
	var width := size.x
	_box(Rect2(0, 0, width, 112), PAPER)
	_text("DELIVERY ORDER", Vector2(22, 28), 18, MUTED)
	if not rules.won():
		_parcel(Rect2(22, 43, 78, 48), int(rules.route[rules.delivered]), true)
		_text("NOW", Vector2(61, 106), 13, MUTED, true)
		var upcoming: int = mini(rules.route.size() - rules.delivered - 1, 8)
		for i in range(upcoming):
			var index: int = int(rules.route[rules.delivered + i + 1])
			var point := Vector2(135.0 + i * (width - 165.0) / 8.0, 70.0)
			draw_circle(point, 19, COLORS[index].lightened(0.82))
			_symbol(point, index, 10, COLORS[index])
		var extra: int = rules.route.size() - rules.delivered - 1 - upcoming
		if extra > 0:
			_text("+%d" % extra, Vector2(width - 36, 106), 16, MUTED, true)
	_text("WAITING AREA", Vector2(18, 151), 18, MUTED)
	_text("%d / %d" % [rules.waiting.size(), rules.capacity], Vector2(width - 65, 151), 18, MUTED)
	var slot_width := (width - 48.0) / 3.0
	for i in range(rules.capacity):
		var slot := Rect2(12 + i * (slot_width + 12), 169, slot_width, 68)
		_box(slot, LANE, 14)
		if i < rules.waiting.size():
			_parcel(slot.grow(-7), int(rules.waiting[i]))
		else:
			draw_circle(slot.get_center(), 5, Color("cecec1"))
	_text("TAP A QUEUE TO SEND ITS TOP PARCEL", Vector2(width / 2.0, 277), 17, MUTED, true)
	var lane_width := (width - 32.0) / 3.0
	for lane in range(3):
		var rect := Rect2(lane * (lane_width + 16), 296, lane_width, size.y - 300)
		_box(rect, LANE, 20)
		var queue: Array = rules.queues[lane]
		var gap := minf(44.0, (rect.size.y - 52.0) / maxf(1.0, queue.size()))
		if queue.is_empty():
			_text("CLEAR", Vector2(rect.get_center().x, rect.position.y + 60), 19, MUTED, true)
		for i in range(queue.size()):
			_parcel(Rect2(rect.position.x + 13, rect.position.y + 13 + i * gap, lane_width - 26, gap - 7), int(queue[i]), i == 0)
		_text("%d left" % queue.size(), Vector2(rect.get_center().x, rect.end.y - 12), 17, MUTED, true)

func _draw_block() -> void:
	var grid := _grid_rect()
	var cell: float = grid.size.x / rules.size
	_box(grid.grow(16), Color("d8ddd1"), 26)
	_box(grid, Color("e8ebdf"), 18)
	for x in range(rules.size):
		for y in range(rules.size):
			draw_circle(grid.position + Vector2(x + 0.5, y + 0.5) * cell, 3, Color("cdd4c5"))
	for i in range(rules.gates.size()):
		var gate: Dictionary = rules.gates[i]
		var gate_rect: Rect2
		var arrow := Vector2.ZERO
		match gate.side:
			"right":
				gate_rect = Rect2(grid.end.x - 5, grid.position.y + gate.start * cell, 22, gate.span * cell)
				arrow = Vector2.RIGHT
			"left":
				gate_rect = Rect2(grid.position.x - 17, grid.position.y + gate.start * cell, 22, gate.span * cell)
				arrow = Vector2.LEFT
			"down":
				gate_rect = Rect2(grid.position.x + gate.start * cell, grid.end.y - 5, gate.span * cell, 22)
				arrow = Vector2.DOWN
			"up":
				gate_rect = Rect2(grid.position.x + gate.start * cell, grid.position.y - 17, gate.span * cell, 22)
				arrow = Vector2.UP
		_box(gate_rect, COLORS[i], 8)
		var center := gate_rect.get_center()
		var along := Vector2.DOWN if gate.side == "right" or gate.side == "left" else Vector2.RIGHT
		_symbol(center - along * 22, i, 7)
		center += along * 18
		draw_polyline(PackedVector2Array([center - arrow * 5 + arrow.orthogonal() * 5, center + arrow * 3, center - arrow * 5 - arrow.orthogonal() * 5]), Color.WHITE, 3, true)
	for i in range(rules.pieces.size()):
		var piece: Dictionary = rules.pieces[i]
		if piece.out:
			continue
		var rect := Rect2(grid.position + Vector2(piece.x, piece.y) * cell + Vector2.ONE * 6, Vector2(piece.w, piece.h) * cell - Vector2.ONE * 12)
		_box(Rect2(rect.position + Vector2(0, 6), rect.size), COLORS[int(piece.color)].darkened(0.2), 17)
		_box(rect, COLORS[int(piece.color)].lightened(flash * 0.2 if selected == i else 0), 17, PAPER if selected == i else Color.TRANSPARENT)
		_symbol(rect.get_center(), int(piece.color), 19)
		if selected == i:
			draw_circle(rect.position + Vector2(14, 14), 4, PAPER)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_position = event.position
			if mode == "block":
				var grid := _grid_rect()
				if grid.has_point(press_position):
					var cell: float = grid.size.x / rules.size
					selected = rules.piece_at(Vector2i((press_position - grid.position) / cell))
					queue_redraw()
					selection_changed.emit()
		else:
			if mode == "parcel" and event.position.y >= 296:
				var lane_width := (size.x - 32.0) / 3.0
				var lane := int(event.position.x / (lane_width + 16))
				if lane >= 0 and lane < 3 and event.position.x - lane * (lane_width + 16) <= lane_width:
					played.emit(lane, Vector2i.ZERO)
			elif mode == "block" and selected >= 0:
				var swipe: Vector2 = event.position - press_position
				if swipe.length() > 24:
					var direction := Vector2i(signf(swipe.x), 0) if absf(swipe.x) > absf(swipe.y) else Vector2i(0, signf(swipe.y))
					played.emit(selected, direction)
		accept_event()
