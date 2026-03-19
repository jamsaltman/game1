extends Control

const TARGET_INTERNAL_HEIGHT := 270.0
const IconLibraryRef = preload("res://scripts/icon_library.gd")
const LABEL_DARK := Color8(33, 27, 22)
const LABEL_LIGHT := Color8(244, 228, 198)
const LABEL_MUTED := Color8(198, 176, 146)
const PANEL_DARK := Color8(23, 21, 19)
const PANEL_INNER := Color8(36, 32, 28)
const PANEL_PAPER := Color8(230, 212, 181)
const PANEL_BORDER := Color8(122, 95, 67)
const ACCENT_GOLD := Color8(224, 171, 87)
const ACCENT_RED := Color8(227, 95, 66)
const ACCENT_SOFT := Color8(155, 124, 88)
const LEGEND_ROLES := [
	{"id": "pusher", "name": "Pusher"},
	{"id": "puller", "name": "Puller"},
	{"id": "blocker", "name": "Blocker"},
	{"id": "redirector", "name": "Redirector"},
	{"id": "grabber", "name": "Grabber"},
	{"id": "guide", "name": "Guide"},
	{"id": "smuggler", "name": "Smuggler"},
	{"id": "killer", "name": "Killer"},
]

var _title_label: Label
var _depth_label: Label
var _score_label: Label
var _phase_label: Label
var _hint_label: Label
var _anchor_label: Label
var _action_bar: HBoxContainer
var _upgrade_overlay: PanelContainer
var _upgrade_title: Label
var _upgrade_buttons: Array[Button] = []
var _hover_panel: PanelContainer
var _hover_state_label: Label
var _hover_icon: TextureRect
var _hover_title_label: Label
var _hover_body_label: Label
var _last_role_label: Label
var _legend_scroll: ScrollContainer
var _log_scroll: ScrollContainer
var _log_container: VBoxContainer
var _legend_container: VBoxContainer
var _settings_button: Button
var _settings_panel: PanelContainer
var _pixel_filter_toggle: CheckButton
var _board_view_host: Control
var _icon_library = IconLibraryRef.new()
var _pixel_filter_enabled: bool = true

@onready var _game_viewport: SubViewport = $GameViewport
@onready var _pixel_display: TextureRect = $UI/PixelDisplay
@onready var _board = $GameViewport/World/Board
@onready var _camera: Camera3D = $GameViewport/World/Camera3D
@onready var _ui_root: Control = $UI


func _ready() -> void:
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pixel_display.texture = _game_viewport.get_texture()
	_pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_overlay()
	_bind_game_surface_input()
	get_viewport().size_changed.connect(_resize_display)
	if is_instance_valid(_board_view_host):
		_board_view_host.resized.connect(_resize_display)
	_apply_pixel_filter_state()
	_board.state_changed.connect(_refresh_overlay)
	_board.hovered_tile_changed.connect(_refresh_hover_card)
	call_deferred("_resize_display")
	_refresh_overlay()
	_refresh_hover_card()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_board.reset_board()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_board.set_selected_action("flip")
			get_viewport().set_input_as_handled()


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
	var host_size := get_viewport_rect().size
	if is_instance_valid(_board_view_host):
		host_size = _board_view_host.size
		if host_size.x <= 0.0 or host_size.y <= 0.0:
			return
	var render_scale := maxf(host_size.y / TARGET_INTERNAL_HEIGHT, 1.0)
	var viewport_size := Vector2i(
		maxi(1, int(round(host_size.x / render_scale))),
		maxi(1, int(round(host_size.y / render_scale)))
	)
	_game_viewport.size = viewport_size

	var filter_material := _pixel_display.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("source_size", Vector2(viewport_size))
		filter_material.set_shader_parameter("display_scale", render_scale)
		filter_material.set_shader_parameter("filter_enabled", _pixel_filter_enabled)

	var fitted_display := _get_fitted_display_rect(host_size, Vector2(viewport_size))
	_pixel_display.position = fitted_display.position
	_pixel_display.size = fitted_display.size

	_board.fit_camera(_camera, host_size)


