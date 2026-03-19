class_name Board
extends Node3D

signal state_changed
signal hovered_tile_changed

const MazeGameRef = preload("res://scripts/maze_game.gd")
const InkPainterRef = preload("res://scripts/ink_painter.gd")
const ThemeManifestRef = preload("res://themes/ink_theme_manifest.tres")

@export_range(3, 10, 1) var grid_width: int = 7
@export_range(3, 10, 1) var grid_height: int = 7
@export_range(1.0, 2.0, 0.01) var tile_spacing: float = 1.18
@export var tile_size: float = 1.04
@export_range(0.0, 2.0, 0.01) var board_margin: float = 0.3
@export_range(0.0, 3.0, 0.01) var camera_padding: float = 0.3
@export var random_seed: int = 0
@export var tile_scene: PackedScene = preload("res://scenes/tile.tscn")

var _game = null
var _tiles_by_pos: Dictionary = {}
var _hovered_tile = null
var _resolving_turn: bool = false
var _selected_targets: Array[Vector2i] = []
var _preview_markers: Array = []
var _player_move_tween: Tween
var _player_base_y: float = 0.30
var _theme_manifest = ThemeManifestRef
var _painter = InkPainterRef.new(_theme_manifest)

@onready var _tiles_root: Node3D = $Tiles
@onready var _board_base: MeshInstance3D = $BoardBase


func _ready() -> void:
	_ensure_helper_nodes()
	start_new_run()


func start_new_run() -> void:
	_game = MazeGameRef.new(Vector2i(grid_width, grid_height), random_seed)
	_rebuild_tiles()
	_sync_board_visuals()
	emit_signal("state_changed")


func reset_board() -> void:
	start_new_run()


func start_next_board() -> void:
	if _game == null:
		start_new_run()
		return
	_game.start_next_board()
	_sync_board_visuals()
	emit_signal("state_changed")


func choose_upgrade(upgrade_id: String) -> void:
	if _game == null or _resolving_turn:
		return
	if _game.choose_upgrade(upgrade_id):
		_sync_board_visuals()
		emit_signal("state_changed")


func set_selected_action(action_id: String) -> void:
	if _game == null or _resolving_turn:
		return
	if _game.set_selected_action(action_id):
		_sync_board_visuals()
		emit_signal("state_changed")


func update_hover(screen_pos: Vector2, active: bool) -> void:
	if _resolving_turn:
		active = false
	var next_tile = _pick_tile(screen_pos) if active else null
	if _hovered_tile == next_tile:
		return
	if is_instance_valid(_hovered_tile):
		_hovered_tile.set_hovered(false)
	_hovered_tile = next_tile
	if is_instance_valid(_hovered_tile):
		_hovered_tile.set_hovered(true)
	emit_signal("hovered_tile_changed")


func click_tile(screen_pos: Vector2) -> void:
	if _game == null or _resolving_turn:
		return
	var tile = _pick_tile(screen_pos)
	if tile == null:
		return
	_handle_grid_click(tile.grid_position)


func _handle_grid_click(grid_pos: Vector2i) -> void:
	var clicked_tile = _tiles_by_pos.get(grid_pos)
	var report: Dictionary = _game.try_flip_cell(grid_pos)
	if not bool(report.get("ok", false)) and _game.selected_action_id != "flip":
		_game.set_selected_action("flip")
		report = _game.try_flip_cell(grid_pos)
	if not bool(report.get("ok", false)):
		if clicked_tile != null:
			clicked_tile.play_click_feedback(false)
		_game.note_invalid_click()
		_sync_board_visuals()
		emit_signal("state_changed")
		return
	if clicked_tile != null:
		clicked_tile.play_click_feedback(true)
	_resolve_visual_report(report)


func _resolve_visual_report(report: Dictionary) -> void:
	_resolving_turn = true
	_sync_board_visuals(false)
	await _animate_reveals(report.get("reveals", []))
	await _animate_player_moves(report.get("moves", []))
	_sync_board_visuals()
	_resolving_turn = false
	emit_signal("state_changed")


