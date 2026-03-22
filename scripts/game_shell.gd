class_name GameShell
extends Control

signal action_requested(action_id: String)
signal upgrade_requested(upgrade_id: String)
signal reset_requested
signal pixel_filter_toggled(enabled: bool)

const ThemeManifestRef = preload("res://themes/ink_theme_manifest.tres")
const InkPainterRef = preload("res://scripts/ink_painter.gd")

var _theme_manifest = ThemeManifestRef
var _painter = InkPainterRef.new(_theme_manifest)
var _action_button_map: Dictionary = {}
var _upgrade_buttons: Array[Button] = []
var _section_cache: Dictionary = {}

@onready var _backdrop: TextureRect = $Backdrop
@onready var _grime: TextureRect = $Grime
@onready var _left_title_panel: PanelContainer = $Margin/Root/Top/LeftRailScroll/LeftRail/TitlePanel
@onready var _status_panel: PanelContainer = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel
@onready var _legend_panel: PanelContainer = $Margin/Root/Top/LeftRailScroll/LeftRail/LegendPanel
@onready var _board_panel: PanelContainer = $Margin/Root/Top/CenterColumn/BoardPanel
@onready var _action_panel: PanelContainer = $Margin/Root/Bottom/ActionDock
@onready var _hover_panel: PanelContainer = $Margin/Root/Top/RightRailScroll/RightRail/HoverPanel
@onready var _log_panel: PanelContainer = $Margin/Root/Top/RightRailScroll/RightRail/LogPanel
@onready var _structure_panel: PanelContainer = $Margin/Root/Top/RightRailScroll/RightRail/StructuresPanel
@onready var _minimap_panel: PanelContainer = $Margin/Root/Top/RightRailScroll/RightRail/MinimapPanel
@onready var _left_rail_scroll: ScrollContainer = $Margin/Root/Top/LeftRailScroll
@onready var _right_rail_scroll: ScrollContainer = $Margin/Root/Top/RightRailScroll
@onready var _title_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/TitlePanel/MarginBox/TitleBox/Title
@onready var _subtitle_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/TitlePanel/MarginBox/TitleBox/Subtitle
@onready var _round_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/Round
@onready var _pressure_value_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/PressureRow/PressureValue
@onready var _objective_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/Objective
@onready var _status_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/Status
@onready var _pixel_toggle: CheckButton = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/PixelToggle
@onready var _pressure_bar: HBoxContainer = $Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/PressureBar
@onready var _turn_panel: PanelContainer = $Margin/Root/Top/LeftRailScroll/LeftRail/TurnPanel
@onready var _turn_title_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/TurnPanel/MarginBox/TurnBox/TurnTitle
@onready var _turn_body_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/TurnPanel/MarginBox/TurnBox/TurnBody
@onready var _turn_footer_label: Label = $Margin/Root/Top/LeftRailScroll/LeftRail/TurnPanel/MarginBox/TurnBox/TurnFooter
@onready var _legend_list: VBoxContainer = $Margin/Root/Top/LeftRailScroll/LeftRail/LegendPanel/MarginBox/LegendBox/LegendScroll/LegendList
@onready var _board_host: Control = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost
@onready var _pixel_display: TextureRect = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/PixelDisplay
@onready var _transition_panel: PanelContainer = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/TransitionPanel
@onready var _transition_eyebrow_label: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/TransitionPanel/MarginBox/TransitionBox/TransitionEyebrow
@onready var _transition_title_label: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/TransitionPanel/MarginBox/TransitionBox/TransitionTitle
@onready var _transition_body_label: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/TransitionPanel/MarginBox/TransitionBox/TransitionBody
@onready var _transition_meta_label: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/TransitionPanel/MarginBox/TransitionBox/TransitionMeta
@onready var _upgrade_overlay: PanelContainer = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/UpgradeOverlay
@onready var _upgrade_title: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/UpgradeOverlay/MarginBox/UpgradeBox/UpgradeTitle
@onready var _upgrade_subtitle: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/UpgradeOverlay/MarginBox/UpgradeBox/UpgradeSubtitle
@onready var _upgrade_context: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/UpgradeOverlay/MarginBox/UpgradeBox/UpgradeContext
@onready var _upgrade_buttons_box: VBoxContainer = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/UpgradeOverlay/MarginBox/UpgradeBox/UpgradeButtons
@onready var _game_over_overlay: PanelContainer = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/GameOverOverlay
@onready var _game_over_eyebrow: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/GameOverOverlay/MarginBox/GameOverBox/GameOverEyebrow
@onready var _game_over_title: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/GameOverOverlay/MarginBox/GameOverBox/GameOverTitle
@onready var _game_over_body: Label = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/GameOverOverlay/MarginBox/GameOverBox/GameOverBody
@onready var _game_over_restart_button: Button = $Margin/Root/Top/CenterColumn/BoardPanel/MarginBox/BoardHost/GameOverOverlay/MarginBox/GameOverBox/GameOverRestart
@onready var _action_row: HBoxContainer = $Margin/Root/Bottom/ActionDock/MarginBox/ActionRow
@onready var _hover_state_label: Label = $Margin/Root/Top/RightRailScroll/RightRail/HoverPanel/MarginBox/HoverBox/HoverState
@onready var _hover_card: TextureRect = $Margin/Root/Top/RightRailScroll/RightRail/HoverPanel/MarginBox/HoverBox/HoverCard
@onready var _hover_title_label: Label = $Margin/Root/Top/RightRailScroll/RightRail/HoverPanel/MarginBox/HoverBox/HoverTitle
@onready var _hover_body_label: Label = $Margin/Root/Top/RightRailScroll/RightRail/HoverPanel/MarginBox/HoverBox/HoverBody
@onready var _next_reveal_label: Label = $Margin/Root/Top/RightRailScroll/RightRail/HoverPanel/MarginBox/HoverBox/NextReveal
@onready var _log_list: VBoxContainer = $Margin/Root/Top/RightRailScroll/RightRail/LogPanel/MarginBox/LogBox/LogList
@onready var _structure_grid: GridContainer = $Margin/Root/Top/RightRailScroll/RightRail/StructuresPanel/MarginBox/StructuresBox/StructureGrid
@onready var _minimap_texture: TextureRect = $Margin/Root/Top/RightRailScroll/RightRail/MinimapPanel/MarginBox/MiniMapBox/MiniMapTexture


