class_name InkPainter
extends RefCounted

const ManifestRef = preload("res://scripts/ink_theme_manifest.gd")

var manifest = null
var _texture_cache: Dictionary = {}
var _style_cache: Dictionary = {}
var _portrait_cache: Dictionary = {}


func _init(theme_manifest = null) -> void:
	manifest = theme_manifest if theme_manifest != null else ManifestRef.new()


func make_display_font(size: int) -> Font:
	var font := SystemFont.new()
	font.font_names = manifest.display_font_names
	font.font_weight = 800
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.allow_system_fallback = true
	font.oversampling = 1.0
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font


func make_body_font(size: int) -> Font:
	var font := SystemFont.new()
	font.font_names = manifest.body_font_names
	font.font_weight = 500
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.allow_system_fallback = true
	font.oversampling = 1.0
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font


func make_backdrop_texture(size: Vector2i) -> Texture2D:
	var key := "backdrop:%s" % size
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var base: Color = manifest.get_color("charcoal")
	var paper: Color = manifest.get_color("ink_soft")
	for y in range(size.y):
		for x in range(size.x):
			var xf := float(x) / maxf(size.x - 1.0, 1.0)
			var yf := float(y) / maxf(size.y - 1.0, 1.0)
			var vignette := clampf(1.25 - pow(abs(xf - 0.5) * 1.9, 1.8) - pow(abs(yf - 0.48) * 2.2, 1.6), 0.0, 1.0)
			var grain := _noise2(x, y, 31)
			var brush := _noise2(x / 4, y / 4, 99)
			var color: Color = base.lerp(paper, 0.10 * vignette + grain * 0.04)
			color = color.darkened((1.0 - vignette) * 0.42)
			if brush > 0.84:
				color = color.lightened(0.08)
			image.set_pixel(x, y, color)
	_draw_scratches(image, Rect2i(0, 0, size.x, size.y), manifest.get_color("shadow"), 16, 43)
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


func make_panel_style(kind: String, accent: Color = Color.TRANSPARENT) -> StyleBoxTexture:
	var key := "panel:%s:%s" % [kind, accent.to_html()]
	if _style_cache.has(key):
		return _style_cache[key]
	var texture := _make_chrome_texture(Vector2i(96, 96), kind, accent)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 24
	style.texture_margin_top = 24
	style.texture_margin_right = 24
	style.texture_margin_bottom = 24
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.modulate_color = Color.WHITE
	style.draw_center = true
	style.content_margin_left = 18
	style.content_margin_top = 18
	style.content_margin_right = 18
	style.content_margin_bottom = 18
	_style_cache[key] = style
	return style


func make_button_style(selected: bool, danger: bool, disabled: bool) -> StyleBoxTexture:
	var kind := "button"
	if danger:
		kind = "danger_button"
	elif selected:
		kind = "selected_button"
	elif disabled:
		kind = "disabled_button"
	return make_panel_style(kind)


func make_role_card_texture(role_id: String, state: Dictionary, size: int = 256, variant: int = 0) -> Texture2D:
	var key := "role:%s:%s:%d:%d" % [role_id, JSON.stringify(state, "", false), size, variant]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var hidden := bool(state.get("is_hidden", false))
	var hovered := bool(state.get("is_hovered", false))
	var previewed := bool(state.get("is_previewed", false))
	var selected := bool(state.get("is_selected_target", false))
	var target := bool(state.get("is_target", false))
	var edge := bool(state.get("is_edge", false))
	var adjacent := bool(state.get("is_player_tile_adjacent", false))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var paper: Color = manifest.get_color("paper")
	var charcoal: Color = manifest.get_color("charcoal")
	var accent: Color = manifest.get_color(role_id, manifest.get_color("highlight"))
	var seed := variant * 17 + role_id.hash()
	var bg: Color = paper
	if hidden:
		bg = manifest.get_color("board").lightened(0.08 + _noise2(variant, seed, 0) * 0.08)
	else:
		bg = paper.lerp(manifest.get_color("paper_dark"), _noise2(seed, size, 0) * 0.18)
	if hovered and not hidden:
		bg = bg.lightened(0.05)
	_draw_irregular_card(image, Rect2i(8, 8, size - 16, size - 16), bg, charcoal, accent, seed)
	if hidden:
		_draw_hidden_card(image, Rect2i(20, 20, size - 40, size - 40), accent, previewed, seed)
	else:
		_draw_portrait_card(image, Rect2i(20, 20, size - 40, size - 40), role_id, accent, seed)
	_draw_card_labels(image, Rect2i(0, 0, size, size), role_id, accent, hidden)
	if edge:
		_draw_corner_notches(image, size, manifest.get_color("highlight"))
	if adjacent:
		_draw_glow_dust(image, Rect2i(12, 12, size - 24, size - 24), manifest.get_color("preview"), 0.20)
	if previewed and hidden:
		_draw_preview_eye(image, size, manifest.get_color("preview"))
	if target:
		_draw_target_marks(image, size, accent.lightened(0.18))
	if selected:
		_draw_selection_frame(image, size, accent)
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