func get_hud_state() -> Dictionary:
	if _game == null:
		return {}
	var hud: Dictionary = _game.get_hud_state()
	hud["hover_card"] = get_hovered_tile_details()
	hud["action_items"] = _get_action_items()
	hud["upgrade_items"] = get_upgrade_offer_data()
	return hud


func get_hovered_tile_details() -> Dictionary:
	if _game == null or not is_instance_valid(_hovered_tile):
		return {}
	var cell = _game.get_cell(_hovered_tile.grid_position)
	if cell == null:
		return {}

	var is_known: bool = not cell.hidden or cell.previewed
	var role_definition = _game.get_role_definition(cell.role_id) if is_known else null
	var title := "Hidden Tile"
	var description := "Flip this tile to reveal who is here."
	var icon_id := "guide"
	var accent_color := Color8(171, 152, 130)
	if role_definition != null:
		title = String(role_definition.display_name)
		description = String(role_definition.description)
		icon_id = String(role_definition.icon_id)
		accent_color = role_definition.accent_color
	elif cell.previewed:
		title = _game.get_role_name(cell.role_id)
		description = "Peek revealed this role."
		icon_id = String(cell.role_id)
		var preview_role = _game.get_role_definition(cell.role_id)
		if preview_role != null:
			accent_color = preview_role.accent_color

	var state_label := "Hidden"
	if cell.previewed and cell.hidden:
		state_label = "Peeked"
	elif not cell.hidden:
		state_label = "Revealed"

	return {
		"grid_position": cell.grid_position,
		"title": title,
		"description": description,
		"state_label": state_label,
		"icon_id": icon_id,
		"accent_color": accent_color,
		"show_front": is_known,
		"is_hidden": cell.hidden,
		"is_previewed": cell.previewed,
		"is_target": _selected_targets.has(cell.grid_position),
		"is_selected_target": _game.selected_action_id != "flip" and _selected_targets.has(cell.grid_position),
		"detail_line": "TRACE %s" % [cell.grid_position],
	}


func get_action_buttons() -> Array:
	return _game.get_action_buttons() if _game != null else []


func get_upgrade_offer_data() -> Array:
	return _game.get_upgrade_offer_data() if _game != null else []


func get_legal_flip_positions() -> Array[Vector2i]:
	return _game.get_legal_flip_positions() if _game != null else []


func fit_camera(camera: Camera3D, viewport_size: Vector2) -> void:
	if camera == null:
		return

	var safe_size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var board_width := maxf((grid_width - 1) * tile_spacing + tile_size, tile_size)
	var board_height := maxf((grid_height - 1) * tile_spacing + tile_size, tile_size)
	var aspect_ratio := safe_size.x / safe_size.y
	var required_height := board_height + camera_padding
	var required_width_as_height := (board_width + camera_padding) / maxf(aspect_ratio, 0.001)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(required_height, required_width_as_height)
	camera.position = Vector3(0.0, 8.4, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.BACK)


func _rebuild_tiles() -> void:
	if is_instance_valid(_hovered_tile):
		_hovered_tile.set_hovered(false)
	_hovered_tile = null
	emit_signal("hovered_tile_changed")
	for child in _tiles_root.get_children():
		_tiles_root.remove_child(child)
		child.queue_free()
	_tiles_by_pos.clear()

	var offset_x := -((grid_width - 1) * tile_spacing) * 0.5
	var offset_z := -((grid_height - 1) * tile_spacing) * 0.5
	var center: Vector2i = _game.get_center_position()
	for row in range(grid_height):
		for column in range(grid_width):
			var grid_pos := Vector2i(column, row)
			if grid_pos == center:
				continue
			var tile = tile_scene.instantiate()
			tile.grid_position = grid_pos
			tile.tile_width = tile_size
			tile.tile_depth = tile_size
			tile.position = Vector3(offset_x + column * tile_spacing, 0.18, offset_z + row * tile_spacing)
			_tiles_root.add_child(tile)
			_tiles_by_pos[grid_pos] = tile

	_update_board_base()
	_update_player_marker_position(true)