func _ready() -> void:
	# Side rails are intentionally scroll-wrapped so adding or resizing a panel
	# cannot silently increase the shell height and push the board off-screen.
	_apply_static_theme()
	_apply_layout_constraints()
	_build_pressure_bar()
	_build_structure_cards()
	_build_upgrade_buttons()
	_game_over_restart_button.pressed.connect(_on_game_over_restart_pressed)
	_pixel_toggle.toggled.connect(_on_pixel_toggle_toggled)
	resized.connect(_refresh_backdrop_textures)
	resized.connect(_apply_layout_constraints)
	call_deferred("_refresh_backdrop_textures")


func get_board_host() -> Control:
	return _board_host


func get_pixel_display() -> TextureRect:
	return _pixel_display


func update_state(state: Dictionary) -> void:
	_title_label.text = String(state.get("title_text", _theme_manifest.title_text))
	_subtitle_label.text = String(state.get("subtitle_text", _theme_manifest.subtitle_text))
	var phase_label := _get_optional_state_string(state, ["phase_label"], String(state.get("phase", "FLIP")).to_upper())
	_round_label.text = "ROUND %02d  %s" % [int(state.get("depth", 1)), phase_label]
	_pressure_value_label.text = "%d / %d" % [int(state.get("pressure_current", 0)), int(state.get("pressure_max", 10))]
	var objective_text := String(state.get("objective_text", "Reach any edge to escape."))
	var objective_detail := _get_optional_state_string(state, ["objective_detail", "goal_detail"], "")
	if not objective_detail.is_empty():
		objective_text += "\n%s" % objective_detail
	_objective_label.text = objective_text
	var status_text := String(state.get("status", ""))
	var status_detail := _get_optional_state_string(state, ["status_detail", "turn_status"], "")
	if not status_detail.is_empty() and status_detail != status_text:
		status_text = "%s\n%s" % [status_text, status_detail] if not status_text.is_empty() else status_detail
	_status_label.text = status_text
	_refresh_section_if_changed("turn", _get_turn_payload(state), _refresh_turn_surface)
	_refresh_section_if_changed("transition", _get_transition_payload(state), _refresh_transition_banner)
	_refresh_pressure_bar(int(state.get("pressure_current", 0)), int(state.get("pressure_max", 10)))
	_refresh_section_if_changed("legend", state.get("legend_items", []), _refresh_legend)
	_refresh_section_if_changed("actions", state.get("action_items", []), _refresh_actions)
	_refresh_section_if_changed("log", {
		"items": state.get("log_items", []),
		"status": status_text,
	}, _refresh_log_bundle)
	_refresh_section_if_changed("hover", state.get("hover_card", {}), _refresh_hover)
	_refresh_section_if_changed("structures", state.get("structure_items", []), _refresh_structures)
	_refresh_section_if_changed("minimap", state.get("minimap", {}), _refresh_minimap)
	_refresh_section_if_changed("upgrades", _get_upgrade_payload(state), _refresh_upgrade_overlay)
	_refresh_section_if_changed("game_over", _get_game_over_payload(state), _refresh_game_over_overlay)