func make_icon_texture(icon_id: String, size: int, color: Color = Color.WHITE, paper_mode: bool = false) -> Texture2D:
	var key := "icon:%s:%d:%s:%s" % [icon_id, size, color.to_html(), str(paper_mode)]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if paper_mode:
		_fill_rect(image, Rect2i(0, 0, size, size), manifest.get_color("paper").darkened(0.04))
	_draw_symbol(image, Rect2i(size / 6, size / 6, size * 2 / 3, size * 2 / 3), icon_id, color)
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


func make_player_token_texture(size: int = 256) -> Texture2D:
	var key := "player:%d" % size
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_irregular_card(image, Rect2i(16, 20, size - 32, size - 40), manifest.get_color("paper"), manifest.get_color("ink"), manifest.get_color("danger"), 211)
	var rect := Rect2i(size * 0.22, size * 0.18, size * 0.56, size * 0.66)
	if not _draw_portrait_asset(image, rect, manifest.get_player_portrait_asset_id()):
		_draw_hooded_figure(image, rect, manifest.get_color("danger"), true, 211)
	_draw_selection_frame(image, size, manifest.get_color("danger"))
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


func make_minimap_texture(snapshot: Dictionary, size: Vector2i) -> Texture2D:
	var key := "minimap:%s:%s" % [JSON.stringify(snapshot, "", false), size]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_fill_rect(image, Rect2i(0, 0, size.x, size.y), manifest.get_color("board"))
	var grid_size: Vector2i = snapshot.get("grid_size", Vector2i(7, 7))
	var cells: Array = snapshot.get("cells", [])
	var padding := 12
	var tile_size := int(min(
		float(size.x - padding * 2) / maxf(grid_size.x, 1),
		float(size.y - padding * 2) / maxf(grid_size.y, 1)
	))
	var offset := Vector2i(
		(size.x - tile_size * grid_size.x) / 2,
		(size.y - tile_size * grid_size.y) / 2
	)
	for cell_data in cells:
		var pos: Vector2i = cell_data.get("position", Vector2i.ZERO)
		var rect := Rect2i(offset.x + pos.x * tile_size, offset.y + pos.y * tile_size, tile_size - 1, tile_size - 1)
		var color: Color = manifest.get_color("paper_dark")
		if bool(cell_data.get("is_hidden", true)):
			color = manifest.get_color("board").lightened(0.13)
		if bool(cell_data.get("is_player", false)):
			color = manifest.get_color("danger")
		elif bool(cell_data.get("is_edge", false)) and not bool(cell_data.get("is_hidden", true)):
			color = manifest.get_color("highlight")
		elif not bool(cell_data.get("is_hidden", true)):
			color = manifest.get_color(String(cell_data.get("role_id", "")), manifest.get_color("paper"))
		_fill_rect(image, rect, color)
		if bool(cell_data.get("is_player", false)):
			_draw_arrow(image, rect.grow(-tile_size / 4), Vector2.RIGHT, manifest.get_color("paper"))
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


