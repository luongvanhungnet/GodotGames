extends RefCounted
## Local player profiles and per-level records. Replays improve a record;
## they never add the same level's score to a ranking twice.
const MAX_PLAYERS := 8
var players: Array = []
var active_id := "p1"
var _next_id := 2

func _init() -> void:
	players = [_new_player("p1", "Player 1")]

func _new_player(id: String, player_name: String) -> Dictionary:
	return {"id": id, "name": player_name, "progress": {"parcel": [], "block": [], "last_parcel": 0, "last_block": 0}, "results": {"parcel": {}, "block": {}}}

func current() -> Dictionary:
	for player in players:
		if player.id == active_id:
			return player
	return players[0]

func add_player(player_name: String) -> String:
	player_name = clean_name(player_name)
	if player_name.is_empty() or players.size() >= MAX_PLAYERS:
		return ""
	for player in players:
		if player.name.nocasecmp_to(player_name) == 0:
			return ""
	var id := "p%d" % _next_id
	_next_id += 1
	players.append(_new_player(id, player_name))
	active_id = id
	return id

func select_player(id: String) -> bool:
	for player in players:
		if player.id == id:
			active_id = id
			return true
	return false

func rename_current(player_name: String) -> bool:
	player_name = clean_name(player_name)
	if player_name.is_empty():
		return false
	for player in players:
		if player.id != active_id and player.name.nocasecmp_to(player_name) == 0:
			return false
	current().name = player_name
	return true

static func clean_name(value: String) -> String:
	var cleaned := ""
	for character in value.strip_edges():
		if character.unicode_at(0) >= 32:
			cleaned += character
	return cleaned.left(18).strip_edges()

static func score_for(milliseconds: int, moves: int, undos: int) -> int:
	if milliseconds < 0 or moves < 1 or undos < 0:
		return 0
	var speed := maxi(0, 2000 - int(milliseconds / 100))
	var efficiency := maxi(0, 3000 - moves * 40 - undos * 120)
	return 1000 + speed + efficiency

func best(game_mode: String, level: int) -> Dictionary:
	return current().results[game_mode].get(str(level), {})

func record(game_mode: String, level: int, milliseconds: int, moves: int, undos: int) -> Dictionary:
	if not game_mode in ["parcel", "block"] or level < 0 or moves < 1 or milliseconds < 0 or undos < 0:
		return {}
	milliseconds = maxi(1, milliseconds)
	var score := score_for(milliseconds, moves, undos)
	var previous := best(game_mode, level)
	var is_high: bool = previous.is_empty() or score > int(previous.high_score)
	var result := {"high_score": score, "best_time_ms": milliseconds, "fewest_moves": moves, "solves": 1}
	if not previous.is_empty():
		result.high_score = maxi(score, int(previous.high_score))
		result.best_time_ms = mini(milliseconds, int(previous.best_time_ms))
		result.fewest_moves = mini(moves, int(previous.fewest_moves))
		result.solves = int(previous.solves) + 1
	current().results[game_mode][str(level)] = result
	return {"score": score, "new_high": is_high, "best": result.duplicate()}

func ranking(game_mode: String = "all") -> Array:
	var rows: Array = []
	for player in players:
		var row := {"id": player.id, "name": player.name, "score": 0, "completed": 0, "time_ms": 0}
		for key in ["parcel", "block"]:
			if game_mode != "all" and game_mode != key:
				continue
			for result in player.results[key].values():
				row.score += int(result.high_score)
				row.completed += 1
				row.time_ms += int(result.best_time_ms)
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score:
			return a.score > b.score
		if a.completed != b.completed:
			return a.completed > b.completed
		if a.time_ms != b.time_ms:
			return a.time_ms < b.time_ms
		return a.name.nocasecmp_to(b.name) < 0)
	for i in range(rows.size()):
		rows[i]["rank"] = i + 1
		if i > 0 and rows[i].score == rows[i - 1].score and rows[i].completed == rows[i - 1].completed and rows[i].time_ms == rows[i - 1].time_ms:
			rows[i].rank = rows[i - 1].rank
	return rows

func to_data() -> Dictionary:
	return {"version": 2, "active_player": active_id, "next_player_id": _next_id, "players": players.duplicate(true)}

func restore(saved: Dictionary, counts: Dictionary) -> void:
	players = []
	active_id = "p1"
	_next_id = 2
	if not saved.get("players") is Array:
		var legacy := _new_player("p1", "Player 1")
		legacy.progress = _read_progress(saved, counts)
		players.append(legacy)
		return
	var ids := {}
	var names := {}
	for item in saved.players:
		if players.size() >= MAX_PLAYERS:
			break
		if not item is Dictionary or not item.get("name") is String or not item.get("id") is String:
			continue
		var player_name := clean_name(item.name)
		var id: String = item.id
		if player_name.is_empty() or not id.begins_with("p") or not id.substr(1).is_valid_int() or ids.has(id) or names.has(player_name.to_lower()):
			continue
		var number := _integer(int(id.substr(1)), 1, 1000000)
		if number < 1:
			continue
		_next_id = maxi(_next_id, number + 1)
		ids[id] = true
		names[player_name.to_lower()] = true
		var player := _new_player(id, player_name)
		player.progress = _read_progress(item.get("progress", {}), counts)
		var results: Variant = item.get("results", {})
		if results is Dictionary:
			for game_mode in ["parcel", "block"]:
				var mode_results: Variant = results.get(game_mode, {})
				if not mode_results is Dictionary:
					continue
				for key in mode_results:
					if not key is String or not key.is_valid_int() or int(key) < 0 or int(key) >= int(counts[game_mode]):
						continue
					var entry: Variant = mode_results[key]
					if not entry is Dictionary:
						continue
					var high := _integer(entry.get("high_score"), 1000, 6000)
					var time := _integer(entry.get("best_time_ms"), 1, 604800000)
					var moves := _integer(entry.get("fewest_moves"), 1, 1000000)
					var solves := _integer(entry.get("solves"), 1, 1000000)
					if high < 0 or time < 0 or moves < 0 or solves < 0:
						continue
					player.results[game_mode][str(int(key))] = {"high_score": high, "best_time_ms": time, "fewest_moves": moves, "solves": solves}
		players.append(player)
	if players.is_empty():
		players.append(_new_player("p1", "Player 1"))
	active_id = str(saved.get("active_player", "p1"))
	if not select_player(active_id):
		active_id = players[0].id

func _read_progress(value: Variant, counts: Dictionary) -> Dictionary:
	var result: Dictionary = _new_player("", "").progress
	if not value is Dictionary:
		return result
	for game_mode in ["parcel", "block"]:
		if value.get(game_mode) is Array:
			for level in value[game_mode]:
				var number := _integer(level, 0, int(counts[game_mode]) - 1)
				if number >= 0 and not result[game_mode].has(number):
					result[game_mode].append(number)
		var last := _integer(value.get("last_" + game_mode), 0, int(counts[game_mode]) - 1)
		if last >= 0:
			result["last_" + game_mode] = last
	return result

func _integer(value: Variant, minimum: int, maximum: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
		return -1
	if value < minimum or value > maximum:
		return -1
	return int(value)