func _build_overlay() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = PANEL_DARK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(backdrop)

	var shell_margin := MarginContainer.new()
	shell_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell_margin.add_theme_constant_override("margin_left", 20)
	shell_margin.add_theme_constant_override("margin_top", 16)
	shell_margin.add_theme_constant_override("margin_right", 20)
	shell_margin.add_theme_constant_override("margin_bottom", 16)
	shell_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(shell_margin)

	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 18)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_margin.add_child(shell)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(250, 0)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 14)
	left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(left_column)

	var title_panel := _make_panel(PANEL_DARK, PANEL_BORDER, 4, 14)
	left_column.add_child(title_panel)
	var title_margin := title_panel.get_child(0) as MarginContainer
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 4)
	title_margin.add_child(title_box)
	_title_label = _make_label("LIVING\nMAZE", 30, LABEL_LIGHT)
	title_box.add_child(_title_label)

	var run_panel := _make_panel(PANEL_INNER, PANEL_BORDER, 3, 14)
	left_column.add_child(run_panel)
	var run_box := _make_section_box(run_panel, "Run Status")
	_depth_label = _make_label("", 18, LABEL_LIGHT)
	_score_label = _make_label("", 16, LABEL_MUTED)
	_phase_label = _make_label("", 16, ACCENT_GOLD)
	_hint_label = _make_label("Click an adjacent hidden tile to flip it.", 17, PANEL_PAPER)
	_hint_label.custom_minimum_size = Vector2(0, 72)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_anchor_label = _make_label("", 15, LABEL_MUTED)
	run_box.add_child(_depth_label)
	run_box.add_child(_score_label)
	run_box.add_child(_phase_label)
	run_box.add_child(_hint_label)
	run_box.add_child(_anchor_label)

	var legend_panel := _make_panel(PANEL_INNER, PANEL_BORDER, 3, 14)
	legend_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(legend_panel)
	var legend_box := _make_section_box(legend_panel, "Legend")
	_legend_scroll = ScrollContainer.new()
	_legend_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_legend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_legend_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_box.add_child(_legend_scroll)

	_legend_container = VBoxContainer.new()
	_legend_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend_container.add_theme_constant_override("separation", 8)
	_legend_scroll.add_child(_legend_container)
	_build_legend()

	var center_column := VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 14)
	center_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(center_column)

	var board_frame := PanelContainer.new()
	board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_frame.add_theme_stylebox_override("panel", _make_stylebox(PANEL_INNER, PANEL_BORDER, 6, 18))
	center_column.add_child(board_frame)

	var board_padding := MarginContainer.new()
	board_padding.add_theme_constant_override("margin_left", 12)
	board_padding.add_theme_constant_override("margin_top", 12)
	board_padding.add_theme_constant_override("margin_right", 12)
	board_padding.add_theme_constant_override("margin_bottom", 12)
	board_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_frame.add_child(board_padding)

	_board_view_host = Control.new()
	_board_view_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view_host.clip_contents = true
	_board_view_host.mouse_filter = Control.MOUSE_FILTER_PASS
	board_padding.add_child(_board_view_host)

	_pixel_display.reparent(_board_view_host)
	_pixel_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pixel_display.position = Vector2.ZERO
	_pixel_display.size = Vector2.ZERO
	_pixel_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pixel_display.stretch_mode = TextureRect.STRETCH_SCALE

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
	_upgrade_overlay.add_theme_stylebox_override("panel", _make_stylebox(PANEL_PAPER, PANEL_BORDER, 4, 18))
	_board_view_host.add_child(_upgrade_overlay)

	var overlay_margin := MarginContainer.new()
	overlay_margin.add_theme_constant_override("margin_left", 18)
	overlay_margin.add_theme_constant_override("margin_top", 16)
	overlay_margin.add_theme_constant_override("margin_right", 18)
	overlay_margin.add_theme_constant_override("margin_bottom", 16)
	_upgrade_overlay.add_child(overlay_margin)

	var overlay_box := VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	overlay_margin.add_child(overlay_box)

	_upgrade_title = _make_label("Choose an upgrade", 24, LABEL_DARK)
	overlay_box.add_child(_upgrade_title)
	for _index in range(3):
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(360, 52)
		_style_button(button, false, true)
		button.pressed.connect(_on_upgrade_pressed.bind(button))
		overlay_box.add_child(button)
		_upgrade_buttons.append(button)

	_action_bar = HBoxContainer.new()
	_action_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 10)
	_action_bar.custom_minimum_size = Vector2(0, 58)
	center_column.add_child(_action_bar)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(280, 0)
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 14)
	right_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(right_column)

	_hover_panel = _make_panel(PANEL_PAPER, PANEL_BORDER, 4, 14)
	right_column.add_child(_hover_panel)
	var hover_box := _make_section_box(_hover_panel, "Tile Intel", LABEL_DARK, LABEL_DARK)
	_hover_state_label = _make_label("Inspect", 14, ACCENT_SOFT)
	hover_box.add_child(_hover_state_label)

	_hover_icon = TextureRect.new()
	_hover_icon.custom_minimum_size = Vector2(96, 96)
	_hover_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hover_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hover_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hover_box.add_child(_hover_icon)

	_hover_title_label = _make_label("Hover a tile", 20, LABEL_DARK)
	_hover_body_label = _make_label("Move the cursor over a tile to inspect its face and effect.", 15, Color8(78, 61, 44))
	_last_role_label = _make_label("Last reveal: none", 14, ACCENT_SOFT)
	hover_box.add_child(_hover_title_label)
	hover_box.add_child(_hover_body_label)
	hover_box.add_child(_last_role_label)

	var log_panel := _make_panel(PANEL_INNER, PANEL_BORDER, 3, 14)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(log_panel)
	var log_box := _make_section_box(log_panel, "Recent Log")
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_child(_log_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 8)
	_log_scroll.add_child(_log_container)

	var settings_wrap := VBoxContainer.new()
	settings_wrap.add_theme_constant_override("separation", 8)
	right_column.add_child(settings_wrap)

	_settings_button = Button.new()
	_settings_button.text = "Display"
	_settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(_settings_button, false, false)
	_settings_button.pressed.connect(_toggle_settings_panel)
	settings_wrap.add_child(_settings_button)

	_settings_panel = _make_panel(PANEL_INNER, PANEL_BORDER, 3, 12)
	_settings_panel.visible = false
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_wrap.add_child(_settings_panel)

	var settings_box := _make_section_box(_settings_panel, "Display")
	_pixel_filter_toggle = CheckButton.new()
	_pixel_filter_toggle.text = "Pixel filter"
	_pixel_filter_toggle.button_pressed = _pixel_filter_enabled
	_pixel_filter_toggle.toggled.connect(_on_pixel_filter_toggled)
	_pixel_filter_toggle.add_theme_color_override("font_color", LABEL_LIGHT)
	_pixel_filter_toggle.add_theme_color_override("font_pressed_color", ACCENT_GOLD)
	_pixel_filter_toggle.add_theme_font_size_override("font_size", 16)
	settings_box.add_child(_pixel_filter_toggle)


