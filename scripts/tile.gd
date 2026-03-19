class_name Tile
extends StaticBody3D

signal flipped(tile: Tile)

const IconLibraryRef = preload("res://scripts/icon_library.gd")

@export_range(0.05, 1.2, 0.01) var flip_duration: float = 0.3
@export_range(0.02, 1.0, 0.01) var flip_squash_depth: float = 0.08
@export var hover_enabled: bool = true
@export_range(0.0, 0.4, 0.01) var hover_lift_height: float = 0.12
@export_range(1.0, 1.3, 0.01) var hover_scale_multiplier: float = 1.08
@export_range(1.0, 1.3, 0.01) var hover_face_scale_multiplier: float = 1.12
@export var tile_width: float = 1.0
@export var tile_depth: float = 1.0
@export var tile_height: float = 0.24
@export var face_texture_size: int = 32
@export var flip_lift_height: float = 0.32

var grid_position: Vector2i = Vector2i.ZERO
var icon_id: String = "guide"
var is_flipped: bool = false
var is_animating: bool = false

var _hovered: bool = false
var _visual_state: Dictionary = {}
var _flip_tween: Tween
var _feedback_tween: Tween
var _base_material: StandardMaterial3D
var _back_material: StandardMaterial3D
var _front_material: StandardMaterial3D
var _icon_library = IconLibraryRef.new()
var _feedback_color: Color = Color(0, 0, 0, 0)
var _feedback_strength: float = 0.0

@onready var _visual_root: Node3D = $VisualRoot
@onready var _body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var _back_face: MeshInstance3D = $VisualRoot/BackFace
@onready var _front_face: MeshInstance3D = $VisualRoot/FrontFace
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_build_geometry()
	_create_materials()
	_update_materials()
	_apply_face_visibility()


func set_visual_state(state: Dictionary) -> void:
	_visual_state = state.duplicate(true)
	grid_position = state.get("grid_position", grid_position)
	icon_id = String(state.get("icon_id", icon_id))
	is_flipped = bool(state.get("is_flipped", is_flipped))
	_update_materials()
	_apply_face_visibility()


func set_hovered(value: bool) -> void:
	var next_hover := value and hover_enabled and not is_animating
	if _hovered == next_hover:
		return
	_hovered = next_hover
	_apply_hover_transform()
	_update_materials()


func play_reveal(next_icon_id: String) -> void:
	icon_id = next_icon_id
	if is_flipped or is_animating:
		_update_materials()
		return
	flip_to_front()


func play_click_feedback(is_valid: bool) -> void:
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	_visual_root.position = Vector3(0.0, 0.0, 0.0)
	_visual_root.scale = Vector3.ONE
	_feedback_tween = create_tween()
	if is_valid:
		_feedback_color = Color8(255, 245, 180)
		_feedback_strength = 0.95
		_feedback_tween.set_trans(Tween.TRANS_BACK)
		_feedback_tween.set_ease(Tween.EASE_OUT)
		_feedback_tween.parallel().tween_property(_visual_root, "position:y", 0.15, 0.07)
		_feedback_tween.parallel().tween_property(_visual_root, "scale", Vector3(1.06, 1.0, 1.06), 0.07)
		_feedback_tween.tween_property(self, "_feedback_strength", 0.0, 0.2)
	else:
		_feedback_color = Color8(255, 106, 106)
		_feedback_strength = 0.9
		_feedback_tween.set_trans(Tween.TRANS_SINE)
		_feedback_tween.set_ease(Tween.EASE_OUT)
		_feedback_tween.tween_property(_visual_root, "position:x", 0.09, 0.04)
		_feedback_tween.tween_property(_visual_root, "position:x", -0.09, 0.06)
		_feedback_tween.tween_property(_visual_root, "position:x", 0.05, 0.04)
		_feedback_tween.tween_property(_visual_root, "position:x", 0.0, 0.05)
		_feedback_tween.parallel().tween_property(self, "_feedback_strength", 0.0, 0.24)
	_feedback_tween.finished.connect(_finish_feedback, CONNECT_ONE_SHOT)
	_update_materials()


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
	_flip_tween.parallel().tween_property(_visual_root, "scale", Vector3(1.08, 1.0, flip_squash_depth), flip_duration * 0.5)
	_flip_tween.tween_property(self, "rotation_degrees:x", 90.0, flip_duration * 0.5)
	_flip_tween.tween_callback(_swap_visible_face)
	_flip_tween.set_trans(Tween.TRANS_BACK)
	_flip_tween.set_ease(Tween.EASE_OUT)
	_flip_tween.parallel().tween_property(_visual_root, "position:y", 0.0, flip_duration * 0.5)
	_flip_tween.parallel().tween_property(_visual_root, "scale", Vector3.ONE, flip_duration * 0.5)
	_flip_tween.tween_property(self, "rotation_degrees:x", 180.0, flip_duration * 0.5)
	_flip_tween.finished.connect(_finish_flip, CONNECT_ONE_SHOT)


