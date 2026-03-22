class_name PlaytestReporter
extends RefCounted

const MazeGame = preload("res://scripts/maze_game.gd")

# This reporter is intended to help measure "reward per effort":
# how much better directed play performs than random play, and whether
# the game is creating meaningful payoff for conscious decisions.

const DEFAULT_SAMPLE_COUNT := 200
const DEFAULT_MAX_ACTIONS := 36
const DEFAULT_MAX_BOARD_DEPTH := 3
const DEFAULT_TRACE_ACTIONS := 12
const DEFAULT_TRACE_SEED := 1
const STRATEGIES := ["random", "greedy"]
const UPGRADE_PRIORITY := ["anchor", "step", "peek", "remote_flip", "daze"]


func build_report(sample_count: int = DEFAULT_SAMPLE_COUNT, max_actions: int = DEFAULT_MAX_ACTIONS, max_board_depth: int = DEFAULT_MAX_BOARD_DEPTH) -> Dictionary:
	var strategy_reports: Dictionary = {}
	for strategy in STRATEGIES:
		strategy_reports[strategy] = _run_strategy(strategy, sample_count, max_actions, max_board_depth)
	return {
		"environment": {
			"grid_size": "7x7",
			"sample_count": sample_count,
			"max_actions": max_actions,
			"max_board_depth": max_board_depth,
		},
		"strategies": strategy_reports,
		"trace": _build_trace("greedy", DEFAULT_TRACE_SEED, DEFAULT_TRACE_ACTIONS, max_actions, max_board_depth),
	}


func _run_strategy(strategy: String, sample_count: int, max_actions: int, max_board_depth: int) -> Dictionary:
	var board1_escaped := 0
	var board1_pressure_losses := 0
	var board1_other_losses := 0
	var board1_stalled := 0
	var board1_actions_total := 0
	var board1_turns_total := 0
	var board1_peak_pressure_total := 0
	var board1_legal_flips_total := 0
	var board1_stay_actions := 0
	var board1_flip_actions := 0
	var board1_reward_screen_hits := 0

	var early_reached_board2 := 0
	var early_reached_board3 := 0
	var early_reward_screen_hits := 0
	var early_actions_total := 0
	var early_upgrades_total := 0
	var early_peak_pressure_total := 0
	var early_legal_flips_total := 0
	var early_stay_actions := 0
	var early_flip_actions := 0
	var actions_to_first_reward_total := 0
	var actions_to_first_reward_runs := 0
	var turns_to_first_reward_total := 0
	var turns_to_first_reward_runs := 0

	for seed in range(1, sample_count + 1):
		var outcome := _playthrough(seed, strategy, max_actions, max_board_depth, false)
		var board1: Dictionary = outcome.get("board1", {})
		var early: Dictionary = outcome.get("early_run", {})
		board1_actions_total += int(board1.get("actions", 0))
		board1_turns_total += int(board1.get("turns", 0))
		board1_peak_pressure_total += int(board1.get("peak_pressure", 0))
		board1_legal_flips_total += int(board1.get("legal_flips_total", 0))
		board1_stay_actions += int(board1.get("stay_actions", 0))
		board1_flip_actions += int(board1.get("flip_actions", 0))
		if bool(board1.get("reward_screen", false)):
			board1_reward_screen_hits += 1

		if bool(board1.get("escaped", false)):
			board1_escaped += 1
		else:
			var reason := String(board1.get("reason", ""))
			if reason.contains("Pressure"):
				board1_pressure_losses += 1
			elif not reason.is_empty():
				board1_other_losses += 1
			else:
				board1_stalled += 1

		early_actions_total += int(early.get("actions", 0))
		early_upgrades_total += int(early.get("upgrades", 0))
		early_peak_pressure_total += int(early.get("peak_pressure", 0))
		early_legal_flips_total += int(early.get("legal_flips_total", 0))
		early_stay_actions += int(early.get("stay_actions", 0))
		early_flip_actions += int(early.get("flip_actions", 0))
		if bool(early.get("reached_board2", false)):
			early_reached_board2 += 1
		if bool(early.get("reached_board3", false)):
			early_reached_board3 += 1
		if bool(early.get("reward_screen", false)):
			early_reward_screen_hits += 1
		if bool(early.get("reached_reward", false)):
			actions_to_first_reward_total += int(early.get("actions_to_reward", 0))
			turns_to_first_reward_total += int(early.get("turns_to_reward", 0))
			actions_to_first_reward_runs += 1
			turns_to_first_reward_runs += 1

	return {
		"strategy": strategy,
		"samples": sample_count,
		"board1": {
			"escaped": board1_escaped,
			"escape_rate": float(board1_escaped) / sample_count,
			"pressure_losses": board1_pressure_losses,
			"other_losses": board1_other_losses,
			"stalled": board1_stalled,
			"avg_actions": float(board1_actions_total) / sample_count,
			"avg_turns": float(board1_turns_total) / sample_count,
			"avg_peak_pressure": float(board1_peak_pressure_total) / sample_count,
			"avg_legal_flips": float(board1_legal_flips_total) / max(board1_actions_total, 1),
			"stay_rate": float(board1_stay_actions) / max(board1_stay_actions + board1_flip_actions, 1),
			"flip_rate": float(board1_flip_actions) / max(board1_stay_actions + board1_flip_actions, 1),
			"reward_screen_hits": board1_reward_screen_hits,
		},
		"early_run": {
			"reached_board2": early_reached_board2,
			"reached_board2_rate": float(early_reached_board2) / sample_count,
			"reached_board3": early_reached_board3,
			"reached_board3_rate": float(early_reached_board3) / sample_count,
			"reward_screen_hits": early_reward_screen_hits,
			"avg_actions": float(early_actions_total) / sample_count,
			"avg_upgrades_chosen": float(early_upgrades_total) / sample_count,
			"avg_peak_pressure": float(early_peak_pressure_total) / sample_count,
			"avg_legal_flips": float(early_legal_flips_total) / max(early_actions_total, 1),
			"stay_rate": float(early_stay_actions) / max(early_stay_actions + early_flip_actions, 1),
			"flip_rate": float(early_flip_actions) / max(early_stay_actions + early_flip_actions, 1),
			"avg_actions_to_reward": float(actions_to_first_reward_total) / max(actions_to_first_reward_runs, 1),
			"avg_turns_to_reward": float(turns_to_first_reward_total) / max(turns_to_first_reward_runs, 1),
		},
	}


