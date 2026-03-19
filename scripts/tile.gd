class_name Tile
extends StaticBody3D

signal flipped(tile: Tile, icon_id: String)

const IconLibraryRef = preload("res://scripts/icon_library.gd")

@export var icon_id: String = "sun":
	set(value):
		icon_id = value
		_update_face_texture()

@export var is_flipped: bool = false:
	set(value):
		is_flipped = value
		if is_node_ready():
			_apply_face_visibility()

@export_range(0.05, 1.2, 0.01) var flip_duration: float = 0.34
@export var hover_enabled: bool = true
@export var tile_width: float = 1.0
@export var tile_depth: float = 1.0
@export var tile_height: float = 0.24
@export var face_texture_size: int = 18
@export var flip_lift_height: float = 0.32
@export_range(0.02, 1.0, 0.01) var flip_squash_depth: float = 0.08

var is_animating: bool = false

var _tile_data
var _flip_tween: Tween
var _base_material: StandardMaterial3D
var _back_material: StandardMaterial3D
var _front_material: StandardMaterial3D
var _hovered: bool = false
var _icon_library = IconLibraryRef.new()

@onready var _visual_root: Node3D = $VisualRoot
@onready var _body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var _back_face: MeshInstance3D = $VisualRoot/BackFace
@onready var _front_face: MeshInstance3D = $VisualRoot/FrontFace
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_build_geometry()
	_create_materials()
	_update_face_texture()
	_apply_face_visibility()


func set_tile_data(data) -> void:
	_tile_data = data
	icon_id = data.icon_id
	is_flipped = data.is_flipped


func set_face(value: String) -> void:
	icon_id = value


func set_hovered(value: bool) -> void:
	var next_hover := value and hover_enabled and not is_animating and not is_flipped
	if _hovered == next_hover:
		return

	_hovered = next_hover
	_visual_root.position.y = 0.08 if _hovered else 0.0
	_visual_root.scale = Vector3.ONE * (1.04 if _hovered else 1.0)
	_update_face_texture()
	_sync_material_tint()


func flip_to_front() -> void:
	if is_flipped or is_animating:
		return

	is_animating = true
	set_hovered(false)

	if is_instance_valid(_flip_tween):
		_flip_tween.kill()

	_back_face.visible = true
	_front_face.visible = false

	_flip_tween = create_tween()
	_flip_tween.set_trans(Tween.TRANS_CUBIC)
	_flip_tween.set_ease(Tween.EASE_OUT)
	_flip_tween.parallel().tween_property(_visual_root, "position:y", flip_lift_height, flip_duration * 0.5)
	_flip_tween.parallel().tween_property(_visual_root, "scale", Vector3(1.1, 1.0, flip_squash_depth), flip_duration * 0.5)
	_flip_tween.tween_property(self, "rotation_degrees:x", 90.0, flip_duration * 0.5)
	_flip_tween.tween_callback(_swap_visible_face)
	_flip_tween.set_trans(Tween.TRANS_BACK)
	_flip_tween.set_ease(Tween.EASE_OUT)
	_flip_tween.parallel().tween_property(_visual_root, "position:y", 0.0, flip_duration * 0.5)
	_flip_tween.parallel().tween_property(_visual_root, "scale", Vector3.ONE, flip_duration * 0.5)
	_flip_tween.tween_property(self, "rotation_degrees:x", 180.0, flip_duration * 0.5)
	_flip_tween.finished.connect(_finish_flip, CONNECT_ONE_SHOT)


func _swap_visible_face() -> void:
	_back_face.visible = false
	_front_face.visible = true


func _finish_flip() -> void:
	is_animating = false
	_visual_root.position.y = 0.0
	_visual_root.scale = Vector3.ONE
	is_flipped = true
	if _tile_data != null:
		_tile_data.is_flipped = true
	emit_signal("flipped", self, icon_id)


func _build_geometry() -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(tile_width, tile_height, tile_depth)
	_body_mesh.mesh = box_mesh

	var face_mesh := QuadMesh.new()
	face_mesh.size = Vector2(tile_width * 0.78, tile_depth * 0.78)

	_back_face.mesh = face_mesh
	_back_face.rotation.x = -PI / 2.0
	_back_face.position = Vector3(0.0, tile_height * 0.5 + 0.003, 0.0)

	_front_face.mesh = face_mesh.duplicate()
	_front_face.rotation.x = PI / 2.0
	_front_face.position = Vector3(0.0, -tile_height * 0.5 - 0.003, 0.0)

	var collision_box := BoxShape3D.new()
	collision_box.size = Vector3(tile_width, tile_height, tile_depth)
	_collision_shape.shape = collision_box


func _create_materials() -> void:
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = Color8(55, 65, 82)
	_base_material.roughness = 0.88
	_base_material.metallic = 0.05

	_back_material = StandardMaterial3D.new()
	_back_material.albedo_color = Color8(218, 221, 214)
	_back_material.roughness = 1.0
	_back_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_back_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_front_material = StandardMaterial3D.new()
	_front_material.albedo_color = Color8(248, 244, 225)
	_front_material.roughness = 1.0
	_front_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_front_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_front_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_front_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_body_mesh.set_surface_override_material(0, _base_material)
	_back_face.set_surface_override_material(0, _back_material)
	_front_face.set_surface_override_material(0, _front_material)
	_sync_material_tint()


func _update_face_texture() -> void:
	if _front_material == null:
		return

	_front_material.albedo_texture = _icon_library.make_face_texture(icon_id, true, _hovered, face_texture_size)
	_back_material.albedo_texture = _icon_library.make_face_texture(icon_id, false, _hovered, face_texture_size)
	_sync_material_tint()


func _apply_face_visibility() -> void:
	rotation_degrees.x = 180.0 if is_flipped else 0.0
	_back_face.visible = not is_flipped
	_front_face.visible = is_flipped


func _sync_material_tint() -> void:
	if _base_material == null:
		return

	_base_material.albedo_color = Color8(88, 124, 168) if _hovered else Color8(55, 65, 82)
	_back_material.albedo_color = Color.WHITE
	_front_material.albedo_color = Color.WHITE
