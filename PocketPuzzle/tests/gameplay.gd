extends SceneTree

const Parcel = preload("res://game/parcel_rules.gd")
const Block = preload("res://game/block_rules.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	create_timer(20).timeout.connect(func(): push_error("Gameplay tests timed out"); quit(1))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/levels.json"))
	_check(data.parcel.size() == 30 and data.block.size() == 30, "Expected 30 levels in both games")
	for number in range(data.parcel.size()):
		var game = Parcel.new()
		game.setup(data.parcel[number])
		var initial := JSON.stringify(game.queues)
		for lane in data.parcel[number].solution:
			_check(game.send(int(lane)), "Parcel %d: stored solution must be legal" % number)
			var remaining: int = game.waiting.size() + game.delivered
			for queue in game.queues:
				remaining += queue.size()
			_check(remaining == game.route.size(), "Parcel conservation")
			_check(game.waiting.size() <= game.capacity, "Waiting capacity")
		_check(game.won() and not game.stuck(), "Parcel %d must be solvable" % number)
		_check(not game.send(0), "No dispatch after completion")
		while game.undo():
			pass
		_check(JSON.stringify(game.queues) == initial and game.delivered == 0 and game.moves == 0, "Parcel undo must restore the whole level")
	for number in range(data.block.size()):
		var game = Block.new()
		game.setup(data.block[number])
		var initial := JSON.stringify(game.pieces)
		for action in data.block[number].solution:
			_check(game.move_piece(int(action[0]), Vector2i(int(action[1]), int(action[2]))), "Block %d: stored solution must be legal" % number)
			_check(_no_overlap(game), "Blocks must not overlap")
		_check(game.won() and game.remaining() == 0, "Block %d must be solvable" % number)
		while game.undo():
			pass
		_check(JSON.stringify(game.pieces) == initial and game.moves == 0, "Block undo must restore the whole level")
	_test_parcel_edges()
	_test_block_edges(data.block[29])
	if failures == 0:
		print("PASS: 60 level solutions, conservation, collisions, gates, rejection, and undo (%d checks)" % checks)
	quit(0 if failures == 0 else 1)

func _no_overlap(game) -> bool:
	var occupied := {}
	for piece in game.pieces:
		if piece.out:
			continue
		for x in range(int(piece.x), int(piece.x + piece.w)):
			for y in range(int(piece.y), int(piece.y + piece.h)):
				var cell := Vector2i(x, y)
				if x < 0 or x >= game.size or y < 0 or y >= game.size or occupied.has(cell):
					return false
				occupied[cell] = true
	return true

func _test_parcel_edges() -> void:
	var game = Parcel.new()
	game.setup({"queues": [[1, 0], [1], [0]], "route": [0, 0, 1, 1], "capacity": 1})
	_check(not game.send(-1) and not game.send(3) and not game.undo(), "Parcel rejects invalid actions")
	_check(game.send(0) and game.waiting == [1], "Nonmatching parcel waits")
	var before := JSON.stringify([game.queues, game.waiting, game.delivered, game.moves])
	_check(not game.send(1), "Full buffer rejects a nonmatch")
	_check(JSON.stringify([game.queues, game.waiting, game.delivered, game.moves]) == before, "Rejected move cannot mutate state")
	_check(not game.stuck(), "A full buffer still allows a matching delivery")
	_check(game.send(0) and game.send(2) and game.delivered == 3 and game.waiting.is_empty(), "Waiting matches drain automatically")
	_check(game.send(1) and game.won(), "Auto-drain can finish a level")
	game.setup({"queues": [[1, 0], [1], [1]], "route": [0, 1, 1, 1], "capacity": 1})
	game.send(1)
	_check(game.stuck(), "Detect a blocked waiting area")
	_check(game.undo() and not game.stuck(), "Undo recovers a blocked board")

func _test_block_edges(level: Dictionary) -> void:
	var game = Block.new()
	game.setup({"size": 5, "pieces": [{"x": 0, "y": 0, "w": 1, "h": 1, "color": 0}, {"x": 1, "y": 0, "w": 1, "h": 1, "color": 1}], "gates": level.gates})
	var initial := JSON.stringify(game.pieces)
	_check(not game.move_piece(0, Vector2i.RIGHT), "Reject occupied cells")
	_check(not game.move_piece(0, Vector2i.LEFT), "Reject a mismatched boundary")
	_check(not game.move_piece(0, Vector2i(1, 1)) and not game.move_piece(-1, Vector2i.UP), "Reject diagonal and invalid piece")
	_check(JSON.stringify(game.pieces) == initial and game.moves == 0 and game.history.is_empty(), "Invalid block moves cannot mutate state")
	game.setup({"size": 5, "pieces": [{"x": 4, "y": 0, "w": 1, "h": 3, "color": 0}], "gates": level.gates})
	_check(not game.can_move(0, Vector2i.RIGHT), "Gate must fit the entire piece")
	game.setup(level)
	initial = JSON.stringify(game.pieces)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6801
	var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	for i in range(250):
		game.move_piece(rng.randi_range(0, game.pieces.size() - 1), directions[rng.randi_range(0, 3)])
		_check(_no_overlap(game), "Seeded exploration preserves geometry")
	while game.undo():
		pass
	_check(JSON.stringify(game.pieces) == initial, "Random move sequence fully reversible")