func update_hover_card(card_data: Dictionary) -> void:
	_refresh_section_if_changed("hover", card_data, _refresh_hover)


func reset_visual_cache() -> void:
	_section_cache.clear()


func set_pixel_filter_enabled(enabled: bool) -> void:
	_pixel_toggle.set_pressed_no_signal(enabled)
	_style_button(_pixel_toggle, enabled, false)


func _refresh_section_if_changed(section_id: String, payload, refresh_callable: Callable) -> void:
	var next_key := JSON.stringify(payload, "", true)
	if _section_cache.get(section_id, "") == next_key:
		return
	_section_cache[section_id] = next_key
	refresh_callable.call(payload)


func _refresh_log_bundle(bundle: Dictionary) -> void:
	_refresh_log(bundle.get("items", []), String(bundle.get("status", "")))


func _get_turn_payload(state: Dictionary) -> Dictionary:
	var selected_action_id := String(state.get("selected_action", "flip"))
	var action_items: Array = state.get("action_items", [])
	var action_item := _find_action_item(action_items, selected_action_id)
	var action_label := String(action_item.get("label", _get_action_display_name(selected_action_id)))
	var title := _get_optional_state_string(state, ["turn_title", "action_title"], "")
	if title.is_empty():
		var end_state: Dictionary = state.get("end_state", {})
		if String(end_state.get("kind", "")) == "victory":
			title = "Board cleared"
		elif bool(state.get("run_over", false)):
			title = "Run ended"
		elif bool(state.get("awaiting_upgrade_choice", false)):
			title = "Choose an upgrade"
		else:
			title = action_label
	var body := _get_optional_state_string(state, ["turn_hint", "action_hint", "status_detail"], "")
	if body.is_empty():
		body = _get_action_instruction(selected_action_id)
	var footer := _get_optional_state_string(state, ["turn_footer", "context_line"], String(state.get("status", "")))
	if footer.is_empty():
		footer = _build_turn_footer(state, action_label)
	var accent := Color(action_item.get("accent_color", _theme_manifest.get_color("highlight")))
	return {
		"visible": true,
		"title": title,
		"body": body,
		"footer": footer,
		"accent_color": accent,
	}


func _refresh_turn_surface(payload: Dictionary) -> void:
	_turn_panel.visible = bool(payload.get("visible", true))
	_turn_title_label.text = String(payload.get("title", "Turn"))
	_turn_body_label.text = String(payload.get("body", ""))
	_turn_footer_label.text = String(payload.get("footer", ""))
	var accent := Color(payload.get("accent_color", _theme_manifest.get_color("highlight")))
	_turn_title_label.add_theme_color_override("font_color", accent)
	_turn_footer_label.add_theme_color_override("font_color", _theme_manifest.get_color("muted"))


func _get_transition_payload(state: Dictionary) -> Dictionary:
	var end_state: Dictionary = state.get("end_state", {})
	if String(end_state.get("kind", "")) != "victory":
		return {"visible": false}
	var title := _get_optional_state_string(state, ["transition_title"], String(end_state.get("title", "Board cleared")))
	var body := _get_optional_state_string(state, ["transition_body"], String(end_state.get("summary", "Route opened.")))
	var detail := _get_optional_state_string(state, ["transition_detail"], String(end_state.get("detail", "Choose an upgrade to continue.")))
	var meta := _get_optional_state_string(state, ["transition_meta"], "")
	if meta.is_empty():
		meta = detail
	if meta.is_empty():
		meta = "Depth %02d  Score %d" % [int(state.get("depth", 1)), int(state.get("score", 0))]
	if bool(state.get("awaiting_upgrade_choice", false)):
		meta += "  Pick one route to continue."
	return {
		"visible": true,
		"eyebrow": _get_optional_state_string(state, ["transition_eyebrow"], "BOARD CLEARED"),
		"title": title,
		"body": body,
		"meta": meta,
		"accent_color": _theme_manifest.get_color("highlight"),
	}