func _sync_board_visuals(update_player_marker: bool = true) -> void:
	if _game == null:
		return
	_selected_targets = _game.get_valid_targets_for_action(_game.selected_action_id)
	var preview_lookup := {}
	for preview in _game.get_preview_intents():
		var from_pos: Vector2i = preview.get("from", Vector2i.ZERO)
		if not preview_lookup.has(from_pos):
			preview_lookup[from_pos] = []
		preview_lookup[from_pos].append(preview)
	for pos in _tiles_by_pos.keys():
		var tile = _tiles_by_pos[pos]
		var cell = _game.get_cell(pos)
		if cell == null:
			continue
		var role_definition = _game.get_role_definition(cell.role_id)
		var icon_id: String = role_definition.icon_id if role_definition != null else "guide"
		var is_target := _selected_targets.has(pos)
		var is_selected_target: bool = _game.selected_action_id != "flip" and is_target
		var selection_state := "idle"
		if is_selected_target:
			selection_state = "selected"
		elif is_target:
			selection_state = "target"
		elif cell.previewed:
			selection_state = "previewed"
		tile.set_visual_state({
			"grid_position": pos,
			"icon_id": icon_id,
			"is_flipped": not cell.hidden,
			"is_target": is_target,
			"is_previewed": cell.previewed,
			"is_selected_target": is_selected_target,
			"is_edge": _is_edge(pos),
			"surface_variant": int(abs(pos.x * 13 + pos.y * 7)) % 4,
			"selection_state": selection_state,
			"overlay_glyphs": [icon_id] if not cell.hidden else [],
			"flow_preview": preview_lookup.get(pos, []),
			"is_player_tile_adjacent": _game.player.position.distance_to(pos) == 1,
		})
	_update_preview_markers()
	if update_player_marker:
		_update_player_marker_position(true)


func _get_action_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = [{
		"id": "flip",
		"label": "REVEAL",
		"selected": _game.selected_action_id == "flip",
		"enabled": true,
		"icon_id": "flip",
		"accent_color": Color8(227, 189, 120),
	}]
	for item in _game.get_action_buttons():
		items.append(item)
	items.append({
		"id": "reset",
		"label": "RESET RUN",
		"selected": false,
		"enabled": true,
		"icon_id": "reset",
		"accent_color": Color8(230, 80, 68),
		"danger": true,
	})
	return items


func _animate_reveals(reveals: Array) -> void:
	for reveal in reveals:
		var pos: Vector2i = reveal.get("position", Vector2i.ZERO)
		var tile = _tiles_by_pos.get(pos)
		if tile == null:
			continue
		var role_definition = _game.get_role_definition(String(reveal.get("role_id", "")))
		if role_definition == null:
			continue
		tile.play_reveal(role_definition.icon_id)
		if tile.is_animating:
			await tile.flipped
		else:
			await get_tree().create_timer(0.02).timeout


func _animate_player_moves(moves: Array) -> void:
	for move in moves:
		var to_pos: Vector2i = move.get("to", _game.player.position)
		if is_instance_valid(_player_move_tween):
			_player_move_tween.kill()
		_player_move_tween = create_tween()
		_player_move_tween.set_trans(Tween.TRANS_QUAD)
		_player_move_tween.set_ease(Tween.EASE_OUT)
		_player_move_tween.tween_property(_player_marker(), "position", _grid_to_world(to_pos, _player_base_y), 0.16)
		await _player_move_tween.finished
		await get_tree().create_timer(0.05).timeout


func _ensure_helper_nodes() -> void:
	if get_node_or_null("PlayerMarker") == null:
		var marker := MeshInstance3D.new()
		marker.name = "PlayerMarker"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.86, 0.96)
		marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color.WHITE
		material.albedo_texture = _painter.make_player_token_texture(256)
		marker.set_surface_override_material(0, material)
		marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(marker)
	if get_node_or_null("PreviewRoot") == null:
		var preview_root := Node3D.new()
		preview_root.name = "PreviewRoot"
		add_child(preview_root)


