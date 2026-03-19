extends Control

const TARGET_INTERNAL_HEIGHT := 270.0

@onready var _game_viewport: SubViewport = $GameViewport
@onready var _pixel_display: TextureRect = $UI/PixelDisplay
@onready var _board = $GameViewport/World/Board
@onready var _camera: Camera3D = $GameViewport/World/Camera3D


func _ready() -> void:
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_pixel_display.texture = _game_viewport.get_texture()
	_pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	get_viewport().size_changed.connect(_resize_display)
	_resize_display()


func _process(_delta: float) -> void:
	var pointer := _get_pointer_data()
	_board.update_hover(pointer.position, pointer.inside)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer := _get_pointer_data()
		if pointer.inside:
			_board.click_tile(pointer.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_board.reset_board()
		get_viewport().set_input_as_handled()


func _resize_display() -> void:
	var window_size := get_viewport_rect().size
	var render_scale := maxf(window_size.y / TARGET_INTERNAL_HEIGHT, 1.0)
	var viewport_size := Vector2i(
		maxi(1, int(round(window_size.x / render_scale))),
		maxi(1, int(round(window_size.y / render_scale)))
	)
	_game_viewport.size = viewport_size

	var filter_material := _pixel_display.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("source_size", Vector2(viewport_size))
		filter_material.set_shader_parameter("display_scale", render_scale)

	_board.fit_camera(_camera, window_size)


func _get_pointer_data() -> Dictionary:
	var display_rect := Rect2(_pixel_display.global_position, _pixel_display.size)
	var mouse_position := get_global_mouse_position()
	if not display_rect.has_point(mouse_position):
		return {
			"inside": false,
			"position": Vector2.ZERO,
		}

	var local_position := mouse_position - display_rect.position
	local_position.x *= _game_viewport.size.x / maxf(display_rect.size.x, 1.0)
	local_position.y *= _game_viewport.size.y / maxf(display_rect.size.y, 1.0)
	local_position.x = clampf(local_position.x, 0.0, _game_viewport.size.x - 1.0)
	local_position.y = clampf(local_position.y, 0.0, _game_viewport.size.y - 1.0)
	return {
		"inside": true,
		"position": local_position,
	}