func _refresh_transition_banner(payload: Dictionary) -> void:
	var visible := bool(payload.get("visible", false))
	_transition_panel.visible = visible
	if not visible:
		return
	_transition_eyebrow_label.text = String(payload.get("eyebrow", "BOARD CLEARED"))
	_transition_title_label.text = String(payload.get("title", "Route opened"))
	_transition_body_label.text = String(payload.get("body", "Choose an upgrade to continue."))
	_transition_meta_label.text = String(payload.get("meta", ""))
	var accent := Color(payload.get("accent_color", _theme_manifest.get_color("highlight")))
	_transition_eyebrow_label.add_theme_color_override("font_color", accent)
	_transition_title_label.add_theme_color_override("font_color", _theme_manifest.get_color("ink"))
	_transition_panel.add_theme_stylebox_override("panel", _painter.make_panel_style("paper", accent))


func _get_upgrade_payload(state: Dictionary) -> Dictionary:
	var items: Array = state.get("upgrade_items", [])
	var title := _get_optional_state_string(state, ["upgrade_title"], "Choose a route")
	var subtitle := _get_optional_state_string(state, ["upgrade_subtitle", "reward_title"], "Pick one upgrade to shape the next board.")
	var context := _get_optional_state_string(state, ["upgrade_context", "reward_context"], "")
	if context.is_empty():
		context = "Depth %02d  Score %d" % [int(state.get("depth", 1)), int(state.get("score", 0))]
		var end_state: Dictionary = state.get("end_state", {})
		var detail := String(end_state.get("detail", ""))
		if not detail.is_empty():
			context += "\n%s" % detail
	return {
		"items": items,
		"title": title,
		"subtitle": subtitle,
		"context": context,
	}


func _find_action_item(items: Array, action_id: String) -> Dictionary:
	for item in items:
		if String(item.get("id", "")) == action_id:
			return item
	return {}


func _get_optional_state_string(state: Dictionary, keys: Array[String], fallback: String) -> String:
	for key in keys:
		var value := String(state.get(key, ""))
		if not value.is_empty():
			return value
	return fallback


func _get_action_display_name(action_id: String) -> String:
	match action_id:
		"flip":
			return "Reveal"
		"stay":
			return "Stay"
		"peek":
			return "Observe"
		"remote_flip":
			return "Remote Flip"
		"step":
			return "Step"
		"daze":
			return "Daze"
		"anchor":
			return "Anchor"
		_:
			return action_id.capitalize()


func _get_action_instruction(action_id: String) -> String:
	match action_id:
		"flip":
			return "Click a hidden adjacent tile to reveal it and let the board resolve."
		"stay":
			return "End the turn without revealing. Pressure still advances."
		"peek":
			return "Click a highlighted adjacent hidden tile to preview it without spending the reveal."
		"remote_flip":
			return "Click a hidden tile exactly two spaces away on a straight line."
		"step":
			return "Click a safe revealed adjacent tile to move before the board reacts."
		"daze":
			return "Click a revealed adjacent tile to delay its next activation."
		"anchor":
			return "Arm the anchor so the next forced move is canceled."
		_:
			return "Choose a legal target or switch actions from the dock."


func _build_turn_footer(state: Dictionary, action_label: String) -> String:
	var segments: Array[String] = []
	var pressure_current := int(state.get("pressure_current", 0))
	var pressure_max := int(state.get("pressure_max", 0))
	if pressure_max > 0:
		segments.append("Pressure %d/%d" % [pressure_current, pressure_max])
	var pressure_warning := bool(state.get("pressure_warning", false))
	if pressure_warning:
		segments.append("Warning threshold reached")
	if bool(state.get("anchor_ready", false)):
		segments.append("Anchor armed")
	if bool(state.get("player_alive", true)) and not bool(state.get("run_over", false)):
		segments.append("Selected: %s" % action_label)
	if segments.is_empty():
		return "Selected: %s" % action_label
	return "  ".join(segments)


