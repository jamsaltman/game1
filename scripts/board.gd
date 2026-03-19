class_name Board
extends Node3D

const TileDataRef = preload("res://scripts/flip_tile_data.gd")

@export_range(2, 10, 1) var grid_width: int = 5
@export_range(2, 10, 1) var grid_height: int = 4
@export_range(1.0, 2.0, 0.01) var tile_spacing: float = 1.28
@export var tile_size: float = 1.0
@export var icon_pool: PackedStringArray = PackedStringArray([
	"sun",
	"leaf",
	"wave",
	"gem",
	"bolt",
	"moon",
])
@export var random_seed: int = 0
@export var tile_scene: PackedScene = preload("res://scenes/tile.tscn")

var _rng := RandomNumberGenerator.new()
var _tile_data: Array = []
var _tiles: Array = []
var _hovered_tile = null

@onready var _tiles_root: Node3D = $Tiles
@onready var _board_base: MeshInstance3D = $BoardBase


func _ready() -> void:
	reset_board()


func reset_board() -> void:
	_seed_rng()
	_clear_tiles()
	_tile_data.clear()
	_tiles.clear()

	var offset_x := -((grid_width - 1) * tile_spacing) * 0.5
	var offset_z := -((grid_height - 1) * tile_spacing) * 0.5

	for row in range(grid_height):
		for column in range(grid_width):
			var tile = tile_scene.instantiate()
			var icon_id := icon_pool[_rng.randi_range(0, icon_pool.size() - 1)]
			var tile_data = TileDataRef.new()
			tile_data.icon_id = icon_id
			tile_data.is_flipped = false

			tile.tile_width = tile_size
			tile.tile_depth = tile_size
			tile.position = Vector3(offset_x + column * tile_spacing, 0.18, offset_z + row * tile_spacing)
			tile.set_tile_data(tile_data)

			_tiles_root.add_child(tile)
			_tiles.append(tile)
			_tile_data.append(tile_data)

	_update_board_base()
	fit_camera(get_viewport().get_camera_3d(), get_viewport().size)


func update_hover(screen_pos: Vector2, active: bool) -> void:
	var next_tile = _pick_tile(screen_pos) if active else null

	if _hovered_tile == next_tile:
		return

	if is_instance_valid(_hovered_tile):
		_hovered_tile.set_hovered(false)

	_hovered_tile = next_tile

	if is_instance_valid(_hovered_tile):
		_hovered_tile.set_hovered(true)


func click_tile(screen_pos: Vector2) -> void:
	var tile = _pick_tile(screen_pos)
	if tile == null:
		return
	tile.flip_to_front()


func _pick_tile(screen_pos: Vector2):
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var board_point: Variant = _screen_to_board_point(camera, screen_pos)
	if board_point == null:
		return null

	for tile in _tiles:
		if not is_instance_valid(tile):
			continue

		var half_width: float = tile.tile_width * 0.5
		var half_depth: float = tile.tile_depth * 0.5
		if abs(board_point.x - tile.position.x) <= half_width and abs(board_point.z - tile.position.z) <= half_depth:
			return tile
	return null


func _seed_rng() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed


func _clear_tiles() -> void:
	if is_instance_valid(_hovered_tile):
		_hovered_tile.set_hovered(false)
	_hovered_tile = null

	for child in _tiles_root.get_children():
		_tiles_root.remove_child(child)
		child.queue_free()


func _update_board_base() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		maxf(grid_width * tile_spacing, tile_size) + 0.9,
		0.24,
		maxf(grid_height * tile_spacing, tile_size) + 0.9
	)
	_board_base.mesh = mesh
	_board_base.position = Vector3(0.0, 0.0, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(203, 176, 118)
	material.roughness = 0.94
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_board_base.set_surface_override_material(0, material)


func fit_camera(camera: Camera3D, viewport_size: Vector2) -> void:
	if camera == null:
		return

	var safe_size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var board_width := maxf((grid_width - 1) * tile_spacing + tile_size, tile_size)
	var board_height := maxf((grid_height - 1) * tile_spacing + tile_size, tile_size)
	var aspect_ratio := safe_size.x / safe_size.y
	var framing_padding := 1.2
	var required_height := board_height + framing_padding
	var required_width_as_height := (board_width + framing_padding) / maxf(aspect_ratio, 0.001)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(required_height, required_width_as_height)
	camera.position = Vector3(0.0, 8.4, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.BACK)


func _screen_to_board_point(camera: Camera3D, screen_pos: Vector2):
	if _tiles.is_empty():
		return null

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)
	if is_zero_approx(ray_normal.y):
		return null

	var plane_y: float = _tiles[0].position.y
	var travel: float = (plane_y - ray_origin.y) / ray_normal.y
	if travel < 0.0:
		return null

	return ray_origin + ray_normal * travel