func _player_marker() -> MeshInstance3D:
	return $PlayerMarker


func _preview_root() -> Node3D:
	return $PreviewRoot


func _update_player_marker_position(immediate: bool = false) -> void:
	if _game == null:
		return
	var next_position := _grid_to_world(_game.player.position, _player_base_y)
	if immediate:
		_player_marker().position = next_position
		return
	if is_instance_valid(_player_move_tween):
		_player_move_tween.kill()
	_player_move_tween = create_tween()
	_player_move_tween.tween_property(_player_marker(), "position", next_position, 0.12)


func _update_preview_markers() -> void:
	for marker in _preview_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_preview_markers.clear()
	for preview in _game.get_preview_intents():
		var from_pos: Vector2i = preview.get("from", Vector2i.ZERO)
		var to_pos: Vector2i = preview.get("to", Vector2i.ZERO)
		if not _game.is_in_bounds(to_pos):
			continue
		var marker := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.70, 0.20)
		marker.mesh = mesh
		var material := StandardMaterial3D.new()
		var is_push := String(preview.get("kind", "")) == "push"
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color.WHITE
		material.albedo_texture = _painter.make_icon_texture(
			"pusher" if is_push else "puller",
			96,
			_theme_manifest.get_color("danger") if is_push else _theme_manifest.get_color("highlight")
		)
		marker.set_surface_override_material(0, material)
		var midpoint := (_grid_to_world(from_pos, 0.42) + _grid_to_world(to_pos, 0.42)) * 0.5
		marker.position = midpoint
		var direction := (_grid_to_world(to_pos, 0.42) - _grid_to_world(from_pos, 0.42)).normalized()
		marker.look_at(midpoint + direction, Vector3.UP)
		marker.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90.0))
		_preview_root().add_child(marker)
		_preview_markers.append(marker)


func _update_board_base() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		maxf(grid_width * tile_spacing, tile_size) + board_margin,
		0.18,
		maxf(grid_height * tile_spacing, tile_size) + board_margin
	)
	_board_base.mesh = mesh
	_board_base.position = Vector3(0.0, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = _theme_manifest.get_color("board")
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.emission_enabled = true
	material.emission = _theme_manifest.get_color("ink_soft")
	material.emission_energy_multiplier = 0.04
	_board_base.set_surface_override_material(0, material)


func _pick_tile(screen_pos: Vector2):
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var board_point: Variant = _screen_to_board_point(camera, screen_pos)
	if board_point == null:
		return null

	for tile in _tiles_by_pos.values():
		var half_width: float = tile.tile_width * 0.5
		var half_depth: float = tile.tile_depth * 0.5
		if abs(board_point.x - tile.position.x) <= half_width and abs(board_point.z - tile.position.z) <= half_depth:
			return tile
	return null


func _screen_to_board_point(camera: Camera3D, screen_pos: Vector2):
	if _tiles_by_pos.is_empty():
		return null
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)
	if is_zero_approx(ray_normal.y):
		return null
	var plane_y: float = 0.18
	var travel: float = (plane_y - ray_origin.y) / ray_normal.y
	if travel < 0.0:
		return null
	return ray_origin + ray_normal * travel


func _grid_to_world(grid_pos: Vector2i, y: float) -> Vector3:
	var offset_x := -((grid_width - 1) * tile_spacing) * 0.5
	var offset_z := -((grid_height - 1) * tile_spacing) * 0.5
	return Vector3(offset_x + grid_pos.x * tile_spacing, y, offset_z + grid_pos.y * tile_spacing)


func _is_edge(pos: Vector2i) -> bool:
	return pos.x == 0 or pos.y == 0 or pos.x == grid_width - 1 or pos.y == grid_height - 1