func _apply_static_theme() -> void:
	var dark_panel: StyleBoxTexture = _painter.make_panel_style("dark")
	var paper_panel: StyleBoxTexture = _painter.make_panel_style("paper")
	for panel in [_left_title_panel, _status_panel, _turn_panel, _legend_panel, _board_panel, _action_panel, _log_panel, _structure_panel, _minimap_panel]:
		panel.add_theme_stylebox_override("panel", dark_panel)
	_hover_panel.add_theme_stylebox_override("panel", paper_panel)
	_transition_panel.add_theme_stylebox_override("panel", _painter.make_panel_style("paper", _theme_manifest.get_color("highlight")))
	_upgrade_overlay.add_theme_stylebox_override("panel", _painter.make_panel_style("paper_soft", _theme_manifest.get_color("highlight")))
	_apply_label_theme(_title_label, 34, _theme_manifest.get_color("paper"), true)
	_apply_label_theme(_subtitle_label, 14, _theme_manifest.get_color("muted"), false)
	_apply_label_theme(_round_label, 20, _theme_manifest.get_color("paper"), true)
	_apply_label_theme($Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/PressureRow/PressureLabel, 13, _theme_manifest.get_color("muted"), true)
	_apply_label_theme(_pressure_value_label, 16, _theme_manifest.get_color("paper"), false)
	_apply_label_theme($Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/ObjectiveHeading, 13, _theme_manifest.get_color("muted"), true)
	_apply_label_theme(_objective_label, 18, _theme_manifest.get_color("paper"), false)
	_apply_label_theme($Margin/Root/Top/LeftRailScroll/LeftRail/StatusPanel/MarginBox/StatusBox/StatusHeading, 13, _theme_manifest.get_color("muted"), true)
	_apply_label_theme(_status_label, 15, _theme_manifest.get_color("muted"), false)
	_apply_label_theme(_turn_title_label, 19, _theme_manifest.get_color("paper"), true)
	_apply_label_theme(_turn_body_label, 15, _theme_manifest.get_color("ink_soft"), false)
	_apply_label_theme(_turn_footer_label, 13, _theme_manifest.get_color("muted"), false)
	_configure_wrapping_label(_objective_label)
	_configure_wrapping_label(_status_label)
	_configure_wrapping_label(_turn_title_label)
	_configure_wrapping_label(_turn_body_label)
	_configure_wrapping_label(_turn_footer_label)
	_pixel_toggle.text = "PIXELATION"
	_pixel_toggle.toggle_mode = true
	_pixel_toggle.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pixel_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pixel_toggle.custom_minimum_size = Vector2(0, 42)
	_style_button(_pixel_toggle, _pixel_toggle.button_pressed, false)
	_apply_panel_headings()
	_apply_label_theme(_hover_state_label, 13, _theme_manifest.get_color("muted"), false)
	_apply_label_theme(_hover_title_label, 24, _theme_manifest.get_color("ink"), true)
	_apply_label_theme(_hover_body_label, 16, _theme_manifest.get_color("ink_soft"), false)
	_apply_label_theme(_next_reveal_label, 14, _theme_manifest.get_color("danger"), false)
	_apply_label_theme(_upgrade_title, 24, _theme_manifest.get_color("ink"), true)
	_apply_label_theme(_upgrade_subtitle, 16, _theme_manifest.get_color("ink_soft"), false)
	_apply_label_theme(_upgrade_context, 13, _theme_manifest.get_color("muted"), false)
	_apply_label_theme(_transition_eyebrow_label, 13, _theme_manifest.get_color("highlight"), true)
	_apply_label_theme(_transition_title_label, 26, _theme_manifest.get_color("ink"), true)
	_apply_label_theme(_transition_body_label, 16, _theme_manifest.get_color("ink_soft"), false)
	_apply_label_theme(_transition_meta_label, 13, _theme_manifest.get_color("muted"), false)
	_game_over_overlay.add_theme_stylebox_override("panel", _painter.make_panel_style("paper", _theme_manifest.get_color("danger")))
	_apply_label_theme(_game_over_eyebrow, 13, _theme_manifest.get_color("danger"), true)
	_apply_label_theme(_game_over_title, 28, _theme_manifest.get_color("ink"), true)
	_apply_label_theme(_game_over_body, 16, _theme_manifest.get_color("ink_soft"), false)
	_configure_wrapping_label(_hover_title_label)
	_configure_wrapping_label(_hover_body_label)
	_configure_wrapping_label(_upgrade_subtitle)
	_configure_wrapping_label(_upgrade_context)
	_configure_wrapping_label(_transition_title_label)
	_configure_wrapping_label(_transition_body_label)
	_configure_wrapping_label(_transition_meta_label)
	_configure_wrapping_label(_game_over_body)
	_style_button(_game_over_restart_button, false, true)
	_upgrade_overlay.visible = false
	_transition_panel.visible = false
	_game_over_overlay.visible = false
	_hover_card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hover_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_minimap_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_action_panel.custom_minimum_size = Vector2(0, 92)


