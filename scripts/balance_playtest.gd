extends SceneTree

const MazeGame = preload("res://scripts/maze_game.gd")

const SAMPLE_COUNT := 200
const MAX_ACTIONS := 24


func _initialize() -> void:
	var random_results := _run_samples("random")
	var greedy_results := _run_samples("greedy")
	print("Random strategy: %s" % JSON.stringify(random_results))
	print("Greedy strategy: %s" % JSON.stringify(greedy_results))
	quit(0)


func _run_samples(strategy: String) -> Dictionary:
	var escaped := 0
	var lost_to_pressure := 0
	var lost_other := 0
	var stalled := 0
	var total_actions := 0
	for seed in range(1, SAMPLE_COUNT + 1):
		var outcome := _play_first_board(seed, strategy)
		total_actions += int(outcome.get("actions", 0))
		if bool(outcome.get("escaped", false)):
			escaped += 1
			continue
		var reason := String(outcome.get("reason", ""))
		if reason.contains("Pressure"):
			lost_to_pressure += 1
		elif not reason.is_empty():
			lost_other += 1
		else:
			stalled += 1
	return {
		"strategy": strategy,
		"samples": SAMPLE_COUNT,
		"escaped": escaped,
		"escape_rate": float(escaped) / SAMPLE_COUNT,
		"pressure_losses": lost_to_pressure,
		"other_losses": lost_other,
		"stalled": stalled,
		"avg_actions": float(total_actions) / SAMPLE_COUNT,
	}


func _play_first_board(seed: int, strategy: String) -> Dictionary:
	var game = MazeGame.new(Vector2i(7, 7), seed)
	var actions := 0
	while actions < MAX_ACTIONS and not game.board_cleared and game.player.alive and not game.run.awaiting_upgrade_choice:
		var action := _choose_action(game, strategy)
		if action.is_empty():
			break
		actions += 1
		match String(action.get("type", "flip")):
			"stay":
				game.try_stay()
			"flip":
				game.try_flip_cell(action.get("pos", Vector2i.ZERO))
			_:
				break
	return {
		"escaped": game.board_cleared,
		"reason": game.failure_reason,
		"actions": actions,
	}


func _choose_action(game, strategy: String) -> Dictionary:
	var legal_flips: Array[Vector2i] = game.get_legal_flip_positions()
	var choices: Array[Dictionary] = []
	for pos in legal_flips:
		choices.append({"type": "flip", "pos": pos})
	choices.append({"type": "stay"})
	if strategy == "random":
		return choices.pick_random() if not choices.is_empty() else {}
	return _choose_greedy_action(game, choices)


func _choose_greedy_action(game, choices: Array[Dictionary]) -> Dictionary:
	var snapshot = game._capture_snapshot()
	var best_choice: Dictionary = {}
	var best_score := -INF
	for choice in choices:
		game._restore_snapshot(snapshot)
		match String(choice.get("type", "")):
			"stay":
				game.try_stay()
			"flip":
				game.try_flip_cell(choice.get("pos", Vector2i.ZERO))
		var score := _score_state(game)
		if score > best_score:
			best_score = score
			best_choice = choice
	game._restore_snapshot(snapshot)
	return best_choice


func _score_state(game) -> float:
	if game.board_cleared:
		return 10000.0 - game.run.turn_index * 50.0
	if not game.player.alive:
		return -10000.0
	var pressure: int = int(game.get_hud_state().get("pressure_current", 0))
	var distance := _distance_to_edge(game.player.position, game.grid_size)
	var score := 0.0
	score -= distance * 35.0
	score -= pressure * 12.0
	score += _count_adjacent_role(game, "pusher") * 16.0
	score += _count_adjacent_role(game, "puller") * 14.0
	score -= _count_adjacent_role(game, "killer") * 20.0
	score -= _count_adjacent_role(game, "grabber") * 10.0
	score += _count_revealed_hidden_conversion(game) * 6.0
	return score


func _count_adjacent_role(game, role_id: String) -> int:
	var count := 0
	for pos in game._get_adjacent_positions(game.player.position):
		var cell = game.get_cell(pos)
		if cell == null or cell.hidden:
			continue
		if cell.role_id == role_id:
			count += 1
	return count


func _count_revealed_hidden_conversion(game) -> int:
	var count := 0
	for cell in game.get_cells():
		if cell == null or cell.is_center:
			continue
		if not cell.hidden:
			count += 1
	return count


func _distance_to_edge(pos: Vector2i, grid_size: Vector2i) -> int:
	return mini(mini(pos.x, pos.y), mini(grid_size.x - 1 - pos.x, grid_size.y - 1 - pos.y))