func _make_chrome_texture(size: Vector2i, kind: String, accent: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var base: Color = manifest.get_color("board")
	var border: Color = manifest.get_color("paper_dark")
	match kind:
		"selected_button":
			base = Color8(68, 52, 37)
			border = manifest.get_color("highlight")
		"danger_button":
			base = Color8(53, 30, 28)
			border = manifest.get_color("danger")
		"disabled_button":
			base = manifest.get_color("ink_soft")
			border = manifest.get_color("muted")
		"paper":
			base = manifest.get_color("paper")
			border = manifest.get_color("ink")
		"paper_soft":
			base = manifest.get_color("paper_dark")
			border = manifest.get_color("ink_soft")
		_:
			pass
	if accent.a > 0.0:
		border = accent
	_fill_rect(image, Rect2i(0, 0, size.x, size.y), Color(0, 0, 0, 0))
	_draw_irregular_card(image, Rect2i(4, 4, size.x - 8, size.y - 8), base, border, border, kind.hash())
	return ImageTexture.create_from_image(image)


func _draw_irregular_card(image: Image, rect: Rect2i, fill_color: Color, border_color: Color, accent: Color, seed: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var nx := x - rect.position.x
			var ny := y - rect.position.y
			var wobble := int(floor(_noise2(nx + seed, ny, 11) * 3.0))
			if nx < 4 + wobble or ny < 4 + wobble or nx >= rect.size.x - 4 - wobble or ny >= rect.size.y - 4 - wobble:
				image.set_pixel(x, y, border_color)
			else:
				var grain := _noise2(x, y, seed) * 0.08
				image.set_pixel(x, y, fill_color.darkened(grain))
	_draw_stains(image, rect.grow(-8), accent, seed)
	_draw_scratches(image, rect.grow(-10), border_color.darkened(0.4), 5, seed + 13)


func _draw_hidden_card(image: Image, rect: Rect2i, accent: Color, previewed: bool, seed: int) -> void:
	var shade: Color = manifest.get_color("board").lightened(0.18)
	_fill_rect(image, rect, shade)
	_draw_stains(image, rect.grow(-6), accent.darkened(0.6), seed + 6)
	var center := rect.get_center()
	var figure_rect := Rect2i(center.x - rect.size.x / 5, rect.position.y + rect.size.y / 4, rect.size.x / 2, rect.size.y / 2)
	_draw_hooded_figure(image, figure_rect, accent.darkened(0.5), false, seed)
	if previewed:
		_draw_preview_eye(image, rect.size.x + 16, manifest.get_color("preview"))
	_draw_question_mark(image, Rect2i(rect.position.x + rect.size.x / 3, rect.position.y + rect.size.y / 6, rect.size.x / 3, rect.size.y / 3), manifest.get_color("muted"))


func _draw_portrait_card(image: Image, rect: Rect2i, role_id: String, accent: Color, seed: int) -> void:
	var top_band := Rect2i(rect.position.x, rect.position.y, rect.size.x, rect.size.y / 4)
	_fill_rect(image, top_band, accent.darkened(0.10))
	var portrait_rect := Rect2i(rect.position.x + 12, rect.position.y + 18, rect.size.x - 24, rect.size.y - 54)
	var asset_id: String = manifest.get_role_portrait_asset_id(role_id)
	if not _draw_portrait_asset(image, portrait_rect, asset_id):
		match role_id:
			"pusher":
				_draw_hooded_figure(image, portrait_rect, accent, true, seed)
				_draw_arrow(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 3, rect.size.y / 6), Vector2.RIGHT, manifest.get_color("ink"))
			"puller":
				_draw_hat_figure(image, portrait_rect, accent, seed)
				_draw_arrow(image, Rect2i(rect.position.x + rect.size.x / 5, rect.position.y + rect.size.y / 2, rect.size.x / 3, rect.size.y / 6), Vector2.LEFT, manifest.get_color("ink"))
			"blocker":
				_draw_guard_figure(image, portrait_rect, accent, seed)
				_draw_barred_gate(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 4, rect.size.y / 4), manifest.get_color("ink"))
			"redirector":
				_draw_scout_figure(image, portrait_rect, accent, seed)
				_draw_bent_arrow(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 3, rect.size.y / 4), accent)
			"grabber":
				_draw_coat_figure(image, portrait_rect, accent, seed)
				_draw_hook(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 4, rect.size.y / 4), accent.darkened(0.2))
			"guide":
				_draw_scarf_figure(image, portrait_rect, accent, seed)
				_draw_eye(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 4, rect.size.y / 6), manifest.get_color("ink"))
			"smuggler":
				_draw_pack_figure(image, portrait_rect, accent, seed)
				_draw_smuggler_mark(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 4, rect.size.y / 4), accent.darkened(0.2))
			"killer":
				_draw_masked_figure(image, portrait_rect, accent, seed)
				_draw_crosshair(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2, rect.size.x / 4, rect.size.y / 4), accent)
			_:
				_draw_hooded_figure(image, portrait_rect, accent, false, seed)
	var badge_rect := Rect2i(rect.position.x + 12, rect.position.y + 8, 28, 28)
	_fill_rect(image, badge_rect.grow(4), manifest.get_color("paper").darkened(0.08))
	_draw_symbol(image, badge_rect, role_id, manifest.get_color("ink"))