func _apply_panel_headings() -> void:
	var heading_paths := [
		$Margin/Root/Top/LeftRailScroll/LeftRail/LegendPanel/MarginBox/LegendBox/Heading,
		$Margin/Root/Top/RightRailScroll/RightRail/LogPanel/MarginBox/LogBox/Heading,
		$Margin/Root/Top/RightRailScroll/RightRail/StructuresPanel/MarginBox/StructuresBox/Heading,
		$Margin/Root/Top/RightRailScroll/RightRail/MinimapPanel/MarginBox/MiniMapBox/Heading,
	]
	for heading in heading_paths:
		_apply_label_theme(heading, 13, _theme_manifest.get_color("paper"), true)


func _apply_label_theme(label: Label, size: int, color: Color, display_font: bool) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", _painter.make_display_font(size) if display_font else _painter.make_body_font(size))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_wrapping_label(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _apply_layout_constraints() -> void:
	var viewport_width := get_viewport_rect().size.x
	_left_rail_scroll.custom_minimum_size.x = clampf(viewport_width * 0.20, 240.0, 320.0)
	_right_rail_scroll.custom_minimum_size.x = clampf(viewport_width * 0.24, 280.0, 360.0)


func _build_pressure_bar() -> void:
	for child in _pressure_bar.get_children():
		child.queue_free()
	for _index in range(10):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(18, 12)
		segment.color = _theme_manifest.get_color("ink_soft")
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pressure_bar.add_child(segment)


func _refresh_pressure_bar(current: int, maximum: int) -> void:
	var fill_count := mini(_pressure_bar.get_child_count(), current)
	for index in range(_pressure_bar.get_child_count()):
		var segment := _pressure_bar.get_child(index) as ColorRect
		if segment == null:
			continue
		var fill := index < fill_count
		segment.color = _theme_manifest.get_color("danger").lightened(index * 0.02) if fill else _theme_manifest.get_color("ink_soft")
	_pressure_bar.visible = maximum > 0


func _refresh_backdrop_textures() -> void:
	var safe_size := get_viewport_rect().size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		return
	_backdrop.texture = _painter.make_backdrop_texture(Vector2i(safe_size))
	_grime.texture = _painter.make_backdrop_texture(Vector2i(safe_size.x / 2.0, safe_size.y / 2.0))
	_grime.modulate = Color(1, 1, 1, 0.22)


func _refresh_legend(items: Array) -> void:
	for child in _legend_list.get_children():
		child.queue_free()
	for item in items:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 42)
		row.add_theme_constant_override("separation", 10)
		_legend_list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.texture = _painter.make_icon_texture(String(item.get("icon_id", "")), 34, Color(item.get("accent_color", _theme_manifest.get_color("paper"))))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = String(item.get("label", "ROLE"))
		_apply_label_theme(label, 16, _theme_manifest.get_color("paper"), false)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)


