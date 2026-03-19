class_name Tile
extends StaticBody3D

signal flipped(tile: Tile)

const InkPainterRef = preload("res://scripts/ink_painter.gd")
const ThemeManifestRef = preload("res://themes/ink_theme_manifest.tres")

@export_range(0.05, 1.2, 0.01) var flip_duration: float = 0.34
@export_range(0.02, 1.0, 0.01) var flip_squash_depth: float = 0.18
@export var hover_enabled: bool = true
@export_range(0.0, 0.4, 0.01) var hover_lift_height: float = 0.10
@export_range(1.0, 1.3, 0.01) var hover_scale_multiplier: float = 1.04
@export_range(1.0, 1.3, 0.01) var hover_face_scale_multiplier: float = 1.05
@export var tile_width: float = 1.0
@export var tile_depth: float = 1.0
@export var tile_height: float = 0.08
@export var face_texture_size: int = 160
@export var flip_lift_height: float = 0.20

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
var _feedback_color: Color = Color(0, 0, 0, 0)
var _feedback_strength: float = 0.0
var _theme_manifest = ThemeManifestRef
var _painter = InkPainterRef.new(_theme_manifest)
var _card_variant: int = 0

@onready var _visual_root: Node3D = $VisualRoot
@onready var _body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var _back_face: MeshInstance3D = $VisualRoot/BackFace
@onready var _front_face: MeshInstance3D = $VisualRoot/FrontFace
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_build_geometry()
	_create_materials()
	_apply_card_pose()
	_update_materials()
	_apply_face_visibility()


func set_visual_state(state: Dictionary) -> void:
	_visual_state = state.duplicate(true)
	grid_position = state.get("grid_position", grid_position)
	icon_id = String(state.get("icon_id", icon_id))
	is_flipped = bool(state.get("is_flipped", is_flipped))
	_card_variant = int(state.get("surface_variant", _card_variant))
	_apply_card_pose()
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
		_feedback_color = _theme_manifest.get_color("highlight")
		_feedback_strength = 0.8
		_feedback_tween.set_trans(Tween.TRANS_BACK)
		_feedback_tween.set_ease(Tween.EASE_OUT)
		_feedback_tween.parallel().tween_property(_visual_root, "position:y", 0.12, 0.08)
		_feedback_tween.parallel().tween_property(_visual_root, "scale", Vector3(1.04, 1.0, 1.04), 0.08)
		_feedback_tween.tween_property(self, "_feedback_strength", 0.0, 0.18)
	else:
		_feedback_color = _theme_manifest.get_color("danger")
		_feedback_strength = 0.95
		_feedback_tween.set_trans(Tween.TRANS_SINE)
		_feedback_tween.set_ease(Tween.EASE_OUT)
		_feedback_tween.tween_property(_visual_root, "position:x", 0.06, 0.04)
		_feedback_tween.tween_property(_visual_root, "position:x", -0.06, 0.06)
		_feedback_tween.tween_property(_visual_root, "position:x", 0.03, 0.04)
		_feedback_tween.tween_property(_visual_root, "position:x", 0.0, 0.05)
		_feedback_tween.parallel().tween_property(self, "_feedback_strength", 0.0, 0.22)
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
	_flip_tween.parallel().tween_property(_visual_root, "scale", Vector3(1.03, 1.0, flip_squash_depth), flip_duration * 0.5)
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
	box_mesh.size = Vector3(tile_width * 0.94, tile_height, tile_depth * 0.94)
	_body_mesh.mesh = box_mesh

	var face_mesh := QuadMesh.new()
	face_mesh.size = Vector2(tile_width * 0.96, tile_depth * 0.96)
	_back_face.mesh = face_mesh
	_back_face.rotation = Vector3(-PI / 2.0, 0.0, PI)
	_back_face.position = Vector3(0.0, tile_height * 0.5 + 0.004, 0.0)

	_front_face.mesh = face_mesh.duplicate()
	_front_face.rotation = Vector3(PI / 2.0, 0.0, PI)
	_front_face.position = Vector3(0.0, -tile_height * 0.5 - 0.004, 0.0)

	var collision_box := BoxShape3D.new()
	collision_box.size = Vector3(tile_width, 0.2, tile_depth)
	_collision_shape.shape = collision_box


func _create_materials() -> void:
	_base_material = StandardMaterial3D.new()
	_base_material.roughness = 1.0
	_base_material.metallic = 0.0
	_base_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_base_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	_back_material = StandardMaterial3D.new()
	_back_material.roughness = 1.0
	_back_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_back_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	_front_material = StandardMaterial3D.new()
	_front_material.roughness = 1.0
	_front_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_front_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_front_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_front_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	_body_mesh.set_surface_override_material(0, _base_material)
	_back_face.set_surface_override_material(0, _back_material)
	_front_face.set_surface_override_material(0, _front_material)


func _update_materials() -> void:
	if _base_material == null:
		return
	var is_target := bool(_visual_state.get("is_target", false))
	var is_previewed := bool(_visual_state.get("is_previewed", false))
	var is_selected_target := bool(_visual_state.get("is_selected_target", false))
	var is_edge := bool(_visual_state.get("is_edge", false))
	var is_player_adjacent := bool(_visual_state.get("is_player_tile_adjacent", false))
	var accent := _theme_manifest.get_color(icon_id, _theme_manifest.get_color("paper_dark"))
	var base_color := _theme_manifest.get_color("paper_dark")
	if not is_flipped:
		base_color = _theme_manifest.get_color("board").lightened(0.08)
	if is_edge:
		base_color = base_color.lerp(_theme_manifest.get_color("highlight"), 0.10)
	if is_target:
		base_color = base_color.lerp(accent, 0.18)
	if is_previewed:
		base_color = base_color.lerp(_theme_manifest.get_color("preview"), 0.12)
	if is_selected_target:
		base_color = base_color.lerp(_theme_manifest.get_color("highlight"), 0.25)
	if is_player_adjacent:
		base_color = base_color.lightened(0.06)
	if _hovered:
		base_color = base_color.lightened(0.08)
	if _feedback_strength > 0.0:
		base_color = base_color.lerp(_feedback_color, _feedback_strength)
	_base_material.albedo_color = base_color
	_base_material.emission_enabled = true
	_base_material.emission = base_color.lightened(0.12)
	_base_material.emission_energy_multiplier = 0.05 if not _hovered else 0.12
	_back_material.albedo_color = Color.WHITE
	_front_material.albedo_color = Color.WHITE
	_back_material.albedo_texture = _painter.make_role_card_texture(icon_id, {
		"is_hidden": true,
		"is_previewed": is_previewed,
		"is_target": is_target,
		"is_selected_target": is_selected_target,
		"is_edge": is_edge,
		"is_hovered": _hovered,
		"is_player_tile_adjacent": is_player_adjacent,
	}, face_texture_size, _card_variant)
	_front_material.albedo_texture = _painter.make_role_card_texture(icon_id, {
		"is_hidden": false,
		"is_previewed": is_previewed,
		"is_target": is_target,
		"is_selected_target": is_selected_target,
		"is_edge": is_edge,
		"is_hovered": _hovered,
		"is_player_tile_adjacent": is_player_adjacent,
	}, face_texture_size, _card_variant)


func _apply_face_visibility() -> void:
	rotation_degrees.x = 180.0 if is_flipped else 0.0
	_back_face.visible = not is_flipped
	_front_face.visible = is_flipped


func _apply_card_pose() -> void:
	var yaw_variation := float((grid_position.x * 13 + grid_position.y * 7 + _card_variant * 5) % 7) - 3.0
	rotation_degrees.y = yaw_variation * 0.6
