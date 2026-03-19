extends Control

const TARGET_INTERNAL_HEIGHT := 270.0

var _depth_label: Label
var _score_label: Label
var _hint_label: Label
var _action_bar: HBoxContainer
var _upgrade_overlay: PanelContainer
var _upgrade_title: Label
var _upgrade_buttons: Array[Button] = []

@onready var _game_viewport: SubViewport = $GameViewport
@onready var _pixel_display: TextureRect = $UI/PixelDisplay
@onready var _board = $GameViewport/World/Board
@onready var _camera: Camera3D = $GameViewport/World/Camera3D
@onready var _ui_root: Control = $UI


func _ready() -> void:
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pixel_display.texture = _game_viewport.get_texture()
	_pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixel_display.mouse_filter = Control.MOUSE_FILTER_STOP
	_pixel_display.gui_input.connect(_on_pixel_display_gui_input)
	get_viewport().size_changed.connect(_resize_display)
	_build_overlay()
	_board.state_changed.connect(_refresh_overlay)
	_resize_display()
	_refresh_overlay()


func _process(_delta: float) -> void:
	var pointer := _get_pointer_data()
	_board.update_hover(pointer.position, pointer.inside)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_board.reset_board()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_board.set_selected_action("flip")
			get_viewport().set_input_as_handled()


func _on_pixel_display_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var local_position: Vector2 = event.position
	var mapped_position := _display_to_viewport_pos(local_position)
	_board.click_tile(mapped_position)
	accept_event()


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


func _build_overlay() -> void:
	var hud_margin := MarginContainer.new()
	hud_margin.name = "HudMargin"
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_margin.add_theme_constant_override("margin_left", 18)
	hud_margin.add_theme_constant_override("margin_top", 18)
	hud_margin.add_theme_constant_override("margin_right", 18)
	hud_margin.add_theme_constant_override("margin_bottom", 18)
	hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(hud_margin)

	var hud_box := VBoxContainer.new()
	hud_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_margin.add_child(hud_box)

	_depth_label = _make_label("")
	_score_label = _make_label("")
	_hint_label = _make_label("Click an adjacent hidden tile to flip it.")
	hud_box.add_child(_depth_label)
	hud_box.add_child(_score_label)
	hud_box.add_child(_hint_label)

	_action_bar = HBoxContainer.new()
	_action_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.anchor_left = 0.5
	_action_bar.anchor_right = 0.5
	_action_bar.anchor_top = 1.0
	_action_bar.anchor_bottom = 1.0
	_action_bar.offset_left = -320
	_action_bar.offset_right = 320
	_action_bar.offset_top = -68
	_action_bar.offset_bottom = -20
	_ui_root.add_child(_action_bar)

	_upgrade_overlay = PanelContainer.new()
	_upgrade_overlay.visible = false
	_upgrade_overlay.custom_minimum_size = Vector2(420, 220)
	_upgrade_overlay.anchor_left = 0.5
	_upgrade_overlay.anchor_right = 0.5
	_upgrade_overlay.anchor_top = 0.5
	_upgrade_overlay.anchor_bottom = 0.5
	_upgrade_overlay.offset_left = -210
	_upgrade_overlay.offset_right = 210
	_upgrade_overlay.offset_top = -120
	_upgrade_overlay.offset_bottom = 120
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_upgrade_overlay)

	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	_upgrade_overlay.add_child(overlay_box)

	_upgrade_title = _make_label("Choose an upgrade")
	overlay_box.add_child(_upgrade_title)
	for _index in range(3):
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(360, 44)
		button.pressed.connect(_on_upgrade_pressed.bind(button))
		overlay_box.add_child(button)
		_upgrade_buttons.append(button)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_overlay() -> void:
	var hud: Dictionary = _board.get_hud_state()
	_depth_label.text = "Board %d" % int(hud.get("depth", 1))
	_score_label.text = "Escapes: %d" % int(hud.get("score", 0))
	var phase_label := String(hud.get("phase", "Flip"))
	var status_text := String(hud.get("status", ""))
	if _board.get_upgrade_offer_data().is_empty():
		_hint_label.text = status_text if not status_text.is_empty() else "Click a glowing adjacent hidden tile."
		if phase_label == "Loss":
			_hint_label.text = String(hud.get("failure_reason", "Press R to restart."))
	else:
		_hint_label.text = "Choose one upgrade to continue."

	_refresh_action_buttons()
	_refresh_upgrade_overlay()


func _refresh_action_buttons() -> void:
	_action_bar.visible = false
	for child in _action_bar.get_children():
		child.queue_free()
	var action_buttons: Array = _board.get_action_buttons()
	if action_buttons.is_empty():
		return
	_action_bar.visible = true
	for button_data in action_buttons:
		var button := Button.new()
		button.text = String(button_data.get("label", "Action"))
		button.disabled = not bool(button_data.get("enabled", true))
		if bool(button_data.get("selected", false)):
			button.modulate = Color8(255, 228, 175)
		button.pressed.connect(_on_action_pressed.bind(String(button_data.get("id", "flip"))))
		_action_bar.add_child(button)


func _refresh_upgrade_overlay() -> void:
	var offers: Array[Dictionary] = _board.get_upgrade_offer_data()
	_upgrade_overlay.visible = not offers.is_empty()
	if offers.is_empty():
		return
	_upgrade_title.text = "Choose an upgrade for the next board"
	for index in range(_upgrade_buttons.size()):
		var button := _upgrade_buttons[index]
		if index >= offers.size():
			button.visible = false
			continue
		var offer: Dictionary = offers[index]
		button.visible = true
		button.text = "%s\n%s" % [offer.get("name", ""), offer.get("description", "")]
		button.set_meta("upgrade_id", offer.get("id", ""))


func _on_action_pressed(action_id: String) -> void:
	_board.set_selected_action(action_id)


func _on_upgrade_pressed(button: Button) -> void:
	var upgrade_id := String(button.get_meta("upgrade_id", ""))
	if upgrade_id.is_empty():
		return
	_board.choose_upgrade(upgrade_id)


func _get_pointer_data() -> Dictionary:
	var display_rect := Rect2(_pixel_display.global_position, _pixel_display.size)
	var mouse_position := get_global_mouse_position()
	if not display_rect.has_point(mouse_position):
		return {
			"inside": false,
			"position": Vector2.ZERO,
		}

	return {
		"inside": true,
		"position": _display_to_viewport_pos(mouse_position - display_rect.position),
	}


func _display_to_viewport_pos(local_position: Vector2) -> Vector2:
	var mapped_position := local_position
	mapped_position.x *= _game_viewport.size.x / maxf(_pixel_display.size.x, 1.0)
	mapped_position.y *= _game_viewport.size.y / maxf(_pixel_display.size.y, 1.0)
	mapped_position.x = clampf(mapped_position.x, 0.0, _game_viewport.size.x - 1.0)
	mapped_position.y = clampf(mapped_position.y, 0.0, _game_viewport.size.y - 1.0)
	return mapped_position