func _refresh_actions(items: Array) -> void:
	for child in _action_row.get_children():
		child.queue_free()
	_action_button_map.clear()
	for item in items:
		var button := Button.new()
		var action_id := String(item.get("id", ""))
		button.text = String(item.get("label", action_id.to_upper()))
		button.disabled = not bool(item.get("enabled", true))
		button.custom_minimum_size = Vector2(0, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = _painter.make_icon_texture(String(item.get("icon_id", action_id)), 22, Color(item.get("accent_color", _theme_manifest.get_color("paper"))))
		_style_button(button, bool(item.get("selected", false)), bool(item.get("danger", false)))
		button.pressed.connect(_on_action_button_pressed.bind(action_id))
		_action_row.add_child(button)
		_action_button_map[action_id] = button


func _refresh_log(items: Array, status_line: String) -> void:
	for child in _log_list.get_children():
		child.queue_free()
	if not status_line.is_empty():
		var status := Label.new()
		status.text = status_line
		_apply_label_theme(status, 14, _theme_manifest.get_color("paper"), false)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_log_list.add_child(status)
	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_log_list.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.texture = _painter.make_icon_texture(String(item.get("icon_id", "")), 18, Color(item.get("accent_color", _theme_manifest.get_color("paper"))))
		row.add_child(icon)
		var label := Label.new()
		label.text = String(item.get("text", ""))
		_apply_label_theme(label, 13, _theme_manifest.get_color("muted"), false)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)


func _refresh_hover(card_data: Dictionary) -> void:
	if card_data.is_empty():
		_hover_state_label.text = "INSPECT"
		_hover_title_label.text = "Hover a tile"
		_hover_body_label.text = "Move over a tile to inspect the occupant, reveal state, and current target hints."
		_next_reveal_label.text = "NEXT REVEAL UNKNOWN"
		_hover_card.texture = _painter.make_role_card_texture("guide", {"is_hidden": true, "is_previewed": false}, 256, 1)
		return
	var icon_id := String(card_data.get("icon_id", "guide"))
	var accent := Color(card_data.get("accent_color", _theme_manifest.get_color(icon_id)))
	_hover_state_label.text = String(card_data.get("state_label", "TILE"))
	_hover_title_label.text = String(card_data.get("title", "Tile"))
	var body_text := String(card_data.get("summary", card_data.get("description", "")))
	if body_text.is_empty():
		body_text = String(card_data.get("description", ""))
	_hover_body_label.text = body_text
	_next_reveal_label.text = String(card_data.get("detail_line", "RECENT INTEL"))
	_hover_card.texture = _painter.make_role_card_texture(icon_id, {
		"is_hidden": bool(card_data.get("is_hidden", false)),
		"is_previewed": bool(card_data.get("is_previewed", false)),
		"is_target": bool(card_data.get("is_target", false)),
		"is_selected_target": bool(card_data.get("is_selected_target", false)),
	}, 256, 2)
	_hover_state_label.add_theme_color_override("font_color", accent)