func _draw_portrait_asset(image: Image, target_rect: Rect2i, asset_id: String) -> bool:
	var portrait := _get_portrait_image(asset_id)
	if portrait == null:
		return false
	var source_rect := _get_portrait_crop_rect(portrait)
	var cropped := portrait.get_region(source_rect)
	cropped.resize(target_rect.size.x, target_rect.size.y, Image.INTERPOLATE_LANCZOS)
	image.blit_rect(cropped, Rect2i(Vector2i.ZERO, target_rect.size), target_rect.position)
	return true


func _get_portrait_image(asset_id: String) -> Image:
	if _portrait_cache.has(asset_id):
		return _portrait_cache[asset_id]
	var path: String = manifest.get_portrait_asset_path(asset_id)
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var portrait := Image.new()
	var error := portrait.load(global_path)
	if error != OK:
		return null
	_portrait_cache[asset_id] = portrait
	return portrait


func _get_portrait_crop_rect(portrait: Image) -> Rect2i:
	var width := portrait.get_width()
	var height := portrait.get_height()
	var left := int(round(width * 0.08))
	var top := int(round(height * 0.07))
	var right := int(round(width * 0.08))
	var bottom := int(round(height * 0.24))
	return Rect2i(left, top, width - left - right, height - top - bottom)


func _draw_card_labels(image: Image, rect: Rect2i, role_id: String, accent: Color, hidden: bool) -> void:
	var label_rect := Rect2i(rect.position.x + 18, rect.size.y - 54, rect.size.x - 36, 18)
	if hidden:
		_fill_rect(image, label_rect, manifest.get_color("ink").lightened(0.15))
	else:
		_fill_rect(image, label_rect, accent.darkened(0.24))
	var tick_rect := Rect2i(label_rect.position.x, label_rect.position.y - 10, 20, 4)
	_fill_rect(image, tick_rect, accent)


func _draw_target_marks(image: Image, size: int, color: Color) -> void:
	_fill_rect(image, Rect2i(12, 12, 20, 5), color)
	_fill_rect(image, Rect2i(size - 32, 12, 20, 5), color)
	_fill_rect(image, Rect2i(12, size - 17, 20, 5), color)
	_fill_rect(image, Rect2i(size - 32, size - 17, 20, 5), color)


func _draw_selection_frame(image: Image, size: int, color: Color) -> void:
	for offset in range(0, 5):
		var rect := Rect2i(8 + offset, 8 + offset, size - 16 - offset * 2, size - 16 - offset * 2)
		_draw_rect_outline(image, rect, color.lightened(offset * 0.03))


func _draw_corner_notches(image: Image, size: int, color: Color) -> void:
	_fill_rect(image, Rect2i(8, 8, 10, 10), color)
	_fill_rect(image, Rect2i(size - 18, 8, 10, 10), color)
	_fill_rect(image, Rect2i(8, size - 18, 10, 10), color)
	_fill_rect(image, Rect2i(size - 18, size - 18, 10, 10), color)


func _draw_preview_eye(image: Image, size: int, color: Color) -> void:
	_draw_eye(image, Rect2i(size - 54, 16, 30, 18), color)