func _make_label(text: String, font_size: int = 16, color: Color = LABEL_LIGHT, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh_overlay() -> void:
	var hud: Dictionary = _board.get_hud_state()
	_depth_label.text = "Round %02d" % int(hud.get("depth", 1))
	_score_label.text = "Escapes %d" % int(hud.get("score", 0))
	var phase_label := String(hud.get("phase", "Flip"))
	var status_text := String(hud.get("status", ""))
	if _board.get_upgrade_offer_data().is_empty():
		_hint_label.text = status_text if not status_text.is_empty() else "Click a glowing adjacent hidden tile."
		if phase_label == "Loss":
			_hint_label.text = String(hud.get("failure_reason", "Press R to restart."))
	else:
		_hint_label.text = "Choose one upgrade to continue."
	_phase_label.text = "Phase %s" % phase_label
	_anchor_label.text = "Anchor armed" if bool(hud.get("anchor_ready", false)) else "Anchor idle"
	var last_role_name := String(hud.get("last_role_name", ""))
	var last_role_description := String(hud.get("last_role_description", ""))
	if last_role_name.is_empty():
		_last_role_label.text = "Last reveal: none"
	else:
		_last_role_label.text = "Last reveal: %s. %s" % [last_role_name, last_role_description]

	_refresh_action_buttons()
	_refresh_upgrade_overlay()
	_refresh_log(String(hud.get("status", "")), hud.get("log_lines", []))
	_refresh_hover_card()


func _refresh_hover_card() -> void:
	var hover_data: Dictionary = _board.get_hovered_tile_details()
	if hover_data.is_empty():
		_hover_state_label.text = "Inspect"
		_hover_title_label.text = "Hover a tile"
		_hover_body_label.text = "Move the cursor over a tile to inspect its face and effect."
		_hover_icon.texture = _icon_library.make_face_texture("guide", false, true, 72)
		return

	var icon_id := String(hover_data.get("icon_id", "guide"))
	var show_front := bool(hover_data.get("show_front", false))
	_hover_state_label.text = String(hover_data.get("state_label", "Tile"))
	_hover_title_label.text = String(hover_data.get("title", "Tile"))
	_hover_body_label.text = String(hover_data.get("description", ""))
	_hover_icon.texture = _icon_library.make_face_texture(icon_id, show_front, true, 72)


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
		button.custom_minimum_size = Vector2(168, 58)
		_style_button(button, bool(button_data.get("selected", false)), true)
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
		_style_button(button, false, true)


func _on_action_pressed(action_id: String) -> void:
	_board.set_selected_action(action_id)


func _on_upgrade_pressed(button: Button) -> void:
	var upgrade_id := String(button.get_meta("upgrade_id", ""))
	if upgrade_id.is_empty():
		return
	_board.choose_upgrade(upgrade_id)


func _toggle_settings_panel() -> void:
	_settings_panel.visible = not _settings_panel.visible


func _on_pixel_filter_toggled(enabled: bool) -> void:
	_pixel_filter_enabled = enabled
	_apply_pixel_filter_state()


func _apply_pixel_filter_state() -> void:
	var filter_material := _pixel_display.material as ShaderMaterial
	if filter_material != null:
		filter_material.set_shader_parameter("filter_enabled", _pixel_filter_enabled)
	if _pixel_filter_toggle != null:
		_pixel_filter_toggle.button_pressed = _pixel_filter_enabled


func _display_to_viewport_pos(local_position: Vector2) -> Vector2:
	var mapped_position := local_position
	mapped_position.x *= _game_viewport.size.x / maxf(_pixel_display.size.x, 1.0)
	mapped_position.y *= _game_viewport.size.y / maxf(_pixel_display.size.y, 1.0)
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
	# Keep all board pointer handling on the rendered game surface so UI refactors
	# cannot silently break clicks by changing propagation on parent controls.
	_pixel_display.mouse_filter = Control.MOUSE_FILTER_STOP
	_pixel_display.gui_input.connect(_on_pixel_display_gui_input)
	_pixel_display.mouse_exited.connect(_on_pixel_display_mouse_exited)


func _make_stylebox(bg: Color, border: Color, border_width: int = 3, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_panel(bg: Color, border: Color, border_width: int = 3, margin: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_stylebox(bg, border, border_width, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", margin)
	panel_margin.add_theme_constant_override("margin_top", margin)
	panel_margin.add_theme_constant_override("margin_right", margin)
	panel_margin.add_theme_constant_override("margin_bottom", margin)
	panel_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_margin)
	return panel


func _make_section_box(panel: PanelContainer, title: String, title_color: Color = LABEL_LIGHT, body_color: Color = LABEL_LIGHT) -> VBoxContainer:
	var panel_margin := panel.get_child(0) as MarginContainer
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel_margin.add_child(box)

	var title_label := _make_label(title.to_upper(), 14, title_color, false)
	box.add_child(title_label)
	return box


func _style_button(button: BaseButton, selected: bool, large: bool) -> void:
	var base_bg := PANEL_INNER if not selected else Color8(70, 42, 31)
	var hover_bg := base_bg.lightened(0.08)
	var pressed_bg := base_bg.darkened(0.08)
	var border := ACCENT_GOLD if selected else PANEL_BORDER
	var text_color := LABEL_LIGHT if not selected else PANEL_PAPER
	if button.disabled:
		base_bg = Color8(54, 48, 43)
		hover_bg = base_bg
		pressed_bg = base_bg
		border = Color8(92, 80, 69)
		text_color = Color8(142, 129, 112)
	button.add_theme_stylebox_override("normal", _make_stylebox(base_bg, border, 3, 12))
	button.add_theme_stylebox_override("hover", _make_stylebox(hover_bg, border, 3, 12))
	button.add_theme_stylebox_override("pressed", _make_stylebox(pressed_bg, border, 3, 12))
	button.add_theme_stylebox_override("disabled", _make_stylebox(base_bg, border, 3, 12))
	button.add_theme_stylebox_override("focus", _make_stylebox(hover_bg, border, 3, 12))
	button.add_theme_font_size_override("font_size", 18 if large else 16)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	button.add_theme_constant_override("h_separation", 10)


func _build_legend() -> void:
	for child in _legend_container.get_children():
		if child is Label:
			continue
		child.queue_free()
	for role_data in LEGEND_ROLES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 34)
		row.add_theme_constant_override("separation", 8)
		_legend_container.add_child(row)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.texture = _icon_library.make_face_texture(String(role_data["id"]), true, false, 34)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)

		var label := _make_label(String(role_data["name"]), 16, LABEL_LIGHT, false)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)


func _refresh_log(current_status: String, lines: Array) -> void:
	for child in _log_container.get_children():
		if child is Label:
			continue
		child.queue_free()

	if not current_status.is_empty():
		var status_label := _make_label(current_status, 15, PANEL_PAPER)
		_log_container.add_child(status_label)

	if lines.is_empty():
		_log_container.add_child(_make_label("No events yet.", 14, LABEL_MUTED))
		return

	for line in lines:
		_log_container.add_child(_make_label("-> %s" % String(line), 14, LABEL_MUTED))