func _playthrough(seed: int, strategy: String, max_actions: int, max_board_depth: int, capture_trace: bool = false, trace_actions: int = DEFAULT_TRACE_ACTIONS) -> Dictionary:
	var game := MazeGame.new(Vector2i(7, 7), seed)
	var actions := 0
	var upgrades := 0
	var peak_pressure := _pressure_from_state(game.get_hud_state())
	var legal_flips_total := 0
	var stay_actions := 0
	var flip_actions := 0
	var board1_actions := 0
	var board1_turns := 0
	var board1_peak_pressure := 0
	var board1_legal_flips_total := 0
	var board1_stay_actions := 0
	var board1_flip_actions := 0
	var board1_reward_screen := false
	var board1_escaped := false
	var board1_reason := ""
	var reached_board2 := false
	var reached_board3 := false
	var early_reward_screen := false
	var reached_reward := false
	var actions_to_reward := 0
	var turns_to_reward := 0
	var trace: Array[Dictionary] = []
	var trace_budget := trace_actions

	while actions < max_actions and game.player.alive and game.run.board_depth <= max_board_depth:
		if game.run.awaiting_upgrade_choice:
			if game.run.board_depth >= max_board_depth:
				break
			var upgrade_id := _choose_upgrade(game)
			if upgrade_id.is_empty():
				break
			var before_depth := game.run.board_depth
			var before_turns := game.run.turn_index
			game.choose_upgrade(upgrade_id)
			upgrades += 1
			reached_reward = true
			if not board1_reward_screen and before_depth == 1:
				board1_reward_screen = true
			if before_depth == 1:
				board1_reward_screen = true
			if capture_trace and trace_budget > 0:
				trace.append({
					"kind": "upgrade",
					"upgrade_id": upgrade_id,
					"board_before": before_depth,
					"turn_before": before_turns,
					"board_after": game.run.board_depth,
					"status": game.status_text,
				})
				trace_budget -= 1
			continue

		if game.board_cleared and not game.run.awaiting_upgrade_choice:
			break

		var frame := _capture_frame(game)
		var action := _choose_action(game, strategy)
		if action.is_empty():
			break
		actions += 1
		if game.run.board_depth == 1:
			board1_actions += 1
			board1_legal_flips_total += frame.legal_flips
			if action.get("type", "") == "stay":
				board1_stay_actions += 1
			else:
				board1_flip_actions += 1
		if action.get("type", "") == "stay":
			stay_actions += 1
			game.try_stay()
		else:
			flip_actions += 1
			game.try_flip_cell(action.get("pos", Vector2i.ZERO))
		var post_hud := game.get_hud_state()
		peak_pressure = maxi(peak_pressure, _pressure_from_state(post_hud))
		legal_flips_total += frame.legal_flips
		if game.run.board_depth == 1:
			board1_turns = game.run.turn_index
			board1_peak_pressure = maxi(board1_peak_pressure, _pressure_from_state(post_hud))

		if capture_trace and trace_budget > 0:
			trace.append(_make_trace_entry(game, frame, post_hud, action, actions, upgrades))
			trace_budget -= 1

		if game.board_cleared and game.run.board_depth == 1:
			board1_escaped = true
		if not game.player.alive and board1_reason.is_empty():
			board1_reason = game.failure_reason
		if game.run.board_depth >= 2:
			reached_board2 = true
		if game.run.board_depth >= 3:
			reached_board3 = true
		if game.run.awaiting_upgrade_choice and game.run.board_depth == 1 and not reached_reward:
			reached_reward = true
			actions_to_reward = actions
			turns_to_reward = game.run.turn_index
		if game.run.awaiting_upgrade_choice and game.run.board_depth == 1:
			board1_reward_screen = true
		if game.run.awaiting_upgrade_choice and game.run.board_depth > 1:
			early_reward_screen = true

	if game.run.board_depth > 1:
		reached_board2 = true
	if game.run.board_depth > 2:
		reached_board3 = true
	if game.run.awaiting_upgrade_choice and game.run.board_depth >= 1:
		if game.run.board_depth == 1:
			board1_reward_screen = true
		else:
			early_reward_screen = true

	if not board1_escaped and board1_reason.is_empty():
		board1_reason = game.failure_reason

	return {
		"board1": {
			"actions": board1_actions,
			"turns": board1_turns,
			"peak_pressure": board1_peak_pressure,
			"legal_flips_total": board1_legal_flips_total,
			"stay_actions": board1_stay_actions,
			"flip_actions": board1_flip_actions,
			"escaped": board1_escaped,
			"reason": board1_reason,
			"reward_screen": board1_reward_screen,
		},
		"early_run": {
			"actions": actions,
			"upgrades": upgrades,
			"peak_pressure": peak_pressure,
			"legal_flips_total": legal_flips_total,
			"stay_actions": stay_actions,
			"flip_actions": flip_actions,
			"reached_board2": reached_board2,
			"reached_board3": reached_board3,
			"reward_screen": board1_reward_screen or early_reward_screen,
			"reached_reward": reached_reward,
			"actions_to_reward": actions_to_reward,
			"turns_to_reward": turns_to_reward,
		},
		"trace": trace,
	}