func _draw_glow_dust(image: Image, rect: Rect2i, color: Color, strength: float) -> void:
	for _i in range(24):
		var px := rect.position.x + int(_noise2(rect.position.x + _i * 7, rect.position.y, 8) * rect.size.x)
		var py := rect.position.y + int(_noise2(rect.position.y + _i * 13, rect.position.x, 17) * rect.size.y)
		var dust := color.darkened(_noise2(px, py, 44) * 0.3)
		dust.a = strength
		_fill_circle(image, Vector2i(px, py), 2 + (_i % 2), dust)


func _draw_symbol(image: Image, rect: Rect2i, icon_id: String, color: Color) -> void:
	match icon_id:
		"flip":
			_draw_eye(image, rect, color)
		"peek":
			_draw_eye(image, rect, color)
		"step":
			_draw_arrow(image, rect, Vector2.RIGHT, color)
		"anchor":
			_draw_anchor(image, rect, color)
		"remote_flip":
			_draw_bent_arrow(image, rect, color)
		"reset":
			_draw_cross(image, rect, color)
		"pusher":
			_draw_arrow(image, rect, Vector2.RIGHT, color)
		"puller":
			_draw_arrow(image, rect, Vector2.LEFT, color)
		"blocker":
			_draw_barred_gate(image, rect, color)
		"redirector":
			_draw_bent_arrow(image, rect, color)
		"grabber":
			_draw_hook(image, rect, color)
		"guide":
			_draw_eye(image, rect, color)
		"smuggler":
			_draw_smuggler_mark(image, rect, color)
		"killer":
			_draw_crosshair(image, rect, color)
		"conduit":
			_draw_plus_grid(image, rect, color)
		"gate":
			_draw_barred_gate(image, rect, color)
		"anchor_node":
			_draw_anchor(image, rect, color)
		"hub":
			_draw_hub(image, rect, color)
		_:
			_draw_plus_grid(image, rect, color)


func _draw_arrow(image: Image, rect: Rect2i, direction: Vector2, color: Color) -> void:
	if abs(direction.x) > abs(direction.y):
		var y := rect.position.y + rect.size.y / 2 - 2
		var start_x := rect.position.x
		var end_x := rect.position.x + rect.size.x
		if direction.x < 0:
			start_x = rect.position.x + rect.size.x
			end_x = rect.position.x
		_fill_rect(image, Rect2i(min(start_x, end_x), y, abs(end_x - start_x), 4), color)
		var tip := rect.position.x + rect.size.x - 4 if direction.x > 0 else rect.position.x + 4
		for step in range(0, 8):
			var width := 8 - step
			var tx := tip - step if direction.x > 0 else tip + step - width
			_fill_rect(image, Rect2i(tx, y - step, width, 1), color)
			_fill_rect(image, Rect2i(tx, y + 4 + step, width, 1), color)
	else:
		var x := rect.position.x + rect.size.x / 2 - 2
		var start_y := rect.position.y
		var end_y := rect.position.y + rect.size.y
		if direction.y < 0:
			start_y = rect.position.y + rect.size.y
			end_y = rect.position.y
		_fill_rect(image, Rect2i(x, min(start_y, end_y), 4, abs(end_y - start_y)), color)


func _draw_bent_arrow(image: Image, rect: Rect2i, color: Color) -> void:
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 5, rect.position.y + rect.size.y / 2, rect.size.x / 2, 4), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 5, 4, rect.size.y / 2), color)
	_draw_arrow(image, Rect2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 6, rect.size.x / 3, rect.size.y / 3), Vector2.RIGHT, color)


func _draw_eye(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_rect_outline(image, rect, color.darkened(0.45))
	_fill_rect(image, Rect2i(rect.position.x + 2, rect.position.y + rect.size.y / 2 - 2, rect.size.x - 4, 4), color)
	_fill_circle(image, Vector2i(rect.get_center()), max(rect.size.x, rect.size.y) / 6, color)


func _draw_anchor(image: Image, rect: Rect2i, color: Color) -> void:
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2 - 2, rect.position.y + rect.size.y / 5, 4, rect.size.y * 3 / 5), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 4, rect.position.y + rect.size.y / 5, rect.size.x / 2, 4), color)
	_draw_rect_outline(image, Rect2i(rect.position.x + rect.size.x / 4, rect.position.y + rect.size.y / 2, rect.size.x / 2, rect.size.y / 4), color)