func _finish_flip() -> void:
	is_animating = false
	is_flipped = true
	_visual_root.position.y = 0.0
	_visual_root.scale = Vector3.ONE
	_apply_face_visibility()
	emit_signal("flipped", self)


func _finish_feedback() -> void:
	if not _hovered:
		_visual_root.position = Vector3.ZERO
		_visual_root.scale = Vector3.ONE
	else:
		_apply_hover_transform()
	_feedback_strength = 0.0
	_update_materials()


func _swap_visible_face() -> void:
	_back_face.visible = false
	_front_face.visible = true


func _apply_hover_transform() -> void:
	_visual_root.position.y = hover_lift_height if _hovered else 0.0
	_visual_root.scale = Vector3.ONE * (hover_scale_multiplier if _hovered else 1.0)
	var face_scale := hover_face_scale_multiplier if _hovered else 1.0
	_back_face.scale = Vector3.ONE * face_scale
	_front_face.scale = Vector3.ONE * face_scale


func _build_geometry() -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(tile_width, tile_height, tile_depth)
	_body_mesh.mesh = box_mesh

	var face_mesh := QuadMesh.new()
	face_mesh.size = Vector2(tile_width * 0.86, tile_depth * 0.86)
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
	_base_material.roughness = 0.92
	_base_material.metallic = 0.03
	_base_material.emission_enabled = true
	_base_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_back_material = StandardMaterial3D.new()
	_back_material.roughness = 1.0
	_back_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_back_material.emission_enabled = true
	_back_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_front_material = StandardMaterial3D.new()
	_front_material.roughness = 1.0
	_front_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_front_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_front_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_front_material.emission_enabled = true
	_front_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_body_mesh.set_surface_override_material(0, _base_material)
	_back_face.set_surface_override_material(0, _back_material)
	_front_face.set_surface_override_material(0, _front_material)


func _update_materials() -> void:
	if _base_material == null:
		return

	var is_edge := bool(_visual_state.get("is_edge", false))
	var is_target := bool(_visual_state.get("is_target", false))
	var is_previewed := bool(_visual_state.get("is_previewed", false))
	var is_selected_target := bool(_visual_state.get("is_selected_target", false))
	var base_color := Color8(74, 64, 55) if not is_flipped else Color8(150, 124, 90)
	if is_edge:
		base_color = Color8(171, 137, 82)
	if is_target:
		base_color = Color8(176, 96, 70)
	if is_previewed:
		base_color = Color8(174, 144, 92)
	if is_selected_target:
		base_color = Color8(228, 165, 80)
	if is_target and not is_flipped:
		base_color = base_color.lightened(0.08)
	if _hovered:
		base_color = base_color.lightened(0.18)
	if _feedback_strength > 0.0:
		base_color = base_color.lerp(_feedback_color, _feedback_strength)

	_base_material.albedo_color = base_color
	_base_material.emission = base_color.lightened(0.1)
	_base_material.emission_energy_multiplier = 0.08 if not _hovered else 0.18
	_back_material.albedo_color = Color.WHITE
	_front_material.albedo_color = Color.WHITE
	_back_material.emission = Color8(255, 232, 192) if _hovered else Color8(0, 0, 0, 0)
	_front_material.emission = Color8(255, 232, 192) if _hovered else Color8(0, 0, 0, 0)
	_back_material.emission_energy_multiplier = 0.2 if _hovered else 0.0
	_front_material.emission_energy_multiplier = 0.2 if _hovered else 0.0
	_back_material.albedo_texture = _icon_library.make_face_texture(icon_id, false, _hovered, face_texture_size)
	_front_material.albedo_texture = _icon_library.make_face_texture(icon_id, true, _hovered, face_texture_size)


func _apply_face_visibility() -> void:
	rotation_degrees.x = 180.0 if is_flipped else 0.0
	_back_face.visible = not is_flipped
	_front_face.visible = is_flipped
