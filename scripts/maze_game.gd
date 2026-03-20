class_name MazeGame
extends RefCounted

const Types = preload("res://scripts/living_maze_types.gd")
const ThemeManifestRef = preload("res://themes/ink_theme_manifest.tres")

const INVALID_POS := Vector2i(-999, -999)
const DIRECTIONS := [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var grid_size: Vector2i = Vector2i(7, 7)
var random_seed: int = 0

var rng := RandomNumberGenerator.new()
var cells: Array = []
var player: Types.PlayerState = Types.PlayerState.new()
var run: Types.RunState = Types.RunState.new()
var role_definitions: Dictionary = {}
var upgrade_definitions: Dictionary = {}
var phase: String = "flip"
var status_text: String = ""
var failure_reason: String = ""
var last_role_id: String = ""
var event_log: Array[String] = []
var selected_action_id: String = "flip"
var board_cleared: bool = false
var turn_report: Dictionary = {}
var _theme_manifest = ThemeManifestRef


func _init(size: Vector2i = Vector2i(7, 7), seed: int = 0) -> void:
	grid_size = size
	random_seed = seed
	_build_role_definitions()
	_build_upgrade_definitions()
	_seed_rng()
	start_new_run(seed)


func start_new_run(seed: int = random_seed) -> void:
	random_seed = seed
	_seed_rng()
	run = Types.RunState.new()
	player = Types.PlayerState.new()
	player.unlocked_upgrades.clear()
	start_next_board(false)


func start_next_board(increment_depth: bool = true) -> void:
	if increment_depth:
		run.board_depth += 1
	player.alive = true
	player.position = get_center_position()
	player.grabbed_by = INVALID_POS
	player.board_charges = _make_board_charges()
	run.awaiting_upgrade_choice = false
	run.offered_upgrade_ids.clear()
	selected_action_id = "flip"
	board_cleared = false
	failure_reason = ""
	last_role_id = ""
	status_text = "Flip someone nearby and let the crowd move you."
	phase = "flip"
	event_log.clear()
	_generate_board()
	_push_event("Board %d begins. Reach any edge to escape." % run.board_depth)
	_refresh_status_text()
	_refresh_turn_report([], [], false)


func choose_upgrade(upgrade_id: String) -> bool:
	if not run.awaiting_upgrade_choice:
		return false
	if not run.offered_upgrade_ids.has(upgrade_id):
		return false
	player.unlocked_upgrades[upgrade_id] = true
	_push_event("Upgrade gained: %s." % get_upgrade_name(upgrade_id))
	start_next_board(true)
	return true


func get_center_position() -> Vector2i:
	return Vector2i(grid_size.x / 2, grid_size.y / 2)


func get_cells() -> Array:
	return cells


func get_cell(pos: Vector2i):
	if not is_in_bounds(pos):
		return null
	return cells[_index_for(pos)]


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_size.x and pos.y < grid_size.y


func get_role_definition(role_id: String):
	return role_definitions.get(role_id)


func get_upgrade_definition(upgrade_id: String):
	return upgrade_definitions.get(upgrade_id)


func get_last_role_definition():
	return role_definitions.get(last_role_id)


func get_legal_flip_positions() -> Array[Vector2i]:
	return _get_flip_positions_for_range(1)


func get_action_buttons() -> Array[Dictionary]:
	var buttons: Array[Dictionary] = []
	for upgrade_id in upgrade_definitions.keys():
		if not player.unlocked_upgrades.get(upgrade_id, false):
			continue
		var charge_value = player.board_charges.get(upgrade_id, 0)
		var enabled := false
		if phase == "flip" and player.alive and not run.awaiting_upgrade_choice:
			match upgrade_id:
				"peek", "step", "remote_flip":
					enabled = charge_value > 0 and not get_valid_targets_for_action(upgrade_id).is_empty()
				"anchor":
					enabled = charge_value > 0 and not bool(player.board_charges.get("anchor_ready", false))
				"flip_again":
					enabled = false
		buttons.append({
			"id": upgrade_id,
			"label": "%s (%s)" % [get_upgrade_name(upgrade_id), _format_charge_label(upgrade_id)],
			"selected": selected_action_id == upgrade_id,
			"enabled": enabled,
			"icon_id": String(upgrade_definitions[upgrade_id].icon_id),
			"accent_color": upgrade_definitions[upgrade_id].accent_color,
		})
	return buttons


func get_valid_targets_for_action(action_id: String) -> Array[Vector2i]:
	match action_id:
		"flip":
			return get_legal_flip_positions()
		"peek":
			return _get_flip_positions_for_range(1)
		"remote_flip":
			return _get_flip_positions_for_range(2, true)
		"step":
			return _get_step_targets()
		_:
			return []


func get_upgrade_offer_data() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for upgrade_id in run.offered_upgrade_ids:
		var definition = get_upgrade_definition(upgrade_id)
		if definition == null:
			continue
		offers.append({
			"id": definition.id,
			"name": definition.display_name,
			"description": definition.description,
			"icon_id": definition.icon_id,
			"accent_color": definition.accent_color,
		})
	return offers


func set_selected_action(action_id: String) -> bool:
	if action_id == "flip":
		selected_action_id = "flip"
		return true
	if not player.unlocked_upgrades.get(action_id, false):
		return false
	var charge_value = player.board_charges.get(action_id, 0)
	match action_id:
		"peek", "step", "remote_flip":
			if charge_value <= 0:
				return false
			selected_action_id = action_id
			return true
		"anchor":
			if charge_value <= 0:
				return false
			player.board_charges["anchor_ready"] = true
			player.board_charges[action_id] = max(charge_value - 1, 0)
			selected_action_id = "flip"
			_push_event("Anchor is armed. The next forced move will be canceled.")
			_refresh_status_text()
			_refresh_turn_report([], [], false)
			return true
		_:
			return false


func try_flip_cell(pos: Vector2i) -> Dictionary:
	if phase != "flip" or run.awaiting_upgrade_choice or not player.alive:
		return _make_action_result(false)
	match selected_action_id:
		"flip":
			return _execute_flip(pos, 1)
		"peek":
			return _execute_peek(pos)
		"remote_flip":
			return _execute_flip(pos, 2, true)
		"step":
			return _execute_step(pos)
		_:
			return _make_action_result(false)


func note_invalid_click() -> void:
	if run.awaiting_upgrade_choice:
		status_text = "Choose an upgrade to continue."
		return
	if not player.alive:
		status_text = failure_reason if not failure_reason.is_empty() else "Press R to restart."
		return
	match selected_action_id:
		"flip":
			status_text = "Click a hidden tile next to the player."
		"peek":
			status_text = "Peek only works on highlighted adjacent hidden tiles."
		"remote_flip":
			status_text = "Remote Flip only works on highlighted tiles exactly 2 spaces away."
		"step":
			status_text = "Step only works on highlighted revealed tiles."
		_:
			status_text = "That tile is not a valid target right now."


func get_preview_intents() -> Array[Dictionary]:
	if phase != "flip" or run.awaiting_upgrade_choice or not player.alive:
		return []
	var previews: Array[Dictionary] = []
	var snapshot := player.position
	for cell in _get_row_major_cells():
		if cell.hidden or cell.is_center or cell.activates_on_turn > run.turn_index:
			continue
		if cell.role_id == "pusher" and _is_orthogonally_adjacent(cell.grid_position, snapshot):
			previews.append({
				"from": cell.grid_position,
				"to": snapshot + _direction_from_to(cell.grid_position, snapshot),
				"kind": "push",
			})
		elif cell.role_id == "puller" and _is_orthogonally_adjacent(cell.grid_position, snapshot):
			previews.append({
				"from": cell.grid_position,
				"to": snapshot + _direction_from_to(snapshot, cell.grid_position),
				"kind": "pull",
			})
	return previews


func get_hud_state() -> Dictionary:
	var role_name := ""
	var role_description := ""
	var role_definition = get_last_role_definition()
	if role_definition != null:
		role_name = role_definition.display_name
		role_description = role_definition.description

	var phase_label := phase.capitalize()
	if run.awaiting_upgrade_choice:
		phase_label = "Reward"
	elif not player.alive:
		phase_label = "Loss"

	var lines: Array[String] = event_log.slice(maxi(event_log.size() - 5, 0), event_log.size())
	return {
		"depth": run.board_depth,
		"score": run.score,
		"phase": phase_label,
		"status": status_text,
		"title_text": _theme_manifest.title_text,
		"subtitle_text": _theme_manifest.subtitle_text,
		"objective_text": "Reach any edge to escape.",
		"pressure_current": _get_pressure_value(),
		"pressure_max": 10,
		"last_role_name": role_name,
		"last_role_description": role_description,
		"failure_reason": failure_reason,
		"player_alive": player.alive,
		"log_lines": lines,
		"selected_action": selected_action_id,
		"anchor_ready": bool(player.board_charges.get("anchor_ready", false)),
		"legend_items": get_role_legend_data(),
		"log_items": get_log_entries(lines),
		"structure_items": get_structure_data(),
		"minimap": get_minimap_data(),
	}


func force_board(role_map: Dictionary, hidden_positions: Array = [], board_depth: int = 1, unlocked_upgrades: Array[String] = []) -> void:
	run.board_depth = board_depth
	run.score = max(board_depth - 1, 0)
	run.turn_index = 0
	run.awaiting_upgrade_choice = false
	run.offered_upgrade_ids.clear()
	cells.clear()
	player = Types.PlayerState.new()
	player.position = get_center_position()
	player.alive = true
	player.grabbed_by = INVALID_POS
	for upgrade_id in unlocked_upgrades:
		player.unlocked_upgrades[upgrade_id] = true
	player.board_charges = _make_board_charges()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Types.CellState.new()
			cell.grid_position = Vector2i(x, y)
			cell.is_center = cell.grid_position == get_center_position()
			if cell.is_center:
				cell.role_id = ""
				cell.hidden = false
			else:
				cell.role_id = String(role_map.get(cell.grid_position, "pusher"))
				cell.hidden = hidden_positions.has(cell.grid_position)
				cell.activates_on_turn = 1
			cells.append(cell)
	board_cleared = false
	failure_reason = ""
	last_role_id = ""
	selected_action_id = "flip"
	phase = "flip"
	event_log.clear()
	_refresh_status_text()
	_refresh_turn_report([], [], false)


func _build_role_definitions() -> void:
	role_definitions.clear()
	_add_role("pusher", "Pusher", "pusher", "Pushes you 1 tile away when active beside you.", "active", 14, 1, 0)
	_add_role("puller", "Puller", "puller", "Pulls you 1 tile toward itself when active beside you.", "active", 14, 1, 0)
	_add_role("blocker", "Blocker", "blocker", "Stops movement into its tile unless you have bypass.", "reactive", 10, 1, 0)
	_add_role("redirector", "Redirector", "redirector", "Redirects incoming movement clockwise.", "reactive", 8, 2, 0)
	_add_role("grabber", "Grabber", "grabber", "Holds you in place once you end beside it.", "reactive", 7, 2, 0)
	_add_role("guide", "Guide", "guide", "Reveals up to 2 nearby hidden people.", "on_reveal", 9, 1, 0)
	_add_role("smuggler", "Smuggler", "smuggler", "Grants a one-time blocker bypass.", "on_reveal", 8, 1, 0)
	_add_role("killer", "Killer", "killer", "Kills you if you enter its tile.", "reactive", 5, 1, 0)


func _build_upgrade_definitions() -> void:
	upgrade_definitions.clear()
	_add_upgrade("peek", "Observe", "Once per board, preview one adjacent hidden role.", "cell")
	_add_upgrade("anchor", "Anchor", "Once per board, cancel the next forced move.", "instant")
	_add_upgrade("step", "Step", "Once per board, move 1 tile onto a safe revealed tile.", "cell")
	_add_upgrade("remote_flip", "Remote Flip", "Once per board, flip a hidden tile at orthogonal range 2.", "cell")
	_add_upgrade("flip_again", "Second Sight", "Once per board, your first flip gives you a bonus extra flip.", "passive")


func _generate_board() -> void:
	var tries := 0
	while tries < 30:
		tries += 1
		cells.clear()
		var counts: Dictionary = {}
		var center := get_center_position()
		var first_ring := _get_adjacent_positions(center)
		var transport_slots := first_ring.duplicate()
		transport_slots.shuffle()
		var transport_pos: Vector2i = transport_slots[0]
		var help_pos: Vector2i = transport_slots[1]
		var transport_roles := ["pusher", "puller"]
		var help_roles := ["guide", "smuggler"]
		var assigned_roles: Dictionary = {
			transport_pos: transport_roles[rng.randi_range(0, transport_roles.size() - 1)],
			help_pos: help_roles[rng.randi_range(0, help_roles.size() - 1)],
		}

		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var pos := Vector2i(x, y)
				var cell := Types.CellState.new()
				cell.grid_position = pos
				cell.is_center = pos == center
				if cell.is_center:
					cell.role_id = ""
					cell.hidden = false
					cell.activates_on_turn = 9999
					cells.append(cell)
					continue

				var distance := _manhattan_distance(pos, center)
				var role_id := ""
				if assigned_roles.has(pos):
					role_id = String(assigned_roles[pos])
				else:
					role_id = _pick_role_for_position(pos, distance, counts)
				counts[role_id] = int(counts.get(role_id, 0)) + 1
				cell.role_id = role_id
				cell.hidden = true
				cell.previewed = false
				cell.activates_on_turn = 1
				cells.append(cell)
		if _is_generation_acceptable():
			return


func _pick_role_for_position(pos: Vector2i, distance: int, counts: Dictionary) -> String:
	var candidates: Array[String] = []
	var weights: Array[int] = []
	var center := get_center_position()
	var first_ring_allowed := {
		"pusher": true,
		"puller": true,
		"guide": true,
		"smuggler": true,
		"blocker": true,
	}
	for role_id in role_definitions.keys():
		var definition: Types.RoleDefinition = role_definitions[role_id]
		if run.board_depth < definition.min_depth:
			continue
		if distance < definition.min_center_distance:
			continue
		if definition.max_count >= 0 and int(counts.get(role_id, 0)) >= definition.max_count:
			continue
		if role_id == "killer" and run.board_depth < 3 and distance <= 2:
			continue
		if distance == 1 and not first_ring_allowed.has(role_id):
			continue
		candidates.append(role_id)
		weights.append(definition.weight)
	if candidates.is_empty():
		return "pusher"
	return _pick_weighted(candidates, weights)


func _is_generation_acceptable() -> bool:
	var center := get_center_position()
	var first_ring := _get_adjacent_positions(center)
	var has_transport := false
	var has_help := false
	for pos in first_ring:
		var cell = get_cell(pos)
		if cell == null:
			continue
		if cell.role_id == "pusher" or cell.role_id == "puller":
			has_transport = true
		if cell.role_id == "guide" or cell.role_id == "smuggler":
			has_help = true
		if cell.role_id == "killer":
			return false
	return has_transport and has_help


func _execute_peek(pos: Vector2i) -> Dictionary:
	if selected_action_id != "peek":
		return _make_action_result(false)
	if not get_valid_targets_for_action("peek").has(pos):
		return _make_action_result(false)
	var cell = get_cell(pos)
	if cell == null or not cell.hidden:
		return _make_action_result(false)
	player.board_charges["peek"] = max(int(player.board_charges.get("peek", 0)) - 1, 0)
	cell.previewed = true
	last_role_id = cell.role_id
	_push_event("Peeked at %s: %s." % [cell.grid_position, get_role_name(cell.role_id)])
	status_text = "Peek used. Flip or use another ability."
	selected_action_id = "flip"
	_refresh_turn_report([], [], false)
	return _make_action_result(true)


func _execute_step(pos: Vector2i) -> Dictionary:
	if selected_action_id != "step":
		return _make_action_result(false)
	if not get_valid_targets_for_action("step").has(pos):
		return _make_action_result(false)
	if player.is_grabbed():
		var current_distance := _manhattan_distance(player.position, player.grabbed_by)
		var next_distance := _manhattan_distance(pos, player.grabbed_by)
		if next_distance > current_distance:
			return _make_action_result(false)
	player.board_charges["step"] = max(int(player.board_charges.get("step", 0)) - 1, 0)
	selected_action_id = "flip"
	var moves := [{
		"from": player.position,
		"to": pos,
		"source_role_id": "step",
		"label": "Step",
	}]
	player.position = pos
	_push_event("Stepped to %s." % pos)
	_after_movement_cleanup()
	if _is_edge(player.position):
		board_cleared = true
		run.score += 1
		_push_event("You reached the edge and escaped.")
	phase = "end_check"
	_evaluate_end_state(false)
	_finalize_action([], moves, false)
	return _make_action_result(true)


func _execute_flip(pos: Vector2i, flip_range: int, consume_remote: bool = false) -> Dictionary:
	var legal_positions := _get_flip_positions_for_range(flip_range, consume_remote)
	if not legal_positions.has(pos):
		return _make_action_result(false)
	var cell = get_cell(pos)
	if cell == null or cell.is_center or not cell.hidden:
		return _make_action_result(false)
	if consume_remote:
		player.board_charges["remote_flip"] = max(int(player.board_charges.get("remote_flip", 0)) - 1, 0)
	selected_action_id = "flip"
	run.turn_index += 1
	phase = "on_reveal"
	var revealed_positions: Array[Dictionary] = []
	var movement_steps: Array[Dictionary] = []
	var used_bonus_flip := false

	_reveal_cell(cell, revealed_positions, true)
	_handle_on_reveal(cell, revealed_positions)

	phase = "reactive"
	phase = "active"
	var intents := _collect_active_intents()
	phase = "settlement"
	movement_steps = _resolve_intents(intents)
	phase = "end_check"
	used_bonus_flip = _evaluate_end_state(true)
	_finalize_action(revealed_positions, movement_steps, used_bonus_flip)
	return _make_action_result(true)


func _reveal_cell(cell, revealed_positions: Array[Dictionary], delayed: bool) -> void:
	cell.hidden = false
	cell.previewed = false
	cell.revealed_on_turn = run.turn_index
	cell.activates_on_turn = run.turn_index + 1 if delayed else run.turn_index
	last_role_id = cell.role_id
	revealed_positions.append({
		"position": cell.grid_position,
		"role_id": cell.role_id,
		"delayed": delayed,
	})
	_push_event("Revealed %s at %s." % [get_role_name(cell.role_id), cell.grid_position])


func _handle_on_reveal(cell, revealed_positions: Array[Dictionary]) -> void:
	match cell.role_id:
		"guide":
			var reveal_count := 0
			for pos in _get_adjacent_positions(cell.grid_position):
				var nearby = get_cell(pos)
				if nearby == null or nearby.is_center or not nearby.hidden:
					continue
				_reveal_cell(nearby, revealed_positions, true)
				reveal_count += 1
				if reveal_count >= 2:
					break
			_push_event("Guide points out nearby faces.")
		"smuggler":
			player.board_charges["bypass"] = 1
			_push_event("Smuggler grants a blocker bypass.")


func _collect_active_intents() -> Array:
	var intents: Array = []
	var snapshot := player.position
	for cell in _get_row_major_cells():
		if cell.hidden or cell.is_center or cell.activates_on_turn > run.turn_index:
			continue
		if not _is_orthogonally_adjacent(cell.grid_position, snapshot):
			continue
		var intent := Types.MovementIntent.new()
		if cell.role_id == "pusher":
			intent.source_role_id = "pusher"
			intent.source_position = cell.grid_position
			intent.direction = _direction_from_to(cell.grid_position, snapshot)
			intent.distance = 1
			intent.label = "Push"
			intents.append(intent)
			_push_event("Pusher at %s shoves you." % cell.grid_position)
		elif cell.role_id == "puller":
			intent.source_role_id = "puller"
			intent.source_position = cell.grid_position
			intent.direction = _direction_from_to(snapshot, cell.grid_position)
			intent.distance = 1
			intent.label = "Pull"
			intents.append(intent)
			_push_event("Puller at %s drags you." % cell.grid_position)
	return intents


func _resolve_intents(intents: Array) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if bool(player.board_charges.get("anchor_ready", false)) and not intents.is_empty():
		var first_intent: Types.MovementIntent = intents[0]
		_push_event("Anchor cancels %s from %s." % [first_intent.label.to_lower(), first_intent.source_position])
		player.board_charges["anchor_ready"] = false
		intents.remove_at(0)
	for intent in intents:
		if not player.alive or board_cleared:
			break
		_apply_movement_intent(intent, steps)
	_after_movement_cleanup()
	return steps


func _apply_movement_intent(intent: Types.MovementIntent, steps: Array[Dictionary]) -> void:
	for _distance_index in range(intent.distance):
		if not player.alive or board_cleared:
			return
		var next_pos := player.position + intent.direction
		if not is_in_bounds(next_pos):
			_push_event("%s is stopped by the edge." % intent.label)
			return
		if player.is_grabbed():
			var current_distance := _manhattan_distance(player.position, player.grabbed_by)
			var next_distance := _manhattan_distance(next_pos, player.grabbed_by)
			if next_distance > current_distance:
				_push_event("Grabber holds you in place.")
				return
		var redirected_step := _try_redirect(intent.direction)
		if redirected_step.size() > 0:
			next_pos = redirected_step["to"]
			intent.direction = redirected_step["direction"]
			_push_event("Redirector bends the movement.")
		var target_cell = get_cell(next_pos)
		if target_cell == null:
			return
		if not _can_enter_cell(target_cell):
			return
		var previous := player.position
		player.position = next_pos
		steps.append({
			"from": previous,
			"to": next_pos,
			"source_role_id": intent.source_role_id,
			"label": intent.label,
		})
		if player.is_grabbed():
			player.grabbed_by = INVALID_POS
			_push_event("You break free of the grabber.")
		if _check_killer(target_cell):
			return
		if _is_edge(next_pos):
			board_cleared = true
			run.score += 1
			_push_event("You reached the edge and escaped.")
			return


func _try_redirect(current_direction: Vector2i) -> Dictionary:
	var next_pos := player.position + current_direction
	var cell = get_cell(next_pos)
	if cell == null or cell.hidden or cell.activates_on_turn > run.turn_index:
		return {}
	if cell.role_id != "redirector":
		return {}
	var redirected_direction := Vector2i(-current_direction.y, current_direction.x)
	var redirected_pos := player.position + redirected_direction
	if not is_in_bounds(redirected_pos):
		return {}
	return {
		"to": redirected_pos,
		"direction": redirected_direction,
	}


func _can_enter_cell(cell) -> bool:
	if cell.hidden or cell.activates_on_turn > run.turn_index:
		return true
	if cell.role_id != "blocker":
		return true
	var bypass_charges := int(player.board_charges.get("bypass", 0))
	if bypass_charges > 0:
		player.board_charges["bypass"] = bypass_charges - 1
		_push_event("Smuggler bypass slips you through a blocker.")
		return true
	_push_event("Blocker stops the movement.")
	return false


func _check_killer(cell) -> bool:
	if cell.hidden or cell.activates_on_turn > run.turn_index:
		return false
	if cell.role_id != "killer":
		return false
	player.alive = false
	failure_reason = "A killer caught you."
	_push_event("You were pushed into a killer.")
	return true


func _after_movement_cleanup() -> void:
	if not player.alive or board_cleared:
		return
	var grabbers := _adjacent_revealed_roles(player.position, "grabber")
	if grabbers.is_empty():
		player.grabbed_by = INVALID_POS
		return
	player.grabbed_by = grabbers[0]
	_push_event("Grabber locks onto you.")


func _evaluate_end_state(consumed_flip: bool) -> bool:
	if board_cleared:
		_prepare_upgrade_choices_if_needed()
		return false
	if not player.alive:
		phase = "loss"
		status_text = failure_reason
		return false
	if _is_trapped():
		player.alive = false
		failure_reason = "You are trapped with no legal actions left."
		status_text = failure_reason
		_push_event(failure_reason)
		return false
	if consumed_flip and player.unlocked_upgrades.get("flip_again", false) and int(player.board_charges.get("flip_again", 0)) > 0:
		if not get_legal_flip_positions().is_empty():
			player.board_charges["flip_again"] = 0
			_push_event("Flip Again lets you take one more flip this board.")
			status_text = "Bonus flip available."
			return true
	return false


func _prepare_upgrade_choices_if_needed() -> void:
	if upgrade_definitions.size() == player.unlocked_upgrades.size():
		start_next_board(true)
		return
	run.awaiting_upgrade_choice = true
	run.offered_upgrade_ids = _draw_upgrade_choices()
	phase = "reward"
	status_text = "Choose an upgrade for the next board."


func _draw_upgrade_choices() -> Array[String]:
	var pool: Array[String] = []
	for upgrade_id in upgrade_definitions.keys():
		if player.unlocked_upgrades.get(upgrade_id, false):
			continue
		pool.append(upgrade_id)
	_shuffle(pool)
	return pool.slice(0, mini(3, pool.size()))


func _is_trapped() -> bool:
	if not get_legal_flip_positions().is_empty():
		return false
	if player.unlocked_upgrades.get("peek", false) and int(player.board_charges.get("peek", 0)) > 0 and not get_valid_targets_for_action("peek").is_empty():
		return false
	if player.unlocked_upgrades.get("remote_flip", false) and int(player.board_charges.get("remote_flip", 0)) > 0 and not get_valid_targets_for_action("remote_flip").is_empty():
		return false
	if player.unlocked_upgrades.get("step", false) and int(player.board_charges.get("step", 0)) > 0 and not get_valid_targets_for_action("step").is_empty():
		return false
	return true


func _get_flip_positions_for_range(max_range: int, exact_range: bool = false) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for direction in DIRECTIONS:
		for distance in range(1, max_range + 1):
			var pos: Vector2i = player.position + direction * distance
			if not is_in_bounds(pos):
				break
			var cell = get_cell(pos)
			if cell == null or cell.is_center:
				continue
			if exact_range and distance != max_range:
				if not cell.hidden:
					continue
			if distance == max_range or not exact_range:
				if cell.hidden:
					positions.append(pos)
			if not exact_range:
				break
	return positions


func _get_step_targets() -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for pos in _get_adjacent_positions(player.position):
		var cell = get_cell(pos)
		if cell == null or cell.hidden:
			continue
		if cell.role_id == "killer":
			continue
		if cell.role_id == "blocker":
			continue
		if player.is_grabbed():
			var current_distance := _manhattan_distance(player.position, player.grabbed_by)
			var next_distance := _manhattan_distance(pos, player.grabbed_by)
			if next_distance > current_distance:
				continue
		targets.append(pos)
	return targets


func _make_board_charges() -> Dictionary:
	return {
		"peek": 1 if player.unlocked_upgrades.get("peek", false) else 0,
		"anchor": 1 if player.unlocked_upgrades.get("anchor", false) else 0,
		"anchor_ready": false,
		"step": 1 if player.unlocked_upgrades.get("step", false) else 0,
		"remote_flip": 1 if player.unlocked_upgrades.get("remote_flip", false) else 0,
		"flip_again": 1 if player.unlocked_upgrades.get("flip_again", false) else 0,
		"bypass": 0,
	}


func _finalize_action(revealed_positions: Array, movement_steps: Array, bonus_flip: bool) -> void:
	if not run.awaiting_upgrade_choice and player.alive:
		phase = "flip"
	_refresh_status_text()
	_refresh_turn_report(revealed_positions, movement_steps, bonus_flip)


func _make_action_result(ok: bool) -> Dictionary:
	return turn_report.duplicate(true) if ok else {"ok": false}


func _refresh_turn_report(revealed_positions: Array, movement_steps: Array, bonus_flip: bool) -> void:
	turn_report = {
		"ok": true,
		"reveals": revealed_positions.duplicate(true),
		"moves": movement_steps.duplicate(true),
		"bonus_flip": bonus_flip,
		"board_cleared": board_cleared,
		"awaiting_upgrade_choice": run.awaiting_upgrade_choice,
		"player_alive": player.alive,
	}


func _refresh_status_text() -> void:
	if run.awaiting_upgrade_choice:
		status_text = "Choose an upgrade for the next board."
		return
	if not player.alive:
		status_text = failure_reason
		return
	var legal_flips := get_legal_flip_positions().size()
	var bypass := int(player.board_charges.get("bypass", 0))
	var grab_text := " Grabbed." if player.is_grabbed() else ""
	var anchor_text := " Anchor ready." if bool(player.board_charges.get("anchor_ready", false)) else ""
	status_text = "%d legal flips.%s%s" % [legal_flips, grab_text, anchor_text]
	if bypass > 0:
		status_text += " Bypass ready."


func _get_pressure_value() -> int:
	var pressure := run.turn_index
	if player.is_grabbed():
		pressure += 2
	if bool(player.board_charges.get("anchor_ready", false)):
		pressure += 1
	for pos in _get_adjacent_positions(player.position):
		var cell = get_cell(pos)
		if cell == null or cell.hidden:
			continue
		if cell.role_id in ["pusher", "puller", "killer", "grabber"]:
			pressure += 1
	return clampi(pressure, 0, 10)


func _adjacent_revealed_roles(origin: Vector2i, role_id: String) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for pos in _get_adjacent_positions(origin):
		var cell = get_cell(pos)
		if cell == null or cell.hidden or cell.activates_on_turn > run.turn_index:
			continue
		if cell.role_id == role_id:
			positions.append(pos)
	return positions


func _get_adjacent_positions(origin: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var pos: Vector2i = origin + direction
		if is_in_bounds(pos):
			positions.append(pos)
	return positions


func _is_orthogonally_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return _manhattan_distance(a, b) == 1


func _direction_from_to(origin: Vector2i, target: Vector2i) -> Vector2i:
	return Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))