func _draw_cross(image: Image, rect: Rect2i, color: Color) -> void:
	for index in range(rect.size.x):
		var y1: int = rect.position.y + index * rect.size.y / max(rect.size.x, 1)
		var y2: int = rect.position.y + rect.size.y - index * rect.size.y / max(rect.size.x, 1) - 1
		_fill_rect(image, Rect2i(rect.position.x + index, y1, 2, 2), color)
		_fill_rect(image, Rect2i(rect.position.x + index, y2, 2, 2), color)


func _draw_barred_gate(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_rect_outline(image, rect, color)
	for bar in range(1, 4):
		var x := rect.position.x + bar * rect.size.x / 4
		_fill_rect(image, Rect2i(x, rect.position.y + 2, 2, rect.size.y - 4), color)


func _draw_hook(image: Image, rect: Rect2i, color: Color) -> void:
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2 - 2, rect.position.y, 4, rect.size.y / 2), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2 - 2, rect.position.y + rect.size.y / 2, rect.size.x / 3, 4), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x * 2 / 3, rect.position.y + rect.size.y / 2, 4, rect.size.y / 3), color)


func _draw_smuggler_mark(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_rect_outline(image, rect, color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 4, rect.position.y + rect.size.y / 3, rect.size.x / 2, rect.size.y / 3), color)


func _draw_crosshair(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_rect_outline(image, rect, color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2 - 1, rect.position.y, 2, rect.size.y), color)
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y + rect.size.y / 2 - 1, rect.size.x, 2), color)


func _draw_plus_grid(image: Image, rect: Rect2i, color: Color) -> void:
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2 - 2, rect.position.y, 4, rect.size.y), color)
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y + rect.size.y / 2 - 2, rect.size.x, 4), color)


func _draw_hub(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_rect_outline(image, rect, color)
	_fill_circle(image, Vector2i(rect.get_center()), rect.size.x / 6, color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 2 - 1, rect.position.y + 3, 2, rect.size.y - 6), color)
	_fill_rect(image, Rect2i(rect.position.x + 3, rect.position.y + rect.size.y / 2 - 1, rect.size.x - 6, 2), color)


func _draw_question_mark(image: Image, rect: Rect2i, color: Color) -> void:
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 3, rect.position.y, rect.size.x / 3, 4), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x * 2 / 3 - 2, rect.position.y + 4, 4, rect.size.y / 3), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 3, rect.position.y + rect.size.y / 3, rect.size.x / 3, 4), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 3, rect.position.y + rect.size.y / 3, 4, rect.size.y / 4), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x / 3, rect.position.y + rect.size.y - 8, 4, 4), color)


func _draw_hooded_figure(image: Image, rect: Rect2i, accent: Color, hooded: bool, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, hooded, false, false, false, false, seed)


func _draw_hat_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, false, true, false, false, false, seed)


func _draw_guard_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, false, false, true, false, false, seed)


func _draw_scout_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, false, false, false, true, false, seed)


func _draw_coat_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, false, false, false, false, true, seed)


func _draw_scarf_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, false, false, false, false, false, seed, true)


func _draw_pack_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, false, false, false, false, true, seed, false, true)