func _build_structure_cards() -> void:
	for child in _structure_grid.get_children():
		child.queue_free()
	var ids := ["conduit", "gate", "anchor_node", "hub"]
	for structure_id in ids:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(96, 96)
		panel.add_theme_stylebox_override("panel", _painter.make_panel_style("paper_soft", _theme_manifest.get_color(structure_id)))
		_structure_grid.add_child(panel)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		margin.add_child(box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(0, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _painter.make_icon_texture(structure_id, 52, _theme_manifest.get_color(structure_id), true)
		box.add_child(icon)
		var label := Label.new()
		label.text = String(_theme_manifest.structure_labels.get(structure_id, structure_id.to_upper()))
		_apply_label_theme(label, 12, _theme_manifest.get_color("paper"), true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		panel.set_meta("structure_id", structure_id)


func _refresh_structures(items: Array) -> void:
	for child in _structure_grid.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		var structure_id := String(panel.get_meta("structure_id", ""))
		var item := {}
		for candidate in items:
			if String(candidate.get("id", "")) == structure_id:
				item = candidate
				break
		panel.modulate = Color(1, 1, 1, 1.0 if not item.is_empty() else 0.7)


func _refresh_minimap(data: Dictionary) -> void:
	_minimap_texture.texture = _painter.make_minimap_texture(data, Vector2i(230, 230))


func _build_upgrade_buttons() -> void:
	for _index in range(3):
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(420, 76)
		button.pressed.connect(_on_upgrade_pressed.bind(button))
		_upgrade_buttons_box.add_child(button)
		_upgrade_buttons.append(button)


func _refresh_upgrade_overlay(payload: Dictionary) -> void:
	var items: Array = payload.get("items", [])
	_upgrade_overlay.visible = not items.is_empty()
	_upgrade_title.text = String(payload.get("title", "Choose a route"))
	_upgrade_subtitle.text = String(payload.get("subtitle", "Pick one upgrade to shape the next board."))
	_upgrade_context.text = String(payload.get("context", ""))
	for index in range(_upgrade_buttons.size()):
		var button := _upgrade_buttons[index]
		if index >= items.size():
			button.visible = false
			continue
		var item: Dictionary = items[index]
		button.visible = true
		button.text = "%s\n%s" % [String(item.get("name", "")), String(item.get("description", ""))]
		button.set_meta("upgrade_id", String(item.get("id", "")))
		button.icon = _painter.make_icon_texture(String(item.get("icon_id", "flip_again")), 20, Color(item.get("accent_color", _theme_manifest.get_color("highlight"))))
		_style_button(button, false, false)


func _get_game_over_payload(state: Dictionary) -> Dictionary:
	var is_loss := bool(state.get("show_game_over", false))
	if not is_loss:
		var end_state := str(state.get("end_state", ""))
		is_loss = end_state == "loss" or end_state == "defeat"
	if not is_loss and state.has("player_alive"):
		is_loss = not bool(state.get("player_alive", true))
	var upgrade_items: Array = state.get("upgrade_items", [])
	var overlay_visible := is_loss and upgrade_items.is_empty()
	if not overlay_visible:
		return {"visible": false}

	var score_value := int(state.get("score", maxi(int(state.get("depth", 1)) - 1, 0)))
	var title := str(state.get("game_over_title", state.get("end_state_title", "Run Lost")))
	var reason := str(state.get("game_over_reason", state.get("failure_reason", state.get("status", "The maze closed around you."))))
	if reason.is_empty():
		reason = "The maze closed around you."
	var body := reason
	if score_value > 0:
		body += "\n\nDepth cleared: %d" % score_value
	if reason.contains("Pressure"):
		body += "\nTry earlier exits or a safer first reveal."
	elif reason.contains("killer") or reason.contains("Killer"):
		body += "\nKiller tiles end the run on entry."
	elif reason.contains("grabber") or reason.contains("Grabber"):
		body += "\nGrabbers make forced movement harder to escape."
	body += "\nPress R to restart."
	return {
		"visible": true,
		"eyebrow": str(state.get("game_over_eyebrow", "RUN ENDED")),
		"title": title,
		"body": body,
	}


func _refresh_game_over_overlay(payload: Dictionary) -> void:
	var visible := bool(payload.get("visible", false))
	_game_over_overlay.visible = visible
	if not visible:
		return
	_game_over_eyebrow.text = str(payload.get("eyebrow", "RUN ENDED"))
	_game_over_title.text = str(payload.get("title", "Run Lost"))
	_game_over_body.text = str(payload.get("body", "The maze closed around you."))


func _style_button(button: BaseButton, selected: bool, danger: bool) -> void:
	var normal: StyleBoxTexture = _painter.make_button_style(selected, danger, button.disabled)
	var hover: StyleBoxTexture = _painter.make_panel_style("selected_button" if selected else ("danger_button" if danger else "paper_soft"))
	var disabled: StyleBoxTexture = _painter.make_button_style(selected, danger, true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	if not (button is CheckButton):
		button.add_theme_font_override("font", _painter.make_display_font(18))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", _theme_manifest.get_color("paper") if not danger else _theme_manifest.get_color("danger"))
	button.add_theme_color_override("font_disabled_color", _theme_manifest.get_color("muted"))
	button.add_theme_color_override("font_hover_color", _theme_manifest.get_color("paper"))
	button.add_theme_color_override("font_pressed_color", _theme_manifest.get_color("paper"))
	button.add_theme_constant_override("h_separation", 10)


func _on_action_button_pressed(action_id: String) -> void:
	if action_id == "reset":
		emit_signal("reset_requested")
		return
	emit_signal("action_requested", action_id)


func _on_upgrade_pressed(button: Button) -> void:
	var upgrade_id := String(button.get_meta("upgrade_id", ""))
	if upgrade_id.is_empty():
		return
	emit_signal("upgrade_requested", upgrade_id)


func _on_game_over_restart_pressed() -> void:
	emit_signal("reset_requested")


func _on_pixel_toggle_toggled(enabled: bool) -> void:
	_style_button(_pixel_toggle, enabled, false)
	emit_signal("pixel_filter_toggled", enabled)