func _index_for(pos: Vector2i) -> int:
	return pos.y * grid_size.x + pos.x


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _is_edge(pos: Vector2i) -> bool:
	return pos.x == 0 or pos.y == 0 or pos.x == grid_size.x - 1 or pos.y == grid_size.y - 1


func _get_row_major_cells() -> Array:
	var ordered: Array = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			ordered.append(get_cell(Vector2i(x, y)))
	return ordered


func _pick_weighted(items: Array[String], weights: Array[int]) -> String:
	var total := 0
	for weight in weights:
		total += weight
	var roll := rng.randi_range(1, max(total, 1))
	var running := 0
	for index in range(items.size()):
		running += weights[index]
		if roll <= running:
			return items[index]
	return items[items.size() - 1]


func _seed_rng() -> void:
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed


func _push_event(text: String) -> void:
	event_log.append(text)
	if event_log.size() > 16:
		event_log.pop_front()


func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp


func _add_role(id: String, name: String, icon_id: String, description: String, timing: String, weight: int, min_depth: int, min_center_distance: int) -> void:
	var definition := Types.RoleDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.icon_id = icon_id
	definition.portrait_asset_id = _theme_manifest.get_role_portrait_asset_id(id)
	definition.legend_icon_id = icon_id
	definition.log_icon_id = icon_id
	definition.silhouette_asset_id = "%s_shadow" % icon_id
	definition.accent_color = _theme_manifest.get_color(icon_id, Color.WHITE)
	definition.description = description
	definition.timing = timing
	definition.weight = weight
	definition.min_depth = min_depth
	definition.min_center_distance = min_center_distance
	role_definitions[id] = definition