func _draw_masked_figure(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	_draw_generic_figure(image, rect, accent, true, false, true, false, true, seed)


func _draw_generic_figure(
	image: Image,
	rect: Rect2i,
	accent: Color,
	hooded: bool,
	hat: bool,
	guard: bool,
	scout: bool,
	long_coat: bool,
	seed: int,
	scarf: bool = false,
	pack: bool = false
) -> void:
	var ink: Color = manifest.get_color("ink")
	var skin: Color = manifest.get_color("paper")
	var face_center := Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 4)
	var body_rect := Rect2i(rect.position.x + rect.size.x / 4, rect.position.y + rect.size.y / 3, rect.size.x / 2, rect.size.y / 2)
	_fill_circle(image, face_center, max(rect.size.x / 10, 6), skin.darkened(0.06))
	_fill_rect(image, body_rect, ink)
	_fill_rect(image, Rect2i(body_rect.position.x + 4, body_rect.position.y + 4, body_rect.size.x - 8, body_rect.size.y - 8), accent.darkened(0.04 + _noise2(seed, rect.position.x, 2) * 0.08))
	if hooded:
		_draw_rect_outline(image, Rect2i(face_center.x - rect.size.x / 7, face_center.y - rect.size.y / 10, rect.size.x / 3, rect.size.y / 4), ink)
	if hat:
		_fill_rect(image, Rect2i(face_center.x - rect.size.x / 6, face_center.y - rect.size.y / 8, rect.size.x / 3, 4), ink)
		_fill_rect(image, Rect2i(face_center.x - rect.size.x / 9, face_center.y - rect.size.y / 5, rect.size.x / 5, 8), ink)
	if scarf:
		_fill_rect(image, Rect2i(body_rect.position.x + 4, body_rect.position.y + 8, body_rect.size.x - 8, 10), manifest.get_color("danger"))
	if long_coat:
		_fill_rect(image, Rect2i(body_rect.position.x + 8, body_rect.position.y + body_rect.size.y / 2, body_rect.size.x - 16, body_rect.size.y / 2), ink)
	if guard:
		_fill_rect(image, Rect2i(body_rect.position.x + body_rect.size.x - 12, body_rect.position.y + 6, 8, body_rect.size.y - 12), manifest.get_color("ink_soft"))
	if scout:
		_fill_rect(image, Rect2i(body_rect.position.x + body_rect.size.x - 10, body_rect.position.y + 10, 10, 10), manifest.get_color("paper"))
	if pack:
		_fill_rect(image, Rect2i(body_rect.position.x - 10, body_rect.position.y + 12, 12, body_rect.size.y - 24), manifest.get_color("ink_soft"))


func _draw_stains(image: Image, rect: Rect2i, accent: Color, seed: int) -> void:
	for index in range(12):
		var radius := 3 + (index % 5)
		var px := rect.position.x + int(_noise2(seed, index * 17, 51) * rect.size.x)
		var py := rect.position.y + int(_noise2(seed, index * 31, 77) * rect.size.y)
		var color := accent.darkened(0.18 + _noise2(px, py, seed) * 0.22)
		color.a = 0.11
		_fill_circle(image, Vector2i(px, py), radius, color)


func _draw_scratches(image: Image, rect: Rect2i, color: Color, count: int, seed: int) -> void:
	for index in range(count):
		var start := Vector2i(
			rect.position.x + int(_noise2(index, seed, 13) * rect.size.x),
			rect.position.y + int(_noise2(index, seed, 29) * rect.size.y)
		)
		var end := start + Vector2i(
			8 + int(_noise2(seed, index, 41) * 24),
			int(_noise2(seed, index, 83) * 10) - 5
		)
		_draw_line(image, start, end, color, 1)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				var base := image.get_pixel(x, y)
				image.set_pixel(x, y, base.lerp(color, color.a if color.a < 1.0 else 1.0))


func _draw_rect_outline(image: Image, rect: Rect2i, color: Color) -> void:
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y, rect.size.x, 2), color)
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y + rect.size.y - 2, rect.size.x, 2), color)
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y, 2, rect.size.y), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x - 2, rect.position.y, 2, rect.size.y), color)


func _fill_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius * radius:
				if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
					var base := image.get_pixel(x, y)
					image.set_pixel(x, y, base.lerp(color, color.a if color.a < 1.0 else 1.0))


func _draw_line(image: Image, start: Vector2i, end: Vector2i, color: Color, thickness: int) -> void:
	var distance := maxi(int(start.distance_to(end)), 1)
	for step in range(distance + 1):
		var t := float(step) / distance
		var point := Vector2(
			lerpf(start.x, end.x, t),
			lerpf(start.y, end.y, t)
		)
		_fill_circle(image, Vector2i(point), max(thickness, 1), color)


func _noise2(x: int, y: int, seed: int) -> float:
	var value := int(x) * 374761393 + int(y) * 668265263 + seed * 700001
	value = int((value ^ (value >> 13)) * 1274126177)
	value ^= value >> 16
	return abs(float(value % 1000)) / 999.0