func _build_trace(strategy: String, seed: int, trace_actions: int, max_actions: int, max_board_depth: int) -> Dictionary:
	var outcome := _playthrough(seed, strategy, max_actions, max_board_depth, true, trace_actions)
	return {
		"strategy": strategy,
		"seed": seed,
		"steps": outcome.get("trace", []),
	}


func _capture_frame(game) -> Dictionary:
	var hud: Dictionary = game.get_hud_state()
	return {
		"board_depth": int(game.run.board_depth),
		"turn_index": int(game.run.turn_index),
		"pressure": int(hud.get("pressure_current", 0)),
		"legal_flips": game.get_legal_flip_positions().size(),
		"distance_to_edge": _distance_to_edge(game.player.position, game.grid_size),
		"status": String(hud.get("status", "")),
		"selected_action": String(hud.get("selected_action", "flip")),
		"player_alive": bool(hud.get("player_alive", true)),
		"awaiting_upgrade_choice": bool(game.run.awaiting_upgrade_choice),
		"board_cleared": bool(game.board_cleared),
	}


func _make_trace_entry(game, frame: Dictionary, post_hud: Dictionary, action: Dictionary, action_index: int, upgrade_index: int) -> Dictionary:
	return {
		"kind": "action",
		"action_index": action_index,
		"upgrade_index": upgrade_index,
		"board_depth": frame.board_depth,
		"turn_index_before": frame.turn_index,
		"pressure_before": frame.pressure,
		"legal_flips_before": frame.legal_flips,
		"distance_before": frame.distance_to_edge,
		"selected_action": frame.selected_action,
		"choice_type": String(action.get("type", "")),
		"choice_pos": _pos_to_string(action.get("pos", Vector2i.ZERO)) if action.get("type", "") == "flip" else "",
		"turn_index_after": int(game.run.turn_index),
		"pressure_after": int(post_hud.get("pressure_current", 0)),
		"player_alive": bool(post_hud.get("player_alive", true)),
		"board_cleared": bool(game.board_cleared),
		"awaiting_upgrade_choice": bool(game.run.awaiting_upgrade_choice),
		"status_after": String(post_hud.get("status", "")),
		"score": int(post_hud.get("score", 0)),
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


func _choose_upgrade(game) -> String:
	var offers: Array = game.get_upgrade_offer_data()
	if offers.is_empty():
		return ""
	for preferred_id in UPGRADE_PRIORITY:
		for offer in offers:
			if String(offer.get("id", "")) == preferred_id:
				return preferred_id
	return String(offers[0].get("id", ""))


func _choose_greedy_action(game, choices: Array[Dictionary]) -> Dictionary:
	var snapshot: Object = game._capture_snapshot()
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


func _pressure_from_state(hud_state: Dictionary) -> int:
	return int(hud_state.get("pressure_current", 0))


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


func _pos_to_string(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