func _add_upgrade(id: String, name: String, description: String, target_mode: String) -> void:
	var definition := Types.UpgradeDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.description = description
	definition.icon_id = id
	definition.accent_color = _theme_manifest.get_color(id, _theme_manifest.get_color("highlight"))
	definition.target_mode = target_mode
	upgrade_definitions[id] = definition


func get_role_legend_data() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for role_id in role_definitions.keys():
		var definition: Types.RoleDefinition = role_definitions[role_id]
		items.append({
			"id": definition.id,
			"label": definition.display_name.to_upper(),
			"icon_id": definition.legend_icon_id,
			"accent_color": definition.accent_color,
		})
	return items


func get_log_entries(lines: Array = []) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var source: Array = lines if not lines.is_empty() else event_log
	for line in source:
		var text := String(line)
		var icon_id := "flip"
		if text.contains("Push") or text.contains("shove"):
			icon_id = "pusher"
		elif text.contains("Pull") or text.contains("drag"):
			icon_id = "puller"
		elif text.contains("Blocker"):
			icon_id = "blocker"
		elif text.contains("Redirector"):
			icon_id = "redirector"
		elif text.contains("Grabber"):
			icon_id = "grabber"
		elif text.contains("Guide"):
			icon_id = "guide"
		elif text.contains("Smuggler"):
			icon_id = "smuggler"
		elif text.contains("killer") or text.contains("Killer"):
			icon_id = "killer"
		elif text.contains("Anchor"):
			icon_id = "anchor"
		entries.append({
			"text": text,
			"icon_id": icon_id,
			"accent_color": _theme_manifest.get_color(icon_id, _theme_manifest.get_color("muted")),
		})
	return entries


