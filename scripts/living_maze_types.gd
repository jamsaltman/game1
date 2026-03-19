class_name LivingMazeTypes
extends RefCounted


class CellState:
	extends RefCounted

	var grid_position: Vector2i = Vector2i.ZERO
	var role_id: String = ""
	var hidden: bool = true
	var is_center: bool = false
	var previewed: bool = false
	var revealed_on_turn: int = -1
	var activates_on_turn: int = 1

	func duplicate_state() -> CellState:
		var copy := CellState.new()
		copy.grid_position = grid_position
		copy.role_id = role_id
		copy.hidden = hidden
		copy.is_center = is_center
		copy.previewed = previewed
		copy.revealed_on_turn = revealed_on_turn
		copy.activates_on_turn = activates_on_turn
		return copy


class PlayerState:
	extends RefCounted

	var position: Vector2i = Vector2i.ZERO
	var alive: bool = true
	var grabbed_by: Vector2i = Vector2i(-999, -999)
	var unlocked_upgrades: Dictionary = {}
	var board_charges: Dictionary = {}

	func duplicate_state() -> PlayerState:
		var copy := PlayerState.new()
		copy.position = position
		copy.alive = alive
		copy.grabbed_by = grabbed_by
		copy.unlocked_upgrades = unlocked_upgrades.duplicate(true)
		copy.board_charges = board_charges.duplicate(true)
		return copy

	func is_grabbed() -> bool:
		return grabbed_by.x > -999 and grabbed_by.y > -999


class RunState:
	extends RefCounted

	var board_depth: int = 1
	var score: int = 0
	var turn_index: int = 0
	var awaiting_upgrade_choice: bool = false
	var offered_upgrade_ids: Array[String] = []

	func duplicate_state() -> RunState:
		var copy := RunState.new()
		copy.board_depth = board_depth
		copy.score = score
		copy.turn_index = turn_index
		copy.awaiting_upgrade_choice = awaiting_upgrade_choice
		copy.offered_upgrade_ids = offered_upgrade_ids.duplicate()
		return copy


class MovementIntent:
	extends RefCounted

	var source_role_id: String = ""
	var source_position: Vector2i = Vector2i.ZERO
	var direction: Vector2i = Vector2i.ZERO
	var distance: int = 1
	var label: String = ""
	var tags: PackedStringArray = PackedStringArray()

	func duplicate_state() -> MovementIntent:
		var copy := MovementIntent.new()
		copy.source_role_id = source_role_id
		copy.source_position = source_position
		copy.direction = direction
		copy.distance = distance
		copy.label = label
		copy.tags = tags.duplicate()
		return copy


class RoleDefinition:
	extends RefCounted

	var id: String = ""
	var display_name: String = ""
	var icon_id: String = ""
	var description: String = ""
	var timing: String = ""
	var weight: int = 0
	var min_depth: int = 1
	var min_center_distance: int = 0
	var max_count: int = -1


class UpgradeDefinition:
	extends RefCounted

	var id: String = ""
	var display_name: String = ""
	var description: String = ""
	var target_mode: String = "cell"
	var targeting_rule: String = ""
