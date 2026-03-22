extends SceneTree

const MazeGame = preload("res://scripts/maze_game.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run_tests()
	if _failures.is_empty():
		print("Living Maze tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	_test_generation_safety()
	_test_hud_guidance_exposes_action_and_board_tip()
	_test_pusher_moves_player()
	_test_redirector_reroutes_movement()
	_test_smuggler_bypass_consumes_charge()
	_test_killer_causes_loss()
	_test_guide_reveal_delays_activation()
	_test_rewinder_grants_undo()
	_test_undo_rewinds_last_action()
	_test_first_board_reward_is_curated()
	_test_escape_offers_upgrades()


func _test_generation_safety() -> void:
	var game = MazeGame.new(Vector2i(7, 7), 11)
	var center := game.get_center_position()
	var first_ring := [
		center + Vector2i.UP,
		center + Vector2i.RIGHT,
		center + Vector2i.DOWN,
		center + Vector2i.LEFT,
	]
	var has_transport := false
	var has_help := false
	for pos in first_ring:
		var cell = game.get_cell(pos)
		_assert_true(cell.role_id != "killer", "generation keeps killers out of the first ring")
		if cell.role_id == "pusher" or cell.role_id == "puller":
			has_transport = true
		if cell.role_id == "guide" or cell.role_id == "smuggler" or cell.role_id == "rewinder":
			has_help = true
	_assert_true(has_transport, "generation guarantees at least one transport role in the first ring")
	_assert_true(has_help, "generation guarantees at least one help role in the first ring")


func _test_hud_guidance_exposes_action_and_board_tip() -> void:
	var game = _make_blank_game()
	game.player.unlocked_upgrades["peek"] = true
	game.player.board_charges["peek"] = 1
	game.set_selected_action("peek")
	var hud: Dictionary = game.get_hud_state()
	_assert_true(String(hud.get("action_instruction", "")).contains("hidden adjacent tile"), "HUD exposes the current action instruction")
	_assert_true(String(hud.get("risk_summary", "")).contains("Pressure"), "HUD exposes the current risk summary")
	_assert_true(String(hud.get("board_tip", "")).contains("Board 1 tip"), "HUD teaches the opening board")
	_assert_true(game.status_text.contains("Observe"), "status text updates immediately when the action changes")


func _test_pusher_moves_player() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(3, 2), "guide", true)
	var report: Dictionary = game.try_flip_cell(Vector2i(3, 2))
	_assert_true(bool(report.get("ok", false)), "flip succeeds for a legal adjacent hidden card")
	_assert_eq(game.player.position, Vector2i(4, 3), "pusher moves the player one tile away")


func _test_redirector_reroutes_movement() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(4, 3), "redirector", false)
	_set_role(game, Vector2i(3, 2), "guide", true)
	game.try_flip_cell(Vector2i(3, 2))
	_assert_eq(game.player.position, Vector2i(3, 4), "redirector bends the incoming movement clockwise")


func _test_smuggler_bypass_consumes_charge() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(4, 3), "blocker", false)
	_set_role(game, Vector2i(3, 2), "smuggler", true)
	game.try_flip_cell(Vector2i(3, 2))
	_assert_eq(game.player.position, Vector2i(4, 3), "smuggler lets the player pass into a blocker tile once")
	_assert_eq(int(game.player.board_charges.get("bypass", -1)), 0, "smuggler bypass charge is consumed on use")


func _test_killer_causes_loss() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(4, 3), "killer", false)
	_set_role(game, Vector2i(3, 2), "guide", true)
	game.try_flip_cell(Vector2i(3, 2))
	_assert_true(not game.player.alive, "killer makes the player lose on entry")


func _test_guide_reveal_delays_activation() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(3, 2), "guide", true)
	_set_role(game, Vector2i(3, 1), "pusher", true)
	_set_role(game, Vector2i(2, 2), "killer", true)
	var report: Dictionary = game.try_flip_cell(Vector2i(3, 2))
	var reveal_count := int(report.get("reveals", []).size())
	_assert_true(reveal_count >= 2, "guide reveals nearby hidden cards immediately")
	_assert_eq(game.get_cell(Vector2i(3, 1)).activates_on_turn, 2, "guide-revealed roles wait until the next turn")


func _test_rewinder_grants_undo() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(3, 2), "rewinder", true)
	var report: Dictionary = game.try_flip_cell(Vector2i(3, 2))
	_assert_true(bool(report.get("ok", false)), "rewinder can be revealed normally")
	_assert_eq(int(game.player.board_charges.get("undo", -1)), 1, "rewinder grants one undo charge on reveal")


func _test_undo_rewinds_last_action() -> void:
	var game = _make_blank_game()
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(3, 2), "rewinder", true)
	game.try_flip_cell(Vector2i(3, 2))
	_assert_eq(game.player.position, Vector2i(4, 3), "rewinder turn still resolves board movement")
	var undo_report: Dictionary = game.try_undo()
	_assert_true(bool(undo_report.get("ok", false)), "undo succeeds after rewinder grants a charge")
	_assert_eq(game.player.position, Vector2i(3, 3), "undo restores the prior player position")
	_assert_true(game.get_cell(Vector2i(3, 2)).hidden, "undo restores the revealed rewinder to hidden")
	_assert_eq(int(game.player.board_charges.get("undo", -1)), 0, "undo spends the granted charge")
	_assert_eq(game.run.turn_index, 0, "undo restores the previous turn index")


func _test_first_board_reward_is_curated() -> void:
	var game = _make_blank_game()
	game.player.position = Vector2i(1, 3)
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(1, 2), "guide", true)
	game.try_flip_cell(Vector2i(1, 2))
	_assert_true(game.run.awaiting_upgrade_choice, "escaping a board opens an upgrade choice")
	_assert_eq(game.run.offered_upgrade_ids, ["peek", "anchor", "step"], "the first board offers curated starter upgrades")
	_assert_true(String(game.get_hud_state().get("objective_text", "")).contains("upgrade"), "objective text shifts into reward mode after escape")


func _test_escape_offers_upgrades() -> void:
	var game = _make_blank_game()
	game.player.position = Vector2i(1, 3)
	_set_role(game, Vector2i(2, 3), "pusher", false)
	_set_role(game, Vector2i(1, 2), "guide", true)
	game.try_flip_cell(Vector2i(1, 2))
	_assert_true(game.run.awaiting_upgrade_choice, "escaping a board opens an upgrade choice")
	_assert_true(game.run.offered_upgrade_ids.size() > 0, "upgrade offer includes at least one option")


func _make_blank_game():
	var game = MazeGame.new(Vector2i(7, 7), 5)
	var role_map: Dictionary = {}
	var hidden_positions: Array = []
	for y in range(7):
		for x in range(7):
			var pos := Vector2i(x, y)
			if pos == Vector2i(3, 3):
				continue
			role_map[pos] = "guide"
			hidden_positions.append(pos)
	game.force_board(role_map, hidden_positions, 1, [])
	return game


func _set_role(game, pos: Vector2i, role_id: String, hidden: bool) -> void:
	var cell = game.get_cell(pos)
	cell.role_id = role_id
	cell.hidden = hidden
	cell.activates_on_turn = 1
	cell.previewed = false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s." % [message, expected, actual])
