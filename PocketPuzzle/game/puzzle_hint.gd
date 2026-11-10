extends RefCounted
## Bounded hints from the catalogue's verified solution; never changes live rules.
const Parcel = preload("res://game/parcel_rules.gd")
const Block = preload("res://game/block_rules.gd")
const MAX_STEPS := 2000

static func state_key(mode: String, state) -> String:
	if mode == "parcel":
		var queues: Array = []
		for lane in state.queues:
			queues.append(lane.map(func(value): return int(value)))
		var waiting: Array = state.waiting.map(func(value): return int(value))
		waiting.sort()
		return JSON.stringify([queues, waiting, int(state.delivered)])
	var pieces: Array = []
	for piece in state.pieces:
		pieces.append([int(piece.x), int(piece.y), bool(piece.out)])
	return JSON.stringify(pieces)

static func suggest(mode: String, level: Dictionary, live) -> Dictionary:
	if not mode in ["parcel", "block"] or live.won():
		return {}
	var solution: Array = level.get("solution", [])
	if solution.is_empty() or solution.size() > MAX_STEPS:
		return {}
	var replay = Parcel.new() if mode == "parcel" else Block.new()
	replay.setup(level)
	var route := {}
	for entry in solution:
		var action: Array = [int(entry)] if mode == "parcel" else [int(entry[0]), int(entry[1]), int(entry[2])]
		var key := state_key(mode, replay)
		var accepted: bool = replay.send(action[0]) if mode == "parcel" else replay.move_piece(action[0], Vector2i(action[1], action[2]))
		if not accepted:
			return {}
		route[key] = action
	if not replay.won():
		return {}
	var current := state_key(mode, live)
	if route.has(current):
		return {"kind": "move", "action": route[current].duplicate()}
	for index in range(live.history.size() - 1, -1, -1):
		if route.has(state_key(mode, live.history[index])):
			return {"kind": "undo", "count": live.history.size() - index}
	return {}
