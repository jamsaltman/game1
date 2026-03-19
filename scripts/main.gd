extends Control

const BASE_RENDER_SIZE := Vector2i(480, 270)

@onready var _game_viewport: SubViewport = $GameViewport
@onready var _pixel_display: TextureRect = $UI/PixelCenter/PixelDisplay
@onready var _board = $GameViewport/World/Board

var _display_scale: int = 1


func _ready() -> void:
	_game_viewport.size = BASE_RENDER_SIZE
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_pixel_display.texture = _game_viewport.get_texture()
	_pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var filter_material := _pixel_display.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("source_size", Vector2(BASE_RENDER_SIZE))

	get_viewport().size_changed.connect(_resize_display)
	_resize_display()


func _process(_delta: float) -> void:
	var pointer := _get_pointer_data()
	_board.update_hover(pointer.position, pointer.inside)


func _unhandled_input(event: InputEvent) -> void:
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
	_display_scale = maxi(1, int(floor(min(window_size.x / float(BASE_RENDER_SIZE.x), window_size.y / float(BASE_RENDER_SIZE.y)))))
	var scaled_size := Vector2(BASE_RENDER_SIZE * _display_scale)
	_pixel_display.custom_minimum_size = scaled_size

	var filter_material := _pixel_display.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("display_scale", float(_display_scale))


func _get_pointer_data() -> Dictionary:
	var display_rect := Rect2(_pixel_display.global_position, _pixel_display.size)
	var mouse_position := get_global_mouse_position()
	if not display_rect.has_point(mouse_position):
		return {
			"inside": false,
			"position": Vector2.ZERO,
		}

	var local_position := (mouse_position - display_rect.position) / float(_display_scale)
	local_position.x = clampf(local_position.x, 0.0, BASE_RENDER_SIZE.x - 1.0)
	local_position.y = clampf(local_position.y, 0.0, BASE_RENDER_SIZE.y - 1.0)
	return {
		"inside": true,
		"position": local_position,
	}
