extends Control

const TARGET_INTERNAL_HEIGHT := 360.0
const PixelFilterShaderRef = preload("res://shaders/pixel_filter.gdshader")

var _pixel_filter_enabled: bool = false

@onready var _game_viewport: SubViewport = $GameViewport
@onready var _board = $GameViewport/World/Board
@onready var _camera: Camera3D = $GameViewport/World/Camera3D
@onready var _shell = $UI/GameShell


func _ready() -> void:
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var pixel_display: TextureRect = _shell.get_pixel_display()
	pixel_display.texture = _game_viewport.get_texture()
	pixel_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pixel_display.position = Vector2.ZERO
	pixel_display.size = Vector2.ZERO
	pixel_display.material = ShaderMaterial.new()
	(pixel_display.material as ShaderMaterial).shader = PixelFilterShaderRef
	_bind_game_surface_input()
	get_viewport().size_changed.connect(_resize_display)
	_shell.get_board_host().resized.connect(_resize_display)
	_shell.action_requested.connect(_on_action_requested)
	_shell.upgrade_requested.connect(_on_upgrade_requested)
	_shell.reset_requested.connect(_on_reset_requested)
	_shell.pixel_filter_toggled.connect(_on_pixel_filter_toggled)
	_board.state_changed.connect(_refresh_shell)
	_board.hovered_tile_changed.connect(_refresh_hover_only)
	call_deferred("_resize_display")
	_shell.set_pixel_filter_enabled(_pixel_filter_enabled)
	_refresh_shell()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_board.reset_board()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			_on_action_requested("stay")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_board.set_selected_action("flip")
			get_viewport().set_input_as_handled()


func _on_action_requested(action_id: String) -> void:
	if action_id == "stay":
		_board.try_stay()
		return
	_board.set_selected_action(action_id)


func _on_upgrade_requested(upgrade_id: String) -> void:
	_board.choose_upgrade(upgrade_id)


func _on_reset_requested() -> void:
	_board.reset_board()


func _on_pixel_filter_toggled(enabled: bool) -> void:
	_pixel_filter_enabled = enabled
	_resize_display()


func _on_pixel_display_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		_board.update_hover(_display_to_viewport_pos(motion_event.position), true)
		return
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if not button_event.pressed or button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_board.click_tile(_display_to_viewport_pos(button_event.position))
		accept_event()


func _on_pixel_display_mouse_exited() -> void:
	_board.update_hover(Vector2.ZERO, false)


func _resize_display() -> void:
	var host_size: Vector2 = _shell.get_board_host().size
	if host_size.x <= 0.0 or host_size.y <= 0.0:
		return
	var render_scale := 1.0
	var viewport_size := Vector2i(
		maxi(1, int(round(host_size.x))),
		maxi(1, int(round(host_size.y)))
	)
	if _pixel_filter_enabled:
		var desired_scale := host_size.y / TARGET_INTERNAL_HEIGHT
		render_scale = maxf(round(desired_scale), 1.0)
		viewport_size = Vector2i(
			maxi(1, int(round(host_size.x / render_scale))),
			maxi(1, int(round(host_size.y / render_scale)))
		)
	_game_viewport.size = viewport_size

	var pixel_display: TextureRect = _shell.get_pixel_display()
	var filter_material := pixel_display.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("source_size", Vector2(viewport_size))
		filter_material.set_shader_parameter("display_scale", render_scale)
		filter_material.set_shader_parameter("filter_enabled", _pixel_filter_enabled)

	var fitted_display := _get_fitted_display_rect(host_size, Vector2(viewport_size))
	pixel_display.position = fitted_display.position
	pixel_display.size = fitted_display.size

	_board.fit_camera(_camera, host_size)


func _refresh_shell() -> void:
	_shell.update_state(_board.get_hud_state())


func _refresh_hover_only() -> void:
	_shell.update_hover_card(_board.get_hovered_tile_details())


func _display_to_viewport_pos(local_position: Vector2) -> Vector2:
	var pixel_display: TextureRect = _shell.get_pixel_display()
	var mapped_position := local_position
	mapped_position.x *= _game_viewport.size.x / maxf(pixel_display.size.x, 1.0)
	mapped_position.y *= _game_viewport.size.y / maxf(pixel_display.size.y, 1.0)
	mapped_position.x = clampf(mapped_position.x, 0.0, _game_viewport.size.x - 1.0)
	mapped_position.y = clampf(mapped_position.y, 0.0, _game_viewport.size.y - 1.0)
	return mapped_position


func _get_fitted_display_rect(host_size: Vector2, source_size: Vector2) -> Rect2:
	var safe_host := Vector2(maxf(host_size.x, 1.0), maxf(host_size.y, 1.0))
	var safe_source := Vector2(maxf(source_size.x, 1.0), maxf(source_size.y, 1.0))
	var scale: float = min(safe_host.x / safe_source.x, safe_host.y / safe_source.y)
	var fitted_size: Vector2 = safe_source * scale
	var fitted_pos: Vector2 = (safe_host - fitted_size) * 0.5
	return Rect2(fitted_pos, fitted_size)


func _bind_game_surface_input() -> void:
	var pixel_display: TextureRect = _shell.get_pixel_display()
	pixel_display.mouse_filter = Control.MOUSE_FILTER_STOP
	pixel_display.gui_input.connect(_on_pixel_display_gui_input)
	pixel_display.mouse_exited.connect(_on_pixel_display_mouse_exited)