func get_structure_data() -> Array[Dictionary]:
	return [
		{"id": "conduit", "enabled": true},
		{"id": "gate", "enabled": run.board_depth >= 2},
		{"id": "anchor_node", "enabled": player.unlocked_upgrades.get("anchor", false) or bool(player.board_charges.get("anchor_ready", false))},
		{"id": "hub", "enabled": run.score > 0 or run.awaiting_upgrade_choice},
	]


func get_minimap_data() -> Dictionary:
	var cells_data: Array[Dictionary] = []
	for cell in cells:
		cells_data.append({
			"position": cell.grid_position,
			"role_id": cell.role_id,
			"is_hidden": cell.hidden,
			"is_edge": _is_edge(cell.grid_position),
			"is_player": cell.grid_position == player.position,
		})
	return {
		"grid_size": grid_size,
		"cells": cells_data,
	}


func get_role_name(role_id: String) -> String:
	var definition = get_role_definition(role_id)
	return definition.display_name if definition != null else role_id.capitalize()


func get_upgrade_name(upgrade_id: String) -> String:
	var definition = get_upgrade_definition(upgrade_id)
	return definition.display_name if definition != null else upgrade_id.capitalize()


func _format_charge_label(upgrade_id: String) -> String:
	if upgrade_id == "flip_again":
		return "%d left" % int(player.board_charges.get(upgrade_id, 0))
	if upgrade_id == "anchor":
		return "ready" if int(player.board_charges.get(upgrade_id, 0)) > 0 or bool(player.board_charges.get("anchor_ready", false)) else "spent"
	return "%d left" % int(player.board_charges.get(upgrade_id, 0))
